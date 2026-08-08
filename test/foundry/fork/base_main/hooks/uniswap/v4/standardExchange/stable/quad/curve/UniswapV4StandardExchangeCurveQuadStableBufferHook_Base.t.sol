// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/TestBase_UniswapV4StandardExchangeQuadStableBufferHook.sol";

/**
 * @notice FK Base: createSelectFork when BASE_RPC_URL/ALCHEMY_KEY set; else honest skip log + hermetic smoke.
 */
contract UniswapV4StandardExchangeQuadStableBufferHook_Base is
    TestBase_UniswapV4StandardExchangeQuadStableBufferHook
{
    bool internal forked;

    function setUp() public override {
        string memory rpc = vm.envOr("FOUNDRY_BASE_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            rpc = vm.envOr("BASE_RPC_URL", string(""));
        }
        if (bytes(rpc).length == 0) {
            string memory key = vm.envOr("ALCHEMY_KEY", string(""));
            if (bytes(key).length > 0) {
                rpc = string.concat("https://base-mainnet.g.alchemy.com/v2/", key);
            }
        }
        if (bytes(rpc).length == 0) {
            super.setUp();
            return;
        }
        try vm.createSelectFork(rpc) {
            forked = true;
        } catch {
            emit log("FK base: createSelectFork failed - hermetic smoke");
        }
        super.setUp();
    }

    function test_FK_base_smoke_orRecordSkip() public {
        if (!forked) {
            emit log("FK base skip/unavailable: BASE_RPC_URL / ALCHEMY_KEY unset or fork failed");
        } else {
            emit log("FK base: live fork active");
        }
        _smokeDeployMintSwapSingle();
    }
}
