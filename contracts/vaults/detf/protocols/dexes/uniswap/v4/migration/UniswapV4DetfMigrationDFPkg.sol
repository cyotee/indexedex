// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721Receiver} from "@crane/contracts/interfaces/IERC721Receiver.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {IDETFStandardizedYield, IDETFStakingPreview} from "contracts/interfaces/IDETFStandardizedYield.sol";
import {IDETFSYDFPkg} from "contracts/vaults/detf/common/sy/IDETFSYDFPkg.sol";
import {DETFSYDeploymentLib} from "contracts/vaults/detf/common/sy/DETFSYDeploymentLib.sol";

import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {VaultFeeType} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";
import {
    IUniswapV4Detf,
    IUniswapV4DetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4DetfRepo as Repo} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfRepo.sol";
import {UniswapV4DetfProcessArgsLib as ArgsLib} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProcessArgsLib.sol";
import {UniswapV4DetfInitializationLib} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfInitializationLib.sol";
import {IUniswapV4DetfBondNFTVaultDFPkg} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/IUniswapV4DetfBondNFTVaultDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/IRebasingClaimTokenDFPkg.sol";

import {IUniswapV4DetfMigrationDFPkg} from "./interfaces/IUniswapV4DetfMigrationDFPkg.sol";
import {IUniswapV4DetfMigration, IUniswapV4DetfMigrationAllocation, IUniswapV4DetfMigrationAccounting} from "./interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationRewardTokenDFPkg, IUniswapV4DetfMigrationRewardToken} from "./sy/rewards/IUniswapV4DetfMigrationRewardToken.sol";
import {UniswapV4DetfMigrationRepo as MigrationRepo} from "./UniswapV4DetfMigrationRepo.sol";
import {MultiStepOwnableRepo} from "@crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {DETFChildSYRepo} from "contracts/vaults/detf/common/sy/DETFChildSYRepo.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
/// @title UniswapV4DetfMigrationDFPkg
/// @notice Unified Uni V4 DETF package. Hook is already deployed; PkgArgs.hook is that address.
contract UniswapV4DetfMigrationDFPkg is IUniswapV4DetfMigrationDFPkg {
    using BetterEfficientHashLib for bytes;
    using AddressSetRepo for AddressSet;

    IFacet immutable ERC20_FACET;
    IFacet immutable ERC5267_FACET;
    IFacet immutable ERC2612_FACET;
    IFacet immutable MULTI_ASSET_BASIC_VAULT_FACET;
    IFacet immutable MULTI_ASSET_STANDARD_VAULT_FACET;
    IFacet immutable EXCHANGE_FACET;
    IFacet immutable BOND_FACET;
    IFacet immutable MAINTENANCE_FACET;
    IFacet immutable CLAIM_FACET;
    IFacet immutable QUERY_FACET;
    IVaultFeeOracleQuery immutable FEE_ORACLE;
    IVaultRegistryDeployment immutable VAULT_REGISTRY_DEPLOYMENT;
    IUniswapV4DetfBondNFTVaultDFPkg immutable BOND_NFT_VAULT_PKG;
    IRebasingClaimTokenDFPkg immutable REBASING_CLAIM_TOKEN_PKG;
    IDETFSYDFPkg immutable SY_PKG;

    IFacet immutable OWNABLE_FACET;
    IFacet immutable MIGRATION_FACET;
    IFacet immutable ALLOCATION_FACET;
    IUniswapV4DetfMigrationRewardTokenDFPkg immutable REWARD_TOKEN_PKG;
    address immutable SELF;
    constructor(PkgInit memory migrationInit_) {
        IUniswapV4DetfDFPkg.PkgInit memory pkgInit = migrationInit_.baseInit;
        OWNABLE_FACET = migrationInit_.ownableFacet;
        MIGRATION_FACET = migrationInit_.migrationFacet;
        ALLOCATION_FACET = migrationInit_.allocationFacet;
        REWARD_TOKEN_PKG = migrationInit_.rewardTokenPkg;
        SELF = address(this);
        if (address(OWNABLE_FACET) == address(0) || address(MIGRATION_FACET) == address(0)
            || address(ALLOCATION_FACET) == address(0) || address(REWARD_TOKEN_PKG) == address(0)) revert InvalidMigrationPackageArguments();
        if (
            address(pkgInit.erc20Facet) == address(0)
                || address(pkgInit.feeOracle) == address(0)
                || address(pkgInit.vaultRegistryDeployment) == address(0)
                || address(pkgInit.bondNftVaultPkg) == address(0)
                || address(pkgInit.rebasingClaimTokenPkg) == address(0)
                || address(pkgInit.syPkg) == address(0)
        ) {
            revert InvalidMigrationPackageArguments();
        }
        for (uint256 i; i < pkgInit.productFacets.length; ++i) {
            if (address(pkgInit.productFacets[i]) == address(0)) revert InvalidMigrationPackageArguments();
        }
        ERC20_FACET = pkgInit.erc20Facet;
        ERC5267_FACET = pkgInit.erc5267Facet;
        ERC2612_FACET = pkgInit.erc2612Facet;
        MULTI_ASSET_BASIC_VAULT_FACET = pkgInit.multiAssetBasicVaultFacet;
        MULTI_ASSET_STANDARD_VAULT_FACET = pkgInit.multiAssetStandardVaultFacet;
        EXCHANGE_FACET = pkgInit.productFacets[0];
        BOND_FACET = pkgInit.productFacets[1];
        MAINTENANCE_FACET = pkgInit.productFacets[2];
        CLAIM_FACET = pkgInit.productFacets[3];
        QUERY_FACET = pkgInit.productFacets[4];
        FEE_ORACLE = pkgInit.feeOracle;
        VAULT_REGISTRY_DEPLOYMENT = pkgInit.vaultRegistryDeployment;
        BOND_NFT_VAULT_PKG = pkgInit.bondNftVaultPkg;
        REBASING_CLAIM_TOKEN_PKG = pkgInit.rebasingClaimTokenPkg;
        SY_PKG = pkgInit.syPkg;
    }

    function deployVault(PkgArgs memory args) external returns (address vault) {
        return VAULT_REGISTRY_DEPLOYMENT.deployVault(IStandardVaultPkg(address(this)), abi.encode(args));
    }

    function packageName() public pure returns (string memory) {
        return type(UniswapV4DetfMigrationDFPkg).name;
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

    function _productFacets() internal view returns (IFacet[5] memory) {
        return [EXCHANGE_FACET, BOND_FACET, MAINTENANCE_FACET, CLAIM_FACET, QUERY_FACET];
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](13);
        facetAddresses_[10] = address(OWNABLE_FACET);
        facetAddresses_[11] = address(MIGRATION_FACET);
        facetAddresses_[12] = address(ALLOCATION_FACET);
        facetAddresses_[0] = address(ERC20_FACET);
        facetAddresses_[1] = address(ERC5267_FACET);
        facetAddresses_[2] = address(ERC2612_FACET);
        facetAddresses_[3] = address(MULTI_ASSET_BASIC_VAULT_FACET);
        facetAddresses_[4] = address(MULTI_ASSET_STANDARD_VAULT_FACET);
        IFacet[5] memory product_ = _productFacets();
        for (uint256 i; i < product_.length; ++i) facetAddresses_[5 + i] = address(product_[i]);
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](16);
        interfaces_[15] = type(IERC721Receiver).interfaceId;
        interfaces_[12] = type(IMultiStepOwnable).interfaceId;
        interfaces_[13] = type(IUniswapV4DetfMigration).interfaceId;
        interfaces_[14] = type(IUniswapV4DetfMigrationAllocation).interfaceId;
        interfaces_[0] = type(IERC20).interfaceId;
        interfaces_[1] = type(IERC20Metadata).interfaceId;
        interfaces_[2] = type(IERC20Permit).interfaceId;
        interfaces_[3] = type(IERC5267).interfaceId;
        interfaces_[4] = type(IBasicVault).interfaceId;
        interfaces_[5] = type(IStandardVault).interfaceId;
        interfaces_[6] = type(IStandardExchangeIn).interfaceId;
        interfaces_[7] = type(IUniswapV4Detf).interfaceId;
        interfaces_[8] = bytes4(keccak256("UniswapV4Detf"));
        interfaces_[9] = type(IDETFStandardizedYield).interfaceId;
        interfaces_[10] = type(IDETFStakingPreview).interfaceId;
        interfaces_[11] = type(IDETFFundedRewards).interfaceId;
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

    function facetCuts() public view returns (IDiamond.FacetCut[] memory cuts_) {
        address[] memory facets_ = facetAddresses();
        cuts_ = new IDiamond.FacetCut[](facets_.length);
        for (uint256 i_; i_ < facets_.length; ++i_) cuts_[i_] = IDiamond.FacetCut(facets_[i_], IDiamond.FacetCutAction.Add, IFacet(facets_[i_]).facetFuncs());
    }

    function diamondConfig() public view returns (DiamondConfig memory config_) {
        config_ = DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    /// @dev Reject removed fields and noncanonical payloads instead of silently reinterpreting them.
    function _decodeArgs(bytes memory encoded_) private pure returns (PkgArgs memory args_) {
        args_ = abi.decode(encoded_, (PkgArgs));
        if (keccak256(encoded_) != keccak256(abi.encode(args_))) revert InvalidMigrationPackageArguments();
    }

    /// @dev Salt ignores `hook` so TestBase can CREATE2-predict the DETF before the hook exists.
    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32 salt_) {
        PkgArgs memory args = _decodeArgs(pkgArgs);
        args.baseArgs.hook = address(0);
        return keccak256(abi.encode(args));
    }

    function processArgs(bytes memory pkgArgs) public view returns (bytes memory processedPkgArgs_) {
        if (msg.sender != address(VAULT_REGISTRY_DEPLOYMENT)) {
            revert IUniswapV4DetfDFPkg.NotCalledByRegistry(msg.sender);
        }
        PkgArgs memory args = _decodeArgs(pkgArgs);
        ArgsLib.requireHookShape(args.baseArgs.hook);
        ArgsLib.requireLiquidityPolicy(args.baseArgs.hook, args.baseArgs.ownerOnlyLiquidity);
        _requireArgs(args);
        return pkgArgs;
    }

    /// @dev Factory preconstruction validation. No proxy call, cut, or state write occurs here.
    function updatePkg(address account_, bytes memory args_) public view returns (bool) {
        if (account_.code.length != 0) revert InvalidMigrationPackageArguments();
        _requireArgs(_decodeArgs(args_));
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory args = _decodeArgs(initArgs);
        if (address(this) == SELF || MigrationRepo._layoutStruct().weth != address(0)) revert InvalidMigrationPackageArguments();
        _requireArgs(args);
        UniswapV4DetfInitializationLib._initialize(
            args.baseArgs,
            FEE_ORACLE,
            vaultFeeTypeIds(),
            vaultTypes(),
            address(BOND_NFT_VAULT_PKG),
            address(REBASING_CLAIM_TOKEN_PKG)
        );
        MultiStepOwnableRepo._initialize(args.owner, args.ownershipBufferPeriod);
        MigrationRepo._layoutStruct().weth = args.weth;
        MigrationRepo._layoutStruct().originalDtf = args.originalDtf;
    }

    function postDeploy(address expectedProxy) public returns (bool) {
        if (address(this) != expectedProxy) {
            IPostDeployAccountHook(expectedProxy).postDeploy();
            return true;
        }
        IUniswapV4Detf self_ = IUniswapV4Detf(address(this));
        self_.completeReserveBondNft();
        self_.completeReserveClaim();
        Repo.Storage storage s_ = Repo._layoutStruct();
        MigrationRepo.Storage storage m_ = MigrationRepo._layoutStruct();
        if (m_.rewardToken != address(0)) revert InvalidMigrationPackageArguments();
        m_.rewardToken = REWARD_TOKEN_PKG.deployToken(IUniswapV4DetfMigrationRewardTokenDFPkg.PkgArgs({
            parent: address(this), receipt: self_.rebasingClaimToken(),
            name: string.concat(IERC20Metadata(address(this)).name(), " SY Rewards"), symbol: "mRT"
        }));
        emit IUniswapV4DetfMigration.MigrationSyRewardTokenWired(m_.rewardToken, self_.rebasingClaimToken());
        DETFSYDeploymentLib._deploy(
            SY_PKG, IStakedDETF(self_.rebasingClaimToken()), s_.mintTable.tokens._values(), s_.burnTable.tokens._values()
        );
        IUniswapV4DetfMigrationRewardToken rt_ = IUniswapV4DetfMigrationRewardToken(m_.rewardToken);
        DETFChildSYRepo.Storage storage sy_ = DETFChildSYRepo._layoutStruct();
        if (rt_.parent() != address(this) || rt_.receipt() != self_.rebasingClaimToken()
            || IStandardizedYield(sy_.rawSY).yieldToken() != address(this)
            || IStandardizedYield(sy_.stakingSY).yieldToken() != self_.rebasingClaimToken()) revert InvalidMigrationChild(m_.rewardToken);
        return true;
    }
    function _requireArgs(PkgArgs memory args_) private pure {
        if (args_.owner == address(0) || args_.weth == address(0) || args_.originalDtf == address(0)
            || args_.weth == args_.originalDtf) revert InvalidMigrationPackageArguments();
    }
}
