// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4QuadStableSwapHook
} from "contracts/hooks/uniswap/v4/stable/quad/TestBase_UniswapV4QuadStableSwapHook.sol";
import {
    UniswapV4QuadStableSwapHook_FactoryService as FactoryService
} from "contracts/hooks/uniswap/v4/stable/quad/UniswapV4QuadStableSwapHook_FactoryService.sol";
import {HookMinerCreate3} from
    "@crane/contracts/protocols/dexes/uniswap/v4/hooks/public/utils/HookMinerCreate3.sol";

/**
 * @title UniswapV4QuadStableSwapHook_Deploy_Test
 * @notice CREATE3 mine flags + hook binding views.
 */
contract UniswapV4QuadStableSwapHook_Deploy_Test is TestBase_UniswapV4QuadStableSwapHook {
    function test_deploy_bindingViews() public view {
        assertEq(address(quad.poolManager()), address(pm));
        assertEq(quad.token0(), address(t0));
        assertEq(quad.token1(), address(t1));
        assertEq(quad.token2(), address(t2));
        assertEq(quad.token3(), address(t3));
        assertEq(quad.lpFeePips(), DEMO_FEE);
        assertEq(quad.baseAmp(), DEMO_AMP);
        assertEq(quad.getCurrentAmp(), DEMO_AMP * 100);
    }

    function test_hookAddress_hasRequiredFlags() public view {
        uint160 flags = FactoryService.requiredFlags();
        assertEq(uint160(hook) & HookMinerCreate3.FLAG_MASK, flags);
    }
}
