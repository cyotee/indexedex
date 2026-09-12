// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IERC721Metadata} from "@crane/contracts/interfaces/IERC721Metadata.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {ERC721MetadataRepo} from "@crane/contracts/tokens/ERC721/ERC721MetadataRepo.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {VaultFeeType} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {DETFFundedBondRepo} from "contracts/vaults/detf/common/bondNft/DETFFundedBondRepo.sol";

/// @notice Factory schema for fresh funded-bond deployments.
interface IDETFNFTVaultDFPkg is IDiamondFactoryPackage {
    struct PkgInit {
        IFacet erc721Facet;
        IFacet metadataFacet;
        IFacet detfNFTVaultFacet;
        IVaultFeeOracleQuery feeOracle;
        IVaultRegistryDeployment vaultRegistryDeployment;
    }

    struct PkgArgs {
        string name;
        string symbol;
        IDetf detf;
        IERC20 lpToken;
    }

    error NotCalledByRegistry(address caller);
    error InvalidPackageArguments();

    function deployVault(string memory name_, string memory symbol_, IDetf detf_, IERC20 lpToken_)
        external returns (address);
}

/// @title DETFNFTVaultDFPkg
/// @notice Registered NFT package with a minimal funded vesting ledger and protocol LP custody.
contract DETFNFTVaultDFPkg is IDETFNFTVaultDFPkg, IStandardVaultPkg {
    using BetterEfficientHashLib for bytes;

    IFacet private immutable ERC721_FACET;
    IFacet private immutable METADATA_FACET;
    IFacet private immutable BOND_FACET;
    IVaultFeeOracleQuery private immutable FEE_ORACLE;
    IVaultRegistryDeployment private immutable REGISTRY;

    constructor(PkgInit memory init_) {
        ERC721_FACET = init_.erc721Facet;
        METADATA_FACET = init_.metadataFacet;
        BOND_FACET = init_.detfNFTVaultFacet;
        FEE_ORACLE = init_.feeOracle;
        REGISTRY = init_.vaultRegistryDeployment;
    }

    /// @inheritdoc IDETFNFTVaultDFPkg
    function deployVault(string memory name_, string memory symbol_, IDetf detf_, IERC20 lpToken_)
        external returns (address)
    {
        return address(REGISTRY.deployVault(
            IStandardVaultPkg(address(this)), abi.encode(PkgArgs(name_, symbol_, detf_, lpToken_))
        ));
    }

    /// @inheritdoc IDiamondFactoryPackage
    function packageName() public pure virtual returns (string memory) { return type(DETFNFTVaultDFPkg).name; }

    /// @inheritdoc IDiamondFactoryPackage
    function facetAddresses() public view returns (address[] memory facets_) {
        facets_ = new address[](3);
        facets_[0] = address(ERC721_FACET);
        facets_[1] = address(BOND_FACET);
        facets_[2] = address(METADATA_FACET);
    }

    /// @inheritdoc IDiamondFactoryPackage
    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](5);
        interfaces_[0] = type(IERC721).interfaceId;
        interfaces_[1] = type(IERC721Metadata).interfaceId;
        interfaces_[2] = type(IDetfBondNFT).interfaceId;
        interfaces_[3] = type(IStandardVault).interfaceId;
        interfaces_[4] = type(IDetfNftReserveDonation).interfaceId;
    }

    /// @inheritdoc IDiamondFactoryPackage
    function packageMetadata() public view returns (string memory, bytes4[] memory, address[] memory) {
        return (packageName(), facetInterfaces(), facetAddresses());
    }

    /// @inheritdoc IDiamondFactoryPackage
    function facetCuts() public view returns (IDiamond.FacetCut[] memory cuts_) {
        cuts_ = new IDiamond.FacetCut[](4);
        cuts_[0] = IDiamond.FacetCut(address(ERC721_FACET), IDiamond.FacetCutAction.Add, ERC721_FACET.facetFuncs());
        cuts_[1] = IDiamond.FacetCut(address(BOND_FACET), IDiamond.FacetCutAction.Add, BOND_FACET.facetFuncs());
        bytes4[] memory transfers_ = new bytes4[](3);
        transfers_[0] = IERC721.transferFrom.selector;
        transfers_[1] = bytes4(keccak256("safeTransferFrom(address,address,uint256)"));
        transfers_[2] = bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)"));
        cuts_[2] = IDiamond.FacetCut(address(BOND_FACET), IDiamond.FacetCutAction.Replace, transfers_);
        cuts_[3] = IDiamond.FacetCut(address(METADATA_FACET), IDiamond.FacetCutAction.Add, METADATA_FACET.facetFuncs());
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
        PkgArgs memory decoded_ = abi.decode(args_, (PkgArgs));
        bytes memory canonical_ = abi.encode(decoded_);
        if (address(decoded_.detf) == address(0) || address(decoded_.lpToken) == address(0)
            || keccak256(canonical_) != keccak256(args_)) revert InvalidPackageArguments();
        return canonical_;
    }

    /// @inheritdoc IDiamondFactoryPackage
    function updatePkg(address, bytes memory) public pure returns (bool) { return true; }

    /// @inheritdoc IDiamondFactoryPackage
    function initAccount(bytes memory args_) public {
        PkgArgs memory decoded_ = abi.decode(args_, (PkgArgs));
        ERC721MetadataRepo._initialize(decoded_.name, decoded_.symbol);
        address[] memory contents_ = new address[](1);
        contents_[0] = address(decoded_.lpToken);
        StandardVaultRepo._initialize(FEE_ORACLE, vaultFeeTypeIds(), vaultTypes(), abi.encode(contents_)._hash());
        DETFFundedBondRepo._initialize(address(decoded_.detf), decoded_.lpToken);
    }

    /// @inheritdoc IStandardVaultPkg
    function name() public pure returns (string memory) { return packageName(); }

    /// @inheritdoc IStandardVaultPkg
    function vaultFeeTypeIds() public pure returns (bytes32 ids_) {
        return VaultTypeUtils._insertFeeTypeId(ids_, VaultFeeType.BOND, type(IDetfBondNFT).interfaceId);
    }

    /// @inheritdoc IStandardVaultPkg
    function vaultTypes() public pure returns (bytes4[] memory) { return facetInterfaces(); }

    /// @inheritdoc IStandardVaultPkg
    function vaultDeclaration() public pure returns (VaultPkgDeclaration memory) {
        return VaultPkgDeclaration({name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()});
    }

    /// @inheritdoc IDiamondFactoryPackage
    function postDeploy(address) public pure returns (bool) { return true; }
}
