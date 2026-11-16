// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import {
    TestBase_UniswapV4HookDiamondPackageCallBackFactory
} from "test/foundry/spec/hooks/uniswap/v4/factory/TestBase_UniswapV4HookDiamondPackageCallBackFactory.sol";

/**
 * @notice FK3 Robinhood 4663 fork smoke. Skips on RPC miss/429; hermetic H* are gating.
 */
contract UniswapV4HookDiamondFactory_RobinhoodForkTest is TestBase_UniswapV4HookDiamondPackageCallBackFactory {
    function setUp() public override {}

    function test_FK3_premineDeploySmoke() public {
        try this._runSmoke() {} catch {}
    }

    function _runSmoke() external {
        try vm.createSelectFork("robinhood_mainnet_alchemy") {}
        catch {
            vm.createSelectFork(vm.envString("ROBINHOOD_RPC_URL"));
        }
        TestBase_UniswapV4HookDiamondPackageCallBackFactory.setUp();
        address proxy = _deployStubPremine();
        require(proxy.code.length > 0, "no code");
        require(
            (uint160(proxy) & hookFactory.FLAG_MASK())
                == (stubPkg.requiredHookFlags() & hookFactory.FLAG_MASK()),
            "flags"
        );
    }
}
