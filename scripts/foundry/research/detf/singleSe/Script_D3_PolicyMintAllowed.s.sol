// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {
    ResearchFixture_DetfSingleSeUniV2
} from "scripts/foundry/research/detf/singleSe/ResearchFixture_DetfSingleSeUniV2.sol";

/**
 * @title Script_D3_PolicyMintAllowed
 * @notice Phase 3 D3: production synthetic drive to mint-allowed; preview==exec mint.
 */
contract Script_D3_PolicyMintAllowed is Script {
    uint256 internal constant BOND_LP = 1_000e18;
    uint256 internal constant MINT_LP = 30e18;
    uint256 internal constant MAX_TRADE_STEPS = 40;

    function run() external {
        ResearchFixture_DetfSingleSeUniV2 fixture = new ResearchFixture_DetfSingleSeUniV2();
        fixture.bootstrapDetfResearch();
        fixture.deployPolicyDetf("Research Policy DETF D3", "rD3");
        fixture.initTelemetry("D3_policyMintAllowed");

        address user = fixture.researchUser();
        fixture.fundAndBond(user, BOND_LP);
        require(fixture.detfInfo().isReserveLive(), "D3: live");
        console2.log("D3: free DETF after bond:", IERC20(fixture.detf()).balanceOf(user));
        fixture.sampleDetf("post_bond");

        uint256 supply0 = IERC20(fixture.detf()).totalSupply();
        uint256 steps = fixture.driveMintAllowed(MAX_TRADE_STEPS);
        uint256 supply1 = IERC20(fixture.detf()).totalSupply();
        console2.log("D3: drive steps / supply0 / supply1:", steps, supply0, supply1);
        console2.log("  synth:", fixture.detfInfo().syntheticPrice());
        require(fixture.detfInfo().isMintingAllowed(), "D3: mint allowed");
        fixture.sampleDetf("mint_allowed");

        uint256 seIn = fixture.fundSeShares(user, MINT_LP);
        uint256 mintIn = seIn / 10;
        if (mintIn == 0) mintIn = seIn;
        uint256 preview = fixture.previewMint(mintIn);
        uint256 exec = fixture.mintSeSharesForDetf(user, mintIn);
        uint256 diff = preview > exec ? preview - exec : exec - preview;
        console2.log("D3: preview/exec/diff", preview, exec, diff);
        require(diff <= 1, "D3: preview-exec > 1 wei");
        require(exec > 0, "D3: mint out > 0");
        fixture.sampleDetf("post_mint_capital_seigniorage");

        _writeArtifacts(steps, supply0, supply1, preview, exec, diff);
        console2.log("wrote research/out/detf/singleSe/D3_policyMintAllowed/");
    }

    function _writeArtifacts(
        uint256 steps,
        uint256 supply0,
        uint256 supply1,
        uint256 preview,
        uint256 exec,
        uint256 diff
    ) internal {
        string memory meta = string.concat(
            '{"campaign":"detf/singleSe","phase":"3","runId":"D3_policyMintAllowed",',
            '"seAttachment":"uniswapV2","driveSteps":',
            vm.toString(steps),
            ',"supplyBeforeDrive":"',
            vm.toString(supply0),
            '","supplyAfterDrive":"',
            vm.toString(supply1),
            '","previewOut":"',
            vm.toString(preview),
            '","execOut":"',
            vm.toString(exec),
            '","previewExecDiff":"',
            vm.toString(diff),
            '","driveNote":"prod_free_detf_burns_plus_uni_trades"}'
        );
        vm.writeFile("research/out/detf/singleSe/D3_policyMintAllowed/meta.json", meta);

        string memory body = string.concat(
            "# D3_policyMintAllowed\n\n",
            "## One-line story\n",
            "Production synthetic drive (free-DETF primary burns when burn-allowed + Uni V2 trades) opened mint; capital mint preview==execution.\n\n",
            "## Synthetic drive (honest)\n",
            "Post-bond product mint-split issues free DETF, diluting synthetic below burnThreshold.\n",
            "Drive (TestBase Phase A+B-aligned, no Open/deal):\n",
            "1. Primary-market burn of free DETF while burn-allowed\n",
            "2. Real Uni V2 trades (SE rate providers)\n\n",
            "RQ5: Uni trades alone do not clear mintThreshold from post-bond synth ~0.625; free-DETF burns are required co-path.\n\n",
            "## Key numbers\n",
            "- driveSteps: ",
            vm.toString(steps),
            "\n- supply drive: ",
            vm.toString(supply0),
            " -> ",
            vm.toString(supply1),
            "\n- preview/exec/diff: ",
            vm.toString(preview),
            " / ",
            vm.toString(exec),
            " / ",
            vm.toString(diff),
            "\n\n## Commands\n```bash\nFOUNDRY_PROFILE=default forge script \\\n",
            "  scripts/foundry/research/detf/singleSe/Script_D3_PolicyMintAllowed.s.sol:Script_D3_PolicyMintAllowed -vv\n```\n"
        );
        vm.writeFile("research/out/detf/singleSe/D3_policyMintAllowed/NOTES.md", body);
    }
}
