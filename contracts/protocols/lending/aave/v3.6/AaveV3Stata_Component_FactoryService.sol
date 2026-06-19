// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                   Foundry                                  */
/* -------------------------------------------------------------------------- */

import {Vm} from "forge-std/Vm.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IStataTokenFactory} from "@crane/contracts/protocols/lending/aave/v3.6/extensions/stata-token/interfaces/IStataTokenFactory.sol";
import {
    AaveV3StataStandardExchangeInFacet
} from "contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeInFacet.sol";
import {
    AaveV3StataStandardExchangeOutFacet
} from "contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeOutFacet.sol";
import {
    AaveV3StataMarkerFacet
} from "contracts/protocols/lending/aave/v3.6/AaveV3StataMarkerFacet.sol";
import {
    IAaveV3StataStandardExchangeDFPkg,
    AaveV3StataStandardExchangeDFPkg
} from "contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeDFPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

library AaveV3Stata_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployAaveV3StataStandardExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(AaveV3StataStandardExchangeInFacet).creationCode,
            abi.encode(type(AaveV3StataStandardExchangeInFacet).name)._hash()
        );
        vm.label(address(instance), type(AaveV3StataStandardExchangeInFacet).name);
    }

    function deployAaveV3StataStandardExchangeOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(AaveV3StataStandardExchangeOutFacet).creationCode,
            abi.encode(type(AaveV3StataStandardExchangeOutFacet).name)._hash()
        );
        vm.label(address(instance), type(AaveV3StataStandardExchangeOutFacet).name);
    }

    function deployAaveV3StataMarkerFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(AaveV3StataMarkerFacet).creationCode,
            abi.encode(type(AaveV3StataMarkerFacet).name)._hash()
        );
        vm.label(address(instance), type(AaveV3StataMarkerFacet).name);
    }

    function deployAaveV3StataStandardExchangeDFPkgFromVaultRegistry(
        IVaultRegistryDeployment vaultRegistry,
        IAaveV3StataStandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (IAaveV3StataStandardExchangeDFPkg instance) {
        instance = IAaveV3StataStandardExchangeDFPkg(
            address(
                vaultRegistry.deployPkg(
                    type(AaveV3StataStandardExchangeDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(AaveV3StataStandardExchangeDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(AaveV3StataStandardExchangeDFPkg).name);
    }

    function deployAaveV3StataStandardExchangeDFPkg(
        IIndexedexManagerProxy indexedexManager,
        IAaveV3StataStandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (IAaveV3StataStandardExchangeDFPkg instance) {
        return deployAaveV3StataStandardExchangeDFPkgFromVaultRegistry(
            IVaultRegistryDeployment(address(indexedexManager)),
            pkgInit
        );
    }

    function buildAaveV3StataPkgInit(
        IFacet erc20Facet,
        IFacet erc2612Facet,
        IFacet erc5267Facet,
        IFacet erc4626Facet,
        IFacet erc4626StandardVaultFacet,
        IFacet multiAssetBasicVaultFacet,
        IFacet multiAssetStandardVaultFacet,
        IFacet aaveV3StataStandardExchangeInFacet,
        IFacet aaveV3StataStandardExchangeOutFacet,
        IFacet aaveV3StataMarkerFacet,
        IVaultFeeOracleQuery vaultFeeOracleQuery,
        IVaultRegistryDeployment vaultRegistryDeployment,
        IPermit2 permit2,
        IStataTokenFactory stataTokenFactory
    ) internal pure returns (IAaveV3StataStandardExchangeDFPkg.PkgInit memory pkgInit) {
        pkgInit.erc20Facet = erc20Facet;
        pkgInit.erc2612Facet = erc2612Facet;
        pkgInit.erc5267Facet = erc5267Facet;
        pkgInit.erc4626Facet = erc4626Facet;
        pkgInit.erc4626StandardVaultFacet = erc4626StandardVaultFacet;
        pkgInit.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        pkgInit.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        pkgInit.aaveV3StataStandardExchangeInFacet = aaveV3StataStandardExchangeInFacet;
        pkgInit.aaveV3StataStandardExchangeOutFacet = aaveV3StataStandardExchangeOutFacet;
        pkgInit.aaveV3StataMarkerFacet = aaveV3StataMarkerFacet;
        pkgInit.vaultFeeOracleQuery = vaultFeeOracleQuery;
        pkgInit.vaultRegistryDeployment = vaultRegistryDeployment;
        pkgInit.permit2 = permit2;
        pkgInit.stataTokenFactory = stataTokenFactory;
    }
}
