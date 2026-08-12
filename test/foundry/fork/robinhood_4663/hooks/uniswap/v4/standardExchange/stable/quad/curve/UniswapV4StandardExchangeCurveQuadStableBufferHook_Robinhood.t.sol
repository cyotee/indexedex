// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.sol";

/**
 * @notice FK Robinhood 4663: createSelectFork when RH RPC/ALCHEMY present; else honest skip + hermetic smoke.
 */
contract UniswapV4StandardExchangeCurveQuadStableBufferHook_Robinhood is
    TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook
{
    bool internal forked;

    function setUp() public override {
        string memory rpc = vm.envOr("FOUNDRY_ROBINHOOD_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            string memory key = vm.envOr("ALCHEMY_KEY", string(""));
            if (bytes(key).length > 0) {
                // foundry.toml may alias robinhood; use public endpoint when no alchemy RH
                rpc = vm.envOr("ROBINHOOD_RPC_URL", string("https://rpc.chain.robinhood.com"));
            }
        }
        if (bytes(rpc).length == 0) {
            super.setUp();
            return;
        }
        try vm.createSelectFork(rpc) {
            forked = true;
        } catch {
            emit log("FK rh4663: createSelectFork failed - hermetic smoke");
            forked = false;
        }
        super.setUp();
    }

    function test_FK_robinhood_smoke_orRecordSkip() public {
        if (!forked) {
            emit log("FK rh4663 skip/unavailable: ROBINHOOD RPC unset or fork failed");
        } else {
            emit log("FK rh4663: live fork active");
        }
        _smokeDeployMintSwapSingle();
    }
}
