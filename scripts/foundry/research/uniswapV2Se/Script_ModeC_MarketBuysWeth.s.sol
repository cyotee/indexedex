// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {
    ResearchFixture_ModeC
} from "scripts/foundry/research/uniswapV2Se/ResearchFixture_ModeC.sol";

/**
 * @title Script_ModeC_MarketBuysWeth
 * @notice Mode C: market buys WETH (Uni USDC→WETH), then close Balancer arbs for USDC profit.
 *
 * ```bash
 * forge script scripts/foundry/research/uniswapV2Se/Script_ModeC_MarketBuysWeth.s.sol:Script_ModeC_MarketBuysWeth -vv
 * python research/plots/plot_price_series.py research/out/uniswapV2Se/modeC_market_buys_weth
 * python research/plots/plot_pnl.py research/out/uniswapV2Se/modeC_market_buys_weth
 * ```
 */
contract Script_ModeC_MarketBuysWeth is Script {
    function run() external {
        ResearchFixture_ModeC fixture = new ResearchFixture_ModeC();
        fixture.bootstrapModeC();
        // tradedIsWeth=false ⇒ market buys WETH; arb profit asset = USDC.
        fixture.initTelemetry("modeC_market_buys_weth", false);
        fixture.configureCloser();

        console2.log("Mode C: market buys WETH + Balancer arb (profit in USDC)");
        console2.log("  trade size USDC (wei):", fixture.TRADE_USDC());
        console2.log("  steps:", fixture.TRADE_STEPS());
        console2.log("  closer:", address(fixture.closer()));
        console2.log("  init USDC/WETH (1e18):", fixture.initUniSpotUsdcPerWeth());
        console2.log("  portfolio0 USDC:", fixture.portfolio0Usdc());

        uint256 steps = fixture.TRADE_STEPS();
        uint256 trade = fixture.TRADE_USDC();
        address weth = address(fixture.tokenWeth());
        address usdc = address(fixture.tokenUsdc());

        for (uint256 i = 0; i < steps; ++i) {
            fixture.swapUniExactIn(usdc, weth, trade);
            (uint256 arbProfit, uint256 arbFills) = fixture.closeBalancerArbs();
            console2.log("  step", i + 1);
            console2.log("    fills", arbFills);
            console2.log("    profit", arbProfit);
            console2.log("    maxBuyProbe", fixture.stepMaxBuyProbe());
            console2.log("    maxSellProbe", fixture.stepMaxSellProbe());
            console2.log("    positiveProbes", fixture.stepPositiveProbes());
            fixture.sample("market_buys_WETH_then_arb");
        }

        console2.log("final USDC/WETH (1e18):", fixture.uniSpotUsdcPerWeth());
        console2.log("cumulative arb USDC profit (wei):", fixture.cumulativeArbProfit());
        console2.log("wrote research/out/uniswapV2Se/modeC_market_buys_weth/");
    }
}
