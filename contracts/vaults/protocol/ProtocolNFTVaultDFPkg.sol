// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IERC721Metadata} from "@crane/contracts/interfaces/IERC721Metadata.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {ERC721Repo} from "@crane/contracts/tokens/ERC721/ERC721Repo.sol";
import {ERC721MetadataRepo} from "@crane/contracts/tokens/ERC721/ERC721MetadataRepo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {MultiStepOwnableRepo} from "@crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {VaultFeeType} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {ProtocolNFTVaultRepo} from "contracts/vaults/protocol/ProtocolNFTVaultRepo.sol";

/**
 * @title IProtocolNFTVaultDFPkg
 * @notice Interface for Protocol NFT Vault Diamond Factory Package.
 */
interface IProtocolNFTVaultDFPkg is IDiamondFactoryPackage {
    struct PkgInit {
        IFacet erc721Facet;
        IFacet erc4626BasicVaultFacet;
        IFacet erc4626StandardVaultFacet;
        IFacet protocolNFTVaultFacet;
        IVaultFeeOracleQuery feeOracle;
        IVaultRegistryDeployment vaultRegistryDeployment;
    }

    struct PkgArgs {
        string name;
        string symbol;
        /// @notice The Protocol DETF contract (CHIR) that owns this vault
        IProtocolDETF protocolDETF;
        /// @notice The LP token (BPT from the 80/20 pool)
        IERC20 lpToken;
        /// @notice The reward token (RICH)
        IERC20 rewardToken;
        /// @notice Decimal offset for share calculations
        uint8 decimalOffset;
        /// @notice Owner address (typically the DETF contract)
        address owner;
    }

    error NotCalledByRegistry(address caller);

    function deployVault(
        string memory name,
        string memory symbol,
        IProtocolDETF protocolDETF,
        IERC20 lpToken,
        IERC20 rewardToken,
        uint8 decimalOffset,
        address owner
    ) external returns (address vaultAddress);
}

/**
 * @title ProtocolNFTVaultDFPkg
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Diamond Factory Package for deploying Protocol NFT Vaults.
 */
