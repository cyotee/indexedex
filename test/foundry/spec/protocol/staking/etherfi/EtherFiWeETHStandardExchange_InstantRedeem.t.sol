// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_EtherFiWeETHStandardExchange} from
    "contracts/test/bases/TestBase_EtherFiWeETHStandardExchange.sol";
import {
    IEtherFiWeETHStandardVault
} from "contracts/protocols/staking/etherfi/interfaces/IEtherFiWeETHStandardVault.sol";

/**
 * @title EtherFiWeETHStandardExchange_InstantRedeem_Test
 * @notice IR1–IR5: WETH pay ladder with hermetic RedemptionManager.
 */
contract EtherFiWeETHStandardExchange_InstantRedeem_Test is TestBase_EtherFiWeETHStandardExchange {
    function test_IR1_sleeveShort_redeemCovers_success() public {
        _seedVaultInventory(0, 50 ether);
        // sleeve almost empty
        _fundSleeve(0.5 ether);
        uint256 weBefore = hermeticWeEth.balanceOf(seVault);

        _enableRedeem(20 ether);

        uint256 amountOut = 5 ether; // needs redeem of ~4.5
        uint256 previewIn =
            seOut.previewExchangeOut(IERC20(seVault), IERC20(address(hermeticWeth)), amountOut);
        uint256 balBefore = hermeticWeth.balanceOf(address(this));
        uint256 amountIn = seOut.exchangeOut(
            IERC20(seVault),
            previewIn,
            IERC20(address(hermeticWeth)),
            amountOut,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(amountIn, previewIn);
        assertEq(hermeticWeth.balanceOf(address(this)) - balBefore, amountOut);
        assertLt(hermeticWeEth.balanceOf(seVault), weBefore);
    }

    function test_IR2_sleeveShort_redeemCapacity0_reverts() public {
        _seedVaultInventory(0, 50 ether);
        _fundSleeve(0.5 ether);
        // capacity remains 0
        assertEq(hermeticRedeem.capacityEth(), 0);

        uint256 amountOut = 5 ether;
        uint256 available = etherFiSe.liquidReserveEth();
        vm.expectRevert(
            abi.encodeWithSelector(
                IEtherFiWeETHStandardVault.InsufficientLiquidReserve.selector, amountOut, available
            )
        );
        seOut.exchangeOut(
            IERC20(seVault),
            type(uint256).max,
            IERC20(address(hermeticWeth)),
            amountOut,
            address(this),
            false,
            block.timestamp + 1 hours
        );
    }

    function test_IR3_redeemFee_minOutEnforced() public {
        _seedVaultInventory(0, 50 ether);
        _fundSleeve(0);
        hermeticRedeem.setExitFeeBps(500); // 5%
        _enableRedeem(20 ether);

        // SE → WETH exact-in: quote assumes 1:1 sleeve path; with fee, execution may under-deliver
        // relative to minOut = preview. Use a high minOut that should fail after fee.
        uint256 shares = IERC20(seVault).balanceOf(address(this)) / 10;
        uint256 preview = seIn.previewExchangeIn(IERC20(seVault), shares, IERC20(address(hermeticWeth)));
        // Require full preview; redeem pays less after fee → Slippage
        vm.expectRevert(); // Slippage or InsufficientLiquidReserve depending on capacity after fee
        seIn.exchangeIn(
            IERC20(seVault),
            shares,
            IERC20(address(hermeticWeth)),
            preview, // minOut = full face
            address(this),
            false,
            block.timestamp + 1 hours
        );
    }

    function test_IR4_exactInAndOut_seToWeth_useLadder() public {
        _seedVaultInventory(0, 50 ether);
        _fundSleeve(1 ether);
        _enableRedeem(30 ether);

        // exact-out
        uint256 amountOut = 5 ether;
        uint256 pin = seOut.previewExchangeOut(IERC20(seVault), IERC20(address(hermeticWeth)), amountOut);
        seOut.exchangeOut(
            IERC20(seVault), pin, IERC20(address(hermeticWeth)), amountOut, address(this), false, block.timestamp + 1 hours
        );

        // exact-in
        uint256 shares = IERC20(seVault).balanceOf(address(this)) / 10;
        uint256 preview = seIn.previewExchangeIn(IERC20(seVault), shares, IERC20(address(hermeticWeth)));
        // Allow dust under-delivery if fee=0 (fee=0 so should match)
        uint256 out = seIn.exchangeIn(
            IERC20(seVault), shares, IERC20(address(hermeticWeth)), preview, address(this), false, block.timestamp + 1 hours
        );
        assertEq(out, preview);
    }

    function test_IR5_weethToWeth_inventorySwap_usesLadder() public {
        _seedVaultInventory(0, 20 ether);
        _fundSleeve(0.2 ether);
        _enableRedeem(20 ether);

        uint256 amount = 3 ether;
        _mintWeViaE(address(this), amount);
        hermeticWeEth.approve(seVault, amount);

        // exact-in
        uint256 preview =
            seIn.previewExchangeIn(IERC20(address(hermeticWeEth)), amount, IERC20(address(hermeticWeth)));
        uint256 out = seIn.exchangeIn(
            IERC20(address(hermeticWeEth)),
            amount,
            IERC20(address(hermeticWeth)),
            preview,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, preview);

        // exact-out
        amount = 2 ether;
        _mintWeViaE(address(this), amount);
        hermeticWeEth.approve(seVault, amount);
        uint256 pin =
            seOut.previewExchangeOut(IERC20(address(hermeticWeEth)), IERC20(address(hermeticWeth)), amount);
        // pull needs pin weETH
        if (pin > amount) {
            _mintWeViaE(address(this), pin - amount);
            hermeticWeEth.approve(seVault, pin);
        }
        uint256 ain = seOut.exchangeOut(
            IERC20(address(hermeticWeEth)),
            pin,
            IERC20(address(hermeticWeth)),
            amount,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(ain, pin);
    }
}
