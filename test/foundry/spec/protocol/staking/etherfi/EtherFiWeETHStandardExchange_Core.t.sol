// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_EtherFiWeETHStandardExchange} from
    "contracts/test/bases/TestBase_EtherFiWeETHStandardExchange.sol";
import {
    IEtherFiWeETHStandardVault
} from "contracts/protocols/staking/etherfi/interfaces/IEtherFiWeETHStandardVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";

/**
 * @title EtherFiWeETHStandardExchange_Core_Test
 * @notice Deploy, R1–R12 dual-surface routes, preview==exec, split mint, sleeve shortfall.
 */
contract EtherFiWeETHStandardExchange_Core_Test is TestBase_EtherFiWeETHStandardExchange {
    function test_D1_deploy_markerAndTokens() public view {
        assertEq(etherFiSe.weETH(), address(hermeticWeEth));
        assertEq(etherFiSe.eETH(), address(hermeticEEth));
        assertEq(etherFiSe.weth(), address(hermeticWeth));
        assertEq(etherFiSe.liquidityPool(), address(hermeticPool));
        assertEq(etherFiSe.withdrawRequestNFT(), address(hermeticQueue));
        assertEq(etherFiSe.redemptionManager(), address(hermeticRedeem));
        assertEq(
            IVaultFeeOracleQuery(address(indexedexManager)).liquidReservePercentageOfVault(seVault),
            DEFAULT_LIQUID_PCT
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                         Q2 / L3 ungated previews                         */
    /* ---------------------------------------------------------------------- */

    function test_Q2_L3_preview_wethOut_zeroSleeve_stillNonZero() public {
        _seedVaultInventory(0, 20 ether);
        assertEq(etherFiSe.liquidReserveEth(), 0);

        uint256 seBal = IERC20(seVault).balanceOf(address(this));
        assertGt(seBal, 0);
        uint256 preview = seIn.previewExchangeIn(IERC20(seVault), seBal / 4, IERC20(address(hermeticWeth)));
        assertGt(preview, 0);

        uint256 requested = 1 ether;
        uint256 sharesIn = seOut.previewExchangeOut(IERC20(seVault), IERC20(address(hermeticWeth)), requested);
        assertGt(sharesIn, 0);
    }

    /* ---------------------------------------------------------------------- */
    /*                         M1 / M2 WETH→SE split mint                       */
    /* ---------------------------------------------------------------------- */

    function test_M1_wethToSe_exactIn_splitMint_liquidNearTarget() public {
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

        uint256 liquid = etherFiSe.liquidReserveEth();
        uint256 total = etherFiSe.totalReserveEth();
        uint256 target = (total * DEFAULT_LIQUID_PCT) / 1e18;
        // Band: within 10% of target or exact (1:1 hermetic rates)
        uint256 band = (target * 0.10e18) / 1e18;
        assertApproxEqAbs(liquid, target, band + 1);
        assertGt(hermeticWeEth.balanceOf(seVault), 0);
        assertLt(liquid, amount); // overage staked
    }

    function test_M2_wethToSe_exactOut_splitMint() public {
        // Large exact-out so amountIn exceeds target liquid and split stakes overage.
        // Fresh vault: first mint with no prior NAV - use large share out via empty→mint exact-in first then out.
        // Prefer: large WETH exact-out shares against zero NAV is awkward; use empty vault large exact-in style via Out.
        // Seed small locked, then exact-out large share amount requiring multi-eth WETH.
        _seedVaultInventory(0, 1 ether);
        // Request shares equal to roughly 80 ether of deposit face
        uint256 ethWanted = 80 ether;
        uint256 sharesOut = seIn.previewExchangeIn(IERC20(address(hermeticWeth)), ethWanted, IERC20(seVault));
        // If preview on empty-ish vault is weird, fall back to ethWanted as shares proxy
        if (sharesOut == 0) sharesOut = ethWanted;

        uint256 previewIn =
            seOut.previewExchangeOut(IERC20(address(hermeticWeth)), IERC20(seVault), sharesOut);
        require(previewIn > 10 ether, "need large amountIn for split");
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

        uint256 liquid = etherFiSe.liquidReserveEth();
        uint256 total = etherFiSe.totalReserveEth();
        uint256 target = (total * DEFAULT_LIQUID_PCT) / 1e18;
        uint256 band = (target * 0.10e18) / 1e18 + 1;
        assertApproxEqAbs(liquid, target, band);
        // Overage was staked - locked weETH grew beyond the 1 eth seed
        assertGt(hermeticWeEth.balanceOf(seVault), 1 ether);
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
        assertEq(etherFiSe.liquidReserveEth(), 0);
        uint256 requested = 1 ether;

        vm.expectRevert(
            abi.encodeWithSelector(IEtherFiWeETHStandardVault.InsufficientLiquidReserve.selector, requested, 0)
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

    function test_L3_preview_doesNotGateOnLiquidSleeve() public {
        _seedVaultInventory(0, 20 ether);
        _fundSleeve(1 ether);
        uint256 available = etherFiSe.liquidReserveEth();
        uint256 requested = available + 5 ether;

        uint256 sharesIn = seOut.previewExchangeOut(IERC20(seVault), IERC20(address(hermeticWeth)), requested);
        assertGt(sharesIn, 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEtherFiWeETHStandardVault.InsufficientLiquidReserve.selector, requested, available
            )
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
            IERC20(address(hermeticWeth)), amount, IERC20(seVault), preview, address(this), false, block.timestamp + 1 hours
        );
        assertEq(out, preview);

        // exact-out
        uint256 sharesOut = out / 10;
        if (sharesOut == 0) sharesOut = 1;
        uint256 pin = seOut.previewExchangeOut(IERC20(address(hermeticWeth)), IERC20(seVault), sharesOut);
        _dealWeth(address(this), pin);
        hermeticWeth.approve(seVault, pin);
        uint256 ain = seOut.exchangeOut(
            IERC20(address(hermeticWeth)), pin, IERC20(seVault), sharesOut, address(this), false, block.timestamp + 1 hours
        );
        assertEq(ain, pin);
    }

    function test_R2_eethToSe_previewEqExec() public {
        uint256 amount = 5 ether;
        hermeticEEth.mint(address(this), amount);
        hermeticEEth.approve(seVault, amount);
        uint256 preview = seIn.previewExchangeIn(IERC20(address(hermeticEEth)), amount, IERC20(seVault));
        uint256 out = seIn.exchangeIn(
            IERC20(address(hermeticEEth)), amount, IERC20(seVault), preview, address(this), false, block.timestamp + 1 hours
        );
        assertEq(out, preview);
        // At rate 1: wrap credits full face; weETH inventory == amount
        assertEq(hermeticWeEth.balanceOf(seVault), amount);
    }

    /// @dev R2 at live-like rate: eETH→SE exact-in and exact-out must have preview==exec after wrap dust.
    function test_R2_eethToSe_nonOneRate_exactInAndOut_previewEqExec() public {
        hermeticWeEth.setRate(1.05e18);

        // Seed some NAV so exact-out mint is well-defined
        _dealWeth(address(this), 10 ether);
        hermeticWeth.approve(seVault, 10 ether);
        seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            10 ether,
            IERC20(seVault),
            0,
            address(this),
            false,
            block.timestamp + 1 hours
        );

        // Exact-in: minOut = preview must not Slippage despite wrap double-floor
        uint256 amountIn = 5 ether;
        hermeticEEth.mint(address(this), amountIn);
        hermeticEEth.approve(seVault, amountIn);
        uint256 previewOut =
            seIn.previewExchangeIn(IERC20(address(hermeticEEth)), amountIn, IERC20(seVault));
        assertGt(previewOut, 0);
        // Credit eth after wrap is strictly less than face at rate > 1
        uint256 weFromWrap = hermeticWeEth.getWeETHByeETH(amountIn);
        uint256 creditEth = hermeticWeEth.getEETHByWeETH(weFromWrap);
        assertLt(creditEth, amountIn);
        uint256 out = seIn.exchangeIn(
            IERC20(address(hermeticEEth)),
            amountIn,
            IERC20(seVault),
            previewOut,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, previewOut);

        // Exact-out: amountIn = preview must mint >= amountOut after credit
        uint256 sharesOut = out / 5;
        if (sharesOut == 0) sharesOut = 1;
        uint256 previewIn =
            seOut.previewExchangeOut(IERC20(address(hermeticEEth)), IERC20(seVault), sharesOut);
        hermeticEEth.mint(address(this), previewIn);
        hermeticEEth.approve(seVault, previewIn);
        uint256 balBefore = IERC20(seVault).balanceOf(address(this));
        uint256 spent = seOut.exchangeOut(
            IERC20(address(hermeticEEth)),
            previewIn,
            IERC20(seVault),
            sharesOut,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(spent, previewIn);
        assertEq(IERC20(seVault).balanceOf(address(this)) - balBefore, sharesOut);
    }

    function test_R3_weethToSe_previewEqExec() public {
        uint256 amount = 5 ether;
        _mintWeViaE(address(this), amount);
        hermeticWeEth.approve(seVault, amount);
        uint256 preview = seIn.previewExchangeIn(IERC20(address(hermeticWeEth)), amount, IERC20(seVault));
        uint256 out = seIn.exchangeIn(
            IERC20(address(hermeticWeEth)), amount, IERC20(seVault), preview, address(this), false, block.timestamp + 1 hours
        );
        assertEq(out, preview);
    }

    function test_R4_seToWeth_exactIn_previewEqExec() public {
        _seedVaultInventory(0, 10 ether);
        _fundSleeve(20 ether);
        uint256 shares = IERC20(seVault).balanceOf(address(this)) / 4;
        uint256 preview = seIn.previewExchangeIn(IERC20(seVault), shares, IERC20(address(hermeticWeth)));
        uint256 balBefore = hermeticWeth.balanceOf(address(this));
        uint256 out = seIn.exchangeIn(
            IERC20(seVault), shares, IERC20(address(hermeticWeth)), preview, address(this), false, block.timestamp + 1 hours
        );
        assertEq(out, preview);
        assertEq(hermeticWeth.balanceOf(address(this)) - balBefore, out);
    }

    function test_R5_seToEeth_previewEqExec() public {
        _seedVaultInventory(0, 20 ether);
        uint256 shares = IERC20(seVault).balanceOf(address(this)) / 5;
        uint256 preview = seIn.previewExchangeIn(IERC20(seVault), shares, IERC20(address(hermeticEEth)));
        uint256 balBefore = hermeticEEth.balanceOf(address(this));
        uint256 out = seIn.exchangeIn(
            IERC20(seVault), shares, IERC20(address(hermeticEEth)), preview, address(this), false, block.timestamp + 1 hours
        );
        assertEq(out, preview);
        assertEq(hermeticEEth.balanceOf(address(this)) - balBefore, out);
    }

    function test_R6_seToWeeth_previewEqExec() public {
        _seedVaultInventory(0, 20 ether);
        uint256 shares = IERC20(seVault).balanceOf(address(this)) / 5;
        uint256 preview = seIn.previewExchangeIn(IERC20(seVault), shares, IERC20(address(hermeticWeEth)));
        uint256 balBefore = hermeticWeEth.balanceOf(address(this));
        uint256 out = seIn.exchangeIn(
            IERC20(seVault), shares, IERC20(address(hermeticWeEth)), preview, address(this), false, block.timestamp + 1 hours
        );
        assertEq(out, preview);
        assertEq(hermeticWeEth.balanceOf(address(this)) - balBefore, out);

        // exact-out SE → weETH
        uint256 amountOut = 1 ether;
        uint256 previewShares =
            seOut.previewExchangeOut(IERC20(seVault), IERC20(address(hermeticWeEth)), amountOut);
        uint256 sharesIn = seOut.exchangeOut(
            IERC20(seVault),
            previewShares,
            IERC20(address(hermeticWeEth)),
            amountOut,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(sharesIn, previewShares);
    }

    function test_R7_wethToEeth_stakeRoute() public {
        uint256 amount = 2 ether;
        _dealWeth(address(this), amount);
        hermeticWeth.approve(seVault, amount);
        uint256 preview =
            seIn.previewExchangeIn(IERC20(address(hermeticWeth)), amount, IERC20(address(hermeticEEth)));
        uint256 out = seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            amount,
            IERC20(address(hermeticEEth)),
            preview,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, preview);
        assertEq(hermeticEEth.balanceOf(address(this)), out);
    }

    function test_R8_wethToWeeth_stakeRoute() public {
        uint256 amount = 2 ether;
        _dealWeth(address(this), amount);
        hermeticWeth.approve(seVault, amount);
        uint256 preview =
            seIn.previewExchangeIn(IERC20(address(hermeticWeth)), amount, IERC20(address(hermeticWeEth)));
        uint256 out = seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            amount,
            IERC20(address(hermeticWeEth)),
            preview,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, preview);
        assertEq(hermeticWeEth.balanceOf(address(this)), out);
    }

    function test_R9_eethToWeth_inventorySwap() public {
        _seedVaultInventory(0, 5 ether);
        _fundSleeve(10 ether);
        uint256 amount = 1 ether;
        hermeticEEth.mint(address(this), amount);
        hermeticEEth.approve(seVault, amount);
        uint256 preview =
            seIn.previewExchangeIn(IERC20(address(hermeticEEth)), amount, IERC20(address(hermeticWeth)));
        uint256 wethBefore = hermeticWeth.balanceOf(address(this));
        uint256 out = seIn.exchangeIn(
            IERC20(address(hermeticEEth)),
            amount,
            IERC20(address(hermeticWeth)),
            preview,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, preview);
        assertEq(hermeticWeth.balanceOf(address(this)) - wethBefore, out);
        assertGe(hermeticWeEth.balanceOf(seVault), amount);
    }

    function test_R10_weethToWeth_inventorySwap() public {
        _seedVaultInventory(0, 5 ether);
        _fundSleeve(10 ether);
        uint256 amount = 2 ether;
        _mintWeViaE(address(this), amount);
        hermeticWeEth.approve(seVault, amount);
        uint256 preview =
            seIn.previewExchangeIn(IERC20(address(hermeticWeEth)), amount, IERC20(address(hermeticWeth)));
        uint256 wethBefore = hermeticWeth.balanceOf(address(this));
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
        assertEq(hermeticWeth.balanceOf(address(this)) - wethBefore, out);
    }

    function test_R11_eethToWeeth_wrap() public {
        uint256 amount = 2 ether;
        hermeticEEth.mint(address(this), amount);
        hermeticEEth.approve(seVault, amount);
        uint256 preview =
            seIn.previewExchangeIn(IERC20(address(hermeticEEth)), amount, IERC20(address(hermeticWeEth)));
        uint256 out = seIn.exchangeIn(
            IERC20(address(hermeticEEth)),
            amount,
            IERC20(address(hermeticWeEth)),
            preview,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, preview);
        assertEq(hermeticWeEth.balanceOf(address(this)), out);

        // exact-out
        uint256 amountOut = 1 ether;
        uint256 pin =
            seOut.previewExchangeOut(IERC20(address(hermeticEEth)), IERC20(address(hermeticWeEth)), amountOut);
        hermeticEEth.mint(address(this), pin);
        hermeticEEth.approve(seVault, pin);
        uint256 ain = seOut.exchangeOut(
            IERC20(address(hermeticEEth)),
            pin,
            IERC20(address(hermeticWeEth)),
            amountOut,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(ain, pin);
    }

    function test_R12_weethToEeth_unwrap() public {
        uint256 amount = 2 ether;
        _mintWeViaE(address(this), amount);
        hermeticWeEth.approve(seVault, amount);
        uint256 preview =
            seIn.previewExchangeIn(IERC20(address(hermeticWeEth)), amount, IERC20(address(hermeticEEth)));
        uint256 out = seIn.exchangeIn(
            IERC20(address(hermeticWeEth)),
            amount,
            IERC20(address(hermeticEEth)),
            preview,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, preview);
        assertEq(hermeticEEth.balanceOf(address(this)), out);
    }

    /* ---------------------------------------------------------------------- */
    /*              Non-1 rate exact-out (floor round-trip guards)              */
    /* ---------------------------------------------------------------------- */

    /// @dev rate ≠ 1: exact-out e↔we and SE→e must use ceil so floor wrap/unwrap still hits amountOut.
    function test_exactOut_nonOneRate_eWe_and_seToE() public {
        // 1 weETH = 1.05 eETH (live-like)
        hermeticWeEth.setRate(1.05e18);

        // Seed locked inventory via WETH stake+wrap path (respects rate)
        _dealWeth(address(this), 50 ether);
        hermeticWeth.approve(seVault, 50 ether);
        seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            50 ether,
            IERC20(seVault),
            0,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        // Fund sleeve for WETH routes
        _fundSleeve(20 ether);

        // eETH → weETH exact-out
        uint256 weOut = 1 ether;
        uint256 eIn = seOut.previewExchangeOut(
            IERC20(address(hermeticEEth)), IERC20(address(hermeticWeEth)), weOut
        );
        // Floor identity would under-deliver: eIn must be > weOut when rate > 1
        assertGt(eIn, weOut);
        hermeticEEth.mint(address(this), eIn);
        hermeticEEth.approve(seVault, eIn);
        uint256 eSpent = seOut.exchangeOut(
            IERC20(address(hermeticEEth)),
            eIn,
            IERC20(address(hermeticWeEth)),
            weOut,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(eSpent, eIn);
        assertGe(hermeticWeEth.balanceOf(address(this)), weOut);

        // weETH → eETH exact-out
        uint256 eOut = 1 ether;
        uint256 weIn = seOut.previewExchangeOut(
            IERC20(address(hermeticWeEth)), IERC20(address(hermeticEEth)), eOut
        );
        // Need ceil we so floor unwrap >= eOut
        assertGt(weIn, 0);
        // Fund weIn for user
        uint256 needE = hermeticWeEth.getEETHByWeETH(weIn) + 1 ether; // buffer for wrap mint
        hermeticEEth.mint(address(this), needE);
        hermeticEEth.approve(address(hermeticWeEth), needE);
        hermeticWeEth.wrap(needE);
        hermeticWeEth.approve(seVault, weIn);
        uint256 weSpent = seOut.exchangeOut(
            IERC20(address(hermeticWeEth)),
            weIn,
            IERC20(address(hermeticEEth)),
            eOut,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(weSpent, weIn);
        assertGe(hermeticEEth.balanceOf(address(this)), eOut);

        // SE → eETH exact-out
        uint256 seToE = 0.5 ether;
        uint256 seInAmt = seOut.previewExchangeOut(IERC20(seVault), IERC20(address(hermeticEEth)), seToE);
        uint256 eBefore = hermeticEEth.balanceOf(address(this));
        uint256 burned = seOut.exchangeOut(
            IERC20(seVault),
            seInAmt,
            IERC20(address(hermeticEEth)),
            seToE,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(burned, seInAmt);
        assertEq(hermeticEEth.balanceOf(address(this)) - eBefore, seToE);

        // WETH → weETH exact-out
        uint256 weWant = 0.25 ether;
        uint256 wIn = seOut.previewExchangeOut(
            IERC20(address(hermeticWeth)), IERC20(address(hermeticWeEth)), weWant
        );
        _dealWeth(address(this), wIn);
        hermeticWeth.approve(seVault, wIn);
        uint256 wSpent = seOut.exchangeOut(
            IERC20(address(hermeticWeth)),
            wIn,
            IERC20(address(hermeticWeEth)),
            weWant,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(wSpent, wIn);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Rebalance (R1–R5)                                */
    /* ---------------------------------------------------------------------- */

    function test_Reb1_rebalance_stakesExcessLiquid() public {
        // seed mostly liquid via donation so liquid >> 20% target
        _seedVaultInventory(0, 10 ether);
        _fundSleeve(100 ether);
        uint256 liquidBefore = etherFiSe.liquidReserveEth();
        assertGt(liquidBefore, etherFiSe.totalReserveEth() * DEFAULT_LIQUID_PCT / 1e18);

        seRebalance.rebalance();

        assertLt(etherFiSe.liquidReserveEth(), liquidBefore);
        assertGt(hermeticWeEth.balanceOf(seVault), 10 ether);
    }

    function test_Reb2_rebalance_queuesDeficit() public {
        _seedVaultInventory(0, 100 ether);
        // tiny sleeve
        _fundSleeve(0.1 ether);
        uint256 weBefore = hermeticWeEth.balanceOf(seVault);
        uint256 liquidBefore = etherFiSe.liquidReserveEth();
        uint256 target = etherFiSe.totalReserveEth() * DEFAULT_LIQUID_PCT / 1e18;
        assertLt(liquidBefore, target);

        seRebalance.rebalance();

        assertLt(hermeticWeEth.balanceOf(seVault), weBefore);
        assertGt(hermeticQueue.lastRequestId(), 0);
    }

    function test_Reb3_claimFinalized_wrapsToWeth() public {
        _seedVaultInventory(0, 50 ether);
        _fundSleeve(0.1 ether);
        seRebalance.rebalance();
        uint256 reqId = hermeticQueue.lastRequestId();
        if (reqId == 0) return;

        (/*owner*/, uint256 face, /*fin*/, /*cl*/) = hermeticQueue.requests(reqId);
        vm.deal(address(this), face);
        hermeticQueue.finalizeForTest{value: face}(reqId);

        uint256 liquidBefore = etherFiSe.liquidReserveEth();
        seRebalance.rebalance();
        assertGe(etherFiSe.liquidReserveEth(), liquidBefore);
    }

    function test_Reb4_userExchange_doesNotEnqueue() public {
        _seedVaultInventory(5 ether, 5 ether);
        _fundSleeve(5 ether);
        uint256 reqBefore = hermeticQueue.lastRequestId();

        uint256 shares = IERC20(seVault).balanceOf(address(this)) / 10;
        seIn.exchangeIn(
            IERC20(seVault),
            shares,
            IERC20(address(hermeticWeth)),
            0,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(hermeticQueue.lastRequestId(), reqBefore);
    }

    function test_Reb5_attackerCannotClaimVaultRequest() public {
        _seedVaultInventory(0, 50 ether);
        _fundSleeve(0.1 ether);
        seRebalance.rebalance();
        uint256 reqId = hermeticQueue.lastRequestId();
        if (reqId == 0) return;

        (/*owner*/, uint256 face, /*fin*/, /*cl*/) = hermeticQueue.requests(reqId);
        vm.deal(address(this), face);
        hermeticQueue.finalizeForTest{value: face}(reqId);

        address attacker = makeAddr("attacker");
        vm.prank(attacker);
        vm.expectRevert("not owner");
        hermeticQueue.claimWithdraw(reqId);
    }
}
