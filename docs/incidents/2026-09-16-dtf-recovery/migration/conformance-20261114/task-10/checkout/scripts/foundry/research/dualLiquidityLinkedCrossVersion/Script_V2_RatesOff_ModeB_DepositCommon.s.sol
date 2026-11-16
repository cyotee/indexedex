// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {
    ResearchFixture_DualLiquidity
} from "scripts/foundry/research/dualLiquidityLinkedCrossVersion/ResearchFixture_DualLiquidity.sol";

/// @notice DualLiquidity v2 Mode B P0: deposit_common under v2/ out root.
contract Script_V2_RatesOff_ModeB_DepositCommon is Script {
    function run() external {
        ResearchFixture_DualLiquidity fixture = new ResearchFixture_DualLiquidity(false);
        fixture.bootstrapResearch();
        fixture.setResearchVersion(2);
        fixture.setResearchModeId(1);
        fixture.initTelemetry("v2/rates_off/modeB_depositCommon");

        console2.log("DL v2 Mode B rates_off: deposit_common");
        uint256 steps = fixture.TRADE_STEPS();
        uint256 size = fixture.TRADE_SIZE();
        for (uint256 i = 0; i < steps; ++i) {
            uint256 out = fixture.depositCommonAlice(size);
            console2.log("  step", i + 1, "exec", out);
            fixture.sample("deposit_common");
        }
        console2.log("wrote research/out/dualLiquidityLinkedCrossVersion/v2/rates_off/modeB_depositCommon/");
    }
}
