// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Events} from "@crane/contracts/tokens/ERC20/IERC20Events.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardizedYield as SY} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeTransitionQuote as Transition, IStandardExchangeExternalQuote as ExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {TestBase_UniswapV4FullSpreadUnlockContextQuote as Shapes} from "contracts/test/bases/TestBase_UniswapV4FullSpreadUnlockContextQuote.sol";
import {IFullSpreadCampaignFeeLedger} from "contracts/test/bases/TestBase_UniswapV4FullSpreadCrossModeCampaign.sol";

// tag::TestBase_FullSpreadG6TransitionLifecycleClosure[]
/// @notice G6 assertions over real registry proxies; the family fixtures supply only setup and calls.
/// @dev No planner/quote implementation is used as an independent accounting reference.
abstract contract TestBase_FullSpreadG6TransitionLifecycleClosure is Test {
    using PoolIdLibrary for PoolKey;

    struct Step {
        bytes next;
        uint256 quantity;
        uint256 claim;
        uint256 payerBalance;
        uint256 recipientBalance;
        uint256 supply;
        uint256 holderShares;
        uint256[4] fees;
    }

    struct Exit {
        Shapes.Snapshot beforeBook;
        bytes next;
        uint256 burn;
        uint256 output;
        uint256 claim;
        uint256 balance;
        uint256[2] entitled;
        uint256[2] growth;
        uint256[4] fees;
    }

    struct SwapObservation {
        uint256 inputLeg;
        uint256 input;
        uint256 output;
        uint160 price;
    }

    struct RollbackObservation {
        bytes state;
        uint256 claim;
        uint256[2] caller;
        uint256[2] manager;
        uint256[2] hook;
        uint256[4] fees;
        uint256[2] growth;
        uint256[2] checkpoints;
        uint256[2] booked;
        uint256 allowance;
    }

    IStandardExchangeProxy internal g6Vault;
    IPoolManager internal g6Manager;
    PoolKey internal g6Key;
    IERC20[2] internal g6Tokens;
    uint256[2] internal g6Units;

    function _g6Blocked(bytes memory data_) internal virtual returns (bytes memory);
    function _g6ExternalSwap(bool zeroForOne_, uint256 amount_) internal virtual;
    function _g6Repair() internal virtual;
    function _g6Rates() internal pure virtual returns (uint256, uint256) { return (0, 0); }

    function _startG6(IStandardExchangeProxy vault_, IPoolManager manager_, PoolKey memory key_,
        IERC20 token0_, IERC20 token1_, uint256 unit0_, uint256 unit1_) internal
    {
        g6Vault = vault_; g6Manager = manager_; g6Key = key_;
        g6Tokens = [token0_, token1_]; g6Units = [unit0_, unit1_];
        vault_.approve(address(vault_), type(uint256).max);
    }

    // tag::test_externalTransitionsPreserveHolderClaimSequentially[]
    /// @notice Carries external deposit/swap projections forward without replacing them with live snapshots.
    function test_externalTransitionsPreserveHolderClaimSequentially() public {
        for (uint256 leg; leg < 2; ++leg) {
            uint256 saved = vm.snapshotState();
            address holder = makeAddr("G6 passive holder");
            g6Vault.transfer(holder, g6Vault.balanceOf(address(this)) / 4);
            (bytes memory state,) = Transition(address(g6Vault)).quoteState(address(g6Tokens[leg]), holder);
            Step[4] memory projected;
            // Both deposit input faces, interspersed with a separate caller's opposite-to-selected swaps.
            // Project the WHOLE sequence before execution: liquidity overlays are relative
            // to this original manager state, not to a partly executed sequence.
            for (uint256 step; step < 4; ++step) {
                projected[step] = _projectExternalStep(state, leg, step);
                state = projected[step].next;
            }
            for (uint256 step; step < 4; ++step) _externalStep(projected[step], holder, leg, step);
            assertTrue(vm.revertToStateAndDelete(saved));
        }
    }
    // end::test_externalTransitionsPreserveHolderClaimSequentially[]

    function _projectExternalStep(bytes memory state_, uint256 leg_, uint256 step_)
        private view returns (Step memory f)
    {
        bool deposit = step_ % 2 == 0;
        uint256 inputLeg = deposit ? step_ / 2 : 1 - leg_;
        uint256 amount = deposit ? g6Units[inputLeg] : g6Units[inputLeg] / 100;
        if (deposit) {
            (f.next, f.quantity, f.claim) = ExternalQuote(address(g6Vault)).quoteExternalDeposit(
                state_, address(g6Tokens[inputLeg]), amount);
        } else {
            (f.next, f.quantity, f.claim) = ExternalQuote(address(g6Vault)).quoteExternalExchange(
                state_, address(g6Tokens[inputLeg]), amount);
        }
        assertGt(f.quantity, 0, "nonzero external operation");
        assertEq(Transition(address(g6Vault)).quoteAssets(f.next,
            Transition(address(g6Vault)).quoteShareBalance(f.next)), f.claim);
    }

    function _externalStep(Step memory f, address holder_, uint256 leg_, uint256 step_) private {
        bool deposit = step_ % 2 == 0;
        uint256 inputLeg = deposit ? step_ / 2 : 1 - leg_;
        uint256 amount = deposit ? g6Units[inputLeg] : g6Units[inputLeg] / 100;
        address recipient = makeAddr("G6 external recipient");
        IERC20 output = deposit ? IERC20(address(g6Vault)) : g6Tokens[leg_];
        assertEq(g6Vault.previewExchangeIn(g6Tokens[inputLeg], amount, output), f.quantity);
        f.payerBalance = g6Tokens[inputLeg].balanceOf(address(this));
        f.recipientBalance = output.balanceOf(recipient);
        f.supply = g6Vault.totalSupply(); f.holderShares = g6Vault.balanceOf(holder_);
        f.fees = _g6Fees();
        vm.recordLogs();
        assertEq(g6Vault.exchangeIn(g6Tokens[inputLeg], amount, output, f.quantity,
            recipient, false, block.timestamp), f.quantity);
        _assertG6Fees(vm.getRecordedLogs(), f.fees);
        assertEq(f.payerBalance - g6Tokens[inputLeg].balanceOf(address(this)), amount, "external debit");
        assertEq(output.balanceOf(recipient) - f.recipientBalance, f.quantity, "separate recipient");
        assertEq(g6Vault.balanceOf(holder_), f.holderShares, "passive holder is not mint recipient");
        assertEq(g6Vault.totalSupply(), f.supply + (deposit ? f.quantity : 0), "exact supply");
        _assertG6Projection(f.next, leg_, holder_, f.claim, false);
    }

    // tag::test_redemptionTransitionAndSYMatchAfterExternalSequence[]
    /// @notice R5/R9: after fee-bearing activity, the same funded burn matches SE and SY field by field.
    function test_redemptionTransitionAndSYMatchAfterExternalSequence() public {
        for (uint256 leg; leg < 2; ++leg) {
            uint256 saved = vm.snapshotState();
            _g6ExternalSwap(leg == 0, 10 * g6Units[leg]);
            uint256 identical = vm.snapshotState();
            bytes memory se = _redeemTransition(leg, false);
            assertTrue(vm.revertToStateAndDelete(identical));
            bytes memory sy = _redeemTransition(leg, true);
            _assertG6Fields(abi.decode(se, (Shapes.Snapshot)), abi.decode(sy, (Shapes.Snapshot)));
            assertTrue(vm.revertToStateAndDelete(saved));
        }
    }
    // end::test_redemptionTransitionAndSYMatchAfterExternalSequence[]

    function _redeemTransition(uint256 leg_, bool sy_) private returns (bytes memory actual_) {
        (bytes memory state,) = Transition(address(g6Vault)).quoteState(address(g6Tokens[leg_]), address(this));
        Exit memory f = _exitQuote(state, g6Vault.balanceOf(address(this)) / 1000);
        f.balance = g6Tokens[leg_].balanceOf(address(this)); f.fees = _g6Fees();
        assertEq(g6Vault.previewExchangeIn(IERC20(address(g6Vault)), f.burn, g6Tokens[leg_]), f.output);
        vm.recordLogs();
        uint256 paid = sy_
            ? SY(address(g6Vault)).redeem(address(this), f.burn, address(g6Tokens[leg_]), f.output, false)
            : g6Vault.exchangeIn(IERC20(address(g6Vault)), f.burn, g6Tokens[leg_], f.output,
                address(this), false, block.timestamp);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        _assertG6Fees(logs, f.fees);
        _assertExitReceipt(f, leg_, paid);
        (SwapObservation memory conversion, uint256 count) = _firstG6Swap(logs);
        assertGt(count, 0, "actual entitlement conversion");
        assertEq(conversion.inputLeg, 1 - leg_);
        assertEq(conversion.input, f.entitled[1 - leg_], "full-fill control");
        assertEq(paid, f.entitled[leg_] + _g6Net(conversion.output), "caller excludes holder repair proceeds");
        actual_ = _assertG6Projection(f.next, leg_, address(this), f.claim, false);
    }

    // tag::test_partialConversionRetainsOpposingEntitlementAndProjectedBook[]
    /// @notice Required F6 partial fill, selected token0. A quote rejection is a failing regression, not success.
    function test_partialConversionRetainsOpposingEntitlementAndProjectedBook() public {
        _partialConversion(0);
    }
    // end::test_partialConversionRetainsOpposingEntitlementAndProjectedBook[]

    // tag::test_partialConversionRetainsOpposingEntitlementAndProjectedBook_token1[]
    /// @notice Symmetric token1 case, independently runnable even if token0 fails.
    function test_partialConversionRetainsOpposingEntitlementAndProjectedBook_token1() public {
        _partialConversion(1);
    }
    // end::test_partialConversionRetainsOpposingEntitlementAndProjectedBook_token1[]

    // tag::test_partialConversionLateMinimumRollsBackBothFaces[]
    /// @notice Actual partial-fill payout plus one fails late and restores every observed economic field.
    function test_partialConversionLateMinimumRollsBackBothFaces() public {
        for (uint256 leg; leg < 2; ++leg) {
            uint256 clean = vm.snapshotState();
            g6Tokens[1 - leg].transfer(address(g6Vault), 5e31);
            RollbackObservation memory before = _g6RollbackObservation(leg);
            uint256 burn = g6Vault.balanceOf(address(this));
            uint256 control = vm.snapshotState();
            Exit memory f = _exitQuote(before.state, burn);
            f.balance = g6Tokens[leg].balanceOf(address(this)); f.fees = _g6Fees();
            vm.recordLogs();
            uint256 actual = g6Vault.exchangeIn(IERC20(address(g6Vault)), burn, g6Tokens[leg], f.output,
                address(this), false, block.timestamp);
            _assertPartialResult(f, leg, actual, vm.getRecordedLogs());
            assertTrue(vm.revertToStateAndDelete(control));
            vm.expectRevert(abi.encodeWithSignature("UniswapV4ExchangeIn_SlippageExceeded()"));
            g6Vault.exchangeIn(IERC20(address(g6Vault)), burn, g6Tokens[leg], actual + 1,
                address(this), false, block.timestamp);
            _assertG6Rollback(before, leg);
            assertTrue(vm.revertToStateAndDelete(clean));
        }
    }
    // end::test_partialConversionLateMinimumRollsBackBothFaces[]

    // tag::test_redemptionAlreadyAtDirectionalLimitRetainsFullOpposingEntitlement[]
    /// @notice Real core establishes each endpoint; F6 then pays only selected inventory and swaps nothing.
    function test_redemptionAlreadyAtDirectionalLimitRetainsFullOpposingEntitlement() public {
        for (uint256 leg; leg < 2; ++leg) {
            uint256 clean = vm.snapshotState();
            _redemptionAtLimit(leg);
            assertTrue(vm.revertToStateAndDelete(clean));
        }
    }
    // end::test_redemptionAlreadyAtDirectionalLimitRetainsFullOpposingEntitlement[]

    function _redemptionAtLimit(uint256 leg_) private {
        _g6ExternalSwap(leg_ == 1, 5e31);
        (uint160 price,,,) = StateLibrary.getSlot0(g6Manager, g6Key.toId());
        assertEq(price, leg_ == 1 ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1);
        g6Tokens[1 - leg_].transfer(address(g6Vault), 1e20);
        (bytes memory state,) = Transition(address(g6Vault)).quoteState(address(g6Tokens[leg_]), address(this));
        Exit memory f = _exitQuote(state, g6Vault.balanceOf(address(this)));
        assertGt(f.entitled[1 - leg_], 0, "full opposing entitlement must exist");
        assertEq(f.output, f.entitled[leg_], "zero conversion cannot augment selected payout");
        assertEq(g6Vault.previewExchangeIn(IERC20(address(g6Vault)), f.burn, g6Tokens[leg_]), f.output);
        f.balance = g6Tokens[leg_].balanceOf(address(this)); f.fees = _g6Fees();
        vm.recordLogs();
        uint256 paid = g6Vault.exchangeIn(IERC20(address(g6Vault)), f.burn, g6Tokens[leg_], f.output,
            address(this), false, block.timestamp);
        _assertAtLimitResult(f, leg_, paid, vm.getRecordedLogs());
    }

    function _assertAtLimitResult(Exit memory f_, uint256 leg_, uint256 paid_, Vm.Log[] memory logs_) private {
        (, uint256 count) = _firstG6Swap(logs_);
        assertEq(count, 0, "no conversion or repair swap at this endpoint fixture");
        _assertG6Fees(logs_, f_.fees);
        _assertExitReceipt(f_, leg_, paid_);
        bytes memory actual = _assertG6Projection(f_.next, leg_, address(this), f_.claim, false);
        Shapes.Snapshot memory afterBook = abi.decode(actual, (Shapes.Snapshot));
        assertEq(afterBook.pool.sqrtPriceX96, f_.beforeBook.pool.sqrtPriceX96);
        _assertPartialOpposingCash(f_, afterBook, leg_, 0, logs_);
        uint256[2] memory principal = _g6Principal(afterBook, afterBook.positionLiquidity);
        uint256 backing = leg_ == 0 ? afterBook.free1 + afterBook.fees1 + principal[1]
            : afterBook.free0 + afterBook.fees0 + principal[0];
        assertGe(backing, f_.entitled[1 - leg_], "entire unconverted entitlement remains backing");
    }

    function _g6RollbackObservation(uint256 leg_) private view returns (RollbackObservation memory f) {
        (f.state, f.claim) = Transition(address(g6Vault)).quoteState(address(g6Tokens[leg_]), address(this));
        Shapes.Snapshot memory q = abi.decode(f.state, (Shapes.Snapshot));
        for (uint256 i; i < 2; ++i) {
            f.caller[i] = g6Tokens[i].balanceOf(address(this));
            f.manager[i] = g6Tokens[i].balanceOf(address(g6Manager));
            f.hook[i] = g6Tokens[i].balanceOf(address(g6Key.hooks));
            f.booked[i] = g6Vault.reserveOfToken(address(g6Tokens[i]));
        }
        f.fees = _g6Fees();
        (f.growth[0], f.growth[1]) = StateLibrary.getFeeGrowthGlobals(g6Manager, g6Key.toId());
        (, f.checkpoints[0], f.checkpoints[1]) = StateLibrary.getPositionInfo(
            g6Manager, g6Key.toId(), address(g6Vault), q.lower, q.upper, bytes32(0));
        f.allowance = g6Vault.allowance(address(this), address(g6Vault));
    }

    function _assertG6Rollback(RollbackObservation memory before_, uint256 leg_) private {
        // The preceding donation was a separate action; rollback preserves its unbooked status.
        (bytes memory actual, uint256 claim) = Transition(address(g6Vault)).quoteState(address(g6Tokens[leg_]), address(this));
        _assertG6Fields(abi.decode(before_.state, (Shapes.Snapshot)), abi.decode(actual, (Shapes.Snapshot)));
        assertEq(claim, before_.claim);
        RollbackObservation memory after_ = _g6RollbackObservation(leg_);
        for (uint256 i; i < 2; ++i) {
            assertEq(after_.caller[i], before_.caller[i]); assertEq(after_.manager[i], before_.manager[i]);
            assertEq(after_.hook[i], before_.hook[i]); assertEq(after_.growth[i], before_.growth[i]);
            assertEq(after_.checkpoints[i], before_.checkpoints[i]);
            assertEq(after_.booked[i], before_.booked[i]);
        }
        for (uint256 i; i < 4; ++i) assertEq(after_.fees[i], before_.fees[i]);
        assertEq(after_.allowance, before_.allowance);
        assertEq(g6Vault.totalSupply(), abi.decode(before_.state, (Shapes.Snapshot)).supply);
        assertEq(g6Vault.balanceOf(address(this)), abi.decode(before_.state, (Shapes.Snapshot)).shares);
        assertEq(g6Vault.reserveOfToken(address(g6Vault)), 0); assertEq(g6Vault.balanceOf(address(g6Vault)), 0);
    }

    function _partialConversion(uint256 leg_) private {
        // Six-decimal real fixtures put full-range input capacity below int128.max.
        // Actual donation, not an edited quote or a storage-created balance.
        g6Tokens[1 - leg_].transfer(address(g6Vault), 5e31);
        uint256 burn = _assertPartialCoreControl(leg_);
        // Do not expectRevert QuoteWorkLimit: plan F6 requires retaining this residual.
        // Supply an actual holder snapshot, never the edited local reference in the control.
        (bytes memory state,) = Transition(address(g6Vault)).quoteState(address(g6Tokens[leg_]), address(this));
        Exit memory f = _exitQuote(state, burn);
        f.balance = g6Tokens[leg_].balanceOf(address(this)); f.fees = _g6Fees();
        assertEq(g6Vault.previewExchangeIn(IERC20(address(g6Vault)), burn, g6Tokens[leg_]), f.output);
        vm.recordLogs();
        uint256 paid = g6Vault.exchangeIn(IERC20(address(g6Vault)), burn, g6Tokens[leg_], f.output,
            address(this), false, block.timestamp);
        _assertPartialResult(f, leg_, paid, vm.getRecordedLogs());
    }

    function _assertPartialCoreControl(uint256 leg_) private returns (uint256 burn) {
        // Zero-holder discovery avoids valuing an enormous claim before the independent
        // core control. Only the local reference below receives the real holder balance.
        (bytes memory state,) = Transition(address(g6Vault)).quoteState(address(g6Tokens[leg_]), address(0));
        Shapes.Snapshot memory beforeBook = abi.decode(state, (Shapes.Snapshot));
        beforeBook.shares = g6Vault.balanceOf(address(this));
        // Burn the caller's entire balance (the activation sink remains). A half
        // burn leaves enough incumbent donation to hide a lost residual in a >= check.
        burn = beforeBook.shares;
        uint256[2] memory entitled = _g6Entitlement(beforeBook, burn);
        // Establish partial-fill reachability against the real core, then restore EXACTLY.
        // This control has MORE active liquidity than F6 after its required removal.
        uint256 saved = vm.snapshotState();
        vm.recordLogs();
        _g6ExternalSwap(leg_ == 1, entitled[1 - leg_]);
        (SwapObservation memory control, uint256 count) = _firstG6Swap(vm.getRecordedLogs());
        assertEq(count, 1); assertEq(control.inputLeg, 1 - leg_);
        assertGt(control.input, 0); assertLt(control.input, entitled[1 - leg_], "real price-limited partial fill");
        assertEq(control.price, leg_ == 1 ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1);
        assertTrue(vm.revertToStateAndDelete(saved));
    }

    function _assertPartialResult(Exit memory f, uint256 leg_, uint256 paid, Vm.Log[] memory logs_) private {
        _assertG6Fees(logs_, f.fees);
        (SwapObservation memory conversion, uint256 swaps) = _firstG6Swap(logs_);
        assertEq(swaps, 1, "endpoint fixture has only the required conversion");
        assertEq(conversion.inputLeg, 1 - leg_);
        assertGt(conversion.input, 0); assertLt(conversion.input, f.entitled[1 - leg_]);
        assertEq(paid, f.entitled[leg_] + _g6Net(conversion.output), "only filled output is paid");
        _assertExitReceipt(f, leg_, paid);
        bytes memory actual = _assertG6Projection(f.next, leg_, address(this), f.claim, false);
        Shapes.Snapshot memory afterBook = abi.decode(actual, (Shapes.Snapshot));
        _assertPartialOpposingCash(f, afterBook, leg_, conversion.input, logs_);
        uint256[2] memory principal = _g6Principal(afterBook, afterBook.positionLiquidity);
        uint256 residual = f.entitled[1 - leg_] - conversion.input;
        assertGt(residual, 0, "unspent caller entitlement exists");
        assertGt(residual, 5e31 / 2, "residual dominates the tiny remaining sink backing");
        uint256 opposingBook = leg_ == 0
            ? afterBook.free1 + afterBook.fees1 + principal[1]
            : afterBook.free0 + afterBook.fees0 + principal[0];
        assertGe(opposingBook, residual, "retained entitlement remains in booked holder backing");
    }

    function _assertPartialOpposingCash(Exit memory f_, Shapes.Snapshot memory after_, uint256 leg_,
        uint256 spent_, Vm.Log[] memory logs_) private view
    {
        Shapes.Snapshot memory at = f_.beforeBook;
        uint256 opposing = 1 - leg_;
        int256 cash = int256(opposing == 0 ? at.free0 + at.fees0 : at.free1 + at.fees1);
        // Reconstruct every signed liquidity settlement at its actual event-time price.
        // The required swap's unspent entitlement is explicitly returned to this ledger.
        cash = cash - int256(f_.entitled[opposing]) + int256(f_.entitled[opposing] - spent_);
        // Principal removal funds part of the conversion, so use signed cash below.
        _assertPartialSettlements(f_, after_, at, opposing, cash, logs_);
    }

    function _assertPartialSettlements(Exit memory f_, Shapes.Snapshot memory after_, Shapes.Snapshot memory at_,
        uint256 opposing_, int256 cash_, Vm.Log[] memory logs_) private view
    {
        for (uint256 i; i < logs_.length; ++i) {
            if (_g6ManagerLog(logs_[i], IPoolManager.Swap.selector)) {
                (,, at_.pool.sqrtPriceX96,,,) = abi.decode(logs_[i].data, (int128, int128, uint160, uint128, int24, uint24));
            } else if (_g6ManagerLog(logs_[i], IPoolManager.ModifyLiquidity.selector)) {
                assertEq(logs_[i].topics[2], bytes32(uint256(uint160(address(g6Vault)))));
                (,, int256 delta,) = abi.decode(logs_[i].data, (int24, int24, int256, bytes32));
                uint256[2] memory principal = _g6Settlement(at_, uint128(uint256(delta < 0 ? -delta : delta)), delta > 0);
                cash_ += delta < 0 ? int256(principal[opposing_]) : -int256(principal[opposing_]);
            }
        }
        (uint256 growth0, uint256 growth1) = StateLibrary.getFeeGrowthInside(g6Manager, g6Key.toId(), at_.lower, at_.upper);
        uint256 growth = opposing_ == 0 ? growth0 : growth1;
        unchecked { growth -= f_.growth[opposing_]; }
        uint128 remaining = f_.beforeBook.positionLiquidity
            - uint128(Math.mulDiv(f_.beforeBook.positionLiquidity, f_.burn, f_.beforeBook.supply));
        cash_ += int256(Math.mulDiv(growth, remaining, uint256(1) << 128));
        assertEq(int256(opposing_ == 0 ? after_.free0 : after_.free1), cash_,
            "exact unspent opposing custody after fees and all placement settlements");
    }

    function _exitQuote(bytes memory state_, uint256 burn_) private view returns (Exit memory f) {
        f.beforeBook = abi.decode(state_, (Shapes.Snapshot)); f.burn = burn_;
        (f.growth[0], f.growth[1]) = StateLibrary.getFeeGrowthInside(
            g6Manager, g6Key.toId(), f.beforeBook.lower, f.beforeBook.upper);
        uint256 used;
        (f.next, used, f.output, f.claim) = Transition(address(g6Vault)).quoteTransition(
            state_, Transition.Operation.RedeemExactIn, burn_);
        assertEq(used, burn_); assertGt(f.output, 0);
        f.entitled = _g6Entitlement(f.beforeBook, burn_);
    }

    // tag::test_directExactInputStillRejectsPriceLimitedFill[]
    /// @notice F6's retained entitlement must not turn a direct caller's exact input into a partial trade.
    function test_directExactInputStillRejectsPriceLimitedFill() public {
        for (uint256 leg; leg < 2; ++leg) {
            (bytes memory state, uint256 claim) = Transition(address(g6Vault)).quoteState(address(g6Tokens[leg]), address(this));
            uint256 beforeInput = g6Tokens[leg].balanceOf(address(this));
            uint256 beforeOutput = g6Tokens[1 - leg].balanceOf(address(this));
            vm.expectRevert(abi.encodeWithSignature("QuoteWorkLimit()"));
            g6Vault.previewExchangeIn(g6Tokens[leg], 5e31, g6Tokens[1 - leg]);
            vm.expectRevert(abi.encodeWithSignature("QuoteWorkLimit()"));
            g6Vault.exchangeIn(g6Tokens[leg], 5e31, g6Tokens[1 - leg], 0, address(this), false, block.timestamp);
            assertEq(g6Tokens[leg].balanceOf(address(this)), beforeInput);
            assertEq(g6Tokens[1 - leg].balanceOf(address(this)), beforeOutput);
            _assertG6Projection(state, leg, address(this), claim, false);
        }
    }
    // end::test_directExactInputStillRejectsPriceLimitedFill[]

    function _assertExitReceipt(Exit memory f_, uint256 leg_, uint256 paid_) private view {
        assertEq(paid_, f_.output);
        assertEq(g6Tokens[leg_].balanceOf(address(this)) - f_.balance, paid_);
        assertEq(g6Vault.totalSupply(), f_.beforeBook.supply - f_.burn);
        assertEq(g6Vault.balanceOf(address(this)), f_.beforeBook.shares - f_.burn);
    }

    // tag::test_fullRangeLifecycleActivationWalkBlockedJoinRepair[]
    /// @notice Ordinary activation, two spot directions and blocked joins retain the sole full-range position.
    function test_fullRangeLifecycleActivationWalkBlockedJoinRepair() public {
        _assertG6FullRange();
        for (uint256 leg; leg < 2; ++leg) {
            Shapes.Snapshot memory beforeWalk = _g6Snapshot(leg, address(this), false);
            uint256[4] memory fees = _g6Fees();
            vm.recordLogs();
            _g6ExternalSwap(leg == 0, 20_000 * g6Units[leg]);
            _assertG6Fees(vm.getRecordedLogs(), fees);
            Shapes.Snapshot memory walked = _g6Snapshot(leg, address(this), false);
            assertEq(walked.positionLiquidity, beforeWalk.positionLiquidity, "external walk cannot change owned L");
            assertEq(walked.free0, beforeWalk.free0); assertEq(walked.free1, beforeWalk.free1);
            assertTrue(walked.pool.tick != beforeWalk.pool.tick, "actual spot walk");
            _assertG6Core(walked); _assertG6FullRange();
            _blockedJoin(leg);
            Shapes.Snapshot memory beforeRepair = _g6Snapshot(leg, address(this), false);
            uint256[2] memory callerBefore = [g6Tokens[0].balanceOf(address(this)), g6Tokens[1].balanceOf(address(this))];
            fees = _g6Fees();
            vm.recordLogs();
            _g6Repair();
            Vm.Log[] memory logs = vm.getRecordedLogs();
            _assertG6Fees(logs, fees);
            Shapes.Snapshot memory repaired = _g6Snapshot(leg, address(this), false);
            assertEq(repaired.supply, beforeRepair.supply); assertEq(repaired.shares, beforeRepair.shares);
            _assertRepairLiquidity(beforeRepair, repaired, logs);
            _assertRepairCash(beforeRepair, repaired, logs);
            assertEq(g6Tokens[0].balanceOf(address(this)), callerBefore[0], "repair pays no token0 reward");
            assertEq(g6Tokens[1].balanceOf(address(this)), callerBefore[1], "repair pays no token1 reward");
            _assertG6Core(repaired); _assertG6FullRange();
        }
    }
    // end::test_fullRangeLifecycleActivationWalkBlockedJoinRepair[]

    function _blockedJoin(uint256 leg_) private {
        (bytes memory state,) = abi.decode(_g6Blocked(abi.encodeCall(Transition.quoteState,
            (address(g6Tokens[leg_]), address(this)))), (bytes, uint256));
        Shapes.Snapshot memory beforeBook = abi.decode(state, (Shapes.Snapshot));
        Step memory f;
        uint256 used;
        (f.next, used, f.quantity, f.claim) = Transition(address(g6Vault)).quoteTransition(
            state, Transition.Operation.DepositExactIn, g6Units[leg_]);
        assertEq(used, g6Units[leg_]); assertGt(f.quantity, 0);
        f.payerBalance = g6Tokens[leg_].balanceOf(address(this)); f.fees = _g6Fees();
        vm.recordLogs();
        assertEq(abi.decode(_g6Blocked(abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (g6Tokens[leg_], used, IERC20(address(g6Vault)), f.quantity, address(this), false, block.timestamp))),
            (uint256)), f.quantity);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        _assertG6Fees(logs, f.fees);
        (, uint256 swaps) = _firstG6Swap(logs); assertEq(swaps, 0, "blocked join never swaps");
        assertEq(f.payerBalance - g6Tokens[leg_].balanceOf(address(this)), used);
        assertEq(g6Vault.totalSupply(), beforeBook.supply + f.quantity);
        assertEq(g6Vault.balanceOf(address(this)), beforeBook.shares + f.quantity);
        bytes memory actual = _assertG6Projection(f.next, leg_, address(this), f.claim, true);
        Shapes.Snapshot memory afterBook = abi.decode(actual, (Shapes.Snapshot));
        assertEq(afterBook.positionLiquidity, beforeBook.positionLiquidity);
        assertEq(afterBook.free0, beforeBook.free0 + (leg_ == 0 ? used : 0));
        assertEq(afterBook.free1, beforeBook.free1 + (leg_ == 1 ? used : 0));
        assertEq(afterBook.fees0, beforeBook.fees0); assertEq(afterBook.fees1, beforeBook.fees1);
        _assertG6FullRange();
    }

    function _assertRepairLiquidity(Shapes.Snapshot memory before_, Shapes.Snapshot memory after_, Vm.Log[] memory logs_)
        private view
    {
        int256 change;
        for (uint256 i; i < logs_.length; ++i) {
            if (!_g6ManagerLog(logs_[i], IPoolManager.ModifyLiquidity.selector)) continue;
            assertEq(logs_[i].topics[2], bytes32(uint256(uint160(address(g6Vault)))));
            (int24 lower, int24 upper, int256 delta, bytes32 salt) = abi.decode(logs_[i].data, (int24, int24, int256, bytes32));
            assertEq(lower, before_.lower); assertEq(upper, before_.upper); assertEq(salt, bytes32(0));
            change += delta;
        }
        assertEq(int256(uint256(after_.positionLiquidity)), int256(uint256(before_.positionLiquidity)) + change,
            "all actual repair removals/additions reconciled");
    }

    function _assertRepairCash(Shapes.Snapshot memory before_, Shapes.Snapshot memory after_, Vm.Log[] memory logs_)
        private view
    {
        int256[2] memory cash = [int256(before_.free0), int256(before_.free1)];
        bytes32 vaultTopic = bytes32(uint256(uint160(address(g6Vault))));
        for (uint256 i; i < logs_.length; ++i) {
            Vm.Log memory entry = logs_[i];
            if (entry.topics.length != 3 || entry.topics[0] != IERC20Events.Transfer.selector) continue;
            if (entry.emitter != address(g6Tokens[0]) && entry.emitter != address(g6Tokens[1])) continue;
            uint256 leg = entry.emitter == address(g6Tokens[0]) ? 0 : 1;
            int256 amount = int256(abi.decode(entry.data, (uint256)));
            if (entry.topics[1] == vaultTopic) cash[leg] -= amount;
            if (entry.topics[2] == vaultTopic) cash[leg] += amount;
        }
        assertEq(int256(after_.free0), cash[0], "repair token0 settlement ledger");
        assertEq(int256(after_.free1), cash[1], "repair token1 settlement ledger");
    }

    function _assertG6Projection(bytes memory expected_, uint256 leg_, address holder_, uint256 claim_, bool blocked_)
        private returns (bytes memory actual_)
    {
        uint256 claim;
        if (blocked_) {
            (actual_, claim) = abi.decode(_g6Blocked(abi.encodeCall(Transition.quoteState,
                (address(g6Tokens[leg_]), holder_))), (bytes, uint256));
        } else (actual_, claim) = Transition(address(g6Vault)).quoteState(address(g6Tokens[leg_]), holder_);
        Shapes.Snapshot memory expected = abi.decode(expected_, (Shapes.Snapshot));
        Shapes.Snapshot memory actual = abi.decode(actual_, (Shapes.Snapshot));
        assertEq(actual.liquidityDelta, 0, "live state has no simulation overlay");
        _assertG6Fields(expected, actual);
        assertEq(claim, claim_, "exact passive/funded holder claim");
        assertEq(Transition(address(g6Vault)).quoteShareBalance(expected_), g6Vault.balanceOf(holder_));
        assertEq(Transition(address(g6Vault)).quoteTotalSupply(expected_), g6Vault.totalSupply());
        _assertG6Core(actual);
    }

    function _g6Snapshot(uint256 leg_, address holder_, bool blocked_) private returns (Shapes.Snapshot memory) {
        bytes memory state;
        if (blocked_) (state,) = abi.decode(_g6Blocked(abi.encodeCall(Transition.quoteState,
            (address(g6Tokens[leg_]), holder_))), (bytes, uint256));
        else (state,) = Transition(address(g6Vault)).quoteState(address(g6Tokens[leg_]), holder_);
        return abi.decode(state, (Shapes.Snapshot));
    }

    function _assertG6Fields(Shapes.Snapshot memory e, Shapes.Snapshot memory a) private pure {
        assertEq(a.vault, e.vault); assertEq(a.token0, e.token0); assertEq(a.idle, e.idle);
        assertEq(a.supply, e.supply, "projected supply"); assertEq(a.shares, e.shares, "projected holder shares");
        assertEq(a.free0, e.free0, "projected local token0"); assertEq(a.free1, e.free1, "projected local token1");
        assertEq(a.fees0, e.fees0, "projected own fees0"); assertEq(a.fees1, e.fees1, "projected own fees1");
        assertEq(a.positionLiquidity, e.positionLiquidity, "projected owned liquidity");
        assertEq(a.lower, e.lower); assertEq(a.upper, e.upper);
        assertEq(a.pool.sqrtPriceX96, e.pool.sqrtPriceX96); assertEq(a.pool.tick, e.pool.tick);
        assertEq(a.pool.liquidity, e.pool.liquidity, "post-removal active liquidity");
        assertEq(a.sleeveWad, e.sleeveWad); assertEq(a.absoluteFloor[0], e.absoluteFloor[0]);
        assertEq(a.absoluteFloor[1], e.absoluteFloor[1]);
        assertEq(a.lowerLiquidityGross, e.lowerLiquidityGross); assertEq(a.upperLiquidityGross, e.upperLiquidityGross);
        assertEq(a.maxLiquidityPerTick, e.maxLiquidityPerTick);
        // Only liquidityDelta is deliberately omitted: it is a cumulative quote overlay,
        // not persisted state. The owned, active and endpoint liquidity above must all match.
    }

    function _assertG6Core(Shapes.Snapshot memory q) private view {
        assertEq(q.free0, g6Tokens[0].balanceOf(address(g6Vault)));
        assertEq(q.free1, g6Tokens[1].balanceOf(address(g6Vault)));
        assertEq(g6Vault.reserveOfToken(address(g6Tokens[0])), q.free0);
        assertEq(g6Vault.reserveOfToken(address(g6Tokens[1])), q.free1);
        assertEq(g6Vault.balanceOf(address(g6Vault)), 0);
        assertEq(g6Vault.reserveOfToken(address(g6Vault)), 0);
        assertEq(address(g6Vault).balance, 0);
        (uint128 liquidity, uint256 last0, uint256 last1) = StateLibrary.getPositionInfo(
            g6Manager, g6Key.toId(), address(g6Vault), q.lower, q.upper, bytes32(0));
        assertEq(q.positionLiquidity, liquidity);
        (uint256 growth0, uint256 growth1) = StateLibrary.getFeeGrowthInside(g6Manager, g6Key.toId(), q.lower, q.upper);
        unchecked { growth0 -= last0; growth1 -= last1; }
        assertEq(q.fees0, Math.mulDiv(growth0, liquidity, uint256(1) << 128), "real own LP checkpoint0");
        assertEq(q.fees1, Math.mulDiv(growth1, liquidity, uint256(1) << 128), "real own LP checkpoint1");
        (uint160 price, int24 tick,,) = StateLibrary.getSlot0(g6Manager, g6Key.toId());
        assertEq(q.pool.sqrtPriceX96, price); assertEq(q.pool.tick, tick);
        assertEq(q.pool.liquidity, StateLibrary.getLiquidity(g6Manager, g6Key.toId()));
        (uint128 lowerGross,) = StateLibrary.getTickLiquidity(g6Manager, g6Key.toId(), q.lower);
        (uint128 upperGross,) = StateLibrary.getTickLiquidity(g6Manager, g6Key.toId(), q.upper);
        assertEq(q.lowerLiquidityGross, lowerGross); assertEq(q.upperLiquidityGross, upperGross);
    }

    function _assertG6FullRange() private {
        Shapes.Snapshot memory q = _g6Snapshot(0, address(this), false);
        int24 lower = TickMath.minUsableTick(g6Key.tickSpacing);
        int24 upper = TickMath.maxUsableTick(g6Key.tickSpacing);
        assertEq(q.lower, lower); assertEq(q.upper, upper);
        assertGt(q.positionLiquidity, 0, "ordinary full-range backing remains");
        assertGt(q.pool.tick, lower); assertLt(q.pool.tick, upper);
        bytes32 lowerSalt = keccak256("indexedex.protocols.dexes.uniswap.v4.position.lowerWing");
        bytes32 upperSalt = keccak256("indexedex.protocols.dexes.uniswap.v4.position.upperWing");
        _assertG6EmptyPosition(-60, 60, bytes32(0));
        _assertG6EmptyPosition(-1800, -60, lowerSalt);
        _assertG6EmptyPosition(60, 1800, upperSalt);
        _assertG6EmptyPosition(lower, upper, lowerSalt);
        _assertG6EmptyPosition(lower, upper, upperSalt);
        _assertG6Core(q);
    }

    function _assertG6EmptyPosition(int24 lower_, int24 upper_, bytes32 salt_) private view {
        (uint128 liquidity,,) = StateLibrary.getPositionInfo(g6Manager, g6Key.toId(), address(g6Vault), lower_, upper_, salt_);
        assertEq(liquidity, 0, "legacy tight/wing position absent");
    }

    function _g6Principal(Shapes.Snapshot memory q, uint128 liquidity_) private pure returns (uint256[2] memory amounts) {
        return _g6Settlement(q, liquidity_, false);
    }

    function _g6Settlement(Shapes.Snapshot memory q, uint128 liquidity_, bool roundUp_) private pure returns (uint256[2] memory amounts) {
        uint160 lower = TickMath.getSqrtPriceAtTick(q.lower);
        uint160 upper = TickMath.getSqrtPriceAtTick(q.upper);
        uint160 price = q.pool.sqrtPriceX96;
        if (price < upper) amounts[0] = SqrtPriceMath.getAmount0Delta(price > lower ? price : lower, upper, liquidity_, roundUp_);
        if (price > lower) amounts[1] = SqrtPriceMath.getAmount1Delta(lower, price < upper ? price : upper, liquidity_, roundUp_);
    }

    function _g6Entitlement(Shapes.Snapshot memory q, uint256 burn_) private pure returns (uint256[2] memory amounts) {
        amounts = _g6Principal(q, uint128(Math.mulDiv(q.positionLiquidity, burn_, q.supply)));
        amounts[0] += Math.mulDiv(q.free0 + q.fees0, burn_, q.supply);
        amounts[1] += Math.mulDiv(q.free1 + q.fees1, burn_, q.supply);
    }

    function _g6ManagerLog(Vm.Log memory log_, bytes32 signature_) private view returns (bool) {
        return log_.emitter == address(g6Manager) && log_.topics.length == 3
            && log_.topics[0] == signature_ && log_.topics[1] == PoolId.unwrap(g6Key.toId());
    }

    function _firstG6Swap(Vm.Log[] memory logs_) private view returns (SwapObservation memory first, uint256 count) {
        for (uint256 i; i < logs_.length; ++i) {
            if (!_g6ManagerLog(logs_[i], IPoolManager.Swap.selector)) continue;
            if (count++ != 0) continue;
            (int128 d0, int128 d1, uint160 price,,,) = abi.decode(logs_[i].data, (int128, int128, uint160, uint128, int24, uint24));
            bool input0 = d0 < 0;
            first = SwapObservation(input0 ? 0 : 1, uint256(-int256(input0 ? d0 : d1)),
                uint256(int256(input0 ? d1 : d0)), price);
        }
    }

    function _g6Fees() private view returns (uint256[4] memory result) {
        if (address(g6Key.hooks) == address(0)) return result;
        IFullSpreadCampaignFeeLedger hook = IFullSpreadCampaignFeeLedger(address(g6Key.hooks));
        for (uint256 i; i < 2; ++i) {
            result[2 * i] = hook.pendingFees(g6Key.toId(), address(g6Tokens[i]));
            result[2 * i + 1] = hook.pendingCreatorTax(g6Key.toId(), address(g6Tokens[i]));
        }
    }

    function _assertG6Fees(Vm.Log[] memory logs_, uint256[4] memory before_) private view {
        if (address(g6Key.hooks) == address(0)) return;
        (uint256 fee, uint256 tax) = _g6Rates();
        uint256[4] memory expected = before_;
        for (uint256 i; i < logs_.length; ++i) {
            if (!_g6ManagerLog(logs_[i], IPoolManager.Swap.selector)) continue;
            (int128 d0, int128 d1,,,,) = abi.decode(logs_[i].data, (int128, int128, uint160, uint128, int24, uint24));
            uint256 leg = d0 > 0 ? 0 : 1;
            uint256 output = uint256(int256(leg == 0 ? d0 : d1));
            expected[2 * leg] += output * fee / 10_000;
            expected[2 * leg + 1] += output * tax / 10_000;
        }
        uint256[4] memory actual = _g6Fees();
        for (uint256 i; i < 4; ++i) assertEq(actual[i], expected[i], "separate measured Pons fee/tax floors");
    }

    function _g6Net(uint256 output_) private pure returns (uint256) {
        (uint256 fee, uint256 tax) = _g6Rates();
        return output_ - output_ * fee / 10_000 - output_ * tax / 10_000;
    }
}
// end::TestBase_FullSpreadG6TransitionLifecycleClosure[]
