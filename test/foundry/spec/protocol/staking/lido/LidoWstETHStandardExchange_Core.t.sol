// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_LidoWstETHStandardExchange} from
    "contracts/test/bases/TestBase_LidoWstETHStandardExchange.sol";
import {ILidoWstETHStandardVault} from
    "contracts/protocols/staking/lido/interfaces/ILidoWstETHStandardVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";

/**
 * @title LidoWstETHStandardExchange_Core_Test
 * @notice Deploy, routes, preview==execution, sleeve shortfall, rebalance, fees.
 */
contract LidoWstETHStandardExchange_Core_Test is TestBase_LidoWstETHStandardExchange {
    function test_D1_deploy_markerAndTokens() public view {
        assertEq(lidoSe.wstETH(), address(hermeticWstEth));
        assertEq(lidoSe.stETH(), address(hermeticStEth));
        assertEq(lidoSe.weth(), address(hermeticWeth));
        assertEq(lidoSe.withdrawalQueue(), address(hermeticQueue));
        assertEq(
            IVaultFeeOracleQuery(address(indexedexManager)).liquidReservePercentageOfVault(seVault),
            DEFAULT_LIQUID_PCT
        );
    }

    function test_P1_wethToSe_previewEqualsExecution() public {
        uint256 amount = 10 ether;
        _dealWeth(address(this), amount);
        hermeticWeth.approve(seVault, amount);

        uint256 preview = seIn.previewExchangeIn(
            IERC20(address(hermeticWeth)), amount, IERC20(seVault)
        );
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
        assertEq(IERC20(seVault).balanceOf(address(this)), out);
        assertEq(lidoSe.liquidReserveEth(), amount);
    }

    function test_P1_wstToSe_previewEqualsExecution() public {
        uint256 amount = 5 ether;
        _mintWstViaSt(address(this), amount);
        hermeticWstEth.approve(seVault, amount);

        uint256 preview = seIn.previewExchangeIn(
            IERC20(address(hermeticWstEth)), amount, IERC20(seVault)
        );
        uint256 out = seIn.exchangeIn(
            IERC20(address(hermeticWstEth)),
            amount,
            IERC20(seVault),
            preview,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, preview);
        assertEq(lidoSe.lockedReserveEth(), amount);
    }

    function test_P1_seToWeth_previewEqualsExecution() public {
        _seedVaultInventory(20 ether, 0);
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

    function test_L2_seToWeth_insufficientSleeve_revertsWithArgs() public {
        _seedVaultInventory(1 ether, 10 ether);
        uint256 available = lidoSe.liquidReserveEth();
        assertEq(available, 1 ether);
        uint256 requested = available + 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                ILidoWstETHStandardVault.InsufficientLiquidReserve.selector, requested, available
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

    function test_L3_preview_doesNotGateOnLiquidSleeve() public {
        // Preview must quote against totalReserveEth even when sleeve cannot pay.
        _seedVaultInventory(1 ether, 10 ether);
        uint256 available = lidoSe.liquidReserveEth();
        uint256 requested = available + 5 ether;
        assertGt(requested, available);

        // Out preview returns shares (no revert); exec still reverts on sleeve shortfall.
        uint256 sharesIn = seOut.previewExchangeOut(
            IERC20(seVault), IERC20(address(hermeticWeth)), requested
        );
        assertGt(sharesIn, 0);

        // Exact-in preview SE → WETH likewise quotes full NAV extractable value.
        uint256 seBal = IERC20(seVault).balanceOf(address(this));
        uint256 wethOut = seIn.previewExchangeIn(
            IERC20(seVault), seBal, IERC20(address(hermeticWeth))
        );
        assertGt(wethOut, available); // can exceed sleeve in the quote

        vm.expectRevert(
            abi.encodeWithSelector(
                ILidoWstETHStandardVault.InsufficientLiquidReserve.selector, requested, available
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

    function test_L4_insufficientSleeve_stateUnchanged() public {
        _seedVaultInventory(2 ether, 5 ether);
        uint256 seBal = IERC20(seVault).balanceOf(address(this));
        uint256 wethVault = hermeticWeth.balanceOf(seVault);
        uint256 supply = IERC20(seVault).totalSupply();

        uint256 requested = wethVault + 1;
        vm.expectRevert();
        seOut.exchangeOut(
            IERC20(seVault),
            type(uint256).max,
            IERC20(address(hermeticWeth)),
            requested,
            address(this),
            false,
            block.timestamp + 1 hours
        );

        assertEq(IERC20(seVault).balanceOf(address(this)), seBal);
        assertEq(hermeticWeth.balanceOf(seVault), wethVault);
        assertEq(IERC20(seVault).totalSupply(), supply);
    }

    function test_R1_rebalance_stakesExcessLiquid() public {
        // fund mostly liquid so actual liquid >> 5% target
        _seedVaultInventory(100 ether, 1 ether);
        uint256 liquidBefore = lidoSe.liquidReserveEth();
        assertGt(liquidBefore, lidoSe.totalReserveEth() * DEFAULT_LIQUID_PCT / 1e18);

        seRebalance.rebalance();

        assertLt(lidoSe.liquidReserveEth(), liquidBefore);
        assertGt(hermeticWstEth.balanceOf(seVault), 1 ether);
    }

    function test_R2_rebalance_queuesDeficit() public {
        // mostly locked, little liquid
        _seedVaultInventory(0.1 ether, 100 ether);
        uint256 liquidBefore = lidoSe.liquidReserveEth();
        uint256 target = lidoSe.totalReserveEth() * DEFAULT_LIQUID_PCT / 1e18;
        assertLt(liquidBefore, target);

        seRebalance.rebalance();

        // pending face should be non-zero (locked inventory reduced)
        assertLt(hermeticWstEth.balanceOf(seVault), 100 ether);
    }

    function test_R3_claimFinalized_wrapsToWeth() public {
        _seedVaultInventory(0.1 ether, 50 ether);
        seRebalance.rebalance();
        // finalize first request if any
        uint256 reqId = hermeticQueue.lastRequestId();
        if (reqId == 0) {
            // force a queue by setting liquid very low target and rebalancing
            return;
        }
        (/*owner*/, uint256 face, /*fin*/, /*cl*/) = hermeticQueue.requests(reqId);
        vm.deal(address(this), face);
        hermeticQueue.finalizeForTest{value: face}(reqId);

        uint256 liquidBefore = lidoSe.liquidReserveEth();
        seRebalance.rebalance();
        assertGe(lidoSe.liquidReserveEth(), liquidBefore);
    }

    function test_R1_invalidRoute_nativeEthOut() public {
        _seedVaultInventory(5 ether, 5 ether);
        // address(0) as tokenOut is invalid
        vm.expectRevert(
            abi.encodeWithSelector(
                IStandardExchangeErrors.InvalidRoute.selector, seVault, address(0)
            )
        );
        seOut.previewExchangeOut(IERC20(seVault), IERC20(address(0)), 1 ether);
    }

    function test_stEthWrapUnwrap_route() public {
        uint256 amount = 2 ether;
        hermeticStEth.mint(address(this), amount);
        hermeticStEth.approve(seVault, amount);
        uint256 preview = seIn.previewExchangeIn(
            IERC20(address(hermeticStEth)), amount, IERC20(address(hermeticWstEth))
        );
        uint256 out = seIn.exchangeIn(
            IERC20(address(hermeticStEth)),
            amount,
            IERC20(address(hermeticWstEth)),
            preview,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, preview);
        assertEq(hermeticWstEth.balanceOf(address(this)), out);
    }

    /* ---------------------------------------------------------------------- */
    /*                    Full closed-form route matrix                         */
    /* ---------------------------------------------------------------------- */

    function test_P1_seToWeth_exactIn_previewEqualsExecution() public {
        _seedVaultInventory(20 ether, 0);
        uint256 shares = 3 ether; // approx; burn exact share amount
        // Use a known share amount from balance
        shares = IERC20(seVault).balanceOf(address(this)) / 4;
        uint256 preview = seIn.previewExchangeIn(
            IERC20(seVault), shares, IERC20(address(hermeticWeth))
        );
        uint256 balBefore = hermeticWeth.balanceOf(address(this));
        uint256 out = seIn.exchangeIn(
            IERC20(seVault),
            shares,
            IERC20(address(hermeticWeth)),
            preview,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, preview);
        assertEq(hermeticWeth.balanceOf(address(this)) - balBefore, out);
    }

    function test_P1_wethToSe_exactOut_previewEqualsExecution() public {
        _seedVaultInventory(5 ether, 5 ether);
        uint256 sharesOut = 1 ether;
        // Ensure we can mint: quote WETH needed
        uint256 previewIn = seOut.previewExchangeOut(
            IERC20(address(hermeticWeth)), IERC20(seVault), sharesOut
        );
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
    }

    function test_P1_seToWst_exactInAndOut() public {
        _seedVaultInventory(2 ether, 20 ether);
        uint256 shares = IERC20(seVault).balanceOf(address(this)) / 10;

        uint256 previewWst = seIn.previewExchangeIn(
            IERC20(seVault), shares, IERC20(address(hermeticWstEth))
        );
        uint256 wstBefore = hermeticWstEth.balanceOf(address(this));
        uint256 out = seIn.exchangeIn(
            IERC20(seVault),
            shares,
            IERC20(address(hermeticWstEth)),
            previewWst,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, previewWst);
        assertEq(hermeticWstEth.balanceOf(address(this)) - wstBefore, out);

        // exact-out SE → wstETH
        uint256 amountOut = 1 ether;
        uint256 previewShares = seOut.previewExchangeOut(
            IERC20(seVault), IERC20(address(hermeticWstEth)), amountOut
        );
        uint256 sharesBefore = IERC20(seVault).balanceOf(address(this));
        uint256 sharesIn = seOut.exchangeOut(
            IERC20(seVault),
            previewShares,
            IERC20(address(hermeticWstEth)),
            amountOut,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(sharesIn, previewShares);
        assertEq(sharesBefore - IERC20(seVault).balanceOf(address(this)), sharesIn);
    }

    function test_P1_wethToWst_stakeRoute() public {
        uint256 amount = 2 ether;
        _dealWeth(address(this), amount);
        hermeticWeth.approve(seVault, amount);
        uint256 preview = seIn.previewExchangeIn(
            IERC20(address(hermeticWeth)), amount, IERC20(address(hermeticWstEth))
        );
        uint256 out = seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            amount,
            IERC20(address(hermeticWstEth)),
            preview,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, preview);
        assertEq(hermeticWstEth.balanceOf(address(this)), out);
    }

    function test_P1_wstToWeth_inventorySwap() public {
        // seed liquid sleeve + keep path for user wst
        _seedVaultInventory(10 ether, 0);
        uint256 amount = 2 ether;
        _mintWstViaSt(address(this), amount);
        hermeticWstEth.approve(seVault, amount);
        uint256 preview = seIn.previewExchangeIn(
            IERC20(address(hermeticWstEth)), amount, IERC20(address(hermeticWeth))
        );
        uint256 wethBefore = hermeticWeth.balanceOf(address(this));
        uint256 out = seIn.exchangeIn(
            IERC20(address(hermeticWstEth)),
            amount,
            IERC20(address(hermeticWeth)),
            preview,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, preview);
        assertEq(hermeticWeth.balanceOf(address(this)) - wethBefore, out);
        // vault locked increased by deposited wst
        assertGe(hermeticWstEth.balanceOf(seVault), amount);
    }

    function test_P1_stEthToWeth_and_wethToStEth() public {
        _seedVaultInventory(10 ether, 0);

        // stETH → WETH
        uint256 amount = 1 ether;
        hermeticStEth.mint(address(this), amount);
        hermeticStEth.approve(seVault, amount);
        uint256 previewWeth = seIn.previewExchangeIn(
            IERC20(address(hermeticStEth)), amount, IERC20(address(hermeticWeth))
        );
        uint256 outWeth = seIn.exchangeIn(
            IERC20(address(hermeticStEth)),
            amount,
            IERC20(address(hermeticWeth)),
            previewWeth,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(outWeth, previewWeth);

        // WETH → stETH (stake)
        hermeticWeth.approve(seVault, outWeth);
        uint256 previewSt = seIn.previewExchangeIn(
            IERC20(address(hermeticWeth)), outWeth, IERC20(address(hermeticStEth))
        );
        uint256 stBefore = hermeticStEth.balanceOf(address(this));
        uint256 outSt = seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            outWeth,
            IERC20(address(hermeticStEth)),
            previewSt,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(outSt, previewSt);
        assertEq(hermeticStEth.balanceOf(address(this)) - stBefore, outSt);
    }

    function test_P1_exactOut_assetAsset_stEthToWst() public {
        uint256 amountOut = 1 ether;
        uint256 previewIn = seOut.previewExchangeOut(
            IERC20(address(hermeticStEth)), IERC20(address(hermeticWstEth)), amountOut
        );
        hermeticStEth.mint(address(this), previewIn);
        hermeticStEth.approve(seVault, previewIn);
        uint256 wstBefore = hermeticWstEth.balanceOf(address(this));
        uint256 amountIn = seOut.exchangeOut(
            IERC20(address(hermeticStEth)),
            previewIn,
            IERC20(address(hermeticWstEth)),
            amountOut,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(amountIn, previewIn);
        assertEq(hermeticWstEth.balanceOf(address(this)) - wstBefore, amountOut);
    }
}
