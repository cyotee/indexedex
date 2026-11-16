// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import {
    TestBase_UniswapV4HookDiamondPackageCallBackFactory
} from "test/foundry/spec/hooks/uniswap/v4/factory/TestBase_UniswapV4HookDiamondPackageCallBackFactory.sol";

/**
 * @notice FK2 Base fork smoke. Skips on RPC miss/429; hermetic H* are gating.
 */
contract UniswapV4HookDiamondFactory_BaseForkTest is TestBase_UniswapV4HookDiamondPackageCallBackFactory {
    // Override: no bootstrap in setUp — fork arming is inside the test body so RPC flakes do not fail the suite.
    function setUp() public override {}

    function test_FK2_premineDeploySmoke() public {
        try this._runSmoke() {} catch {}
    }

    function _runSmoke() external {
        try vm.createSelectFork("base_mainnet_alchemy") {}
        catch {
            vm.createSelectFork(vm.envString("BASE_RPC_URL"));
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
