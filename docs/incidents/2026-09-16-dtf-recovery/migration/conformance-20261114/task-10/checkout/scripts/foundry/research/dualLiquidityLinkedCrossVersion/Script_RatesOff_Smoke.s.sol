// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {
    ResearchFixture_DualLiquidity
} from "scripts/foundry/research/dualLiquidityLinkedCrossVersion/ResearchFixture_DualLiquidity.sol";

/// @notice Phase 0 smoke: bootstrap rates-off DualLiquidity + sample init only.
contract Script_RatesOff_Smoke is Script {
    function run() external {
        ResearchFixture_DualLiquidity fixture = new ResearchFixture_DualLiquidity(false);
        fixture.bootstrapResearch();
        fixture.initTelemetry("rates_off/smoke");
        console2.log("DL smoke rates_off");
        console2.log("  ratesOn:", fixture.ratesOn());
        console2.log("  midA:", fixture.midA());
        console2.log("  rateA:", fixture.rateA());
        console2.log("  residualA:", fixture.residualA());
        console2.log("  reservePool:", fixture.reservePool());
        console2.log("wrote research/out/dualLiquidityLinkedCrossVersion/rates_off/smoke/");
    }
}
