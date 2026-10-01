// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {
    IBalancerV3StandardExchangeRouterProxy
} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {CoordinatorSeRouterDeployLib} from "test/foundry/spec/routers/balancerV3-uniswapV4/helpers/CoordinatorSeRouterDeployLib.sol";
import {
    TestBase_StandardExchangeBufferPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";

/**
 * @title StandardExchangeBufferPool_D49
 * @notice APEX D49 (amendment to D37) boundary controls on the production constProd buffer pool.
 * @dev This package carries one staticcall probe: `prepaySessionActive()` on the swap router
 *      (StandardExchangeBufferHookTarget.sol `_isPrepayRouter`). It is single-vault, so the SE
 *      preview is a direct hard call and there is no walk; the walk-equivalent tests below record
 *      that a reverting or zero preview reverts the swap instead of being skipped.
 *      Fixtures: Crane RouterMock (no prepay interface) and the real IndexedEx SE router
 *      (prepay-capable). Dependency failures are injected with vm.mockCall / vm.mockCallRevert on
 *      the router or the SE, never on the pool, hook, package or registry (the SUT).
 */
contract StandardExchangeBufferPool_D49_Test is TestBase_StandardExchangeBufferPool {
    error DependencyRejected(bytes32 tag);

    bytes internal REJECT = abi.encodeWithSelector(DependencyRejected.selector, keccak256("APEX-D49"));

    IBalancerV3StandardExchangeRouterProxy internal seRouterReal;

    function setUp() public virtual override {
        super.setUp();
        seRouterReal = CoordinatorSeRouterDeployLib.deploy(create3Factory, diamondPackageFactory, bv3Vault, permit2, IWETH(address(weth)));
        vm.label(address(seRouterReal), "SeRouterReal");
        vm.startPrank(alice);
        tta.approve(address(permit2), type(uint256).max);
        shares.approve(address(permit2), type(uint256).max);
        permit2.approve(address(tta), address(seRouterReal), type(uint160).max, type(uint48).max);
        permit2.approve(address(shares), address(seRouterReal), type(uint160).max, type(uint48).max);
        vm.stopPrank();
    }

    /* ------------------------------------------------------------------ */
    /*                                helpers                              */
    /* ------------------------------------------------------------------ */

    function _pool() internal view returns (IStandardExchangeBufferPool) {
        return IStandardExchangeBufferPool(bufferPool);
    }

    function _swapViaRealRouter(IERC20 tokenIn, IERC20 tokenOut, uint256 amountIn) internal returns (uint256 out) {
        vm.prank(alice);
        out = seRouterReal.swapSingleTokenExactIn(
            bufferPool,
            tokenIn,
            IStandardExchangeProxy(address(0)),
            tokenOut,
            IStandardExchangeProxy(address(0)),
            amountIn,
            0,
            block.timestamp,
            false,
            ""
        );
    }

    struct Snap {
        uint256 aliceTta;
        uint256 aliceShares;
        uint256 seSupply;
        uint256 bpt;
        uint256 virtualTTA;
        int256 hookSharesDelta;
    }

    function _snap() internal view returns (Snap memory s) {
        s.aliceTta = tta.balanceOf(alice);
        s.aliceShares = shares.balanceOf(alice);
        s.seSupply = shares.totalSupply();
        s.bpt = IERC20(bufferPool).totalSupply();
        s.virtualTTA = _pool().virtualTTA();
        s.hookSharesDelta = _pool().hookSharesDelta();
    }

    function _assertUnchanged(Snap memory s) internal view {
        assertEq(tta.balanceOf(alice), s.aliceTta, "alice TTA unchanged");
        assertEq(shares.balanceOf(alice), s.aliceShares, "alice shares unchanged");
        assertEq(shares.totalSupply(), s.seSupply, "SE supply unchanged");
        assertEq(IERC20(bufferPool).totalSupply(), s.bpt, "BPT supply unchanged");
        assertEq(_pool().virtualTTA(), s.virtualTTA, "virtualTTA unchanged");
        assertEq(_pool().hookSharesDelta(), s.hookSharesDelta, "hookSharesDelta unchanged");
    }

    bytes4 internal constant PASS = IBalancerV3StandardExchangeRouterPrepay.passPrepayAuth.selector;
    bytes4 internal constant RESTORE = IBalancerV3StandardExchangeRouterPrepay.restorePrepayAuth.selector;

    /* ------------------------------------------------------------------ */
    /*                     D49(a): prepay hand-off boundary                 */
    /* ------------------------------------------------------------------ */

    /// @dev A router without `prepaySessionActive()` (Crane RouterMock) is probed and skipped: the
    ///      swap completes and neither hand-off call is ever attempted.
    function test_D49_noPrepayRouter_handoffSkipped_swapCompletes() public {
        mintTTA(alice, 10e18);
        vm.expectCall(address(router), abi.encodeWithSelector(PASS), 0);
        vm.expectCall(address(router), abi.encodeWithSelector(RESTORE), 0);
        uint256 seSupply = shares.totalSupply();
        uint256 out = swapTTAforShares(alice, 10e18);
        assertGt(out, 0, "swap through a prepay-less router completes");
        assertGt(shares.totalSupply(), seSupply, "reconcile folded TTA into the SE");
    }

    /// @dev The real SE router opens a prepay session for every swap and pushes the pool as route
    ///      principal, so the hook is the stack top: the hand-off is a hard call that succeeds, the
    ///      reconcile completes, and the session is restored and closed after the swap.
    function test_D49_prepayRouter_handoffSucceeds_funded() public {
        mintTTA(alice, 10e18);
        vm.expectCall(address(seRouterReal), abi.encodeWithSelector(PASS, address(seVault)), 1);
        vm.expectCall(address(seRouterReal), abi.encodeWithSelector(RESTORE), 1);
        uint256 seSupply = shares.totalSupply();
        uint256 out = _swapViaRealRouter(tta, shares, 10e18);
        assertGt(out, 0, "funded swap through the prepay router completes");
        assertGt(shares.totalSupply(), seSupply, "reconcile folded TTA into the SE");
        IBalancerV3StandardExchangeRouterPrepay p = IBalancerV3StandardExchangeRouterPrepay(address(seRouterReal));
        assertFalse(p.prepaySessionActive(), "prepay session closed after the swap");
        assertEq(p.prepayAuthDepth(), 0, "prepay auth stack empty after the swap");
    }

    /// @dev Once the router is selected, `passPrepayAuth` is hard: a router that rejects the
    ///      hand-off reverts the whole swap with the router's own bytes and nothing changes.
    function test_D49_prepayRouter_handoffIsHard_revertPropagates() public {
        mintTTA(alice, 10e18);
        Snap memory s = _snap();
        vm.mockCallRevert(address(seRouterReal), abi.encodeWithSelector(PASS, address(seVault)), REJECT);
        vm.expectRevert(REJECT);
        _swapViaRealRouter(tta, shares, 10e18);
        vm.clearMockedCalls();
        _assertUnchanged(s);
    }

    /// @dev `restorePrepayAuth` is hard too: a rejected restore after a successful fold reverts the
    ///      swap and rolls the fold back.
    function test_D49_prepayRouter_restoreIsHard_revertPropagates() public {
        mintTTA(alice, 10e18);
        Snap memory s = _snap();
        vm.mockCallRevert(address(seRouterReal), abi.encodeWithSelector(RESTORE), REJECT);
        vm.expectRevert(REJECT);
        _swapViaRealRouter(tta, shares, 10e18);
        vm.clearMockedCalls();
        _assertUnchanged(s);
    }

    /* ------------------------------------------------------------------ */
    /*          D49(b) walk-equivalent: SE preview and operative calls       */
    /* ------------------------------------------------------------------ */

    /// @dev Single vault: `previewExchangeOut` is a direct hard call (no probe). A reverting
    ///      preview reverts the shares→TTA swap with the SE's bytes; nothing is skipped.
    function test_D49_preview_isHard_revertPropagates() public {
        mintShares(alice, 100e18);
        Snap memory s = _snap();
        vm.mockCallRevert(address(seVault), abi.encodeWithSelector(IStandardExchangeOut.previewExchangeOut.selector), REJECT);
        vm.expectRevert(REJECT);
        swapSharesForTTA(alice, 20e18);
        vm.clearMockedCalls();
        _assertUnchanged(s);
    }

    /// @dev Single vault: a zero preview cannot be walked past. The pre-seat has nothing to redeem
    ///      and the swap reverts (recorded: PreSeatRedemptionFailed or the SE's own revert on a
    ///      zero-share exchangeOut); nothing changes.
    function test_D49_preview_zero_swapReverts() public {
        mintShares(alice, 100e18);
        Snap memory s = _snap();
        vm.mockCall(
            address(seVault), abi.encodeWithSelector(IStandardExchangeOut.previewExchangeOut.selector), abi.encode(uint256(0))
        );
        vm.expectPartialRevert(IStandardExchangeErrors.MaxAmountExceeded.selector);
        swapSharesForTTA(alice, 20e18);
        vm.clearMockedCalls();
        _assertUnchanged(s);
    }

    /// @dev Operative `exchangeIn` (TTA→shares reconcile) reverts: the swap reverts with the SE's
    ///      bytes and every transfer, share and book is rolled back.
    function test_D49_operative_exchangeIn_revertPropagates() public {
        mintTTA(alice, 10e18);
        Snap memory s = _snap();
        vm.mockCallRevert(address(seVault), abi.encodeWithSelector(IStandardExchangeIn.exchangeIn.selector), REJECT);
        vm.expectRevert(REJECT);
        swapTTAforShares(alice, 10e18);
        vm.clearMockedCalls();
        _assertUnchanged(s);
    }

    /// @dev Operative `exchangeOut` (shares→TTA pre-seat) reverts after a successful preview: the
    ///      swap reverts with the SE's bytes and is rolled back.
    function test_D49_operative_exchangeOut_revertPropagates() public {
        mintShares(alice, 100e18);
        Snap memory s = _snap();
        vm.mockCallRevert(address(seVault), abi.encodeWithSelector(IStandardExchangeOut.exchangeOut.selector), REJECT);
        vm.expectRevert(REJECT);
        swapSharesForTTA(alice, 20e18);
        vm.clearMockedCalls();
        _assertUnchanged(s);
    }

    /// @dev Positive control: with no injected failure both directions complete and the SE side
    ///      moves (fold on buy, redeem on sell).
    function test_D49_positiveControl_bothDirectionsComplete() public {
        mintTTA(alice, 10e18);
        uint256 seSupply = shares.totalSupply();
        assertGt(swapTTAforShares(alice, 10e18), 0);
        assertGt(shares.totalSupply(), seSupply, "buy folded into the SE");
        mintShares(alice, 100e18);
        seSupply = shares.totalSupply();
        assertGt(swapSharesForTTA(alice, 20e18), 0);
        assertLt(shares.totalSupply(), seSupply, "sell redeemed from the SE");
    }
}
