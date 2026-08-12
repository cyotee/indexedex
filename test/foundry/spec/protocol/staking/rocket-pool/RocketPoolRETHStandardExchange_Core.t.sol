// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {TestBase_RocketPoolRETHStandardExchange} from
    "contracts/test/bases/TestBase_RocketPoolRETHStandardExchange.sol";
import {
    IRocketPoolRETHStandardVault
} from "contracts/protocols/staking/rocket-pool/interfaces/IRocketPoolRETHStandardVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";

/**
 * @title RocketPoolRETHStandardExchange_Core_Test
 * @notice Deploy, dual-surface route matrix, preview==exec, soft stake, sleeve shortfall.
 */
contract RocketPoolRETHStandardExchange_Core_Test is TestBase_RocketPoolRETHStandardExchange {
    function test_D1_deploy_markerAndTokens() public view {
        assertEq(rocketPoolSe.rETH(), address(hermeticReth));
        assertEq(rocketPoolSe.weth(), address(hermeticWeth));
        assertEq(rocketPoolSe.depositPool(), address(hermeticPool));
        assertEq(IERC4626(seVault).asset(), address(hermeticReth));
        assertEq(
            IVaultFeeOracleQuery(address(indexedexManager)).liquidReservePercentageOfVault(seVault),
            DEFAULT_LIQUID_PCT
        );
    }

    function test_Q2_L3_preview_wethOut_zeroSleeve_stillNonZero() public {
        _seedVaultInventory(0, 20 ether);
        assertEq(rocketPoolSe.liquidReserveEth(), 0);

        uint256 seBal = IERC20(seVault).balanceOf(address(this));
        assertGt(seBal, 0);
        uint256 preview = seIn.previewExchangeIn(IERC20(seVault), seBal / 4, IERC20(address(hermeticWeth)));
        assertGt(preview, 0);

        uint256 requested = 1 ether;
        uint256 sharesIn = seOut.previewExchangeOut(IERC20(seVault), IERC20(address(hermeticWeth)), requested);
        assertGt(sharesIn, 0);
    }

    function test_Q3_preview_capacity0_stillNonZero() public {
        hermeticPool.setMaxDepositAmount(0);
        uint256 previewSe = seIn.previewExchangeIn(IERC20(address(hermeticWeth)), 5 ether, IERC20(seVault));
        assertGt(previewSe, 0);
        uint256 previewReth = seIn.previewExchangeIn(
            IERC20(address(hermeticWeth)), 5 ether, IERC20(address(hermeticReth))
        );
        assertGt(previewReth, 0);
    }

    /* ---------------------------------------------------------------------- */
    /*                    Soft stake WETH→SE (capacity open)                   */
    /* ---------------------------------------------------------------------- */

    function test_B1_wethToSe_exactIn_softStake_liquidNearTarget() public {
        uint256 amount = 100 ether;
        _dealWeth(address(this), amount);
        hermeticWeth.approve(seVault, amount);

        uint256 preview = seIn.previewExchangeIn(IERC20(address(hermeticWeth)), amount, IERC20(seVault));
        uint256 out = seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            amount,
            IERC20(seVault),
            preview,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, preview);

        uint256 liquid = rocketPoolSe.liquidReserveEth();
        uint256 total = rocketPoolSe.totalReserveEth();
        uint256 target = (total * DEFAULT_LIQUID_PCT) / 1e18;
        uint256 band = (target * 0.10e18) / 1e18;
        assertApproxEqAbs(liquid, target, band + 1);
        assertGt(hermeticReth.balanceOf(seVault), 0);
        assertLt(liquid, amount);
    }

    function test_B2_wethToSe_exactOut_softStake() public {
        _seedVaultInventory(0, 1 ether);
        uint256 ethWanted = 80 ether;
        uint256 sharesOut = seIn.previewExchangeIn(IERC20(address(hermeticWeth)), ethWanted, IERC20(seVault));
        if (sharesOut == 0) sharesOut = ethWanted;

        uint256 previewIn = seOut.previewExchangeOut(IERC20(address(hermeticWeth)), IERC20(seVault), sharesOut);
        require(previewIn > 10 ether, "need large amountIn");
        _dealWeth(address(this), previewIn);
        hermeticWeth.approve(seVault, previewIn);
        uint256 balBefore = IERC20(seVault).balanceOf(address(this));
        uint256 amountIn = seOut.exchangeOut(
            IERC20(address(hermeticWeth)),
            previewIn,
            IERC20(seVault),
            sharesOut,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(amountIn, previewIn);
        assertEq(IERC20(seVault).balanceOf(address(this)) - balBefore, sharesOut);

        uint256 liquid = rocketPoolSe.liquidReserveEth();
        uint256 total = rocketPoolSe.totalReserveEth();
        uint256 target = (total * DEFAULT_LIQUID_PCT) / 1e18;
        uint256 band = (target * 0.10e18) / 1e18 + 1;
        assertApproxEqAbs(liquid, target, band);
        assertGt(hermeticReth.balanceOf(seVault), 1 ether);
    }

    function test_B3_wethToSe_capacity0_mintSucceeds_liquidHigh() public {
        hermeticPool.setMaxDepositAmount(0);
        uint256 amount = 50 ether;
        _dealWeth(address(this), amount);
        hermeticWeth.approve(seVault, amount);

        uint256 rethBefore = hermeticReth.balanceOf(seVault);
        uint256 preview = seIn.previewExchangeIn(IERC20(address(hermeticWeth)), amount, IERC20(seVault));
        uint256 out = seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            amount,
            IERC20(seVault),
            preview,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, preview);
        assertEq(hermeticReth.balanceOf(seVault), rethBefore); // no stake
        assertEq(rocketPoolSe.liquidReserveEth(), amount);
        assertGt(IERC20(seVault).balanceOf(address(this)), 0);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Sleeve pay / shortfall                           */
    /* ---------------------------------------------------------------------- */

    function test_L1_seToWeth_withFundedSleeve() public {
        _seedVaultInventory(0, 20 ether);
        _fundSleeve(10 ether);
        uint256 amountOut = 3 ether;
        uint256 previewIn = seOut.previewExchangeOut(IERC20(seVault), IERC20(address(hermeticWeth)), amountOut);
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
    }

    function test_L2_seToWeth_emptySleeve_revertsWithArgs() public {
        _seedVaultInventory(0, 20 ether);
        assertEq(rocketPoolSe.liquidReserveEth(), 0);
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

    function test_N1_invalidRoute_nativeEth() public {
        _seedVaultInventory(5 ether, 5 ether);
        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, seVault, address(0))
        );
        seOut.previewExchangeOut(IERC20(seVault), IERC20(address(0)), 1 ether);

        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(0), seVault)
        );
        seIn.previewExchangeIn(IERC20(address(0)), 1 ether, IERC20(seVault));
    }

    /* ---------------------------------------------------------------------- */
    /*                    Full closed-form route matrix (R*)                    */
    /* ---------------------------------------------------------------------- */

    function test_R1_wethToSe_inAndOut_previewEqExec() public {
        uint256 amount = 10 ether;
        _dealWeth(address(this), amount);
        hermeticWeth.approve(seVault, amount);
        uint256 preview = seIn.previewExchangeIn(IERC20(address(hermeticWeth)), amount, IERC20(seVault));
        uint256 out = seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            amount,
            IERC20(seVault),
            preview,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, preview);

        uint256 sharesOut = out / 10;
        if (sharesOut == 0) sharesOut = 1;
        uint256 pin = seOut.previewExchangeOut(IERC20(address(hermeticWeth)), IERC20(seVault), sharesOut);
        _dealWeth(address(this), pin);
        hermeticWeth.approve(seVault, pin);
        uint256 ain = seOut.exchangeOut(
            IERC20(address(hermeticWeth)),
            pin,
            IERC20(seVault),
            sharesOut,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(ain, pin);
    }

    function test_R2_rethToSe_previewEqExec() public {
        uint256 amount = 5 ether;
        _mintReth(address(this), amount);
        hermeticReth.approve(seVault, amount);
        uint256 preview = seIn.previewExchangeIn(IERC20(address(hermeticReth)), amount, IERC20(seVault));
        uint256 out = seIn.exchangeIn(
            IERC20(address(hermeticReth)),
            amount,
            IERC20(seVault),
            preview,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, preview);
        assertEq(hermeticReth.balanceOf(seVault), amount);
    }

    function test_R3_seToWeth_inAndOut_previewEqExec() public {
        _seedVaultInventory(0, 20 ether);
        _fundSleeve(15 ether);

        uint256 seBal = IERC20(seVault).balanceOf(address(this));
        uint256 sharesIn = seBal / 4;
        uint256 preview = seIn.previewExchangeIn(IERC20(seVault), sharesIn, IERC20(address(hermeticWeth)));
        uint256 balBefore = hermeticWeth.balanceOf(address(this));
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
        assertEq(hermeticWeth.balanceOf(address(this)) - balBefore, out);

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

    function test_R4_seToReth_previewEqExec() public {
        _seedVaultInventory(0, 20 ether);
        uint256 seBal = IERC20(seVault).balanceOf(address(this));
        uint256 sharesIn = seBal / 4;
        uint256 preview = seIn.previewExchangeIn(IERC20(seVault), sharesIn, IERC20(address(hermeticReth)));
        uint256 balBefore = hermeticReth.balanceOf(address(this));
        uint256 out = seIn.exchangeIn(
            IERC20(seVault),
            sharesIn,
            IERC20(address(hermeticReth)),
            preview,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, preview);
        assertEq(hermeticReth.balanceOf(address(this)) - balBefore, out);
    }

    function test_R5_wethToReth_hard_previewEqExec() public {
        uint256 amount = 5 ether;
        _dealWeth(address(this), amount);
        hermeticWeth.approve(seVault, amount);
        uint256 preview = seIn.previewExchangeIn(
            IERC20(address(hermeticWeth)), amount, IERC20(address(hermeticReth))
        );
        uint256 balBefore = hermeticReth.balanceOf(address(this));
        uint256 out = seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            amount,
            IERC20(address(hermeticReth)),
            preview,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, preview);
        assertEq(hermeticReth.balanceOf(address(this)) - balBefore, out);
    }

    function test_R6_rethToWeth_inventory_previewEqExec() public {
        _fundSleeve(20 ether);
        uint256 amount = 3 ether;
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
        // rETH stayed locked in vault
        assertEq(hermeticReth.balanceOf(seVault), amount);
    }
}
