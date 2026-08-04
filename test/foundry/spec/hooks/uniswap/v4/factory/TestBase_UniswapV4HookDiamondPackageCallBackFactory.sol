// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacetRegistry} from "@crane/contracts/interfaces/IFacetRegistry.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC8109Introspection} from "@crane/contracts/interfaces/IERC8109Introspection.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";

import {
    IUniswapV4HookDiamondPackageCallBackFactory
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    IUniswapV4HookDiamondPackage
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackage.sol";
import {
    UniswapV4HookDiamondPackageCallBackFactory_FactoryService as HookFactoryService
} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol";
import {
    UniswapV4HookDiamondFactoryStubPackage
} from "test/foundry/spec/hooks/uniswap/v4/factory/stubs/UniswapV4HookDiamondFactoryStubPackage.sol";
import {
    IUniswapV4HookDiamondFactoryStubPackage
} from "test/foundry/spec/hooks/uniswap/v4/factory/stubs/IUniswapV4HookDiamondFactoryStubPackage.sol";
import {
    UniswapV4HookDiamondCreate2Lib as Create2Lib
} from "contracts/hooks/uniswap/v4/factory/libs/UniswapV4HookDiamondCreate2Lib.sol";

/**
 * @title TestBase_UniswapV4HookDiamondPackageCallBackFactory
 * @notice Gold TestBase: real CREATE3 factory + stub package + registry wiring.
 */
abstract contract TestBase_UniswapV4HookDiamondPackageCallBackFactory is IndexedexTest {
    using BetterEfficientHashLib for bytes;
    using HookFactoryService for ICreate3FactoryProxy;

    IUniswapV4HookDiamondPackageCallBackFactory internal hookFactory;
    IUniswapV4HookDiamondFactoryStubPackage internal stubPkg;
    bytes internal stubArgs;
    uint256 internal stubMineNonce;

    function setUp() public virtual override {
        IndexedexTest.setUp();

        IFacet hookFlagsFacet = HookFactoryService.deployUniswapV4HookFlagsFacet(create3Factory);

        IFacetRegistry registry = IFacetRegistry(address(create3Factory));
        hookFactory = HookFactoryService.deployUniswapV4HookDiamondPackageCallBackFactory(
            create3Factory,
            IUniswapV4HookDiamondPackageCallBackFactory.InitArgs({
                erc165Facet: registry.canonicalFacet(type(IERC165).interfaceId),
                diamondLoupeFacet: registry.canonicalFacet(type(IDiamondLoupe).interfaceId),
                erc8109IntrospectionFacet: registry.canonicalFacet(type(IERC8109Introspection).interfaceId),
                postDeployHookFacet: registry.canonicalFacet(type(IPostDeployAccountHook).interfaceId),
                hookFlagsFacet: hookFlagsFacet
            })
        );

        // Wire hook factory on manager (owner) for registry deployHookVault*.
        vm.prank(owner);
        IVaultRegistryDeployment(address(indexedexManager)).setHookDiamondPackageFactory(address(hookFactory));

        // Deploy stub package via CREATE3 with registry wired for package.deployVault → deployHookVault.
        stubPkg = IUniswapV4HookDiamondFactoryStubPackage(
            create3Factory.create3WithArgs(
                type(UniswapV4HookDiamondFactoryStubPackage).creationCode,
                abi.encode(IVaultRegistryDeployment(address(indexedexManager))),
                abi.encode(type(UniswapV4HookDiamondFactoryStubPackage).name)._hash()
            )
        );
        vm.label(address(stubPkg), "UniswapV4HookDiamondFactoryStubPackage");

        stubArgs = abi.encode(IUniswapV4HookDiamondFactoryStubPackage.PkgArgs({value: 42}));
        stubMineNonce = HookFactoryService.findMineNonce(
            hookFactory, IUniswapV4HookDiamondPackage(address(stubPkg)), stubArgs
        );
    }

    /// @dev Factory isolation path (no vault registry). Product path is package.deployVault.
    function _deployStubPremine() internal returns (address proxy) {
        proxy = hookFactory.deployWithMineNonce(
            IUniswapV4HookDiamondPackage(address(stubPkg)), stubArgs, stubMineNonce
        );
    }

    /// @dev Register a fresh stub package instance for package → registry → factory deploys.
    function _registerStubPkg(bytes32 salt) internal returns (IUniswapV4HookDiamondFactoryStubPackage registered) {
        vm.prank(owner);
        registered = IUniswapV4HookDiamondFactoryStubPackage(
            IVaultRegistryDeployment(address(indexedexManager)).deployPkg(
                type(UniswapV4HookDiamondFactoryStubPackage).creationCode,
                abi.encode(IVaultRegistryDeployment(address(indexedexManager))),
                salt
            )
        );
    }

    /// @dev Product path: package.deployVault → registry.deployHookVault → factory → register.
    function _deployStubViaPackage(IUniswapV4HookDiamondFactoryStubPackage pkg, uint256 value, uint256 mineNonce)
        internal
        returns (address vault)
    {
        vault = pkg.deployVault(IUniswapV4HookDiamondFactoryStubPackage.PkgArgs({value: value}), mineNonce);
    }
}
