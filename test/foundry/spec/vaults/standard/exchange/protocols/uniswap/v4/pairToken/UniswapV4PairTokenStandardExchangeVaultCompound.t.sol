// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {Vm, VmSafe} from "forge-std/Vm.sol";
import {TestBase_UniswapV4PairTokenStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/test/bases/TestBase_UniswapV4PairTokenStandardExchangeVault.sol";
import {IUniswapV4PairTokenStandardExchangeVault as IVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol";
import {IUniswapV4PairTokenStandardExchangeVaultDFPkg as IPackage} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol";
import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Events} from "@crane/contracts/interfaces/IERC20Events.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";

// tag::UniswapV4PairTokenStandardExchangeVaultCompoundTest[]
/// @notice Real public maintenance with independent manager growth/delta conservation controls.
contract UniswapV4PairTokenStandardExchangeVaultCompoundTest is TestBase_UniswapV4PairTokenStandardExchangeVault {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    struct Before {
        uint256 supply;
        uint256 shares;
        uint128 liquidity;
        uint256 book0;
        uint256 book1;
        uint256 raw0;
        uint256 raw1;
        uint256 pool0;
        uint256 pool1;
        uint256 holder0;
        uint256 holder1;
        uint256 fees0;
        uint256 fees1;
        uint256 inside0;
        uint256 inside1;
    }

    struct Observed {
        uint256 fees0;
        uint256 fees1;
        uint256 cost0;
        uint256 cost1;
        uint128 added;
        int256 swap0;
        int256 swap1;
        uint256 swaps;
        uint256 pokes;
        uint256 adds;
        uint256 managerAdded;
        uint256 firstPoke;
        uint256 swapIndex;
        uint256 lastModify;
    }

    struct EntryExpectation {
        Before incumbent;
        int256 swap0;
        int256 swap1;
        uint160 price;
        uint256 fees0;
        uint256 fees1;
    }

    /// @notice S1-A66: empty compound does not poke, adopt unsolicited balances or create shares.
    function test_PairToken_CMP_EmptyCompoundCleanAndUnsolicitedNoOp() public {
        _assertEmpty();
        _fund(address(this), 10001, 20003);
        token0.transfer(address(vault), 10001);
        token1.transfer(address(vault), 20003);
        _assertEmpty();
        assertEq(token0.balanceOf(address(vault)), 10001);
        assertEq(token1.balanceOf(address(vault)), 20003);
    }

    /// @notice S1-A22: all fees retained once; no supply, allowance, notify or recipient side effects.
    function test_PairToken_CMP_NoVaultFeeOrShareChange() public {
        _bootstrap(1e18, 1e18, address(this));
        _fund(address(poolActor), 1e12, 2e12);
        poolActor.donate(key, 1e12, 2e12);
        _fund(address(this), 12345, 23456);
        token0.transfer(address(vault), 12345);
        token1.transfer(address(vault), 23456);
        Before memory before_ = _before();
        assertGt(before_.fees0, 0);
        assertGt(before_.fees1, 0);
        vm.startStateDiffRecording();
        Observed memory actual_ = _compound(before_);
        Vm.AccountAccess[] memory accesses_ = vm.stopAndReturnStateDiff();
        _assertOnlyPoolAndTokenCalls(accesses_);
        assertGe(actual_.fees0, before_.fees0);
        assertGe(actual_.fees1, before_.fees1);
        assertEq(token0.allowance(address(vault), address(pool)), 0);
        assertEq(token1.allowance(address(vault), address(pool)), 0);
        assertEq(token0.allowance(address(vault), address(indexedexManager)), 0);
        assertEq(token1.allowance(address(vault), address(indexedexManager)), 0);
        assertEq(token0.allowance(address(vault), address(feeCollector)), 0);
        assertEq(token1.allowance(address(vault), address(feeCollector)), 0);
        (uint256 book0_, uint256 book1_) = vault.localReserves();
        assertEq(token0.balanceOf(address(vault)) - book0_, 12345);
        assertEq(token1.balanceOf(address(vault)) - book1_, 23456);
    }

    /// @notice S1-A23/A69: exactly 1000 is idle; one unit above enables balanced reinvestment.
    function test_PairToken_CMP_StrictRawDustAndBalancedLeftoverTie() public {
        _bootstrap(1e18, 1e18, address(this));
        uint256 snapshot_ = vm.snapshotState();
        _donate(1000, 1000);
        Observed memory atDust_ = _compound(_before());
        assertEq(atDust_.swaps, 0);
        assertEq(atDust_.added, 0);
        _assertBook(1000, 1000);
        assertTrue(vm.revertToState(snapshot_));
        _donate(1001, 1001);
        // At P=Q96, the independently affordable balanced addition leaves (0,0).
        // Its leftover valuations tie exactly; the baseline selects token0 but
        // the <=DUST branch emits no swap, so direction is economically unobservable.
        Observed memory aboveDust_ = _compound(_before());
        assertEq(aboveDust_.swaps, 0);
        assertEq(aboveDust_.added, 1001);
        assertEq(aboveDust_.cost0, 1001);
        assertEq(aboveDust_.cost1, 1001);
        _assertBook(0, 0);
    }

    /// @notice S1-A23: a nonzero chosen leftover no larger than DUST does not ratio-swap.
    function test_PairToken_CMP_SmallLeftoverDoesNotSwap() public {
        _bootstrap(1e18, 1e18, address(this));
        _donate(2001, 1001);
        Observed memory actual_ = _compound(_before());
        assertEq(actual_.swaps, 0);
        assertEq(actual_.added, 1001);
        _assertBook(1000, 0);
    }

    /// @notice S1-A23: a sequential-floor value tie can have a positive token0 sale at a low price.
    function test_PairToken_CMP_SequentialFloorTieChoosesToken0() public {
        key.fee = 500;
        uint160 price_ = TickMath.getSqrtPriceAtTick(-860000);
        pool.initialize(key, price_);
        vault = _deployVault(_defaultArgs(key, address(token0), "observable leftover tie"));
        _bootstrap(1e28, 1, address(this));
        _donate(1000000, 0);
        Before memory before_ = _before();
        assertEq(before_.book1, 0, "zero limiting leg implies zero affordable add");
        uint256 value0_ = (before_.book0 * price_ / (uint256(1) << 96)) * price_ / (uint256(1) << 96);
        assertEq(value0_, before_.book1, "independent sequential-floor tie");
        assertGt(before_.book0 / 2, 0);
        Observed memory actual_ = _compound(before_);
        assertEq(actual_.swaps, 1);
        assertEq(uint256(-actual_.swap0), before_.book0 / 2, "tie chooses token0, not empty token1");
        assertEq(actual_.swap1, 0, "tiny raw token1 output rounds to zero");
        assertEq(actual_.added, 0);
        assertEq(actual_.pokes, 2);
    }

    /// @notice S1-A23: both sale directions use half leftover until the quarter cap binds.
    function test_PairToken_CMP_HalfLeftoverBothDirections() public {
        _bootstrap(1e18, 1e18, address(this));
        uint256 snapshot_ = vm.snapshotState();
        _donate(1000000, 0);
        Observed memory sell0_ = _compound(_before());
        assertEq(sell0_.swaps, 1);
        assertEq(-sell0_.swap0, 500000);
        assertGt(sell0_.swap1, 0);
        assertTrue(vm.revertToState(snapshot_));
        _donate(0, 1000000);
        Observed memory sell1_ = _compound(_before());
        assertEq(sell1_.swaps, 1);
        assertEq(-sell1_.swap1, 500000);
        assertGt(sell1_.swap0, 0);
    }

    /// @notice S1-A23: compute cap from actual active-liquidity principal, not the owned book.
    function test_PairToken_CMP_QuarterReserveCapBothDirections() public {
        _bootstrap(1e18, 1e18, address(this));
        uint256 snapshot_ = vm.snapshotState();
        _assertQuarterCap(true);
        assertTrue(vm.revertToState(snapshot_));
        _assertQuarterCap(false);
    }

    /// @notice S1-A23: outside the owned full range, zero active liquidity disables the ratio swap.
    function test_PairToken_CMP_ZeroActiveLiquidityNoSwap() public {
        _bootstrap(1e6, 1e6, address(this));
        _fund(address(poolActor), 1e35, 0);
        poolActor.swap(key, SwapParams(true, -int256(1e35), TickMath.MIN_SQRT_PRICE + 1));
        assertEq(pool.getLiquidity(key.toId()), 0);
        assertGt(vault.positionLiquidity(), 0);
        (uint160 price_,,,) = pool.getSlot0(key.toId());
        assertLt(price_, TickMath.getSqrtPriceAtTick(vault.tickLower()));
        _donate(1000000000000000000000000, 0);
        Observed memory actual_ = _compound(_before());
        assertEq(actual_.swaps, 0);
        assertGt(actual_.added, 0, "one-sided out-of-range addition is fundable");
        assertEq(pool.getLiquidity(key.toId()), 0, "owned is not active liquidity");
    }

    /// @notice S1-A24: positive add realizes swap fees on pre-add liquidity, once and nonrecursively.
    function test_PairToken_CMP_PositiveAddFinalFeeCheckpoint() public {
        _bootstrap(1e18, 1e18, address(this));
        _donate(1e12, 0);
        Before memory before_ = _before();
        Observed memory actual_ = _compound(before_);
        assertEq(actual_.swaps, 1);
        assertEq(actual_.adds, 1);
        assertEq(actual_.pokes, 1, "initial collection; add is the final checkpoint");
        assertLt(actual_.firstPoke, actual_.swapIndex);
        assertLt(actual_.swapIndex, actual_.lastModify);
        assertGt(actual_.fees0, 0);
        _assertCheckpointCurrent();
        // No recursively reinvested fee: it remains in the final exact local book.
        (uint256 book0_,) = vault.localReserves();
        assertGe(book0_, actual_.fees0);
    }

    /// @notice S1-A24: 100%-fee swap has no output or add, so a final poke realizes its fee.
    function test_PairToken_CMP_NoAddFinalFeeCheckpoint() public {
        key.fee = 1000000;
        pool.initialize(key, uint160(1) << 96);
        IPackage.PkgArgs memory args_ = _defaultArgs(key, address(token0), "no-add fee checkpoint");
        vault = _deployVault(args_);
        _bootstrap(1e18, 1e18, address(this));
        _donate(1000000, 0);
        Before memory before_ = _before();
        Observed memory actual_ = _compound(before_);
        assertEq(actual_.swaps, 1);
        assertEq(actual_.swap0, -500000);
        assertEq(actual_.swap1, 0);
        assertEq(actual_.added, 0);
        assertEq(actual_.adds, 0);
        assertEq(actual_.pokes, 2, "collection and nonrecursive post-swap checkpoint");
        assertLt(actual_.firstPoke, actual_.swapIndex);
        assertLt(actual_.swapIndex, actual_.lastModify);
        assertGt(actual_.fees0, 0);
        _assertCheckpointCurrent();
        _assertBook(before_.book0 - 500000 + actual_.fees0, 0);
    }

    /// @notice S1-A24: entry-swap fees are checkpointed to old supply before caller-only addition.
    function test_PairToken_CMP_EntrySwapFeesStayIncumbentBothDirections() public {
        _bootstrap(1e18, 1e18, address(this));
        _fund(address(poolActor), 1e18, 1e18);
        _fund(address(this), 1e15, 1e15);
        uint256 snapshot_ = vm.snapshotState();
        _assertEntryFees(true);
        assertTrue(vm.revertToState(snapshot_));
        _assertEntryFees(false);
    }

    function _assertEntryFees(bool input0_) private {
        uint256 amount_ = 1e15;
        EntryExpectation memory expected_;
        expected_.incumbent = _before();
        uint256 snapshot_ = vm.snapshotState();
        // Independent actor-only swap from the identical pool state; the actual
        // operation must credit its fees to the pre-mint position, not the entrant.
        BalanceDelta delta_ = poolActor.swap(key, SwapParams(
            input0_, -int256(amount_ / 2), input0_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
        ));
        expected_.swap0 = delta_.amount0();
        expected_.swap1 = delta_.amount1();
        (expected_.price,,,) = pool.getSlot0(key.toId());
        (uint256 inside0_, uint256 inside1_) = pool.getFeeGrowthInside(key.toId(), vault.tickLower(), vault.tickUpper());
        expected_.fees0 = FullMath.mulDiv(inside0_ - expected_.incumbent.inside0,
            expected_.incumbent.liquidity, uint256(1) << 128);
        expected_.fees1 = FullMath.mulDiv(inside1_ - expected_.incumbent.inside1,
            expected_.incumbent.liquidity, uint256(1) << 128);
        assertGt(input0_ ? expected_.fees0 : expected_.fees1, 0);
        assertTrue(vm.revertToState(snapshot_));
        vm.recordLogs();(uint256 minted_,) = IStandardExchangeIn(address(vault)).exchangeIn(IERC20(input0_ ? address(token0) : address(token1)), amount_, IERC20(address(vault)),
            0, address(this), false, block.timestamp
        );
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        assertEq(IERC20(address(vault)).totalSupply(), expected_.incumbent.supply + minted_);
        assertEq(IERC20(address(vault)).balanceOf(address(this)), expected_.incumbent.shares + minted_);
        (uint160 actualPrice_,,,) = pool.getSlot0(key.toId());
        assertEq(actualPrice_, expected_.price);
        _assertEntryBook(expected_, input0_, amount_, logs_);
        _assertCheckpointCurrent();
    }

    function _assertEntryBook(
        EntryExpectation memory e_, bool input0_, uint256 amount_, Vm.Log[] memory logs_
    ) private view {
        uint128 current_ = vault.positionLiquidity();
        uint128 added_ = current_ - e_.incumbent.liquidity;
        uint160 lower_ = TickMath.getSqrtPriceAtTick(vault.tickLower());
        uint160 upper_ = TickMath.getSqrtPriceAtTick(vault.tickUpper());
        uint256[6] memory expected_;
        expected_[0] = amount_;
        expected_[3] = _apply(input0_ ? amount_ : 0, e_.swap0)
            - SqrtPriceMath.getAmount0Delta(e_.price, upper_, added_, true);
        expected_[4] = _apply(input0_ ? 0 : amount_, e_.swap1)
            - SqrtPriceMath.getAmount1Delta(lower_, e_.price, added_, true);
        expected_[1] = SqrtPriceMath.getAmount0Delta(e_.price, upper_, current_, false);
        expected_[1] -= SqrtPriceMath.getAmount0Delta(e_.price, upper_, e_.incumbent.liquidity, false);
        expected_[2] = SqrtPriceMath.getAmount1Delta(lower_, e_.price, current_, false);
        expected_[2] -= SqrtPriceMath.getAmount1Delta(lower_, e_.price, e_.incumbent.liquidity, false);
        expected_[5] = IERC20(address(vault)).totalSupply() - e_.incumbent.supply;
        _assertBook(e_.incumbent.book0 + e_.fees0 + expected_[3], e_.incumbent.book1 + e_.fees1 + expected_[4]);
        uint256 events_;
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].emitter != address(vault) || logs_[i_].topics[0] != IVault.ZapCredit.selector) continue;
            ++events_;
            uint256[6] memory fields_ = abi.decode(logs_[i_].data, (uint256[6]));
            assertEq(abi.encode(fields_), abi.encode(expected_));
        }
        assertEq(events_, 1);
    }

    function _assertEmpty() private {
        Before memory before_ = _before();
        vm.startStateDiffRecording();
        Observed memory actual_ = _compound(before_);
        Vm.AccountAccess[] memory accesses_ = vm.stopAndReturnStateDiff();
        assertEq(actual_.swaps, 0);
        assertEq(actual_.pokes, 0, "never poke an empty position");
        assertEq(actual_.added, 0);
        assertEq(actual_.fees0, 0);
        assertEq(actual_.fees1, 0);
        _assertBook(0, 0);
        for (uint256 i_; i_ < accesses_.length; ++i_) {
            assertFalse(accesses_[i_].kind == VmSafe.AccountAccessKind.Call && accesses_[i_].account == address(pool),
                "no manager mutation for an empty compound");
        }
    }

    function _assertQuarterCap(bool zeroForOne_) private {
        (uint160 price_,,,) = pool.getSlot0(key.toId());
        uint128 active_ = pool.getLiquidity(key.toId());
        uint256 reserve_ = zeroForOne_
            ? SqrtPriceMath.getAmount0Delta(price_, TickMath.getSqrtPriceAtTick(vault.tickUpper()), active_, false)
            : SqrtPriceMath.getAmount1Delta(TickMath.getSqrtPriceAtTick(vault.tickLower()), price_, active_, false);
        uint256 cap_ = reserve_ * vault.maxZapBps() / 10000 / 4;
        _donate(zeroForOne_ ? 1e20 : 0, zeroForOne_ ? 0 : 1e20);
        assertLt(cap_, 1e20 / 2, "cap binds before half leftover");
        Observed memory actual_ = _compound(_before());
        assertEq(actual_.swaps, 1);
        assertEq(uint256(-(zeroForOne_ ? actual_.swap0 : actual_.swap1)), cap_);
    }

    function _compound(Before memory before_) private returns (Observed memory actual_) {
        vm.recordLogs();
        (uint256 reported0_, uint256 reported1_) = vault.compound();
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        actual_ = _observe(logs_);
        assertEq(reported0_, actual_.fees0);
        assertEq(reported1_, actual_.fees1);
        _assertConservation(before_, actual_);
    }

    function _observe(Vm.Log[] memory logs_) private view returns (Observed memory o_) {
        uint256 compoundEvents_;
        for (uint256 i_; i_ < logs_.length; ++i_) {
            Vm.Log memory entry_ = logs_[i_];
            if (entry_.emitter == address(vault)) {
                if (entry_.topics[0] == IVault.Compounded.selector) {
                    ++compoundEvents_;
                    (o_.fees0, o_.fees1, o_.cost0, o_.cost1, o_.added) =
                        abi.decode(entry_.data, (uint256, uint256, uint256, uint256, uint128));
                }
                assertTrue(entry_.topics[0] != IERC20Events.Transfer.selector, "compound never emits share transfers");
                assertTrue(entry_.topics[0] != IERC20Events.Approval.selector, "compound never approves shares");
            }
            if (entry_.emitter != address(pool) || entry_.topics.length < 3) continue;
            assertEq(entry_.topics[1], PoolId.unwrap(key.toId()));
            assertEq(entry_.topics[2], bytes32(uint256(uint160(address(vault)))));
            if (entry_.topics[0] == IPoolManager.Swap.selector) {
                ++o_.swaps;
                (int128 amount0_, int128 amount1_,,,,) = abi.decode(entry_.data, (int128, int128, uint160, uint128, int24, uint24));
                o_.swap0 += amount0_;
                o_.swap1 += amount1_;
                o_.swapIndex = i_;
            } else if (entry_.topics[0] == IPoolManager.ModifyLiquidity.selector) {
                (int24 lower_, int24 upper_, int256 delta_, bytes32 salt_) =
                    abi.decode(entry_.data, (int24, int24, int256, bytes32));
                assertEq(lower_, vault.tickLower());
                assertEq(upper_, vault.tickUpper());
                assertEq(salt_, bytes32(0));
                assertGe(delta_, 0, "compound cannot remove backing");
                if (delta_ == 0) {
                    if (o_.pokes == 0) o_.firstPoke = i_;
                    ++o_.pokes;
                } else {
                    ++o_.adds;
                    o_.managerAdded += uint256(delta_);
                }
                o_.lastModify = i_;
            }
        }
        assertEq(compoundEvents_, 1);
        assertEq(o_.managerAdded, o_.added, "manager add equals reported add");
    }

    function _assertConservation(Before memory b_, Observed memory o_) private view {
        assertEq(IERC20(address(vault)).totalSupply(), b_.supply);
        assertEq(IERC20(address(vault)).balanceOf(address(this)), b_.shares);
        assertEq(IERC20(address(vault)).balanceOf(address(vault)), 0);
        assertEq(IERC20(address(vault)).balanceOf(address(0xdead)), 0);
        assertEq(vault.positionLiquidity(), b_.liquidity + o_.added);
        {
            (uint128 managerOwned_,,) =
                pool.getPositionInfo(key.toId(), address(vault), vault.tickLower(), vault.tickUpper(), bytes32(0));
            assertEq(managerOwned_, b_.liquidity + o_.added);
            (uint256 inside0_, uint256 inside1_) = pool.getFeeGrowthInside(key.toId(), vault.tickLower(), vault.tickUpper());
            unchecked {
                assertEq(o_.fees0, b_.fees0 + FullMath.mulDiv(inside0_ - b_.inside0, b_.liquidity, uint256(1) << 128),
                    "every checkpoint fee exactly once on old liquidity");
                assertEq(o_.fees1, b_.fees1 + FullMath.mulDiv(inside1_ - b_.inside1, b_.liquidity, uint256(1) << 128));
            }
        }
        // Canonical costs at the final price, not SUT arithmetic or the emitted cost itself.
        {
            (uint160 price_,,,) = pool.getSlot0(key.toId());
            uint160 lower_ = TickMath.getSqrtPriceAtTick(vault.tickLower());
            uint160 upper_ = TickMath.getSqrtPriceAtTick(vault.tickUpper());
            if (price_ < lower_) price_ = lower_;
            if (price_ > upper_) price_ = upper_;
            if (b_.book0 + b_.fees0 <= 1000 && b_.book1 + b_.fees1 <= 1000) {
                assertEq(o_.added, 0, "strict initial raw dust gate");
            } else {
                assertEq(o_.added, LiquidityAmounts.getLiquidityForAmounts(price_, lower_, upper_,
                    _apply(b_.book0 + b_.fees0, o_.swap0), _apply(b_.book1 + b_.fees1, o_.swap1)),
                    "independent affordable addition excludes final checkpoint fees");
            }
            assertEq(o_.cost0, SqrtPriceMath.getAmount0Delta(price_, upper_, o_.added, true));
            assertEq(o_.cost1, SqrtPriceMath.getAmount1Delta(lower_, price_, o_.added, true));
        }
        uint256 expected0_ = _apply(b_.book0 + o_.fees0, o_.swap0) - o_.cost0;
        uint256 expected1_ = _apply(b_.book1 + o_.fees1, o_.swap1) - o_.cost1;
        _assertBook(expected0_, expected1_);
        assertEq(token0.balanceOf(address(vault)), expected0_ + b_.raw0 - b_.book0);
        assertEq(token1.balanceOf(address(vault)), expected1_ + b_.raw1 - b_.book1);
        assertEq(token0.balanceOf(address(pool)) + token0.balanceOf(address(vault)), b_.pool0 + b_.raw0);
        assertEq(token1.balanceOf(address(pool)) + token1.balanceOf(address(vault)), b_.pool1 + b_.raw1);
        assertEq(token0.balanceOf(address(this)), b_.holder0);
        assertEq(token1.balanceOf(address(this)), b_.holder1);
        assertEq(TransientStateLibrary.currencyDelta(pool, address(vault), key.currency0), 0);
        assertEq(TransientStateLibrary.currencyDelta(pool, address(vault), key.currency1), 0);
    }

    function _before() private view returns (Before memory b_) {
        b_.supply = IERC20(address(vault)).totalSupply();
        b_.shares = IERC20(address(vault)).balanceOf(address(this));
        (b_.liquidity, b_.inside0, b_.inside1) =
            pool.getPositionInfo(key.toId(), address(vault), vault.tickLower(), vault.tickUpper(), bytes32(0));
        (uint256 inside0_, uint256 inside1_) = pool.getFeeGrowthInside(key.toId(), vault.tickLower(), vault.tickUpper());
        unchecked {
            b_.fees0 = FullMath.mulDiv(inside0_ - b_.inside0, b_.liquidity, uint256(1) << 128);
            b_.fees1 = FullMath.mulDiv(inside1_ - b_.inside1, b_.liquidity, uint256(1) << 128);
        }
        b_.inside0 = inside0_;
        b_.inside1 = inside1_;
        (b_.book0, b_.book1) = vault.localReserves();
        b_.raw0 = token0.balanceOf(address(vault));
        b_.raw1 = token1.balanceOf(address(vault));
        b_.pool0 = token0.balanceOf(address(pool));
        b_.pool1 = token1.balanceOf(address(pool));
        b_.holder0 = token0.balanceOf(address(this));
        b_.holder1 = token1.balanceOf(address(this));
    }

    function _assertCheckpointCurrent() private view {
        (, uint256 last0_, uint256 last1_) =
            pool.getPositionInfo(key.toId(), address(vault), vault.tickLower(), vault.tickUpper(), bytes32(0));
        (uint256 inside0_, uint256 inside1_) = pool.getFeeGrowthInside(key.toId(), vault.tickLower(), vault.tickUpper());
        assertEq(last0_, inside0_);
        assertEq(last1_, inside1_);
    }

    function _assertOnlyPoolAndTokenCalls(Vm.AccountAccess[] memory accesses_) private view {
        for (uint256 i_; i_ < accesses_.length; ++i_) {
            Vm.AccountAccess memory access_ = accesses_[i_];
            if (access_.accessor != address(vault) || access_.kind != VmSafe.AccountAccessKind.Call) continue;
            assertTrue(access_.account == address(pool) || access_.account == address(token0)
                || access_.account == address(token1), "unexpected external call / fee-manager notify");
        }
    }

    function _donate(uint256 amount0_, uint256 amount1_) private {
        _fund(address(this), amount0_, amount1_);
        if (amount0_ != 0) vault.donate(address(token0), amount0_);
        if (amount1_ != 0) vault.donate(address(token1), amount1_);
    }

    function _assertBook(uint256 amount0_, uint256 amount1_) private view {
        (uint256 book0_, uint256 book1_) = vault.localReserves();
        assertEq(book0_, amount0_);
        assertEq(book1_, amount1_);
        assertEq(IBasicVault(address(vault)).reserveOfToken(address(token0)), amount0_);
        assertEq(IBasicVault(address(vault)).reserveOfToken(address(token1)), amount1_);
    }

    function _apply(uint256 amount_, int256 delta_) private pure returns (uint256) {
        return delta_ < 0 ? amount_ - uint256(-delta_) : amount_ + uint256(delta_);
    }
}
// end::UniswapV4PairTokenStandardExchangeVaultCompoundTest[]
