// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IFacetRegistry} from "@crane/contracts/interfaces/IFacetRegistry.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC8109Introspection} from "@crane/contracts/interfaces/IERC8109Introspection.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IUniswapV4HookDiamondPackageCallBackFactory
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    UniswapV4HookDiamondPackageCallBackFactory_FactoryService as HookFactoryService
} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol";

/// @title Script_03_DeployHookDiamondFactory
/// @notice Deploy Uni V4 hook diamond package factory and pin on IndexedexManager.
contract Script_03_DeployHookDiamondFactory is DeploymentBase {
    using HookFactoryService for ICreate3FactoryProxy;

    string internal constant CRANE_FOUNDATION_FILE = "01_crane_foundation.json";
    string internal constant CORE_FILE = "02_indexedex_core.json";
    string internal constant ARTIFACT_FILE = "03_hook_factory.json";

    ICreate3FactoryProxy private create3Factory;
    address private indexedexManager;
    IUniswapV4HookDiamondPackageCallBackFactory private hookFactory;
    IFacet private hookFlagsFacet;

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        RobinhoodCanonicalLib.requireCanonicalPins();
        _loadPrior();
        _logHeader("Stage 03: Deploy Hook Diamond Factory");

        if (_loadExisting()) {
            _exportJson();
            _logResults();
            return;
        }

        vm.startBroadcast();
        hookFlagsFacet = HookFactoryService.deployUniswapV4HookFlagsFacet(create3Factory);
        IFacetRegistry facetReg = IFacetRegistry(address(create3Factory));
        hookFactory = HookFactoryService.deployUniswapV4HookDiamondPackageCallBackFactory(
            create3Factory,
            IUniswapV4HookDiamondPackageCallBackFactory.InitArgs({
                erc165Facet: facetReg.canonicalFacet(type(IERC165).interfaceId),
                diamondLoupeFacet: facetReg.canonicalFacet(type(IDiamondLoupe).interfaceId),
                erc8109IntrospectionFacet: facetReg.canonicalFacet(type(IERC8109Introspection).interfaceId),
                postDeployHookFacet: facetReg.canonicalFacet(type(IPostDeployAccountHook).interfaceId),
                hookFlagsFacet: hookFlagsFacet
            })
        );
        IVaultRegistryDeployment(indexedexManager).setHookDiamondPackageFactory(address(hookFactory));
        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPrior() internal {
        create3Factory = ICreate3FactoryProxy(_readAddress(CRANE_FOUNDATION_FILE, "create3Factory"));
        indexedexManager = _readAddress(CORE_FILE, "indexedexManager");
        require(address(create3Factory) != address(0), "missing create3Factory");
        require(indexedexManager != address(0), "missing indexedexManager");
    }

    function _loadExisting() internal returns (bool) {
        (address hf, bool ok) = _readAddressSafe(ARTIFACT_FILE, "hookFactory");
        if (!ok || hf.code.length == 0) return false;
        hookFactory = IUniswapV4HookDiamondPackageCallBackFactory(hf);
        (address flags, bool okFlags) = _readAddressSafe(ARTIFACT_FILE, "hookFlagsFacet");
        if (okFlags) hookFlagsFacet = IFacet(flags);
        return true;
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("hookFactory", "hookFactory", address(hookFactory));
        json = vm.serializeAddress("hookFactory", "hookFlagsFacet", address(hookFlagsFacet));
        json = vm.serializeAddress("hookFactory", "poolManager", RobinhoodCanonicalLib.poolManager());
        json = vm.serializeAddress("hookFactory", "indexedexManager", indexedexManager);
        json = vm.serializeUint("hookFactory", "chainId", block.chainid);
        _writeJson(json, ARTIFACT_FILE);
    }

    function _logResults() internal view {
        _logAddress("HookFactory:", address(hookFactory));
        _logComplete("Stage 03");
    }
}
