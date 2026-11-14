// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
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
import {IUniswapV4DetfMigrationRecovery} from "./interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {IUniswapV4DetfMigration, IUniswapV4DetfMigrationAllocation, IUniswapV4DetfMigrationAccounting} from "./interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationRewardTokenDFPkg, IUniswapV4DetfMigrationRewardToken} from "./sy/rewards/IUniswapV4DetfMigrationRewardToken.sol";
import {IUniswapV4DetfMigrationSYDFPkg as MigrationSYPackage} from "./sy/IUniswapV4DetfMigrationSYDFPkg.sol";
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
    IDiamondPackageCallBackFactory immutable DIAMOND_FACTORY;

    IFacet immutable OWNABLE_FACET;
    IFacet immutable MIGRATION_FACET;
    IFacet immutable ALLOCATION_FACET;
    IFacet immutable RECOVERY_FACET;
    IFacet immutable CLAIM_VAULT_ALLOCATION_FACET;
    IUniswapV4DetfMigrationRewardTokenDFPkg immutable REWARD_TOKEN_PKG;
    address immutable SELF;
    constructor(PkgInit memory migrationInit_) {
        IUniswapV4DetfDFPkg.PkgInit memory pkgInit = migrationInit_.baseInit;
        OWNABLE_FACET = migrationInit_.ownableFacet;
        MIGRATION_FACET = migrationInit_.migrationFacet;
        ALLOCATION_FACET = migrationInit_.allocationFacet;
        RECOVERY_FACET = migrationInit_.recoveryFacet;
        CLAIM_VAULT_ALLOCATION_FACET = migrationInit_.claimVaultAllocationFacet;
        REWARD_TOKEN_PKG = migrationInit_.rewardTokenPkg;
        SELF = address(this);
        if (address(OWNABLE_FACET) == address(0) || address(MIGRATION_FACET) == address(0)
            || address(ALLOCATION_FACET) == address(0) || address(RECOVERY_FACET) == address(0)
            || address(CLAIM_VAULT_ALLOCATION_FACET) == address(0)
            || address(REWARD_TOKEN_PKG) == address(0)) revert InvalidMigrationPackageArguments();
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
        DIAMOND_FACTORY = MigrationSYPackage(address(pkgInit.syPkg)).diamondFactory();
    }

    function deployVault(PkgArgs memory args) external returns (address vault) {
        if (address(this) != SELF) revert InvalidMigrationPackageArguments();
        _requireArgs(args);
        bytes memory encoded_ = abi.encode(args);
        vault = VAULT_REGISTRY_DEPLOYMENT.deployVault(IStandardVaultPkg(SELF), encoded_);
        // Existing-code factory reuse skips every callback. Never report a different hook's
        // already constructed parent as a successful deployment of this full payload.
        if (address(DIAMOND_FACTORY.pkgOfAccount(vault)) != SELF
            || keccak256(DIAMOND_FACTORY.pkgArgsOfAccount(vault)) != keccak256(encoded_)) {
            revert InvalidMigrationPackageArguments();
        }
    }

    function syPackage() external view returns (address) { return address(SY_PKG); }

    function prepareSyChildren(PkgArgs memory args_) external returns (address rawSy_, address stakingSy_) {
        if (address(this) != SELF) revert InvalidMigrationPackageArguments();
        MigrationSYPackage.Preparation memory p_ = MigrationSYPackage(address(SY_PKG)).prepare(args_);
        return (p_.rawSy, p_.stakingSy);
    }

    function preparationDependencies() external view returns (PreparationDependencies memory) {
        return PreparationDependencies(address(BOND_NFT_VAULT_PKG), address(REBASING_CLAIM_TOKEN_PKG),
            address(FEE_ORACLE), address(SY_PKG));
    }

    function syConstruction(PkgArgs memory args_) external view returns (SyConstruction memory) {
        return MigrationSYPackage(address(SY_PKG)).construction(SELF, args_);
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
        facetAddresses_ = new address[](15);
        facetAddresses_[14] = address(CLAIM_VAULT_ALLOCATION_FACET);
        facetAddresses_[13] = address(RECOVERY_FACET);
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
        interfaces_ = new bytes4[](17);
        interfaces_[16] = type(IUniswapV4DetfMigrationRecovery).interfaceId;
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
        _requirePreparation(args);
        return pkgArgs;
    }

    /// @dev Factory preconstruction validation. No proxy call, cut, or state write occurs here.
    function updatePkg(address account_, bytes memory args_) public view returns (bool) {
        if (address(this) != SELF || msg.sender != address(DIAMOND_FACTORY) || account_.code.length != 0
            || account_ != DIAMOND_FACTORY.calcAddress(IDiamondFactoryPackage(SELF), args_)) {
            revert InvalidMigrationPackageArguments();
        }
        _requireArgs(_decodeArgs(args_));
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory args = _decodeArgs(initArgs);
        if (msg.sender != address(DIAMOND_FACTORY) || address(this) == SELF || address(this).code.length != 0
            || MigrationRepo._layoutStruct().weth != address(0)
            || address(DIAMOND_FACTORY.pkgOfAccount(address(this))) != SELF
            || keccak256(DIAMOND_FACTORY.pkgArgsOfAccount(address(this))) != keccak256(initArgs)) {
            revert InvalidMigrationPackageArguments();
        }
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
            if (address(this) != SELF || msg.sender != address(DIAMOND_FACTORY)
                || address(DIAMOND_FACTORY.pkgOfAccount(expectedProxy)) != SELF) revert InvalidMigrationPackageArguments();
            IPostDeployAccountHook(expectedProxy).postDeploy();
            return true;
        }
        if (msg.sender != SELF) revert InvalidMigrationPackageArguments();
        IUniswapV4Detf self_ = IUniswapV4Detf(address(this));
        PkgArgs memory args_ = _decodeArgs(DIAMOND_FACTORY.pkgArgsOfAccount(address(this)));
        MigrationSYPackage.Preparation memory prepared_ = _requirePreparation(args_);
        SyConstruction memory construction_ = MigrationSYPackage(address(SY_PKG)).construction(SELF, args_);
        MigrationSYPackage(address(SY_PKG)).validateBond(
            prepared_.bond, prepared_.bondPackage, construction_.bondArgs, false, address(0)
        );
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
        _validatePreparedChildren(s_, sy_, self_);
        MigrationSYPackage(address(SY_PKG)).validateBond(
            address(s_.bondNftVault), prepared_.bondPackage, construction_.bondArgs, true, s_.creator
        );
        return true;
    }

    function _requirePreparation(PkgArgs memory args_) private view returns (MigrationSYPackage.Preparation memory p_) {
        bytes32 id_ = keccak256(abi.encode(block.chainid, SELF, args_));
        p_ = MigrationSYPackage(address(SY_PKG)).preparation(id_);
        SyConstruction memory c_ = MigrationSYPackage(address(SY_PKG)).construction(SELF, args_);
        if (!p_.completed || p_.constructionId != id_ || p_.parentPackage != SELF
            || p_.parent != c_.parent || p_.bond != c_.bond || p_.receipt != c_.receipt
            || p_.bondPackage != address(BOND_NFT_VAULT_PKG)
            || p_.bondArgsHash != keccak256(abi.encode(c_.bondArgs))
            || p_.rawArgsHash != keccak256(abi.encode(c_.rawArgs))
            || p_.stakingArgsHash != keccak256(abi.encode(c_.stakingArgs))) {
            revert MigrationPreparationRequired(id_);
        }
    }

    function _validatePreparedChildren(Repo.Storage storage s_, DETFChildSYRepo.Storage storage sy_,
        IUniswapV4Detf self_) private view
    {
        PkgArgs memory args_ = _decodeArgs(DIAMOND_FACTORY.pkgArgsOfAccount(address(this)));
        MigrationSYPackage.Preparation memory p_ = _requirePreparation(args_);
        if (p_.parent != address(this) || p_.bond != address(s_.bondNftVault)
            || p_.receipt != address(s_.rebasingClaimToken) || p_.rawSy != sy_.rawSY || p_.stakingSy != sy_.stakingSY) {
            revert InvalidMigrationChild(address(SY_PKG));
        }
        IDETFSYDFPkg.PkgArgs memory a_ = IDETFSYDFPkg.PkgArgs(
            IERC20(address(this)), IStakedDETF(address(s_.rebasingClaimToken)), false,
            string.concat("SY ", IERC20Metadata(address(this)).name()),
            string.concat("SY-", IERC20Metadata(address(this)).symbol()),
            s_.mintTable.tokens._values(), s_.burnTable.tokens._values()
        );
        if (keccak256(abi.encode(a_)) != p_.rawArgsHash) revert InvalidMigrationChild(sy_.rawSY);
        MigrationSYPackage(address(SY_PKG)).validateChild(sy_.rawSY, a_);
        a_.isStaking = true;
        a_.name = string.concat("SY Staked ", IERC20Metadata(address(this)).name());
        a_.symbol = string.concat("SY-s", IERC20Metadata(address(this)).symbol());
        if (keccak256(abi.encode(a_)) != p_.stakingArgsHash) revert InvalidMigrationChild(sy_.stakingSY);
        MigrationSYPackage(address(SY_PKG)).validateChild(sy_.stakingSY, a_);
        address[5] memory children_ = [p_.bond, p_.receipt, MigrationRepo._layoutStruct().rewardToken, p_.rawSy, p_.stakingSy];
        for (uint256 i_; i_ < children_.length; ++i_) {
            if (children_[i_] == address(this) || children_[i_] == address(0)) revert InvalidMigrationChild(children_[i_]);
            for (uint256 j_; j_ < i_; ++j_) {
                if (children_[i_] == children_[j_]) revert InvalidMigrationChild(children_[i_]);
            }
            if (IUniswapV4DetfMigrationAccounting(children_[i_]).migrationAccountingPhase() != 0) {
                revert InvalidMigrationChild(children_[i_]);
            }
        }
        address feeTo_ = address(FEE_ORACLE.feeTo());
        if (IStakedDETF(p_.receipt).detf() != address(this) || IERC20(p_.receipt).totalSupply() != 0
            || IStakedDETF(p_.receipt).stakingState().accountedBacking != 0
            || IStakedDETF(p_.receipt).stakingState().totalGons != 0
            || IERC721(p_.bond).ownerOf(0) != p_.bond || IERC721(p_.bond).ownerOf(1) != feeTo_
            || IERC721(p_.bond).ownerOf(2) != (s_.creator == address(0) ? feeTo_ : s_.creator)
            || self_.rebasingClaimToken() != p_.receipt) revert InvalidMigrationChild(p_.receipt);
    }
    function _requireArgs(PkgArgs memory args_) private pure {
        if (args_.owner == address(0) || args_.weth == address(0) || args_.originalDtf == address(0)
            || args_.weth == args_.originalDtf) revert InvalidMigrationPackageArguments();
    }
}
