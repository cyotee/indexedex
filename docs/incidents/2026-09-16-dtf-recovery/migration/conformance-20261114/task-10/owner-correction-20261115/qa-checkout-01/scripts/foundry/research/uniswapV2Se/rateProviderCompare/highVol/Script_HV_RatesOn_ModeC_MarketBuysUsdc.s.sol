// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {
    ResearchFixture_RateProviderCompare_ModeC
} from "scripts/foundry/research/uniswapV2Se/rateProviderCompare/ResearchFixture_RateProviderCompare_ModeC.sol";

/// @notice High-vol (mul=10) R+ Mode C: market buys USDC + arb. Fee unchanged.
contract Script_HV_RatesOn_ModeC_MarketBuysUsdc is Script {
    uint256 internal constant MUL = 10;

    function run() external {
        ResearchFixture_RateProviderCompare_ModeC fixture =
            new ResearchFixture_RateProviderCompare_ModeC(true, MUL, 0);
        fixture.bootstrapModeC();
        fixture.initTelemetry(
            "rateProviderCompare/highVol/mul10/rates_on/modeC_market_buys_usdc", true
        );
        fixture.configureCloser();

        console2.log("RPC HV Mode C rates_on: market buys USDC + arb");
        console2.log("  ratesOn:", fixture.ratesOn());
        console2.log("  tradeSizeMul:", fixture.tradeSizeMul());

        uint256 steps = fixture.tradeSteps();
        uint256 trade = fixture.tradeWethWei();
        address tokenIn = address(fixture.tokenWeth());
        address tokenOut = address(fixture.tokenUsdc());

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
            fixture.sample("market_buys_USDC_then_arb");
        }

        console2.log("cumulative arb profit:", fixture.cumulativeArbProfit());
        console2.log(
            "wrote research/out/uniswapV2Se/rateProviderCompare/highVol/mul10/rates_on/modeC_market_buys_usdc/"
        );
    }
}
