// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";

/**
 * @notice Base mainnet equal-priority smoke (real product path).
 */
contract UniswapV4StandardExchangeWeightedBufferHook_Base is
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
{
    function test_forkOrHermetic_smoke_deployMintSwapSingle() public {
        try vm.envString("FOUNDRY_BASE_RPC_URL") returns (string memory url) {
            if (bytes(url).length > 0) {}
        } catch {}
        _smokeDeployMintSwapSingle();
    }
}
