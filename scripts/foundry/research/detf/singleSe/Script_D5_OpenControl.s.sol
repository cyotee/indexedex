// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

import {
    ResearchFixture_DetfSingleSeUniV2
} from "scripts/foundry/research/detf/singleSe/ResearchFixture_DetfSingleSeUniV2.sol";

/**
 * @title Script_D5_OpenControl
 * @notice Phase 3 D5: Open mode live mint/burn; no natural expansion after warp.
 *
 * ```bash
 * FOUNDRY_PROFILE=default forge script \
 *   scripts/foundry/research/detf/singleSe/Script_D5_OpenControl.s.sol:Script_D5_OpenControl -vv
 * ```
 */
contract Script_D5_OpenControl is Script {
    uint256 internal constant BOND_LP = 1_000e18;
    uint256 internal constant MINT_LP = 30e18;

    function run() external {
        ResearchFixture_DetfSingleSeUniV2 fixture = new ResearchFixture_DetfSingleSeUniV2();
        fixture.bootstrapDetfResearch();
        fixture.deployOpenDetf("Research Open DETF D5", "oD5");
        fixture.initTelemetry("D5_openControl");

        address user = fixture.researchUser();
        require(uint8(fixture.detfInfo().thresholdMode()) == uint8(ThresholdMode.Open), "D5: Open mode");

        (uint256 bondId,) = fixture.fundAndBond(user, BOND_LP);
        require(fixture.detfInfo().isReserveLive(), "D5: live");
        require(fixture.detfInfo().isMintingAllowed(), "D5: mint always when live Open");
        require(fixture.detfInfo().isBurningAllowed(), "D5: burn always when live Open");
        fixture.sampleDetf("post_bond_open");

        // Optional Uni trades to stress synth (gates still pass).
        fixture.tradeUni(address(fixture.tokenWeth()), 100e18);
        fixture.tradeUni(address(fixture.tokenUsdc()), 100_000e18);
        fixture.sampleDetf("post_uni_stress");
        require(fixture.detfInfo().isMintingAllowed(), "D5: mint still after trades");
        require(fixture.detfInfo().isBurningAllowed(), "D5: burn still after trades");

        // Snapshot pending before warp (bond may have zero pending without seigniorage).
        uint256 pending0 = fixture.pendingRewardsOf(bondId);
        uint256 supply0 = IERC20(fixture.detf()).totalSupply();
        fixture.detfInfo().compoundProtocolRewards(); // seed clock if any
        fixture.sampleDetf("pre_warp");

        vm.warp(block.timestamp + fixture.RESEARCH_WARP());
        fixture.detfInfo().compoundProtocolRewards();
        uint256 pending1 = fixture.pendingRewardsOf(bondId);
        uint256 supply1 = IERC20(fixture.detf()).totalSupply();
        console2.log("D5: supply before/after warp", supply0, supply1);
        console2.log("D5: pending before/after", pending0, pending1);
        require(supply1 == supply0, "D5: Open never expands supply");
        require(pending1 == pending0, "D5: Open no expansion pending growth");
        fixture.sampleDetf("post_warp_no_expansion");

        // Prove mint + burn routes once.
        uint256 seIn = fixture.fundSeShares(user, MINT_LP);
        uint256 mintIn = seIn / 10;
        if (mintIn == 0) mintIn = seIn;
        uint256 mintOut = fixture.mintSeSharesForDetf(user, mintIn);
        require(mintOut > 0, "D5: mint works");
        fixture.sampleDetf("post_mint");
        uint256 burnAmt = mintOut / 2;
        uint256 burnOut = fixture.burnDetfForSeShares(user, burnAmt);
        require(burnOut > 0, "D5: burn works");
        fixture.sampleDetf("post_burn");

        console2.log("wrote research/out/detf/singleSe/D5_openControl/");
        _writeNotes(supply0, supply1, pending0, pending1);
    }

    function _writeNotes(uint256 supply0, uint256 supply1, uint256 pending0, uint256 pending1) internal {
        string memory path = "research/out/detf/singleSe/D5_openControl/NOTES.md";
        string memory body = string.concat(
            "# D5_openControl\n\n",
            "## One-line story\n",
            "Open-mode Single SE DETF: live mint/burn independent of synthetic; warp shows no natural expansion.\n\n",
            "## Key numbers\n",
            "- supply pre/post warp: ",
            vm.toString(supply0),
            " / ",
            vm.toString(supply1),
            "\n",
            "- pending pre/post warp: ",
            vm.toString(pending0),
            " / ",
            vm.toString(pending1),
            "\n\n",
            "## Non-claims\n",
            "- Open does not advertise a peg; no APY claim.\n\n",
            "## Commands\n",
            "```bash\n",
            "FOUNDRY_PROFILE=default forge script \\\n",
            "  scripts/foundry/research/detf/singleSe/Script_D5_OpenControl.s.sol:Script_D5_OpenControl -vv\n",
            "```\n"
        );
        vm.writeFile(path, body);
    }
}
