// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {
    UniswapV3StandardExchangeInFacet
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeInFacet.sol";
import {
    UniswapV3StandardExchangeInQueryFacet
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeInQueryFacet.sol";
import {
    UniswapV3StandardExchangeOutFacet
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeOutFacet.sol";
import {
    UniswapV3StandardExchangePositionImportFacet
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangePositionImportFacet.sol";
import {
    IUniswapV3StandardExchangeDFPkg,
    UniswapV3StandardExchangeDFPkg
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeDFPkg.sol";

library UniswapV3_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniswapV3StandardExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV3StandardExchangeInFacet).creationCode,
            abi.encode(type(UniswapV3StandardExchangeInFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV3StandardExchangeInFacet).name);
    }

    function deployUniswapV3StandardExchangeInQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV3StandardExchangeInQueryFacet).creationCode,
            abi.encode(type(UniswapV3StandardExchangeInQueryFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV3StandardExchangeInQueryFacet).name);
    }

    function deployUniswapV3StandardExchangeOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV3StandardExchangeOutFacet).creationCode,
            abi.encode(type(UniswapV3StandardExchangeOutFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV3StandardExchangeOutFacet).name);
    }

    function deployUniswapV3StandardExchangePositionImportFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV3StandardExchangePositionImportFacet).creationCode,
            abi.encode(type(UniswapV3StandardExchangePositionImportFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV3StandardExchangePositionImportFacet).name);
    }

    function deployUniswapV3StandardExchangeDFPkgFromVaultRegistry(
        IVaultRegistryDeployment vaultRegistry,
        IUniswapV3StandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (IUniswapV3StandardExchangeDFPkg instance) {
        instance = IUniswapV3StandardExchangeDFPkg(
            address(
                vaultRegistry.deployPkg(
                    type(UniswapV3StandardExchangeDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(UniswapV3StandardExchangeDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(UniswapV3StandardExchangeDFPkg).name);
    }

    function buildArgsUniswapV3StandardExchangePkgInit(
        IFacet erc20Facet,
        IFacet erc5267Facet,
        IFacet erc2612Facet,
        IFacet multiAssetBasicVaultFacet,
        IFacet multiAssetStandardVaultFacet,
        IFacet uniswapV3StandardExchangeInFacet,
        IFacet uniswapV3StandardExchangeInQueryFacet,
        IFacet uniswapV3StandardExchangeOutFacet,
        IFacet uniswapV3StandardExchangePositionImportFacet,
        IVaultFeeOracleQuery vaultFeeOracleQuery,
        IVaultRegistryDeployment vaultRegistryDeployment,
        IPermit2 permit2,
        IUniswapV3Factory uniswapV3Factory
    ) internal pure returns (IUniswapV3StandardExchangeDFPkg.PkgInit memory pkgInit) {
        pkgInit.erc20Facet = erc20Facet;
        pkgInit.erc5267Facet = erc5267Facet;
        pkgInit.erc2612Facet = erc2612Facet;
        pkgInit.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        pkgInit.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        pkgInit.uniswapV3StandardExchangeInFacet = uniswapV3StandardExchangeInFacet;
        pkgInit.uniswapV3StandardExchangeInQueryFacet = uniswapV3StandardExchangeInQueryFacet;
        pkgInit.uniswapV3StandardExchangeOutFacet = uniswapV3StandardExchangeOutFacet;
        pkgInit.uniswapV3StandardExchangePositionImportFacet = uniswapV3StandardExchangePositionImportFacet;
        pkgInit.vaultFeeOracleQuery = vaultFeeOracleQuery;
        pkgInit.vaultRegistryDeployment = vaultRegistryDeployment;
        pkgInit.permit2 = permit2;
        pkgInit.uniswapV3Factory = uniswapV3Factory;
    }

    function deployUniswapV3StandardExchangeDFPkg(
        IIndexedexManagerProxy indexedexManager,
        IUniswapV3StandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (IUniswapV3StandardExchangeDFPkg instance) {
        return deployUniswapV3StandardExchangeDFPkgFromVaultRegistry(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
    }
}
