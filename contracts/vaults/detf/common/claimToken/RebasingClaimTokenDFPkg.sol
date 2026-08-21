// SPDX-License-Identifier: BSL-1.1
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

import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {RebasingClaimTokenRepo} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenRepo.sol";

/**
 * @title IRebasingClaimTokenDFPkg
 * @notice Interface for rebasing claim token Diamond Factory Package.
 */
interface IRebasingClaimTokenDFPkg is IDiamondFactoryPackage {
    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet rebasingClaimTokenFacet;
        IDiamondPackageCallBackFactory diamondFactory;
    }

    struct PkgArgs {
        /// @notice The DETF diamond
        IDetf detf;
        /// @notice The Protocol NFT Vault contract
        IDETFNFTVault nftVault;
        /// @notice Settlement token for zapout quotes (pair / rateAsset as wired by the DETF)
        IERC20 rateAsset;
        /// @notice The protocol-owned NFT token ID
        uint256 detfNFTId;
        /// @notice Owner address (typically the DETF contract)
        address owner;
        /// @notice ERC-20 name. Empty → DETF name + " Claim", else "RebasingClaim".
        string name;
        /// @notice ERC-20 symbol. Empty → DETF symbol + "IR", else "RebasingClaim".
        string symbol;
        /// @notice Optional salt for deterministic deployment
        bytes32 optionalSalt;
    }

    function deployToken(
        IDetf detf,
        IDETFNFTVault nftVault,
        IERC20 rateAsset,
        uint256 detfNFTId,
        address owner
    ) external returns (address tokenAddress);

    function deployToken(
        IDetf detf,
        IDETFNFTVault nftVault,
        IERC20 rateAsset,
        uint256 detfNFTId,
        address owner,
        string memory name,
        string memory symbol
    ) external returns (address tokenAddress);
}

/**
 * @title RebasingClaimTokenDFPkg
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Diamond Factory Package for deploying rebasing claim token rebasing token.
 */
contract RebasingClaimTokenDFPkg is IRebasingClaimTokenDFPkg {
    using BetterEfficientHashLib for bytes;

    IFacet immutable ERC20_FACET;
    IFacet immutable ERC5267_FACET;
    IFacet immutable ERC2612_FACET;
    IFacet immutable REBASING_CLAIM_TOKEN_FACET;
    IDiamondPackageCallBackFactory immutable DIAMOND_FACTORY;

    constructor(PkgInit memory pkgInit) {
        ERC20_FACET = pkgInit.erc20Facet;
        ERC5267_FACET = pkgInit.erc5267Facet;
        ERC2612_FACET = pkgInit.erc2612Facet;
        REBASING_CLAIM_TOKEN_FACET = pkgInit.rebasingClaimTokenFacet;
        DIAMOND_FACTORY = pkgInit.diamondFactory;
    }

    function deployToken(
        IDetf detf,
        IDETFNFTVault nftVault,
        IERC20 rateAsset,
        uint256 detfNFTId,
        address owner
    ) external returns (address tokenAddress) {
        (string memory name_, string memory symbol_) = _deriveClaimMetadata(detf);
        return deployToken(detf, nftVault, rateAsset, detfNFTId, owner, name_, symbol_);
    }

    function deployToken(
        IDetf detf,
        IDETFNFTVault nftVault,
        IERC20 rateAsset,
        uint256 detfNFTId,
        address owner,
        string memory name,
        string memory symbol
    ) public returns (address tokenAddress) {
        (string memory name_, string memory symbol_) = _resolveNameSymbol(detf, name, symbol);
        return address(
            DIAMOND_FACTORY.deploy(
                this,
                abi.encode(
                    PkgArgs({
                        detf: detf,
                        nftVault: nftVault,
                        rateAsset: rateAsset,
                        detfNFTId: detfNFTId,
                        owner: owner,
                        name: name_,
                        symbol: symbol_,
                        optionalSalt: abi.encode(address(detf))._hash()
                    })
                )
            )
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                       IDiamondFactoryPackage                           */
    /* ---------------------------------------------------------------------- */

    function packageName() public pure returns (string memory name_) {
        return type(RebasingClaimTokenDFPkg).name;
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](3);
        facetAddresses_[0] = address(ERC5267_FACET);
        facetAddresses_[1] = address(ERC2612_FACET);
        facetAddresses_[2] = address(REBASING_CLAIM_TOKEN_FACET);
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](7);
        interfaces[0] = type(IERC20).interfaceId;
        interfaces[1] = type(IERC20Metadata).interfaceId;
        interfaces[2] = type(IERC20Permit).interfaceId;
        interfaces[3] = type(IERC5267).interfaceId;
        interfaces[4] = type(IRebasingClaimToken).interfaceId;
        interfaces[5] = type(IStandardExchangeIn).interfaceId;
        interfaces[6] = type(IStandardExchangeOut).interfaceId;
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
            facetAddress: address(REBASING_CLAIM_TOKEN_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: REBASING_CLAIM_TOKEN_FACET.facetFuncs()
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

        string memory name_ = bytes(args.name).length == 0 ? "RebasingClaim" : args.name;
        string memory symbol_ = bytes(args.symbol).length == 0 ? "RebasingClaim" : args.symbol;
        ERC20Repo._initialize(name_, symbol_, 18);
        EIP712Repo._initialize(name_, "1");

        // Initialize rebasing claim token storage
        RebasingClaimTokenRepo._initialize(args.detf, args.nftVault, args.rateAsset, args.detfNFTId);
    }

    function postDeploy(address) public pure returns (bool) {
        return true;
    }

    function _deriveClaimMetadata(IDetf detf)
        private
        view
        returns (string memory name_, string memory symbol_)
    {
        return _resolveNameSymbol(detf, "", "");
    }

    function _resolveNameSymbol(IDetf detf, string memory name_, string memory symbol_)
        private
        view
        returns (string memory resolvedName_, string memory resolvedSymbol_)
    {
        resolvedName_ = bytes(name_).length == 0 ? _tryDetfClaimName(detf) : name_;
        resolvedSymbol_ = bytes(symbol_).length == 0 ? _tryDetfClaimSymbol(detf) : symbol_;
    }

    function _tryDetfClaimName(IDetf detf) private view returns (string memory) {
        if (address(detf).code.length == 0) return "RebasingClaim";
        try IERC20Metadata(address(detf)).name() returns (string memory n) {
            if (bytes(n).length == 0) return "RebasingClaim";
            return string.concat(n, " Claim");
        } catch {
            return "RebasingClaim";
        }
    }

    function _tryDetfClaimSymbol(IDetf detf) private view returns (string memory) {
        if (address(detf).code.length == 0) return "RebasingClaim";
        try IERC20Metadata(address(detf)).symbol() returns (string memory s) {
            if (bytes(s).length == 0) return "RebasingClaim";
            return string.concat(s, "IR");
        } catch {
            return "RebasingClaim";
        }
    }
}
