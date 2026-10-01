// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {StandardExchangeAccountingHandler} from "test/foundry/spec/vaults/standard/exchange/invariant/StandardExchangeAccountingHandler.sol";

interface IStakingAccountingHost {
    function fundReceipt(address to_, uint256 amount_) external;
    function settleRequests() external;
    function accountingState() external view returns (bytes32);
}
interface IStakingAccountingVault {
    function totalReserveEth() external view returns (uint256);
    function liquidReserveEth() external view returns (uint256);
    function rebalance() external;
}
interface IHostileAccountingWeth is IERC20 {
    function deposit() external payable;
    function arm(address target_, bytes calldata call_) external;
    function reentryAttempts() external view returns (uint256);
    function nestedCallSucceeded() external view returns (bool);
    function nestedErrorSelector() external view returns (bytes4);
}

/// @dev Real staking SE, genuine funding and native receipt transfers; only the WETH
/// dependency provides a transfer callback, exercising the production reentrancy guard.
abstract contract StakingStandardExchangeAccountingHandler is StandardExchangeAccountingHandler {
    enum StakingAction { WethDeposit, WethExit, Rebalance, ReenterIn, ReenterOut }
    mapping(StakingAction => Counts) public stakingCounts;
    IStakingAccountingHost public immutable host;
    IHostileAccountingWeth public immutable weth;

    constructor(address se_, IERC20 receipt_, address weth_, IStakingAccountingHost host_)
        StandardExchangeAccountingHandler(IStandardExchangeIn(se_), receipt_, IERC20(se_), true,
            address(0xCA1101), address(0xCA1102), address(0xBAD))
    { host = host_; weth = IHostileAccountingWeth(weth_); }

    function _fund(address actor_, uint256 amount_) internal override { host.fundReceipt(actor_, amount_); }

    function _state() internal view override returns (bytes32) {
        return keccak256(abi.encode(super._state(), host.accountingState()));
    }

    function _restingQuote(uint256 amount_) internal view override returns (uint256) {
        // All three hermetic receipt rates are 1:1 and their production packages use offset 3.
        // A standing receipt donation is in live NAV; this call credits only amount_.
        uint256 nav = IStakingAccountingVault(address(seIn)).totalReserveEth();
        return Math.mulDiv(amount_, share.totalSupply() + 1000, nav - amount_ + 1);
    }

    function _additionalActions(address actor_, uint256 seed_) internal override {
        _wethDeposit(actor_, bound(seed_, 0.1 ether, 1 ether));
        _wethExit(actor_);
        _rebalance();
    }

    function _fundWeth(address actor_, uint256 amount_) internal {
        vm.deal(actor_, amount_);
        vm.prank(actor_);
        weth.deposit{value: amount_}();
    }

    function _wethDeposit(address actor_, uint256 amount_) internal {
        ++stakingCounts[StakingAction.WethDeposit].attempted;
        _fundWeth(actor_, amount_);
        Checkpoint memory before_ = Checkpoint(weth.balanceOf(actor_), share.balanceOf(actor_),
            seIn.previewExchangeIn(weth, amount_, share));
        vm.prank(actor_);
        weth.approve(address(seIn), amount_);
        ++stakingCounts[StakingAction.ReenterIn].attempted;
        weth.arm(address(seIn), abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (weth, amount_, share, 0, attacker, true, block.timestamp + 1 hours)));
        vm.prank(actor_);
        uint256 minted = seIn.exchangeIn(weth, amount_, share, before_.quote, actor_, false, block.timestamp + 1 hours);
        _assertNestedLocked(StakingAction.ReenterIn);
        assertGt(minted, 0, "funded WETH deposit succeeds");
        assertEq(minted, before_.quote, "WETH quote and mint");
        assertEq(before_.assets - weth.balanceOf(actor_), amount_, "WETH principal debited once");
        assertEq(share.balanceOf(actor_) - before_.shares, minted, "WETH recipient shares");
        mintedShares += minted;
        ++stakingCounts[StakingAction.WethDeposit].succeeded;
    }

    function _wethExit(address actor_) internal {
        ++stakingCounts[StakingAction.WethExit].attempted;
        uint256 amount = seIn.previewExchangeIn(share, share.balanceOf(actor_) / 20, weth);
        uint256 liquid = IStakingAccountingVault(address(seIn)).liquidReserveEth();
        if (amount > liquid / 2) amount = liquid / 2;
        assertGt(amount, 0, "funded sleeve supports nonzero partial exit");
        IStandardExchangeOut out = IStandardExchangeOut(address(seIn));
        Checkpoint memory before_ = Checkpoint(weth.balanceOf(actor_), share.balanceOf(actor_),
            out.previewExchangeOut(share, weth, amount));
        ++stakingCounts[StakingAction.ReenterOut].attempted;
        weth.arm(address(seIn), abi.encodeCall(IStandardExchangeOut.exchangeOut,
            (share, 1, weth, 1, attacker, false, block.timestamp + 1 hours)));
        vm.prank(actor_);
        uint256 used = out.exchangeOut(share, before_.quote, weth, amount, actor_, false, block.timestamp + 1 hours);
        _assertNestedLocked(StakingAction.ReenterOut);
        assertEq(used, before_.quote, "partial sleeve exit spends quote");
        assertEq(before_.shares - share.balanceOf(actor_), used, "sleeve burn once");
        assertEq(weth.balanceOf(actor_) - before_.assets, amount, "exact sleeve payout");
        burnedShares += used;
        ++stakingCounts[StakingAction.WethExit].succeeded;
    }

    function _assertNestedLocked(StakingAction action_) internal {
        assertEq(weth.reentryAttempts(), 1, "operative transfer callback reached");
        assertFalse(weth.nestedCallSucceeded(), "nested money call rejected");
        assertEq(weth.nestedErrorSelector(), IReentrancyLock.IsLocked.selector, "intended guard rejects");
        assertEq(share.balanceOf(attacker), 0, "nested caller receives no shares");
        ++stakingCounts[action_].expectedRevert;
    }

    function _rebalance() internal {
        IStakingAccountingVault vault = IStakingAccountingVault(address(seIn));
        uint256 supply = share.totalSupply();
        uint256 nav = vault.totalReserveEth();
        for (uint256 i; i < 2; ++i) {
            ++stakingCounts[StakingAction.Rebalance].attempted;
            host.settleRequests();
            vault.rebalance();
            ++stakingCounts[StakingAction.Rebalance].succeeded;
        }
        assertEq(share.totalSupply(), supply, "rebalance cannot issue shares");
        assertEq(vault.totalReserveEth(), nav, "receipt, sleeve and pending claims conserve face value");
    }

    function assertStakingAccounting() external view {
        for (uint8 i; i < 5; ++i) {
            Counts memory c = stakingCounts[StakingAction(i)];
            uint256 required = i == uint8(StakingAction.Rebalance) ? (cycles / 4) * 2 : cycles / 4;
            assertEq(c.attempted, required, "staking action reached every cycle");
            assertEq(c.succeeded + c.expectedRevert, required, "staking action classified");
            assertEq(c.unexpectedRevert, 0, "unexpected revert fails campaign");
        }
    }

    /// @dev Same starting state for pull and atomic delivery. Both supported principal tokens
    /// are exercised; returning to the snapshot preserves the stateful campaign's ghost ledger.
    struct Parity { IERC20 token; address payer; uint256 desired; uint256 needed; uint256 maximum; bool exactOut; }

    function seedParity() external { _deposit(actors[0], 2 ether, false); }

    function assertPretransferParity(bool useWeth_, bool exactOut_, bool overpay_) external {
        Parity memory p;
        p.token = useWeth_ ? IERC20(address(weth)) : base;
        p.payer = actors[0];
        p.exactOut = exactOut_;
        p.desired = seIn.previewExchangeIn(p.token, 1 ether, share);
        p.needed = exactOut_ ? IStandardExchangeOut(address(seIn)).previewExchangeOut(p.token, share, p.desired) : 1 ether;
        p.maximum = overpay_ ? p.needed + p.needed / 2 + 1 : p.needed;
        uint256 snapshot = vm.snapshotState();
        uint256 pull = _parityCall(p, false);
        assertEq(pull, exactOut_ ? p.needed : p.desired, "same-state funded pull control");
        assertTrue(vm.revertToState(snapshot));
        snapshot = vm.snapshotState();
        uint256 beforeShares = share.balanceOf(p.payer);
        uint256 pushed = _parityCall(p, true);
        assertEq(pushed, pull, "atomic pretransfer equals prior quote and pull");
        assertEq(share.balanceOf(p.payer) - beforeShares, p.desired, "atomic recipient gets exact quoted shares");
        assertEq(p.token.balanceOf(address(integrator)), exactOut_ ? p.maximum - p.needed : 0, "bounded refund only for exact-out");
        assertTrue(vm.revertToState(snapshot));
    }

    function _parityCall(Parity memory p, bool prepaid_) internal returns (uint256) {
        _fundParity(p.payer, p.token, p.maximum);
        if (prepaid_) {
            vm.prank(p.payer);
            p.token.approve(address(integrator), p.maximum);
            return abi.decode(integrator.consumePretransfer(p.token, p.payer, address(seIn), p.maximum, _parityData(p)), (uint256));
        }
        vm.startPrank(p.payer);
        p.token.approve(address(seIn), p.maximum);
        uint256 result = p.exactOut
            ? IStandardExchangeOut(address(seIn)).exchangeOut(p.token, p.maximum, share, p.desired, p.payer, false, block.timestamp + 1 hours)
            : seIn.exchangeIn(p.token, p.needed, share, p.desired, p.payer, false, block.timestamp + 1 hours);
        vm.stopPrank();
        return result;
    }

    function _parityData(Parity memory p) internal view returns (bytes memory) {
        if (p.exactOut) return abi.encodeCall(IStandardExchangeOut.exchangeOut,
            (p.token, p.maximum, share, p.desired, p.payer, true, block.timestamp + 1 hours));
        return abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (p.token, p.needed, share, p.desired, p.payer, true, block.timestamp + 1 hours));
    }

    function _fundParity(address actor_, IERC20 token_, uint256 amount_) internal {
        if (address(token_) == address(weth)) _fundWeth(actor_, amount_);
        else _fund(actor_, amount_);
    }
}
