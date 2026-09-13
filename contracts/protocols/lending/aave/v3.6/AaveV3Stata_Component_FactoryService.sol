// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

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

import {IAaveV3StataStandardExchangeDFPkg} from "contracts/protocols/lending/aave/v3.6/IAaveV3StataStandardExchangeDFPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

library AaveV3Stata_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployAaveV3StataStandardExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory code = ArtifactCreationCode.creationCode("AaveV3StataStandardExchangeInFacet.sol:AaveV3StataStandardExchangeInFacet");
        instance = create3Factory.deployFacet(
            code, ArtifactCreationCode.releaseSalt(abi.encode("AaveV3StataStandardExchangeInFacet")._hash(), code, bytes(""))
        );
        vm.label(address(instance), "AaveV3StataStandardExchangeInFacet");
    }

    function deployAaveV3StataStandardExchangeOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory code = ArtifactCreationCode.creationCode("AaveV3StataStandardExchangeOutFacet.sol:AaveV3StataStandardExchangeOutFacet");
        instance = create3Factory.deployFacet(
            code, ArtifactCreationCode.releaseSalt(abi.encode("AaveV3StataStandardExchangeOutFacet")._hash(), code, bytes(""))
        );
        vm.label(address(instance), "AaveV3StataStandardExchangeOutFacet");
    }

    function deployAaveV3StataMarkerFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory code = ArtifactCreationCode.creationCode("AaveV3StataMarkerFacet.sol:AaveV3StataMarkerFacet");
        instance = create3Factory.deployFacet(
            code, ArtifactCreationCode.releaseSalt(abi.encode("AaveV3StataMarkerFacet")._hash(), code, bytes(""))
        );
        vm.label(address(instance), "AaveV3StataMarkerFacet");
    }

    function deployAaveV3StataStandardExchangeDFPkgFromVaultRegistry(
        IVaultRegistryDeployment vaultRegistry,
        IAaveV3StataStandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (IAaveV3StataStandardExchangeDFPkg instance) {
        bytes memory code = ArtifactCreationCode.creationCode("AaveV3StataStandardExchangeDFPkg.sol:AaveV3StataStandardExchangeDFPkg");
        bytes memory args = abi.encode(pkgInit);
        instance = IAaveV3StataStandardExchangeDFPkg(address(vaultRegistry.deployPkg(
            code, args, ArtifactCreationCode.releaseSalt(abi.encode("AaveV3StataStandardExchangeDFPkg")._hash(), code, args)
        )));
        vm.label(address(instance), "AaveV3StataStandardExchangeDFPkg");
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
