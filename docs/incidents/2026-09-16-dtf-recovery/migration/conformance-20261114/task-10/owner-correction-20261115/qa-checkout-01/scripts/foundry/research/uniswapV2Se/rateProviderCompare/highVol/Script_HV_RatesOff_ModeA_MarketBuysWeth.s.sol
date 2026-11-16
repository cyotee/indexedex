// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {
    ResearchFixture_RateProviderCompare
} from "scripts/foundry/research/uniswapV2Se/rateProviderCompare/ResearchFixture_RateProviderCompare.sol";

/// @notice High-vol (mul=10) R− Mode A: market buys WETH. Fee unchanged.
contract Script_HV_RatesOff_ModeA_MarketBuysWeth is Script {
    uint256 internal constant MUL = 10;

    function run() external {
        ResearchFixture_RateProviderCompare fixture =
            new ResearchFixture_RateProviderCompare(false, MUL, 0);
        fixture.bootstrapResearch();
        fixture.initTelemetry(
            "rateProviderCompare/highVol/mul10/rates_off/modeA_market_buys_weth", false
        );

        console2.log("RPC HV Mode A rates_off: market buys WETH");
        console2.log("  ratesOn:", fixture.ratesOn());
        console2.log("  tradeSizeMul:", fixture.tradeSizeMul());

        uint256 steps = fixture.tradeSteps();
        uint256 trade = fixture.tradeUsdcWei();
        address tokenIn = address(fixture.tokenUsdc());
        address tokenOut = address(fixture.tokenWeth());

        for (uint256 i = 0; i < steps; ++i) {
            fixture.swapUniExactIn(tokenIn, tokenOut, trade);
            fixture.sample("market_buys_WETH");
        }

        console2.log("final USDC/WETH:", fixture.uniSpotUsdcPerWeth());
        console2.log(
            "wrote research/out/uniswapV2Se/rateProviderCompare/highVol/mul10/rates_off/modeA_market_buys_weth/"
        );
    }
}
