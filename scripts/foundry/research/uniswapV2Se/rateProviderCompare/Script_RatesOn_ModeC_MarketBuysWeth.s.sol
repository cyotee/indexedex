// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {
    ResearchFixture_RateProviderCompare_ModeC
} from "scripts/foundry/research/uniswapV2Se/rateProviderCompare/ResearchFixture_RateProviderCompare_ModeC.sol";

/// @notice rateProviderCompare pure-state Mode C: market buys WETH + arb
contract Script_RatesOn_ModeC_MarketBuysWeth is Script {
    function run() external {
        ResearchFixture_RateProviderCompare_ModeC fixture =
            new ResearchFixture_RateProviderCompare_ModeC(true, 1, 0);
        fixture.bootstrapModeC();
        fixture.initTelemetry("rateProviderCompare/rates_on/modeC_market_buys_weth", false);
        fixture.configureCloser();

        console2.log("RPC Mode C rates_on: market buys WETH + arb");
        console2.log("  ratesOn:", fixture.ratesOn());

        uint256 steps = fixture.tradeSteps();
        uint256 trade = fixture.tradeUsdcWei();
        address tokenIn = address(fixture.tokenUsdc());
        address tokenOut = address(fixture.tokenWeth());

        for (uint256 i = 0; i < steps; ++i) {
            fixture.swapUniExactIn(tokenIn, tokenOut, trade);
            (uint256 profit, uint256 fills) = fixture.closeBalancerArbs();
            console2.log("  step");
            console2.log(i + 1);
            console2.log("    fills");
            console2.log(fills);
            console2.log("    profit");
            console2.log(profit);
            console2.log("    maxBuy");
            console2.log(fixture.stepMaxBuyProbe());
            console2.log("    maxSell");
            console2.log(fixture.stepMaxSellProbe());
            fixture.sample("market_buys_WETH_then_arb");
        }

        console2.log("cumulative arb profit:", fixture.cumulativeArbProfit());
        console2.log("wrote research/out/uniswapV2Se/rateProviderCompare/rates_on/modeC_market_buys_weth/");
    }
}
