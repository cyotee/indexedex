// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Vm} from "forge-std/Vm.sol";

import {
    ResearchFixture_OrbitalHook
} from "scripts/foundry/research/uniswapV4/hooks/orbital/ResearchFixture_OrbitalHook.sol";
import {ResearchTelemetry} from "scripts/foundry/research/harness/ResearchTelemetry.sol";

/**
 * @title Script_H2_Preview
 * @notice Assert previewSwapExactIn == execution on six directions (one step each).
 */
contract Script_H2_Preview is Script {
    function run() external {
        ResearchFixture_OrbitalHook fixture = new ResearchFixture_OrbitalHook();
        fixture.bootstrapResearch();
        fixture.seedLiquidity(fixture.DEFAULT_SEED());
        fixture.setDexFee(0.003e18);
        fixture.initTelemetry("H2_preview");

        (address t0, address t1, address t2) = fixture.tokenAddresses();
        fixture.sample("seed");

        _check(fixture, t0, t1, "t0_t1");
        _check(fixture, t1, t0, "t1_t0");
        _check(fixture, t1, t2, "t1_t2");
        _check(fixture, t2, t1, "t2_t1");
        _check(fixture, t0, t2, "t0_t2");
        _check(fixture, t2, t0, "t2_t0");

        console2.log("H2: all six directions preview==exec");
        console2.log("wrote research/out/uniswapV4/hooks/orbital/H2_preview/");
        _writeNotes();
    }

    function _check(ResearchFixture_OrbitalHook fixture, address tin, address tout, string memory tag)
        internal
    {
        (uint256 preview_, uint256 exec_) = fixture.measurePreviewExactIn(tin, tout, 1 ether);
        require(preview_ == exec_, "H2: preview != exec");
        // Append explicit preview line
        ResearchTelemetry.appendLine(
            fixture.telemetryPaths(),
            string.concat(
                '{"step":',
                ResearchTelemetry.u(fixture.currentStep()),
                ',"tag":"preview_',
                tag,
                '","previewOut":',
                ResearchTelemetry.u(preview_),
                ',"execOut":',
                ResearchTelemetry.u(exec_),
                "}"
            )
        );
        console2.log(tag);
        console2.log("  preview==exec:", preview_);
    }

    function _writeNotes() internal {
        string memory path = "research/out/uniswapV4/hooks/orbital/H2_preview/NOTES.md";
        string memory body = string.concat(
            "# H2_preview\n\n",
            "## One-line story\n",
            "After seed + 0.3% fee, exact-in preview matches execution on all six orbital pair directions.\n\n",
            "## Result\n",
            "PASS: previewOut == execOut (exact) for 1 ether swaps.\n\n",
            "## Commands\n",
            "```bash\n",
            "forge script scripts/foundry/research/uniswapV4/hooks/orbital/Script_H2_Preview.s.sol:Script_H2_Preview -vv\n",
            "```\n"
        );
        Vm vm_ = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
        vm_.writeFile(path, body);
    }
}
