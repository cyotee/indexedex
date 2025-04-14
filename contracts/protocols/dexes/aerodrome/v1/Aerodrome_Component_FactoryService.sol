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
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IRouter} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IRouter.sol";
import {IPoolFactory} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPoolFactory.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {
    AerodromeStandardExchangeInFacet
} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeInFacet.sol";
import {
    AerodromeStandardExchangeOutFacet
} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeOutFacet.sol";
import {
    IAerodromeStandardExchangeDFPkg,
    AerodromeStandardExchangeDFPkg
} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

library Aerodrome_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployAerodromeStandardExchangeInFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(AerodromeStandardExchangeInFacet).creationCode,
            abi.encode(type(AerodromeStandardExchangeInFacet).name)._hash()
        );
        vm.label(address(instance), type(AerodromeStandardExchangeInFacet).name);
    }

    function deployAerodromeStandardExchangeOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(AerodromeStandardExchangeOutFacet).creationCode,
            abi.encode(type(AerodromeStandardExchangeOutFacet).name)._hash()
        );
        vm.label(address(instance), type(AerodromeStandardExchangeOutFacet).name);
    }

    function deployAerodromeStandardExchangeDFPkg(
        IVaultRegistryDeployment vaultRegistry,
        IAerodromeStandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (IAerodromeStandardExchangeDFPkg instance) {
        instance = IAerodromeStandardExchangeDFPkg(
            address(
                vaultRegistry.deployPkg(
                    type(AerodromeStandardExchangeDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(AerodromeStandardExchangeDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(AerodromeStandardExchangeDFPkg).name);
    }

    struct DeployDFPkgParams {
        IVaultRegistryDeployment vaultRegistry;
        IFacet erc20Facet;
        IFacet erc2612Facet;
        IFacet erc5267Facet;
        IFacet erc4626Facet;
        IFacet erc4626BasicVaultFacet;
        IFacet erc4626StandardVaultFacet;
        IFacet aerodromeStandardExchangeInFacet;
        IFacet aerodromeStandardExchangeOutFacet;
        IVaultFeeOracleQuery vaultFeeOracleQuery;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IPermit2 permit2;
        IRouter aerodromeRouter;
        IPoolFactory aerodromePoolFactory;
    }

    function deployAerodromeStandardExchangeDFPkg(
        IVaultRegistryDeployment vaultRegistry,
        IFacet erc20Facet,
        IFacet erc2612Facet,
        IFacet erc5267Facet,
        IFacet erc4626Facet,
        IFacet erc4626BasicVaultFacet,
        IFacet erc4626StandardVaultFacet,
        IFacet aerodromeStandardExchangeInFacet,
        IFacet aerodromeStandardExchangeOutFacet,
        IVaultFeeOracleQuery vaultFeeOracleQuery,
        IVaultRegistryDeployment vaultRegistryDeployment,
        IPermit2 permit2,
        IRouter aerodromeRouter,
        IPoolFactory aerodromePoolFactory
    ) internal returns (IAerodromeStandardExchangeDFPkg instance) {
        DeployDFPkgParams memory params;
        params.vaultRegistry = vaultRegistry;
        params.erc20Facet = erc20Facet;
        params.erc2612Facet = erc2612Facet;
        params.erc5267Facet = erc5267Facet;
        params.erc4626Facet = erc4626Facet;
        params.erc4626BasicVaultFacet = erc4626BasicVaultFacet;
        params.erc4626StandardVaultFacet = erc4626StandardVaultFacet;
        params.aerodromeStandardExchangeInFacet = aerodromeStandardExchangeInFacet;
        params.aerodromeStandardExchangeOutFacet = aerodromeStandardExchangeOutFacet;
        params.vaultFeeOracleQuery = vaultFeeOracleQuery;
        params.vaultRegistryDeployment = vaultRegistryDeployment;
        params.permit2 = permit2;
        params.aerodromeRouter = aerodromeRouter;
        params.aerodromePoolFactory = aerodromePoolFactory;
        return _deployDFPkgFromParams(params);
    }

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
        pkgInit.erc4626BasicVaultFacet = params.erc4626BasicVaultFacet;
        pkgInit.erc4626StandardVaultFacet = params.erc4626StandardVaultFacet;
        pkgInit.aerodromeStandardExchangeInFacet = params.aerodromeStandardExchangeInFacet;
        pkgInit.aerodromeStandardExchangeOutFacet = params.aerodromeStandardExchangeOutFacet;
        pkgInit.vaultFeeOracleQuery = params.vaultFeeOracleQuery;
        pkgInit.vaultRegistryDeployment = params.vaultRegistryDeployment;
        pkgInit.permit2 = params.permit2;
        pkgInit.aerodromeRouter = params.aerodromeRouter;
        pkgInit.aerodromePoolFactory = params.aerodromePoolFactory;
        return deployAerodromeStandardExchangeDFPkg(vaultRegistry_, pkgInit);
    }
}
