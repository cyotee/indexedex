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
import {
    IMixedLegWeightedBufferPool
} from "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/IMixedLegWeightedBufferPool.sol";
import {CoordinatorSeRouterDeployLib} from "test/foundry/spec/routers/balancerV3-uniswapV4/helpers/CoordinatorSeRouterDeployLib.sol";
import {
    TestBase_MixedLegWeightedBufferPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/bases/TestBase_MixedLegWeightedBufferPool.sol";

/**
 * @title MixedLegWeightedBufferPool_D49
 * @notice APEX D49 (amendment to D37) boundary controls on the production mixed-leg weighted pool.
 * @dev This package carries one staticcall probe: `prepaySessionActive()` on the swap router
 *      (`_isPrepayRouter`). Each pair has exactly one SE vault, so the SE preview is a direct hard
 *      call and there is no walk; the walk-equivalent tests record that a reverting or zero preview
 *      reverts the swap instead of being skipped. Pair 0 is buffer0 (DAI) with `seVault`.
 *      Dependency failures are injected with vm.mockCall / vm.mockCallRevert on the router or the
 *      SE, never on the pool, hook, package or registry (the SUT).
 */
contract MixedLegWeightedBufferPool_D49_Test is TestBase_MixedLegWeightedBufferPool {
    error DependencyRejected(bytes32 tag);

    bytes internal REJECT = abi.encodeWithSelector(DependencyRejected.selector, keccak256("APEX-D49"));

    bytes4 internal constant PASS = IBalancerV3StandardExchangeRouterPrepay.passPrepayAuth.selector;
    bytes4 internal constant RESTORE = IBalancerV3StandardExchangeRouterPrepay.restorePrepayAuth.selector;
    bytes4 internal constant PREVIEW_OUT = IStandardExchangeOut.previewExchangeOut.selector;
    bytes4 internal constant EXCHANGE_IN = IStandardExchangeIn.exchangeIn.selector;
    bytes4 internal constant EXCHANGE_OUT = IStandardExchangeOut.exchangeOut.selector;

    IBalancerV3StandardExchangeRouterProxy internal seRouterReal;

    function setUp() public virtual override {
        super.setUp();
        seRouterReal = CoordinatorSeRouterDeployLib.deploy(create3Factory, diamondPackageFactory, bv3Vault, permit2, IWETH(address(weth)));
        vm.label(address(seRouterReal), "SeRouterReal");
        vm.startPrank(alice);
        buffer0.approve(address(permit2), type(uint256).max);
        IERC20(address(seVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(buffer0), address(seRouterReal), type(uint160).max, type(uint48).max);
        permit2.approve(address(seVault), address(seRouterReal), type(uint160).max, type(uint48).max);
        vm.stopPrank();
    }

    /* ------------------------------------------------------------------ */
    /*                                helpers                              */
    /* ------------------------------------------------------------------ */

    function _pool() internal view returns (IMixedLegWeightedBufferPool) {
        return IMixedLegWeightedBufferPool(mixedLegPool);
    }

    function _shares0() internal view returns (IERC20) {
        return IERC20(address(seVault));
    }

    function _buy(uint256 amount) internal returns (uint256) {
        _mintToken(address(buffer0), alice, amount);
        return swapExactIn(alice, buffer0, _shares0(), amount);
    }

    function _sell(uint256 amount) internal returns (uint256) {
        return swapExactIn(alice, _shares0(), buffer0, amount);
    }

    function _buyViaRealRouter(uint256 amount) internal returns (uint256 out) {
        _mintToken(address(buffer0), alice, amount);
        vm.prank(alice);
        out = seRouterReal.swapSingleTokenExactIn(
            mixedLegPool,
            buffer0,
            IStandardExchangeProxy(address(0)),
            _shares0(),
            IStandardExchangeProxy(address(0)),
            amount,
            0,
            block.timestamp,
            false,
            ""
        );
    }

    struct Snap {
        uint256 aliceBuffer;
        uint256 aliceShares;
        uint256 supply0;
        uint256 bpt;
        uint256 virtualBuffer;
        int256 delta0;
    }

    function _snap() internal view returns (Snap memory s) {
        s.aliceBuffer = buffer0.balanceOf(alice);
        s.aliceShares = _shares0().balanceOf(alice);
        s.supply0 = _shares0().totalSupply();
        s.bpt = IERC20(mixedLegPool).totalSupply();
        s.virtualBuffer = _pool().virtualBuffer(0);
        s.delta0 = _pool().hookShareDelta(0);
    }

    function _assertUnchanged(Snap memory s) internal view {
        assertEq(buffer0.balanceOf(alice), s.aliceBuffer, "alice buffer unchanged");
        assertEq(_shares0().balanceOf(alice), s.aliceShares, "alice shares unchanged");
        assertEq(_shares0().totalSupply(), s.supply0, "SE supply unchanged");
        assertEq(IERC20(mixedLegPool).totalSupply(), s.bpt, "BPT supply unchanged");
        assertEq(_pool().virtualBuffer(0), s.virtualBuffer, "virtualBuffer unchanged");
        assertEq(_pool().hookShareDelta(0), s.delta0, "hookShareDelta unchanged");
    }

    /* ------------------------------------------------------------------ */
    /*                     D49(a): prepay hand-off boundary                 */
    /* ------------------------------------------------------------------ */

    function test_D49_noPrepayRouter_handoffSkipped_swapCompletes() public {
        vm.expectCall(address(router), abi.encodeWithSelector(PASS), 0);
        vm.expectCall(address(router), abi.encodeWithSelector(RESTORE), 0);
        Snap memory s = _snap();
        assertGt(_buy(10e18), 0, "swap through a prepay-less router completes");
        assertGt(_shares0().totalSupply(), s.supply0, "reconcile folded the buffer into the SE");
    }

    function test_D49_prepayRouter_handoffSucceeds_funded() public {
        vm.expectCall(address(seRouterReal), abi.encodeWithSelector(PASS, address(seVault)), 1);
        vm.expectCall(address(seRouterReal), abi.encodeWithSelector(RESTORE), 1);
        Snap memory s = _snap();
        assertGt(_buyViaRealRouter(10e18), 0, "funded swap through the prepay router completes");
        assertGt(_shares0().totalSupply(), s.supply0, "reconcile folded the buffer into the SE");
        IBalancerV3StandardExchangeRouterPrepay p = IBalancerV3StandardExchangeRouterPrepay(address(seRouterReal));
        assertFalse(p.prepaySessionActive(), "prepay session closed after the swap");
        assertEq(p.prepayAuthDepth(), 0, "prepay auth stack empty after the swap");
    }

    function test_D49_prepayRouter_handoffIsHard_revertPropagates() public {
        _mintToken(address(buffer0), alice, 10e18);
        Snap memory s = _snap();
        vm.mockCallRevert(address(seRouterReal), abi.encodeWithSelector(PASS, address(seVault)), REJECT);
        vm.prank(alice);
        vm.expectRevert(REJECT);
        seRouterReal.swapSingleTokenExactIn(
            mixedLegPool, buffer0, IStandardExchangeProxy(address(0)), _shares0(), IStandardExchangeProxy(address(0)),
            10e18, 0, block.timestamp, false, ""
        );
        vm.clearMockedCalls();
        _assertUnchanged(s);
    }

    function test_D49_prepayRouter_restoreIsHard_revertPropagates() public {
        _mintToken(address(buffer0), alice, 10e18);
        Snap memory s = _snap();
        vm.mockCallRevert(address(seRouterReal), abi.encodeWithSelector(RESTORE), REJECT);
        vm.prank(alice);
        vm.expectRevert(REJECT);
        seRouterReal.swapSingleTokenExactIn(
            mixedLegPool, buffer0, IStandardExchangeProxy(address(0)), _shares0(), IStandardExchangeProxy(address(0)),
            10e18, 0, block.timestamp, false, ""
        );
        vm.clearMockedCalls();
        _assertUnchanged(s);
    }

    /* ------------------------------------------------------------------ */
    /*          D49(b) walk-equivalent: SE preview and operative calls       */
    /* ------------------------------------------------------------------ */

    /// @dev Single vault per pair: `previewExchangeOut` is a direct hard call. A reverting preview
    ///      reverts the shares→buffer swap with the SE's bytes; nothing is skipped.
    function test_D49_preview_isHard_revertPropagates() public {
        Snap memory s = _snap();
        assertGe(s.aliceShares, 20e18, "alice holds pair-0 shares from init");
        vm.mockCallRevert(address(seVault), abi.encodeWithSelector(PREVIEW_OUT), REJECT);
        vm.startPrank(alice);
        vm.expectRevert(REJECT);
        router.swapSingleTokenExactIn(mixedLegPool, _shares0(), buffer0, 20e18, 0, type(uint256).max, false, bytes(""));
        vm.stopPrank();
        vm.clearMockedCalls();
        _assertUnchanged(s);
    }

    /// @dev Single vault per pair: a zero preview cannot be walked past; the pre-seat has nothing
    ///      to redeem: the SE's exchangeOut with a zero share budget reverts MaxAmountExceeded(0, needed)
    ///      (recorded 2026-09-21) and the swap rolls back; nothing changes.
    function test_D49_preview_zero_swapReverts() public {
        Snap memory s = _snap();
        vm.mockCall(address(seVault), abi.encodeWithSelector(PREVIEW_OUT), abi.encode(uint256(0)));
        vm.startPrank(alice);
        vm.expectPartialRevert(IStandardExchangeErrors.MaxAmountExceeded.selector);
        router.swapSingleTokenExactIn(mixedLegPool, _shares0(), buffer0, 20e18, 0, type(uint256).max, false, bytes(""));
        vm.stopPrank();
        vm.clearMockedCalls();
        _assertUnchanged(s);
    }

    /// @dev Operative `exchangeIn` (buffer→shares reconcile) reverts: swap reverts with the SE's
    ///      bytes; full rollback.
    function test_D49_operative_exchangeIn_revertPropagates() public {
        _mintToken(address(buffer0), alice, 10e18);
        Snap memory s = _snap();
        vm.mockCallRevert(address(seVault), abi.encodeWithSelector(EXCHANGE_IN), REJECT);
        vm.startPrank(alice);
        vm.expectRevert(REJECT);
        router.swapSingleTokenExactIn(mixedLegPool, buffer0, _shares0(), 10e18, 0, type(uint256).max, false, bytes(""));
        vm.stopPrank();
        vm.clearMockedCalls();
        _assertUnchanged(s);
    }

    /// @dev Operative `exchangeOut` (shares→buffer pre-seat) reverts after a successful preview:
    ///      swap reverts with the SE's bytes; full rollback.
    function test_D49_operative_exchangeOut_revertPropagates() public {
        Snap memory s = _snap();
        vm.mockCallRevert(address(seVault), abi.encodeWithSelector(EXCHANGE_OUT), REJECT);
        vm.startPrank(alice);
        vm.expectRevert(REJECT);
        router.swapSingleTokenExactIn(mixedLegPool, _shares0(), buffer0, 20e18, 0, type(uint256).max, false, bytes(""));
        vm.stopPrank();
        vm.clearMockedCalls();
        _assertUnchanged(s);
    }

    /// @dev Positive control: no injected failure, both directions complete and move the SE.
    function test_D49_positiveControl_bothDirectionsComplete() public {
        Snap memory s = _snap();
        assertGt(_buy(10e18), 0);
        assertGt(_shares0().totalSupply(), s.supply0, "buy folded into the SE");
        s = _snap();
        assertGt(_sell(20e18), 0);
        assertLt(_shares0().totalSupply(), s.supply0, "sell redeemed from the SE");
    }
}
