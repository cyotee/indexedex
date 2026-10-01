// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IRouter as BalancerRouter} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IRouter.sol";
import {Test} from "forge-std/Test.sol";
import {DetfStatefulActions} from "contracts/test/bases/DetfStatefulActions.sol";
import {HostileReentrantShare} from "contracts/test/adversarial/HostileReentrantShare.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {
    TestBase_MultiVaultWeightedDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";

interface IDetfInvariantBook {
    function reserveOfToken(address token) external view returns (uint256);
}

interface IMultiWeightedStatefulHost {
    function fundBuffer(address to, uint256 amt) external;
    function marketTrade(address actor, uint256 amount) external;
}

contract Handler_MultiVaultWeightedDetfStateful is DetfStatefulActions {
    IStandardExchangeIn public immutable seIn;
    IERC20 public immutable buffer;
    IMultiWeightedStatefulHost public immutable host;
    address[3] public actors;
    address public immutable attacker;

    struct ActionCounts {
        uint256 attempted;
        uint256 succeeded;
        uint256 expectedRevert;
        uint256 unexpectedRevert;
    }
    ActionCounts public deposits;
    ActionCounts public withdrawals;
    ActionCounts public eoaChecks;
    ActionCounts public contractChecks;
    uint256 public attempted;
    uint256 public ghost_in;
    uint256 public ghost_out;
    uint256 public ghost_eoaReject;
    uint256 public ghost_contractReject;

    constructor(
        IStandardExchangeIn seIn_,
        IERC20 token_,
        IMultiWeightedStatefulHost host_,
        address a0,
        address a1,
        address attacker_
    ) {
        seIn = seIn_;
        buffer = token_;
        host = host_;
        actors = [a0, a1, address(0xCA1103)];
        attacker = attacker_;
    }

    // Registered production SE shares cannot install the hostile transfer callback;
    // package rejection is covered by MultiVaultWeightedDetf_Reentrancy.t.sol.
    function _lifecycleHasCallback() internal pure override returns (bool) {
        return false;
    }

    function _lifecycleFund(address actor_, uint256 amount_) internal override {
        host.fundBuffer(actor_, amount_);
    }

    function _lifecycleTrade(address actor_, uint256 amount_) internal override {
        host.marketTrade(actor_, amount_);
    }

    function _lifecycleInput() internal view override returns (IERC20) {
        return IERC20(address(buffer));
    }

    function _lifecycleDetf() internal view override returns (address) {
        return address(seIn);
    }

    /// @notice Each randomized lifecycle funds a real mint and partial redemption, then reaches both prepaid checks.
    /// @dev Small nonzero amounts avoid exhausting the fixture reserve while preserving native 9-decimal DETF units.
    function cycle(
        uint256 amountSeed,
        uint256 /* actorSeed */
    )
        public
    {
        ++attempted;
        address actor = actors[(attempted - 1) % actors.length];
        uint256 minted = _deposit(actor, bound(amountSeed, 1e16, 1e17));
        _withdraw(actor, minted / 4);
        _statefulActions(actor, actors[attempted % actors.length], minted, true, attempted);
        _rejectUnfunded(false);
        _rejectUnfunded(true);
    }

    function _deposit(address actor, uint256 amount) internal returns (uint256 minted) {
        ++deposits.attempted;
        host.fundBuffer(actor, amount);
        uint256 beforeAssets = buffer.balanceOf(actor);
        IERC20 shares = IERC20(address(seIn));
        uint256 beforeShares = shares.balanceOf(actor);
        uint256 quote = seIn.previewExchangeIn(buffer, amount, shares);
        assertGt(quote, 0, "funded mint quote");
        vm.startPrank(actor);
        buffer.approve(address(seIn), amount);
        minted = seIn.exchangeIn(buffer, amount, shares, quote, actor, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertEq(beforeAssets - buffer.balanceOf(actor), amount, "exact funded input consumed");
        assertEq(shares.balanceOf(actor) - beforeShares, minted, "actual DETF delivered");
        assertEq(minted, quote, "mint preview matches execution");
        ++deposits.succeeded;
        ++ghost_in;
    }

    function _withdraw(address actor, uint256 amount) internal {
        ++withdrawals.attempted;
        assertGt(amount, 0, "partial redemption is nonzero");
        IERC20 shares = IERC20(address(seIn));
        uint256 beforeShares = shares.balanceOf(actor);
        uint256 beforeAssets = buffer.balanceOf(actor);
        uint256 quote = seIn.previewExchangeIn(shares, amount, buffer);
        assertGt(quote, 0, "funded redemption quote");
        vm.startPrank(actor);
        shares.approve(address(seIn), amount);
        uint256 paid = seIn.exchangeIn(shares, amount, buffer, 1, actor, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertEq(beforeShares - shares.balanceOf(actor), amount, "only declared shares consumed");
        assertEq(buffer.balanceOf(actor) - beforeAssets, paid, "actual redemption paid");
        assertGt(paid, 0, "funded redemption succeeds");
        ++withdrawals.succeeded;
        ++ghost_out;
    }

    function _book() internal view returns (uint256) {
        return IDetfInvariantBook(address(seIn)).reserveOfToken(address(buffer));
    }

    function _state(address caller) internal view returns (bytes32) {
        IERC20 shares = IERC20(address(seIn));
        return keccak256(
            abi.encode(
                _lifecycleLiabilities(),
                shares.totalSupply(),
                shares.balanceOf(address(seIn)),
                shares.balanceOf(caller),
                buffer.balanceOf(address(seIn)),
                buffer.balanceOf(caller),
                _book(),
                buffer.allowance(caller, address(seIn)),
                shares.allowance(caller, address(seIn))
            )
        );
    }

    function _rejectUnfunded(bool contractCaller) internal {
        ActionCounts storage counts = contractCaller ? contractChecks : eoaChecks;
        ++counts.attempted;
        address caller = contractCaller ? address(this) : attacker;
        uint256 held = buffer.balanceOf(address(seIn));
        uint256 booked = _book();
        uint256 available = held > booked ? held - booked : 0;
        uint256 claimed = available + 1;
        bytes32 beforeState = _state(caller);
        bytes memory expected = contractCaller
            ? abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed, available)
            : abi.encodeWithSelector(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        vm.prank(caller);
        vm.expectRevert(expected);
        seIn.exchangeIn(buffer, claimed, IERC20(address(seIn)), 0, caller, true, block.timestamp + 1 hours);
        assertEq(_state(caller), beforeState, "rejected call preserves balances, book, supply and approvals");
        ++counts.expectedRevert;
        if (contractCaller) ++ghost_contractReject;
        else ++ghost_eoaReject;
    }

    /// @notice No setup operation satisfies the campaign counts; every sampled cycle must reach every action.
    function assertAccounting() external view {
        _assertStatefulCounts(attempted, true);
        assertEq(deposits.attempted, attempted);
        assertEq(withdrawals.attempted, attempted);
        assertEq(eoaChecks.attempted, attempted);
        assertEq(contractChecks.attempted, attempted);
        assertEq(deposits.succeeded, attempted, "all funded mints succeed");
        assertEq(withdrawals.succeeded, attempted, "all partial redemptions succeed");
        assertEq(eoaChecks.expectedRevert, attempted, "all EOA checks reached");
        assertEq(contractChecks.expectedRevert, attempted, "all contract credit checks reached");
        assertEq(
            deposits.unexpectedRevert + withdrawals.unexpectedRevert + eoaChecks.unexpectedRevert
                + contractChecks.unexpectedRevert,
            0
        );
    }
}

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 64
/// forge-config: default.invariant.fail-on-revert = true
contract MultiVaultWeightedDetfInvariant is TestBase_MultiVaultWeightedDetf, IMultiWeightedStatefulHost {
    Handler_MultiVaultWeightedDetfStateful internal handler;

    function fundBuffer(address to, uint256 amt) external {
        uint256 funded_ = _fundSeSharesLeg(0, address(this), amt * 4);
        assertGe(funded_, amt);
        seShares[0].transfer(to, amt);
    }

    function marketTrade(address actor_, uint256 amount_) external {
        IERC20 input_ = IERC20(detf);
        IERC20 output_ = seShares[0];
        uint256 beforeIn_ = input_.balanceOf(actor_);
        uint256 beforeOut_ = output_.balanceOf(actor_);
        vm.startPrank(actor_);
        input_.approve(address(permit2), amount_);
        IPermit2(address(permit2)).approve(address(input_), address(router), uint160(amount_), type(uint48).max);
        uint256 out_ = BalancerRouter(address(router))
            .swapSingleTokenExactIn(detfInfo.reservePool(), input_, output_, amount_, 1, block.timestamp, false, "");
        vm.stopPrank();
        assertEq(beforeIn_ - input_.balanceOf(actor_), amount_);
        assertGt(out_, 0);
        assertEq(output_.balanceOf(actor_) - beforeOut_, out_);
    }

    function setUp() public override {
        super.setUp();
        address a0 = makeAddr("mbInv0");
        address a1 = makeAddr("mbInv1");
        address att = makeAddr("mbInvAttacker");
        _useDetf(_deployOpenThresholdDetfN(1));
        _goLiveViaBptBond(detf, a0, 1_000 ether);
        handler = new Handler_MultiVaultWeightedDetfStateful(
            IStandardExchangeIn(detf), seShares[0], IMultiWeightedStatefulHost(address(this)), a0, a1, att
        );
        bytes4[] memory sels = new bytes4[](1);
        sels[0] = handler.cycle.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: sels}));
    }

    function invariant_accounting() public view {
        handler.assertAccounting();
    }

    function afterInvariant() public view {
        assertGe(handler.attempted(), 8, "campaign reached every money action and all three honest actors");
        handler.assertAccounting();
    }

    function test_deterministicLifecycle() public {
        for (uint256 i; i < 8; ++i) {
            handler.cycle(5e16, i);
        }
        assertEq(handler.ghost_in(), 8);
        assertEq(handler.ghost_out(), 8);
        assertEq(handler.ghost_eoaReject(), 8);
        assertEq(handler.ghost_contractReject(), 8);
        handler.assertAccounting();
    }
}
