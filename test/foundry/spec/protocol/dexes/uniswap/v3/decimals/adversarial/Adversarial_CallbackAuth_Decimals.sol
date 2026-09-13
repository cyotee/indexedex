// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    IUniswapV3MintCallback
} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3MintCallback.sol";
import {
    IUniswapV3SwapCallback
} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3SwapCallback.sol";
import {
    TestBase_UniswapV3StandardExchange_Adversarial_Decimals
} from "test/foundry/spec/protocol/dexes/uniswap/v3/decimals/adversarial/TestBase_UniswapV3StandardExchange_Adversarial_Decimals.sol";

/// @notice Callback auth. pairToken = tokenA. Amounts are raw units via `_u0`/`_u1`.
abstract contract Adversarial_CallbackAuth_Decimals is TestBase_UniswapV3StandardExchange_Adversarial_Decimals {
    function test_D1_callbackSpoof_revertsBalancesUnchanged() public {
        address token0 = pool.token0();
        address token1 = pool.token1();
        _mint(token0, address(vault), _u0(10));
        _mint(token1, address(vault), _u1(10));
        uint256 bal0 = IERC20(token0).balanceOf(address(vault));
        uint256 bal1 = IERC20(token1).balanceOf(address(vault));

        uint256 a0 = _u0(1);
        uint256 a1 = _u1(1);
        vm.prank(attacker);
        vm.expectRevert();
        IUniswapV3MintCallback(address(vault)).uniswapV3MintCallback(a0, a1, "");

        vm.prank(attacker);
        vm.expectRevert();
        IUniswapV3SwapCallback(address(vault)).uniswapV3SwapCallback(int256(a0), int256(a1), "");

        assertEq(IERC20(token0).balanceOf(address(vault)), bal0);
        assertEq(IERC20(token1).balanceOf(address(vault)), bal1);
    }
}
