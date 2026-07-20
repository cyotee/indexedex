// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {
    ResearchFixture_UniswapV2SeRateMatrix
} from "scripts/foundry/research/uniswapV2Se/ResearchFixture_UniswapV2SeRateMatrix.sol";

/**
 * @title Script_ModeA_TradeWeth
 * @notice Mode A: external flow WETH→USDC on Uni. LP framing = market buys our USDC.
 *         Charts use Uni USDC/WETH and Balancer mid_t/mid_0 (raw pair/liveShares).
 *
 * ```bash
 * forge script scripts/foundry/research/uniswapV2Se/Script_ModeA_TradeWeth.s.sol:Script_ModeA_TradeWeth -vv
 * python research/plots/plot_price_series.py research/out/uniswapV2Se/modeA_trade_weth
 * python research/plots/plot_pnl.py research/out/uniswapV2Se/modeA_trade_weth
 * ```
 */
contract Script_ModeA_TradeWeth is Script {
    function run() external {
        ResearchFixture_UniswapV2SeRateMatrix fixture = new ResearchFixture_UniswapV2SeRateMatrix();
        fixture.bootstrapResearch();
        // tradedIsWeth=true ⇒ trader sells WETH into pool ⇒ market buys USDC from us.
        fixture.initTelemetry("modeA_trade_weth", true);

        console2.log("Mode A: market buys USDC from our Uni liquidity (flow: WETH -> USDC)");
        console2.log("  trade size WETH (wei):", fixture.TRADE_WETH());
        console2.log("  steps:", fixture.TRADE_STEPS());
        console2.log("  init USDC/WETH (1e18):", fixture.initUniSpotUsdcPerWeth());
        console2.log("  vault LP deposited:", fixture.vaultLpDeposited());
        console2.log("  free LP outside vault:", fixture.freeLpOutsideVault());
        console2.log("  portfolio0 USDC:", fixture.portfolio0Usdc());

        uint256 steps = fixture.TRADE_STEPS();
        uint256 trade = fixture.TRADE_WETH();
        address weth = address(fixture.tokenWeth());
        address usdc = address(fixture.tokenUsdc());

        for (uint256 i = 0; i < steps; ++i) {
            fixture.swapUniExactIn(weth, usdc, trade);
            fixture.sample("market_buys_USDC");
        }

        console2.log("final USDC/WETH (1e18):", fixture.uniSpotUsdcPerWeth());
        console2.log("final uniPriceIndex (1e18):", fixture.uniPriceIndex());
        console2.log("wrote research/out/uniswapV2Se/modeA_trade_weth/");
        console2.log("plot: python research/plots/plot_price_series.py research/out/uniswapV2Se/modeA_trade_weth");
        console2.log("plot: python research/plots/plot_pnl.py research/out/uniswapV2Se/modeA_trade_weth");
    }
}
