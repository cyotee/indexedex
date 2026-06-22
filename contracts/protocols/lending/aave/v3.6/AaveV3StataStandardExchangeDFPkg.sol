// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondCut} from "@crane/contracts/interfaces/IDiamondCut.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {ERC4626Service} from "@crane/contracts/tokens/ERC4626/ERC4626Service.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQueryAware} from "contracts/interfaces/IVaultFeeOracleQueryAware.sol";
import {
    VaultFeeType,
    VaultFeeTypeIds
} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {MultiAssetBasicVaultRepo} from 'contracts/vaults/basic/MultiAssetBasicVaultRepo.sol';
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {IAaveV3StataStandardVault} from "contracts/interfaces/IAaveV3StataStandardVault.sol";
import {IStataTokenFactory} from "@crane/contracts/protocols/lending/aave/v3.6/extensions/stata-token/interfaces/IStataTokenFactory.sol";
import {IERC20AaveLM} from "@crane/contracts/protocols/lending/aave/v3.6/extensions/stata-token/interfaces/IERC20AaveLM.sol";

interface IAaveV3StataStandardExchangeDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    error NotCalledByRegistry(address caller);

    error ZeroStata();

    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet erc4626Facet;
        IFacet erc4626StandardVaultFacet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet aaveV3StataStandardExchangeInFacet;
        IFacet aaveV3StataStandardExchangeOutFacet;
        IFacet aaveV3StataMarkerFacet;
        IVaultFeeOracleQuery vaultFeeOracleQuery;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IPermit2 permit2;
        IStataTokenFactory stataTokenFactory;
    }

    struct PkgArgs {
        address stataToken; // the reserve asset
    }

    function deployVault(IERC20 stataToken) external returns (address vault);

    function deployVaultFromUnderlying(IERC20 underlying) external returns (address vault);
}

