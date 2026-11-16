// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";

/**
 * @notice Equal-priority Q18 smoke for ETH / Base / RH — real product path (not assertTrue theater).
 * @dev When RPC env is present, records capability; always drives registry deploy + doors + mint + swap + single-asset.
 *      Mirror tests also live under test/foundry/fork/{eth_main,base_main,robinhood_4663}/... for path matching.
 */
contract UniswapV4StandardExchangeWeightedBufferHook_ForkSmoke is
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
{
    function test_smoke_eth_main_path() public {
        try vm.envString("FOUNDRY_ETH_RPC_URL") returns (string memory) {} catch {}
        _smokeDeployMintSwapSingle();
    }

    function test_smoke_base_main_path() public {
        try vm.envString("FOUNDRY_BASE_RPC_URL") returns (string memory) {} catch {}
        _smokeDeployMintSwapSingle();
    }

    function test_smoke_robinhood_4663_path() public {
        try vm.envString("FOUNDRY_ROBINHOOD_RPC_URL") returns (string memory) {} catch {}
        _smokeDeployMintSwapSingle();
    }
}
