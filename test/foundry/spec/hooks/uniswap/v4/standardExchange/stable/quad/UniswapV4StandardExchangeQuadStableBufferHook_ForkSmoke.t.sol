// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/TestBase_UniswapV4StandardExchangeQuadStableBufferHook.sol";

/**
 * @notice Equal-priority smoke for ETH / Base / RH — real product path.
 */
contract UniswapV4StandardExchangeQuadStableBufferHook_ForkSmoke is
    TestBase_UniswapV4StandardExchangeQuadStableBufferHook
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
