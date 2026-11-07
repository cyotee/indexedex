// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {Vm} from "forge-std/Vm.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {HookComponentAccountingBehavior} from "../HookComponentAccountingBehavior.sol";
import {UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault as FullSpreadRow} from "./UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";

/// @notice Real FullSpread component-accounting adapter; no substitute vault or synthetic balances.
contract UniswapV4DualSEBCPHook_ComponentAccounting is FullSpreadRow, HookComponentAccountingBehavior {
    function test_component_sequentialShareJoinQuoteRequiresProjectionButExecutionWorks() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        uint256[] memory funded = _hbFundShares(HB_BOB, 10 ether);
        uint256 amount = funded[0] / 10;
        vm.expectRevert(bytes4(keccak256("InvalidQuoteState()")));
        IUniswapV4SeBufferHook(hook).previewJoinSingleAssetExactIn(seUT, amount);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        vm.prank(HB_BOB);
        uint256 net = IUniswapV4SeBufferHook(hook).joinSingleAssetExactIn(seUT, amount, HB_BOB, 1, block.timestamp);
        assertGt(net, 0);
        _hbAssertFee(before_, _hbSnapshot(HB_BOB), net);
    }

    function test_component_oneConversionPerLegQuoteRemainsAvailable() public {
        _hbBootstrap();
        uint256[] memory amounts = _hbFundShares(HB_BOB, 10 ether);
        (uint256 quote,,) = dual.previewDepositFlexible(
            faceIsC0 ? amounts[0] : amounts[1], true,
            faceIsC0 ? amounts[1] : amounts[0], true
        );
        assertGt(quote, 0);
        assertEq(_hbJoinShares(HB_BOB, amounts, quote), quote);
    }

    function test_component_sequentialExitQuoteRequiresProjectionButExecutionWorks() public {
        _hbBootstrap();
        uint256 burned = IERC20(hook).balanceOf(HB_ALICE) / 10;
        vm.expectRevert(bytes4(keccak256("InvalidQuoteState()")));
        IUniswapV4SeBufferHook(hook).previewExitSingleAssetExactBptIn(face, burned);
        uint256 beforePair = IERC20(face).balanceOf(HB_ALICE);
        uint256 supply = IERC20(hook).totalSupply();
        vm.prank(HB_ALICE);
        uint256 paid = IUniswapV4SeBufferHook(hook).exitSingleAssetExactBptIn(face, burned, HB_ALICE, 1, block.timestamp);
        assertGt(paid, 0);
        assertEq(IERC20(face).balanceOf(HB_ALICE) - beforePair, paid);
        assertEq(IERC20(hook).totalSupply(), supply - burned);
    }

    function _hbHook() internal view override returns (address) { return hook; }

    function _hbPairs() internal view override returns (address[] memory pairs_) {
        pairs_ = new address[](2);
        pairs_[0] = face; pairs_[1] = other;
    }

    function _hbExchanges() internal view override returns (address[] memory exchanges_) {
        exchanges_ = new address[](2);
        exchanges_[0] = seUT; exchanges_[1] = seUT1;
    }

    function _hbSetFee(uint256 fee_) internal override {
        if (fee_ == 0) {
            // Zero clears the vault override; clear the fixture's global fallback too.
            vm.prank(owner);
            IVaultFeeOracleManager(address(indexedexManager)).setDefaultDexSwapFee(0);
        }
        _enableProtocolFee(fee_);
        assertEq(IVaultFeeOracleQuery(address(indexedexManager)).dexSwapFeeOfVault(hook),
            fee_, "configured hook LP fee");
    }
    function _hbFeeRecipient() internal view override returns (address) { return dual.feeTo(); }

    function _hbFundShares(address actor_, uint256 budget_) internal override returns (uint256[] memory amounts_) {
        address[] memory pairs_ = _hbPairs();
        address[] memory exchanges_ = _hbExchanges();
        amounts_ = new uint256[](pairs_.length);
        for (uint256 i_; i_ < pairs_.length; ++i_) {
            address input_ = exchanges_[i_];
            if (input_ == address(0)) {
                input_ = pairs_[i_];
                SimpleMintableERC20(input_).mint(actor_, budget_);
                amounts_[i_] = budget_;
            } else {
                amounts_[i_] = fullSpread.acquireShares(input_, pairs_[i_], actor_, budget_);
            }
            vm.prank(actor_);
            IERC20(input_).approve(hook, type(uint256).max);
        }
    }

    function _hbFundPairs(address actor_, uint256 budget_) internal override returns (uint256[] memory amounts_) {
        address[] memory pairs_ = _hbPairs();
        amounts_ = new uint256[](pairs_.length);
        for (uint256 i_; i_ < pairs_.length; ++i_) {
            SimpleMintableERC20(pairs_[i_]).mint(actor_, budget_);
            amounts_[i_] = budget_;
            vm.prank(actor_);
            IERC20(pairs_[i_]).approve(hook, type(uint256).max);
        }
    }

    function _hbJoinShares(address actor_, uint256[] memory amounts_, uint256 minimum_)
        internal override returns (uint256 net_)
    {
        uint256 a0_ = faceIsC0 ? amounts_[0] : amounts_[1];
        uint256 a1_ = faceIsC0 ? amounts_[1] : amounts_[0];
        vm.prank(actor_);
        (net_,,) = dual.depositFlexible(a0_, true, a1_, true, actor_, minimum_, block.timestamp);
    }

    function _hbJoinPairs(address actor_, uint256[] memory amounts_, uint256 minimum_)
        internal override returns (uint256 net_)
    {
        uint256 a0_ = faceIsC0 ? amounts_[0] : amounts_[1];
        uint256 a1_ = faceIsC0 ? amounts_[1] : amounts_[0];
        vm.prank(actor_);
        (net_,,) = dual.deposit(a0_, a1_, actor_, minimum_, block.timestamp);
    }

    function _hbExitPairs(address actor_, uint256 burned_) internal override {
        vm.prank(actor_);
        dual.withdraw(burned_, actor_, 1, 1, block.timestamp);
    }

    function _hbMoveUnderlyingMarket() internal override {
        fullSpread.acquireShares(seUT, face, address(0xCAFE40), 50_000 ether);
    }

    function _hbRate() internal view override returns (uint256) { return IRateProvider(dual.rateProvider(face)).getRate(); }
    function _hbMinimumError() internal pure override returns (bytes4) { return bytes4(keccak256("InsufficientLpOut()")); }
    function _hbInitialPairError() internal pure override returns (bytes4) { return bytes4(keccak256("InvalidRoute()")); }

    function _hbDisable(bool byPackage_, bool disabled_) internal override {
        address package_ = fullSpread.pkg();
        vm.prank(owner);
        if (byPackage_) IVaultRegistryDisableManager(address(indexedexManager)).setPackageDisabled(package_, disabled_);
        else IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(seUT, disabled_);
    }

    function _hbTrade(address actor_, uint256 inputIndex_, uint256 outputIndex_, uint256 amount_)
        internal override returns (uint256 output_)
    {
        address[] memory pairs_ = _hbPairs();
        vm.prank(actor_);
        (output_,) = IStandardExchangeIn(hook).exchangeIn(
            IERC20(pairs_[inputIndex_]), amount_, IERC20(pairs_[outputIndex_]), 1, actor_, false, block.timestamp
        );
    }

    function test_H3_realFullRefundBecomesPoolLocalInput() public {
        uint256[] memory amounts_ = _hbFundShares(HB_ALICE, 100 ether);
        amounts_[0] /= 10;
        _hbJoinShares(HB_ALICE, amounts_, 1);
        _hbFundPairs(HB_BOB, 1 ether);
        (uint256 quotedShares_, uint256 refund_) = IStandardExchangeIn(seUT)
            .previewExchangeIn(IERC20(face), 1, IERC20(seUT));
        assertEq(quotedShares_, 0, "real FullSpread dust conversion mints nothing");
        assertEq(refund_, 1, "real full input refund");
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        uint256 paid_ = _hbTrade(HB_BOB, 0, 1, 1);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        assertGt(paid_, 0, "imbalanced book makes the one-wei trade executable");
        assertEq(after_.pairs[0], before_.pairs[0] + 1);
        assertEq(after_.shares[0], before_.shares[0]);
        assertEq(after_.shareSupply[0], before_.shareSupply[0]);
        assertEq(before_.userPairs[0] - after_.userPairs[0], 1);
        assertEq(after_.pairs[1], before_.pairs[1] - paid_);
        assertEq(after_.shares[1], before_.shares[1]);
        assertEq(after_.supply, before_.supply);
    }

    function test_H3_realPartialRefundIsBookedOnceNotPaidToSwapper() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 100 ether);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        vm.recordLogs();
        uint256 paid_ = _hbTrade(HB_BOB, 0, 1, 10 ether);
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        uint256 refund_;
        uint256 minted_;
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].topics.length != 3 || logs_[i_].topics[0] != keccak256("Transfer(address,address,uint256)")) continue;
            address from_ = address(uint160(uint256(logs_[i_].topics[1])));
            address to_ = address(uint160(uint256(logs_[i_].topics[2])));
            if (logs_[i_].emitter == face && from_ == seUT && to_ == hook) refund_ += abi.decode(logs_[i_].data, (uint256));
            if (logs_[i_].emitter == seUT && from_ == address(0) && to_ == hook) minted_ += abi.decode(logs_[i_].data, (uint256));
        }
        assertGt(refund_, 0, "real partial SE refund");
        assertLt(refund_, 10 ether);
        assertGt(minted_, 0);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        assertEq(after_.pairs[0], before_.pairs[0] + refund_);
        assertEq(after_.shares[0], before_.shares[0] + minted_);
        assertEq(before_.userPairs[0] - after_.userPairs[0], 10 ether, "pool refund is not caller credit");
        assertEq(after_.userPairs[1] - before_.userPairs[1], paid_);
        assertEq(after_.supply, before_.supply);
        assertEq(after_.feeLp, before_.feeLp, "conversion-only swap issues no LP fee");
    }

    function test_H3_exactLocalEqualityLeavesMixedZeroComponent() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 100 ether);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        uint256 wanted_ = before_.pairs[0];
        uint256 needed_ = IStandardExchangeOut(hook).previewExchangeOut(IERC20(other), IERC20(face), wanted_);
        assertGt(wanted_, 0);
        vm.prank(HB_BOB);
        uint256 used_ = IStandardExchangeOut(hook).exchangeOut(IERC20(other), needed_, IERC20(face), wanted_,
            HB_BOB, false, block.timestamp);
        assertEq(used_, needed_);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        assertEq(after_.pairs[0], 0, "exact equality consumes only local output");
        assertEq(after_.shares[0], before_.shares[0]);
        assertEq(after_.shareSupply[0], before_.shareSupply[0]);
        uint256[] memory supplied_ = _hbFundShares(HB_BOB, 10 ether);
        before_ = _hbSnapshot(HB_BOB);
        uint256 net_ = _hbJoinShares(HB_BOB, supplied_, 1);
        after_ = _hbSnapshot(HB_BOB);
        _hbAssertFee(before_, after_, net_);
        _hbAssertContributions(before_, after_);
        assertEq(after_.pairs[0], 0, "zero component requires no local contribution");
    }

    function test_H3_disabledShareOutputRollsBackButPairExitSucceeds() public {
        _hbBootstrap();
        _hbDisable(false, true);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_ALICE);
        uint256 burn_ = before_.userLp / 4;
        vm.prank(HB_ALICE);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, seUT));
        dual.withdrawFlexible(burn_, HB_ALICE, faceIsC0, !faceIsC0, 0, 0, block.timestamp);
        assertEq(abi.encode(_hbSnapshot(HB_ALICE)), abi.encode(before_));
        _hbExitPairs(HB_ALICE, burn_);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_ALICE);
        for (uint256 i_; i_ < 2; ++i_) {
            assertEq(after_.pairs[i_], before_.pairs[i_] - burn_ * before_.pairs[i_] / before_.supply);
            assertEq(after_.shares[i_], before_.shares[i_] - burn_ * before_.shares[i_] / before_.supply);
        }
    }

    function test_H3_disabledPairOnlyJoinCannotBorrowIncumbentShares() public {
        _hbBootstrap();
        uint256[] memory amounts_ = _hbFundPairs(HB_BOB, 10 ether);
        _hbDisable(false, true);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        vm.expectRevert(_hbMinimumError());
        this.hbJoinPairs(HB_BOB, amounts_, 1);
        assertEq(abi.encode(_hbSnapshot(HB_BOB)), abi.encode(before_));
        vm.prank(HB_BOB);
        IERC20(face).approve(seUT, amounts_[0]);
        vm.prank(HB_BOB);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, seUT));
        IStandardExchangeIn(seUT).exchangeIn(IERC20(face), amounts_[0], IERC20(seUT), 1, HB_BOB, false, block.timestamp);
    }

    function test_H3_zeroRoundedSecondGenesisLegRestoresFirstRedemption() public {
        uint256[] memory amounts_ = _hbFundShares(HB_ALICE, 100 ether);
        amounts_[faceIsC0 ? 1 : 0] = 19;
        ComponentSnapshot memory before_ = _hbSnapshot(HB_ALICE);
        vm.expectRevert();
        this.hbJoinShares(HB_ALICE, amounts_, 1);
        assertEq(abi.encode(_hbSnapshot(HB_ALICE)), abi.encode(before_), "first leg's burn and allowances roll back");
        assertEq(IERC20(hook).balanceOf(address(0)), 0);
    }

    function test_H3_laterMinimumAndDeadlineRestoreAllComponents() public {
        _hbBootstrap();
        uint256[] memory amounts_ = _hbFundShares(HB_BOB, 10 ether);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        vm.expectRevert(_hbMinimumError());
        this.hbJoinShares(HB_BOB, amounts_, type(uint256).max);
        assertEq(abi.encode(_hbSnapshot(HB_BOB)), abi.encode(before_));
        (uint256 a0_, uint256 a1_) = _c(amounts_[0], amounts_[1]);
        vm.prank(HB_BOB);
        vm.expectRevert(abi.encodeWithSignature("DeadlineExpired()"));
        dual.depositFlexible(a0_, true, a1_, true, HB_BOB, 1, block.timestamp - 1);
        assertEq(abi.encode(_hbSnapshot(HB_BOB)), abi.encode(before_));
    }

    function test_H3_bookedLocalCannotSatisfyUnfundedOrShortPretransfer() public {
        _hbBootstrap();
        bytes memory call_ = abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (IERC20(face), 1 ether, IERC20(other), 1, address(rowCaller), true, block.timestamp));
        ComponentSnapshot memory before_ = _hbSnapshot(address(rowCaller));
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1 ether, 0));
        rowCaller.execute(hook, call_);
        assertEq(abi.encode(_hbSnapshot(address(rowCaller))), abi.encode(before_));
        uint256 payerBefore_ = IERC20(face).balanceOf(address(this));
        SimpleMintableERC20(face).mint(address(this), 0.5 ether);
        IERC20(face).approve(address(rowCaller), 0.5 ether);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1 ether, 0.5 ether));
        rowCaller.consumePretransfer(IERC20(face), address(this), hook, 0.5 ether, call_);
        assertEq(abi.encode(_hbSnapshot(address(rowCaller))), abi.encode(before_));
        assertEq(IERC20(face).balanceOf(address(this)), payerBefore_ + 0.5 ether, "short funding rolls back");
    }

    function test_H3_ambientSharesCannotSubsidizeLaterJoin() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        uint256[] memory incoming_ = _hbFundShares(HB_BOB, 10 ether);
        uint256[] memory donation_ = _hbFundShares(HB_ALICE, 3 ether);
        uint256 checkpoint_ = vm.snapshotState();
        uint256 control_ = _hbJoinShares(HB_BOB, incoming_, 1);
        ComponentSnapshot memory expected_ = _hbSnapshot(HB_BOB);
        assertTrue(vm.revertToState(checkpoint_));
        vm.startPrank(HB_ALICE);
        IERC20(seUT).transfer(hook, donation_[0]);
        IERC20(seUT1).transfer(hook, donation_[1]);
        vm.stopPrank();
        uint256 net_ = _hbJoinShares(HB_BOB, incoming_, 1);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        assertEq(net_, control_);
        assertEq(after_.supply, expected_.supply);
        assertEq(after_.pairs, expected_.pairs);
        assertEq(after_.userPairs, expected_.userPairs);
        assertEq(after_.userShares, expected_.userShares);
        for (uint256 i_; i_ < 2; ++i_) assertEq(after_.shares[i_], expected_.shares[i_] + donation_[i_]);
    }

    function test_H3_outerUnlockFailureAndCaughtFailureRestoreBothBooks() public {
        _hbBootstrap();
        DualComponentUnlockCaller caller_ = new DualComponentUnlockCaller(pm, hook, face, other);
        _hbFundPairs(address(caller_), 100 ether);
        ComponentSnapshot memory before_ = _hbSnapshot(address(caller_));
        vm.expectRevert(DualComponentUnlockCaller.OuterFailure.selector);
        caller_.run(10 ether, 1);
        assertEq(abi.encode(_hbSnapshot(address(caller_))), abi.encode(before_), "outer failure restores both vaults and books");
        uint256 checkpoint_ = vm.snapshotState();
        uint256 control_ = caller_.run(10 ether, 0);
        assertGt(control_, 0, "real two-vault call inside one unlock");
        ComponentSnapshot memory expected_ = _hbSnapshot(address(caller_));
        assertTrue(vm.revertToState(checkpoint_));
        uint256 actual_ = caller_.run(10 ether, 2);
        assertEq(actual_, control_);
        assertEq(abi.encode(_hbSnapshot(address(caller_))), abi.encode(expected_), "caught failure leaves no interim book or lock");
        address[4] memory holders_ = [hook, seUT, seUT1, address(caller_)];
        address[4] memory currencies_ = [face, other, fullSpread.otherToken(), pairRecord.p1()];
        for (uint256 i_; i_ < 4; ++i_) for (uint256 j_; j_ < 4; ++j_)
            assertEq(TransientStateLibrary.currencyDelta(pm, holders_[i_], Currency.wrap(currencies_[j_])), 0);
    }

    /// @notice Unsupported exact-net is a product rejection, not a skipped LP assertion.
    function test_HB47_exactNetRejectedAndRollsBack() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 100 ether);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        address token_ = _hbPairs()[1];
        assertEq(IUniswapV4SeBufferHook(hook).previewJoinSingleAssetExactOut(token_, 1 ether), 0);
        vm.prank(HB_BOB);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("InvalidRoute()"))));
        IUniswapV4SeBufferHook(hook).joinSingleAssetExactOut(token_, 1 ether, HB_BOB, 100 ether, block.timestamp);
        assertEq(abi.encode(_hbSnapshot(HB_BOB)), abi.encode(before_), "unsupported exact-net restores every leg");
    }
}

