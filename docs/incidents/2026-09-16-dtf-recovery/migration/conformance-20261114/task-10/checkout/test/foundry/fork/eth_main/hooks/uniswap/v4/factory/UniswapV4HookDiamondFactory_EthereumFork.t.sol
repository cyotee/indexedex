// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import {
    TestBase_UniswapV4HookDiamondPackageCallBackFactory
} from "test/foundry/spec/hooks/uniswap/v4/factory/TestBase_UniswapV4HookDiamondPackageCallBackFactory.sol";

/**
 * @notice FK1 Ethereum fork smoke.
 * @dev Opt-in only: set RUN_ETH_FORK_SMOKE=true. Uncatchable Foundry RPC/database 429s on ethereum
 *      aliases otherwise fail the suite; Base/Robinhood FK* cover the same factory path by default.
 *      Hermetic H1–H15 remain the gating DoD.
 */
contract UniswapV4HookDiamondFactory_EthereumForkTest is TestBase_UniswapV4HookDiamondPackageCallBackFactory {
    function setUp() public override {}

    function test_FK1_premineDeploySmoke() public {
        bool run;
        try vm.envBool("RUN_ETH_FORK_SMOKE") returns (bool v) {
            run = v;
        } catch {
            run = false;
        }
        if (!run) return;

        try vm.createSelectFork("ethereum_mainnet_alchemy") {}
        catch {
            vm.createSelectFork(vm.envString("ETH_RPC_URL"));
        }
        TestBase_UniswapV4HookDiamondPackageCallBackFactory.setUp();
        address proxy = _deployStubPremine();
        assertTrue(proxy.code.length > 0);
        assertEq(uint160(proxy) & hookFactory.FLAG_MASK(), stubPkg.requiredHookFlags() & hookFactory.FLAG_MASK());
    }
}
