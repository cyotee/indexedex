// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {PairTokenIOTestBase, PairTokenIOCreditRouter} from "./UniswapV4PairTokenStandardExchangeVaultStandardExchange.t.sol";
import {IUniswapV4PairTokenStandardExchangeVault as IVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol";
import {UniswapV4PairTokenStandardExchangeVaultExecution as Execution} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultExecution.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {NativeStandardYieldErrors} from "contracts/vaults/standard/sy/NativeStandardYieldErrors.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {VmSafe} from "forge-std/Vm.sol";

/// @notice A genuine forced-ETH source; no vault storage or bytecode manipulation.
contract PairTokenIOForceETH {
    constructor(address payable recipient_) payable {
        selfdestruct(recipient_);
    }
}

/// @notice Non-SUT refund/payout actor with rejecting, reentrant and gas-heavy receive modes.
contract PairTokenIONativeReceiver {
    IVault public immutable vault;
    uint256 public received;
    uint256 public calls;
    uint8 public mode;
    bytes public reentryError;
    bytes public outPreviewError;
    bytes public outExecutionError;

    constructor(IVault vault_) {
        vault = vault_;
    }

    function configure(uint8 mode_) external {
        mode = mode_;
    }

    function depositPair(address token1_, uint256 max0_, uint256 max1_) external payable returns (uint256) {
        IERC20(token1_).approve(address(vault), max1_);
        return vault.depositPair{value: max0_}(max0_, max1_, 0, address(this), block.timestamp);
    }

    receive() external payable {
        require(mode != 1, "reject ETH");
        // Storage writes exceed a 2,300-gas stipend.
        received += msg.value;
        ++calls;
        if (mode == 2 || mode == 3) {
            (bool ok_, bytes memory data_) = address(vault).call(abi.encodeCall(IVault.compound, ()));
            if (mode == 2) require(ok_, "reentrant payout");
            require(!ok_, "guard missing");
            reentryError = data_;
            (, outPreviewError) = address(vault).staticcall(abi.encodeCall(
                IStandardExchangeOut.previewExchangeOut, (IERC20(address(0)), IERC20(address(vault)), 1)
            ));
            (, outExecutionError) = address(vault).call(abi.encodeCall(
                IStandardExchangeOut.exchangeOut,
                (IERC20(address(0)), 0, IERC20(address(vault)), 1, address(0), true, 0)
            ));
        }
    }
}

/// @notice S1-A49-A55/A60 and native I/O rollback, against real registered diamonds.
// tag::UniswapV4PairTokenStandardExchangeVaultNativeTest[]
contract UniswapV4PairTokenStandardExchangeVaultNativeTest is PairTokenIOTestBase {
    using PoolIdLibrary for *;
    using StateLibrary for *;

    function _nativeVault() internal {
        _deployPool(true, 18, 18);
        vault = _deployVault(_defaultArgs(key, address(wrappedNative), "native PairToken"));
        vm.deal(address(this), 1e25);
    }

    function test_NAT_PairedExactMaximumRefundAndPendingInputIsolation() public {
        _nativeVault();
        _bootstrap(1e21, 1e21, address(this));
        _fund(address(this), 3e20, 1e20);
        // Incumbent maintenance must not spend the incoming native maximum.
        vault.donate{value: 1e18}(address(0), 1e18);
        (uint256 quote_, uint256 used0_, uint256 used1_) = vault.previewDepositPair(3e20, 1e20);
        assertLt(used0_, 3e20, "native maximum has a refund");
        uint256 supply_ = _share().totalSupply();
        uint256 eth_ = address(this).balance;
        uint256 token_ = token1.balanceOf(address(this));
        token1.approve(address(vault), used1_);
        assertEq(vault.depositPair{value: 3e20}(3e20, 1e20, quote_, address(this), block.timestamp), quote_);
        assertEq(address(this).balance, eth_ - used0_, "only accepted native input paid");
        assertEq(token1.balanceOf(address(this)), token_ - used1_, "pull accepted ERC20 only");
        assertEq(token1.allowance(address(this), address(vault)), 0);
        assertEq(_share().totalSupply(), supply_ + quote_);
        assertEq(IERC20(address(wrappedNative)).balanceOf(address(vault)), 0, "adapter not extra backing");
        _assertStable();
    }

    function test_NAT_WrongPairedAndSYValuesRollback() public {
        _nativeVault();
        _bootstrap(1e21, 1e21, address(this));
        _fund(address(this), 1e19, 1e19);
        bytes32 before_ = _stateHash();
        uint256[3] memory wrong_ = [uint256(0), uint256(1e18 - 1), uint256(1e18 + 1)];
        for (uint256 i; i < wrong_.length; ++i) {
            vm.expectRevert(abi.encodeWithSelector(Execution.InvalidNativeValue.selector, 1e18, wrong_[i]));
            vault.depositPair{value: wrong_[i]}(1e18, 1e18, 0, address(this), block.timestamp);
            vm.expectRevert(NativeStandardYieldErrors.UnsupportedNativePayment.selector);
            _sy().deposit{value: wrong_[i]}(address(this), address(0), 1e18, 0);
            assertEq(_stateHash(), before_, "wrong value cannot fund earlier maintenance");
        }
        vm.expectRevert(NativeStandardYieldErrors.UnsupportedNativePayment.selector);
        _sy().deposit{value: 1}(address(this), address(wrappedNative), 1e18, 0);
        assertEq(_stateHash(), before_);
    }

    function test_NAT_RawWrappedSYAndSEDepositEqualSnapshots() public {
        _nativeVault();
        _bootstrap(1e21, 1e21, address(this));
        uint256 amount_ = 1e18;
        wrappedNative.deposit{value: amount_}();
        IERC20(address(wrappedNative)).approve(address(vault), amount_);
        uint256 quote_ = _sy().previewDeposit(address(0), amount_);
        assertEq(_sy().previewDeposit(address(wrappedNative), amount_), quote_);
        (uint256 previewAmountOut1,) = _se().previewExchangeIn(IERC20(address(wrappedNative)), amount_, _share());
        assertEq(previewAmountOut1, quote_);
        bytes32 expected_;
        for (uint256 i; i < 3; ++i) {
            uint256 snapshot_ = vm.snapshotState();
            uint256 eth_ = address(this).balance;
            uint256 wrapped_ = IERC20(address(wrappedNative)).balanceOf(address(this));
            uint256 supply_ = _share().totalSupply();
            uint256 actual_;
            if (i == 0) {
                vm.expectEmit(true, true, true, true, address(vault));
                emit IStandardizedYield.Deposit(address(this), address(this), address(0), amount_, quote_);
                actual_ = _sy().deposit{value: amount_}(address(this), address(0), amount_, quote_);
            } else if (i == 1) {
                actual_ = _sy().deposit(address(this), address(wrappedNative), amount_, quote_);
            } else {(actual_,) = _se().exchangeIn(IERC20(address(wrappedNative)), amount_, _share(), quote_, address(this), false, block.timestamp);
            }
            assertEq(actual_, quote_);
            assertEq(_share().totalSupply(), supply_ + quote_);
            assertEq(address(this).balance, eth_ - (i == 0 ? amount_ : 0));
            assertEq(IERC20(address(wrappedNative)).balanceOf(address(this)), wrapped_ - (i == 0 ? 0 : amount_));
            assertEq(IERC20(address(wrappedNative)).balanceOf(address(vault)), 0);
            _assertStable();
            if (i == 0) expected_ = _nativeEconomicHash();
            else assertEq(_nativeEconomicHash(), expected_, "representation-independent economic state");
            assertTrue(vm.revertToState(snapshot_));
        }
    }

    function test_NAT_RawWrappedSYAndSEExitEqualSnapshots() public {
        _nativeVault();
        _bootstrap(1e21, 1e21, address(this));
        uint256 shares_ = 1e18;
        uint256 quote_ = _sy().previewRedeem(address(0), shares_);
        assertEq(_sy().previewRedeem(address(wrappedNative), shares_), quote_);
        (uint256 previewAmountOut2,) = _se().previewExchangeIn(_share(), shares_, IERC20(address(wrappedNative)));
        assertEq(previewAmountOut2, quote_);
        bytes32 expected_;
        for (uint256 i; i < 3; ++i) {
            uint256 snapshot_ = vm.snapshotState();
            uint256 eth_ = address(this).balance;
            uint256 wrapped_ = IERC20(address(wrappedNative)).balanceOf(address(this));
            uint256 supply_ = _share().totalSupply();
            uint256 actual_;
            if (i < 2) {
                address token_ = i == 0 ? address(0) : address(wrappedNative);
                vm.expectEmit(true, true, true, true, address(vault));
                emit IStandardizedYield.Redeem(address(this), address(this), token_, shares_, quote_);
                actual_ = _sy().redeem(address(this), shares_, token_, quote_, false);
            } else {(actual_,) = _se().exchangeIn(_share(), shares_, IERC20(address(wrappedNative)), quote_, address(this), false, block.timestamp);
            }
            assertEq(actual_, quote_);
            assertEq(_share().totalSupply(), supply_ - shares_);
            assertEq(address(this).balance, eth_ + (i == 0 ? quote_ : 0));
            assertEq(IERC20(address(wrappedNative)).balanceOf(address(this)), wrapped_ + (i == 0 ? 0 : quote_));
            assertEq(IERC20(address(wrappedNative)).balanceOf(address(vault)), 0);
            _assertStable();
            if (i == 0) expected_ = _nativeEconomicHash();
            else assertEq(_nativeEconomicHash(), expected_, "raw/alias final book and manager equal");
            assertTrue(vm.revertToState(snapshot_));
        }
    }

    function test_NAT_OutstandingERC20SyncResetBeforeNativeDebt() public {
        _nativeVault();
        _fund(address(this), 1e21, 1e21);
        _approveVault(address(vault));
        vm.startStateDiffRecording();
        pool.sync(key.currency1);
        // Genesis has native debt first. Without sync(native), manager settle
        // rejects this exact value while token1 remains the synced currency.
        assertEq(vault.depositPair{value: 1e21}(1e21, 1e21, 1e21, address(this), block.timestamp), 1e21);
        _assertNativeSyncOrder(vm.stopAndReturnStateDiff());
        _assertStable();
        assertEq(_share().totalSupply(), 1e21);
        // Also execute a take -> wrap -> ERC20 payout and unwrap -> native settle.
        _sy().redeem(address(this), 1e18, address(wrappedNative), 0, false);
        wrappedNative.deposit{value: 1e18}();
        IERC20(address(wrappedNative)).approve(address(vault), 1e18);
        pool.sync(key.currency1);
        _sy().deposit(address(this), address(wrappedNative), 1e18, 0);
        _assertStable();
    }

    function test_NAT_ForcedAndEmptyCalldataETHExcludedThroughTerminalRestart() public {
        _nativeVault();
        _bootstrap(1e21, 1e21, address(this));
        uint256 supply_ = _share().totalSupply();
        bytes32 economic_ = _nativeEconomicHash();
        new PairTokenIOForceETH{value: 1111}(payable(address(vault)));
        (bool ok_,) = address(vault).call{value: 2222}("");
        assertTrue(ok_, "proxy receive accepts empty calldata");
        assertEq(_nativeEconomicHash(), economic_, "receipt alone never books or mints");
        assertEq(_share().totalSupply(), supply_);
        vault.compound();
        _assertNativeExcess(3333);
        uint256 eth_ = address(this).balance;
        uint256 token_ = token1.balanceOf(address(this));
        (uint256 expected0_, uint256 expected1_) = vault.previewRedeemPair(supply_);
        (uint256 actual0_, uint256 actual1_) = vault.redeemPair(supply_, expected0_, expected1_, address(this), block.timestamp);
        assertEq(actual0_, expected0_);
        assertEq(actual1_, expected1_);
        assertEq(address(this).balance, eth_ + expected0_);
        assertEq(token1.balanceOf(address(this)), token_ + expected1_);
        assertEq(_share().totalSupply(), 0);
        assertEq(vault.positionLiquidity(), 0);
        (uint256 book0_, uint256 book1_) = vault.localReserves();
        assertEq(book0_, 0);
        assertEq(book1_, 0);
        assertEq(address(vault).balance, 3333, "last holder cannot take unbooked ETH");
        assertEq(token1.balanceOf(address(vault)), 0);
        assertEq(_sy().exchangeRate(), 0);
        _bootstrap(1e18, 1e18, address(this));
        assertEq(_share().totalSupply(), 1e18, "fresh geometric mean");
        _assertNativeExcess(3333);
        _assertStable();
    }

    function test_NAT_RejectingAndReentrantPayoutRollback() public {
        _nativeVault();
        _bootstrap(1e21, 1e21, address(this));
        PairTokenIONativeReceiver receiver_ = new PairTokenIONativeReceiver(vault);
        for (uint8 mode_ = 1; mode_ <= 2; ++mode_) {
            receiver_.configure(mode_);
            bytes32 before_ = _stateHash();
            uint256 eth_ = address(receiver_).balance;
            uint256 token_ = token1.balanceOf(address(receiver_));
            vm.expectRevert(Execution.NativeTransferFailed.selector);
            vault.redeemPair(1e18, 0, 0, address(receiver_), block.timestamp);
            assertEq(_stateHash(), before_, "pair payout rollback");
            vm.expectRevert(Execution.NativeTransferFailed.selector);
            _sy().redeem(address(receiver_), 1e18, address(0), 0, false);
            assertEq(_stateHash(), before_, "sale/burn/native payout rollback");
            assertEq(address(receiver_).balance, eth_);
            assertEq(token1.balanceOf(address(receiver_)), token_);
            assertEq(receiver_.received(), 0);
            assertEq(receiver_.calls(), 0);
        }
    }

    function test_NAT_RejectingAndReentrantRefundRollback() public {
        _nativeVault();
        _bootstrap(1e21, 1e21, address(this));
        PairTokenIONativeReceiver receiver_ = new PairTokenIONativeReceiver(vault);
        _fund(address(receiver_), 0, 1e18);
        for (uint8 mode_ = 1; mode_ <= 2; ++mode_) {
            receiver_.configure(mode_);
            bytes32 before_ = _stateHash();
            uint256 token_ = token1.balanceOf(address(receiver_));
            vm.expectRevert(Execution.NativeTransferFailed.selector);
            receiver_.depositPair{value: 2e18}(address(token1), 2e18, 1e18);
            assertEq(_stateHash(), before_, "refund failure rolls back manager, pull and mint");
            assertEq(token1.balanceOf(address(receiver_)), token_);
            assertEq(token1.allowance(address(receiver_), address(vault)), 0, "approval inside reverted call");
            assertEq(_share().balanceOf(address(receiver_)), 0);
            assertEq(address(receiver_).balance, 0);
        }
    }

    function test_NAT_NormalHeavyReceiverAndCaughtReentryOutPrecedence() public {
        _nativeVault();
        _bootstrap(1e21, 1e21, address(this));
        PairTokenIONativeReceiver receiver_ = new PairTokenIONativeReceiver(vault);
        receiver_.configure(3);
        (uint256 payout0_, uint256 payout1_) = vault.previewRedeemPair(1e18);
        vault.redeemPair(1e18, payout0_, payout1_, address(receiver_), block.timestamp);
        assertEq(receiver_.received(), payout0_);
        assertEq(receiver_.calls(), 1);
        assertEq(address(receiver_).balance, payout0_);
        assertEq(token1.balanceOf(address(receiver_)), payout1_);
        assertEq(receiver_.reentryError(), abi.encodeWithSelector(IVault.ReentrantOperation.selector));
        assertEq(receiver_.outPreviewError(), abi.encodeWithSelector(IStandardExchangeOut.ExchangeOutNotAvailable.selector));
        assertEq(receiver_.outExecutionError(), abi.encodeWithSelector(IStandardExchangeOut.ExchangeOutNotAvailable.selector));
        _assertStable();
        receiver_.configure(0);
        _fund(address(receiver_), 0, 1e18);
        (, uint256 used0_, uint256 used1_) = vault.previewDepositPair(2e18, 1e18);
        uint256 received_ = receiver_.received();
        uint256 balance_ = address(receiver_).balance;
        uint256 token_ = token1.balanceOf(address(receiver_));
        receiver_.depositPair{value: 2e18}(address(token1), 2e18, 1e18);
        assertEq(receiver_.received(), received_ + 2e18 - used0_);
        assertEq(address(receiver_).balance, balance_ + 2e18 - used0_);
        assertEq(token1.balanceOf(address(receiver_)), token_ - used1_);
        _assertStable();
    }

    function test_NAT_WrappedShortExcessCreditDoesNotUseBookedETH() public {
        _nativeVault();
        _bootstrap(1e21, 1e21, address(this));
        vault.donate{value: 1e18}(address(0), 1e18);
        PairTokenIOCreditRouter router_ = new PairTokenIOCreditRouter();
        wrappedNative.deposit{value: 3e18}();
        IERC20(address(wrappedNative)).transfer(address(router_), 3e18);
        bytes32 before_ = _stateHash();
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1e18, 0));
        router_.exchange(address(vault), address(wrappedNative), 0, 1e18, address(vault), address(this));
        assertEq(_stateHash(), before_, "native backing is not wrapped credit");
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1e18, 1e18 - 1));
        router_.exchange(address(vault), address(wrappedNative), 1e18 - 1, 1e18, address(vault), address(this));
        assertEq(_stateHash(), before_);
        assertEq(IERC20(address(wrappedNative)).balanceOf(address(router_)), 3e18);
        uint256 supply_ = _share().totalSupply();
        uint256 quote_ = _sy().previewDeposit(address(wrappedNative), 1e18);
        assertEq(router_.exchange(address(vault), address(wrappedNative), 2e18, 1e18, address(vault), address(this)), quote_);
        assertEq(_share().totalSupply(), supply_ + quote_);
        assertEq(IERC20(address(wrappedNative)).balanceOf(address(vault)), 1e18, "excess wrapper stays unbooked");
        assertEq(IERC20(address(wrappedNative)).balanceOf(address(router_)), 1e18, "no excess refund");
        _assertStable();
        vault.compound();
        assertEq(IERC20(address(wrappedNative)).balanceOf(address(vault)), 1e18, "compound cannot adopt wrapped excess");
        _assertStable();
        vault.redeemPair(_share().totalSupply(), 0, 0, address(this), block.timestamp);
        assertEq(_share().totalSupply(), 0);
        assertEq(vault.positionLiquidity(), 0);
        assertEq(IERC20(address(wrappedNative)).balanceOf(address(vault)), 1e18, "terminal cannot sweep wrapped excess");
        _bootstrap(1e18, 1e18, address(this));
        assertEq(IERC20(address(wrappedNative)).balanceOf(address(vault)), 1e18, "restart cannot adopt wrapped excess");
        _assertStable();
    }

    function test_NAT_DiscoveryAndZeroAddressSERejected() public {
        _nativeVault();
        address[] memory in_ = _sy().getTokensIn();
        address[] memory out_ = _sy().getTokensOut();
        assertEq(in_.length, 3);
        assertEq(out_.length, 3);
        assertEq(in_[0], address(0));
        assertEq(in_[1], address(wrappedNative));
        assertEq(in_[2], address(token1));
        for (uint256 i; i < 3; ++i) {
            assertEq(out_[i], in_[i]);
            assertTrue(_sy().isValidTokenIn(in_[i]));
            assertTrue(_sy().isValidTokenOut(in_[i]));
        }
        _bootstrap(1e21, 1e21, address(this));
        bytes32 before_ = _stateHash();
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(0), address(vault)));_se().exchangeIn(IERC20(address(0)), 1e18, _share(), 0, address(this), false, block.timestamp);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(vault), address(0)));_se().exchangeIn(_share(), 1e18, IERC20(address(0)), 0, address(this), false, block.timestamp);
        // Nonpayable SE selectors reject attached ETH at the ABI boundary.
        (bool ok_,) = address(vault).call{value: 1}(abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (IERC20(address(wrappedNative)), 1e18, _share(), 0, address(this), false, block.timestamp)));
        assertFalse(ok_);
        assertEq(_stateHash(), before_);
    }

    function test_NAT_TerminalRawAndWrappedSingleExitWithRealExternalLiquidity() public {
        _nativeVault();
        _bootstrap(1e21, 1e21, address(this));
        _externalLiquidity();
        for (uint256 i; i < 2; ++i) {
            uint256 snapshot_ = vm.snapshotState();
            address token_ = i == 0 ? address(0) : address(wrappedNative);
            uint256 shares_ = _share().totalSupply();
            uint256 quote_ = _sy().previewRedeem(token_, shares_);
            uint256 before_ = _raw(token_, address(this));
            assertEq(_sy().redeem(address(this), shares_, token_, quote_, false), quote_);
            assertEq(_raw(token_, address(this)), before_ + quote_);
            assertEq(_share().totalSupply(), 0);
            assertEq(vault.positionLiquidity(), 0);
            (uint256 book0_, uint256 book1_) = vault.localReserves();
            assertEq(book0_, 0);
            assertEq(book1_, 0);
            assertEq(address(vault).balance, 0);
            assertEq(token1.balanceOf(address(vault)), 0);
            assertEq(IERC20(address(wrappedNative)).balanceOf(address(vault)), 0);
            _assertStable();
            assertTrue(vm.revertToState(snapshot_));
        }
    }

    function test_NAT_DisabledNativeCapitalBlockedRawAndWrappedExitsRemain() public {
        _nativeVault();
        _bootstrap(1e21, 1e21, address(this));
        _fund(address(this), 1e19, 1e19);
        wrappedNative.deposit{value: 1e18}();
        IERC20(address(wrappedNative)).approve(address(vault), 1e18);
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(address(vault), true);
        bytes32 before_ = _stateHash();
        vm.expectRevert(IVault.IssuanceDisabled.selector);
        vault.depositPair{value: 1e18}(1e18, 1e18, 0, address(this), block.timestamp);
        for (uint256 i; i < 2; ++i) {
            address token_ = i == 0 ? address(0) : address(wrappedNative);
            vm.expectRevert(IVault.IssuanceDisabled.selector);
            _sy().deposit{value: i == 0 ? 1e18 : 0}(address(this), token_, 1e18, 0);
            vm.expectRevert(IVault.IssuanceDisabled.selector);
            vault.donate{value: i == 0 ? 1e18 : 0}(token_, 1e18);
            assertEq(_stateHash(), before_);
        }
        uint256 supply_ = _share().totalSupply();
        vault.compound();
        assertEq(_share().totalSupply(), supply_);
        for (uint256 i; i < 2; ++i) {
            uint256 snapshot_ = vm.snapshotState();
            address token_ = i == 0 ? address(0) : address(wrappedNative);
            uint256 quote_ = _sy().previewRedeem(token_, 1e18);
            uint256 balance_ = _raw(token_, address(this));
            assertEq(_sy().redeem(address(this), 1e18, token_, quote_, false), quote_);
            assertEq(_raw(token_, address(this)), balance_ + quote_);
            assertEq(_share().totalSupply(), supply_ - 1e18);
            _assertStable();
            assertTrue(vm.revertToState(snapshot_));
        }
    }

    function _assertNativeExcess(uint256 expected_) internal view {
        (uint256 book0_,) = vault.localReserves();
        assertEq(address(vault).balance - book0_, expected_);
    }

    function _nativeEconomicHash() internal view returns (bytes32 result_) {
        {
            (uint160 price_, int24 tick_, uint24 protocol_, uint24 fee_) = pool.getSlot0(key.toId());
            (uint256 growth0_, uint256 growth1_) = pool.getFeeGrowthGlobals(key.toId());
            result_ = keccak256(abi.encode(price_, tick_, protocol_, fee_, growth0_, growth1_, pool.getLiquidity(key.toId())));
        }
        (uint128 liquidity_, uint256 checkpoint0_, uint256 checkpoint1_) =
            pool.getPositionInfo(key.toId(), address(vault), vault.tickLower(), vault.tickUpper(), bytes32(0));
        (uint256 book0_, uint256 book1_) = vault.localReserves();
        return keccak256(abi.encode(result_, liquidity_, checkpoint0_, checkpoint1_, book0_, book1_, _share().totalSupply()));
    }

    function _assertNativeSyncOrder(VmSafe.AccountAccess[] memory accesses_) internal view {
        bool dirtyERC20_;
        bool nativeSynced_;
        uint256 nativeSettlements_;
        for (uint256 i; i < accesses_.length; ++i) {
            VmSafe.AccountAccess memory access_ = accesses_[i];
            if (access_.account == address(0) && access_.data.length >= 4) {
                bytes4 zeroSelector_ = bytes4(access_.data);
                assertTrue(zeroSelector_ != IERC20.balanceOf.selector && zeroSelector_ != IERC20.transfer.selector
                    && zeroSelector_ != IERC20.transferFrom.selector, "no ERC20 method on native currency");
            }
            if (access_.kind != VmSafe.AccountAccessKind.Call || access_.account != address(pool) || access_.data.length < 4) continue;
            bytes4 selector_ = bytes4(access_.data);
            if (selector_ == IPoolManager.sync.selector) {
                if (keccak256(access_.data) == keccak256(abi.encodeCall(IPoolManager.sync, (key.currency1)))) {
                    dirtyERC20_ = true;
                    nativeSynced_ = false;
                } else if (keccak256(access_.data) == keccak256(abi.encodeCall(IPoolManager.sync, (Currency.wrap(address(0)))))) {
                    assertTrue(dirtyERC20_, "explicit outstanding ERC20 sync precedes native reset");
                    nativeSynced_ = true;
                }
            } else if (selector_ == IPoolManager.settle.selector && access_.value != 0) {
                assertTrue(nativeSynced_, "native debt must reset sync before exact value settlement");
                assertEq(access_.accessor, address(vault), "registered diamond settles its debt");
                ++nativeSettlements_;
                nativeSynced_ = false;
            }
        }
        assertGt(nativeSettlements_, 0, "record a real native value settlement");
    }
}
// end::UniswapV4PairTokenStandardExchangeVaultNativeTest[]
