// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {
    ResearchFixture_DetfSingleSeUniV2
} from "scripts/foundry/research/detf/singleSe/ResearchFixture_DetfSingleSeUniV2.sol";

/**
 * @title Script_D6_CapitalSeigniorageDilution
 * @notice Phase 3 D6: sequence of primary mints; supply up (capital seigniorage only).
 *
 * ```bash
 * FOUNDRY_PROFILE=default forge script \
 *   scripts/foundry/research/detf/singleSe/Script_D6_CapitalSeigniorageDilution.s.sol:Script_D6_CapitalSeigniorageDilution -vv
 * ```
 */
contract Script_D6_CapitalSeigniorageDilution is Script {
    uint256 internal constant BOND_LP = 1_000e18;
    uint256 internal constant MINT_LP = 25e18;
    uint256 internal constant N_MINTS = 5;
    uint256 internal constant MAX_TRADE_STEPS = 40;

    function run() external {
        ResearchFixture_DetfSingleSeUniV2 fixture = new ResearchFixture_DetfSingleSeUniV2();
        fixture.bootstrapDetfResearch();
        fixture.deployPolicyDetf("Research Policy DETF D6", "rD6");
        fixture.enableSeigniorage(0.20e18);
        fixture.initTelemetry("D6_capitalSeigniorage");

        address user = fixture.researchUser();
        fixture.fundAndBond(user, BOND_LP);
        require(fixture.detfInfo().isReserveLive(), "D6: live");
        fixture.sampleDetf("post_bond");

        if (!fixture.detfInfo().isMintingAllowed()) {
            fixture.driveMintAllowed(MAX_TRADE_STEPS);
        }
        require(fixture.detfInfo().isMintingAllowed(), "D6: mint allowed");
        fixture.sampleDetf("mint_allowed");

        uint256 supply0 = IERC20(fixture.detf()).totalSupply();
        uint256 lastSupply = supply0;
        for (uint256 i; i < N_MINTS; ++i) {
            if (!fixture.detfInfo().isMintingAllowed()) {
                // Trades may have left deadband after dilution - re-drive.
                fixture.driveMintAllowed(MAX_TRADE_STEPS);
            }
            uint256 seIn = fixture.fundSeShares(user, MINT_LP);
            if (seIn == 0) break;
            uint256 mintIn = seIn / 10;
            if (mintIn == 0) mintIn = seIn;
            uint256 out = fixture.mintSeSharesForDetf(user, mintIn);
            require(out > 0, "D6: mint out");
            uint256 supply = IERC20(fixture.detf()).totalSupply();
            require(supply > lastSupply, "D6: supply increases each mint");
            lastSupply = supply;
            fixture.sampleDetf(string.concat("mint_", vm.toString(i + 1)));
            console2.log("D6 mint", i + 1, "supply", supply);
        }
        require(lastSupply > supply0, "D6: net supply growth");

        console2.log("wrote research/out/detf/singleSe/D6_capitalSeigniorage/");
        _writeNotes(supply0, lastSupply);
    }

    function _writeNotes(uint256 supply0, uint256 supplyN) internal {
        string memory path = "research/out/detf/singleSe/D6_capitalSeigniorage/NOTES.md";
        string memory body = string.concat(
            "# D6_capitalSeigniorage\n\n",
            "## One-line story\n",
            "Sequence of primary mints (capital seigniorage) increases DETF totalSupply; not natural expansion (D8).\n\n",
            "## Key numbers\n",
            "- supply start: ",
            vm.toString(supply0),
            "\n",
            "- supply end: ",
            vm.toString(supplyN),
            "\n\n",
            "## Labeling\n",
            "- Capital seigniorage only - external SE shares for DETF.\n",
            "- Natural expansion is D8 (time + mint-rich Policy).\n\n",
            "## Commands\n",
            "```bash\n",
            "FOUNDRY_PROFILE=default forge script \\\n",
            "  scripts/foundry/research/detf/singleSe/Script_D6_CapitalSeigniorageDilution.s.sol:Script_D6_CapitalSeigniorageDilution -vv\n",
            "```\n"
        );
        vm.writeFile(path, body);
    }
}