contract ProtocolNFTVaultDFPkg is IProtocolNFTVaultDFPkg, IStandardVaultPkg {
    using BetterEfficientHashLib for bytes;
    using BetterSafeERC20 for IERC20;
    using BetterSafeERC20 for IERC20Metadata;

    bytes4 private constant _SAFE_TRANSFER_FROM_WITH_DATA_SELECTOR =
        bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)"));
    bytes4 private constant _SAFE_TRANSFER_FROM_SELECTOR =
        bytes4(keccak256("safeTransferFrom(address,address,uint256)"));

    ProtocolNFTVaultDFPkg SELF;

    IFacet immutable ERC721_FACET;
    IFacet immutable ERC4626_BASIC_VAULT_FACET;
    IFacet immutable ERC4626_STANDARD_VAULT_FACET;
    IFacet immutable PROTOCOL_NFT_VAULT_FACET;
    IVaultFeeOracleQuery immutable VAULT_FEE_ORACLE_QUERY;
    IVaultRegistryDeployment immutable VAULT_REGISTRY_DEPLOYMENT;

    constructor(PkgInit memory pkgInit) {
        SELF = this;
        ERC721_FACET = pkgInit.erc721Facet;
        ERC4626_BASIC_VAULT_FACET = pkgInit.erc4626BasicVaultFacet;
        ERC4626_STANDARD_VAULT_FACET = pkgInit.erc4626StandardVaultFacet;
        PROTOCOL_NFT_VAULT_FACET = pkgInit.protocolNFTVaultFacet;
        VAULT_FEE_ORACLE_QUERY = pkgInit.feeOracle;
        VAULT_REGISTRY_DEPLOYMENT = pkgInit.vaultRegistryDeployment;
    }

    function deployVault(
        string memory name_,
        string memory symbol,
        IProtocolDETF protocolDETF,
        IERC20 lpToken,
        IERC20 rewardToken,
        uint8 decimalOffset,
        address owner
    ) external returns (address vaultAddress) {
        return address(
            VAULT_REGISTRY_DEPLOYMENT.deployVault(
                SELF,
                abi.encode(
                    PkgArgs({
                        name: name_,
                        symbol: symbol,
                        protocolDETF: protocolDETF,
                        lpToken: lpToken,
                        rewardToken: rewardToken,
                        decimalOffset: decimalOffset,
                        owner: owner
                    })
                )
            )
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                       IDiamondFactoryPackage                           */
    /* ---------------------------------------------------------------------- */

    function packageName() public pure returns (string memory name_) {
        return type(ProtocolNFTVaultDFPkg).name;
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](4);
        facetAddresses_[0] = address(ERC721_FACET);
        facetAddresses_[1] = address(ERC4626_BASIC_VAULT_FACET);
        facetAddresses_[2] = address(ERC4626_STANDARD_VAULT_FACET);
        facetAddresses_[3] = address(PROTOCOL_NFT_VAULT_FACET);
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](5);
        interfaces[0] = type(IERC721).interfaceId;
        interfaces[1] = type(IERC721Metadata).interfaceId;
        interfaces[2] = type(IProtocolNFTVault).interfaceId;
        interfaces[3] = type(IBasicVault).interfaceId;
        interfaces[4] = type(IStandardVault).interfaceId;
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

    function facetCuts() public view returns (IDiamond.FacetCut[] memory facetCuts_) {
        facetCuts_ = new IDiamond.FacetCut[](5);

        facetCuts_[0] = IDiamond.FacetCut({
            facetAddress: address(ERC721_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC721_FACET.facetFuncs()
        });
        facetCuts_[1] = IDiamond.FacetCut({
            facetAddress: address(ERC4626_BASIC_VAULT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC4626_BASIC_VAULT_FACET.facetFuncs()
        });
        facetCuts_[2] = IDiamond.FacetCut({
            facetAddress: address(ERC4626_STANDARD_VAULT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC4626_STANDARD_VAULT_FACET.facetFuncs()
        });
        facetCuts_[3] = IDiamond.FacetCut({
            facetAddress: address(PROTOCOL_NFT_VAULT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: PROTOCOL_NFT_VAULT_FACET.facetFuncs()
        });

        // Replace ERC721 transfer selectors to prevent sending bond NFTs to the DETF.
        bytes4[] memory guardedTransferSelectors = new bytes4[](3);
        guardedTransferSelectors[0] = _SAFE_TRANSFER_FROM_WITH_DATA_SELECTOR;
        guardedTransferSelectors[1] = _SAFE_TRANSFER_FROM_SELECTOR;
        guardedTransferSelectors[2] = IERC721.transferFrom.selector;

        facetCuts_[4] = IDiamond.FacetCut({
            facetAddress: address(PROTOCOL_NFT_VAULT_FACET),
            action: IDiamond.FacetCutAction.Replace,
            functionSelectors: guardedTransferSelectors
        });
    }

    function diamondConfig() public view returns (DiamondConfig memory config) {
        config = IDiamondFactoryPackage.DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32 salt) {
        return abi.encode(pkgArgs)._hash();
    }

    function processArgs(bytes memory pkgArgs) public view virtual returns (bytes memory processedPkgArgs) {
        if (msg.sender != address(VAULT_REGISTRY_DEPLOYMENT)) {
            revert NotCalledByRegistry(msg.sender);
        }
        return pkgArgs;
    }

    function updatePkg(address, bytes memory) public pure virtual returns (bool) {
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory args = abi.decode(initArgs, (PkgArgs));

        // Initialize ownership (DETF is the owner)
        MultiStepOwnableRepo._initialize(args.owner, 1 days);

        // Initialize ERC721 metadata
        ERC721MetadataRepo._initialize(args.name, args.symbol);

        // Vault components (ERC4626-backed Basic/Standard vault views)
        ERC4626Repo._initialize(args.lpToken, IERC20Metadata(address(args.lpToken)).safeDecimals(), args.decimalOffset);
        ERC4626Repo._setLastTotalAssets(args.lpToken.balanceOf(address(this)));

        {
            address[] memory contents = new address[](1);
            contents[0] = address(args.lpToken);
            StandardVaultRepo._initialize(
                VAULT_FEE_ORACLE_QUERY, vaultFeeTypeIds(), vaultTypes(), abi.encode(contents)._hash()
            );
        }

        // Initialize Protocol NFT vault storage
        ProtocolNFTVaultRepo._initialize(args.protocolDETF, args.lpToken, args.rewardToken, args.decimalOffset);
    }

    /* ---------------------------------------------------------------------- */
    /*                              IStandardVaultPkg                         */
    /* ---------------------------------------------------------------------- */

    function name() public pure returns (string memory) {
        return packageName();
    }

    function vaultFeeTypeIds() public pure returns (bytes32 vaultFeeTypeIds_) {
        vaultFeeTypeIds_ =
            VaultTypeUtils._insertFeeTypeId(vaultFeeTypeIds_, VaultFeeType.BOND, type(IProtocolNFTVault).interfaceId);
    }

    function vaultTypes() public pure returns (bytes4[] memory typeIDs) {
        return facetInterfaces();
    }

    function vaultDeclaration() public pure returns (VaultPkgDeclaration memory declaration) {
        return VaultPkgDeclaration({name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()});
    }

    function postDeploy(address) public pure returns (bool) {
        return true;
    }
}
