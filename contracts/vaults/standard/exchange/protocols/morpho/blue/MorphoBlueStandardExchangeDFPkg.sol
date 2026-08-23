// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/tokens/ERC20/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IMorpho, Id, MarketParams, Market} from
    "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {MarketParamsLib} from "@crane/contracts/external/morpho/blue/libraries/MarketParamsLib.sol";
import {MorphoBlueAwareRepo} from
    "@crane/contracts/protocols/lending/morpho/blue/aware/MorphoBlueAwareRepo.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {VaultFeeType} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {
    IMorphoBlueStandardExchange
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/IMorphoBlueStandardExchange.sol";
import {
    IMorphoBlueStandardExchangeDFPkg
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/IMorphoBlueStandardExchangeDFPkg.sol";
import {
    MorphoBlueStandardExchangeRepo
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeRepo.sol";

/**
 * @title MorphoBlueStandardExchangeDFPkg
 * @notice Registry DFPkg: ERC20 + permit + Morpho-aware IERC4626 + MultiAsset Basic/Standard + In/Out + Marker.
 * @dev Does not cut stock `ERC4626Facet` or `ERC4626StandardVaultFacet`.
 */
contract MorphoBlueStandardExchangeDFPkg is IMorphoBlueStandardExchangeDFPkg {
    using BetterEfficientHashLib for bytes;
    using BetterSafeERC20 for IERC20Metadata;
    using MarketParamsLib for MarketParams;

    MorphoBlueStandardExchangeDFPkg public immutable SELF;

    IFacet public immutable ERC20_FACET;
    IFacet public immutable ERC5267_FACET;
    IFacet public immutable ERC2612_FACET;
    IFacet public immutable MORPHO_BLUE_ERC4626_FACET;
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
        MORPHO_BLUE_ERC4626_FACET = pkgInit.morphoBlueErc4626Facet;
        MULTI_ASSET_BASIC_VAULT_FACET = pkgInit.multiAssetBasicVaultFacet;
        MULTI_ASSET_STANDARD_VAULT_FACET = pkgInit.multiAssetStandardVaultFacet;
        EXCHANGE_IN_FACET = pkgInit.exchangeInFacet;
        EXCHANGE_OUT_FACET = pkgInit.exchangeOutFacet;
        MARKER_FACET = pkgInit.markerFacet;
        VAULT_FEE_ORACLE_QUERY = pkgInit.vaultFeeOracleQuery;
        VAULT_REGISTRY_DEPLOYMENT = pkgInit.vaultRegistryDeployment;
        PERMIT2 = pkgInit.permit2;
    }

    function deployVault(PkgArgs memory args) public returns (address vault) {
        vault = VAULT_REGISTRY_DEPLOYMENT.deployVault(SELF, abi.encode(args));
    }

    function name() public pure returns (string memory) {
        return type(MorphoBlueStandardExchangeDFPkg).name;
    }

    function vaultFeeTypeIds() public pure returns (bytes32 vaultFeeTypeIds_) {
        vaultFeeTypeIds_ = VaultTypeUtils._insertFeeTypeId(
            vaultFeeTypeIds_, VaultFeeType.LENDING, type(IMorphoBlueStandardExchange).interfaceId
        );
    }

    function vaultTypes() public pure returns (bytes4[] memory) {
        return facetInterfaces();
    }

    function vaultDeclaration() public pure returns (VaultPkgDeclaration memory declaration) {
        return VaultPkgDeclaration({name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()});
    }

    function packageName() public pure returns (string memory) {
        return type(MorphoBlueStandardExchangeDFPkg).name;
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
        interfaces[7] = type(IMorphoBlueStandardExchange).interfaceId;
        interfaces[8] = type(IBasicVault).interfaceId;
        interfaces[9] = type(IStandardVault).interfaceId;
    }

    function facetCuts() public view returns (IDiamond.FacetCut[] memory cuts) {
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
            facetAddress: address(MORPHO_BLUE_ERC4626_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: MORPHO_BLUE_ERC4626_FACET.facetFuncs()
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
        facetAddresses_ = new address[](9);
        facetAddresses_[0] = address(ERC20_FACET);
        facetAddresses_[1] = address(ERC5267_FACET);
        facetAddresses_[2] = address(ERC2612_FACET);
        facetAddresses_[3] = address(MORPHO_BLUE_ERC4626_FACET);
        facetAddresses_[4] = address(MULTI_ASSET_BASIC_VAULT_FACET);
        facetAddresses_[5] = address(MULTI_ASSET_STANDARD_VAULT_FACET);
        facetAddresses_[6] = address(EXCHANGE_IN_FACET);
        facetAddresses_[7] = address(EXCHANGE_OUT_FACET);
        facetAddresses_[8] = address(MARKER_FACET);
    }

    function diamondConfig() public view returns (DiamondConfig memory config) {
        config = IDiamondFactoryPackage.DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32) {
        return keccak256(pkgArgs);
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory args = abi.decode(initArgs, (PkgArgs));
        if (address(args.morpho) == address(0)) revert IMorphoBlueStandardExchange.ZeroMorpho();
        if (args.marketParams.loanToken == address(0)) revert IMorphoBlueStandardExchange.ZeroLoanToken();
        if (args.marketParams.oracle == address(0)) revert IMorphoBlueStandardExchange.ZeroOracle();
        if (args.marketParams.irm == address(0)) revert IMorphoBlueStandardExchange.ZeroIrm();

        Id id_ = args.marketParams.id();
        Market memory market_ = args.morpho.market(id_);
        if (market_.lastUpdate == 0) {
            revert IMorphoBlueStandardExchange.MarketNotCreated(id_);
        }

        MorphoBlueAwareRepo._initialize(args.morpho, args.marketParams.irm, args.marketParams.oracle);
        MorphoBlueStandardExchangeRepo._initialize(args.marketParams);

        string memory name_ = _shareName(args.marketParams.loanToken);
        ERC20Repo._initialize(name_, "ixMBSE", 18);
        EIP712Repo._initialize(name_, "1");

        uint8 loanDecimals_ = IERC20Metadata(args.marketParams.loanToken).safeDecimals();
        ERC4626Repo._initialize(IERC20(args.marketParams.loanToken), loanDecimals_, 0);
        ERC4626Repo._setLastTotalAssets(0);

        address[] memory vaultTokens = new address[](1);
        vaultTokens[0] = args.marketParams.loanToken;
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
        view
        returns (string memory name_, bytes4[] memory interfaces, address[] memory facets)
    {
        name_ = "MorphoBlueStandardExchangeDFPkg";
        interfaces = facetInterfaces();
        facets = this.facetAddresses();
    }

    function processArgs(bytes memory pkgArgs) public pure returns (bytes memory) {
        return pkgArgs;
    }

    function updatePkg(address, bytes memory) public pure returns (bool) {
        return true;
    }

    function _shareName(address loanToken_) private view returns (string memory) {
        try IERC20Metadata(loanToken_).symbol() returns (string memory symbol_) {
            if (bytes(symbol_).length != 0) {
                return string.concat("IndexedEx Morpho Blue SE ", symbol_);
            }
        } catch {}
        return "IndexedEx Morpho Blue SE";
    }
}
