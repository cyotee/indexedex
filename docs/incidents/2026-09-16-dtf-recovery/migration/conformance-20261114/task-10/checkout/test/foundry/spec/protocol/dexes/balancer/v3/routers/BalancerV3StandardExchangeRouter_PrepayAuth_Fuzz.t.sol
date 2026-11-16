// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {
    BalancerV3StandardExchangeRouterRepo
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterRepo.sol";
import {
    TestBase_PrepaySessionHarness
} from "test/foundry/spec/protocol/dexes/balancer/v3/routers/TestBase_PrepaySessionHarness.sol";
import {
    MidSessionAttacker,
    PrincipalCaller
} from "test/foundry/spec/protocol/dexes/balancer/v3/routers/adversarial/Adversarial_PrepayAuth.t.sol";

/**
 * @title BalancerV3StandardExchangeRouter_PrepayAuth_Fuzz
 * @notice L1 fuzz: session-off EOA block + session-active top-mismatch prepay/pass.
 */
contract BalancerV3StandardExchangeRouter_PrepayAuth_Fuzz_Test is TestBase_PrepaySessionHarness {
    MidSessionAttacker internal attacker;
    PrincipalCaller internal principal;

    function setUp() public override {
        super.setUp();
        attacker = new MidSessionAttacker(address(seRouter));
        principal = new PrincipalCaller(address(seRouter));
    }

    /// @dev Session-off: random EOA cannot prepay.
    function testFuzz_P_AUTH_eoaPrepayReverts(uint256 amtSeed) public {
        uint256 amt = bound(amtSeed, 1, 1_000_000e18);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amt;
        amounts[1] = amt;
        address eoa = makeAddr(string(abi.encodePacked("atk", amtSeed)));
        vm.prank(eoa);
        vm.expectRevert(
            abi.encodeWithSelector(BalancerV3StandardExchangeRouterRepo.PrepayNotAuthorized.selector, eoa)
        );
        prepayRouter.prepayAddLiquidityUnbalanced(daiUsdcPool, amounts, 0, "");
    }

    /// @dev P-AUTH-TOP: when session is on and principal is top, attacker prepay reverts NotPrepayAuthTop.
    function testFuzz_P_AUTH_TOP_sessionActive_nonTopPrepayReverts(uint256 amtSeed) public {
        uint256 amt = bound(amtSeed, 1, 100e18);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amt;
        amounts[1] = amt;
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

    /// @dev P-PASS: non-top cannot pass while session active.
    function testFuzz_P_PASS_sessionActive_nonTopPassReverts(address next) public {
        vm.assume(next != address(0));
        vm.expectRevert(
            abi.encodeWithSelector(
                BalancerV3StandardExchangeRouterRepo.NotAuthorizedToPass.selector,
                address(attacker),
                address(principal)
            )
        );
        prepaySessionHarness.withPrepaySession(
            address(principal), address(attacker), abi.encodeCall(attacker.attackPass, (next))
        );
        assertFalse(prepayRouter.prepaySessionActive());
    }

    /// @dev P-SESSION-END: after successful direct swap, session inactive.
    function testFuzz_P_SESSION_afterSwap(uint256 amountInSeed) public {
        uint256 amountIn = bound(amountInSeed, 1e15, TEST_AMOUNT);
        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);
        deal(address(token0), alice, amountIn);
        vm.startPrank(alice);
        token0.approve(address(permit2), type(uint256).max);
        permit2.approve(address(token0), address(seRouter), type(uint160).max, type(uint48).max);
        seRouter.swapSingleTokenExactIn(
            daiUsdcPool, token0, _noVault(), token1, _noVault(), amountIn, 0, type(uint256).max, false, ""
        );
        vm.stopPrank();
        assertFalse(prepayRouter.prepaySessionActive());
        assertEq(prepayRouter.prepayAuthDepth(), 0);
    }

    /// @dev Pass is no-op when session off.
    function testFuzz_P_PASS_noopSessionOff(address next) public {
        assertTrue(prepayRouter.passPrepayAuth(next));
        assertFalse(prepayRouter.prepaySessionActive());
        assertEq(prepayRouter.prepayAuthDepth(), 0);
    }
}
