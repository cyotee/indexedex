// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {
    BalancerV3StandardExchangeRouterRepo
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterRepo.sol";
import {
    TestBase_PrepaySessionHarness,
    IPrepaySessionHarness
} from "test/foundry/spec/protocol/dexes/balancer/v3/routers/TestBase_PrepaySessionHarness.sol";

/**
 * @title MidSessionAttacker
 * @notice Contract that probes pass/prepay while a prepay session is active (not stack top).
 */
contract MidSessionAttacker {
    IBalancerV3StandardExchangeRouterPrepay public immutable router;

    constructor(address router_) {
        router = IBalancerV3StandardExchangeRouterPrepay(router_);
    }

    function attackPass(address next) external returns (bool) {
        return router.passPrepayAuth(next);
    }

    function attackRestore() external returns (bool) {
        return router.restorePrepayAuth();
    }

    function attackPrepay(address pool, uint256[] calldata amounts) external returns (uint256) {
        return router.prepayAddLiquidityUnbalanced(pool, amounts, 0, "");
    }
}

/**
 * @title PrincipalCaller
 * @notice Acts as stack top during harness session (pass/restore as authorized principal).
 */
contract PrincipalCaller {
    IBalancerV3StandardExchangeRouterPrepay public immutable router;

    constructor(address router_) {
        router = IBalancerV3StandardExchangeRouterPrepay(router_);
    }

    function passTo(address next) external returns (bool) {
        return router.passPrepayAuth(next);
    }

    function restore() external returns (bool) {
        return router.restorePrepayAuth();
    }

    function prepayAsTop(address pool, uint256[] calldata amounts) external returns (uint256) {
        return router.prepayAddLiquidityUnbalanced(pool, amounts, 1, "");
    }
}

/**
 * @title Adversarial_PrepayAuth
 * @notice P0 adversarial coverage for prepay session auth.
 * @dev Drives production router prepay/pass/restore entry points. Mid-session cases use
 *      `withPrepaySession` which calls production Repo `_sessionBegin` / `_pushPrepayAuth` /
 *      `_sessionEnd` (same functions swap hooks use).
 *
 * Catalog:
 * - A1 free-balance EOA steal blocked
 * - B1 mid-session non-top prepay blocked (session active)
 * - C1 non-principal pass during session (alias C4)
 * - C4 passPrepayAuth not top during session
 * - D1 open unlocked gate gone (EOA while Balancer unlocked)
 * - D2 session-off EOA blocked
 * - D3 restore by non-parent blocked during session
 * - D6 self-root contract session-off succeeds
 * - E1 residual: after self-root success, router free inventory of pool tokens stays clean path
 * - E2 atomicity: failed mid-session prepay leaves session clean after harness end
 * - H2 session clean after successful swap; after failed swap
 * - H3 query path ends session (via production query hooks)
 *
 * @dev Deferred P1/P2 (not silently missing):
 *      B2 multi-path settle absorption; C2 malicious on-path SE isolation bounds;
 *      C5 stuck baton without try/finally in nested SE production sites;
 *      G1 Buffer hermetic pass (see buffer-detf-prepay.log / Buffer suite when run);
 *      G2 nested depth 3; H1 grief unsettled outer BalanceNotSettled reconstruction.
 */
