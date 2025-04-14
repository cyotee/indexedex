// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {MultiStepOwnableRepo} from "@crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {IRICHIR} from "contracts/interfaces/IRICHIR.sol";
import {RICHIRRepo} from "contracts/vaults/protocol/RICHIRRepo.sol";

/**
 * @title IRICHIRDFPkg
 * @notice Interface for RICHIR Diamond Factory Package.
 */
interface IRICHIRDFPkg is IDiamondFactoryPackage {
    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet richirFacet;
        IDiamondPackageCallBackFactory diamondFactory;
    }

    struct PkgArgs {
        /// @notice The Protocol DETF contract (CHIR)
        IProtocolDETF protocolDETF;
        /// @notice The Protocol NFT Vault contract
        IProtocolNFTVault nftVault;
        /// @notice The WETH token
        IERC20 wethToken;
        /// @notice The protocol-owned NFT token ID
        uint256 protocolNFTId;
        /// @notice Owner address (typically the DETF contract)
        address owner;
        /// @notice Optional salt for deterministic deployment
        bytes32 optionalSalt;
    }

    function deployToken(
        IProtocolDETF protocolDETF,
        IProtocolNFTVault nftVault,
        IERC20 wethToken,
        uint256 protocolNFTId,
        address owner
    ) external returns (address tokenAddress);
}

/**
 * @title RICHIRDFPkg
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Diamond Factory Package for deploying RICHIR rebasing token.
 */
contract RICHIRDFPkg is IRICHIRDFPkg {
    using BetterEfficientHashLib for bytes;

    IFacet immutable ERC20_FACET;
    IFacet immutable ERC5267_FACET;
    IFacet immutable ERC2612_FACET;
    IFacet immutable RICHIR_FACET;
    IDiamondPackageCallBackFactory immutable DIAMOND_FACTORY;

    constructor(PkgInit memory pkgInit) {
        ERC20_FACET = pkgInit.erc20Facet;
        ERC5267_FACET = pkgInit.erc5267Facet;
        ERC2612_FACET = pkgInit.erc2612Facet;
        RICHIR_FACET = pkgInit.richirFacet;
        DIAMOND_FACTORY = pkgInit.diamondFactory;
    }

    function deployToken(
        IProtocolDETF protocolDETF,
        IProtocolNFTVault nftVault,
        IERC20 wethToken,
        uint256 protocolNFTId,
        address owner
    ) external returns (address tokenAddress) {
        return address(
            DIAMOND_FACTORY.deploy(
                this,
                abi.encode(
                    PkgArgs({
                        protocolDETF: protocolDETF,
                        nftVault: nftVault,
                        wethToken: wethToken,
                        protocolNFTId: protocolNFTId,
                        owner: owner,
                        optionalSalt: abi.encode(address(protocolDETF))._hash()
                    })
                )
            )
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                       IDiamondFactoryPackage                           */
    /* ---------------------------------------------------------------------- */

    function packageName() public pure returns (string memory name_) {
        return type(RICHIRDFPkg).name;
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](3);
        facetAddresses_[0] = address(ERC5267_FACET);
        facetAddresses_[1] = address(ERC2612_FACET);
        facetAddresses_[2] = address(RICHIR_FACET);
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](5);
        interfaces[0] = type(IERC20).interfaceId;
        interfaces[1] = type(IERC20Metadata).interfaceId;
        interfaces[2] = type(IERC20Permit).interfaceId;
        interfaces[3] = type(IERC5267).interfaceId;
        interfaces[4] = type(IRICHIR).interfaceId;
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
        facetCuts_ = new IDiamond.FacetCut[](3);

        facetCuts_[0] = IDiamond.FacetCut({
            facetAddress: address(ERC5267_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC5267_FACET.facetFuncs()
        });
        facetCuts_[1] = IDiamond.FacetCut({
            facetAddress: address(ERC2612_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC2612_FACET.facetFuncs()
        });
        facetCuts_[2] = IDiamond.FacetCut({
            facetAddress: address(RICHIR_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: RICHIR_FACET.facetFuncs()
        });
    }

    function diamondConfig() public view returns (DiamondConfig memory config) {
        config = IDiamondFactoryPackage.DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32 salt) {
        return abi.encode(pkgArgs)._hash();
    }

    function processArgs(bytes memory pkgArgs) public pure virtual returns (bytes memory processedPkgArgs) {
        return pkgArgs;
    }

    function updatePkg(address, bytes memory) public pure virtual returns (bool) {
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory args = abi.decode(initArgs, (PkgArgs));

        // Initialize ownership (DETF is the owner)
        MultiStepOwnableRepo._initialize(args.owner, 1 days);

        // Initialize ERC20 metadata
        ERC20Repo._initialize("RICHIR", "RICHIR", 18);

        // Initialize EIP712
        EIP712Repo._initialize("RICHIR", "1");

        // Initialize RICHIR storage
        RICHIRRepo._initialize(args.protocolDETF, args.nftVault, args.wethToken, args.protocolNFTId);
    }

    function postDeploy(address) public pure returns (bool) {
        return true;
    }
}
