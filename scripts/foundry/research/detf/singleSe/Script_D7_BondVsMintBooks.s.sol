// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {
    ResearchFixture_DetfSingleSeUniV2
} from "scripts/foundry/research/detf/singleSe/ResearchFixture_DetfSingleSeUniV2.sol";

/**
 * @title Script_D7_BondVsMintBooks
 * @notice Phase 3 D7: bonder pending rewards vs free DETF holder (no expansion airdrop).
 *
 * ```bash
 * FOUNDRY_PROFILE=default forge script \
 *   scripts/foundry/research/detf/singleSe/Script_D7_BondVsMintBooks.s.sol:Script_D7_BondVsMintBooks -vv
 * ```
 */
contract Script_D7_BondVsMintBooks is Script {
    uint256 internal constant BOND_LP = 1_000e18;
    uint256 internal constant MINT_LP = 30e18;
    uint256 internal constant MAX_TRADE_STEPS = 40;

    function run() external {
        ResearchFixture_DetfSingleSeUniV2 fixture = new ResearchFixture_DetfSingleSeUniV2();
        fixture.bootstrapDetfResearch();
        fixture.deployPolicyDetf("Research Policy DETF D7", "rD7");
        fixture.enableSeigniorage(0.20e18);
        fixture.initTelemetry("D7_bondVsMint");

        address alice = fixture.researchUser();
        address bob = fixture.researchUser2();

        // Alice: first bond (bonder).
        (uint256 aliceBond,) = fixture.fundAndBond(alice, BOND_LP);
        require(fixture.detfInfo().isReserveLive(), "D7: live");
        fixture.sampleDetfTagged("alice_bonded", "alice_bonder");

        // Bob: free DETF via mint when allowed (no bond).
        if (!fixture.detfInfo().isMintingAllowed()) {
            fixture.driveMintAllowed(MAX_TRADE_STEPS);
        }
        require(fixture.detfInfo().isMintingAllowed(), "D7: mint for bob");
        uint256 seIn = fixture.fundSeShares(bob, MINT_LP);
        uint256 mintIn = seIn / 10;
        if (mintIn == 0) mintIn = seIn;
        fixture.mintSeSharesForDetf(bob, mintIn);
        uint256 bobFree0 = IERC20(fixture.detf()).balanceOf(bob);
        require(bobFree0 > 0, "D7: bob free DETF");
        fixture.sampleDetfTagged("bob_minted_free", "bob_free");

        // Capital seigniorage mint (alice path already bonded) + short expansion window if mint-rich.
        if (fixture.detfInfo().isMintingAllowed()) {
            uint256 more = fixture.fundSeShares(bob, 20e18);
            if (more > 0) {
                uint256 chunk = more / 10;
                if (chunk == 0) chunk = more;
                try fixture.mintSeSharesForDetf(bob, chunk) {} catch {}
            }
        }
        fixture.sampleDetfTagged("post_capital_mint", "system");

        uint256 alicePending0 = fixture.pendingRewardsOf(aliceBond);
        uint256 bobFreeBeforeWarp = IERC20(fixture.detf()).balanceOf(bob);

        if (fixture.detfInfo().isMintingAllowed()) {
            fixture.detfInfo().compoundProtocolRewards();
            vm.warp(block.timestamp + 12 hours);
            fixture.detfInfo().compoundProtocolRewards();
        }
        uint256 alicePending1 = fixture.pendingRewardsOf(aliceBond);
        uint256 bobFreeAfterWarp = IERC20(fixture.detf()).balanceOf(bob);

        console2.log("D7 alice pending 0/1", alicePending0, alicePending1);
        console2.log("D7 bob free 0/1", bobFreeBeforeWarp, bobFreeAfterWarp);

        // Bob free DETF must not receive expansion airdrop (balance only changes via his own mints).
        require(bobFreeAfterWarp == bobFreeBeforeWarp, "D7: free holder no expansion airdrop");
        // Bonder has reward path (pending may grow from seigniorage inventory and/or expansion).
        // At minimum, books differ: bonder has bond NFT effective shares; bob has free ERC20 only.
        require(fixture.bondNftVault().effectiveSharesOf(aliceBond) > 0, "D7: alice effective shares");
        require(fixture.bondNftVault().balanceOf(bob) == 0, "D7: bob has no bond NFT");

        fixture.sampleDetfTagged("post_books_compare", "alice_bonder");
        fixture.sampleDetfTagged("post_books_compare", "bob_free");

        console2.log("wrote research/out/detf/singleSe/D7_bondVsMint/");
        _writeNotes(alicePending0, alicePending1, bobFreeBeforeWarp, bobFreeAfterWarp);
    }

    function _writeNotes(uint256 ap0, uint256 ap1, uint256 bf0, uint256 bf1) internal {
        string memory path = "research/out/detf/singleSe/D7_bondVsMint/NOTES.md";
        string memory body = string.concat(
            "# D7_bondVsMint\n\n",
            "## One-line story\n",
            "Bonder has bond-NFT reward ledger path; free DETF holder does not receive expansion airdrop on balance.\n\n",
            "## Key numbers\n",
            "- alice pending pre/post: ",
            vm.toString(ap0),
            " / ",
            vm.toString(ap1),
            "\n",
            "- bob free DETF pre/post warp: ",
            vm.toString(bf0),
            " / ",
            vm.toString(bf1),
            "\n\n",
            "## Commands\n",
            "```bash\n",
            "FOUNDRY_PROFILE=default forge script \\\n",
            "  scripts/foundry/research/detf/singleSe/Script_D7_BondVsMintBooks.s.sol:Script_D7_BondVsMintBooks -vv\n",
            "```\n"
        );
        vm.writeFile(path, body);
    }
}
