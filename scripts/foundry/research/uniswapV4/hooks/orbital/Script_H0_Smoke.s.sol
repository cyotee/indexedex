// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Vm} from "forge-std/Vm.sol";

import {
    ResearchFixture_OrbitalHook
} from "scripts/foundry/research/uniswapV4/hooks/orbital/ResearchFixture_OrbitalHook.sol";

/**
 * @title Script_H0_Smoke
 * @notice Orbital hook: production deploy; three doors; radius 0 until seed.
 *
 * ```bash
 * FOUNDRY_PROFILE=default forge script \
 *   scripts/foundry/research/uniswapV4/hooks/orbital/Script_H0_Smoke.s.sol:Script_H0_Smoke -vv
 * ```
 */
contract Script_H0_Smoke is Script {
    function run() external {
        ResearchFixture_OrbitalHook fixture = new ResearchFixture_OrbitalHook();
        fixture.bootstrapResearch();
        fixture.initTelemetry("H0_smoke");

        console2.log("H0: Orbital Swap Hook smoke");
        console2.log("  hook:", fixture.hookAddress());
        console2.log("  radius (pre-seed):", fixture.radius());

        require(fixture.radius() == 0, "H0: radius should be 0 pre-seed");
        fixture.sample("pre_seed");

        uint256 shares = fixture.seedLiquidity(fixture.DEFAULT_SEED());
        console2.log("  seeded shares:", shares);
        console2.log("  radius (post-seed):", fixture.radius());
        require(shares > 0, "H0: seed shares");
        require(fixture.radius() > 0, "H0: radius after seed");
        fixture.sample("post_seed");

        console2.log("wrote research/out/uniswapV4/hooks/orbital/H0_smoke/");
        _writeNotes();
    }

    function _writeNotes() internal {
        string memory path = "research/out/uniswapV4/hooks/orbital/H0_smoke/NOTES.md";
        string memory body = string.concat(
            "# H0_smoke\n\n",
            "## One-line story\n",
            "Orbital Swap Hook deploys via production package path; radius 0 until first LP; seed establishes sphere.\n\n",
            "## Setup\n",
            "- Product: Uniswap V4 Orbital Swap Hook (3-asset)\n",
            "- Path: hook factory + registry deployHookVault (TestBase)\n",
            "- Seed: 500 ether per leg\n\n",
            "## What the series shows\n",
            "1. pre_seed: radius=0, reserves empty\n",
            "2. post_seed: radius>0, equal-ish reserves, LP supply>0\n\n",
            "## Caveats\n",
            "- Hermetic mintable tokens; not live APY\n",
            "- Numeraire = token units 1:1\n\n",
            "## Commands\n",
            "```bash\n",
            "forge script scripts/foundry/research/uniswapV4/hooks/orbital/Script_H0_Smoke.s.sol:Script_H0_Smoke -vv\n",
            "```\n"
        );
        Vm vm_ = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
        vm_.writeFile(path, body);
    }
}
