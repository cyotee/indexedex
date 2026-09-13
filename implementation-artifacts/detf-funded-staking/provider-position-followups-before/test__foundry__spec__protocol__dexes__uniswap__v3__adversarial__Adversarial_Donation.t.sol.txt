// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {
    TestBase_UniswapV3StandardExchange_Adversarial
} from "test/foundry/spec/protocol/dexes/uniswap/v3/adversarial/TestBase_UniswapV3StandardExchange_Adversarial.sol";

contract Adversarial_Donation_Test is TestBase_UniswapV3StandardExchange_Adversarial {
    function test_A1_donation_doesNotGrantFreeSharesAsPrincipal() public {
        address token0 = pool.token0();
        // Incumbent deposits.
        ERC20PermitMintableStub(token0).mint(victim, 100 ether);
        vm.startPrank(victim);
        IERC20(token0).approve(address(vault), type(uint256).max);
        uint256 shares =
            vault.exchangeIn(IERC20(token0), 100 ether, IERC20(address(vault)), 0, victim, false, block.timestamp + 1);
        vm.stopPrank();

        // Attacker donates tokens directly.
        ERC20PermitMintableStub(token0).mint(attacker, 50 ether);
        vm.prank(attacker);
        IERC20(token0).transfer(address(vault), 50 ether);

        // Next depositor only gets shares for own principal (donation stays free inventory / compounds for incumbents).
        ERC20PermitMintableStub(token0).mint(attacker, 1 ether);
        vm.startPrank(attacker);
        IERC20(token0).approve(address(vault), type(uint256).max);
        uint256 attackerShares =
            vault.exchangeIn(IERC20(token0), 1 ether, IERC20(address(vault)), 0, attacker, false, block.timestamp + 1);
        vm.stopPrank();

        assertLt(attackerShares, shares / 5, "donation not free-minted to attacker");
        assertEq(IERC20(address(vault)).balanceOf(victim), shares);
    }

    function test_A3_feeTiming_tinyZapAfterFees() public {
        address token0 = pool.token0();
        ERC20PermitMintableStub(token0).mint(victim, 200 ether);
        vm.startPrank(victim);
        IERC20(token0).approve(address(vault), type(uint256).max);
        uint256 incumbent =
            vault.exchangeIn(IERC20(token0), 200 ether, IERC20(address(vault)), 0, victim, false, block.timestamp + 1);
        vm.stopPrank();

        _externalSwapExactIn(pool, true, 40_000 ether);
        _externalSwapExactIn(pool, false, 40_000 ether);

        ERC20PermitMintableStub(token0).mint(attacker, 1 ether);
        vm.startPrank(attacker);
        IERC20(token0).approve(address(vault), type(uint256).max);
        uint256 attackerShares =
            vault.exchangeIn(IERC20(token0), 1 ether, IERC20(address(vault)), 0, attacker, false, block.timestamp + 1);
        vm.stopPrank();

        assertLt(attackerShares, incumbent / 20, "attacker only own principal");
        assertEq(IERC20(address(vault)).balanceOf(victim), incumbent);
    }
}
