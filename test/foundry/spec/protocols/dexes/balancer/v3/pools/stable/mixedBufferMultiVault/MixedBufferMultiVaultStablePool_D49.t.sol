// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {
    IBalancerV3StandardExchangeRouterProxy
} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {
    IMixedBufferMultiVaultStablePool
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/IMixedBufferMultiVaultStablePool.sol";
import {CoordinatorSeRouterDeployLib} from "test/foundry/spec/routers/balancerV3-uniswapV4/helpers/CoordinatorSeRouterDeployLib.sol";
import {
    TestBase_MixedBufferMultiVaultStablePool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/bases/TestBase_MixedBufferMultiVaultStablePool.sol";

/**
 * @title MixedBufferMultiVaultStablePool_D49
 * @notice APEX D49 (amendment to D37) boundary controls on the production two-vault mixed pool (one unpaired leg).
 * @dev Probes under test (staticcall, interface detection only): `prepaySessionActive()` on the
 *      swap router, and the SE `previewExchangeIn` / `previewExchangeOut` that select which vault
 *      the walk uses. Operative calls (`passPrepayAuth`, `restorePrepayAuth`, `exchangeIn`,
 *      `exchangeOut`) are hard and their revert propagates with full rollback.
 *      Two production SE vaults with equal seeding: rank ties resolve to index 0 (`seVault`), so
 *      index 0 is probed first and index 1 (`seVault1`) is the walk's next candidate.
 *      Dependency failures are injected with vm.mockCall / vm.mockCallRevert on the router or an
 *      SE vault, never on the pool, hook, package or registry (the SUT).
 */
contract MixedBufferMultiVaultStablePool_D49_Test is TestBase_MixedBufferMultiVaultStablePool {
    error DependencyRejected(bytes32 tag);

    bytes internal REJECT = abi.encodeWithSelector(DependencyRejected.selector, keccak256("APEX-D49"));

    bytes4 internal constant PASS = IBalancerV3StandardExchangeRouterPrepay.passPrepayAuth.selector;
    bytes4 internal constant RESTORE = IBalancerV3StandardExchangeRouterPrepay.restorePrepayAuth.selector;
    bytes4 internal constant PREVIEW_IN = IStandardExchangeIn.previewExchangeIn.selector;
    bytes4 internal constant PREVIEW_OUT = IStandardExchangeOut.previewExchangeOut.selector;
    bytes4 internal constant EXCHANGE_IN = IStandardExchangeIn.exchangeIn.selector;
    bytes4 internal constant EXCHANGE_OUT = IStandardExchangeOut.exchangeOut.selector;

    IBalancerV3StandardExchangeRouterProxy internal seRouterReal;

    function _targetVaultCount() internal pure virtual override returns (uint8) {
        return 2;
    }

    function setUp() public virtual override {
        super.setUp();
        seRouterReal = CoordinatorSeRouterDeployLib.deploy(create3Factory, diamondPackageFactory, bv3Vault, permit2, IWETH(address(weth)));
        vm.label(address(seRouterReal), "SeRouterReal");
        vm.startPrank(alice);
        dai.approve(address(permit2), type(uint256).max);
        IERC20(address(seVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouterReal), type(uint160).max, type(uint48).max);
        permit2.approve(address(seVault), address(seRouterReal), type(uint160).max, type(uint48).max);
        vm.stopPrank();
    }

    /* ------------------------------------------------------------------ */
    /*                                helpers                              */
    /* ------------------------------------------------------------------ */

    function _pool() internal view returns (IMixedBufferMultiVaultStablePool) {
        return IMixedBufferMultiVaultStablePool(mbmvsPool);
    }

    function _shares0() internal view returns (IERC20) {
        return IERC20(address(seVault));
    }

    function _shares1() internal view returns (IERC20) {
        return IERC20(address(seVault1));
    }

    function _buy(uint256 amount) internal returns (uint256) {
        dai.mint(alice, amount);
        return swapExactIn(alice, IERC20(address(dai)), _shares0(), amount);
    }

    function _sell(uint256 amount) internal returns (uint256) {
        return swapExactIn(alice, _shares0(), IERC20(address(dai)), amount);
    }

    function _buyViaRealRouter(uint256 amount) internal returns (uint256 out) {
        dai.mint(alice, amount);
        vm.prank(alice);
        out = seRouterReal.swapSingleTokenExactIn(
            mbmvsPool,
            IERC20(address(dai)),
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
        uint256 aliceDai;
        uint256 aliceShares0;
        uint256 supply0;
        uint256 supply1;
        uint256 bpt;
        uint256 virtualBuffer;
        int256 delta0;
        int256 delta1;
    }

    function _snap() internal view returns (Snap memory s) {
        s.aliceDai = dai.balanceOf(alice);
        s.aliceShares0 = _shares0().balanceOf(alice);
        s.supply0 = _shares0().totalSupply();
        s.supply1 = _shares1().totalSupply();
        s.bpt = IERC20(mbmvsPool).totalSupply();
        s.virtualBuffer = _pool().virtualBuffer();
        s.delta0 = _pool().hookShareDelta(0);
        s.delta1 = _pool().hookShareDelta(1);
    }

    function _assertUnchanged(Snap memory s) internal view {
        assertEq(dai.balanceOf(alice), s.aliceDai, "alice buffer unchanged");
        assertEq(_shares0().balanceOf(alice), s.aliceShares0, "alice shares unchanged");
        assertEq(_shares0().totalSupply(), s.supply0, "vault0 supply unchanged");
        assertEq(_shares1().totalSupply(), s.supply1, "vault1 supply unchanged");
        assertEq(IERC20(mbmvsPool).totalSupply(), s.bpt, "BPT supply unchanged");
        assertEq(_pool().virtualBuffer(), s.virtualBuffer, "virtualBuffer unchanged");
        assertEq(_pool().hookShareDelta(0), s.delta0, "delta0 unchanged");
        assertEq(_pool().hookShareDelta(1), s.delta1, "delta1 unchanged");
    }

    /* ------------------------------------------------------------------ */
    /*                     D49(a): prepay hand-off boundary                 */
    /* ------------------------------------------------------------------ */

    function test_D49_noPrepayRouter_handoffSkipped_swapCompletes() public {
        vm.expectCall(address(router), abi.encodeWithSelector(PASS), 0);
        vm.expectCall(address(router), abi.encodeWithSelector(RESTORE), 0);
        Snap memory s = _snap();
        assertGt(_buy(10e18), 0, "swap through a prepay-less router completes");
        assertEq(_pool().virtualBuffer(), s.virtualBuffer + 10e18, "reconcile booked the buffer");
    }

    function test_D49_prepayRouter_handoffSucceeds_funded() public {
        vm.expectCall(address(seRouterReal), abi.encodeWithSelector(PASS), 1);
        vm.expectCall(address(seRouterReal), abi.encodeWithSelector(RESTORE), 1);
        Snap memory s = _snap();
        assertGt(_buyViaRealRouter(10e18), 0, "funded swap through the prepay router completes");
        assertEq(_pool().virtualBuffer(), s.virtualBuffer + 10e18, "reconcile booked the buffer");
        IBalancerV3StandardExchangeRouterPrepay p = IBalancerV3StandardExchangeRouterPrepay(address(seRouterReal));
        assertFalse(p.prepaySessionActive(), "prepay session closed after the swap");
        assertEq(p.prepayAuthDepth(), 0, "prepay auth stack empty after the swap");
    }

    function test_D49_prepayRouter_handoffIsHard_revertPropagates() public {
        dai.mint(alice, 10e18);
        Snap memory s = _snap();
        vm.mockCallRevert(address(seRouterReal), abi.encodeWithSelector(PASS), REJECT);
        vm.prank(alice);
        vm.expectRevert(REJECT);
        seRouterReal.swapSingleTokenExactIn(
            mbmvsPool, IERC20(address(dai)), IStandardExchangeProxy(address(0)), _shares0(),
            IStandardExchangeProxy(address(0)), 10e18, 0, block.timestamp, false, ""
        );
        vm.clearMockedCalls();
        _assertUnchanged(s);
    }

    function test_D49_prepayRouter_restoreIsHard_revertPropagates() public {
        dai.mint(alice, 10e18);
        Snap memory s = _snap();
        vm.mockCallRevert(address(seRouterReal), abi.encodeWithSelector(RESTORE), REJECT);
        vm.prank(alice);
        vm.expectRevert(REJECT);
        seRouterReal.swapSingleTokenExactIn(
            mbmvsPool, IERC20(address(dai)), IStandardExchangeProxy(address(0)), _shares0(),
            IStandardExchangeProxy(address(0)), 10e18, 0, block.timestamp, false, ""
        );
        vm.clearMockedCalls();
        _assertUnchanged(s);
    }

    /* ------------------------------------------------------------------ */
    /*                  D49(b): reconcile walk (buffer → shares)            */
    /* ------------------------------------------------------------------ */

    /// @dev Vault 0's `previewExchangeIn` reverts: the probe skips it and the walk deposits into
    ///      vault 1. Vault 0 receives no operative call and keeps its supply.
    function test_D49_walk_previewRevert_skipsToNextVault() public {
        Snap memory s = _snap();
        vm.mockCallRevert(address(seVault), abi.encodeWithSelector(PREVIEW_IN), REJECT);
        vm.expectCall(address(seVault), abi.encodeWithSelector(PREVIEW_IN), 1);
        vm.expectCall(address(seVault), abi.encodeWithSelector(EXCHANGE_IN), 0);
        assertGt(_buy(10e18), 0, "swap completes through vault 1");
        vm.clearMockedCalls();
        assertEq(_shares0().totalSupply(), s.supply0, "vault 0 untouched");
        assertGt(_shares1().totalSupply(), s.supply1, "vault 1 minted");
        assertEq(_pool().hookShareDelta(0), s.delta0, "delta0 untouched");
        assertGt(_pool().hookShareDelta(1), s.delta1, "delta1 grew");
    }

    /// @dev Vault 0's preview returns zero: same skip, same next vault.
    function test_D49_walk_previewZero_skipsToNextVault() public {
        Snap memory s = _snap();
        vm.mockCall(address(seVault), abi.encodeWithSelector(PREVIEW_IN), abi.encode(uint256(0)));
        vm.expectCall(address(seVault), abi.encodeWithSelector(EXCHANGE_IN), 0);
        assertGt(_buy(10e18), 0, "swap completes through vault 1");
        vm.clearMockedCalls();
        assertEq(_shares0().totalSupply(), s.supply0, "vault 0 untouched");
        assertGt(_shares1().totalSupply(), s.supply1, "vault 1 minted");
        assertGt(_pool().hookShareDelta(1), s.delta1, "delta1 grew");
    }

    /// @dev Vault 0's preview succeeds and its operative `exchangeIn` reverts: the swap reverts
    ///      with the SE's bytes. The walk does not move on to vault 1; everything rolls back.
    function test_D49_walk_operativeRevert_propagates() public {
        dai.mint(alice, 10e18);
        Snap memory s = _snap();
        vm.mockCallRevert(address(seVault), abi.encodeWithSelector(EXCHANGE_IN), REJECT);
        vm.startPrank(alice);
        vm.expectRevert(REJECT);
        router.swapSingleTokenExactIn(
            mbmvsPool, IERC20(address(dai)), _shares0(), 10e18, 0, type(uint256).max, false, bytes("")
        );
        vm.stopPrank();
        vm.clearMockedCalls();
        _assertUnchanged(s);
    }

    /// @dev Every probe fails: the walk ends in AllVaultsExhausted and nothing changes.
    function test_D49_walk_allProbesFail_allVaultsExhausted() public {
        dai.mint(alice, 10e18);
        Snap memory s = _snap();
        vm.mockCallRevert(address(seVault), abi.encodeWithSelector(PREVIEW_IN), REJECT);
        vm.mockCallRevert(address(seVault1), abi.encodeWithSelector(PREVIEW_IN), REJECT);
        vm.startPrank(alice);
        vm.expectRevert(IMixedBufferMultiVaultStablePool.AllVaultsExhausted.selector);
        router.swapSingleTokenExactIn(
            mbmvsPool, IERC20(address(dai)), _shares0(), 10e18, 0, type(uint256).max, false, bytes("")
        );
        vm.stopPrank();
        vm.clearMockedCalls();
        _assertUnchanged(s);
    }

    /* ------------------------------------------------------------------ */
    /*                  D49(b): pre-seat walk (shares → buffer)             */
    /* ------------------------------------------------------------------ */

    /// @dev Vault 0's `previewExchangeOut` reverts: the redeem walk skips it and pre-seats from
    ///      vault 1 (its shares are burned, its delta falls). Vault 0 is not redeemed.
    function test_D49_preSeat_previewRevert_skipsToNextVault() public {
        Snap memory s = _snap();
        assertGe(s.aliceShares0, 20e18, "alice holds vault 0 shares from init");
        vm.mockCallRevert(address(seVault), abi.encodeWithSelector(PREVIEW_OUT), REJECT);
        vm.expectCall(address(seVault), abi.encodeWithSelector(EXCHANGE_OUT), 0);
        assertGt(_sell(20e18), 0, "swap completes through vault 1");
        vm.clearMockedCalls();
        assertEq(_shares0().totalSupply(), s.supply0, "vault 0 not redeemed");
        assertLt(_shares1().totalSupply(), s.supply1, "vault 1 redeemed");
        assertLt(_pool().hookShareDelta(1), s.delta1, "delta1 fell");
        assertLt(_pool().virtualBuffer(), s.virtualBuffer, "virtual buffer consumed");
    }

    /// @dev Vault 0's pre-seat preview succeeds and its operative `exchangeOut` reverts: the swap
    ///      reverts with the SE's bytes and rolls back; no fallthrough to vault 1.
    function test_D49_preSeat_operativeRevert_propagates() public {
        Snap memory s = _snap();
        vm.mockCallRevert(address(seVault), abi.encodeWithSelector(EXCHANGE_OUT), REJECT);
        vm.startPrank(alice);
        vm.expectRevert(REJECT);
        router.swapSingleTokenExactIn(
            mbmvsPool, _shares0(), IERC20(address(dai)), 20e18, 0, type(uint256).max, false, bytes("")
        );
        vm.stopPrank();
        vm.clearMockedCalls();
        _assertUnchanged(s);
    }

    /// @dev Positive control: no injected failure, vault 0 is selected in both directions from the
    ///      equal-depth init state (rank ties resolve to index 0). Each direction starts from the
    ///      same state: a buy shifts vault 0's derived depth, so the sell is checked on a snapshot.
    function test_D49_positiveControl_vault0Selected() public {
        uint256 snapshot = vm.snapshotState();
        Snap memory s = _snap();
        assertGt(_buy(10e18), 0);
        assertGt(_shares0().totalSupply(), s.supply0, "buy folded into vault 0");
        assertEq(_shares1().totalSupply(), s.supply1, "vault 1 untouched on buy");
        vm.revertToState(snapshot);
        s = _snap();
        assertGt(_sell(20e18), 0);
        assertLt(_shares0().totalSupply(), s.supply0, "sell redeemed from vault 0");
        assertEq(_shares1().totalSupply(), s.supply1, "vault 1 untouched on sell");
    }
}
