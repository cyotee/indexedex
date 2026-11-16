// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4BalancerQuadStableSwapHook
} from "contracts/hooks/uniswap/v4/stable/quad/balancer/TestBase_UniswapV4BalancerQuadStableSwapHook.sol";
import {
    UniswapV4BalancerQuadStableSwapHook_FactoryService as FactoryService
} from "contracts/hooks/uniswap/v4/stable/quad/balancer/UniswapV4BalancerQuadStableSwapHook_FactoryService.sol";
import {
    UniswapV4HookDiamondCreate2Lib as Create2Lib
} from "contracts/hooks/uniswap/v4/factory/libs/UniswapV4HookDiamondCreate2Lib.sol";

/**
 * @title UniswapV4BalancerQuadStableSwapHook_Deploy_Test
 * @notice Hook diamond package path: binding views + flag address bits.
 */
contract UniswapV4BalancerQuadStableSwapHook_Deploy_Test is TestBase_UniswapV4BalancerQuadStableSwapHook {
    function test_deploy_bindingViews() public view {
        assertEq(address(quad.poolManager()), address(pm));
        assertEq(quad.token0(), address(t0));
        assertEq(quad.token1(), address(t1));
        assertEq(quad.token2(), address(t2));
        assertEq(quad.token3(), address(t3));
        assertEq(quad.lpFeePips(), DEMO_FEE);
        assertEq(quad.baseAmp(), DEMO_AMP);
        assertEq(quad.getCurrentAmp(), DEMO_AMP * 1e3); // Balancer AMP_PRECISION
    }

    function test_hookAddress_hasRequiredFlags() public view {
        uint160 flags = FactoryService.requiredFlags();
        assertEq(uint160(hook) & Create2Lib.FLAG_MASK, flags & Create2Lib.FLAG_MASK);
    }

    function test_deploy_registersVault() public view {
        assertTrue(_registry().isVault(hook), "registered vault");
    }
}
