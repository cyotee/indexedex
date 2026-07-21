// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {
    ResearchFixture_DualLiquidity
} from "scripts/foundry/research/dualLiquidityLinkedCrossVersion/ResearchFixture_DualLiquidity.sol";

/// @notice DualLiquidity Mode B rates-off: repeated commonToken deposits (preview vs exec).
contract Script_RatesOff_ModeB_DepositCommon is Script {
    function run() external {
        ResearchFixture_DualLiquidity fixture = new ResearchFixture_DualLiquidity(false);
        fixture.bootstrapResearch();
        fixture.setResearchModeId(1);
        fixture.initTelemetry("rates_off/modeB_depositCommon");

        console2.log("DL Mode B rates_off: deposit common");
        console2.log("  ratesOn:", fixture.ratesOn());

        uint256 steps = fixture.TRADE_STEPS();
        uint256 size = fixture.TRADE_SIZE();
        for (uint256 i = 0; i < steps; ++i) {
            uint256 out = fixture.depositCommonAlice(size);
            console2.log("  step", i + 1);
            console2.log("    preview", fixture.lastPreviewOut());
            console2.log("    exec", out);
            fixture.sample("deposit_common");
        }

        console2.log("wrote research/out/dualLiquidityLinkedCrossVersion/rates_off/modeB_depositCommon/");
    }
}
