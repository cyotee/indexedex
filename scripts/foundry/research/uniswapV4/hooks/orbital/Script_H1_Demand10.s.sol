// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Vm} from "forge-std/Vm.sol";

import {
    ResearchFixture_OrbitalHook
} from "scripts/foundry/research/uniswapV4/hooks/orbital/ResearchFixture_OrbitalHook.sol";

/**
 * @title Script_H1_Demand10
 * @notice Mirror of H1_demand_01: market buys token0 with token1.
 */
contract Script_H1_Demand10 is Script {
    function run() external {
        ResearchFixture_OrbitalHook fixture = new ResearchFixture_OrbitalHook();
        fixture.bootstrapResearch();
        fixture.seedLiquidity(fixture.DEFAULT_SEED());
        fixture.setDexFee(0.003e18);
        fixture.initTelemetry("H1_demand_10");

        (address t0, address t1,) = fixture.tokenAddresses();
        console2.log("H1: market buys token0 with token1");

        fixture.sample("t0_seed");

        uint256 steps = fixture.TRADE_STEPS();
        uint256 trade = fixture.TRADE_SIZE();
        for (uint256 i = 0; i < steps; ++i) {
            fixture.swapExactIn(t1, t0, trade);
            fixture.sample("market_buys_t0");
        }

        console2.log("wrote research/out/uniswapV4/hooks/orbital/H1_demand_10/");
        _writeNotes();
    }

    function _writeNotes() internal {
        string memory path = "research/out/uniswapV4/hooks/orbital/H1_demand_10/NOTES.md";
        string memory body = string.concat(
            "# H1_demand_10\n\n",
            "## One-line story\n",
            "Mirror demand: market buys token0 with token1 for 24 steps after equal seed.\n\n",
            "## Setup\n",
            "- Same as H1_demand_01 with reversed tokenIn/tokenOut\n\n",
            "## Expectation\n",
            "midIndex01 should move opposite to H1_demand_01 under raw r1/r0 framing.\n\n",
            "## Commands\n",
            "```bash\n",
            "forge script scripts/foundry/research/uniswapV4/hooks/orbital/Script_H1_Demand10.s.sol:Script_H1_Demand10 -vv\n",
            "```\n"
        );
        Vm vm_ = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
        vm_.writeFile(path, body);
    }
}
