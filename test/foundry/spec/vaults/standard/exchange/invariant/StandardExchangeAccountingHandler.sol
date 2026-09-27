// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";

/// @dev APEX R11 money-path campaign shared by production fixtures. Unsupported D32 public
/// pretransfer stays unsupported. Uncaught operation failures abort the campaign rather than
/// incrementing a success counter. All counters start at zero after deployment.
abstract contract StandardExchangeAccountingHandler is Test {
    enum Action { PullDeposit, PushDeposit, Transfer, ExactOut, Donation, EoaReject, ReusedCreditReject, BookedCreditReject, ExactOutMint, RestingCredit, AtomicUnsupported }
    struct Counts { uint256 attempted; uint256 succeeded; uint256 expectedRevert; uint256 unexpectedRevert; }
    struct Checkpoint { uint256 assets; uint256 shares; uint256 quote; }
    IStandardExchangeIn public immutable seIn;
    IERC20 public immutable base;
    IERC20 public immutable share;
    AtomicPretransferCaller public immutable integrator;
    bool public immutable supportsPrepay;
    uint256 public immutable initialLocked;
    address[3] public actors;
    address public immutable attacker;
    uint256 public cycles;
    uint256 public ghost_in;
    uint256 public ghost_out;
    uint256 public ghost_eoaReject;
    uint256 public mintedShares;
    uint256 public burnedShares;
    uint256 public donated;
    uint256 public immutable initialSupply;
    mapping(Action => Counts) public counts;
    mapping(address => uint256) public actorCycles;

    constructor(IStandardExchangeIn seIn_, IERC20 base_, IERC20 share_, bool supportsPrepay_, address a0_, address a1_, address attacker_) {
        seIn = seIn_; base = base_; share = share_;
        supportsPrepay = supportsPrepay_;
        initialLocked = share_.balanceOf(address(1));
        integrator = new AtomicPretransferCaller();
        actors[0] = a0_; actors[1] = a1_; actors[2] = address(0xCA1103);
        attacker = attacker_;
        initialSupply = share_.totalSupply();
    }

    /// @dev Only this selector is targeted. Every randomized call reaches valid money operations
    /// and exact-error attacks. No bootstrap increments; unexpected reverts fail the campaign.
    function cycle(uint256 amountSeed_, uint256 transferSeed_) public virtual {
        address actor = actors[cycles % 3];
        address recipient = actors[(cycles + 1) % 3];
        uint256 phase = cycles % 4;
        ++cycles;
        ++actorCycles[actor];
        uint256 amount = bound(amountSeed_, 1e16, 5 ether);
        _deposit(actor, amount, false);
        _withdraw(actor);
        if (phase == 0) {
            if (supportsPrepay) _deposit(actor, amount / 2, true);
            else _rejectAtomicDelivery(actor, amount / 2);
            _rejectContract(Action.ReusedCreditReject);
        } else if (phase == 1) {
            _mintExactOut(actor, amount / 5);
            _transfer(actor, recipient, transferSeed_);
        } else if (phase == 2) {
            _donate();
            _restingCredit(actor);
            // Sweep/book remaining donation before checking that it cannot be used twice.
            _deposit(actor, amount / 10, false);
            _rejectContract(Action.BookedCreditReject);
        } else {
            _rejectEoa();
            _additionalActions(actor, amountSeed_);
        }
    }

    function _additionalActions(address, uint256) internal virtual {}

    function _restingQuote(uint256 amount_) internal view virtual returns (uint256) {
        return seIn.previewExchangeIn(base, amount_, share);
    }

    function _fund(address actor_, uint256 amount_) internal virtual;

    function _deposit(address actor_, uint256 amount_, bool prepaid_) internal {
        Action action = prepaid_ ? Action.PushDeposit : Action.PullDeposit;
        ++counts[action].attempted;
        _fund(actor_, amount_);
        Checkpoint memory before_ = Checkpoint(base.balanceOf(actor_), share.balanceOf(actor_),
            seIn.previewExchangeIn(base, amount_, share));
        assertGt(before_.quote, 0, "deposit quote nonzero");
        uint256 minted;
        if (prepaid_) {
            vm.prank(actor_);
            base.approve(address(integrator), amount_);
            bytes memory data = _depositData(actor_, amount_, before_.quote, true);
            minted = abi.decode(integrator.consumePretransfer(base, actor_, address(seIn), amount_, data), (uint256));
        } else {
            vm.startPrank(actor_);
            base.approve(address(seIn), amount_);
            minted = seIn.exchangeIn(base, amount_, share, before_.quote, actor_, false, block.timestamp + 1 hours);
            vm.stopPrank();
        }
        assertEq(before_.assets - base.balanceOf(actor_), amount_, "only declared principal debited");
        assertEq(share.balanceOf(actor_) - before_.shares, minted, "actual recipient issuance");
        assertEq(minted, before_.quote, "deposit preview matches execution");
        assertEq(base.balanceOf(address(integrator)), 0, "exact-in refunds nothing");
        mintedShares += minted;
        ++ghost_in;
        ++counts[action].succeeded;
    }


    function _mintExactOut(address actor_, uint256 amount_) internal {
        ++counts[Action.ExactOutMint].attempted;
        uint256 desired = seIn.previewExchangeIn(base, amount_, share);
        assertGt(desired, 0, "exact-out mint nonzero");
        IStandardExchangeOut seOut = IStandardExchangeOut(address(seIn));
        uint256 needed = seOut.previewExchangeOut(base, share, desired);
        uint256 maximum = needed + needed / 10 + 1;
        _fund(actor_, maximum);
        Checkpoint memory before_ = Checkpoint(base.balanceOf(actor_), share.balanceOf(actor_), needed);
        uint256 used = _executeMint(actor_, maximum, desired);
        assertEq(used, before_.quote, "same-state exact-out mint quote");
        assertLe(used, maximum, "input bounded by max");
        assertEq(before_.assets - base.balanceOf(actor_), used, "net debit after bounded refund");
        assertEq(share.balanceOf(actor_) - before_.shares, desired, "exact requested shares minted");
        assertEq(base.balanceOf(address(integrator)), 0, "refund returned to payer");
        mintedShares += desired;
        ++counts[Action.ExactOutMint].succeeded;
    }

    function _executeMint(address actor_, uint256 maximum, uint256 desired) internal returns (uint256 used) {
        if (supportsPrepay) {
            vm.prank(actor_);
            base.approve(address(integrator), maximum);
            bytes memory data = _mintData(actor_, maximum, desired, true);
            used = abi.decode(integrator.consumePretransfer(base, actor_, address(seIn), maximum, data), (uint256));
            assertEq(base.balanceOf(address(integrator)), maximum - used, "only unused bounded credit refunded");
            integrator.execute(address(base), abi.encodeCall(IERC20.transfer, (actor_, maximum - used)));
        } else {
            vm.startPrank(actor_);
            base.approve(address(seIn), maximum);
            used = IStandardExchangeOut(address(seIn)).exchangeOut(base, maximum, share, desired, actor_, false, block.timestamp + 1 hours);
            vm.stopPrank();
        }
    }

    function _mintData(address actor_, uint256 maximum_, uint256 desired_, bool prepaid_) internal view returns (bytes memory) {
        return abi.encodeCall(IStandardExchangeOut.exchangeOut,
            (base, maximum_, share, desired_, actor_, prepaid_, block.timestamp + 1 hours));
    }

    function _restingCredit(address actor_) internal {
        ++counts[Action.RestingCredit].attempted;
        uint256 amount = 1e8;
        bytes memory data = _depositData(actor_, amount, 0, true);
        if (!supportsPrepay) {
            bytes32 before_ = _state();
            vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, amount, uint256(0)));
            integrator.execute(address(seIn), data);
            assertEq(_state(), before_, "D32 resting principal is backing, never public credit");
            ++counts[Action.RestingCredit].expectedRevert;
            return;
        }
        uint256 quote = _restingQuote(amount);
        uint256 beforeShares = share.balanceOf(actor_);
        uint256 beforeBase = base.balanceOf(address(integrator));
        uint256 minted = abi.decode(integrator.execute(address(seIn), data), (uint256));
        assertGt(minted, 0, "resting credit positive control issues");
        assertEq(minted, quote, "no issuance beyond partial credited input");
        assertEq(share.balanceOf(actor_) - beforeShares, minted, "partial resting input issues once");
        assertEq(base.balanceOf(address(integrator)), beforeBase, "exact-input has no residual refund");
        mintedShares += minted;
        ++counts[Action.RestingCredit].succeeded;
    }

    function _rejectAtomicDelivery(address actor_, uint256 amount_) internal {
        ++counts[Action.AtomicUnsupported].attempted;
        _fund(actor_, amount_);
        vm.prank(actor_);
        base.approve(address(integrator), amount_);
        uint256 payerBefore = base.balanceOf(actor_);
        uint256 allowanceBefore = base.allowance(actor_, address(integrator));
        bytes32 before_ = _state();
        bytes memory data = _depositData(actor_, amount_, 0, true);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, amount_, uint256(0)));
        integrator.consumePretransfer(base, actor_, address(seIn), amount_, data);
        assertEq(_state(), before_, "unsupported atomic delivery rolls back");
        assertEq(base.balanceOf(actor_), payerBefore, "atomic transfer rolls back payer");
        assertEq(base.allowance(actor_, address(integrator)), allowanceBefore, "atomic transfer rolls back allowance");
        ++counts[Action.AtomicUnsupported].expectedRevert;
    }

    function _depositData(address recipient_, uint256 amount_, uint256 minimum_, bool prepaid_) internal view returns (bytes memory) {
        return abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (base, amount_, share, minimum_, recipient_, prepaid_, block.timestamp + 1 hours));
    }

    function _transfer(address from_, address to_, uint256 seed_) internal {
        ++counts[Action.Transfer].attempted;
        uint256 fromBefore = share.balanceOf(from_);
        uint256 toBefore = share.balanceOf(to_);
        uint256 amount = fromBefore / bound(seed_, 4, 8);
        assertGt(amount, 0, "transfer is nonzero");
        vm.prank(from_);
        share.transfer(to_, amount);
        assertEq(fromBefore - share.balanceOf(from_), amount, "transfer debit");
        assertEq(share.balanceOf(to_) - toBefore, amount, "transfer credit");
        ++counts[Action.Transfer].succeeded;
    }

    function _withdraw(address actor_) internal {
        ++counts[Action.ExactOut].attempted;
        Checkpoint memory before_ = Checkpoint(base.balanceOf(actor_), share.balanceOf(actor_), 0);
        uint256 amountOut = seIn.previewExchangeIn(share, before_.shares / 4, base);
        assertGt(amountOut, 0, "withdrawal output nonzero");
        IStandardExchangeOut seOut = IStandardExchangeOut(address(seIn));
        before_.quote = seOut.previewExchangeOut(share, base, amountOut);
        assertGt(before_.quote, 0, "withdrawal input nonzero");
        vm.startPrank(actor_);
        share.approve(address(seIn), before_.quote);
        uint256 used = seOut.exchangeOut(share, before_.quote, base, amountOut, actor_, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertEq(used, before_.quote, "withdrawal spends exact quote");
        assertEq(before_.shares - share.balanceOf(actor_), used, "shares consumed once");
        assertEq(base.balanceOf(actor_) - before_.assets, amountOut, "exact requested payout");
        burnedShares += used;
        ++ghost_out;
        ++counts[Action.ExactOut].succeeded;
    }

    function _donate() internal {
        ++counts[Action.Donation].attempted;
        uint256 amount = 1e9;
        _fund(address(this), amount);
        uint256 held = base.balanceOf(address(seIn));
        uint256 supply = share.totalSupply();
        base.transfer(address(seIn), amount);
        assertEq(base.balanceOf(address(seIn)) - held, amount, "donation custody");
        assertEq(share.totalSupply(), supply, "donation does not issue shares");
        donated += amount;
        ++counts[Action.Donation].succeeded;
    }

    function _rejectContract(Action action_) internal {
        ++counts[action_].attempted;
        bytes32 before_ = _state();
        bytes memory data = _depositData(address(integrator), 1e15, 0, true);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, uint256(1e15), uint256(0)));
        integrator.execute(address(seIn), data);
        assertEq(_state(), before_, "rejected contract preserves balances and supply");
        ++counts[action_].expectedRevert;
    }

    function _rejectEoa() internal {
        ++counts[Action.EoaReject].attempted;
        bytes32 before_ = _state();
        vm.prank(attacker);
        if (supportsPrepay) vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        else vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, uint256(1e15), uint256(0)));
        seIn.exchangeIn(base, 1e15, share, 0, attacker, true, block.timestamp + 1 hours);
        assertEq(_state(), before_, "rejected EOA preserves balances and supply");
        ++ghost_eoaReject;
        ++counts[Action.EoaReject].expectedRevert;
    }

    function _state() internal view virtual returns (bytes32) {
        uint256[14] memory values;
        values[0] = share.totalSupply();
        values[1] = base.balanceOf(address(seIn));
        values[2] = share.balanceOf(address(seIn));
        values[3] = base.balanceOf(address(integrator));
        values[4] = share.balanceOf(address(integrator));
        values[5] = base.balanceOf(attacker);
        values[6] = share.balanceOf(attacker);
        for (uint256 i; i < 3; ++i) values[7 + i] = share.balanceOf(actors[i]);
        for (uint256 i; i < 3; ++i) values[11 + i] = base.balanceOf(actors[i]);
        values[10] = base.allowance(address(integrator), address(seIn));
        return keccak256(abi.encode(values));
    }

    function assertAccounting() external view {
        assertEq(ghost_in, cycles + (cycles + 1) / 4 + (supportsPrepay ? (cycles + 3) / 4 : 0), "all funded deposits reached");
        assertEq(ghost_out, cycles, "all nonzero exits reached");
        assertEq(ghost_eoaReject, cycles / 4, "all EOA checks reached");
        for (uint8 i; i < 11; ++i) {
            Counts memory c = counts[Action(i)];
            uint256 required;
            if (i == uint8(Action.PullDeposit)) required = cycles + (cycles + 1) / 4;
            else if (i == uint8(Action.ExactOut)) required = cycles;
            else if (i == uint8(Action.PushDeposit)) required = supportsPrepay ? (cycles + 3) / 4 : 0;
            else if (i == uint8(Action.AtomicUnsupported)) required = supportsPrepay ? 0 : (cycles + 3) / 4;
            else if (i == uint8(Action.ReusedCreditReject)) required = (cycles + 3) / 4;
            else if (i == uint8(Action.Transfer) || i == uint8(Action.ExactOutMint)) required = (cycles + 2) / 4;
            else if (i == uint8(Action.EoaReject)) required = cycles / 4;
            else required = (cycles + 1) / 4;
            assertEq(c.unexpectedRevert, 0, "uncaught unexpected revert fails campaign");
            assertEq(c.attempted, required, "action attempted every cycle");
            assertEq(c.succeeded + c.expectedRevert, required, "no swallowed or unclassified failure");
        }
        uint256 expectedLock = !supportsPrepay && cycles > 0 && initialSupply == 0 ? 1000 : initialLocked;
        assertEq(share.balanceOf(address(1)), expectedLock, "only the specified initial Loop lock");
        uint256 owned;
        for (uint256 i; i < 3; ++i) owned += share.balanceOf(actors[i]);
        assertEq(owned, mintedShares - burnedShares, "honest holdings conserve all issued shares");
        assertEq(share.totalSupply(), initialSupply + mintedShares - burnedShares + share.balanceOf(address(1)) - initialLocked, "supply issuance and burns reconcile");
        assertEq(share.balanceOf(address(integrator)), 0, "no attack shares");
        assertEq(share.balanceOf(attacker), 0, "no EOA attack shares");
    }
}
