// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IERC8109Introspection} from "@crane/contracts/interfaces/IERC8109Introspection.sol";
import {MinimalDiamondCallBackProxy} from "@crane/contracts/proxies/MinimalDiamondCallBackProxy.sol";

import {
    TestBase_UniswapV4HookDiamondPackageCallBackFactory
} from "test/foundry/spec/hooks/uniswap/v4/factory/TestBase_UniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    IUniswapV4HookFlags
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookFlags.sol";
import {
    IUniswapV4HookDiamondFactoryStubPackage
} from "test/foundry/spec/hooks/uniswap/v4/factory/stubs/IUniswapV4HookDiamondFactoryStubPackage.sol";
import {
    IUniswapV4HookDiamondPackageCallBackFactory
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    IUniswapV4HookDiamondPackage
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackage.sol";

contract UniswapV4HookDiamondFactory_DeployTest is TestBase_UniswapV4HookDiamondPackageCallBackFactory {
    /// H1: factory code at CREATE3 predicted address; immutables set
    function test_H1_factoryDeployedViaCreate3() public view {
        assertTrue(address(hookFactory).code.length > 0);
        assertTrue(address(hookFactory.ERC165_FACET()) != address(0));
        assertTrue(address(hookFactory.DIAMOND_LOUPE_FACET()) != address(0));
        assertTrue(address(hookFactory.ERC8109_INTROSPECTION_FACET()) != address(0));
        assertTrue(address(hookFactory.POST_DEPLOY_HOOK_FACET()) != address(0));
        assertTrue(address(hookFactory.HOOK_FLAGS_FACET()) != address(0));
    }

    /// H2: PROXY_INIT_HASH == keccak256(MinimalDiamondCallBackProxy.creationCode)
    function test_H2_proxyInitHash() public view {
        assertEq(
            hookFactory.PROXY_INIT_HASH(), keccak256(type(MinimalDiamondCallBackProxy).creationCode)
        );
    }

    /// H9: loupe has ERC165, Loupe, ERC8109, HookFlags
    function test_H9_baseFacetsOnProxy() public {
        address proxy = _deployStubPremine();
        IDiamondLoupe loupe = IDiamondLoupe(proxy);
        assertTrue(IERC165(proxy).supportsInterface(type(IERC165).interfaceId));
        assertTrue(IERC165(proxy).supportsInterface(type(IDiamondLoupe).interfaceId));
        assertTrue(IERC165(proxy).supportsInterface(type(IUniswapV4HookFlags).interfaceId));
        assertTrue(loupe.facetAddress(IDiamondLoupe.facets.selector) != address(0));
        assertTrue(loupe.facetAddress(IUniswapV4HookFlags.requiredHookFlags.selector) != address(0));
        assertTrue(loupe.facetAddress(IERC8109Introspection.functionFacetPairs.selector) != address(0));
    }

    /// H11: stub binding storage readable
    function test_H11_stubBindingReadable() public {
        address proxy = _deployStubPremine();
        assertEq(IUniswapV4HookDiamondFactoryStubPackage(proxy).bindingValue(), 42);
    }

    /// H14: event on first deploy only
    function test_H14_eventOnFirstDeployOnly() public {
        address predicted = hookFactory.calcAddress(
            IUniswapV4HookDiamondPackage(address(stubPkg)), stubArgs, stubMineNonce
        );
        bytes memory processed = stubPkg.processArgs(stubArgs);
        bytes32 packageSalt = stubPkg.calcSalt(processed);
        uint160 flags = stubPkg.requiredHookFlags() & hookFactory.FLAG_MASK();

        vm.recordLogs();
        address first = _deployStubPremine();
        assertEq(first, predicted);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic0 = keccak256("HookDiamondDeployed(address,address,bytes32,uint256,uint160)");
        bool found;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter == address(hookFactory) && logs[i].topics.length >= 3 && logs[i].topics[0] == topic0) {
                assertEq(address(uint160(uint256(logs[i].topics[1]))), first);
                assertEq(address(uint160(uint256(logs[i].topics[2]))), address(stubPkg));
                (bytes32 saltLogged, uint256 nonceLogged, uint160 flagsLogged) =
                    abi.decode(logs[i].data, (bytes32, uint256, uint160));
                assertEq(saltLogged, packageSalt);
                assertEq(nonceLogged, stubMineNonce);
                assertEq(flagsLogged, flags);
                found = true;
            }
        }
        assertTrue(found, "first deploy must emit HookDiamondDeployed");

        vm.recordLogs();
        address second = hookFactory.deployWithMineNonce(
            IUniswapV4HookDiamondPackage(address(stubPkg)), stubArgs, stubMineNonce
        );
        assertEq(first, second);
        logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter == address(hookFactory) && logs[i].topics.length > 0) {
                assertTrue(logs[i].topics[0] != topic0, "must not emit HookDiamondDeployed on idempotent path");
            }
        }
    }
}
