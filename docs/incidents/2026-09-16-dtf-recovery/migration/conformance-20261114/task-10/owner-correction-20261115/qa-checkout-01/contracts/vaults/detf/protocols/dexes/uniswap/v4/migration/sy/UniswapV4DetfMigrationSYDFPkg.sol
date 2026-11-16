// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC721Metadata} from "@crane/contracts/interfaces/IERC721Metadata.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {DETFSYRepo} from "contracts/vaults/detf/common/sy/DETFSYRepo.sol";
import {IDETFSYDFPkg} from "contracts/vaults/detf/common/sy/IDETFSYDFPkg.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IDETFNFTVaultDFPkg} from "contracts/vaults/detf/common/bondNft/IDETFNFTVaultDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/IRebasingClaimTokenDFPkg.sol";
import {DETFChildTokenMetadata as Metadata} from "contracts/vaults/detf/common/DETFChildTokenMetadata.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4Detf, IUniswapV4DetfDFPkg} from "../../detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4DetfProcessArgsLib as ArgsLib} from "../../detf/UniswapV4DetfProcessArgsLib.sol";
import {IUniswapV4DetfMigrationDFPkg as ParentPackage} from "../interfaces/IUniswapV4DetfMigrationDFPkg.sol";
import {IUniswapV4DetfMigrationSY} from "./IUniswapV4DetfMigrationSY.sol";
import {IUniswapV4DetfMigrationSYDFPkg} from "./IUniswapV4DetfMigrationSYDFPkg.sol";
import {IUniswapV4DetfMigrationBondNFTVault} from "../bondNft/IUniswapV4DetfMigrationBondNFTVault.sol";

