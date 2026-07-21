// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {
    ResearchFixture_RateProviderCompare
} from "scripts/foundry/research/uniswapV2Se/rateProviderCompare/ResearchFixture_RateProviderCompare.sol";

/// @notice rateProviderCompare pure-state Mode A: market buys USDC (WETH->USDC)
contract Script_RatesOn_ModeA_MarketBuysUsdc is Script {
    function run() external {
        ResearchFixture_RateProviderCompare fixture =
            new ResearchFixture_RateProviderCompare(true, 1, 0);
        fixture.bootstrapResearch();
        fixture.initTelemetry("rateProviderCompare/rates_on/modeA_market_buys_usdc", true);

        console2.log("RPC Mode A rates_on: market buys USDC (WETH->USDC)");
        console2.log("  ratesOn:", fixture.ratesOn());
        console2.log("  steps:", fixture.tradeSteps());

        uint256 steps = fixture.tradeSteps();
        uint256 trade = fixture.tradeWethWei();
        address tokenIn = address(fixture.tokenWeth());
        address tokenOut = address(fixture.tokenUsdc());

        for (uint256 i = 0; i < steps; ++i) {
            fixture.swapUniExactIn(tokenIn, tokenOut, trade);
            fixture.sample("market_buys_USDC");
        }

        console2.log("final USDC/WETH:", fixture.uniSpotUsdcPerWeth());
        console2.log("wrote research/out/uniswapV2Se/rateProviderCompare/rates_on/modeA_market_buys_usdc/");
    }
}
