// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IUniswapV4SinglePositionAware} from "@crane/contracts/interfaces/IUniswapV4SinglePositionAware.sol";
import {UniswapV4FullSpreadStandardExchangeVaultRepo as Repo} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultRepo.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {IUniswapV4FullSpreadStandardExchangeVaultDFPkg as IPackage} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol";
import {IFullSpreadVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol";
import {Vm} from "forge-std/Vm.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {UniswapV4FullSpreadStandardExchangeVaultMath as VaultMath} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMath.sol";
import {IUniswapV4FullSpreadStandardExchangeVault as IVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {TestBase_UniswapV4FullSpreadStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol";

interface IFullSpreadUnlocked {
    function exchangeIn(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256 amountRefunded);

    function exchangeBundleInForSingleOut(
        uint256[] calldata amountsIn,
        address tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256[] memory amountsRefunded);

    function balanceOf(address account) external view returns (uint256);
}

/// @notice Non-SUT ERC20 that makes a real foreign sync call during its own transfer.
contract SettlementClobberToken is MintableERC20Decimals {
    address internal target;
    IPoolManager internal manager;
    Currency internal other;

    constructor() MintableERC20Decimals("Sync clobber", "SYNC", 18) {}

    function arm(address target_, IPoolManager manager_, Currency other_) external {
        target = target_;
        manager = manager_;
        other = other_;
    }

    function transfer(address to_, uint256 amount_) external override returns (bool) {
        _transfer(msg.sender, to_, amount_);
        if (msg.sender == target && to_ == address(manager)) manager.sync(other);
        return true;
    }
}

contract UnlockedExchangeCaller is IUnlockCallback {
    struct Context {
        Currency currency;
        uint256 amount;
        bool ownCredit;
        bool catchFailure;
        bool failOuter;
        uint256 value;
    }

    int256 public foreignDeltaAfter;
    int256 public vaultDeltaAfter;
    int256 public vaultDelta0After;
    int256 public vaultDelta1After;
    uint256 public callerBalance1After;
    uint256 public allowance0After;
    uint256 public allowance1After;
    uint256 public nonzeroAfter;
    bool public unlockedAfter;
    bool public succeeded;
    bytes public result;

    /// @notice Execute the same calldata without opening an outer unlock.
    function runLocked(address vault_, bytes memory data_) external returns (bytes memory) {
        return _call(vault_, data_);
    }

    function run(IPoolManager manager_, address vault_, bytes memory data_) external returns (bytes memory) {
        Context memory context_;
        return manager_.unlock(abi.encode(vault_, data_, context_));
    }

    /// @notice Leave a real outer debt or create a real vault credit before dispatch.
    function runContext(IPoolManager manager_, address vault_, bytes memory data_, Context memory context_)
        external returns (bytes memory)
    {
        return manager_.unlock(abi.encode(vault_, data_, context_));
    }

    function unlockCallback(bytes calldata data_) external override returns (bytes memory) {
        (address vault_, bytes memory call_, Context memory context_) = abi.decode(data_, (address, bytes, Context));
        IPoolManager manager_ = IPoolManager(msg.sender);
        IERC20 token_ = IERC20(Currency.unwrap(context_.currency));
        if (context_.amount != 0) {
            if (context_.ownCredit) {
                manager_.sync(context_.currency);
                token_.transfer(address(manager_), context_.amount);
                manager_.settleFor(vault_);
                require(TransientStateLibrary.currencyDelta(manager_, vault_, context_.currency) == int256(context_.amount),
                    "real own credit before vault dispatch");
            } else {
                manager_.take(context_.currency, address(this), context_.amount);
            }
        }
        bytes memory ret_;
        if (context_.catchFailure) {
            (succeeded, ret_) = vault_.call{value: context_.value}(call_);
            result = ret_;
        } else {
            ret_ = _call(vault_, call_);
        }
        vaultDelta0After = TransientStateLibrary.currencyDelta(
            manager_, vault_, IUniswapV4SinglePositionAware(vault_).poolKey().currency0
        );
        vaultDelta1After = TransientStateLibrary.currencyDelta(
            manager_, vault_, IUniswapV4SinglePositionAware(vault_).poolKey().currency1
        );
        address[] memory faces_ = IFullSpreadVault(vault_).vaultTokens();
        callerBalance1After = IERC20(faces_[1]).balanceOf(address(this));
        allowance0After = IERC20(faces_[0]).allowance(address(this), vault_);
        allowance1After = IERC20(faces_[1]).allowance(address(this), vault_);
        foreignDeltaAfter = TransientStateLibrary.currencyDelta(manager_, address(this), context_.currency);
        vaultDeltaAfter = TransientStateLibrary.currencyDelta(manager_, vault_, context_.currency);
        nonzeroAfter = TransientStateLibrary.getNonzeroDeltaCount(manager_);
        unlockedAfter = TransientStateLibrary.isUnlocked(manager_);
        if (context_.failOuter) revert("outer failure");
        if (context_.amount != 0 && !context_.ownCredit) {
            manager_.sync(context_.currency);
            token_.transfer(address(manager_), context_.amount);
            require(manager_.settle() == context_.amount, "outer settlement");
        }
        return ret_;
    }

    function _call(address vault_, bytes memory call_) private returns (bytes memory) {
        (bool ok_, bytes memory ret_) = vault_.call(call_);
        if (!ok_) {
            assembly {
                revert(add(ret_, 32), mload(ret_))
            }
        }
        return ret_;
    }
}

contract UniswapV4FullSpreadStandardExchangeVault_AlreadyUnlocked_Test is TestBase_UniswapV4FullSpreadStandardExchangeVault {
    using TransientStateLibrary for IPoolManager;

    IFullSpreadUnlocked internal money;
    UnlockedExchangeCaller internal caller;

    function setUp() public override {
        super.setUp();
        money = IFullSpreadUnlocked(address(vault));
        caller = new UnlockedExchangeCaller();
        _fund(address(this), 2_000_000 ether, 2_000_000 ether);
        _approve(address(vault));
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 100_000 ether;
        amounts_[1] = 100_000 ether;
        money.exchangeBundleInForSingleOut(amounts_, address(vault), 0, address(this), false, block.timestamp);
        token0.mint(address(caller), 10_000 ether);
        vm.prank(address(caller));
        IERC20(address(token0)).approve(address(vault), type(uint256).max);
        token1.mint(address(caller), 10_000 ether);
        vm.prank(address(caller));
        IERC20(address(token1)).approve(address(vault), type(uint256).max);
    }

    function test_borrowedExchangeInMintsAndClearsDeltas() public {
        vm.expectCall(address(pool), abi.encodeWithSelector(IPoolManager.unlock.selector), uint64(1));
        vm.expectCall(address(vault), abi.encodeWithSelector(IUnlockCallback.unlockCallback.selector), uint64(0));
        bytes memory call_ = abi.encodeWithSelector(
            IFullSpreadUnlocked.exchangeIn.selector,
            address(token0),
            100 ether,
            address(vault),
            0,
            address(caller),
            false,
            block.timestamp
        );
        bytes memory ret_ = caller.run(pool, address(vault), call_);
        (uint256 shares_,) = abi.decode(ret_, (uint256, uint256));
        assertGt(shares_, 0);
        assertEq(money.balanceOf(address(caller)), shares_);
        _assertInnerDeltas();
        assertEq(pool.currencyDelta(address(vault), Currency.wrap(address(token0))), 0);
        assertEq(pool.currencyDelta(address(vault), Currency.wrap(address(token1))), 0);
    }

    /// @notice M20: an outer debt is not a vault debt and may remain at the inner return.
    function test_borrowedExchangeLeavesForeignDebtOpen() public {
        UnlockedExchangeCaller.Context memory context_;
        context_.currency = key.currency1;
        context_.amount = 3 ether;
        bytes memory ret_ = caller.runContext(pool, address(vault), _mintCall(false, 0), context_);
        (uint256 shares_,) = abi.decode(ret_, (uint256, uint256));
        assertGt(shares_, 0);
        assertEq(caller.foreignDeltaAfter(), -int256(context_.amount), "outer debt remains");
        assertEq(caller.vaultDeltaAfter(), 0, "vault closes its own delta");
        assertEq(caller.nonzeroAfter(), 1, "global delta count need not be zero");
        assertTrue(caller.unlockedAfter(), "inner call does not relock");
        _assertInnerDeltas();
        assertEq(pool.currencyDelta(address(vault), key.currency0), 0);
        assertEq(pool.currencyDelta(address(vault), key.currency1), 0);
    }

    /// @notice M20: a real settleFor credit exercises the bare own-delta entry reject.
    function test_borrowedNonzeroOwnDeltaBareReverts() public {
        bytes32 before_ = _vaultState();
        uint256[2] memory balances_ = [token0.balanceOf(address(caller)), token1.balanceOf(address(caller))];
        uint256[2] memory allowances_ = [token0.allowance(address(caller), address(vault)),
            token1.allowance(address(caller), address(vault))];
        for (uint256 i; i < 2; ++i) {
            for (uint256 j; j < 2; ++j) {
                UnlockedExchangeCaller.Context memory context_;
                context_.currency = i == 0 ? key.currency0 : key.currency1;
                context_.amount = j == 0 ? 1 : 1 ether;
                context_.ownCredit = true;
                vm.expectRevert(bytes(""));
                caller.runContext(pool, address(vault), _mintCall(false, 0), context_);
                assertEq(_vaultState(), before_, "own-credit rejection restores vault and pool state");
                assertEq(token0.balanceOf(address(caller)), balances_[0]);
                assertEq(token1.balanceOf(address(caller)), balances_[1]);
                assertEq(token0.allowance(address(caller), address(vault)), allowances_[0]);
                assertEq(token1.allowance(address(caller), address(vault)), allowances_[1]);
                assertEq(pool.currencyDelta(address(vault), key.currency0), 0);
                assertEq(pool.currencyDelta(address(vault), key.currency1), 0);
            }
        }
    }

    /// @notice M20: a caught failure restores the vault, but does not settle the outer debt.
    function test_caughtBorrowedMinimumFailureRestoresVault() public {
        UnlockedExchangeCaller.Context memory context_;
        context_.currency = key.currency1;
        context_.amount = 3 ether;
        context_.catchFailure = true;
        vm.prank(address(caller));
        token0.approve(address(vault), 200 ether);
        uint256 supply_ = vault.totalSupply();
        uint128 liquidity_ = vault.positionLiquidity();
        uint256 caller0_ = token0.balanceOf(address(caller));
        uint256 caller1_ = token1.balanceOf(address(caller));
        uint256 allowance0_ = token0.allowance(address(caller), address(vault));
        uint256 allowance1_ = token1.allowance(address(caller), address(vault));
        bytes32 state_ = _vaultState();
        uint256 vault0_ = token0.balanceOf(address(vault));
        uint256 vault1_ = token1.balanceOf(address(vault));
        caller.runContext(pool, address(vault), _mintCall(false, type(uint256).max), context_);
        assertFalse(caller.succeeded());
        bytes memory reason_ = caller.result();
        assertEq(bytes4(reason_), IStandardExchangeErrors.AmountOutNotMet.selector);
        assertEq(caller.foreignDeltaAfter(), -int256(context_.amount));
        assertTrue(caller.unlockedAfter());
        _assertInnerDeltas();
        assertEq(caller.nonzeroAfter(), 1);
        assertEq(caller.callerBalance1After(), caller1_ + context_.amount, "only outer take remains at inner return");
        assertEq(caller.allowance0After(), allowance0_);
        assertEq(caller.allowance1After(), allowance1_);
        assertEq(token1.balanceOf(address(caller)), caller1_, "outer debt repaid exactly");
        assertEq(_vaultState(), state_, "caught failure restores books, manager and position");
        assertEq(vault.totalSupply(), supply_);
        assertEq(vault.positionLiquidity(), liquidity_);
        assertEq(money.balanceOf(address(caller)), 0);
        assertEq(token0.balanceOf(address(caller)), caller0_);
        assertEq(token0.balanceOf(address(vault)), vault0_);
        assertEq(token1.balanceOf(address(vault)), vault1_);
    }

    /// @notice M20: a later outer revert undoes the successful borrowed deposit and swap.
    function test_outerFailureRestoresBorrowedSwap() public {
        UnlockedExchangeCaller.Context memory context_;
        context_.failOuter = true;
        vm.prank(address(caller));
        token0.approve(address(vault), 200 ether);
        uint256 supply_ = vault.totalSupply();
        uint128 liquidity_ = vault.positionLiquidity();
        uint256 caller0_ = token0.balanceOf(address(caller));
        uint256 pool0_ = token0.balanceOf(address(pool));
        uint256 pool1_ = token1.balanceOf(address(pool));
        bytes32 state_ = _vaultState();
        uint256 caller1_ = token1.balanceOf(address(caller));
        uint256 allowance_ = token0.allowance(address(caller), address(vault));
        vm.expectRevert(bytes("outer failure"));
        caller.runContext(pool, address(vault), _mintCall(false, 0), context_);
        assertEq(vault.totalSupply(), supply_);
        assertEq(vault.positionLiquidity(), liquidity_);
        assertEq(money.balanceOf(address(caller)), 0);
        assertEq(token0.balanceOf(address(caller)), caller0_);
        assertEq(token0.balanceOf(address(pool)), pool0_);
        assertEq(token1.balanceOf(address(pool)), pool1_);
        assertEq(token1.balanceOf(address(caller)), caller1_);
        assertEq(token0.allowance(address(caller), address(vault)), allowance_);
        assertEq(_vaultState(), state_, "outer revert restores local books and pool state");
    }

    /// @notice M20: the locked and borrowed exits pay the same receipt from the same state.
    function test_borrowedExitToken0ReceiptMatchesLockedFromSameState() public {
        _assertExitReceipt(true);
    }

    function test_borrowedExitToken1ReceiptMatchesLockedFromSameState() public {
        _assertExitReceipt(false);
    }

    function _assertExitReceipt(bool token0Out_) internal {
        // Collect trading fees into booked balances through a real add, then accrue more unpaid fees.
        money.exchangeIn(address(token0), 100 ether, address(token1), 0, address(this), false, block.timestamp);
        money.exchangeIn(address(token1), 100 ether, address(token0), 0, address(this), false, block.timestamp);
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 100 ether;
        amounts_[1] = 100 ether;
        money.exchangeBundleInForSingleOut(amounts_, address(vault), 0, address(this), false, block.timestamp);
        money.exchangeIn(address(token0), 100 ether, address(token1), 0, address(this), false, block.timestamp);
        money.exchangeIn(address(token1), 100 ether, address(token0), 0, address(this), false, block.timestamp);
        IERC20 wanted_ = IERC20(token0Out_ ? address(token0) : address(token1));
        assertGt(wanted_.balanceOf(address(vault)), 0, "collected requested fees remain booked");
        IERC20(address(vault)).transfer(address(caller), 1_000 ether);
        (uint256 principal_, uint256 fee_, uint256 booked_) = _requestedClaims(token0Out_);
        assertGt(principal_, 0);
        assertGt(fee_, 0, "requested unpaid fee claim is nonzero");
        assertGt(booked_, 0, "requested booked claim is nonzero");
        bytes memory call_ = abi.encodeWithSelector(
            IFullSpreadUnlocked.exchangeIn.selector,
            address(vault), 100 ether, address(wanted_), 0, address(caller), false, block.timestamp
        );
        uint256 snapshot_ = vm.snapshotState();
        uint256 before_ = wanted_.balanceOf(address(caller));
        (uint256 locked_, uint256 lockedRefund_) = abi.decode(caller.runLocked(address(vault), call_), (uint256, uint256));
        assertEq(wanted_.balanceOf(address(caller)) - before_, locked_, "locked recipient receipt");
        uint128 liquidity_ = vault.positionLiquidity();
        uint256 supply_ = vault.totalSupply();
        assertTrue(vm.revertToState(snapshot_));
        uint256 preSupply_ = vault.totalSupply();
        uint128 preLiquidity_ = vault.positionLiquidity();
        uint256 preShares_ = vault.balanceOf(address(caller));
        uint256 vault0_ = token0.balanceOf(address(vault));
        uint256 vault1_ = token1.balanceOf(address(vault));
        bytes memory minimumCall_ = abi.encodeWithSelector(
            IFullSpreadUnlocked.exchangeIn.selector,
            address(vault), 100 ether, address(wanted_), locked_ + 1, address(caller), false, block.timestamp
        );
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector, locked_ + 1, locked_));
        caller.run(pool, address(vault), minimumCall_);
        assertEq(vault.totalSupply(), preSupply_, "minimum miss burns no shares");
        assertEq(vault.balanceOf(address(caller)), preShares_);
        assertEq(vault.positionLiquidity(), preLiquidity_);
        assertEq(wanted_.balanceOf(address(caller)), before_);
        assertEq(token0.balanceOf(address(vault)), vault0_);
        assertEq(token1.balanceOf(address(vault)), vault1_);
        vm.expectCall(address(pool), abi.encodeWithSelector(IPoolManager.unlock.selector), uint64(1));
        vm.expectCall(address(vault), abi.encodeWithSelector(IUnlockCallback.unlockCallback.selector), uint64(0));
        vm.recordLogs();
        (uint256 borrowed_, uint256 refund_) = abi.decode(caller.run(pool, address(vault), call_), (uint256, uint256));
        uint256 swapReceipt_ = _executedSwapReceipt(token0Out_);
        assertGt(swapReceipt_, 0);
        assertEq(borrowed_, swapReceipt_ + principal_ + fee_ + booked_, "executed four-part receipt");
        assertEq(borrowed_, locked_, "same four-part receipt");
        assertEq(refund_, lockedRefund_);
        assertEq(wanted_.balanceOf(address(caller)) - before_, borrowed_, "borrowed recipient receipt");
        assertEq(vault.positionLiquidity(), liquidity_);
        assertEq(vault.totalSupply(), supply_);
        _assertInnerDeltas();
        assertEq(pool.currencyDelta(address(vault), key.currency0), 0);
        assertEq(pool.currencyDelta(address(vault), key.currency1), 0);
    }

    function _requestedClaims(bool token0Out_) internal view
        returns (uint256 principal_, uint256 fee_, uint256 booked_)
    {
        int24 lower_ = TickMath.minUsableTick(key.tickSpacing);
        int24 upper_ = TickMath.maxUsableTick(key.tickSpacing);
        (uint128 liquidity_, uint256 last0_, uint256 last1_) = StateLibrary.getPositionInfo(
            pool, key.toId(), address(vault), lower_, upper_, bytes32(0)
        );
        assertEq(liquidity_, vault.positionLiquidity(), "diamond owns full-range salt-zero position");
        (uint160 price_,,,) = StateLibrary.getSlot0(pool, key.toId());
        uint256 supply_ = vault.totalSupply();
        uint128 removed_ = uint128(FullMath.mulDiv(liquidity_, 100 ether, supply_));
        (uint256 principal0_, uint256 principal1_) = VaultMath.amountsForLiquidity(
            price_, TickMath.getSqrtPriceAtTick(lower_), TickMath.getSqrtPriceAtTick(upper_), removed_
        );
        principal_ = token0Out_ ? principal0_ : principal1_;
        (uint256 inside0_, uint256 inside1_) = StateLibrary.getFeeGrowthInside(pool, key.toId(), lower_, upper_);
        uint256 unpaid_ = FullMath.mulDiv(
            liquidity_, token0Out_ ? inside0_ - last0_ : inside1_ - last1_, uint256(1) << 128
        );
        fee_ = FullMath.mulDiv(unpaid_, 100 ether, supply_);
        // The real bundle add collected the prior fees; no direct transfer or maintenance added unbooked custody.
        uint256 held_ = IERC20(token0Out_ ? address(token0) : address(token1)).balanceOf(address(vault));
        booked_ = FullMath.mulDiv(held_, 100 ether, supply_);
    }

    function _executedSwapReceipt(bool token0Out_) internal returns (uint256 receipt_) {
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        uint256 swaps_;
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].emitter != address(pool) || logs_[i_].topics.length != 3
                || logs_[i_].topics[0] != keccak256("Swap(bytes32,address,int128,int128,uint160,uint128,int24,uint24)")
                || logs_[i_].topics[2] != bytes32(uint256(uint160(address(vault))))) continue;
            (int128 amount0_, int128 amount1_,,,,) =
                abi.decode(logs_[i_].data, (int128, int128, uint160, uint128, int24, uint24));
            int128 received_ = token0Out_ ? amount0_ : amount1_;
            assertGt(int256(received_), 0, "executed requested-token credit");
            receipt_ += uint256(int256(received_));
            ++swaps_;
        }
        assertEq(swaps_, 1, "one executed opposing-claim swap");
    }

    /// @notice M20: both pass-through directions pay the same actual receipt on either dispatch path.
    function test_borrowedPassThroughBothDirectionsMatchesLockedReceipt() public {
        _assertPassThrough(address(token0), address(token1));
        _assertPassThrough(address(token1), address(token0));
    }

    function _assertPassThrough(address in_, address out_) internal {
        bytes memory call_ = abi.encodeWithSelector(
            IFullSpreadUnlocked.exchangeIn.selector,
            in_, 100 ether, out_, 0, address(caller), false, block.timestamp
        );
        uint256 snapshot_ = vm.snapshotState();
        uint256 before_ = IERC20(out_).balanceOf(address(caller));
        (uint256 locked_, uint256 lockedRefund_) = abi.decode(caller.runLocked(address(vault), call_), (uint256, uint256));
        assertTrue(vm.revertToState(snapshot_));
        uint256 supply_ = vault.totalSupply();
        uint128 liquidity_ = vault.positionLiquidity();
        (uint256 borrowed_, uint256 refund_) = abi.decode(caller.run(pool, address(vault), call_), (uint256, uint256));
        assertEq(borrowed_, locked_);
        assertEq(refund_, lockedRefund_);
        assertEq(IERC20(out_).balanceOf(address(caller)) - before_, borrowed_);
        assertEq(vault.totalSupply(), supply_, "pass-through never mints or burns");
        assertEq(vault.positionLiquidity(), liquidity_);
        assertEq(pool.currencyDelta(address(vault), key.currency0), 0);
        assertEq(pool.currencyDelta(address(vault), key.currency1), 0);
    }

    /// @notice M20: if a real token call clobbers sync, an unclosed action fails SettlementMismatch.
    function test_borrowedSettlementMismatchRestoresAllVaultEffects() public {
        SettlementClobberToken probe_ = new SettlementClobberToken();
        address other_ = address(token1);
        key.currency0 = Currency.wrap(address(probe_) < other_ ? address(probe_) : other_);
        key.currency1 = Currency.wrap(address(probe_) < other_ ? other_ : address(probe_));
        pool.initialize(key, uint160(1) << 96);
        IFullSpreadVault fresh_ = IFullSpreadVault(package.deployVault(IPackage.PkgArgs(key)));
        probe_.mint(address(this), 100_000 ether);
        token1.mint(address(this), 100_000 ether);
        probe_.approve(address(fresh_), type(uint256).max);
        token1.approve(address(fresh_), type(uint256).max);
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 100_000 ether;
        amounts_[1] = 100_000 ether;
        fresh_.exchangeBundleInForSingleOut(amounts_, address(fresh_), 0, address(this), false, block.timestamp);
        probe_.mint(address(caller), 100 ether);
        vm.prank(address(caller));
        probe_.approve(address(fresh_), type(uint256).max);
        probe_.arm(address(fresh_), pool, Currency.wrap(other_));
        uint256 supply_ = fresh_.totalSupply();
        uint128 liquidity_ = fresh_.positionLiquidity();
        uint256 poolProbe_ = probe_.balanceOf(address(pool));
        uint256 poolOther_ = token1.balanceOf(address(pool));
        uint256 localProbe_ = probe_.balanceOf(address(fresh_));
        uint256 localOther_ = token1.balanceOf(address(fresh_));
        vm.expectRevert(IVault.SettlementMismatch.selector);
        caller.run(pool, address(fresh_), abi.encodeWithSelector(
            IFullSpreadUnlocked.exchangeIn.selector,
            address(probe_), 100 ether, address(fresh_), 0, address(caller), false, block.timestamp
        ));
        assertEq(fresh_.totalSupply(), supply_);
        assertEq(fresh_.positionLiquidity(), liquidity_);
        assertEq(fresh_.balanceOf(address(caller)), 0);
        assertEq(probe_.balanceOf(address(caller)), 100 ether);
        assertEq(probe_.balanceOf(address(pool)), poolProbe_);
        assertEq(token1.balanceOf(address(pool)), poolOther_);
        assertEq(probe_.balanceOf(address(fresh_)), localProbe_);
        assertEq(token1.balanceOf(address(fresh_)), localOther_);
        assertEq(pool.currencyDelta(address(fresh_), key.currency0), 0);
        assertEq(pool.currencyDelta(address(fresh_), key.currency1), 0);
    }

    /// @notice M20: an unfunded borrower cannot use vault inventory or somebody else's shares.
    function test_borrowedUnfundedCallerAndUnownedSharesRevert() public {
        UnlockedExchangeCaller empty_ = new UnlockedExchangeCaller();
        vm.prank(address(empty_));
        IERC20(address(token0)).approve(address(vault), type(uint256).max);
        IERC20(address(vault)).transfer(address(vault), 2 ether);
        uint256 parked_ = vault.balanceOf(address(vault));
        bytes32 before_ = _vaultState();
        uint256 supply_ = vault.totalSupply();
        vm.expectRevert();
        empty_.run(pool, address(vault), _mintCall(false, 0));
        bytes memory call_ = abi.encodeWithSelector(
            IFullSpreadUnlocked.exchangeIn.selector,
            address(vault), 1 ether, address(token0), 0, address(empty_), false, block.timestamp
        );
        vm.expectRevert(abi.encodeWithSelector(
            IERC20Errors.ERC20InsufficientBalance.selector, address(empty_), 0, 1 ether
        ));
        empty_.run(pool, address(vault), call_);
        assertEq(vault.totalSupply(), supply_);
        assertEq(money.balanceOf(address(empty_)), 0);
        assertEq(vault.balanceOf(address(vault)), parked_, "parked shares are not borrower authority");
        assertEq(_vaultState(), before_);
    }

    /// @notice FS-A20: value is rejected at the ABI boundary inside a live outer unlock.
    function test_borrowedValueRejectsAtNonpayableBoundary() public {
        vm.deal(address(caller), 1 ether);
        UnlockedExchangeCaller.Context memory context_;
        context_.catchFailure = true;
        context_.value = 1;
        bytes32 before_ = _vaultState();
        caller.runContext(pool, address(vault), _mintCall(false, 0), context_);
        assertFalse(caller.succeeded());
        assertEq(caller.result(), bytes(""), "nonpayable rejection has no internal context error");
        assertEq(address(caller).balance, 1 ether);
        assertEq(address(vault).balance, 0);
        assertEq(_vaultState(), before_);
        _assertInnerDeltas();
        assertTrue(caller.unlockedAfter());
    }

    /// @notice FS-A38: a direct disabled SE mint still rejects inside an outer unlock.
    function test_borrowedDisabledDirectMintRestoresState() public {
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(address(vault), true);
        bytes32 before_ = _vaultState();
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, address(vault)));
        caller.run(pool, address(vault), _mintCall(false, 0));
        assertEq(_vaultState(), before_);
    }

    /// @notice FS-A33: both mint faces have identical net, refund, fee and raw-liquidity supply deltas.
    function test_borrowedMintBothFacesMatchesLockedFromSameState() public {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(address(vault), 3e17);
        // Per face: two locked action unlocks/callbacks, then one borrowed
        // outer unlock with no vault callback.
        vm.expectCall(address(pool), abi.encodeWithSelector(IPoolManager.unlock.selector), uint64(6));
        vm.expectCall(address(vault), abi.encodeWithSelector(IUnlockCallback.unlockCallback.selector), uint64(4));
        for (uint256 i_; i_ < 2; ++i_) {
            address input_ = i_ == 0 ? address(token0) : address(token1);
            bytes memory call_ = abi.encodeWithSelector(
                IFullSpreadUnlocked.exchangeIn.selector,
                input_, 100 ether, address(vault), 0, address(caller), false, block.timestamp
            );
            uint256 snapshot_ = vm.snapshotState();
            uint256 supply_ = vault.totalSupply();
            uint256 liquidity_ = vault.positionLiquidity();
            address feeTo_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
            uint256 feeBefore_ = vault.balanceOf(feeTo_);
            uint256 payerBefore_ = IERC20(input_).balanceOf(address(caller));
            (uint256 locked_, uint256 refund_) = abi.decode(caller.runLocked(address(vault), call_), (uint256, uint256));
            assertGt(locked_, 0);
            uint256 gross_ = FullMath.mulDiv(vault.positionLiquidity() - liquidity_, supply_, liquidity_);
            assertEq(vault.totalSupply() - supply_, gross_);
            uint256 fee_ = vault.balanceOf(feeTo_) - feeBefore_;
            assertEq(fee_, FullMath.mulDiv(gross_, 3e17, 1e18));
            assertEq(locked_ + fee_, gross_, "fee is split from gross");
            assertEq(payerBefore_ - IERC20(input_).balanceOf(address(caller)), 100 ether - refund_);
            bytes32 lockedState_ = _vaultState();
            assertTrue(vm.revertToState(snapshot_));
            (uint256 borrowed_, uint256 borrowedRefund_) =
                abi.decode(caller.run(pool, address(vault), call_), (uint256, uint256));
            assertEq(borrowed_, locked_);
            assertEq(borrowedRefund_, refund_);
            assertEq(vault.balanceOf(address(caller)), borrowed_, "caller receives net shares");
            assertEq(vault.balanceOf(feeTo_) - feeBefore_, fee_);
            assertEq(payerBefore_ - IERC20(input_).balanceOf(address(caller)), 100 ether - borrowedRefund_);
            assertEq(_vaultState(), lockedState_, "same settlement, books, custody and position");
            _assertInnerDeltas();
            assertTrue(vm.revertToState(snapshot_));
        }
    }

    /// @dev Capture the inner return, before the outer caller settles or the manager relocks.
    function _assertInnerDeltas() internal view {
        assertEq(caller.vaultDelta0After(), 0, "currency0 closed before inner return");
        assertEq(caller.vaultDelta1After(), 0, "currency1 closed before inner return");
    }

    /// @dev Read-only family storage plus real manager position/price and custody.
    function _vaultState() internal view returns (bytes32) {
        bytes32[6] memory slots_;
        for (uint256 i_; i_ < slots_.length; ++i_) {
            slots_[i_] = vm.load(address(vault), bytes32(uint256(Repo.STORAGE_SLOT) + i_));
        }
        (uint160 price_, int24 tick_, uint24 protocolFee_, uint24 lpFee_) = StateLibrary.getSlot0(pool, key.toId());
        (uint128 position_, uint256 growth0_, uint256 growth1_) = StateLibrary.getPositionInfo(
            pool, key.toId(), address(vault), TickMath.minUsableTick(key.tickSpacing),
            TickMath.maxUsableTick(key.tickSpacing), bytes32(0)
        );
        return keccak256(abi.encode(
            vault.totalSupply(), vault.balanceOf(address(this)), vault.balanceOf(address(caller)),
            vault.balanceOf(address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo())),
            token0.balanceOf(address(vault)), token1.balanceOf(address(vault)),
            token0.balanceOf(address(pool)), token1.balanceOf(address(pool)),
            position_, growth0_, growth1_, price_, tick_, protocolFee_, lpFee_, slots_
        ));
    }

    /// @notice M20: every noncanonical borrowed route rejects before any manager action.
    function test_borrowedBundleOutDonateAndCompoundReject() public {
        address[] memory faces_ = new address[](2);
        faces_[0] = address(token0);
        faces_[1] = address(token1);
        _assertBorrowedRouteRejects(abi.encodeWithSignature(
            "exchangeBundleOut(address,uint256,address[],uint256[],address,bool,uint256)",
            address(vault), 1 ether, faces_, new uint256[](2), address(caller), false, block.timestamp
        ));
        address feeTo_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        vm.prank(feeTo_);
        (bool appointed_,) = address(vault).call(abi.encodeWithSignature("setOperator(address,bool)", address(caller), true));
        assertTrue(appointed_);
        _assertBorrowedRouteRejects(abi.encodeWithSignature("donate(address,uint256,bool)", address(token0), 1 ether, false));
        _assertBorrowedRouteRejects(abi.encodeWithSignature("compound()"));
    }

    /// @dev Each rejected route must preserve books, shares, caller funding and manager position.
    function _assertBorrowedRouteRejects(bytes memory call_) internal {
        bytes32 before_ = _vaultState();
        uint256 caller0_ = token0.balanceOf(address(caller));
        uint256 caller1_ = token1.balanceOf(address(caller));
        uint256 allowance0_ = token0.allowance(address(caller), address(vault));
        uint256 allowance1_ = token1.allowance(address(caller), address(vault));
        vm.expectRevert(IVault.ManagerAlreadyUnlocked.selector);
        caller.run(pool, address(vault), call_);
        assertEq(_vaultState(), before_);
        assertEq(token0.balanceOf(address(caller)), caller0_);
        assertEq(token1.balanceOf(address(caller)), caller1_);
        assertEq(token0.allowance(address(caller), address(vault)), allowance0_);
        assertEq(token1.allowance(address(caller), address(vault)), allowance1_);
        assertEq(pool.currencyDelta(address(vault), key.currency0), 0);
        assertEq(pool.currencyDelta(address(vault), key.currency1), 0);
    }

    function _mintCall(bool pretransferred_, uint256 minimum_) internal view returns (bytes memory) {
        return abi.encodeWithSelector(
            IFullSpreadUnlocked.exchangeIn.selector,
            address(token0), 100 ether, address(vault), minimum_, address(caller), pretransferred_, block.timestamp
        );
    }

    function test_borrowedBundleRevertsAlreadyUnlocked() public {
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 1 ether;
        amounts_[1] = 1 ether;
        bytes memory call_ = abi.encodeWithSelector(
            IFullSpreadUnlocked.exchangeBundleInForSingleOut.selector,
            amounts_,
            address(vault),
            0,
            address(caller),
            false,
            block.timestamp
        );
        _assertBorrowedRouteRejects(call_);
    }

    function test_borrowedPretransferReverts() public {
        bytes memory call_ = abi.encodeWithSelector(
            IFullSpreadUnlocked.exchangeIn.selector,
            address(token0),
            1 ether,
            address(vault),
            0,
            address(caller),
            true,
            block.timestamp
        );
        vm.expectRevert(IVault.InvalidUnlockedContext.selector);
        caller.run(pool, address(vault), call_);
    }
}
