// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {DETFFundedStakingRepo} from "contracts/vaults/detf/common/claimToken/DETFFundedStakingRepo.sol";

/// @title IRebasingClaimTokenDFPkg
/// @notice Deployment arguments for the funded nine-decimal staking token.
interface IRebasingClaimTokenDFPkg is IDiamondFactoryPackage {
    struct PkgInit {
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet rebasingClaimTokenFacet;
        IDiamondPackageCallBackFactory diamondFactory;
    }

    struct PkgArgs {
        IDetf detf;
        IDETFNFTVault nftVault;
        IVaultFeeOracleQuery feeOracle;
        string name;
        string symbol;
        bytes32 optionalSalt;
    }

    function deployToken(
        IDetf detf_, IDETFNFTVault nftVault_, IVaultFeeOracleQuery feeOracle_,
        string memory name_, string memory symbol_
    ) external returns (address tokenAddress_);
}

/// @title RebasingClaimTokenDFPkg
/// @notice Immutable funded staking receipts with standard principal routes and ERC-2612 permits.
contract RebasingClaimTokenDFPkg is IRebasingClaimTokenDFPkg {
    using BetterEfficientHashLib for bytes;

    error InvalidPackageArguments();

    IFacet immutable ERC5267_FACET;
    IFacet immutable ERC2612_FACET;
    IFacet immutable REBASING_CLAIM_TOKEN_FACET;
    IDiamondPackageCallBackFactory immutable DIAMOND_FACTORY;

    constructor(PkgInit memory pkgInit_) {
        ERC5267_FACET = pkgInit_.erc5267Facet;
        ERC2612_FACET = pkgInit_.erc2612Facet;
        REBASING_CLAIM_TOKEN_FACET = pkgInit_.rebasingClaimTokenFacet;
        DIAMOND_FACTORY = pkgInit_.diamondFactory;
    }

    /// @inheritdoc IRebasingClaimTokenDFPkg
    function deployToken(
        IDetf detf_, IDETFNFTVault nftVault_, IVaultFeeOracleQuery feeOracle_,
        string memory name_, string memory symbol_
    ) external returns (address tokenAddress_) {
        PkgArgs memory args_ = PkgArgs({
            detf: detf_,
            nftVault: nftVault_,
            feeOracle: feeOracle_,
            name: bytes(name_).length == 0 ? "Staked DETF" : name_,
            symbol: bytes(symbol_).length == 0 ? "sDETF" : symbol_,
            optionalSalt: abi.encode(address(detf_))._hash()
        });
        return address(DIAMOND_FACTORY.deploy(this, abi.encode(args_)));
    }

    /// @inheritdoc IDiamondFactoryPackage
    function packageName() public pure returns (string memory) {
        return type(RebasingClaimTokenDFPkg).name;
    }

    /// @inheritdoc IDiamondFactoryPackage
    function facetAddresses() public view returns (address[] memory facets_) {
        facets_ = new address[](3);
        facets_[0] = address(ERC5267_FACET);
        facets_[1] = address(ERC2612_FACET);
        facets_[2] = address(REBASING_CLAIM_TOKEN_FACET);
    }

    /// @inheritdoc IDiamondFactoryPackage
    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](7);
        interfaces_[0] = type(IERC20).interfaceId;
        interfaces_[1] = type(IERC20Metadata).interfaceId;
        interfaces_[2] = type(IERC20Permit).interfaceId;
        interfaces_[3] = type(IERC5267).interfaceId;
        interfaces_[4] = type(IStakedDETF).interfaceId;
        interfaces_[5] = type(IStandardExchangeIn).interfaceId;
        interfaces_[6] = type(IStandardExchangeOut).interfaceId;
    }

    /// @inheritdoc IDiamondFactoryPackage
    function packageMetadata()
        public view returns (string memory name_, bytes4[] memory interfaces_, address[] memory facets_)
    {
        return (packageName(), facetInterfaces(), facetAddresses());
    }

    /// @inheritdoc IDiamondFactoryPackage
    function facetCuts() public view returns (IDiamond.FacetCut[] memory cuts_) {
        cuts_ = new IDiamond.FacetCut[](3);
        cuts_[0] = IDiamond.FacetCut({
            facetAddress: address(ERC5267_FACET), action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC5267_FACET.facetFuncs()
        });
        cuts_[1] = IDiamond.FacetCut({
            facetAddress: address(ERC2612_FACET), action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC2612_FACET.facetFuncs()
        });
        cuts_[2] = IDiamond.FacetCut({
            facetAddress: address(REBASING_CLAIM_TOKEN_FACET), action: IDiamond.FacetCutAction.Add,
            functionSelectors: REBASING_CLAIM_TOKEN_FACET.facetFuncs()
        });
    }

    /// @inheritdoc IDiamondFactoryPackage
    function diamondConfig() public view returns (DiamondConfig memory) {
        return DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    /// @inheritdoc IDiamondFactoryPackage
    function calcSalt(bytes memory pkgArgs_) public pure returns (bytes32) {
        return abi.encode(pkgArgs_)._hash();
    }

    /// @inheritdoc IDiamondFactoryPackage
    function processArgs(bytes memory pkgArgs_) public pure returns (bytes memory) {
        PkgArgs memory args_ = abi.decode(pkgArgs_, (PkgArgs));
        if (
            address(args_.detf) == address(0) || address(args_.nftVault) == address(0)
                || address(args_.feeOracle) == address(0) || abi.encode(args_)._hash() != pkgArgs_._hash()
        ) revert InvalidPackageArguments();
        return pkgArgs_;
    }

    /// @inheritdoc IDiamondFactoryPackage
    function updatePkg(address, bytes memory) public pure returns (bool) {
        return true;
    }

    /// @inheritdoc IDiamondFactoryPackage
    function initAccount(bytes memory initArgs_) public {
        PkgArgs memory args_ = abi.decode(processArgs(initArgs_), (PkgArgs));
        string memory name_ = bytes(args_.name).length == 0 ? "Staked DETF" : args_.name;
        string memory symbol_ = bytes(args_.symbol).length == 0 ? "sDETF" : args_.symbol;
        ERC20Repo._initialize(name_, symbol_, 9);
        EIP712Repo._initialize(name_, "1");
        DETFFundedStakingRepo._initialize(IERC20(address(args_.detf)), address(args_.nftVault), args_.feeOracle);
    }

    /// @inheritdoc IDiamondFactoryPackage
    function postDeploy(address) public pure returns (bool) {
        return true;
    }
}