/// @notice Registered Migration SY composition with fixed pre-parent construction evidence.
/// @dev No preparation endpoint is installed on a proxy. All authorization is on immutable SELF.
contract UniswapV4DetfMigrationSYDFPkg is IUniswapV4DetfMigrationSYDFPkg, IStandardVaultPkg {
    IFacet private immutable DOMAIN_FACET;
    IFacet private immutable PERMIT_FACET;
    IFacet private immutable SY_FACET;
    IVaultFeeOracleQuery private immutable FEE_ORACLE;
    IVaultRegistryDeployment private immutable REGISTRY;
    IDiamondPackageCallBackFactory private immutable FACTORY;
    IUniswapV4DetfMigrationSYDFPkg private immutable SELF;
    mapping(bytes32 => Preparation) private preparations;
    mapping(bytes32 => address) private children;
    bool private preparing;

    constructor(MigrationPkgInit memory init_) {
        DOMAIN_FACET = init_.baseInit.erc5267Facet;
        PERMIT_FACET = init_.baseInit.erc2612Facet;
        SY_FACET = init_.baseInit.syFacet;
        FEE_ORACLE = init_.baseInit.feeOracle;
        REGISTRY = init_.baseInit.vaultRegistryDeployment;
        FACTORY = init_.diamondFactory;
        SELF = IUniswapV4DetfMigrationSYDFPkg(address(this));
        if (address(DOMAIN_FACET) == address(0) || address(PERMIT_FACET) == address(0)
            || address(SY_FACET) == address(0) || address(FEE_ORACLE) == address(0)
            || address(REGISTRY) == address(0) || address(FACTORY) == address(0)) revert InvalidSyConstruction();
    }

    function diamondFactory() external view returns (IDiamondPackageCallBackFactory) { return FACTORY; }
    function preparation(bytes32 id_) external view returns (Preparation memory) { return preparations[id_]; }
    function authorizedChild(bytes32 hash_) external view returns (address) { return children[hash_]; }

    function prepare(ParentPackage.PkgArgs memory args_) external returns (Preparation memory p_) {
        if (address(this) != address(SELF)) revert InvalidSyConstruction();
        if (preparing) revert SyPreparationBusy();
        if (!IVaultRegistryVaultPackageQuery(address(REGISTRY)).isPackage(msg.sender)
            || ParentPackage(msg.sender).syPackage() != address(SELF)) revert InvalidSyConstruction();
        ParentPackage.SyConstruction memory c_ = construction(msg.sender, args_);
        address parent_ = FACTORY.calcAddress(IDiamondFactoryPackage(msg.sender), abi.encode(args_));
        bytes32 id_ = keccak256(abi.encode(block.chainid, msg.sender, args_));
        if (c_.constructionId != id_ || c_.parent != parent_ || parent_.code.length != 0
            || address(c_.rawArgs.detf) != parent_ || address(c_.stakingArgs.detf) != parent_
            || address(c_.rawArgs.staking) != c_.receipt || address(c_.stakingArgs.staking) != c_.receipt
            || c_.rawArgs.isStaking || !c_.stakingArgs.isStaking) revert InvalidSyConstruction();
        p_ = preparations[id_];
        address bondPackage_ = ParentPackage(msg.sender).preparationDependencies().bondPackage;
        if (p_.completed) {
            if (p_.bondPackage != bondPackage_ || p_.bond != c_.bond
                || p_.bondArgsHash != keccak256(abi.encode(c_.bondArgs))
                || p_.parentPackage != msg.sender || p_.parent != parent_ || p_.constructionId != id_
                || p_.receipt != c_.receipt || p_.rawArgsHash != keccak256(abi.encode(c_.rawArgs))
                || p_.stakingArgsHash != keccak256(abi.encode(c_.stakingArgs))) revert InvalidSyConstruction();
            validateBond(p_.bond, bondPackage_, c_.bondArgs, false, address(0));
            validateChild(p_.rawSy, c_.rawArgs);
            validateChild(p_.stakingSy, c_.stakingArgs);
            return p_;
        }
        if (p_.parent != address(0)) revert SyPreparationBusy();
        preparing = true;
        p_ = Preparation({
            parentPackage: msg.sender, constructionId: id_, parent: parent_, bond: c_.bond, receipt: c_.receipt,
            bondPackage: bondPackage_, bondArgsHash: keccak256(abi.encode(c_.bondArgs)),
            rawSy: FACTORY.calcAddress(SELF, abi.encode(c_.rawArgs)),
            stakingSy: FACTORY.calcAddress(SELF, abi.encode(c_.stakingArgs)),
            rawArgsHash: keccak256(abi.encode(c_.rawArgs)),
            stakingArgsHash: keccak256(abi.encode(c_.stakingArgs)), completed: false
        });
        if (p_.rawSy == p_.stakingSy || children[p_.rawArgsHash] != address(0)
            || children[p_.stakingArgsHash] != address(0)) revert InvalidSyConstruction();
        preparations[id_] = p_;
        children[p_.rawArgsHash] = p_.rawSy;
        children[p_.stakingArgsHash] = p_.stakingSy;
        if (IDETFNFTVaultDFPkg(bondPackage_).deployVault(
            c_.bondArgs.name, c_.bondArgs.symbol, c_.bondArgs.detf, c_.bondArgs.lpToken
        ) != p_.bond) revert InvalidSyConstruction();
        validateBond(p_.bond, bondPackage_, c_.bondArgs, false, address(0));
        if (_deploy(c_.rawArgs) != p_.rawSy || _deploy(c_.stakingArgs) != p_.stakingSy) {
            revert InvalidSyConstruction();
        }
        validateChild(p_.rawSy, c_.rawArgs);
        validateChild(p_.stakingSy, c_.stakingArgs);
        validateBond(p_.bond, bondPackage_, c_.bondArgs, false, address(0));
        p_.completed = true;
        preparations[id_].completed = true;
        preparing = false;
    }

    function construction(address parentPackage_, ParentPackage.PkgArgs memory args_) public view returns (ParentPackage.SyConstruction memory c_) {
        if (args_.owner == address(0) || args_.weth == address(0) || args_.originalDtf == address(0)
            || args_.weth == args_.originalDtf) revert ParentPackage.InvalidMigrationPackageArguments();
        ParentPackage.PreparationDependencies memory d_ = ParentPackage(parentPackage_).preparationDependencies();
        if (d_.syPackage != address(SELF) || d_.feeOracle != address(FEE_ORACLE)
            || !IVaultRegistryVaultPackageQuery(address(REGISTRY)).isPackage(parentPackage_)) revert InvalidSyConstruction();
        c_.constructionId = keccak256(abi.encode(block.chainid, parentPackage_, args_));
        c_.parent = FACTORY.calcAddress(IDiamondFactoryPackage(parentPackage_), abi.encode(args_));
        IUniswapV4Detf.PkgArgs memory a_ = args_.baseArgs;
        ArgsLib.requireHookShape(a_.hook);
        ArgsLib.requireLiquidityPolicy(a_.hook, a_.ownerOnlyLiquidity);
        ArgsLib.requireDetfSelfLegAndOwner(a_.hook, c_.parent);
        ArgsLib.requireCreationRates(a_, IUniswapV4SeBufferHook(a_.hook).tokens().length - 1);
        c_.bondArgs = IDETFNFTVaultDFPkg.PkgArgs({
                name: Metadata.resolveBondName(a_.bondName, a_.name),
                symbol: Metadata.resolveBondSymbol(a_.bondSymbol, a_.symbol),
                detf: IDetf(c_.parent), lpToken: IERC20(a_.hook)
            });
        c_.bond = FACTORY.calcAddress(IDiamondFactoryPackage(d_.bondPackage), abi.encode(c_.bondArgs));
        c_.receipt = FACTORY.calcAddress(IDiamondFactoryPackage(d_.receiptPackage),
            abi.encode(IRebasingClaimTokenDFPkg.PkgArgs({
                detf: IDetf(c_.parent), nftVault: IDETFNFTVault(c_.bond), feeOracle: FEE_ORACLE,
                name: Metadata.resolveClaimName(a_.claimName, a_.name),
                symbol: Metadata.resolveClaimSymbol(a_.claimSymbol, a_.symbol),
                optionalSalt: keccak256(abi.encode(c_.parent))
            })));
        address[] memory inputs_ = _routeTokens(a_.hook, c_.parent, a_.mintRouteMode, a_.mintRoutes);
        address[] memory outputs_ = _routeTokens(a_.hook, c_.parent, a_.burnRouteMode, a_.burnRoutes);
        c_.rawArgs = IDETFSYDFPkg.PkgArgs(IERC20(c_.parent), IStakedDETF(c_.receipt), false,
            string.concat("SY ", a_.name), string.concat("SY-", a_.symbol), inputs_, outputs_);
        c_.stakingArgs = IDETFSYDFPkg.PkgArgs(IERC20(c_.parent), IStakedDETF(c_.receipt), true,
            string.concat("SY Staked ", a_.name), string.concat("SY-s", a_.symbol), inputs_, outputs_);
    }

    /// @dev Memory counterpart of ArgsLib's ordered sets; never writes package/factory routes.
    function _routeTokens(address hook_, address parent_, IUniswapV4Detf.RouteTableMode mode_,
        IUniswapV4Detf.IoRoute[] memory rows_) private view returns (address[] memory tokens_)
    {
        address[] memory pairs_ = IUniswapV4SeBufferHook(hook_).tokens();
        if (mode_ == IUniswapV4Detf.RouteTableMode.Custom) {
            tokens_ = new address[](rows_.length);
            for (uint256 i_; i_ < rows_.length; ++i_) {
                address token_ = address(rows_[i_].token);
                address vault_ = address(rows_[i_].vault);
                if (token_ == address(0) || vault_ == address(0)) revert IUniswapV4DetfDFPkg.ZeroAddress();
                if (token_ == parent_) revert IUniswapV4DetfDFPkg.InvalidRouteTable();
                bool member_;
                for (uint256 j_; j_ < pairs_.length; ++j_) {
                    if (pairs_[j_] != parent_ && IUniswapV4SeBufferHook(hook_).standardExchangeOf(pairs_[j_]) == vault_) {
                        member_ = true; break;
                    }
                }
                if (!member_) revert IUniswapV4DetfDFPkg.InvalidRouteTable();
                if (token_ == vault_) {
                    IStandardExchange(vault_).previewExchangeIn(IERC20(vault_), 1e18, IERC20(vault_));
                } else {
                    address[] memory listed_ = IBasicVault(vault_).vaultTokens();
                    bool listedToken_;
                    for (uint256 j_; j_ < listed_.length; ++j_) if (listed_[j_] == token_) { listedToken_ = true; break; }
                    if (!listedToken_) revert IUniswapV4DetfDFPkg.InvalidRouteTable();
                    (uint256 out_,) = IStandardExchangeIn(vault_).previewExchangeIn(IERC20(token_), 1e18, IERC20(vault_));
                    if (out_ == 0) revert IUniswapV4DetfDFPkg.InvalidRouteTable();
                }
                for (uint256 j_; j_ < i_; ++j_) {
                    if (tokens_[j_] == token_) revert IUniswapV4DetfDFPkg.DuplicateRoute(token_);
                }
                tokens_[i_] = token_;
            }
            return tokens_;
        }
        tokens_ = new address[](2 * pairs_.length);
        uint256 count_;
        for (uint256 i_; i_ < pairs_.length; ++i_) {
            if (pairs_[i_] == parent_) continue;
            address se_ = IUniswapV4SeBufferHook(hook_).standardExchangeOf(pairs_[i_]);
            address[2] memory row_ = [pairs_[i_], se_];
            for (uint256 j_; j_ < 2; ++j_) {
                bool present_;
                for (uint256 k_; k_ < count_; ++k_) if (tokens_[k_] == row_[j_]) { present_ = true; break; }
                if (!present_) tokens_[count_++] = row_[j_];
            }
        }
        assembly { mstore(tokens_, count_) }
    }
    function deployVault(IDETFSYDFPkg.PkgArgs memory args_) external returns (address) {
        if (address(this) != address(SELF)) revert InvalidSyConstruction();
        if (preparing) revert SyPreparationBusy();
        _expected(abi.encode(args_));
        return _deploy(args_);
    }

    function _deploy(IDETFSYDFPkg.PkgArgs memory args_) private returns (address) {
        return REGISTRY.deployVault(IStandardVaultPkg(address(SELF)), abi.encode(args_));
    }

    function packageName() public pure returns (string memory) { return type(UniswapV4DetfMigrationSYDFPkg).name; }
    function name() public pure returns (string memory) { return packageName(); }
    function vaultFeeTypeIds() public pure returns (bytes32) { return bytes32(0); }
    function vaultTypes() public view returns (bytes4[] memory) { return facetInterfaces(); }
    function vaultDeclaration() public view returns (VaultPkgDeclaration memory) {
        return VaultPkgDeclaration(name(), vaultFeeTypeIds(), vaultTypes());
    }
    function facetAddresses() public view returns (address[] memory facets_) {
        facets_ = new address[](3);
        facets_[0] = address(DOMAIN_FACET);
        facets_[1] = address(PERMIT_FACET);
        facets_[2] = address(SY_FACET);
    }
    function facetInterfaces() public view returns (bytes4[] memory ids_) {
        bytes4[] memory selected_ = SY_FACET.facetInterfaces();
        ids_ = new bytes4[](6 + selected_.length);
        ids_[0] = type(IERC20).interfaceId;
        ids_[1] = type(IERC20Metadata).interfaceId;
        ids_[2] = type(IERC20Permit).interfaceId;
        ids_[3] = type(IERC5267).interfaceId;
        ids_[4] = type(IStandardizedYield).interfaceId;
        ids_[5] = type(IStandardVault).interfaceId;
        uint256 count_ = 6;
        for (uint256 i_; i_ < selected_.length; ++i_) {
            bool present_;
            for (uint256 j_; j_ < count_; ++j_) {
                if (ids_[j_] == selected_[i_]) { present_ = true; break; }
            }
            if (!present_) ids_[count_++] = selected_[i_];
        }
        assembly { mstore(ids_, count_) }
    }
    function packageMetadata() public view returns (string memory, bytes4[] memory, address[] memory) {
        return (packageName(), facetInterfaces(), facetAddresses());
    }
    function facetCuts() public view returns (IDiamond.FacetCut[] memory cuts_) {
        address[] memory facets_ = facetAddresses();
        cuts_ = new IDiamond.FacetCut[](facets_.length);
        for (uint256 i_; i_ < facets_.length; ++i_) {
            cuts_[i_] = IDiamond.FacetCut(facets_[i_], IDiamond.FacetCutAction.Add, IFacet(facets_[i_]).facetFuncs());
        }
    }
    function diamondConfig() public view returns (DiamondConfig memory) {
        return DiamondConfig(facetCuts(), facetInterfaces());
    }
    function calcSalt(bytes memory args_) public pure returns (bytes32) { return keccak256(abi.encode(args_)); }

    function _expected(bytes memory encoded_) private view returns (address child_) {
        IDETFSYDFPkg.PkgArgs memory a_ = abi.decode(encoded_, (IDETFSYDFPkg.PkgArgs));
        bytes32 hash_ = keccak256(encoded_);
        if (hash_ != keccak256(abi.encode(a_))) revert InvalidSyConstruction();
        // processArgs/initAccount execute in factory/proxy storage, never in this mapping.
        child_ = SELF.authorizedChild(hash_);
        if (child_ == address(0) || child_ != FACTORY.calcAddress(SELF, encoded_)) revert InvalidSyConstruction();
    }

    function processArgs(bytes memory args_) public view returns (bytes memory) {
        if (address(this) != address(FACTORY) || msg.sender != address(REGISTRY)) revert InvalidSyConstruction();
        _expected(args_);
        return args_;
    }

    function updatePkg(address account_, bytes memory args_) public view returns (bool) {
        if (address(this) != address(SELF) || msg.sender != address(FACTORY)
            || account_.code.length != 0 || account_ != _expected(args_)
            || address(FACTORY.pkgOfAccount(account_)) != address(SELF)
            || keccak256(FACTORY.pkgArgsOfAccount(account_)) != keccak256(args_)) revert InvalidSyConstruction();
        return true;
    }

    function initAccount(bytes memory args_) public {
        if (msg.sender != address(FACTORY) || address(this) == address(SELF) || address(this).code.length != 0
            || address(this) != _expected(args_) || address(DETFSYRepo._layoutStruct().detf) != address(0)
            || address(FACTORY.pkgOfAccount(address(this))) != address(SELF)
            || keccak256(FACTORY.pkgArgsOfAccount(address(this))) != keccak256(args_)) revert InvalidSyConstruction();
        IDETFSYDFPkg.PkgArgs memory a_ = abi.decode(args_, (IDETFSYDFPkg.PkgArgs));
        ERC20Repo._initialize(a_.name, a_.symbol, 9);
        EIP712Repo._initialize(a_.name, "1");
        address[] memory contents_ = new address[](1);
        contents_[0] = address(a_.detf);
        StandardVaultRepo._initialize(FEE_ORACLE, vaultFeeTypeIds(), vaultTypes(), keccak256(abi.encode(contents_)));
        // The immutable construction proof replaces only the absent receipt's detf() read.
        // Canonical raw initialization still performs ordered-set deduplication and route rejection.
        DETFSYRepo._initialize(a_.detf, a_.staking, false,
            a_.isStaking ? _prependReceipt(address(a_.staking), a_.tokensIn) : a_.tokensIn,
            a_.isStaking ? _prependReceipt(address(a_.staking), a_.tokensOut) : a_.tokensOut);
        DETFSYRepo._layoutStruct().isStaking = a_.isStaking;
    }

    function postDeploy(address account_) public view returns (bool) {
        if (address(this) != address(SELF) || msg.sender != address(FACTORY)
            || address(FACTORY.pkgOfAccount(account_)) != address(SELF)) revert InvalidSyConstruction();
        return true;
    }

    function _prependReceipt(address receipt_, address[] memory routes_) private pure returns (address[] memory tokens_) {
        tokens_ = new address[](routes_.length + 1);
        tokens_[0] = receipt_;
        for (uint256 i_; i_ < routes_.length; ++i_) tokens_[i_ + 1] = routes_[i_];
    }

    function _tokens(IDETFSYDFPkg.PkgArgs memory a_, address[] memory routes_)
        private pure returns (address[] memory tokens_)
    {
        tokens_ = new address[](routes_.length + 2);
        tokens_[0] = address(a_.detf);
        uint256 count_ = 1;
        if (a_.isStaking && address(a_.staking) != tokens_[0]) tokens_[count_++] = address(a_.staking);
        for (uint256 i_; i_ < routes_.length; ++i_) {
            bool present_;
            for (uint256 j_; j_ < count_; ++j_) if (tokens_[j_] == routes_[i_]) { present_ = true; break; }
            if (!present_) tokens_[count_++] = routes_[i_];
        }
        assembly { mstore(tokens_, count_) }
    }

    /// @notice Explicit reuse validation: the factory returns existing children before callbacks.
    function validateBond(address bond_, address package_, IDETFNFTVaultDFPkg.PkgArgs memory a_,
        bool reserved_, address creator_) public view
    {
        bytes memory encoded_ = abi.encode(a_);
        IUniswapV4DetfMigrationBondNFTVault b_ = IUniswapV4DetfMigrationBondNFTVault(bond_);
        if (bond_.code.length == 0 || bond_ != FACTORY.calcAddress(IDiamondFactoryPackage(package_), encoded_)
            || address(FACTORY.pkgOfAccount(bond_)) != package_
            || keccak256(FACTORY.pkgArgsOfAccount(bond_)) != keccak256(encoded_)
            || b_.detf() != address(a_.detf) || address(b_.lpToken()) != address(a_.lpToken)
            || keccak256(bytes(IERC721Metadata(bond_).name())) != keccak256(bytes(a_.name))
            || keccak256(bytes(IERC721Metadata(bond_).symbol())) != keccak256(bytes(a_.symbol))
            || b_.attributedBondGons() != 0 || b_.migrationAccountingPhase() != 0
            || b_.reservedBondNftsWired() != reserved_ || b_.ownerOf(3) != address(0)
            || !IVaultRegistryVaultQuery(address(REGISTRY)).isVault(bond_)) revert InvalidSyConstruction();
        address feeTo_ = reserved_ ? address(FEE_ORACLE.feeTo()) : address(0);
        if (b_.ownerOf(0) != (reserved_ ? bond_ : address(0)) || b_.ownerOf(1) != feeTo_
            || b_.ownerOf(2) != (reserved_ && creator_ != address(0) ? creator_ : feeTo_)) {
            revert InvalidSyConstruction();
        }
        address[] memory registered_ = IVaultRegistryVaultQuery(address(REGISTRY)).vaultsOfPackage(package_);
        bool found_;
        for (uint256 i_; i_ < registered_.length; ++i_) if (registered_[i_] == bond_) { found_ = true; break; }
        if (!found_) revert InvalidSyConstruction();
        address[] memory tokens_ = new address[](1);
        tokens_[0] = address(a_.lpToken);
        IStandardVault.VaultConfig memory config_ = IStandardVault(bond_).vaultConfig();
        if (config_.vaultFeeTypeIds != IStandardVaultPkg(package_).vaultFeeTypeIds()
            || config_.contentsId != keccak256(abi.encode(tokens_))
            || keccak256(abi.encode(config_.tokens)) != keccak256(abi.encode(tokens_))
            || keccak256(abi.encode(config_.vaultTypes)) != keccak256(abi.encode(IStandardVaultPkg(package_).vaultTypes()))) {
            revert InvalidSyConstruction();
        }
        // Validate the final result of ordered Add/Replace cuts, not each historical owner.
        IDiamond.FacetCut[] memory base_ = IDiamondFactoryPackage(address(FACTORY)).facetCuts();
        IDiamond.FacetCut[] memory selected_ = IDiamondFactoryPackage(package_).facetCuts();
        IDiamond.FacetCut[] memory cuts_ = new IDiamond.FacetCut[](base_.length + selected_.length);
        for (uint256 i_; i_ < base_.length; ++i_) cuts_[i_] = base_[i_];
        for (uint256 i_; i_ < selected_.length; ++i_) cuts_[base_.length + i_] = selected_[i_];
        uint256 count_;
        for (uint256 i_; i_ < cuts_.length; ++i_) {
            for (uint256 j_; j_ < cuts_[i_].functionSelectors.length; ++j_) {
                bytes4 selector_ = cuts_[i_].functionSelectors[j_];
                if (selector_ == IPostDeployAccountHook.postDeploy.selector) continue;
                bool replaced_;
                for (uint256 k_ = i_ + 1; k_ < cuts_.length; ++k_) {
                    for (uint256 l_; l_ < cuts_[k_].functionSelectors.length; ++l_) {
                        if (cuts_[k_].functionSelectors[l_] == selector_) { replaced_ = true; break; }
                    }
                    if (replaced_) break;
                }
                if (replaced_) continue;
                if (IDiamondLoupe(bond_).facetAddress(selector_) != cuts_[i_].facetAddress) revert InvalidSyConstruction();
                ++count_;
            }
        }
        IDiamondLoupe.Facet[] memory actual_ = IDiamondLoupe(bond_).facets();
        uint256 actualCount_;
        for (uint256 i_; i_ < actual_.length; ++i_) actualCount_ += actual_[i_].functionSelectors.length;
        if (actualCount_ != count_
            || IDiamondLoupe(bond_).facetAddress(IPostDeployAccountHook.postDeploy.selector) != address(0)) {
            revert InvalidSyConstruction();
        }
        bytes4[] memory interfaces_ = IDiamondFactoryPackage(package_).facetInterfaces();
        for (uint256 i_; i_ < interfaces_.length; ++i_) {
            if (!IERC165(bond_).supportsInterface(interfaces_[i_])) revert InvalidSyConstruction();
        }
        interfaces_ = IFacet(address(FACTORY)).facetInterfaces();
        for (uint256 i_; i_ < interfaces_.length; ++i_) {
            if (!IERC165(bond_).supportsInterface(interfaces_[i_])) revert InvalidSyConstruction();
        }
    }

    /// @notice Explicit reuse validation: the factory returns existing children before callbacks.
    function validateChild(address child_, IDETFSYDFPkg.PkgArgs memory a_) public view {
        bytes memory encoded_ = abi.encode(a_);
        IUniswapV4DetfMigrationSY sy_ = IUniswapV4DetfMigrationSY(child_);
        if (child_ != _expected(encoded_) || address(FACTORY.pkgOfAccount(child_)) != address(SELF)
            || keccak256(FACTORY.pkgArgsOfAccount(child_)) != keccak256(encoded_)
            || sy_.yieldToken() != (a_.isStaking ? address(a_.staking) : address(a_.detf))
            || IERC20Metadata(child_).decimals() != 9
            || keccak256(bytes(IERC20Metadata(child_).name())) != keccak256(bytes(a_.name))
            || keccak256(bytes(IERC20Metadata(child_).symbol())) != keccak256(bytes(a_.symbol))
            || IERC20(child_).totalSupply() != 0 || sy_.attributedSyGons() != 0
            || sy_.migrationAccountingPhase() != 0
            || keccak256(abi.encode(sy_.getTokensIn())) != keccak256(abi.encode(_tokens(a_, a_.tokensIn)))
            || keccak256(abi.encode(sy_.getTokensOut())) != keccak256(abi.encode(_tokens(a_, a_.tokensOut)))) {
            revert InvalidSyConstruction();
        }
        (IStandardizedYield.AssetType kind_, address asset_, uint8 decimals_) = sy_.assetInfo();
        if (kind_ != IStandardizedYield.AssetType.TOKEN || asset_ != address(a_.detf) || decimals_ != 9
            || IDiamondLoupe(child_).facetAddress(IPostDeployAccountHook.postDeploy.selector) != address(0)) {
            revert InvalidSyConstruction();
        }
        IDiamond.FacetCut[] memory cuts_ = facetCuts();
        for (uint256 i_; i_ < cuts_.length; ++i_) {
            for (uint256 j_; j_ < cuts_[i_].functionSelectors.length; ++j_) {
                if (IDiamondLoupe(child_).facetAddress(cuts_[i_].functionSelectors[j_]) != cuts_[i_].facetAddress) {
                    revert InvalidSyConstruction();
                }
            }
        }
        bytes4[] memory interfaces_ = facetInterfaces();
        for (uint256 i_; i_ < interfaces_.length; ++i_) {
            if (!IERC165(child_).supportsInterface(interfaces_[i_])) revert InvalidSyConstruction();
        }
        // Before parent construction every accounting mutation synchronizes the absent parent
        // and reverts. Approvals cannot change backing/dust/cursors. At final publication, the
        // fixed canonical initializer, unchanged facets and zero supply prove their zero state.
    }
}
