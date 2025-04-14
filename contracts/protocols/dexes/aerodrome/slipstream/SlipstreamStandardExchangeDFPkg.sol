// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondCut} from "@crane/contracts/interfaces/IDiamondCut.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {ICLFactory} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/ICLFactory.sol";
import {ICLPool} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/ICLPool.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";
import {
    VaultFeeType,
    VaultFeeTypeIds
} from "contracts/interfaces/VaultFeeTypes.sol";

/**
 * @title ISlipstreamStandardExchangeDFPkg - Interface for Slipstream Standard Exchange Diamond Factory Package.
 * @author cyotee doge <doge.cyotee>
 */
interface ISlipstreamStandardExchangeDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {

    error NotCalledByRegistry(address caller);

    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet slipstreamStandardExchangeInFacet;
        IFacet slipstreamStandardExchangeOutFacet;
        IVaultFeeOracleQuery vaultFeeOracleQuery;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IPermit2 permit2;
        ICLFactory slipstreamFactory;
    }

    struct PkgArgs {
        ICLPool pool;
        uint24 widthMultiplier;
    }

    function deployVault(ICLPool pool, uint24 widthMultiplier) external returns (address vault);
}

/**
 * @title SlipstreamStandardExchangeDFPkg - Diamond Factory Package for Slipstream Standard Exchange Vaults.
 * @author cyotee doge <doge.cyotee>
 * @notice Deploys vaults that wrap Slipstream concentrated liquidity positions.
 */
