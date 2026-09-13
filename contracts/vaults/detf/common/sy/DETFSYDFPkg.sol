// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IDETFSYDFPkg} from "contracts/vaults/detf/common/sy/IDETFSYDFPkg.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {DETFSYRepo} from "contracts/vaults/detf/common/sy/DETFSYRepo.sol";



/// @title DETFSYDFPkg
/// @notice Registered immutable SY deployment. Underlying DETF economics charge route fees once.
contract DETFSYDFPkg is IDETFSYDFPkg, IStandardVaultPkg {
    using BetterEfficientHashLib for bytes;

    error NotCalledByRegistry(address caller);
    error InvalidPackageArguments();

    IFacet private immutable DOMAIN_FACET;
    IFacet private immutable PERMIT_FACET;
    IFacet private immutable SY_FACET;
    IVaultFeeOracleQuery private immutable FEE_ORACLE;
    IVaultRegistryDeployment private immutable REGISTRY;

    constructor(PkgInit memory init_) {
        DOMAIN_FACET = init_.erc5267Facet;
        PERMIT_FACET = init_.erc2612Facet;
        SY_FACET = init_.syFacet;
        FEE_ORACLE = init_.feeOracle;
        REGISTRY = init_.vaultRegistryDeployment;
    }

    /// @inheritdoc IDETFSYDFPkg
    function deployVault(PkgArgs memory args_) external returns (address) {
        return address(REGISTRY.deployVault(IStandardVaultPkg(address(this)), abi.encode(args_)));
    }

    /// @inheritdoc IDiamondFactoryPackage
    function packageName() public pure returns (string memory) { return type(DETFSYDFPkg).name; }

    /// @inheritdoc IDiamondFactoryPackage
    function facetAddresses() public view returns (address[] memory facets_) {
        facets_ = new address[](3);
        facets_[0] = address(DOMAIN_FACET);
        facets_[1] = address(PERMIT_FACET);
        facets_[2] = address(SY_FACET);
    }

    /// @inheritdoc IDiamondFactoryPackage
    function facetInterfaces() public pure returns (bytes4[] memory ids_) {
        ids_ = new bytes4[](6);
        ids_[0] = type(IERC20).interfaceId;
        ids_[1] = type(IERC20Metadata).interfaceId;
        ids_[2] = type(IERC20Permit).interfaceId;
        ids_[3] = type(IERC5267).interfaceId;
        ids_[4] = type(IStandardizedYield).interfaceId;
        ids_[5] = type(IStandardVault).interfaceId;
    }

    /// @inheritdoc IDiamondFactoryPackage
    function packageMetadata() public view returns (string memory, bytes4[] memory, address[] memory) {
        return (packageName(), facetInterfaces(), facetAddresses());
    }

    /// @inheritdoc IDiamondFactoryPackage
    function facetCuts() public view returns (IDiamond.FacetCut[] memory cuts_) {
        address[] memory facets_ = facetAddresses();
        cuts_ = new IDiamond.FacetCut[](facets_.length);
        for (uint256 i; i < facets_.length; ++i) {
            cuts_[i] = IDiamond.FacetCut(facets_[i], IDiamond.FacetCutAction.Add, IFacet(facets_[i]).facetFuncs());
        }
    }

    /// @inheritdoc IDiamondFactoryPackage
    function diamondConfig() public view returns (DiamondConfig memory) {
        return DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    /// @inheritdoc IDiamondFactoryPackage
    function calcSalt(bytes memory args_) public pure returns (bytes32) { return abi.encode(args_)._hash(); }

    /// @inheritdoc IDiamondFactoryPackage
    function processArgs(bytes memory args_) public view returns (bytes memory) {
        if (msg.sender != address(REGISTRY)) revert NotCalledByRegistry(msg.sender);
        PkgArgs memory a_ = abi.decode(args_, (PkgArgs));
        if (address(a_.detf) == address(0) || IERC20Metadata(address(a_.detf)).decimals() != 9
            || (a_.isStaking && (address(a_.staking) == address(0) || a_.staking.decimals() != 9
                || a_.staking.detf() != address(a_.detf)))
            || keccak256(abi.encode(a_)) != keccak256(args_)) revert InvalidPackageArguments();
        return args_;
    }

    /// @inheritdoc IDiamondFactoryPackage
    function initAccount(bytes memory args_) public {
        PkgArgs memory a_ = abi.decode(args_, (PkgArgs));
        ERC20Repo._initialize(a_.name, a_.symbol, 9);
        EIP712Repo._initialize(a_.name, "1");
        address[] memory contents_ = new address[](1);
        contents_[0] = address(a_.detf);
        StandardVaultRepo._initialize(FEE_ORACLE, vaultFeeTypeIds(), vaultTypes(), abi.encode(contents_)._hash());
        DETFSYRepo._initialize(a_.detf, a_.staking, a_.isStaking, a_.tokensIn, a_.tokensOut);
    }

    /// @inheritdoc IDiamondFactoryPackage
    function updatePkg(address, bytes memory) public pure returns (bool) { return true; }

    /// @inheritdoc IDiamondFactoryPackage
    function postDeploy(address) public pure returns (bool) { return true; }

    /// @inheritdoc IStandardVaultPkg
    function name() public pure returns (string memory) { return packageName(); }

    /// @inheritdoc IStandardVaultPkg
    function vaultFeeTypeIds() public pure returns (bytes32) { return bytes32(0); }

    /// @inheritdoc IStandardVaultPkg
    function vaultTypes() public pure returns (bytes4[] memory) { return facetInterfaces(); }

    /// @inheritdoc IStandardVaultPkg
    function vaultDeclaration() public pure returns (VaultPkgDeclaration memory) {
        return VaultPkgDeclaration({name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()});
    }
}
