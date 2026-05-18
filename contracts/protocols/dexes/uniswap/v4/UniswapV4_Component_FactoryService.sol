// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {UniswapV4StandardExchangeInFacet} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet.sol";
import {UniswapV4StandardExchangeOutFacet} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutFacet.sol";
import {
    IUniswapV4StandardExchangeDFPkg,
    UniswapV4StandardExchangeDFPkg
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";

library UniswapV4_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniswapV4StandardExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV4StandardExchangeInFacet).creationCode,
            abi.encode(type(UniswapV4StandardExchangeInFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV4StandardExchangeInFacet).name);
    }

    function deployUniswapV4StandardExchangeOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV4StandardExchangeOutFacet).creationCode,
            abi.encode(type(UniswapV4StandardExchangeOutFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV4StandardExchangeOutFacet).name);
    }

    function deployUniswapV4StandardExchangeDFPkgFromVaultRegistry(
        IVaultRegistryDeployment vaultRegistry,
        IUniswapV4StandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (IUniswapV4StandardExchangeDFPkg instance) {
        instance = IUniswapV4StandardExchangeDFPkg(
            address(
                vaultRegistry.deployPkg(
                    type(UniswapV4StandardExchangeDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(UniswapV4StandardExchangeDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(UniswapV4StandardExchangeDFPkg).name);
    }

    function buildArgsUniswapV4StandardExchangePkgInit(
        IFacet erc20Facet,
        IFacet erc5267Facet,
        IFacet erc2612Facet,
        IFacet multiAssetBasicVaultFacet,
        IFacet multiAssetStandardVaultFacet,
        IFacet uniswapV4StandardExchangeInFacet,
        IFacet uniswapV4StandardExchangeOutFacet,
        IVaultFeeOracleQuery vaultFeeOracleQuery,
        IVaultRegistryDeployment vaultRegistryDeployment,
        IPermit2 permit2,
        IPoolManager poolManager
    ) internal pure returns (IUniswapV4StandardExchangeDFPkg.PkgInit memory pkgInit) {
        pkgInit.erc20Facet = erc20Facet;
        pkgInit.erc5267Facet = erc5267Facet;
        pkgInit.erc2612Facet = erc2612Facet;
        pkgInit.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        pkgInit.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        pkgInit.uniswapV4StandardExchangeInFacet = uniswapV4StandardExchangeInFacet;
        pkgInit.uniswapV4StandardExchangeOutFacet = uniswapV4StandardExchangeOutFacet;
        pkgInit.vaultFeeOracleQuery = vaultFeeOracleQuery;
        pkgInit.vaultRegistryDeployment = vaultRegistryDeployment;
        pkgInit.permit2 = permit2;
        pkgInit.poolManager = poolManager;
    }

    function deployUniswapV4StandardExchangeDFPkg(
        IIndexedexManagerProxy indexedexManager,
        IUniswapV4StandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (IUniswapV4StandardExchangeDFPkg instance) {
        return deployUniswapV4StandardExchangeDFPkgFromVaultRegistry(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
    }
}