contract SlipstreamStandardExchangeDFPkg is ISlipstreamStandardExchangeDFPkg {
    using BetterEfficientHashLib for bytes;
    using BetterSafeERC20 for IERC20;

    IFacet immutable ERC20_FACET;
    IFacet immutable ERC5267_FACET;
    IFacet immutable ERC2612_FACET;
    IFacet immutable MULTI_ASSET_BASIC_VAULT_FACET;
    IFacet immutable MULTI_ASSET_STANDARD_VAULT_FACET;
    IFacet immutable SLIPSTREAM_EXCHANGE_IN_FACET;
    IFacet immutable SLIPSTREAM_EXCHANGE_OUT_FACET;
    IVaultFeeOracleQuery immutable VAULT_FEE_ORACLE_QUERY;
    IVaultRegistryDeployment immutable VAULT_REGISTRY_DEPLOYMENT;
    IPermit2 immutable PERMIT2;
    ICLFactory immutable SLIPSTREAM_FACTORY;

    constructor(PkgInit memory pkgInit) {
        ERC20_FACET = pkgInit.erc20Facet;
        ERC5267_FACET = pkgInit.erc5267Facet;
        ERC2612_FACET = pkgInit.erc2612Facet;
        MULTI_ASSET_BASIC_VAULT_FACET = pkgInit.multiAssetBasicVaultFacet;
        MULTI_ASSET_STANDARD_VAULT_FACET = pkgInit.multiAssetStandardVaultFacet;
        SLIPSTREAM_EXCHANGE_IN_FACET = pkgInit.slipstreamStandardExchangeInFacet;
        SLIPSTREAM_EXCHANGE_OUT_FACET = pkgInit.slipstreamStandardExchangeOutFacet;
        VAULT_FEE_ORACLE_QUERY = pkgInit.vaultFeeOracleQuery;
        VAULT_REGISTRY_DEPLOYMENT = pkgInit.vaultRegistryDeployment;
        PERMIT2 = pkgInit.permit2;
        SLIPSTREAM_FACTORY = pkgInit.slipstreamFactory;
    }

    /* -------------------------------------------------------------------------- */
    /*                            IStandardVaultPkg                                */
    /* -------------------------------------------------------------------------- */

    function name() public pure override returns (string memory) {
        return packageName();
    }

    function vaultFeeTypeIds() public pure override returns (bytes32 vaultFeeTypeIds_) {
        return VaultTypeUtils._insertFeeTypeId(vaultFeeTypeIds_, VaultFeeType.USAGE, type(IStandardVault).interfaceId);
    }

    function vaultTypes() public pure override returns (bytes4[] memory typeIDs) {
        return facetInterfaces();
    }

    function vaultDeclaration() public pure override returns (VaultPkgDeclaration memory declaration) {
        return VaultPkgDeclaration({name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()});
    }

    /* -------------------------------------------------------------------------- */
    /*                              IStandardVaultPkg helpers                     */
    /* -------------------------------------------------------------------------- */

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](7);
        interfaces[0] = type(IERC20).interfaceId;
        interfaces[1] = type(IERC20Metadata).interfaceId;
        // TODO Add XOR of IERC20 and IERC20Metadata.
        interfaces[2] = type(IERC5267).interfaceId;
        interfaces[3] = type(IERC20Permit).interfaceId;
        // TODO Add IBasicVault
        interfaces[4] = type(IStandardVault).interfaceId;
        interfaces[5] = type(IStandardExchangeIn).interfaceId;
        interfaces[6] = type(IStandardExchangeOut).interfaceId;
    }

    /* -------------------------------------------------------------------------- */
    /*                           IDiamondFactoryPackage                            */
    /* -------------------------------------------------------------------------- */

    function packageName() public pure override returns (string memory) {
        return type(SlipstreamStandardExchangeDFPkg).name;
    }

    function facetCuts() public view override returns (IDiamond.FacetCut[] memory facetCuts_) {
        facetCuts_ = new IDiamond.FacetCut[](7);

        facetCuts_[0] = IDiamond.FacetCut({
            facetAddress: address(ERC20_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC20_FACET.facetFuncs()
        });

        facetCuts_[1] = IDiamond.FacetCut({
            facetAddress: address(ERC5267_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC5267_FACET.facetFuncs()
        });

        facetCuts_[2] = IDiamond.FacetCut({
            facetAddress: address(ERC2612_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC2612_FACET.facetFuncs()
        });

        facetCuts_[3] = IDiamond.FacetCut({
            facetAddress: address(MULTI_ASSET_BASIC_VAULT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: MULTI_ASSET_BASIC_VAULT_FACET.facetFuncs()
        });

        facetCuts_[4] = IDiamond.FacetCut({
            facetAddress: address(MULTI_ASSET_STANDARD_VAULT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: MULTI_ASSET_STANDARD_VAULT_FACET.facetFuncs()
        });

        facetCuts_[5] = IDiamond.FacetCut({
            facetAddress: address(SLIPSTREAM_EXCHANGE_IN_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: SLIPSTREAM_EXCHANGE_IN_FACET.facetFuncs()
        });

        facetCuts_[6] = IDiamond.FacetCut({
            facetAddress: address(SLIPSTREAM_EXCHANGE_OUT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: SLIPSTREAM_EXCHANGE_OUT_FACET.facetFuncs()
        });
    }

    function diamondConfig() public view override returns (DiamondConfig memory config) {
        config = DiamondConfig({facetCuts: facetCuts(), interfaces: new bytes4[](0)});
    }

    function calcSalt(bytes memory pkgArgs) public pure override returns (bytes32) {
        return abi.encode(pkgArgs)._hash();
    }

    function initAccount(bytes memory) external pure override {
        // Initialize vault storage
    }

    function postDeploy(address) external pure override returns (bool) {
        return true;
    }

    /* -------------------------------------------------------------------------- */
    /*                      IDiamondFactoryPackage                                 */
    /* -------------------------------------------------------------------------- */

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](7);
        facetAddresses_[0] = address(ERC20_FACET);
        facetAddresses_[1] = address(ERC5267_FACET);
        facetAddresses_[2] = address(ERC2612_FACET);
        facetAddresses_[3] = address(MULTI_ASSET_BASIC_VAULT_FACET);
        facetAddresses_[4] = address(MULTI_ASSET_STANDARD_VAULT_FACET);
        facetAddresses_[5] = address(SLIPSTREAM_EXCHANGE_IN_FACET);
        facetAddresses_[6] = address(SLIPSTREAM_EXCHANGE_OUT_FACET);
        return facetAddresses_;
    }

    function packageMetadata()
        public
        view
        returns (string memory name_, bytes4[] memory interfaces, address[] memory facets)
    {
        name_ = packageName();
        interfaces = facetInterfaces();
        facets = facetAddresses();
    }

    function processArgs(bytes memory pkgArgs) public pure returns (bytes memory processedPkgArgs) {
        processedPkgArgs = pkgArgs;
    }

    function updatePkg(address, bytes memory) external pure returns (bool) {
        return true;
    }

    /* -------------------------------------------------------------------------- */
    /*                     ISlipstreamStandardExchangeDFPkg                        */
    /* -------------------------------------------------------------------------- */

    /// @notice Deploy a vault for an existing Slipstream pool with width multiplier
    /// @dev Position ticks are derived on first deposit using widthMultiplier * tickSpacing
    function deployVault(ICLPool pool, uint24 widthMultiplier) external override returns (address vault) {
        vault = VAULT_REGISTRY_DEPLOYMENT.deployVault(
            ISlipstreamStandardExchangeDFPkg(address(this)),
            abi.encode(PkgArgs({pool: pool, widthMultiplier: widthMultiplier}))
        );
    }
}
