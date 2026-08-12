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
    TestBase_UniswapV3StandardExchange_Adversarial
} from "test/foundry/spec/protocol/dexes/uniswap/v3/adversarial/TestBase_UniswapV3StandardExchange_Adversarial.sol";

contract Adversarial_CallbackAuth_Test is TestBase_UniswapV3StandardExchange_Adversarial {
    function test_D1_callbackSpoof_revertsBalancesUnchanged() public {
        address token0 = pool.token0();
        address token1 = pool.token1();
        // Fund vault with inventory so spoof would be profitable if allowed.
        ERC20PermitMintableStub_mint(token0, address(vault), 10 ether);
        ERC20PermitMintableStub_mint(token1, address(vault), 10 ether);
        uint256 bal0 = IERC20(token0).balanceOf(address(vault));
        uint256 bal1 = IERC20(token1).balanceOf(address(vault));

        vm.prank(attacker);
        vm.expectRevert();
        IUniswapV3MintCallback(address(vault)).uniswapV3MintCallback(1 ether, 1 ether, "");

        vm.prank(attacker);
        vm.expectRevert();
        IUniswapV3SwapCallback(address(vault)).uniswapV3SwapCallback(int256(1 ether), int256(1 ether), "");

        assertEq(IERC20(token0).balanceOf(address(vault)), bal0);
        assertEq(IERC20(token1).balanceOf(address(vault)), bal1);
    }

    function ERC20PermitMintableStub_mint(address token, address to, uint256 amount) internal {
        (bool ok,) = token.call(abi.encodeWithSignature("mint(address,uint256)", to, amount));
        require(ok, "mint");
    }
}
