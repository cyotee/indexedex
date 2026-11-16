// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {
    ResearchFixture_DetfSingleSeUniV2
} from "scripts/foundry/research/detf/singleSe/ResearchFixture_DetfSingleSeUniV2.sol";

/**
 * @title Script_D1_FirstBond
 * @notice Phase 3 D1: first bond -> live; sample supply/synth/bond id.
 *
 * ```bash
 * FOUNDRY_PROFILE=default forge script \
 *   scripts/foundry/research/detf/singleSe/Script_D1_FirstBond.s.sol:Script_D1_FirstBond -vv
 * ```
 */
contract Script_D1_FirstBond is Script {
    uint256 internal constant BOND_LP = 1_000e18;

    function run() external {
        ResearchFixture_DetfSingleSeUniV2 fixture = new ResearchFixture_DetfSingleSeUniV2();
        fixture.bootstrapDetfResearch();
        fixture.deployPolicyDetf("Research Policy DETF", "rDETF");
        fixture.initTelemetry("D1_firstBond");

        address user = fixture.researchUser();
        fixture.sampleDetf("pre_bond_inert");
        require(!fixture.detfInfo().isReserveLive(), "D1: expected inert pre-bond");

        (uint256 tokenId_, uint256 seShares_) = fixture.fundAndBond(user, BOND_LP);
        console2.log("D1: first bond");
        console2.log("  tokenId:", tokenId_);
        console2.log("  seShares used (approx):", seShares_);
        console2.log("  live:", fixture.detfInfo().isReserveLive());
        console2.log("  synth:", fixture.detfInfo().syntheticPrice());
        console2.log("  supply:", IERC20(fixture.detf()).totalSupply());
        console2.log("  reservePool:", fixture.detfInfo().reservePool());

        require(fixture.detfInfo().isReserveLive(), "D1: expected live after first bond");
        require(fixture.detfInfo().reservePool() != address(0), "D1: reserve pool missing");
        require(tokenId_ != 0, "D1: bond id");

        fixture.sampleDetf("post_first_bond");

        // Residual free inventory: SE shares and free DETF on diamond should be zero.
        require(fixture.seShare().balanceOf(fixture.detf()) == 0, "D1: residual se shares on diamond");
        // Free DETF on diamond may be 0 after success paths; BPT may remain.

        console2.log("wrote research/out/detf/singleSe/D1_firstBond/");
        _writeNotes(tokenId_);
    }

    function _writeNotes(uint256 tokenId_) internal {
        string memory path = "research/out/detf/singleSe/D1_firstBond/NOTES.md";
        string memory body = string.concat(
            "# D1_firstBond\n\n",
            "## One-line story\n",
            "First bond of Uni V2 SE shares boots Policy Single SE DETF from inert to live with reserve pool + bond NFT.\n\n",
            "## Setup\n",
            "- DETF: Single SE Policy (default thresholds)\n",
            "- SE: Uni V2 WETH/USDC hermetic\n",
            "- Bond LP amount: 1000e18 Uni LP -> SE shares -> bond\n\n",
            "## Assertions\n",
            "- isReserveLive after bond\n",
            "- reservePool != 0\n",
            "- bond tokenId != 0\n",
            "- residual free SE shares on diamond == 0\n\n",
            "## Caveats\n",
            "- Hermetic research; not mainnet APY\n",
            "- Synthetic at live may sit in deadband or already mint-allowed (see D2)\n\n",
            "## Commands\n",
            "```bash\n",
            "FOUNDRY_PROFILE=default forge script \\\n",
            "  scripts/foundry/research/detf/singleSe/Script_D1_FirstBond.s.sol:Script_D1_FirstBond -vv\n",
            "```\n"
        );
        vm.writeFile(path, body);
        tokenId_; // silence unused when notes static
    }
}
