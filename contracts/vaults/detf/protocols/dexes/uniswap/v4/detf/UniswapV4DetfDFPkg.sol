// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {VaultFeeType} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {
    DETFThresholdPolicy,
    ThresholdMode
} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {DETFEpochNaturalExpansionLib} from "contracts/vaults/detf/common/core/DETFEpochNaturalExpansionLib.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {
    IUniswapV4Detf,
    IUniswapV4DetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4DetfRepo as Repo} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfRepo.sol";
import {UniswapV4DetfProcessArgsLib as ArgsLib} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProcessArgsLib.sol";
import {IUniswapV4DetfBondNFTVaultDFPkg} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/UniswapV4DetfBondNFTVaultDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";

/// @title UniswapV4DetfDFPkg
/// @notice Unified Uni V4 DETF package. Hook is already deployed; PkgArgs.hook is that address.
contract UniswapV4DetfDFPkg is IUniswapV4DetfDFPkg {
    using BetterEfficientHashLib for bytes;

    IFacet immutable ERC20_FACET;
    IFacet immutable ERC5267_FACET;
    IFacet immutable ERC2612_FACET;
    IFacet immutable MULTI_ASSET_BASIC_VAULT_FACET;
    IFacet immutable MULTI_ASSET_STANDARD_VAULT_FACET;
    IFacet immutable PRODUCT_FACET;
    IVaultFeeOracleQuery immutable FEE_ORACLE;
    IVaultRegistryDeployment immutable VAULT_REGISTRY_DEPLOYMENT;
    IUniswapV4DetfBondNFTVaultDFPkg immutable BOND_NFT_VAULT_PKG;
    IRebasingClaimTokenDFPkg immutable REBASING_CLAIM_TOKEN_PKG;

    constructor(PkgInit memory pkgInit) {
        if (
            address(pkgInit.erc20Facet) == address(0) || address(pkgInit.productFacet) == address(0)
                || address(pkgInit.feeOracle) == address(0)
                || address(pkgInit.vaultRegistryDeployment) == address(0)
                || address(pkgInit.bondNftVaultPkg) == address(0)
                || address(pkgInit.rebasingClaimTokenPkg) == address(0)
        ) {
            revert ZeroAddress();
        }
        ERC20_FACET = pkgInit.erc20Facet;
        ERC5267_FACET = pkgInit.erc5267Facet;
        ERC2612_FACET = pkgInit.erc2612Facet;
        MULTI_ASSET_BASIC_VAULT_FACET = pkgInit.multiAssetBasicVaultFacet;
        MULTI_ASSET_STANDARD_VAULT_FACET = pkgInit.multiAssetStandardVaultFacet;
        PRODUCT_FACET = pkgInit.productFacet;
        FEE_ORACLE = pkgInit.feeOracle;
        VAULT_REGISTRY_DEPLOYMENT = pkgInit.vaultRegistryDeployment;
        BOND_NFT_VAULT_PKG = pkgInit.bondNftVaultPkg;
        REBASING_CLAIM_TOKEN_PKG = pkgInit.rebasingClaimTokenPkg;
    }

    function deployVault(IUniswapV4Detf.PkgArgs memory args) external returns (address vault) {
        return VAULT_REGISTRY_DEPLOYMENT.deployVault(IStandardVaultPkg(address(this)), abi.encode(args));
    }

    function packageName() public pure returns (string memory) {
        return type(UniswapV4DetfDFPkg).name;
    }

    function name() public pure returns (string memory) {
        return packageName();
    }

    function vaultFeeTypeIds() public pure returns (bytes32 vaultFeeTypeIds_) {
        return VaultTypeUtils._insertFeeTypeId(
            vaultFeeTypeIds_, VaultFeeType.USAGE, type(IStandardExchangeIn).interfaceId
        );
    }

    function vaultTypes() public pure returns (bytes4[] memory typeIDs_) {
        return facetInterfaces();
    }

    function vaultDeclaration() public pure returns (VaultPkgDeclaration memory declaration_) {
        return VaultPkgDeclaration({name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()});
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](6);
        facetAddresses_[0] = address(ERC20_FACET);
        facetAddresses_[1] = address(ERC5267_FACET);
        facetAddresses_[2] = address(ERC2612_FACET);
        facetAddresses_[3] = address(MULTI_ASSET_BASIC_VAULT_FACET);
        facetAddresses_[4] = address(MULTI_ASSET_STANDARD_VAULT_FACET);
        facetAddresses_[5] = address(PRODUCT_FACET);
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](9);
        interfaces_[0] = type(IERC20).interfaceId;
        interfaces_[1] = type(IERC20Metadata).interfaceId;
        interfaces_[2] = type(IERC20Permit).interfaceId;
        interfaces_[3] = type(IERC5267).interfaceId;
        interfaces_[4] = type(IBasicVault).interfaceId;
        interfaces_[5] = type(IStandardVault).interfaceId;
        interfaces_[6] = type(IStandardExchangeIn).interfaceId;
        interfaces_[7] = type(IUniswapV4Detf).interfaceId;
        interfaces_[8] = bytes4(keccak256("UniswapV4Detf"));
    }

    function packageMetadata()
        public
        view
        returns (string memory name_, bytes4[] memory interfaces_, address[] memory facets_)
    {
        name_ = packageName();
        interfaces_ = facetInterfaces();
        facets_ = facetAddresses();
    }

    function facetCuts() public view returns (IDiamond.FacetCut[] memory facetCuts_) {
        facetCuts_ = new IDiamond.FacetCut[](6);
        facetCuts_[0] = IDiamond.FacetCut(address(ERC20_FACET), IDiamond.FacetCutAction.Add, ERC20_FACET.facetFuncs());
        facetCuts_[1] =
            IDiamond.FacetCut(address(ERC5267_FACET), IDiamond.FacetCutAction.Add, ERC5267_FACET.facetFuncs());
        facetCuts_[2] =
            IDiamond.FacetCut(address(ERC2612_FACET), IDiamond.FacetCutAction.Add, ERC2612_FACET.facetFuncs());
        facetCuts_[3] = IDiamond.FacetCut(
            address(MULTI_ASSET_BASIC_VAULT_FACET),
            IDiamond.FacetCutAction.Add,
            MULTI_ASSET_BASIC_VAULT_FACET.facetFuncs()
        );
        facetCuts_[4] = IDiamond.FacetCut(
            address(MULTI_ASSET_STANDARD_VAULT_FACET),
            IDiamond.FacetCutAction.Add,
            MULTI_ASSET_STANDARD_VAULT_FACET.facetFuncs()
        );
        facetCuts_[5] =
            IDiamond.FacetCut(address(PRODUCT_FACET), IDiamond.FacetCutAction.Add, PRODUCT_FACET.facetFuncs());
    }

    function diamondConfig() public view returns (DiamondConfig memory config_) {
        config_ = DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    /// @dev Salt ignores `hook` so TestBase can CREATE2-predict the DETF before the hook exists.
    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32 salt_) {
        IUniswapV4Detf.PkgArgs memory args = abi.decode(pkgArgs, (IUniswapV4Detf.PkgArgs));
        args.hook = address(0);
        return keccak256(abi.encode(args));
    }

    function processArgs(bytes memory pkgArgs) public view returns (bytes memory processedPkgArgs_) {
        if (msg.sender != address(VAULT_REGISTRY_DEPLOYMENT)) {
            revert NotCalledByRegistry(msg.sender);
        }
        IUniswapV4Detf.PkgArgs memory args = abi.decode(pkgArgs, (IUniswapV4Detf.PkgArgs));
        ArgsLib.requireHookShape(args.hook);
        ArgsLib.requireCustomClose(args);
        return pkgArgs;
    }

    function updatePkg(address, bytes memory) public pure returns (bool) {
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        IUniswapV4Detf.PkgArgs memory args = abi.decode(initArgs, (IUniswapV4Detf.PkgArgs));
        ArgsLib.requireHookShape(args.hook);
        ArgsLib.requireDetfSelfLegAndOwner(args.hook, address(this));
        ArgsLib.requireCustomClose(args);

        address[] memory hookTokens_ = IUniswapV4SeBufferHook(args.hook).tokens();
        uint256 pairCount_ = hookTokens_.length - 1;
        ArgsLib.requireCreationRates(args, pairCount_);
        uint256[] memory opening_ = ArgsLib.resolveOpening(args.creationPairPerDetfWad, args.openingPairPerDetfWad);

        ERC20Repo._initialize(args.name, args.symbol, 18);
        EIP712Repo._initialize(args.name, "1");

        address[] memory contents_ = new address[](hookTokens_.length + 1);
        for (uint256 i; i < hookTokens_.length; ++i) {
            contents_[i] = hookTokens_[i];
        }
        contents_[hookTokens_.length] = args.hook;
        StandardVaultRepo._initialize(
            FEE_ORACLE, vaultFeeTypeIds(), vaultTypes(), abi.encode(contents_)._hash()
        );

        DETFThresholdPolicy.requireValidThresholdMode(args.thresholdMode);
        (uint256 mint_, uint256 burn_) =
            DETFThresholdPolicy.resolveAndRequireValidThresholds(args.mintThreshold, args.burnThreshold);
        (uint256 epoch_, uint256 rate_, uint256 maxCatch_) = DETFEpochNaturalExpansionLib.resolveExpansionParams(
            args.expansionEpochLength, args.expansionClosureRatePerYearWad, args.expansionMaxCatchUpEpochs
        );

        Repo._initializeCore(
            Repo.CoreInit({
                hook: args.hook,
                feeOracle: FEE_ORACLE,
                creationPairPerDetfWad: args.creationPairPerDetfWad,
                openingPairPerDetfWad: opening_,
                bondNftVaultPkg: address(BOND_NFT_VAULT_PKG),
                rebasingClaimTokenPkg: address(REBASING_CLAIM_TOKEN_PKG),
                creator: args.creator
            })
        );
        Repo._initializePolicy(
            Repo.PolicyInit({
                mintThreshold: mint_,
                burnThreshold: burn_,
                thresholdMode: args.thresholdMode,
                expansionEpochLength: epoch_,
                expansionClosureRatePerYearWad: rate_,
                expansionMaxCatchUpEpochs: maxCatch_
            })
        );
        Repo._setChildTokenMetadata(args.claimName, args.claimSymbol, args.bondName, args.bondSymbol);
        Repo._setRouteModes(
            args.mintRouteMode,
            args.burnRouteMode,
            args.bondRouteMode,
            args.closeRouteMode,
            args.donateRouteMode
        );
        ArgsLib.storeHookSetsAndRates(args.hook, address(this), args.creationPairPerDetfWad, opening_);
        _storeTables(args);
        MultiAssetBasicVaultRepo._initialize(contents_);
        emit IUniswapV4Detf.ThresholdModeSet(args.thresholdMode, mint_, burn_);
    }

    function _storeTables(IUniswapV4Detf.PkgArgs memory args) private {
        Repo.Storage storage s = Repo._layoutStruct();
        if (args.mintRouteMode == IUniswapV4Detf.RouteTableMode.Custom) {
            ArgsLib.storeCustomTable(args.hook, address(this), args.mintRoutes, s.mintTable, false, false);
        } else {
            ArgsLib.storeDefaultInbound(args.hook, address(this), s.mintTable);
        }
        if (args.burnRouteMode == IUniswapV4Detf.RouteTableMode.Custom) {
            ArgsLib.storeCustomTable(args.hook, address(this), args.burnRoutes, s.burnTable, false, false);
        } else {
            ArgsLib.storeDefaultInbound(args.hook, address(this), s.burnTable);
        }
        if (args.bondRouteMode == IUniswapV4Detf.RouteTableMode.Custom) {
            ArgsLib.storeCustomTable(args.hook, address(this), args.bondRoutes, s.bondTable, false, false);
        } else {
            ArgsLib.storeDefaultInbound(args.hook, address(this), s.bondTable);
        }
        if (args.closeRouteMode == IUniswapV4Detf.RouteTableMode.Custom) {
            ArgsLib.storeCustomTable(args.hook, address(this), args.closeRoutes, s.closeTable, true, false);
        } else {
            ArgsLib.storeDefaultClose(args.hook, address(this), s.closeTable);
        }
        if (args.donateRouteMode == IUniswapV4Detf.RouteTableMode.Custom) {
            ArgsLib.storeCustomTable(args.hook, address(this), args.donateRoutes, s.donateTable, false, true);
            ArgsLib.requireDonateSubset();
        } else {
            ArgsLib.storeDonateUnion();
        }
    }

    function postDeploy(address expectedProxy) public returns (bool) {
        if (address(this) != expectedProxy) {
            IPostDeployAccountHook(expectedProxy).postDeploy();
            return true;
        }
        IUniswapV4Detf self_ = IUniswapV4Detf(address(this));
        self_.completeReserveBondNft();
        self_.completeReserveClaim();
        return true;
    }
}
