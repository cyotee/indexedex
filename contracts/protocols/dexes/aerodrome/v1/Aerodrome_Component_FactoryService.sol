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
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IRouter} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IRouter.sol";
import {IPoolFactory} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPoolFactory.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IAerodromeStandardExchangeDFPkg} from "contracts/protocols/dexes/aerodrome/v1/IAerodromeStandardExchangeDFPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

library Aerodrome_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployAerodromeStandardExchangeInFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        bytes memory code = ArtifactCreationCode.creationCode("AerodromeStandardExchangeInFacet.sol:AerodromeStandardExchangeInFacet");
        bytes32 releaseSalt = keccak256(abi.encode("AerodromeStandardExchangeInFacet", keccak256(code)));
        instance = create3Factory.deployFacet(code, releaseSalt);
        vm.label(address(instance), "AerodromeStandardExchangeInFacet");
    }

    function deployAerodromeStandardExchangeOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory code = ArtifactCreationCode.creationCode("AerodromeStandardExchangeOutFacet.sol:AerodromeStandardExchangeOutFacet");
        bytes32 releaseSalt = keccak256(abi.encode("AerodromeStandardExchangeOutFacet", keccak256(code)));
        instance = create3Factory.deployFacet(code, releaseSalt);
        vm.label(address(instance), "AerodromeStandardExchangeOutFacet");
    }

    function deployAerodromeStandardExchangeOutQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory code = ArtifactCreationCode.creationCode("AerodromeStandardExchangeOutQueryFacet.sol:AerodromeStandardExchangeOutQueryFacet");
        bytes32 releaseSalt = keccak256(abi.encode("AerodromeStandardExchangeOutQueryFacet", keccak256(code)));
        instance = create3Factory.deployFacet(code, releaseSalt);
        vm.label(address(instance), "AerodromeStandardExchangeOutQueryFacet");
    }

    function deployAerodromeStandardExchangeDFPkg(
        IVaultRegistryDeployment vaultRegistry,
        IAerodromeStandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (IAerodromeStandardExchangeDFPkg instance) {
        bytes memory code = ArtifactCreationCode.creationCode("AerodromeStandardExchangeDFPkg.sol:AerodromeStandardExchangeDFPkg");
        bytes memory arguments = abi.encode(pkgInit);
        bytes32 releaseSalt = keccak256(abi.encode("AerodromeStandardExchangeDFPkg", keccak256(code), keccak256(arguments)));
        instance = IAerodromeStandardExchangeDFPkg(address(vaultRegistry.deployPkg(code, arguments, releaseSalt)));
        vm.label(address(instance), "AerodromeStandardExchangeDFPkg");
    }

    struct DeployDFPkgParams {
        IVaultRegistryDeployment vaultRegistry;
        IFacet erc20Facet;
        IFacet erc2612Facet;
        IFacet erc5267Facet;
        IFacet erc4626Facet;
        // IFacet erc4626BasicVaultFacet;
        IFacet multiAssetBasicVaultFacet;
        // IFacet erc4626StandardVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet aerodromeStandardExchangeInFacet;
        IFacet aerodromeStandardExchangeOutFacet;
        IFacet aerodromeStandardExchangeOutQueryFacet;
        IVaultFeeOracleQuery vaultFeeOracleQuery;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IPermit2 permit2;
        IRouter aerodromeRouter;
        IPoolFactory aerodromePoolFactory;
    }

    // Positional multi-arg deploy removed (stack-too-deep with outQuery; use PkgInit overload).

    function _deployDFPkgFromParams(DeployDFPkgParams memory params)
        private
        returns (IAerodromeStandardExchangeDFPkg instance)
    {
        // Cache vaultRegistry before building pkgInit to reduce stack pressure
        IVaultRegistryDeployment vaultRegistry_ = params.vaultRegistry;

        IAerodromeStandardExchangeDFPkg.PkgInit memory pkgInit;
        pkgInit.erc20Facet = params.erc20Facet;
        pkgInit.erc2612Facet = params.erc2612Facet;
        pkgInit.erc5267Facet = params.erc5267Facet;
        pkgInit.erc4626Facet = params.erc4626Facet;
        // pkgInit.erc4626BasicVaultFacet = params.erc4626BasicVaultFacet;
        pkgInit.multiAssetBasicVaultFacet = params.multiAssetBasicVaultFacet;
        // pkgInit.erc4626StandardVaultFacet = params.erc4626StandardVaultFacet;
        pkgInit.multiAssetStandardVaultFacet = params.multiAssetStandardVaultFacet;
        pkgInit.aerodromeStandardExchangeInFacet = params.aerodromeStandardExchangeInFacet;
        pkgInit.aerodromeStandardExchangeOutFacet = params.aerodromeStandardExchangeOutFacet;
        pkgInit.aerodromeStandardExchangeOutQueryFacet = params.aerodromeStandardExchangeOutQueryFacet;
        pkgInit.vaultFeeOracleQuery = params.vaultFeeOracleQuery;
        pkgInit.vaultRegistryDeployment = params.vaultRegistryDeployment;
        pkgInit.permit2 = params.permit2;
        pkgInit.aerodromeRouter = params.aerodromeRouter;
        pkgInit.aerodromePoolFactory = params.aerodromePoolFactory;
        return deployAerodromeStandardExchangeDFPkg(vaultRegistry_, pkgInit);
    }
}
