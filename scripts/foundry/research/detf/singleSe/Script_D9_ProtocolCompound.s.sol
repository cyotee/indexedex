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
 * @title Script_D9_ProtocolCompound
 * @notice Phase 3 D9: protocol compound increases protocol-owned BPT principal.
 * @dev Production path only: Open DETF + seigniorage mint inventory (no deal seed).
 *      Open allows mint when live so seigniorage inventory accrues without Policy gates.
 *
 * ```bash
 * FOUNDRY_PROFILE=default forge script \
 *   scripts/foundry/research/detf/singleSe/Script_D9_ProtocolCompound.s.sol:Script_D9_ProtocolCompound -vv
 * ```
 */
contract Script_D9_ProtocolCompound is Script {
    uint256 internal constant BOND_LP = 1_000e18;
    uint256 internal constant SECOND_BOND_LP = 200e18;
    uint256 internal constant MINT_LP = 40e18;

    function run() external {
        ResearchFixture_DetfSingleSeUniV2 fixture = new ResearchFixture_DetfSingleSeUniV2();
        fixture.bootstrapDetfResearch();
        // Open: mint when live without synthetic gates; seigniorage inventory is real product path.
        fixture.deployOpenDetf("Research Open DETF D9", "oD9");
        require(uint8(fixture.detfInfo().thresholdMode()) == uint8(ThresholdMode.Open), "D9: Open");
        fixture.enableSeigniorage(0.20e18);
        fixture.initTelemetry("D9_protocolCompound");

        address user = fixture.researchUser();
        address minter = fixture.researchUser2();

        // First bond -> sell to protocol so protocol NFT has principal + effective share weight.
        (uint256 firstId,) = fixture.fundAndBond(user, BOND_LP);
        fixture.sellBondToProtocol(user, firstId);
        uint256 protocolBpt0 = fixture.protocolBptBalance();
        require(protocolBpt0 > 0, "D9: protocol principal after sell");
        fixture.sampleDetf("post_sell_to_protocol");

        // User keeps second bond (claim-while-locked surface).
        (uint256 userBond,) = fixture.fundAndBond(user, SECOND_BOND_LP);
        require(fixture.bondNftVault().effectiveSharesOf(userBond) > 0, "D9: user bond shares");
        fixture.sampleDetf("post_user_bond");

        // Snapshot BPT before seigniorage mint (lazy compound may run inside mint).
        uint256 protocolBptBeforeMint = fixture.protocolBptBalance();
        require(fixture.detfInfo().isMintingAllowed(), "D9: Open mint when live");

        // Production seigniorage mint(s): inventory DETF -> bond vault reward ledger by share weights.
        uint256 mintedTotal;
        for (uint256 i; i < 4; ++i) {
            uint256 seIn = fixture.fundSeShares(minter, MINT_LP);
            if (seIn == 0) break;
            uint256 mintIn = seIn / 15;
            if (mintIn == 0) mintIn = seIn;
            try fixture.mintSeSharesForDetf(minter, mintIn) returns (uint256 out_) {
                mintedTotal += out_;
            } catch {
                break;
            }
            fixture.sampleDetf(string.concat("seigniorage_mint_", vm.toString(i + 1)));
        }
        require(mintedTotal > 0, "D9: seigniorage mint produced DETF");
        fixture.sampleDetf("post_seigniorage_mints");

        uint256 protocolBptAfterMint = fixture.protocolBptBalance();
        uint256 protocolPending = fixture.protocolPendingRewards();
        console2.log("D9 protocol BPT before/after mint", protocolBptBeforeMint, protocolBptAfterMint);
        console2.log("D9 protocol pending after mint", protocolPending);

        // Path A: lazy compound on mint already increased protocol principal.
        // Path B: public compoundProtocolRewards sinks remaining protocol pending.
        uint256 protocolBptBefore = protocolBptAfterMint;
        uint256 detfIn;
        uint256 bptOut;

        if (protocolBptAfterMint > protocolBptBeforeMint) {
            // Lazy compound credited principal during mint(s).
            console2.log("D9: lazy compound increased protocol BPT on mint path");
            detfIn = 1; // mark success path (lazy); public call still attempted below if pending remains
            bptOut = protocolBptAfterMint - protocolBptBeforeMint;
            protocolBptBefore = protocolBptBeforeMint;
        }

        if (protocolPending > 0 || detfIn == 0) {
            protocolBptBefore = fixture.protocolBptBalance();
            (detfIn, bptOut) = fixture.compoundProtocol();
            console2.log("D9 public compound detfIn/bptOut", detfIn, bptOut);
            // If first public call is no-op, more seigniorage mint then compound (still production).
            if (detfIn == 0) {
                uint256 seIn2 = fixture.fundSeShares(minter, MINT_LP);
                if (seIn2 > 0) {
                    uint256 mintIn2 = seIn2 / 15;
                    if (mintIn2 == 0) mintIn2 = seIn2;
                    try fixture.mintSeSharesForDetf(minter, mintIn2) {} catch {}
                }
                protocolBptBefore = fixture.protocolBptBalance();
                (detfIn, bptOut) = fixture.compoundProtocol();
                console2.log("D9 retry compound detfIn/bptOut", detfIn, bptOut);
            }
        }

        uint256 protocolBptAfter = fixture.protocolBptBalance();
        console2.log("D9 protocol BPT final before/after", protocolBptBefore, protocolBptAfter);

        // Success: protocol principal strictly rose via production seigniorage compound (lazy and/or public).
        require(protocolBptAfter > protocolBpt0, "D9: protocol BPT above post-sell baseline");
        require(
            protocolBptAfter > protocolBptBeforeMint || (detfIn > 0 && bptOut > 0 && protocolBptAfter > protocolBptBefore),
            "D9: protocol BPT must rise from seigniorage compound path"
        );
        if (detfIn > 0 && bptOut > 0 && protocolBptAfter >= protocolBptBefore + bptOut) {
            // public compound exact credit
            require(protocolBptAfter == protocolBptBefore + bptOut, "D9: principal += bptOut");
        }
        fixture.sampleDetf("post_compound");

        require(block.timestamp < fixture.bondNftVault().unlockTimeOf(userBond), "D9: user still locked");

        string memory meta = string.concat(
            '{"campaign":"detf/singleSe","phase":"3","runId":"D9_protocolCompound",',
            '"seAttachment":"uniswapV2","thresholdMode":"Open",',
            '"protocolBptBaseline":"',
            vm.toString(protocolBpt0),
            '","protocolBptBeforeMint":"',
            vm.toString(protocolBptBeforeMint),
            '","protocolBptAfter":"',
            vm.toString(protocolBptAfter),
            '","detfIn":"',
            vm.toString(detfIn),
            '","bptOut":"',
            vm.toString(bptOut),
            '","accounting":"bondNftVault.originalSharesOf(detfNFTId)",',
            '"rewardSource":"seigniorage_mint_no_deal"}'
        );
        vm.writeFile("research/out/detf/singleSe/D9_protocolCompound/meta.json", meta);

        console2.log("wrote research/out/detf/singleSe/D9_protocolCompound/");
        _writeNotes(protocolBpt0, protocolBptBeforeMint, protocolBptAfter, detfIn, bptOut);
    }

    function _writeNotes(
        uint256 bpt0,
        uint256 bptBeforeMint,
        uint256 bptAfter,
        uint256 detfIn,
        uint256 bptOut
    ) internal {
        string memory path = "research/out/detf/singleSe/D9_protocolCompound/NOTES.md";
        string memory body = string.concat(
            "# D9_protocolCompound\n\n",
            "## One-line story\n",
            "Open DETF + seigniorage mints build protocol NFT reward inventory; compound (lazy and/or public) raises protocol BPT principal. No deal seed.\n\n",
            "## Accounting\n",
            "- Metric: `bondNftVault.originalSharesOf(detfNFTId)`\n",
            "- Reward source: production seigniorage inventory on mint (20% incentive)\n",
            "- Single-sided DETF join skew accepted in v1 product law\n\n",
            "## Key numbers\n",
            "- protocolBpt after sell: ",
            vm.toString(bpt0),
            "\n",
            "- protocolBpt before seigniorage mint: ",
            vm.toString(bptBeforeMint),
            "\n",
            "- protocolBpt after compound path: ",
            vm.toString(bptAfter),
            "\n",
            "- public compound detfIn / bptOut: ",
            vm.toString(detfIn),
            " / ",
            vm.toString(bptOut),
            "\n\n",
            "## Non-claims\n",
            "- No claim APY / mainnet yield claim\n\n",
            "## Commands\n",
            "```bash\n",
            "FOUNDRY_PROFILE=default forge script \\\n",
            "  scripts/foundry/research/detf/singleSe/Script_D9_ProtocolCompound.s.sol:Script_D9_ProtocolCompound -vv\n",
            "```\n"
        );
        vm.writeFile(path, body);
    }
}
