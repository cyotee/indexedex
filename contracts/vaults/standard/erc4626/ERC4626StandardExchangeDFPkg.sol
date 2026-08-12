// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {VaultFeeType} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {IERC4626StandardExchange} from "contracts/vaults/standard/erc4626/IERC4626StandardExchange.sol";

interface IERC4626StandardExchangeDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    error NotCalledByRegistry(address caller);
    error ZeroProtocolVault();

    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet erc4626Facet;
        IFacet erc4626StandardVaultFacet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet exchangeInFacet;
        IFacet exchangeOutFacet;
        IFacet markerFacet;
        IVaultFeeOracleQuery vaultFeeOracleQuery;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IPermit2 permit2;
    }

    struct PkgArgs {
        address protocolVault;
    }

    function deployVault(IERC4626 protocolVault) external returns (address vault);
}

/**
 * @title ERC4626StandardExchangeDFPkg
 * @notice Generic ERC-4626 Standard Exchange: SE asset = protocol vault;
 *         vaultTokens = [protocolVault, IERC4626(protocolVault).asset()].
 */
contract ERC4626StandardExchangeDFPkg is IERC4626StandardExchangeDFPkg {
    using BetterEfficientHashLib for bytes;
    using BetterSafeERC20 for IERC20;

    ERC4626StandardExchangeDFPkg public immutable SELF;

    IFacet public immutable ERC20_FACET;
    IFacet public immutable ERC5267_FACET;
    IFacet public immutable ERC2612_FACET;
    IFacet public immutable ERC4626_FACET;
    IFacet public immutable ERC4626_STANDARD_VAULT_FACET;
    IFacet public immutable MULTI_ASSET_BASIC_VAULT_FACET;
    IFacet public immutable MULTI_ASSET_STANDARD_VAULT_FACET;
    IFacet public immutable EXCHANGE_IN_FACET;
    IFacet public immutable EXCHANGE_OUT_FACET;
    IFacet public immutable MARKER_FACET;
    IVaultFeeOracleQuery public immutable VAULT_FEE_ORACLE_QUERY;
    IVaultRegistryDeployment public immutable VAULT_REGISTRY_DEPLOYMENT;
    IPermit2 public immutable PERMIT2;

    constructor(PkgInit memory pkgInit) {
        SELF = this;
        ERC20_FACET = pkgInit.erc20Facet;
        ERC5267_FACET = pkgInit.erc5267Facet;
        ERC2612_FACET = pkgInit.erc2612Facet;
        ERC4626_FACET = pkgInit.erc4626Facet;
        ERC4626_STANDARD_VAULT_FACET = pkgInit.erc4626StandardVaultFacet;
        MULTI_ASSET_BASIC_VAULT_FACET = pkgInit.multiAssetBasicVaultFacet;
        MULTI_ASSET_STANDARD_VAULT_FACET = pkgInit.multiAssetStandardVaultFacet;
        EXCHANGE_IN_FACET = pkgInit.exchangeInFacet;
        EXCHANGE_OUT_FACET = pkgInit.exchangeOutFacet;
        MARKER_FACET = pkgInit.markerFacet;
        VAULT_FEE_ORACLE_QUERY = pkgInit.vaultFeeOracleQuery;
        VAULT_REGISTRY_DEPLOYMENT = pkgInit.vaultRegistryDeployment;
        PERMIT2 = pkgInit.permit2;
    }

    function deployVault(IERC4626 protocolVault) public returns (address vault) {
        if (address(protocolVault) == address(0)) revert ZeroProtocolVault();
        vault = VAULT_REGISTRY_DEPLOYMENT.deployVault(
            SELF, abi.encode(PkgArgs({protocolVault: address(protocolVault)}))
        );
    }

    function name() public pure returns (string memory) {
        return type(ERC4626StandardExchangeDFPkg).name;
    }

    function vaultFeeTypeIds() public pure returns (bytes32 vaultFeeTypeIds_) {
        vaultFeeTypeIds_ = VaultTypeUtils._insertFeeTypeId(
            vaultFeeTypeIds_, VaultFeeType.LENDING, type(IERC4626StandardExchange).interfaceId
        );
    }

    function vaultTypes() public pure returns (bytes4[] memory) {
        return facetInterfaces();
    }

    function vaultDeclaration() public pure returns (VaultPkgDeclaration memory declaration) {
        return VaultPkgDeclaration({name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()});
    }

    function packageName() public pure returns (string memory) {
        return type(ERC4626StandardExchangeDFPkg).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](10);
        interfaces[0] = type(IERC20).interfaceId;
        interfaces[1] = type(IERC20Metadata).interfaceId;
        interfaces[2] = type(IERC20Permit).interfaceId;
        interfaces[3] = type(IERC5267).interfaceId;
        interfaces[4] = type(IERC4626).interfaceId;
        interfaces[5] = type(IStandardExchangeIn).interfaceId;
        interfaces[6] = type(IStandardExchangeOut).interfaceId;
        interfaces[7] = type(IERC4626StandardExchange).interfaceId;
        interfaces[8] = type(IBasicVault).interfaceId;
        interfaces[9] = type(IStandardVault).interfaceId;
    }

    function facetCuts() public view returns (IDiamond.FacetCut[] memory cuts) {
        // Multi-asset Basic + Standard (PRD §6.0.B). MultiAssetStandard replaces
        // ERC4626StandardVaultFacet for IStandardVault so vaultConfig.tokens uses
        // MultiAssetBasicVaultRepo (protocolVault + asset), avoiding FunctionAlreadyPresent.
        cuts = new IDiamond.FacetCut[](9);
        cuts[0] = IDiamond.FacetCut({
            facetAddress: address(ERC20_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC20_FACET.facetFuncs()
        });
        cuts[1] = IDiamond.FacetCut({
            facetAddress: address(ERC5267_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC5267_FACET.facetFuncs()
        });
        cuts[2] = IDiamond.FacetCut({
            facetAddress: address(ERC2612_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC2612_FACET.facetFuncs()
        });
        cuts[3] = IDiamond.FacetCut({
            facetAddress: address(ERC4626_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC4626_FACET.facetFuncs()
        });
        cuts[4] = IDiamond.FacetCut({
            facetAddress: address(MULTI_ASSET_BASIC_VAULT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: MULTI_ASSET_BASIC_VAULT_FACET.facetFuncs()
        });
        cuts[5] = IDiamond.FacetCut({
            facetAddress: address(MULTI_ASSET_STANDARD_VAULT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: MULTI_ASSET_STANDARD_VAULT_FACET.facetFuncs()
        });
        cuts[6] = IDiamond.FacetCut({
            facetAddress: address(EXCHANGE_IN_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: EXCHANGE_IN_FACET.facetFuncs()
        });
        cuts[7] = IDiamond.FacetCut({
            facetAddress: address(EXCHANGE_OUT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: EXCHANGE_OUT_FACET.facetFuncs()
        });
        cuts[8] = IDiamond.FacetCut({
            facetAddress: address(MARKER_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: MARKER_FACET.facetFuncs()
        });
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
        IERC4626 protocolVault = IERC4626(args.protocolVault);
        address underlying = protocolVault.asset();
        uint8 vaultDecimals = IERC20Metadata(args.protocolVault).decimals();

        string memory name_ = string.concat("IndexedEx SE ", IERC20Metadata(args.protocolVault).symbol());
        ERC20Repo._initialize(name_, "ixSE", 18);
        EIP712Repo._initialize(name_, "1");
        // SE ERC-4626 asset is the protocol vault
        ERC4626Repo._initialize(IERC20(args.protocolVault), vaultDecimals, 0);
        ERC4626Repo._setLastTotalAssets(0);

        // vaultTokens = [protocolVault, asset()]
        address[] memory vaultTokens = new address[](2);
        vaultTokens[0] = args.protocolVault;
        vaultTokens[1] = underlying;
        MultiAssetBasicVaultRepo._initialize(vaultTokens);

        bytes32 contentsId = abi.encode(vaultTokens)._hash();
        StandardVaultRepo._initialize(
            VAULT_FEE_ORACLE_QUERY, vaultFeeTypeIds(), vaultTypes(), contentsId
        );
        VaultFeeOracleQueryAwareRepo._initialize(VAULT_FEE_ORACLE_QUERY);
        Permit2AwareRepo._initialize(PERMIT2);
    }

    function postDeploy(address) public pure returns (bool) {
        return true;
    }

    function packageMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces, address[] memory facets)
    {
        name_ = "ERC4626StandardExchangeDFPkg";
        interfaces = facetInterfaces();
        facets = new address[](0);
    }

    function processArgs(bytes memory pkgArgs) public pure returns (bytes memory) {
        return pkgArgs;
    }

    function updatePkg(address, bytes memory) public pure returns (bool) {
        return true;
    }
}
