// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {ModifyLiquidityParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {
    TestBase_UniswapV4QuadStableSwapHook
} from "contracts/hooks/uniswap/v4/stable/quad/TestBase_UniswapV4QuadStableSwapHook.sol";

/**
 * @title UniswapV4QuadStableSwapHook_Safety_Test
 * @notice CL ban, donate ban, wrong init keys, donation pricing.
 */
contract UniswapV4QuadStableSwapHook_Safety_Test is TestBase_UniswapV4QuadStableSwapHook {
    function test_I2_clAddLiquidity_reverts() public {
        _addLiquidityFirst(1_000);
        PoolKey memory key = _poolKeys()[0];
        // direct hook call as pool manager
        vm.prank(address(pm));
        vm.expectRevert();
        IHooks(hook).beforeAddLiquidity(
            address(this),
            key,
            ModifyLiquidityParams({tickLower: -1, tickUpper: 1, liquidityDelta: 1, salt: bytes32(0)}),
            ""
        );
    }

    function test_I2_donate_reverts() public {
        // beforeDonate is view+onlyPoolManager; call as PM must revert DonateNotAllowed
        vm.prank(address(pm));
        (bool ok,) = hook.call(
            abi.encodeWithSelector(
                IHooks.beforeDonate.selector, address(this), _poolKeys()[0], uint256(1), uint256(1), ""
            )
        );
        assertFalse(ok);
    }

    function test_donation_ignored_for_pricing() public {
        _addLiquidityFirst(1_000);
        uint256 amtIn = _raw(t0, 10);
        uint256 predBefore = quad.previewSwapExactIn(address(t0), address(t1), amtIn);
        t0.mint(hook, _raw(t0, 1_000));
        uint256 predAfter = quad.previewSwapExactIn(address(t0), address(t1), amtIn);
        assertEq(predBefore, predAfter);
    }
}
