// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {
    ResearchFixture_DualLiquidity
} from "scripts/foundry/research/dualLiquidityLinkedCrossVersion/ResearchFixture_DualLiquidity.sol";

/// @notice DualLiquidity v2 Mode A rates-off: V4 common→tokenA leg demand → share-book series.
contract Script_V2_RatesOff_ModeA_LegDemand is Script {
    function run() external {
        ResearchFixture_DualLiquidity fixture = new ResearchFixture_DualLiquidity(false);
        fixture.bootstrapResearch();
        fixture.setResearchVersion(2);
        fixture.setResearchModeId(0);
        fixture.initTelemetry("v2/rates_off/modeA_legDemand");

        console2.log("DL v2 Mode A rates_off: V4 common->tokenA demand");
        uint256 steps = fixture.TRADE_STEPS();
        uint256 size = fixture.TRADE_SIZE();
        for (uint256 i = 0; i < steps; ++i) {
            fixture.swapLegMarketA(size);
            fixture.sample("leg_demand_A");
        }
        console2.log("  residualA:", fixture.residualA());
        console2.log("  markFullExit:", fixture.markFullExit(fixture.researchAlice()));
        console2.log("wrote research/out/dualLiquidityLinkedCrossVersion/v2/rates_off/modeA_legDemand/");
    }
}
