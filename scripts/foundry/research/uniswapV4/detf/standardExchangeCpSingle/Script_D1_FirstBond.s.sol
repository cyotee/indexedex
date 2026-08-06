// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Vm} from "forge-std/Vm.sol";

import {
    ResearchFixture_UniV4CpDetf
} from "scripts/foundry/research/uniswapV4/detf/standardExchangeCpSingle/ResearchFixture_UniV4CpDetf.sol";

/**
 * @title Script_D1_FirstBond
 * @notice Permissionless first bond with pairToken → isReserveLive.
 */
contract Script_D1_FirstBond is Script {
    function run() external {
        ResearchFixture_UniV4CpDetf fixture = new ResearchFixture_UniV4CpDetf();
        fixture.bootstrapResearch();
        fixture.initTelemetry("D1_firstBond");

        console2.log("D1: first bond -> live");
        require(!fixture.detfInfoView().isReserveLive(), "D1: start inert");
        fixture.sampleDetf("pre_bond");

        (uint256 tokenId, uint256 shares) = fixture.firstBondPublic(100 ether);
        console2.log("  bond tokenId:", tokenId);
        console2.log("  lp principal:", shares);

        require(fixture.detfInfoView().isReserveLive(), "D1: expected live");
        require(tokenId > 0, "D1: bond nft");
        require(shares > 0, "D1: lp shares");

        fixture.sampleDetf("post_bond");
        console2.log("wrote research/out/uniswapV4/detf/standardExchangeCpSingle/D1_firstBond/");
        _writeNotes();
    }

    function _writeNotes() internal {
        string memory path = "research/out/uniswapV4/detf/standardExchangeCpSingle/D1_firstBond/NOTES.md";
        string memory body = string.concat(
            "# D1_firstBond\n\n",
            "## One-line story\n",
            "First bond with pairToken takes Uni V4 CP DETF live; bond NFT holds hook LP principal.\n\n",
            "## Setup\n",
            "- Bond amount: 100 ether pairToken\n",
            "- Lock: TestBase DEFAULT_MIN_LOCK\n\n",
            "## Result\n",
            "PASS: isReserveLive=true after bond; tokenId>0; shares>0.\n\n",
            "## Commands\n",
            "```bash\n",
            "forge script scripts/foundry/research/uniswapV4/detf/standardExchangeCpSingle/Script_D1_FirstBond.s.sol:Script_D1_FirstBond -vv\n",
            "```\n"
        );
        Vm vm_ = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
        vm_.writeFile(path, body);
    }
}
