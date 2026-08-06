// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Vm} from "forge-std/Vm.sol";

import {
    ResearchFixture_OrbitalHook
} from "scripts/foundry/research/uniswapV4/hooks/orbital/ResearchFixture_OrbitalHook.sol";

/**
 * @title Script_H1_Demand01
 * @notice Market buys token1 with token0 for TRADE_STEPS (LP framing: demand against t0→t1 door).
 *
 * ```bash
 * FOUNDRY_PROFILE=default forge script \
 *   scripts/foundry/research/uniswapV4/hooks/orbital/Script_H1_Demand01.s.sol:Script_H1_Demand01 -vv
 * ```
 */
contract Script_H1_Demand01 is Script {
    function run() external {
        ResearchFixture_OrbitalHook fixture = new ResearchFixture_OrbitalHook();
        fixture.bootstrapResearch();
        fixture.seedLiquidity(fixture.DEFAULT_SEED());
        fixture.setDexFee(0.003e18);
        fixture.initTelemetry("H1_demand_01");

        (address t0, address t1,) = fixture.tokenAddresses();
        console2.log("H1: market buys token1 with token0");
        console2.log("  trade size:", fixture.TRADE_SIZE());
        console2.log("  steps:", fixture.TRADE_STEPS());

        fixture.sample("t0_seed");

        uint256 steps = fixture.TRADE_STEPS();
        uint256 trade = fixture.TRADE_SIZE();
        for (uint256 i = 0; i < steps; ++i) {
            fixture.swapExactIn(t0, t1, trade);
            fixture.sample("market_buys_t1");
        }

        console2.log("  final r1:", fixture.reserveOf(t1));
        console2.log("wrote research/out/uniswapV4/hooks/orbital/H1_demand_01/");
        _writeNotes();
    }

    function _writeNotes() internal {
        string memory path = "research/out/uniswapV4/hooks/orbital/H1_demand_01/NOTES.md";
        string memory body = string.concat(
            "# H1_demand_01\n\n",
            "## One-line story\n",
            "After equal three-leg seed, market repeatedly buys token1 with token0 on the orbital pair door.\n\n",
            "## Setup\n",
            "- Seed: 500 ether per leg; dex fee 0.3%\n",
            "- Drive: exact-in token0->token1, 1 ether x 24 steps\n",
            "- Book: research user LP from seed (passive)\n\n",
            "## What the series shows\n",
            "1. midIndex01 moves as r1/r0 changes vs init\n",
            "2. r0 rises (token in), r1 falls (token out)\n",
            "3. radius / lpSupply stay defined (sphere state)\n\n",
            "## Caveats\n",
            "- Hermetic; fee + inventory not yet split P&L panels\n",
            "- mid ratios are raw reserve ratios, not USD\n\n",
            "## Commands\n",
            "```bash\n",
            "forge script scripts/foundry/research/uniswapV4/hooks/orbital/Script_H1_Demand01.s.sol:Script_H1_Demand01 -vv\n",
            "python research/plots/plot_uniswap_v4_hook_mids.py research/out/uniswapV4/hooks/orbital/H1_demand_01\n",
            "```\n"
        );
        Vm vm_ = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
        vm_.writeFile(path, body);
    }
}
