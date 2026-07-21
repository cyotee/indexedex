// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {
    ResearchFixture_DualLiquidity
} from "scripts/foundry/research/dualLiquidityLinkedCrossVersion/ResearchFixture_DualLiquidity.sol";

/// @notice v2 Phase 0 smoke: rates-off bootstrap + 3 deposit_common steps with volume fields.
contract Script_V2_RatesOff_Smoke is Script {
    function run() external {
        ResearchFixture_DualLiquidity fixture = new ResearchFixture_DualLiquidity(false);
        fixture.bootstrapResearch();
        fixture.setResearchVersion(2);
        fixture.setResearchModeId(1);
        fixture.initTelemetry("v2/rates_off/smoke");

        console2.log("DL v2 smoke rates_off");
        console2.log("  researchVersion:", fixture.researchVersion());
        console2.log("  liveVaultA:", fixture.liveVaultA());
        console2.log("  liveVaultB:", fixture.liveVaultB());
        console2.log("  livePairVault:", fixture.livePairVault());
        console2.log("  balDiamondBpt:", fixture.balDiamondBpt());

        uint256 size = fixture.TRADE_SIZE();
        for (uint256 i = 0; i < 3; ++i) {
            uint256 out = fixture.depositCommonAlice(size);
            console2.log("  smoke deposit step", i + 1, "exec", out);
            console2.log("    dLivePairVault after sample next...");
            fixture.sample("deposit_common");
            console2.log("    livePairVault:", fixture.livePairVault());
            console2.log("    balDiamondBpt:", fixture.balDiamondBpt());
            console2.log("    balAliceShares:", fixture.balAliceShares());
        }

        console2.log("wrote research/out/dualLiquidityLinkedCrossVersion/v2/rates_off/smoke/");
    }
}
