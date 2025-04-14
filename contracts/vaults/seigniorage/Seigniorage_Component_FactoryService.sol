// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                   Foundry                                  */
/* -------------------------------------------------------------------------- */

import {Vm} from "forge-std/Vm.sol";

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IRouter} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRouter.sol";
import {IVault as IBalancerVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IWeightedPool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {
    IERC20PermitMintBurnLockedOwnableDFPkg
} from "@crane/contracts/tokens/ERC20/ERC20PermitMintBurnLockedOwnableDFPkg.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {
    IWeightedPool8020Factory
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool8020Factory.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {ISeigniorageNFTVault} from "contracts/interfaces/ISeigniorageNFTVault.sol";
import {ISeigniorageDETF} from "contracts/interfaces/ISeigniorageDETF.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {
    IStandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/StandardExchangeRateProviderDFPkg.sol";
import {SeigniorageDETFExchangeInFacet} from "contracts/vaults/seigniorage/SeigniorageDETFExchangeInFacet.sol";
import {SeigniorageDETFExchangeOutFacet} from "contracts/vaults/seigniorage/SeigniorageDETFExchangeOutFacet.sol";
import {SeigniorageDETFUnderwritingFacet} from "contracts/vaults/seigniorage/SeigniorageDETFUnderwritingFacet.sol";
import {SeigniorageNFTVaultFacet} from "contracts/vaults/seigniorage/SeigniorageNFTVaultFacet.sol";
import {ERC4626BasedBasicVaultFacet} from "contracts/vaults/basic/ERC4626BasedBasicVaultFacet.sol";
import {ERC4626StandardVaultFacet} from "contracts/vaults/standard/ERC4626StandardVaultFacet.sol";
import {ISeigniorageDETFDFPkg, SeigniorageDETFDFPkg} from "contracts/vaults/seigniorage/SeigniorageDETFDFPkg.sol";
import {
    ISeigniorageNFTVaultDFPkg,
    SeigniorageNFTVaultDFPkg
} from "contracts/vaults/seigniorage/SeigniorageNFTVaultDFPkg.sol";

/**
 * @title Seigniorage_Component_FactoryService
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Factory service for deploying Seigniorage vault components via CREATE3.
 * @dev Provides deterministic deployment of facets and packages.
 */
library Seigniorage_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    /* ---------------------------------------------------------------------- */
    /*                              Facet Deployment                          */
    /* ---------------------------------------------------------------------- */

    function deploySeigniorageDETFExchangeInFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(SeigniorageDETFExchangeInFacet).creationCode,
            abi.encode(type(SeigniorageDETFExchangeInFacet).name)._hash()
        );
        vm.label(address(instance), type(SeigniorageDETFExchangeInFacet).name);
    }

    function deploySeigniorageDETFExchangeOutFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(SeigniorageDETFExchangeOutFacet).creationCode,
            abi.encode(type(SeigniorageDETFExchangeOutFacet).name)._hash()
        );
        vm.label(address(instance), type(SeigniorageDETFExchangeOutFacet).name);
    }

    function deploySeigniorageDETFUnderwritingFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(SeigniorageDETFUnderwritingFacet).creationCode,
            abi.encode(type(SeigniorageDETFUnderwritingFacet).name)._hash()
        );
        vm.label(address(instance), type(SeigniorageDETFUnderwritingFacet).name);
    }

    function deploySeigniorageNFTVaultFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(SeigniorageNFTVaultFacet).creationCode, abi.encode(type(SeigniorageNFTVaultFacet).name)._hash()
        );
        vm.label(address(instance), type(SeigniorageNFTVaultFacet).name);
    }

    function deployERC4626BasedBasicVaultFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(ERC4626BasedBasicVaultFacet).creationCode, abi.encode(type(ERC4626BasedBasicVaultFacet).name)._hash()
        );
        vm.label(address(instance), type(ERC4626BasedBasicVaultFacet).name);
    }

    function deployERC4626StandardVaultFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(ERC4626StandardVaultFacet).creationCode, abi.encode(type(ERC4626StandardVaultFacet).name)._hash()
        );
        vm.label(address(instance), type(ERC4626StandardVaultFacet).name);
    }

    /* ---------------------------------------------------------------------- */
    /*                            Package Deployment                          */
    /* ---------------------------------------------------------------------- */

    function deploySeigniorageDETFDFPkg(
        IVaultRegistryDeployment vaultRegistry,
        ISeigniorageDETFDFPkg.PkgInit memory pkgInit
    ) internal returns (ISeigniorageDETFDFPkg instance) {
        instance = ISeigniorageDETFDFPkg(
            address(
                vaultRegistry.deployPkg(
                    type(SeigniorageDETFDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(SeigniorageDETFDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(SeigniorageDETFDFPkg).name);
    }

    function deploySeigniorageNFTVaultDFPkg(
        IVaultRegistryDeployment vaultRegistry,
        ISeigniorageNFTVaultDFPkg.PkgInit memory pkgInit
    ) internal returns (ISeigniorageNFTVaultDFPkg instance) {
        instance = ISeigniorageNFTVaultDFPkg(
            address(
                vaultRegistry.deployPkg(
                    type(SeigniorageNFTVaultDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(SeigniorageNFTVaultDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(SeigniorageNFTVaultDFPkg).name);
    }

    /* ---------------------------------------------------------------------- */
    /*                          Helper Functions                              */
    /* ---------------------------------------------------------------------- */

    struct SeigniorageDETFPkgInitParams {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet erc4626BasicVaultFacet;
        IFacet erc4626StandardVaultFacet;
        IFacet seigniorageDETFExchangeInFacet;
        IFacet seigniorageDETFExchangeOutFacet;
        IFacet seigniorageDETFUnderwritingFacet;
        IVaultFeeOracleQuery feeOracle;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IPermit2 permit2;
        IBalancerVault balancerV3Vault;
        IRouter balancerV3Router;
        IBalancerV3StandardExchangeRouterPrepay balancerV3PrepayRouter;
        IWeightedPool8020Factory weightedPool8020Factory;
        IDiamondPackageCallBackFactory diamondFactory;
        IERC20PermitMintBurnLockedOwnableDFPkg seigniorageTokenPkg;
        ISeigniorageNFTVaultDFPkg seigniorageNFTVaultPkg;
        IStandardExchangeRateProviderDFPkg reserveVaultRateProviderPkg;
    }

    function buildSeigniorageDETFPkgInit(SeigniorageDETFPkgInitParams memory params)
        internal
        pure
        returns (ISeigniorageDETFDFPkg.PkgInit memory pkgInit)
    {
        // Use explicit field assignments to avoid stack-too-deep during struct literal codegen.
        pkgInit.erc20Facet = params.erc20Facet;
        pkgInit.erc5267Facet = params.erc5267Facet;
        pkgInit.erc2612Facet = params.erc2612Facet;
        pkgInit.erc4626BasicVaultFacet = params.erc4626BasicVaultFacet;
        pkgInit.erc4626StandardVaultFacet = params.erc4626StandardVaultFacet;
        pkgInit.seigniorageDETFExchangeInFacet = params.seigniorageDETFExchangeInFacet;
        pkgInit.seigniorageDETFExchangeOutFacet = params.seigniorageDETFExchangeOutFacet;
        pkgInit.seigniorageDETFUnderwritingFacet = params.seigniorageDETFUnderwritingFacet;
        pkgInit.feeOracle = params.feeOracle;
        pkgInit.vaultRegistryDeployment = params.vaultRegistryDeployment;
        pkgInit.permit2 = params.permit2;
        pkgInit.balancerV3Vault = params.balancerV3Vault;
        pkgInit.balancerV3Router = params.balancerV3Router;
        pkgInit.balancerV3PrepayRouter = params.balancerV3PrepayRouter;
        pkgInit.weightedPool8020Factory = params.weightedPool8020Factory;
        pkgInit.diamondFactory = params.diamondFactory;
        pkgInit.seigniorageTokenPkg = params.seigniorageTokenPkg;
        pkgInit.seigniorageNFTVaultPkg = params.seigniorageNFTVaultPkg;
        pkgInit.reserveVaultRateProviderPkg = params.reserveVaultRateProviderPkg;
    }

    function buildSeigniorageNFTVaultPkgInit(
        IFacet erc721Facet,
        IFacet erc4626BasicVaultFacet,
        IFacet erc4626StandardVaultFacet,
        IFacet seigniorageNFTVaultFacet,
        IVaultFeeOracleQuery feeOracle,
        IVaultRegistryDeployment vaultRegistryDeployment
    ) internal pure returns (ISeigniorageNFTVaultDFPkg.PkgInit memory pkgInit) {
        pkgInit = ISeigniorageNFTVaultDFPkg.PkgInit({
            erc721Facet: erc721Facet,
            erc4626BasicVaultFacet: erc4626BasicVaultFacet,
            erc4626StandardVaultFacet: erc4626StandardVaultFacet,
            seigniorageNFTVaultFacet: seigniorageNFTVaultFacet,
            feeOracle: feeOracle,
            vaultRegistryDeployment: vaultRegistryDeployment
        });
    }

    function buildSeigniorageDETFPkgArgs(
        string memory name,
        string memory symbol,
        IStandardExchangeProxy reserveVault,
        IERC20Metadata reserveVaultRateTarget
    ) internal pure returns (ISeigniorageDETFDFPkg.PkgArgs memory pkgArgs) {
        pkgArgs = ISeigniorageDETFDFPkg.PkgArgs({
            name: name, symbol: symbol, reserveVault: reserveVault, reserveVaultRateTarget: reserveVaultRateTarget
        });
    }

    // NOTE: buildSeigniorageNFTVaultPkgArgs helper removed due to stack-depth limits.
    // Callers should construct ISeigniorageNFTVaultDFPkg.PkgArgs directly.
}
