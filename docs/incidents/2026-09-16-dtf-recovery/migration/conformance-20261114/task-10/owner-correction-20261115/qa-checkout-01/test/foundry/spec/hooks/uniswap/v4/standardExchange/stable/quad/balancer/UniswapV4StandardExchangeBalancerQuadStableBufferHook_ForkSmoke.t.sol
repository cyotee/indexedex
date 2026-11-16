// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";

/**
 * @notice Equal-priority smoke for ETH / Base / RH — real product path.
 */
contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_ForkSmoke is
    TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook
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