contract AaveV3StataStandardExchangeDFPkg is IAaveV3StataStandardExchangeDFPkg {
    using BetterEfficientHashLib for bytes;
    using BetterSafeERC20 for IERC20;
    using ERC4626Service for IERC4626;

    AaveV3StataStandardExchangeDFPkg public immutable SELF;

    IFacet public immutable ERC20_FACET;
    IFacet public immutable ERC5267_FACET;
    IFacet public immutable ERC2612_FACET;
    IFacet public immutable ERC4626_FACET;
    IFacet public immutable ERC4626_STANDARD_VAULT_FACET;
    IFacet public immutable MULTI_ASSET_BASIC_VAULT_FACET;
    IFacet public immutable MULTI_ASSET_STANDARD_VAULT_FACET;
    IFacet public immutable AAVE_V3_STATA_STANDARD_EXCHANGE_IN_FACET;
    IFacet public immutable AAVE_V3_STATA_STANDARD_EXCHANGE_OUT_FACET;
    IFacet public immutable AAVE_V3_STATA_MARKER_FACET;
    IVaultFeeOracleQuery public immutable VAULT_FEE_ORACLE_QUERY;
    IVaultRegistryDeployment public immutable VAULT_REGISTRY_DEPLOYMENT;
    IPermit2 public immutable PERMIT2;
    IStataTokenFactory public immutable STATA_TOKEN_FACTORY;

    constructor(PkgInit memory pkgInit) {
        SELF = this;
        ERC20_FACET = pkgInit.erc20Facet;
        ERC5267_FACET = pkgInit.erc5267Facet;
        ERC2612_FACET = pkgInit.erc2612Facet;
        ERC4626_FACET = pkgInit.erc4626Facet;
        ERC4626_STANDARD_VAULT_FACET = pkgInit.erc4626StandardVaultFacet;
        MULTI_ASSET_BASIC_VAULT_FACET = pkgInit.multiAssetBasicVaultFacet;
        MULTI_ASSET_STANDARD_VAULT_FACET = pkgInit.multiAssetStandardVaultFacet;
        AAVE_V3_STATA_STANDARD_EXCHANGE_IN_FACET = pkgInit.aaveV3StataStandardExchangeInFacet;
        AAVE_V3_STATA_STANDARD_EXCHANGE_OUT_FACET = pkgInit.aaveV3StataStandardExchangeOutFacet;
        AAVE_V3_STATA_MARKER_FACET = pkgInit.aaveV3StataMarkerFacet;
        VAULT_FEE_ORACLE_QUERY = pkgInit.vaultFeeOracleQuery;
        VAULT_REGISTRY_DEPLOYMENT = pkgInit.vaultRegistryDeployment;
        PERMIT2 = pkgInit.permit2;
        STATA_TOKEN_FACTORY = pkgInit.stataTokenFactory;
    }

    function _diamondPkgFactory() internal view virtual returns (IDiamondPackageCallBackFactory) {
        // Placeholder - actual packages often return the one from init or manager.
        // Full wiring is handled in the FactoryService and when calling via IndexedexManager.
        return IDiamondPackageCallBackFactory(address(VAULT_REGISTRY_DEPLOYMENT)); // best effort
    }

    /* ---------------------------------------------------------------------- */
    /*                        IAaveV3StataStandardExchangeDFPkg               */
    /* ---------------------------------------------------------------------- */

    function deployVault(IERC20 stataToken) public returns (address vault) {
        if (address(stataToken) == address(0)) revert ZeroStata();

        // Deploy the vault proxy via the registry deployment (through IndexedexManager in practice)
        vault = VAULT_REGISTRY_DEPLOYMENT.deployVault(
            SELF,
            abi.encode(PkgArgs({stataToken: address(stataToken)}))
        );

        // Initialize the ERC4626 with the stata as reserve asset
        // This would typically be done in post init or the package's initAccount.
        // For sketch, assume the standard facets handle setting reserve via init.
        // In real, the Pkg would set ERC4626Repo with the stata.

        return vault;
    }

    function deployVaultFromUnderlying(IERC20 underlying) public returns (address vault) {
        if (address(underlying) == address(0)) revert ZeroStata();

        // Check or deploy Stata via factory
        address stata = STATA_TOKEN_FACTORY.getStataToken(address(underlying));
        if (stata == address(0)) {
            address[] memory underlyings = new address[](1);
            underlyings[0] = address(underlying);
            address[] memory created = STATA_TOKEN_FACTORY.createStataTokens(underlyings);
            stata = created[0];
        }

        return deployVault(IERC20(stata));
    }

    /* ---------------------------------------------------------------------- */
    /*                            IStandardVaultPkg                           */
    /* ---------------------------------------------------------------------- */

    function name() public pure returns (string memory) {
        return type(AaveV3StataStandardExchangeDFPkg).name;
    }

    function vaultFeeTypeIds() public pure returns (bytes32 vaultFeeTypeIds_) {
        // Use the marker interface ID for the lending usage fee type so it can be overridden to 0
        vaultFeeTypeIds_ = VaultTypeUtils._insertFeeTypeId(
            vaultFeeTypeIds_,
            VaultFeeType.LENDING,
            type(IAaveV3StataStandardVault).interfaceId
        );
        return vaultFeeTypeIds_;
    }

    function vaultTypes() public pure returns (bytes4[] memory vaultTypes_) {
        // Will be populated by facetInterfaces in full impl
        return facetInterfaces();
    }

    function vaultDeclaration() public pure returns (VaultPkgDeclaration memory declaration) {
        return VaultPkgDeclaration({name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()});
    }

    /* ---------------------------------------------------------------------- */
    /*                           IDiamondFactoryPackage                       */
    /* ---------------------------------------------------------------------- */

    function packageName() public pure returns (string memory name_) {
        return type(AaveV3StataStandardExchangeDFPkg).name;
    }

    // facetCuts and other diamond logic would be in full impl, using the facets from init
    // For sketch, the structure is in place. The actual facet wiring happens via the manager.

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        // Approximate - in real DFPkg it aggregates from all included facets
        interfaces = new bytes4[](8);
        interfaces[0] = type(IERC20).interfaceId;
        interfaces[1] = type(IERC20Metadata).interfaceId;
        interfaces[2] = type(IERC20Permit).interfaceId;
        interfaces[3] = type(IERC5267).interfaceId;
        interfaces[4] = type(IERC4626).interfaceId;
        interfaces[5] = type(IStandardExchangeIn).interfaceId;
        interfaces[6] = type(IStandardExchangeOut).interfaceId;
        interfaces[7] = type(IAaveV3StataStandardVault).interfaceId;
        return interfaces;
    }

    // Note: full implementation would have immutable references to facets and build FacetCut[] in facetCuts()
    // and handle initAccount to set the ERC4626 reserve to the stata from PkgArgs.

    function facetCuts() public view returns (IDiamond.FacetCut[] memory cuts) {
        cuts = new IDiamond.FacetCut[](9);
        cuts[0] = IDiamond.FacetCut({ facetAddress: address(ERC20_FACET), action: IDiamond.FacetCutAction.Add, functionSelectors: ERC20_FACET.facetFuncs() });
        cuts[1] = IDiamond.FacetCut({ facetAddress: address(ERC5267_FACET), action: IDiamond.FacetCutAction.Add, functionSelectors: ERC5267_FACET.facetFuncs() });
        cuts[2] = IDiamond.FacetCut({ facetAddress: address(ERC2612_FACET), action: IDiamond.FacetCutAction.Add, functionSelectors: ERC2612_FACET.facetFuncs() });
        cuts[3] = IDiamond.FacetCut({ facetAddress: address(ERC4626_FACET), action: IDiamond.FacetCutAction.Add, functionSelectors: ERC4626_FACET.facetFuncs() });
        cuts[4] = IDiamond.FacetCut({ facetAddress: address(ERC4626_STANDARD_VAULT_FACET), action: IDiamond.FacetCutAction.Add, functionSelectors: ERC4626_STANDARD_VAULT_FACET.facetFuncs() });
        cuts[5] = IDiamond.FacetCut({ facetAddress: address(MULTI_ASSET_BASIC_VAULT_FACET), action: IDiamond.FacetCutAction.Add, functionSelectors: MULTI_ASSET_BASIC_VAULT_FACET.facetFuncs() });
        cuts[6] = IDiamond.FacetCut({ facetAddress: address(AAVE_V3_STATA_STANDARD_EXCHANGE_IN_FACET), action: IDiamond.FacetCutAction.Add, functionSelectors: AAVE_V3_STATA_STANDARD_EXCHANGE_IN_FACET.facetFuncs() });
        cuts[7] = IDiamond.FacetCut({ facetAddress: address(AAVE_V3_STATA_STANDARD_EXCHANGE_OUT_FACET), action: IDiamond.FacetCutAction.Add, functionSelectors: AAVE_V3_STATA_STANDARD_EXCHANGE_OUT_FACET.facetFuncs() });
        cuts[8] = IDiamond.FacetCut({ facetAddress: address(AAVE_V3_STATA_MARKER_FACET), action: IDiamond.FacetCutAction.Add, functionSelectors: AAVE_V3_STATA_MARKER_FACET.facetFuncs() });
    }

    function facetAddresses() external view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](0);
    }

    function diamondConfig() public view returns (DiamondConfig memory config) {
        config = IDiamondFactoryPackage.DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32) {
        return keccak256(pkgArgs);
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory args = abi.decode(initArgs, (PkgArgs));
        uint8 dec = IERC20Metadata(args.stataToken).decimals();
        // Standard offset is often 0 or configured; use 0 for simplicity here.
        ERC4626Repo._initialize(IERC20(args.stataToken), dec, 0);
        // Also set last total assets if needed for the vault.
        ERC4626Repo._setLastTotalAssets(0);
    }

    function postDeploy(address) public returns (bool) {
        return true;
    }

    function packageMetadata() external pure returns (string memory name_, bytes4[] memory interfaces, address[] memory facets) {
        name_ = "AaveV3StataStandardExchangeDFPkg";
        interfaces = facetInterfaces();
        facets = new address[](0);
    }

    function processArgs(bytes memory pkgArgs) public returns (bytes memory) {
        return pkgArgs;
    }

    function updatePkg(address, bytes memory) public returns (bool) {
        return true;
    }
}
