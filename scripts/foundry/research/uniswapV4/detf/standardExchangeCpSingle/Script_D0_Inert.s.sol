// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {
    ResearchFixture_UniV4CpDetf
} from "scripts/foundry/research/uniswapV4/detf/standardExchangeCpSingle/ResearchFixture_UniV4CpDetf.sol";

/**
 * @title Script_D0_Inert
 * @notice Uni V4 CP DETF: Policy deploy is inert; mint blocked.
 *
 * ```bash
 * FOUNDRY_PROFILE=default forge script \
 *   scripts/foundry/research/uniswapV4/detf/standardExchangeCpSingle/Script_D0_Inert.s.sol:Script_D0_Inert -vv
 * ```
 */
contract Script_D0_Inert is Script {
    function run() external {
        ResearchFixture_UniV4CpDetf fixture = new ResearchFixture_UniV4CpDetf();
        fixture.bootstrapResearch();
        fixture.initTelemetry("D0_inert");

        console2.log("D0: Uni V4 CP DETF inert");
        console2.log("  detf:", fixture.detfAddress());
        console2.log("  live:", fixture.detfInfoView().isReserveLive());

        require(!fixture.detfInfoView().isReserveLive(), "D0: expected inert");
        require(!fixture.detfInfoView().isMintingAllowed(), "D0: mint disallowed inert");

        // Default thresholds when Policy
        uint256 mintTh = fixture.detfInfoView().mintThreshold();
        uint256 burnTh = fixture.detfInfoView().burnThreshold();
        console2.log("  mintTh:", mintTh);
        console2.log("  burnTh:", burnTh);
        require(mintTh == 1.05e18, "D0: default mint threshold");
        require(burnTh == 0.95e18, "D0: default burn threshold");

        fixture.sampleDetf("inert_t0");

        // Mint must revert while inert
        address user = fixture.researchUser();
        address pair = fixture.pairTokenAddress();
        uint256 amt = 1 ether;
        vm.startPrank(user);
        IERC20(pair).approve(fixture.detfAddress(), amt);
        try fixture.detfExchangeInView().exchangeIn(
            IERC20(pair),
            amt,
            IERC20(fixture.detfAddress()),
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
            console2.log("  mint reverted as expected");
            console2.logBytes4(sel);
        }
        vm.stopPrank();

        fixture.sampleDetf("inert_post_mint_probe");
        console2.log("wrote research/out/uniswapV4/detf/standardExchangeCpSingle/D0_inert/");
        _writeNotes();
    }

    function _writeNotes() internal {
        string memory path = "research/out/uniswapV4/detf/standardExchangeCpSingle/D0_inert/NOTES.md";
        string memory body = string.concat(
            "# D0_inert\n\n",
            "## One-line story\n",
            "Uni V4 Single SE CP DETF deploys Policy inert against SE Buffer CP hook; mint blocked; defaults 1.05/0.95.\n\n",
            "## Setup\n",
            "- DETF: UniswapV4SingleStandardExchangeDETF (Policy)\n",
            "- Reserve host: Single SE Buffer CP Hook + ERC-4626 wrapper SE\n",
            "- Gold TestBase production path\n\n",
            "## Result\n",
            "PASS: isReserveLive=false; isMintingAllowed=false; mint reverts; thresholds 1.05/0.95.\n\n",
            "## Caveats\n",
            "- Hermetic; not Balancer Single SE re-run\n\n",
            "## Commands\n",
            "```bash\n",
            "forge script scripts/foundry/research/uniswapV4/detf/standardExchangeCpSingle/Script_D0_Inert.s.sol:Script_D0_Inert -vv\n",
            "```\n"
        );
        Vm vm_ = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
        vm_.writeFile(path, body);
    }
}
