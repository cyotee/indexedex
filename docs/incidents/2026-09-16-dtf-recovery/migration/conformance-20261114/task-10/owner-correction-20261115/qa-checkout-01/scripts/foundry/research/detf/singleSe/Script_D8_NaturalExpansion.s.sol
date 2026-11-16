// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

import {
    ResearchFixture_DetfSingleSeUniV2
} from "scripts/foundry/research/detf/singleSe/ResearchFixture_DetfSingleSeUniV2.sol";

/**
 * @title Script_D8_NaturalExpansion
 * @notice Phase 3 D8: Policy mint-rich + warp -> expansion supply up; Open twin does not.
 *
 * ```bash
 * FOUNDRY_PROFILE=default forge script \
 *   scripts/foundry/research/detf/singleSe/Script_D8_NaturalExpansion.s.sol:Script_D8_NaturalExpansion -vv
 * ```
 */
contract Script_D8_NaturalExpansion is Script {
    uint256 internal constant BOND_LP = 1_000e18;
    uint256 internal constant SECOND_BOND_LP = 200e18;
    uint256 internal constant MAX_TRADE_STEPS = 80;
    uint256 internal constant WARP_SECONDS = 12 hours;

    function run() external {
        ResearchFixture_DetfSingleSeUniV2 fixture = new ResearchFixture_DetfSingleSeUniV2();
        fixture.bootstrapDetfResearch();
        fixture.deployPolicyDetf("Research Policy DETF D8", "rD8");
        fixture.enableSeigniorage(0.20e18);
        fixture.initTelemetry("D8_naturalExpansion");

        address user = fixture.researchUser();
        (uint256 firstId,) = fixture.fundAndBond(user, BOND_LP);
        fixture.sellBondToProtocol(user, firstId);
        (uint256 userBond,) = fixture.fundAndBond(user, SECOND_BOND_LP);
        require(fixture.detfInfo().isReserveLive(), "D8: live");
        require(uint8(fixture.detfInfo().thresholdMode()) == uint8(ThresholdMode.Policy), "D8: Policy");
        fixture.sampleDetf("post_bonds");

        if (!fixture.detfInfo().isMintingAllowed()) {
            fixture.driveMintAllowed(MAX_TRADE_STEPS);
        }
        require(fixture.detfInfo().isMintingAllowed(), "D8: mint-rich for expansion");
        fixture.sampleDetf("mint_rich");

        fixture.compoundProtocol();
        uint256 supply0 = IERC20(fixture.detf()).totalSupply();
        uint256 pending0 = fixture.pendingRewardsOf(userBond);
        uint256 expRate = fixture.detfInfo().expansionClosureRatePerSecond();
        require(expRate > 0, "D8: expansion rate must be on");
        console2.log("D8 expansion rate/s:", expRate);
        fixture.sampleDetf("pre_warp");

        vm.warp(block.timestamp + WARP_SECONDS);
        require(IERC20(fixture.detf()).totalSupply() == supply0, "D8: no mint until touch");
        fixture.compoundProtocol();

        uint256 supply1 = IERC20(fixture.detf()).totalSupply();
        uint256 pending1 = fixture.pendingRewardsOf(userBond);
        console2.log("D8 supply 0/1", supply0, supply1);
        console2.log("D8 pending 0/1", pending0, pending1);
        require(supply1 > supply0, "D8: expansion increased totalSupply");
        fixture.sampleDetf("post_expansion");

        _runOpenTwin(fixture);
        _writeMetaAndNotes(fixture, supply0, supply1, pending0, pending1, expRate);
        console2.log("wrote research/out/detf/singleSe/D8_naturalExpansion/");
    }

    function _runOpenTwin(ResearchFixture_DetfSingleSeUniV2 fixture) internal {
        fixture.deployOpenDetf("Research Open DETF D8 twin", "oD8");
        fixture.enableSeigniorage(0.20e18);
        address bob = fixture.researchUser2();
        fixture.fundAndBond(bob, BOND_LP);
        require(fixture.detfInfo().isMintingAllowed(), "D8 open: mint");
        uint256 openSupply0 = IERC20(fixture.detf()).totalSupply();
        fixture.compoundProtocol();
        vm.warp(block.timestamp + WARP_SECONDS);
        fixture.compoundProtocol();
        require(IERC20(fixture.detf()).totalSupply() == openSupply0, "D8: Open twin never expands");
        fixture.sampleDetf("open_twin_no_expansion");
    }

    function _writeMetaAndNotes(
        ResearchFixture_DetfSingleSeUniV2 fixture,
        uint256 supply0,
        uint256 supply1,
        uint256 pending0,
        uint256 pending1,
        uint256 expRate
    ) internal {
        fixture; // silence if unused - used for symmetry
        string memory meta = string.concat(
            '{"campaign":"detf/singleSe","phase":"3","runId":"D8_naturalExpansion",',
            '"seAttachment":"uniswapV2","expansionClosureRatePerSecond":"',
            vm.toString(expRate),
            '","warpSeconds":"',
            vm.toString(WARP_SECONDS),
            '","supplyBefore":"',
            vm.toString(supply0),
            '","supplyAfter":"',
            vm.toString(supply1),
            '"}'
        );
        vm.writeFile("research/out/detf/singleSe/D8_naturalExpansion/meta.json", meta);

        string memory body = string.concat(
            "# D8_naturalExpansion\n\n",
            "## One-line story\n",
            "Policy + live + mint-rich + warp + touch -> natural expansion mints free DETF; Open twin does not expand.\n\n",
            "## Key numbers\n",
            "- expansionClosureRatePerSecond: ",
            vm.toString(expRate),
            "\n- warpSeconds: ",
            vm.toString(WARP_SECONDS),
            "\n- supply pre/post: ",
            vm.toString(supply0),
            " / ",
            vm.toString(supply1),
            "\n- pending pre/post: ",
            vm.toString(pending0),
            " / ",
            vm.toString(pending1),
            "\n\n## Non-claims\n- No APY / mainnet yield claim.\n\n## Commands\n```bash\n",
            "FOUNDRY_PROFILE=default forge script \\\n",
            "  scripts/foundry/research/detf/singleSe/Script_D8_NaturalExpansion.s.sol:Script_D8_NaturalExpansion -vv\n```\n"
        );
        vm.writeFile("research/out/detf/singleSe/D8_naturalExpansion/NOTES.md", body);
    }
}