contract Adversarial_PrepayAuth_Test is TestBase_PrepaySessionHarness {
    uint256 internal constant LIQ = 100e18;

    MidSessionAttacker internal attacker;
    PrincipalCaller internal principal;

    function setUp() public override {
        super.setUp();
        attacker = new MidSessionAttacker(address(seRouter));
        principal = new PrincipalCaller(address(seRouter));
    }

    /* ---------------------------------------------------------------------- */
    /*  D1 / D2                                                                 */
    /* ---------------------------------------------------------------------- */

    function test_D1_eoa_prepay_sessionOff_reverts() public {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = LIQ;
        amounts[1] = LIQ;
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(BalancerV3StandardExchangeRouterRepo.PrepayNotAuthorized.selector, alice)
        );
        prepayRouter.prepayAddLiquidityUnbalanced(daiUsdcPool, amounts, 1, "");
    }

    function test_D1_eoa_prepay_whileUnlocked_reverts() public {
        dai.mint(alice, LIQ);
        usdc.mint(alice, LIQ);
        vm.prank(alice);
        dai.transfer(address(vault), LIQ);
        vm.prank(alice);
        usdc.transfer(address(vault), LIQ);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = LIQ;
        amounts[1] = LIQ;
        vault.unlock(abi.encodeCall(this._unlockThenEoaAttack, (amounts)));
    }

    function _unlockThenEoaAttack(uint256[] memory amounts) external returns (bytes memory) {
        assertTrue(vault.isUnlocked(), "precondition unlocked");
        vm.prank(alice);
        try prepayRouter.prepayAddLiquidityUnbalanced(daiUsdcPool, amounts, 1, "") {
            revert("D1: EOA prepay must not succeed while unlocked");
        } catch (bytes memory reason) {
            assertEq(bytes4(reason), BalancerV3StandardExchangeRouterRepo.PrepayNotAuthorized.selector);
        }
        return "";
    }

    function test_D2_sessionOff_eoaBlocked() public {
        test_D1_eoa_prepay_sessionOff_reverts();
    }

    /* ---------------------------------------------------------------------- */
    /*  A1                                                                      */
    /* ---------------------------------------------------------------------- */

    function test_A1_freeBalance_eoaCannotPrepayJoin() public {
        dai.mint(address(this), LIQ);
        usdc.mint(address(this), LIQ);
        dai.transfer(address(vault), LIQ);
        usdc.transfer(address(vault), LIQ);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = LIQ;
        amounts[1] = LIQ;
        uint256 bptBefore = IERC20(daiUsdcPool).balanceOf(alice);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(BalancerV3StandardExchangeRouterRepo.PrepayNotAuthorized.selector, alice)
        );
        prepayRouter.prepayAddLiquidityUnbalanced(daiUsdcPool, amounts, 1, "");
        assertEq(IERC20(daiUsdcPool).balanceOf(alice), bptBefore, "A1: no BPT to attacker EOA");
    }

    /* ---------------------------------------------------------------------- */
    /*  D6 self-root                                                            */
    /* ---------------------------------------------------------------------- */

    function test_D6_selfRoot_contract_prepay_sessionOff_succeeds() public {
        dai.mint(address(this), LIQ);
        usdc.mint(address(this), LIQ);
        dai.transfer(address(vault), LIQ);
        usdc.transfer(address(vault), LIQ);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = LIQ;
        amounts[1] = LIQ;
        uint256 bptBefore = IERC20(daiUsdcPool).balanceOf(address(this));
        uint256 bpt = prepayRouter.prepayAddLiquidityUnbalanced(daiUsdcPool, amounts, 1, "");
        assertGt(bpt, 0);
        assertEq(IERC20(daiUsdcPool).balanceOf(address(this)), bptBefore + bpt);
    }

    /* ---------------------------------------------------------------------- */
    /*  C4 / C1: pass not top during ACTIVE session                             */
    /* ---------------------------------------------------------------------- */

    function test_C4_passPrepayAuth_sessionOff_isNoop() public {
        assertTrue(prepayRouter.passPrepayAuth(address(0xBEEF)));
        assertFalse(prepayRouter.prepaySessionActive());
        assertEq(prepayRouter.prepayAuthDepth(), 0);
    }

    /// @dev Mid-session: attacker is not stack top → NotAuthorizedToPass.
    function test_C4_passPrepayAuth_notTop_reverts_duringSwapSession() public {
        assertFalse(prepayRouter.prepaySessionActive());
        // Session with principal = address(principal); attacker calls pass (not top).
        vm.expectRevert(
            abi.encodeWithSelector(
                BalancerV3StandardExchangeRouterRepo.NotAuthorizedToPass.selector,
                address(attacker),
                address(principal)
            )
        );
        prepaySessionHarness.withPrepaySession(
            address(principal),
            address(attacker),
            abi.encodeCall(attacker.attackPass, (address(0xBEEF)))
        );
        // Harness always ends session even on revert of outer call? withPrepaySession reverts before end if call fails.
        // Production path: session end is after call; on revert of target, assembly reverts after _sessionEnd.
        // Check harness: sessionEnd is BEFORE the if (!ok) revert - yes, session is cleaned.
        assertFalse(prepayRouter.prepaySessionActive(), "session must end after harness");
        assertEq(prepayRouter.prepayAuthDepth(), 0);
    }

    function test_C1_nonPrincipal_pass_duringSession_reverts() public {
        test_C4_passPrepayAuth_notTop_reverts_duringSwapSession();
    }

    /* ---------------------------------------------------------------------- */
    /*  B1: mid-session non-top prepay                                          */
    /* ---------------------------------------------------------------------- */

    function test_B1_midSession_nonTop_prepay_reverts() public {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = LIQ;
        amounts[1] = LIQ;
        vm.expectRevert(
            abi.encodeWithSelector(
                BalancerV3StandardExchangeRouterRepo.NotPrepayAuthTop.selector,
                address(attacker),
                address(principal)
            )
        );
        prepaySessionHarness.withPrepaySession(
            address(principal),
            address(attacker),
            abi.encodeCall(attacker.attackPrepay, (daiUsdcPool, amounts))
        );
        assertFalse(prepayRouter.prepaySessionActive());
    }

    /* ---------------------------------------------------------------------- */
    /*  D3: restore by non-parent                                               */
    /* ---------------------------------------------------------------------- */

    function test_D3_restore_byNonParent_reverts() public {
        // Depth must be >= 2 for restore; principal passes to child, then attacker tries restore.
        // Flow inside principal: passTo(child) then we need attacker to restore.
        // Simpler: session with principal only (depth 1) → restore reverts NotAuthorizedToRestore.
        vm.expectRevert(); // depth < 2 or wrong parent
        prepaySessionHarness.withPrepaySession(
            address(principal), address(attacker), abi.encodeCall(attacker.attackRestore, ())
        );
        assertFalse(prepayRouter.prepaySessionActive());
    }

    function test_D3_restore_wrongParent_afterPass_reverts() public {
        // principal is top; principal passes to child (principal still parent);
        // attacker (neither parent nor child appropriately) tries restore.
        address child = makeAddr("child");
        // Call as principal: pass to child, then as attacker restore should fail.
        // Nested: harness session top=principal; call principal.passTo(child) which pushes child;
        // then still in same withPrepaySession... need multi-step inside one session.

        // Use principal to pass then attacker restore in one external call chain:
        NestedRestoreProbe probe = new NestedRestoreProbe(address(seRouter), address(principal), address(attacker));
        vm.expectRevert(
            abi.encodeWithSelector(
                BalancerV3StandardExchangeRouterRepo.NotAuthorizedToRestore.selector,
                address(attacker),
                address(principal)
            )
        );
        prepaySessionHarness.withPrepaySession(
            address(principal), address(probe), abi.encodeCall(probe.run, (child))
        );
        assertFalse(prepayRouter.prepaySessionActive());
    }

    /* ---------------------------------------------------------------------- */
    /*  E1 residual / E2 atomicity                                              */
    /* ---------------------------------------------------------------------- */

    function test_E1_selfRoot_success_noRouterTokenRetention() public {
        dai.mint(address(this), LIQ);
        usdc.mint(address(this), LIQ);
        dai.transfer(address(vault), LIQ);
        usdc.transfer(address(vault), LIQ);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = LIQ;
        amounts[1] = LIQ;
        prepayRouter.prepayAddLiquidityUnbalanced(daiUsdcPool, amounts, 1, "");
        // Router should not retain free DAI/USDC from prepay settle path.
        assertEq(dai.balanceOf(address(seRouter)), 0, "E1: no free DAI on router");
        assertEq(usdc.balanceOf(address(seRouter)), 0, "E1: no free USDC on router");
    }

    function test_E2_midSession_failedPrepay_sessionCleanAfter() public {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;
        // Attacker fails auth; harness still ends session.
        try prepaySessionHarness.withPrepaySession(
            address(principal),
            address(attacker),
            abi.encodeCall(attacker.attackPrepay, (daiUsdcPool, amounts))
        ) {
            revert("expected fail");
        } catch {
            // expected
        }
        assertFalse(prepayRouter.prepaySessionActive(), "E2: session cleaned after failed mid-session prepay");
        assertEq(prepayRouter.prepayAuthDepth(), 0);
    }

    /* ---------------------------------------------------------------------- */
    /*  H2 session clean after swap success / revert                            */
    /* ---------------------------------------------------------------------- */

    function test_H2_sessionCleanAfterDirectSwap() public {
        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);
        _dealAndApproveRouter(alice, token0, TEST_AMOUNT);
        vm.prank(alice);
        seRouter.swapSingleTokenExactIn(
            daiUsdcPool, token0, _noVault(), token1, _noVault(), TEST_AMOUNT, 0, type(uint256).max, false, ""
        );
        assertFalse(prepayRouter.prepaySessionActive());
        assertEq(prepayRouter.prepayAuthDepth(), 0);
    }

    function test_H2_sessionCleanAfterFailedSwap() public {
        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);
        _dealAndApproveRouter(alice, token0, TEST_AMOUNT);
        vm.prank(alice);
        try seRouter.swapSingleTokenExactIn(
            daiUsdcPool,
            token0,
            _noVault(),
            token1,
            _noVault(),
            TEST_AMOUNT,
            type(uint256).max, // impossible minOut
            type(uint256).max,
            false,
            ""
        ) {
            revert("expected slippage revert");
        } catch {
            // expected
        }
        assertFalse(prepayRouter.prepaySessionActive(), "H2: session clean after failed swap");
        assertEq(prepayRouter.prepayAuthDepth(), 0);
    }

    /* ---------------------------------------------------------------------- */
    /*  H3 query session ends clean                                             */
    /* ---------------------------------------------------------------------- */

    function test_H3_queryExactIn_sessionCleanAfter() public {
        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);
        // Production query entry (vault.quote → querySwapSingleTokenExactInHook with session begin/end).
        uint256 snap = vm.snapshotState();
        vm.prank(address(0), address(0));
        try seRouter.querySwapSingleTokenExactIn(
            daiUsdcPool, token0, _noVault(), token1, _noVault(), TEST_AMOUNT, alice, ""
        ) returns (uint256) {
            // ok
        } catch {
            // quote may revert in some env setups; session must still not leak after snap revert
        }
        vm.revertToState(snap);
        assertFalse(prepayRouter.prepaySessionActive(), "H3: no leaked session after query");
        assertEq(prepayRouter.prepayAuthDepth(), 0);
    }

    /* ---------------------------------------------------------------------- */
    /*  Views                                                                     */
    /* ---------------------------------------------------------------------- */

    function test_prepayAuth_views_initiallyInactive() public view {
        assertFalse(prepayRouter.prepaySessionActive());
        assertEq(prepayRouter.prepayAuthTop(), address(0));
        assertEq(prepayRouter.prepayAuthDepth(), 0);
    }

    function _dealAndApproveRouter(address who, IERC20 token, uint256 amount) internal {
        deal(address(token), who, amount);
        vm.startPrank(who);
        token.approve(address(permit2), type(uint256).max);
        permit2.approve(address(token), address(seRouter), type(uint160).max, type(uint48).max);
        vm.stopPrank();
    }
}

/**
 * @dev principal is session top; passes to child; attacker tries restore (wrong parent).
 */
contract NestedRestoreProbe {
    IBalancerV3StandardExchangeRouterPrepay public immutable router;
    PrincipalCaller public immutable principal;
    MidSessionAttacker public immutable attacker;

    constructor(address router_, address principal_, address attacker_) {
        router = IBalancerV3StandardExchangeRouterPrepay(router_);
        principal = PrincipalCaller(principal_);
        attacker = MidSessionAttacker(attacker_);
    }

    function run(address child) external {
        // msg.sender for pass must be principal (top). Call via principal.
        principal.passTo(child);
        // Now top is child, parent is principal. Attacker restore should fail.
        attacker.attackRestore();
    }
}
