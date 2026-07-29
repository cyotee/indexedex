// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {
    TestBase_UniswapV3StandardExchange_Adversarial
} from "test/foundry/spec/protocol/dexes/uniswap/v3/adversarial/TestBase_UniswapV3StandardExchange_Adversarial.sol";

contract Adversarial_Accounting_Test is TestBase_UniswapV3StandardExchange_Adversarial {
    function test_E1_roundTrip_zapInOut_conservation() public {
        address token0 = pool.token0();
        ERC20PermitMintableStub(token0).mint(attacker, 100 ether);
        vm.startPrank(attacker);
        IERC20(token0).approve(address(vault), type(uint256).max);
        uint256 shares =
            vault.exchangeIn(IERC20(token0), 100 ether, IERC20(address(vault)), 0, attacker, false, block.timestamp + 1);
        uint256 balBefore = IERC20(token0).balanceOf(attacker);
        vault.exchangeOut(
            IERC20(address(vault)), shares, IERC20(token0), 1, attacker, false, block.timestamp + 1
        );
        vm.stopPrank();
        uint256 recovered = IERC20(token0).balanceOf(attacker) - balBefore;
        // Fees/slippage on wing path; recovery should be positive and not exceed deposit.
        assertGt(recovered, 0);
        assertLe(recovered, 100 ether);
        _assertNoUnexpectedFreeInventory(1 ether);
    }

    function test_E2_zeroAmountAndDeadline() public {
        address token0 = pool.token0();
        address token1 = pool.token1();
        ERC20PermitMintableStub(token0).mint(attacker, 1 ether);
        vm.warp(1000);
        vm.startPrank(attacker);
        IERC20(token0).approve(address(vault), type(uint256).max);
        vm.expectRevert();
        vault.exchangeIn(IERC20(token0), 0, IERC20(address(vault)), 0, attacker, false, block.timestamp + 1);
        vm.expectRevert();
        vault.exchangeIn(IERC20(token0), 1 ether, IERC20(token1), 0, attacker, false, 1);
        vm.stopPrank();
        assertEq(IERC20(address(vault)).totalSupply(), 0);
    }

    function test_E3_slippage_atomicNoPartialMint() public {
        address token0 = pool.token0();
        ERC20PermitMintableStub(token0).mint(attacker, 50 ether);
        vm.startPrank(attacker);
        IERC20(token0).approve(address(vault), type(uint256).max);
        vm.expectRevert();
        vault.exchangeIn(
            IERC20(token0), 50 ether, IERC20(address(vault)), type(uint256).max, attacker, false, block.timestamp + 1
        );
        vm.stopPrank();
        assertEq(IERC20(address(vault)).totalSupply(), 0);
    }

    function test_E4_successPath_residualPolicy() public {
        address token0 = pool.token0();
        ERC20PermitMintableStub(token0).mint(attacker, 50 ether);
        vm.startPrank(attacker);
        IERC20(token0).approve(address(vault), type(uint256).max);
        vault.exchangeIn(IERC20(token0), 50 ether, IERC20(address(vault)), 0, attacker, false, block.timestamp + 1);
        vm.stopPrank();
        _assertNoUnexpectedFreeInventory(1 ether);
    }
}
