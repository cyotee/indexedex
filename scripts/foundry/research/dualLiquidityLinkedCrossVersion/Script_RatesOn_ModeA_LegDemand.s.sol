// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {
    ResearchFixture_DualLiquidity
} from "scripts/foundry/research/dualLiquidityLinkedCrossVersion/ResearchFixture_DualLiquidity.sol";

/// @notice DualLiquidity research Mode A rates-on: V4 common→tokenA leg demand.
contract Script_RatesOn_ModeA_LegDemand is Script {
    function run() external {
        ResearchFixture_DualLiquidity fixture = new ResearchFixture_DualLiquidity(true);
        fixture.bootstrapResearch();
        fixture.setResearchModeId(0);
        fixture.initTelemetry("rates_on/modeA_legDemand");

        console2.log("DL Mode A rates_on: V4 common->tokenA demand");
        console2.log("  ratesOn:", fixture.ratesOn());
        console2.log("  steps:", fixture.TRADE_STEPS());

        uint256 steps = fixture.TRADE_STEPS();
        uint256 size = fixture.TRADE_SIZE();
        for (uint256 i = 0; i < steps; ++i) {
            fixture.swapLegMarketA(size);
            fixture.sample("leg_demand_A");
        }

        console2.log("  residualA:", fixture.residualA());
        console2.log("wrote research/out/dualLiquidityLinkedCrossVersion/rates_on/modeA_legDemand/");
    }
}
