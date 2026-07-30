// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {
    ResearchFixture_DetfSingleSeUniV2
} from "scripts/foundry/research/detf/singleSe/ResearchFixture_DetfSingleSeUniV2.sol";

/**
 * @title Script_D4_PolicyBurnGate
 * @notice Phase 3 D4: burn allowed when synth < burnThreshold; preview~=exec burn.
 * @dev Free DETF via production mint after Uni-only mint-rich (no deal seed).
 *
 * ```bash
 * FOUNDRY_PROFILE=default forge script \
 *   scripts/foundry/research/detf/singleSe/Script_D4_PolicyBurnGate.s.sol:Script_D4_PolicyBurnGate -vv
 * ```
 */
contract Script_D4_PolicyBurnGate is Script {
    uint256 internal constant BOND_LP = 1_000e18;
    uint256 internal constant MINT_LP = 20e18;
    uint256 internal constant MAX_TRADE_STEPS = 80;

    function run() external {
        ResearchFixture_DetfSingleSeUniV2 fixture = new ResearchFixture_DetfSingleSeUniV2();
        fixture.bootstrapDetfResearch();
        fixture.deployPolicyDetf("Research Policy DETF D4", "rD4");
        fixture.initTelemetry("D4_policyBurnGate");

        address user = fixture.researchUser();
        fixture.fundAndBond(user, BOND_LP);
        require(fixture.detfInfo().isReserveLive(), "D4: live");
        fixture.sampleDetf("post_bond");

        // Free DETF: prefer product free DETF from bond mint-split; else capital mint after drive.
        uint256 detfBal = IERC20(fixture.detf()).balanceOf(user);
        console2.log("D4: free DETF after bond:", detfBal);
        if (detfBal == 0) {
            if (!fixture.detfInfo().isMintingAllowed()) {
                uint256 steps = fixture.driveMintAllowed(MAX_TRADE_STEPS);
                console2.log("D4: drive steps to mint-allowed:", steps);
            }
            require(fixture.detfInfo().isMintingAllowed(), "D4: need mint path for free DETF");
            fixture.sampleDetf("mint_allowed");
            uint256 seIn = fixture.fundSeShares(user, MINT_LP);
            uint256 mintIn = seIn / 20;
            if (mintIn == 0) mintIn = seIn;
            fixture.mintSeSharesForDetf(user, mintIn);
            detfBal = IERC20(fixture.detf()).balanceOf(user);
            fixture.sampleDetf("post_mint_for_burn_path");
        }
        require(detfBal > 0, "D4: user holds free DETF");

        // Drive burn-allowed via Uni trades (+ capital dilution if still mint-rich).
        if (!fixture.detfInfo().isBurningAllowed()) {
            uint256 tradeSteps = fixture.driveBurnAllowed(MAX_TRADE_STEPS);
            console2.log("D4: steps to burn-allowed:", tradeSteps);
        }
        require(fixture.detfInfo().isBurningAllowed(), "D4: burn allowed");
        require(fixture.detfInfo().syntheticPrice() < fixture.detfInfo().burnThreshold(), "D4: synth < burnTh");
        fixture.sampleDetf("burn_allowed");

        detfBal = IERC20(fixture.detf()).balanceOf(user);
        uint256 burnAmt = detfBal / 2;
        if (burnAmt > 20e18) burnAmt = 20e18;
        require(burnAmt > 0, "D4: burn amount");
        uint256 preview = fixture.previewBurn(burnAmt);
        uint256 exec = fixture.burnDetfForSeShares(user, burnAmt);
        uint256 diff = preview > exec ? preview - exec : exec - preview;
        console2.log("D4: burn preview/exec", preview, exec);
        require(exec > 0, "D4: burn out");
        // Share-leg exit dust on large SE share units (documented bound).
        uint256 rel = preview == 0 ? diff : (diff * 1e18) / preview;
        require(diff <= 1e15 || rel <= 1e12, "D4: preview-exec out of documented bound");
        fixture.sampleDetf("post_burn");

        if (!fixture.detfInfo().isMintingAllowed()) {
            uint256 supply0 = IERC20(fixture.detf()).totalSupply();
            vm.warp(block.timestamp + 1 days);
            fixture.detfInfo().compoundProtocolRewards();
            require(IERC20(fixture.detf()).totalSupply() == supply0, "D4: no expansion when not mint-rich");
            fixture.sampleDetf("post_warp_no_expansion");
        }

        console2.log("wrote research/out/detf/singleSe/D4_policyBurnGate/");
        _writeNotes(preview, exec, diff);
    }

    function _writeNotes(uint256 preview, uint256 exec, uint256 diff) internal {
        string memory path = "research/out/detf/singleSe/D4_policyBurnGate/NOTES.md";
        string memory body = string.concat(
            "# D4_policyBurnGate\n\n",
            "## One-line story\n",
            "Policy burn gate: free DETF from bond mint-split or capital mint after production drive; burn when synth < burnTh.\n\n",
            "## Setup\n",
            "- DETF: Single SE Policy\n",
            "- Free DETF: product bond mint-split when present; else capital mint after production drive\n",
            "- Drive (if needed): free-DETF primary burns when burn-allowed + Uni trades (no Open/deal)\n",
            "- Synthetic: post-bond often already burn-allowed; reverse/dilution if re-entry after mint\n\n",
            "## Key numbers\n",
            "- previewOut: ",
            vm.toString(preview),
            "\n",
            "- execOut: ",
            vm.toString(exec),
            "\n",
            "- |preview-exec|: ",
            vm.toString(diff),
            "\n",
            "- Bound: abs <= 1e15 OR relative <= 1e-6\n\n",
            "## Commands\n",
            "```bash\n",
            "FOUNDRY_PROFILE=default forge script \\\n",
            "  scripts/foundry/research/detf/singleSe/Script_D4_PolicyBurnGate.s.sol:Script_D4_PolicyBurnGate -vv\n",
            "```\n"
        );
        vm.writeFile(path, body);
    }
}
