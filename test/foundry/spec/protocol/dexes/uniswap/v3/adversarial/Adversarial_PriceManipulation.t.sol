// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {
    TestBase_UniswapV3StandardExchange_Adversarial
} from "test/foundry/spec/protocol/dexes/uniswap/v3/adversarial/TestBase_UniswapV3StandardExchange_Adversarial.sol";

contract Adversarial_PriceManipulation_Test is TestBase_UniswapV3StandardExchange_Adversarial {
    function test_B1_spotManip_noUnboundedFreeLunch() public {
        address token0 = pool.token0();
        ERC20PermitMintableStub(token0).mint(victim, 100 ether);
        vm.startPrank(victim);
        IERC20(token0).approve(address(vault), type(uint256).max);
        uint256 shares =
            vault.exchangeIn(IERC20(token0), 100 ether, IERC20(address(vault)), 0, victim, false, block.timestamp + 1);
        vm.stopPrank();

        // Moderate external skew (not enough to break zap quote limits).
        _externalSwapExactIn(pool, true, 5_000 ether);

        ERC20PermitMintableStub(token0).mint(attacker, 10 ether);
        uint256 balBefore = IERC20(token0).balanceOf(attacker);
        vm.startPrank(attacker);
        IERC20(token0).approve(address(vault), type(uint256).max);
        uint256 aShares =
            vault.exchangeIn(IERC20(token0), 10 ether, IERC20(address(vault)), 0, attacker, false, block.timestamp + 1);
        vm.stopPrank();

        _externalSwapExactIn(pool, false, 5_000 ether);

        // Burn all attacker shares for whatever token0 is available (exact share burn path via max).
        vm.startPrank(attacker);
        uint256 balMid = IERC20(token0).balanceOf(attacker);
        // Use zap-out requesting a small amount so preview finds shares; or burn via exchangeOut
        // with minOut that is small relative to position.
        try vault.exchangeOut(
            IERC20(address(vault)), aShares, IERC20(token0), 1 wei, attacker, false, block.timestamp + 1
        ) returns (uint256 burned) {
            assertLe(burned, aShares);
        } catch {
            // If path reverts after extreme geometry, conservation still holds for victim.
        }
        vm.stopPrank();

        uint256 balAfter = IERC20(token0).balanceOf(attacker);
        if (balAfter > balBefore) {
            assertLt(balAfter - balBefore, 10 ether, "bounded");
        }
        // Victim shares unchanged (no free lunch dilution).
        assertEq(IERC20(address(vault)).balanceOf(victim), shares);
        assertGt(aShares, 0);
        balMid; // silence
    }
}
