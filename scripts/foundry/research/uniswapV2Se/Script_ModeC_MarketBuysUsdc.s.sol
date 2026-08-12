// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {
    ResearchFixture_ModeC
} from "scripts/foundry/research/uniswapV2Se/ResearchFixture_ModeC.sol";

/**
 * @title Script_ModeC_MarketBuysUsdc
 * @notice Mode C: market buys USDC (Uni WETH→USDC), then close Balancer arbs for WETH profit.
 *
 * Path per step: Uni demand → closer buys vault shares on Balancer if edge → redeem SE →
 * Uni LP → convert to WETH (profit = vs Uni-only pair conversion).
 *
 * ```bash
 * forge script scripts/foundry/research/uniswapV2Se/Script_ModeC_MarketBuysUsdc.s.sol:Script_ModeC_MarketBuysUsdc -vv
 * python research/plots/plot_price_series.py research/out/uniswapV2Se/modeC_market_buys_usdc
 * python research/plots/plot_pnl.py research/out/uniswapV2Se/modeC_market_buys_usdc
 * ```
 */
contract Script_ModeC_MarketBuysUsdc is Script {
    function run() external {
        ResearchFixture_ModeC fixture = new ResearchFixture_ModeC();
        fixture.bootstrapModeC();
        // tradedIsWeth=true ⇒ market buys USDC; arb profit asset = WETH.
        fixture.initTelemetry("modeC_market_buys_usdc", true);
        fixture.configureCloser();

        console2.log("Mode C: market buys USDC + Balancer arb (profit in WETH)");
        console2.log("  trade size WETH (wei):", fixture.TRADE_WETH());
        console2.log("  steps:", fixture.TRADE_STEPS());
        console2.log("  closer:", address(fixture.closer()));
        console2.log("  init USDC/WETH (1e18):", fixture.initUniSpotUsdcPerWeth());
        console2.log("  portfolio0 USDC:", fixture.portfolio0Usdc());

        uint256 steps = fixture.TRADE_STEPS();
        uint256 trade = fixture.TRADE_WETH();
        address weth = address(fixture.tokenWeth());
        address usdc = address(fixture.tokenUsdc());

        for (uint256 i = 0; i < steps; ++i) {
            fixture.swapUniExactIn(weth, usdc, trade);
            (uint256 arbProfit, uint256 arbFills) = fixture.closeBalancerArbs();
            console2.log("  step", i + 1);
            console2.log("    fills", arbFills);
            console2.log("    profit", arbProfit);
            console2.log("    maxBuyProbe", fixture.stepMaxBuyProbe());
            console2.log("    maxSellProbe", fixture.stepMaxSellProbe());
            console2.log("    positiveProbes", fixture.stepPositiveProbes());
            fixture.sample("market_buys_USDC_then_arb");
        }

        console2.log("final USDC/WETH (1e18):", fixture.uniSpotUsdcPerWeth());
        console2.log("cumulative arb WETH profit (wei):", fixture.cumulativeArbProfit());
        console2.log("wrote research/out/uniswapV2Se/modeC_market_buys_usdc/");
    }
}