/// @dev Non-SUT caller: injects an outer failure after a genuine hook operation.
contract DualComponentUnlockCaller is IUnlockCallback {
    IPoolManager private immutable manager;
    address private immutable hook;
    address private immutable input;
    address private immutable output;
    error OuterFailure();

    constructor(IPoolManager manager_, address hook_, address input_, address output_) {
        manager = manager_;
        hook = hook_;
        input = input_;
        output = output_;
    }

    function run(uint256 amount, uint256 mode) external returns (uint256) {
        return abi.decode(manager.unlock(abi.encode(amount, mode)), (uint256));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(manager), "manager only");
        (uint256 amount, uint256 mode) = abi.decode(data, (uint256, uint256));
        if (mode == 2) {
            try IStandardExchangeIn(hook).exchangeIn(IERC20(input), amount, IERC20(output), type(uint256).max,
                address(this), false, block.timestamp) returns (uint256, uint256) {
                revert("impossible minimum succeeded");
            } catch (bytes memory reason) {
                require(bytes4(reason) == bytes4(keccak256("InsufficientTokenOut()")), "minimum failure only");
            }
        }
        (uint256 paid,) = IStandardExchangeIn(hook).exchangeIn(IERC20(input), amount, IERC20(output), 1,
            address(this), false, block.timestamp);
        if (mode == 1) revert OuterFailure();
        return abi.encode(paid);
    }
}
