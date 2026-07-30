// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {
    ResearchFixture_DetfSingleSeUniV2
} from "scripts/foundry/research/detf/singleSe/ResearchFixture_DetfSingleSeUniV2.sol";

/**
 * @title Script_D0_Inert
 * @notice Phase 3 D0: deploy Policy DETF inert; mint blocked; warp -> no expansion path for inert.
 *
 * ```bash
 * FOUNDRY_PROFILE=default forge script \
 *   scripts/foundry/research/detf/singleSe/Script_D0_Inert.s.sol:Script_D0_Inert -vv
 * ```
 */
contract Script_D0_Inert is Script {
    function run() external {
        ResearchFixture_DetfSingleSeUniV2 fixture = new ResearchFixture_DetfSingleSeUniV2();
        fixture.bootstrapDetfResearch();
        fixture.deployPolicyDetf("Research Policy DETF", "rDETF");
        fixture.initTelemetry("D0_inert");

        console2.log("D0: Policy DETF inert deploy");
        console2.log("  detf:", fixture.detf());
        console2.log("  seVault:", address(fixture.seVault()));
        console2.log("  live:", fixture.detfInfo().isReserveLive());
        console2.log("  synth:", fixture.detfInfo().syntheticPrice());
        console2.log("  mintTh:", fixture.detfInfo().mintThreshold());
        console2.log("  burnTh:", fixture.detfInfo().burnThreshold());

        require(!fixture.detfInfo().isReserveLive(), "D0: expected inert");
        require(!fixture.detfInfo().isMintingAllowed(), "D0: mint should be disallowed inert");
        require(fixture.detfInfo().mintThreshold() == 1.05e18, "D0: default mint threshold");
        require(fixture.detfInfo().burnThreshold() == 0.95e18, "D0: default burn threshold");

        fixture.sampleDetf("inert_t0");

        // Mint must revert while inert (use small share amount if any free shares exist).
        address user = fixture.researchUser();
        uint256 seBal = fixture.seShare().balanceOf(user);
        if (seBal == 0) {
            // Fund a dust amount of SE shares from free Uni LP for the mint-revert check.
            uint256 freeLp = IERC20(address(fixture.uniV2Pair())).balanceOf(fixture.liquidityProvider());
            uint256 useLp = freeLp / 1000;
            if (useLp > 0) {
                seBal = fixture.fundSeShares(user, useLp);
            }
        }
        if (seBal > 0) {
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
                revert("D0: mint should have reverted while inert");
            } catch (bytes memory reason) {
                bytes4 sel;
                if (reason.length >= 4) {
                    sel = bytes4(reason[0]) | (bytes4(reason[1]) >> 8) | (bytes4(reason[2]) >> 16)
                        | (bytes4(reason[3]) >> 24);
                }
                // Accept any revert (ReservePoolNotInitialized preferred).
                console2.log("  mint reverted as expected (selector):");
                console2.logBytes4(sel);
            }
            vm.stopPrank();
        } else {
            console2.log("  skip mint-revert probe (no SE shares funded)");
        }

        fixture.sampleDetf("inert_pre_warp");
        vm.warp(block.timestamp + fixture.RESEARCH_WARP());
        // Inert: no bond, no expansion surface for users.
        require(!fixture.detfInfo().isReserveLive(), "D0: still inert after warp");
        require(!fixture.detfInfo().isMintingAllowed(), "D0: mint still disallowed after warp");
        fixture.sampleDetf("inert_post_warp");

        console2.log("wrote research/out/detf/singleSe/D0_inert/");
        _writeNotes();
    }

    function _writeNotes() internal {
        string memory path = "research/out/detf/singleSe/D0_inert/NOTES.md";
        string memory body = string.concat(
            "# D0_inert\n\n",
            "## One-line story\n",
            "Policy Single SE DETF deploys inert against Uni V2 SE; mint blocked; warp does not enable mint/expansion.\n\n",
            "## Setup\n",
            "- DETF: Single SE Policy (default thresholds)\n",
            "- SE: Uni V2 WETH/USDC hermetic\n",
            "- Drive: deploy only + warp\n\n",
            "## Assertions\n",
            "- isReserveLive == false\n",
            "- isMintingAllowed == false\n",
            "- mintThreshold/burnThreshold defaults 1.05e18 / 0.95e18\n",
            "- mint reverts while inert (when SE shares available)\n\n",
            "## Caveats\n",
            "- Hermetic research; not mainnet APY\n",
            "- Expansion positive path is D8; D0 only checks inert negatives\n\n",
            "## Commands\n",
            "```bash\n",
            "FOUNDRY_PROFILE=default forge script \\\n",
            "  scripts/foundry/research/detf/singleSe/Script_D0_Inert.s.sol:Script_D0_Inert -vv\n",
            "```\n"
        );
        vm.writeFile(path, body);
    }
}
