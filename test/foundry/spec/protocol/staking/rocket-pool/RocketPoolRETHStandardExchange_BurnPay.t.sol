// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_RocketPoolRETHStandardExchange} from
    "contracts/test/bases/TestBase_RocketPoolRETHStandardExchange.sol";
import {
    IRocketPoolRETHStandardVault
} from "contracts/protocols/staking/rocket-pool/interfaces/IRocketPoolRETHStandardVault.sol";

/**
 * @title RocketPoolRETHStandardExchange_BurnPay_Test
 * @notice WETH pay ladder: sleeve → rETH.burn → InsufficientLiquidReserve.
 */
contract RocketPoolRETHStandardExchange_BurnPay_Test is TestBase_RocketPoolRETHStandardExchange {
    function test_BP1_sleeveShort_burnCovers() public {
        // Lock rETH via mint; empty sleeve; fund collateral for burn
        _seedVaultInventory(0, 30 ether);
        assertEq(rocketPoolSe.liquidReserveEth(), 0);
        _enableBurn(20 ether);

        uint256 amountOut = 2 ether;
        uint256 rethBefore = hermeticReth.balanceOf(seVault);
        uint256 previewIn = seOut.previewExchangeOut(IERC20(seVault), IERC20(address(hermeticWeth)), amountOut);
        uint256 balBefore = hermeticWeth.balanceOf(address(this));
        seOut.exchangeOut(
            IERC20(seVault),
            previewIn,
            IERC20(address(hermeticWeth)),
            amountOut,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(hermeticWeth.balanceOf(address(this)) - balBefore, amountOut);
        assertLt(hermeticReth.balanceOf(seVault), rethBefore);
    }

    function test_BP2_sleeveShort_collateral0_reverts() public {
        _seedVaultInventory(0, 20 ether);
        assertEq(rocketPoolSe.liquidReserveEth(), 0);
        // no collateral
        uint256 requested = 1 ether;
        vm.expectRevert(
            abi.encodeWithSelector(IRocketPoolRETHStandardVault.InsufficientLiquidReserve.selector, requested, 0)
        );
        seOut.exchangeOut(
            IERC20(seVault),
            type(uint256).max,
            IERC20(address(hermeticWeth)),
            requested,
            address(this),
            false,
            block.timestamp + 1 hours
        );
    }

    function test_BP3_exactInAndOut_seToWeth_useLadder() public {
        _seedVaultInventory(0, 40 ether);
        _enableBurn(30 ether);

        // exact-in
        uint256 sharesIn = IERC20(seVault).balanceOf(address(this)) / 10;
        uint256 preview = seIn.previewExchangeIn(IERC20(seVault), sharesIn, IERC20(address(hermeticWeth)));
        uint256 out = seIn.exchangeIn(
            IERC20(seVault),
            sharesIn,
            IERC20(address(hermeticWeth)),
            preview,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, preview);

        // exact-out
        uint256 amountOut = 1 ether;
        uint256 pin = seOut.previewExchangeOut(IERC20(seVault), IERC20(address(hermeticWeth)), amountOut);
        seOut.exchangeOut(
            IERC20(seVault),
            pin,
            IERC20(address(hermeticWeth)),
            amountOut,
            address(this),
            false,
            block.timestamp + 1 hours
        );
    }

    function test_BP4_rethToWeth_inventory_usesLadder() public {
        // No sleeve - must burn vault rETH after inventory credit... wait:
        // rETH→WETH keeps user rETH as locked inventory and pays WETH via ladder.
        // Vault needs locked rETH to burn if sleeve empty - user rETH is pulled first so vault has it.
        // Burn uses vault rETH including the just-pulled amount? Actually pay uses eth face of amountIn
        // and burns shortfall from vault inventory which includes the credited rETH.
        _enableBurn(10 ether);
        uint256 amount = 2 ether;
        _mintReth(address(this), amount);
        hermeticReth.approve(seVault, amount);
        uint256 preview = seIn.previewExchangeIn(
            IERC20(address(hermeticReth)), amount, IERC20(address(hermeticWeth))
        );
        uint256 balBefore = hermeticWeth.balanceOf(address(this));
        uint256 out = seIn.exchangeIn(
            IERC20(address(hermeticReth)),
            amount,
            IERC20(address(hermeticWeth)),
            preview,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, preview);
        assertEq(hermeticWeth.balanceOf(address(this)) - balBefore, out);
    }

    function test_BP5_minOut_enforced_whenBurnUsed() public {
        _seedVaultInventory(0, 20 ether);
        _enableBurn(10 ether);
        uint256 sharesIn = IERC20(seVault).balanceOf(address(this)) / 5;
        uint256 preview = seIn.previewExchangeIn(IERC20(seVault), sharesIn, IERC20(address(hermeticWeth)));
        vm.expectRevert(abi.encodeWithSelector(IRocketPoolRETHStandardVault.Slippage.selector));
        seIn.exchangeIn(
            IERC20(seVault),
            sharesIn,
            IERC20(address(hermeticWeth)),
            preview + 1,
            address(this),
            false,
            block.timestamp + 1 hours
        );
    }
}
