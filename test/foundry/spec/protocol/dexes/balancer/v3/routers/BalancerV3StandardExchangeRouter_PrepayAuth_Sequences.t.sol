// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {
    BalancerV3StandardExchangeRouterRepo
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterRepo.sol";
import {
    TestBase_BalancerV3StandardExchangeRouter
} from "contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol";

/**
 * @title BalancerV3StandardExchangeRouter_PrepayAuth_Sequences
 * @notice L2 multi-step sequences: victim swap then attacker prepay; session sticky checks.
 */
contract BalancerV3StandardExchangeRouter_PrepayAuth_Sequences_Test is TestBase_BalancerV3StandardExchangeRouter {
    IBalancerV3StandardExchangeRouterPrepay internal prepayRouter;

    function setUp() public override {
        super.setUp();
        prepayRouter = IBalancerV3StandardExchangeRouterPrepay(address(seRouter));
    }

    function test_invariantSequence_victimSwapThenAttackerPrepay() public {
        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);
        uint256 amountIn = TEST_AMOUNT;
        deal(address(token0), alice, amountIn);
        vm.startPrank(alice);
        token0.approve(address(permit2), type(uint256).max);
        permit2.approve(address(token0), address(seRouter), type(uint160).max, type(uint48).max);
        seRouter.swapSingleTokenExactIn(
            daiUsdcPool, token0, _noVault(), token1, _noVault(), amountIn, 0, type(uint256).max, false, ""
        );
        vm.stopPrank();

        assertFalse(prepayRouter.prepaySessionActive());

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1e18;
        amounts[1] = 1e18;
        address attacker = makeAddr("attacker");
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(BalancerV3StandardExchangeRouterRepo.PrepayNotAuthorized.selector, attacker)
        );
        prepayRouter.prepayAddLiquidityUnbalanced(daiUsdcPool, amounts, 0, "");
    }

    function testFuzz_invariantSequence_victimThenAttacker(uint256 victimIn, uint256 attackAmt) public {
        victimIn = bound(victimIn, 1e15, TEST_AMOUNT);
        attackAmt = bound(attackAmt, 1, 100e18);
        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);
        deal(address(token0), alice, victimIn);
        vm.startPrank(alice);
        token0.approve(address(permit2), type(uint256).max);
        permit2.approve(address(token0), address(seRouter), type(uint160).max, type(uint48).max);
        seRouter.swapSingleTokenExactIn(
            daiUsdcPool, token0, _noVault(), token1, _noVault(), victimIn, 0, type(uint256).max, false, ""
        );
        vm.stopPrank();

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = attackAmt;
        amounts[1] = attackAmt;
        address attacker = makeAddr("attacker2");
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(BalancerV3StandardExchangeRouterRepo.PrepayNotAuthorized.selector, attacker)
        );
        prepayRouter.prepayAddLiquidityUnbalanced(daiUsdcPool, amounts, 0, "");
        assertFalse(prepayRouter.prepaySessionActive());
    }
}
