// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_UniswapV3StandardExchange_Adversarial_Decimals
} from "test/foundry/spec/protocol/dexes/uniswap/v3/decimals/adversarial/TestBase_UniswapV3StandardExchange_Adversarial_Decimals.sol";

/// @notice Price manipulation. pairToken = tokenA. Amounts are raw units via `_u0`.
abstract contract Adversarial_PriceManipulation_Decimals_ProDexUniV3 is TestBase_UniswapV3StandardExchange_Adversarial_Decimals {
    function test_B1_spotManip_noUnboundedFreeLunch() public {
        address token0 = pool.token0();
        uint256 victimIn = _u0(100);
        _mint(token0, victim, victimIn);
        vm.startPrank(victim);
        IERC20(token0).approve(address(vault), type(uint256).max);
        uint256 shares =
            _activateWithFundedToken0(victim, victimIn, _u1(100));
        vm.stopPrank();

        _swapHuman(pool, true, 5_000);

        uint256 attackerIn = _u0(10);
        _mint(token0, attacker, attackerIn);
        uint256 balBefore = IERC20(token0).balanceOf(attacker);
        vm.startPrank(attacker);
        IERC20(token0).approve(address(vault), type(uint256).max);
        uint256 aShares =
            vault.exchangeIn(IERC20(token0), attackerIn, IERC20(address(vault)), 0, attacker, false, block.timestamp + 1);
        vm.stopPrank();

        _swapHuman(pool, false, 5_000);

        vm.startPrank(attacker);
        uint256 balMid = IERC20(token0).balanceOf(attacker);
        try vault.exchangeOut(
            IERC20(address(vault)), aShares, IERC20(token0), 1 wei, attacker, false, block.timestamp + 1
        ) returns (uint256 burned) {
            assertLe(burned, aShares);
        } catch {}
        vm.stopPrank();

        uint256 balAfter = IERC20(token0).balanceOf(attacker);
        if (balAfter > balBefore) {
            assertLt(balAfter - balBefore, attackerIn, "bounded");
        }
        assertEq(IERC20(address(vault)).balanceOf(victim), shares);
        assertGt(aShares, 0);
        balMid;
    }
}
