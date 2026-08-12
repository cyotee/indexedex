// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {
    ResearchFixture_DetfSingleSeUniV2
} from "scripts/foundry/research/detf/singleSe/ResearchFixture_DetfSingleSeUniV2.sol";

/**
 * @title Script_D2_PolicyDeadband
 * @notice Phase 3 D2: deadband check after first bond; N/A if already mint-allowed.
 *
 * ```bash
 * FOUNDRY_PROFILE=default forge script \
 *   scripts/foundry/research/detf/singleSe/Script_D2_PolicyDeadband.s.sol:Script_D2_PolicyDeadband -vv
 * ```
 */
contract Script_D2_PolicyDeadband is Script {
    uint256 internal constant BOND_LP = 1_000e18;

    function run() external {
        ResearchFixture_DetfSingleSeUniV2 fixture = new ResearchFixture_DetfSingleSeUniV2();
        fixture.bootstrapDetfResearch();
        fixture.deployPolicyDetf("Research Policy DETF D2", "rD2");
        fixture.initTelemetry("D2_policyDeadband");

        address user = fixture.researchUser();
        fixture.fundAndBond(user, BOND_LP);
        require(fixture.detfInfo().isReserveLive(), "D2: live");

        uint256 synth = fixture.detfInfo().syntheticPrice();
        bool mintOk = fixture.detfInfo().isMintingAllowed();
        bool burnOk = fixture.detfInfo().isBurningAllowed();
        fixture.sampleDetf("post_bond_gates");

        console2.log("D2: post-bond gates");
        console2.log("  synth:", synth);
        console2.log("  mintOk:", mintOk);
        console2.log("  burnOk:", burnOk);

        string memory d2Status;
        if (mintOk) {
            d2Status = "na_already_mint_allowed";
            console2.log("  status: N/A (already mint-allowed)");
            // Do not force deadband - D3/D4 carry gate story.
        } else {
            d2Status = "deadband_or_burn_side";
            // Mint should fail when !isMintingAllowed.
            uint256 seBal = fixture.fundSeShares(user, 50e18);
            vm.startPrank(user);
            fixture.seShare().approve(fixture.detf(), seBal);
            try fixture.detfExchangeIn().exchangeIn(
                fixture.seShare(),
                seBal,
                IERC20(fixture.detf()),
                0,
                user,
                false,
                block.timestamp + 1 hours
            ) {
                revert("D2: mint should revert when !isMintingAllowed");
            } catch {
                console2.log("  mint reverted as expected in deadband/not-allowed");
            }
            vm.stopPrank();

            // Warp: no expansion while not mint-rich (or not allowed).
            uint256 supply0 = IERC20(fixture.detf()).totalSupply();
            fixture.sampleDetf("pre_warp");
            vm.warp(block.timestamp + fixture.RESEARCH_WARP());
            fixture.detfInfo().compoundProtocolRewards();
            uint256 supply1 = IERC20(fixture.detf()).totalSupply();
            require(supply1 == supply0, "D2: no expansion when not mint-allowed");
            fixture.sampleDetf("post_warp_no_expansion");
        }

        // Enrich meta with d2Status.
        string memory meta = string.concat(
            '{"campaign":"detf/singleSe","phase":"3","runId":"D2_policyDeadband",',
            '"seAttachment":"uniswapV2","product":"detf/singleSe","d2Status":"',
            d2Status,
            '","syntheticPrice":"',
            vm.toString(synth),
            '"}'
        );
        // Re-write meta via init path: use ResearchTelemetry through fixture by re-init is destructive.
        // Write file directly.
        vm.writeFile("research/out/detf/singleSe/D2_policyDeadband/meta.json", meta);

        console2.log("wrote research/out/detf/singleSe/D2_policyDeadband/");
        _writeNotes(d2Status, mintOk, synth);
    }

    function _writeNotes(string memory d2Status, bool mintOk, uint256 synth) internal {
        string memory path = "research/out/detf/singleSe/D2_policyDeadband/NOTES.md";
        string memory body = string.concat(
            "# D2_policyDeadband\n\n",
            "## One-line story\n",
            mintOk
                ? "Post first-bond synthetic already mint-allowed - D2 marked N/A (do not force deadband).\n\n"
                : "Post first-bond mint not allowed; mint reverts; warp yields no natural expansion.\n\n",
            "## Setup\n",
            "- DETF: Single SE Policy\n",
            "- SE: Uni V2 WETH/USDC hermetic\n\n",
            "## Status\n",
            "- d2Status: ",
            d2Status,
            "\n",
            "- syntheticPrice (wei): ",
            vm.toString(synth),
            "\n\n",
            "## Caveats\n",
            "- N/A is acceptable per campaign PRD; D3/D4 prove gates under real Uni trades\n\n",
            "## Commands\n",
            "```bash\n",
            "FOUNDRY_PROFILE=default forge script \\\n",
            "  scripts/foundry/research/detf/singleSe/Script_D2_PolicyDeadband.s.sol:Script_D2_PolicyDeadband -vv\n",
            "```\n"
        );
        vm.writeFile(path, body);
    }
}
