// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {
    ResearchFixture_DualLiquidity
} from "scripts/foundry/research/dualLiquidityLinkedCrossVersion/ResearchFixture_DualLiquidity.sol";

/// @notice DualLiquidity v2 Mode B P1: swap_tokenA_tokenB volume driver under v2/ out root.
contract Script_V2_RatesOff_ModeB_SwapTokenATokenB is Script {
    function run() external {
        ResearchFixture_DualLiquidity fixture = new ResearchFixture_DualLiquidity(false);
        fixture.bootstrapResearch();
        fixture.setResearchVersion(2);
        fixture.setResearchModeId(1);
        fixture.initTelemetry("v2/rates_off/modeB_swapTokenATokenB");

        console2.log("DL v2 Mode B rates_off: swap_tokenA_tokenB");
        uint256 steps = fixture.TRADE_STEPS();
        uint256 size = fixture.TRADE_SIZE();
        for (uint256 i = 0; i < steps; ++i) {
            uint256 out = fixture.swapTokenATokenBAlice(size);
            console2.log("  step", i + 1, "exec", out);
            fixture.sample("swap_tokenA_tokenB");
        }
        console2.log("wrote research/out/dualLiquidityLinkedCrossVersion/v2/rates_off/modeB_swapTokenATokenB/");
    }
}
