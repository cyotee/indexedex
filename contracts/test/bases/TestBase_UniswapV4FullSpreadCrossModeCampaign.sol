// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield as SY} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";

interface IFullSpreadCampaignReserve {
    function deployedReserve() external view returns (uint256, uint256);
}

interface IFullSpreadCampaignFeeLedger {
    function pendingFees(PoolId, address) external view returns (uint256);
    function pendingCreatorTax(PoolId, address) external view returns (uint256);
}

// tag::TestBase_UniswapV4FullSpreadCrossModeCampaign[]
/// @notice Test-only accounting assertions shared by independent registry-proxy fixtures.
/// @dev No family implementation, quote service, planner or execution helper is reused here.
/// Each fuzz input drives 32 sequential actions; balances are never restored between steps.
abstract contract TestBase_UniswapV4FullSpreadCrossModeCampaign is Test {
    using PoolIdLibrary for PoolKey;

    struct PoolSnapshot { uint160 sqrtPriceX96; int24 tick; uint128 liquidity; }
    struct BookSnapshot {
        address vault; bool token0; bool idle; uint256 supply; uint256 shares;
        uint256 free0; uint256 free1; uint256 fees0; uint256 fees1;
        uint128 positionLiquidity; int24 lower; int24 upper; int128 liquidityDelta;
        PoolSnapshot pool; uint256 sleeveWad; uint256[2] absoluteFloor;
        uint128 lowerLiquidityGross; uint128 upperLiquidityGross; uint128 maxLiquidityPerTick;
    }

    struct StepFrame {
        BookSnapshot beforeBook;
        uint256[2] beforeGrowth;
        uint256[2] beforeCaller;
        uint256[4] hookBefore;
    }
    struct ObservedSwap { uint256 inputLeg; uint256 input; uint256 output; }
    struct MintReference {
        BookSnapshot original; BookSnapshot finalBook;
        uint256[2] repriced; uint256[2] finalPrincipal; uint256[2] cash; uint256[2] settlement;
        bool addition; uint256 expected;
    }

    IStandardExchangeProxy internal campaignVault;
    IPoolManager internal campaignManager;
    PoolKey internal campaignKey;
    IERC20[2] internal campaignTokens;
    uint256[2] internal campaignUnits;
    uint256[2] internal conservedBalances;
    uint256 internal initialSupply;
    uint256 internal initialShares;
    uint256 internal issuedShares;
    uint256 internal burntShares;
    address internal incumbent;
    uint256 internal incumbentShares;

    function _campaignBlocked(bytes memory data_) internal virtual returns (bytes memory);
    function _campaignHookRates() internal pure virtual returns (uint16, uint16) { return (0, 0); }

    function _startCampaign(IStandardExchangeProxy vault_, IPoolManager manager_, PoolKey memory key_, uint256[2] memory units_) internal {
        campaignVault = vault_; campaignManager = manager_; campaignKey = key_; campaignUnits = units_;
        // Native settlement has its own suites; this conservation universe uses two ERC20 currencies.
        require(Currency.unwrap(key_.currency0) != address(0), "campaign requires ERC20 pool faces");
        campaignTokens = [IERC20(Currency.unwrap(key_.currency0)), IERC20(Currency.unwrap(key_.currency1))];
        for (uint256 i; i < 2; ++i) {
            campaignTokens[i].approve(address(vault_), type(uint256).max);
            conservedBalances[i] = _custodySum(i);
        }
        incumbent = makeAddr("passive campaign incumbent");
        incumbentShares = vault_.balanceOf(address(this)) / 10;
        assertGt(incumbentShares, 0);
        vault_.transfer(incumbent, incumbentShares);
        initialSupply = vault_.totalSupply(); initialShares = vault_.balanceOf(address(this));
        assertGt(initialShares, 0);
        _assertCampaignBook();
    }

    function _runCampaign(uint256 seed_) internal {
        uint256[8] memory attempts;
        uint256 offset = seed_ % 8;
        for (uint256 step; step < 32; ++step) {
            seed_ = uint256(keccak256(abi.encode(seed_, step)));
            // Every campaign visits every mode four times, with randomized directions and sizes.
            uint256 mode = (step + offset) % 8;
            uint256 leg = (seed_ >> 8) % 2;
            uint256 amount = campaignUnits[leg] * (1 + (seed_ >> 16) % 8);
            StepFrame memory frame;
            frame.beforeBook = _coreCampaignSnapshot();
            (frame.beforeGrowth[0], frame.beforeGrowth[1]) = StateLibrary.getFeeGrowthInside(
                campaignManager, campaignKey.toId(), frame.beforeBook.lower, frame.beforeBook.upper);
            frame.beforeCaller = [campaignTokens[0].balanceOf(address(this)), campaignTokens[1].balanceOf(address(this))];
            frame.hookBefore = _feeLedgers();
            vm.recordLogs();
            int256 shareChange = _campaignStep(mode, leg, amount);
            Vm.Log[] memory logs = vm.getRecordedLogs();
            if (shareChange > 0) issuedShares += uint256(shareChange);
            if (shareChange < 0) burntShares += uint256(-shareChange);
            assertEq(int256(campaignVault.totalSupply()) - int256(frame.beforeBook.supply), shareChange, "supply ledger");
            assertEq(int256(campaignVault.balanceOf(address(this))) - int256(frame.beforeBook.shares), shareChange, "no phantom owned shares");
            _assertIdleAttribution(mode, leg, amount, shareChange, frame, logs);
            _assertHookAccrual(logs, frame.hookBefore, mode == 6);
            _assertCampaignBook();
            ++attempts[mode];
        }
        // Modes 0-5 require positive execution; mode 6 permits the explicitly
        // unsupported EO domain, and mode 7 requires a false-credit rejection.
        for (uint256 i; i < 8; ++i) assertEq(attempts[i], 4, "mode omitted");
    }

    function _campaignStep(uint256 mode_, uint256 leg_, uint256 amount_) private returns (int256 shares_) {
        IERC20 input = campaignTokens[leg_];
        IERC20 output = campaignTokens[1 - leg_];
        uint256 balance = input.balanceOf(address(this));
        if (mode_ == 0 || mode_ == 1) {
            uint256 quote = campaignVault.previewExchangeIn(input, amount_, IERC20(address(campaignVault)));
            uint256 minted = mode_ == 0
                ? campaignVault.exchangeIn(input, amount_, IERC20(address(campaignVault)), quote, address(this), false, block.timestamp)
                : SY(address(campaignVault)).deposit(address(this), address(input), amount_, quote);
            assertEq(minted, quote); assertGt(minted, 0);
            assertEq(balance - input.balanceOf(address(this)), amount_);
            return int256(minted);
        }
        if (mode_ == 2) {
            BookSnapshot memory book = _coreCampaignSnapshot();
            uint256 expected = _blockedForward(book, leg_, amount_);
            uint256 minted = abi.decode(_campaignBlocked(abi.encodeCall(IStandardExchangeIn.exchangeIn,
                (input, amount_, IERC20(address(campaignVault)), expected, address(this), false, block.timestamp))), (uint256));
            assertEq(minted, expected); assertGt(minted, 0);
            assertEq(balance - input.balanceOf(address(this)), amount_);
            return int256(minted);
        }
        if (mode_ == 3) {
            BookSnapshot memory book = _coreCampaignSnapshot();
            uint256 requested = Math.max(book.shares / 100_000, 1);
            uint256 required = _blockedInverse(book, leg_, requested);
            assertGe(_blockedForward(book, leg_, required), requested);
            assertLt(_blockedForward(book, leg_, required - 1), requested);
            uint256 used = abi.decode(_campaignBlocked(abi.encodeCall(IStandardExchangeOut.exchangeOut,
                (input, required, IERC20(address(campaignVault)), requested, address(this), false, block.timestamp))), (uint256));
            assertEq(used, required);
            assertEq(balance - input.balanceOf(address(this)), required);
            return int256(requested);
        }
        if (mode_ == 4 || mode_ == 5) {
            uint256 burn = Math.max(campaignVault.balanceOf(address(this)) / 100_000, 1);
            uint256 quote = campaignVault.previewExchangeIn(IERC20(address(campaignVault)), burn, input);
            uint256 received = mode_ == 4
                ? campaignVault.exchangeIn(IERC20(address(campaignVault)), burn, input, quote, address(this), false, block.timestamp)
                : SY(address(campaignVault)).redeem(address(this), burn, address(input), quote, false);
            assertEq(received, quote); assertGt(received, 0);
            assertEq(input.balanceOf(address(this)) - balance, received);
            return -int256(burn);
        }
        if (mode_ == 6) {
            // The supported scalar EO domain is narrow. Its rejection must be atomic,
            // not a searched inverse or a zero quote. Dedicated suites prove EO successes.
            uint256 wanted = campaignUnits[1 - leg_];
            bytes32 beforeState = _campaignFingerprint();
            try campaignVault.previewExchangeOut(input, output, wanted) returns (uint256 quote) {
                uint256 beforeOutput = output.balanceOf(address(this));
                uint256 used = campaignVault.exchangeOut(input, quote, output, wanted, address(this), false, block.timestamp);
                assertEq(used, quote); assertGt(used, 0);
                assertEq(balance - input.balanceOf(address(this)), used);
                assertEq(output.balanceOf(address(this)) - beforeOutput, wanted);
            } catch (bytes memory error) {
                assertEq(error, abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(input), address(output)));
                (bool ok, bytes memory actual) = address(campaignVault).call(abi.encodeCall(IStandardExchangeOut.exchangeOut,
                    (input, type(uint256).max, output, wanted, address(this), false, block.timestamp)));
                assertFalse(ok); assertEq(actual, error); assertEq(_campaignFingerprint(), beforeState);
            }
            return 0;
        }
        bytes32 beforeState = _campaignFingerprint();
        (bool ok, bytes memory error) = address(campaignVault).call(abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (input, amount_, IERC20(address(campaignVault)), 0, address(this), true, block.timestamp)));
        assertFalse(ok);
        assertEq(error, abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, amount_, 0));
        assertEq(_campaignFingerprint(), beforeState, "false pretransfer changed state");
    }

    function _campaignSnapshot() private view returns (BookSnapshot memory book_) {
        (bytes memory data,) = Transition(address(campaignVault)).quoteState(address(campaignTokens[0]), address(this));
        return abi.decode(data, (BookSnapshot));
    }

    function _coreCampaignSnapshot() private view returns (BookSnapshot memory book_) {
        book_.supply = campaignVault.totalSupply(); book_.shares = campaignVault.balanceOf(address(this));
        book_.free0 = campaignTokens[0].balanceOf(address(campaignVault));
        book_.free1 = campaignTokens[1].balanceOf(address(campaignVault));
        book_.lower = TickMath.minUsableTick(campaignKey.tickSpacing);
        book_.upper = TickMath.maxUsableTick(campaignKey.tickSpacing);
        (book_.pool.sqrtPriceX96, book_.pool.tick,,) = StateLibrary.getSlot0(campaignManager, campaignKey.toId());
        book_.pool.liquidity = StateLibrary.getLiquidity(campaignManager, campaignKey.toId());
        uint256 last0; uint256 last1;
        (book_.positionLiquidity, last0, last1) = StateLibrary.getPositionInfo(campaignManager,
            campaignKey.toId(), address(campaignVault), book_.lower, book_.upper, bytes32(0));
        (uint256 growth0, uint256 growth1) = StateLibrary.getFeeGrowthInside(campaignManager, campaignKey.toId(), book_.lower, book_.upper);
        unchecked { growth0 -= last0; growth1 -= last1; }
        book_.fees0 = Math.mulDiv(growth0, book_.positionLiquidity, uint256(1) << 128);
        book_.fees1 = Math.mulDiv(growth1, book_.positionLiquidity, uint256(1) << 128);
    }

    function _principal(BookSnapshot memory book_) private pure returns (uint256[2] memory value_) {
        uint160 a = TickMath.getSqrtPriceAtTick(book_.lower);
        uint160 b = TickMath.getSqrtPriceAtTick(book_.upper);
        uint160 q = book_.pool.sqrtPriceX96;
        if (q < b) value_[0] = SqrtPriceMath.getAmount0Delta(q > a ? q : a, b, book_.positionLiquidity, false);
        if (q > a) value_[1] = SqrtPriceMath.getAmount1Delta(a, q < b ? q : b, book_.positionLiquidity, false);
    }

    function _backing(BookSnapshot memory book_) private pure returns (uint256[2] memory value_) {
        value_ = _principal(book_);
        value_[0] += book_.free0 + book_.fees0; value_[1] += book_.free1 + book_.fees1;
    }

    function _blockedForward(BookSnapshot memory book_, uint256 leg_, uint256 amount_) private pure returns (uint256) {
        uint256[2] memory b = _backing(book_);
        uint256 product = b[leg_] * b[1 - leg_];
        uint256 k = Math.sqrt(product);
        if (k * k < product) ++k;
        uint256 next = Math.sqrt((b[leg_] + amount_) * b[1 - leg_]);
        return next > k ? Math.mulDiv(book_.supply, next - k, k) : 0;
    }

    function _blockedInverse(BookSnapshot memory book_, uint256 leg_, uint256 shares_) private pure returns (uint256) {
        uint256[2] memory b = _backing(book_);
        uint256 product = b[0] * b[1];
        uint256 k = Math.sqrt(product);
        if (k * k < product) ++k;
        uint256 next = k + Math.mulDiv(shares_, k, book_.supply, Math.Rounding.Ceil);
        return Math.mulDiv(next, next, b[1 - leg_], Math.Rounding.Ceil) - b[leg_];
    }

    function _assertCampaignBook() internal view {
        BookSnapshot memory book = _campaignSnapshot();
        assertEq(campaignVault.totalSupply(), initialSupply + issuedShares - burntShares);
        assertEq(campaignVault.balanceOf(address(this)), initialShares + issuedShares - burntShares);
        assertEq(campaignVault.balanceOf(incumbent), incumbentShares);
        BookSnapshot memory core = _coreCampaignSnapshot();
        assertEq(book.pool.sqrtPriceX96, core.pool.sqrtPriceX96); assertEq(book.pool.tick, core.pool.tick);
        assertEq(book.pool.liquidity, core.pool.liquidity);
        assertEq(book.lower, core.lower); assertEq(book.upper, core.upper);
        assertEq(book.supply, campaignVault.totalSupply()); assertEq(book.shares, campaignVault.balanceOf(address(this)));
        assertEq(book.free0, campaignTokens[0].balanceOf(address(campaignVault)));
        assertEq(book.free1, campaignTokens[1].balanceOf(address(campaignVault)));
        for (uint256 i; i < 2; ++i) {
            assertEq(_custodySum(i), conservedBalances[i], "global token conservation");
            assertEq(campaignVault.reserveOfToken(address(campaignTokens[i])), campaignTokens[i].balanceOf(address(campaignVault)));
        }
        assertEq(campaignVault.reserveOfToken(address(campaignVault)), 0); assertEq(campaignVault.balanceOf(address(campaignVault)), 0);
        assertEq(address(campaignVault).balance, 0);
        (uint128 liquidity, uint256 last0, uint256 last1) = StateLibrary.getPositionInfo(
            campaignManager, campaignKey.toId(), address(campaignVault), book.lower, book.upper, bytes32(0));
        assertEq(book.positionLiquidity, liquidity);
        (uint256 growth0, uint256 growth1) = StateLibrary.getFeeGrowthInside(campaignManager, campaignKey.toId(), book.lower, book.upper);
        unchecked { growth0 -= last0; growth1 -= last1; }
        assertEq(book.fees0, Math.mulDiv(growth0, liquidity, uint256(1) << 128));
        assertEq(book.fees1, Math.mulDiv(growth1, liquidity, uint256(1) << 128));
        uint256[2] memory principal = _principal(book);
        (uint256 deployed0, uint256 deployed1) = IFullSpreadCampaignReserve(address(campaignVault)).deployedReserve();
        assertEq(principal[0], deployed0); assertEq(principal[1], deployed1);
    }

    function _custodySum(uint256 leg_) private view returns (uint256 value_) {
        IERC20 token = campaignTokens[leg_];
        value_ = token.balanceOf(address(this)) + token.balanceOf(address(campaignVault)) + token.balanceOf(address(campaignManager));
        if (address(campaignKey.hooks) != address(0)) value_ += token.balanceOf(address(campaignKey.hooks));
    }

    function _pending(uint256 leg_) private view returns (uint256) {
        if (address(campaignKey.hooks) == address(0)) return 0;
        IFullSpreadCampaignFeeLedger hook = IFullSpreadCampaignFeeLedger(address(campaignKey.hooks));
        return hook.pendingFees(campaignKey.toId(), address(campaignTokens[leg_]))
            + hook.pendingCreatorTax(campaignKey.toId(), address(campaignTokens[leg_]));
    }

    function _feeLedgers() private view returns (uint256[4] memory result_) {
        if (address(campaignKey.hooks) == address(0)) return result_;
        IFullSpreadCampaignFeeLedger hook = IFullSpreadCampaignFeeLedger(address(campaignKey.hooks));
        for (uint256 i; i < 2; ++i) {
            result_[2 * i] = hook.pendingFees(campaignKey.toId(), address(campaignTokens[i]));
            result_[2 * i + 1] = hook.pendingCreatorTax(campaignKey.toId(), address(campaignTokens[i]));
        }
    }

    function _assertHookAccrual(Vm.Log[] memory logs_, uint256[4] memory before_, bool exactOutput_) private view {
        if (address(campaignKey.hooks) == address(0)) return;
        (uint16 fee, uint16 tax) = _campaignHookRates();
        uint256[4] memory charged;
        for (uint256 i; i < logs_.length; ++i) {
            if (logs_[i].emitter != address(campaignManager) || logs_[i].topics.length != 3
                || logs_[i].topics[0] != IPoolManager.Swap.selector || logs_[i].topics[1] != PoolId.unwrap(campaignKey.toId())) continue;
            (int128 d0, int128 d1,,,,) = abi.decode(logs_[i].data, (int128, int128, uint160, uint128, int24, uint24));
            uint256 leg = exactOutput_ ? (d0 < 0 ? 0 : 1) : (d0 > 0 ? 0 : 1);
            int256 delta = leg == 0 ? int256(d0) : int256(d1);
            uint256 amount = uint256(delta < 0 ? -delta : delta);
            charged[2 * leg] += amount * fee / 10_000;
            charged[2 * leg + 1] += amount * tax / 10_000;
        }
        uint256[4] memory afterLedgers = _feeLedgers();
        for (uint256 i; i < 4; ++i) assertEq(afterLedgers[i] - before_[i], charged[i], "separate fee/tax attribution");
    }

    function _observedSwaps(Vm.Log[] memory logs_) private view returns (ObservedSwap[] memory swaps_, uint256 count_) {
        swaps_ = new ObservedSwap[](logs_.length);
        for (uint256 i; i < logs_.length; ++i) {
            if (logs_[i].emitter != address(campaignManager) || logs_[i].topics.length != 3
                || logs_[i].topics[0] != IPoolManager.Swap.selector || logs_[i].topics[1] != PoolId.unwrap(campaignKey.toId())) continue;
            assertEq(logs_[i].topics[2], bytes32(uint256(uint160(address(campaignVault)))));
            (int128 d0, int128 d1,,,,) = abi.decode(logs_[i].data, (int128, int128, uint160, uint128, int24, uint24));
            bool input0 = d0 < 0;
            swaps_[count_++] = ObservedSwap(input0 ? 0 : 1, uint256(-int256(input0 ? d0 : d1)), uint256(int256(input0 ? d1 : d0)));
        }
    }

    function _netCoreOutput(uint256 output_) private view returns (uint256) {
        if (address(campaignKey.hooks) == address(0)) return output_;
        (uint16 fee, uint16 tax) = _campaignHookRates();
        return output_ - output_ * fee / 10_000 - output_ * tax / 10_000;
    }

    function _assertIdleAttribution(uint256 mode_, uint256 leg_, uint256 amount_, int256 shares_,
        StepFrame memory frame_, Vm.Log[] memory logs_) private view
    {
        (ObservedSwap[] memory swaps, uint256 count) = _observedSwaps(logs_);
        if (mode_ <= 1) {
            assertLe(count, 1, "composition is one caller-funded swap");
            uint256[2] memory contribution;
            contribution[leg_] = amount_;
            if (count != 0) {
                assertEq(swaps[0].inputLeg, leg_);
                contribution[leg_] -= swaps[0].input;
                contribution[1 - leg_] = _netCoreOutput(swaps[0].output);
            }
            _assertMintAttribution(frame_, contribution, uint256(shares_));
        } else if (mode_ == 4 || mode_ == 5) {
            _assertExitAttribution(frame_, swaps, count, leg_, uint256(-shares_));
        } else if (mode_ == 6 && count != 0) {
            assertEq(count, 1, "closed EO has no numerical repair trade");
            assertEq(swaps[0].inputLeg, leg_);
            uint256 debt = swaps[0].input;
            if (address(campaignKey.hooks) != address(0)) {
                (uint16 fee, uint16 tax) = _campaignHookRates();
                debt += swaps[0].input * fee / 10_000 + swaps[0].input * tax / 10_000;
            }
            assertEq(frame_.beforeCaller[leg_] - campaignTokens[leg_].balanceOf(address(this)), debt);
            assertEq(campaignTokens[1 - leg_].balanceOf(address(this)) - frame_.beforeCaller[1 - leg_], swaps[0].output);
        }
    }

    function _assertMintAttribution(StepFrame memory frame_, uint256[2] memory contribution_, uint256 minted_) private view {
        MintReference memory ref;
        ref.finalBook = _coreCampaignSnapshot();
        ref.original = frame_.beforeBook;
        ref.original.pool.sqrtPriceX96 = ref.finalBook.pool.sqrtPriceX96;
        ref.repriced = _principal(ref.original);
        ref.finalPrincipal = _principal(ref.finalBook);
        (uint256 g0, uint256 g1) = StateLibrary.getFeeGrowthInside(campaignManager, campaignKey.toId(), ref.original.lower, ref.original.upper);
        unchecked { g0 -= frame_.beforeGrowth[0]; g1 -= frame_.beforeGrowth[1]; }
        ref.cash = [ref.original.free0 + ref.original.fees0 + Math.mulDiv(g0, ref.original.positionLiquidity, uint256(1) << 128),
            ref.original.free1 + ref.original.fees1 + Math.mulDiv(g1, ref.original.positionLiquidity, uint256(1) << 128)];
        ref.addition = ref.finalBook.positionLiquidity >= ref.original.positionLiquidity;
        uint128 change = ref.addition ? ref.finalBook.positionLiquidity - ref.original.positionLiquidity : ref.original.positionLiquidity - ref.finalBook.positionLiquidity;
        ref.settlement = _liquiditySettlement(ref.finalBook, change, ref.addition);
        ref.expected = type(uint256).max;
        for (uint256 i; i < 2; ++i) {
            uint256 backing = ref.cash[i] + ref.repriced[i];
            uint256 free = ref.cash[i] + contribution_[i];
            uint256 loss;
            if (ref.addition) {
                free -= ref.settlement[i];
                loss = ref.settlement[i] - (ref.finalPrincipal[i] - ref.repriced[i]);
                contribution_[i] -= loss;
            } else {
                free += ref.settlement[i];
                loss = ref.repriced[i] - ref.finalPrincipal[i] - ref.settlement[i];
                backing -= loss;
            }
            assertEq(free, campaignTokens[i].balanceOf(address(campaignVault)), "actual caller/holder cash attribution");
            ref.expected = Math.min(ref.expected, Math.mulDiv(ref.original.supply, contribution_[i], backing));
            assertGe(10_000 * minted_ * backing, 9_999 * ref.original.supply * contribution_[i], "independent alignment");
        }
        assertEq(minted_, ref.expected, "independent post-swap proportional issuance");
    }

    function _liquiditySettlement(BookSnapshot memory book_, uint128 liquidity_, bool roundUp_) private pure returns (uint256[2] memory result_) {
        uint160 a = TickMath.getSqrtPriceAtTick(book_.lower);
        uint160 b = TickMath.getSqrtPriceAtTick(book_.upper);
        uint160 q = book_.pool.sqrtPriceX96;
        if (q < b) result_[0] = SqrtPriceMath.getAmount0Delta(q > a ? q : a, b, liquidity_, roundUp_);
        if (q > a) result_[1] = SqrtPriceMath.getAmount1Delta(a, q < b ? q : b, liquidity_, roundUp_);
    }

    function _assertExitAttribution(StepFrame memory frame_, ObservedSwap[] memory swaps_, uint256 count_, uint256 leg_, uint256 burn_) private view {
        BookSnapshot memory book = frame_.beforeBook;
        uint128 removed = uint128(Math.mulDiv(book.positionLiquidity, burn_, book.supply));
        uint256[2] memory entitled = _liquiditySettlement(book, removed, false);
        entitled[0] += Math.mulDiv(book.free0 + book.fees0, burn_, book.supply);
        entitled[1] += Math.mulDiv(book.free1 + book.fees1, burn_, book.supply);
        uint256 expected = entitled[leg_];
        if (entitled[1 - leg_] != 0) {
            assertGt(count_, 0); assertEq(swaps_[0].inputLeg, 1 - leg_);
            assertEq(swaps_[0].input, entitled[1 - leg_], "only caller opposing entitlement converted");
            expected += _netCoreOutput(swaps_[0].output);
        }
        assertEq(campaignTokens[leg_].balanceOf(address(this)) - frame_.beforeCaller[leg_], expected,
            "remaining-holder repair/fees cannot augment caller payout");
    }

    function _campaignFingerprint() private view returns (bytes32) {
        return keccak256(abi.encode(_campaignSnapshot(),
            campaignTokens[0].balanceOf(address(this)), campaignTokens[1].balanceOf(address(this)),
            _custodySum(0), _custodySum(1), _pending(0), _pending(1)));
    }
}
// end::TestBase_UniswapV4FullSpreadCrossModeCampaign[]
