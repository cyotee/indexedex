// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {
    TestBase_UniswapV3StandardExchange_Adversarial
} from "test/foundry/spec/protocol/dexes/uniswap/v3/adversarial/TestBase_UniswapV3StandardExchange_Adversarial.sol";

contract Adversarial_Accounting_Test is TestBase_UniswapV3StandardExchange_Adversarial {
    function test_E1_roundTrip_zapInOut_conservation() public {
        address token0 = pool.token0();
        uint256 deposit = 100 ether;
        // A separate holder provides both activation assets. The attacker pays only token0.
        ERC20PermitMintableStub(token0).mint(victim, deposit);
        vm.startPrank(victim);
        IERC20(token0).approve(address(vault), type(uint256).max);
        _activateWithFundedToken0(victim, deposit, 100 ether);
        vm.stopPrank();

        ERC20PermitMintableStub(token0).mint(attacker, deposit);
        uint256 beforePayment = IERC20(token0).balanceOf(attacker);
        vm.startPrank(attacker);
        IERC20(token0).approve(address(vault), type(uint256).max);
        uint256 shares = vault.exchangeIn(
            IERC20(token0), deposit, IERC20(address(vault)), 0, attacker, false, block.timestamp + 1
        );
        vault.approve(address(vault), shares);
        uint256 beforeRedemption = IERC20(token0).balanceOf(attacker);
        uint256 recovered = vault.exchangeIn(
            IERC20(address(vault)), shares, IERC20(token0), 1, attacker, false, block.timestamp + 1
        );
        vm.stopPrank();
        assertEq(vault.balanceOf(attacker), 0, "all attacker shares redeemed");
        assertEq(IERC20(token0).balanceOf(attacker) - beforeRedemption, recovered, "actual recovery");
        assertGt(recovered, 0);
        assertLe(IERC20(token0).balanceOf(attacker), beforePayment, "round trip cannot exceed payment");
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
        (address[] memory tokens, uint256[] memory amounts) = _activationInputs(
            attacker, 50 ether, 50 ether
        );
        vm.expectRevert(bytes4(keccak256("UniswapV3ExchangeIn_SlippageExceeded()")));
        IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(vault)), type(uint256).max, attacker, false, block.timestamp + 1
        );
        vm.stopPrank();
        assertEq(IERC20(address(vault)).totalSupply(), 0);
    }

    function test_E4_successPath_residualPolicy() public {
        address token0 = pool.token0();
        ERC20PermitMintableStub(token0).mint(attacker, 50 ether);
        vm.startPrank(attacker);
        IERC20(token0).approve(address(vault), type(uint256).max);
        _activateWithFundedToken0(attacker, 50 ether, 50 ether);
        vm.stopPrank();
        _assertNoUnexpectedFreeInventory(1 ether);
    }
}
