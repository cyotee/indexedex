// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from '@crane/contracts/interfaces/IFacet.sol';
import {IDiamondFactoryPackage} from '@crane/contracts/interfaces/IDiamondFactoryPackage.sol';
import {IDiamondPackageCallBackFactory} from '@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol';
import {IDiamond} from '@crane/contracts/interfaces/IDiamond.sol';
import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {IERC20Metadata} from '@crane/contracts/interfaces/IERC20Metadata.sol';
import {IERC20Permit} from '@crane/contracts/interfaces/IERC20Permit.sol';
import {IERC5267} from '@crane/contracts/interfaces/IERC5267.sol';
import {IMultiStepOwnable} from '@crane/contracts/interfaces/IMultiStepOwnable.sol';
import {BetterEfficientHashLib} from '@crane/contracts/utils/BetterEfficientHashLib.sol';
import {ERC20Repo} from '@crane/contracts/tokens/ERC20/ERC20Repo.sol';
import {EIP712Repo} from '@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol';
import {MultiStepOwnableRepo} from '@crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol';

import {IDETF} from 'contracts/interfaces/IDETF.sol';
import {IDETFNFTVault} from 'contracts/interfaces/IDETFNFTVault.sol';
import {IRebasingClaimToken} from 'contracts/interfaces/IRebasingClaimToken.sol';
import {IStandardExchangeIn} from 'contracts/interfaces/IStandardExchangeIn.sol';
import {IStandardExchangeOut} from 'contracts/interfaces/IStandardExchangeOut.sol';
import {RebasingDETFTokenRepo} from 'contracts/vaults/detf/composed/stable/common/RebasingDETFTokenRepo.sol';

interface IRebasingDETFTokenDFPkg is IDiamondFactoryPackage {
    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiStepOwnableFacet;
        IFacet rebasingDetfTokenFacet;
        IDiamondPackageCallBackFactory diamondFactory;
    }

    struct PkgArgs {
        IDETF detf;
        IDETFNFTVault nftVault;
        IERC20 rateAsset;
        uint256 detfNFTId;
        address owner;
        bytes32 optionalSalt;
    }

    function deployToken(
        IDETF detf,
        IDETFNFTVault nftVault,
        IERC20 rateAsset,
        uint256 detfNFTId,
        address owner
    ) external returns (address tokenAddress);
}

contract RebasingDETFTokenDFPkg is IRebasingDETFTokenDFPkg {
    using BetterEfficientHashLib for bytes;

    IFacet immutable ERC20_FACET;
    IFacet immutable ERC5267_FACET;
    IFacet immutable ERC2612_FACET;
    IFacet immutable MULTI_STEP_OWNABLE_FACET;
    IFacet immutable REBASING_DETF_TOKEN_FACET;
    IDiamondPackageCallBackFactory immutable DIAMOND_FACTORY;

    constructor(PkgInit memory pkgInit) {
        ERC20_FACET = pkgInit.erc20Facet;
        ERC5267_FACET = pkgInit.erc5267Facet;
        ERC2612_FACET = pkgInit.erc2612Facet;
        MULTI_STEP_OWNABLE_FACET = pkgInit.multiStepOwnableFacet;
        REBASING_DETF_TOKEN_FACET = pkgInit.rebasingDetfTokenFacet;
        DIAMOND_FACTORY = pkgInit.diamondFactory;
    }

    function deployToken(
        IDETF detf,
        IDETFNFTVault nftVault,
        IERC20 rateAsset,
        uint256 detfNFTId,
        address owner
    ) external returns (address tokenAddress) {
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
                        optionalSalt: abi.encode(address(detf))._hash()
                    })
                )
            )
        );
    }

    function packageName() public pure returns (string memory name_) {
        return type(RebasingDETFTokenDFPkg).name;
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](4);
        facetAddresses_[0] = address(ERC5267_FACET);
        facetAddresses_[1] = address(ERC2612_FACET);
        facetAddresses_[2] = address(MULTI_STEP_OWNABLE_FACET);
        facetAddresses_[3] = address(REBASING_DETF_TOKEN_FACET);
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](8);
        interfaces_[0] = type(IERC20).interfaceId;
        interfaces_[1] = type(IERC20Metadata).interfaceId;
        interfaces_[2] = type(IERC20Permit).interfaceId;
        interfaces_[3] = type(IERC5267).interfaceId;
        interfaces_[4] = type(IMultiStepOwnable).interfaceId;
        interfaces_[5] = type(IRebasingClaimToken).interfaceId;
        interfaces_[6] = type(IStandardExchangeIn).interfaceId;
        interfaces_[7] = type(IStandardExchangeOut).interfaceId;
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
        facetCuts_ = new IDiamond.FacetCut[](4);
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
            facetAddress: address(MULTI_STEP_OWNABLE_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: MULTI_STEP_OWNABLE_FACET.facetFuncs()
        });
        facetCuts_[3] = IDiamond.FacetCut({
            facetAddress: address(REBASING_DETF_TOKEN_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: REBASING_DETF_TOKEN_FACET.facetFuncs()
        });
    }

    function diamondConfig() public view returns (DiamondConfig memory config_) {
        config_ = IDiamondFactoryPackage.DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32 salt_) {
        return abi.encode(pkgArgs)._hash();
    }

    function processArgs(bytes memory pkgArgs) public pure virtual returns (bytes memory processedPkgArgs_) {
        return pkgArgs;
    }

    function updatePkg(address, bytes memory) public pure virtual returns (bool) {
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory args = abi.decode(initArgs, (PkgArgs));

        MultiStepOwnableRepo._initialize(args.owner, 1 days);
        ERC20Repo._initialize('RebasingDETFToken', 'RDETF', 18);
        EIP712Repo._initialize('RebasingDETFToken', '1');
        RebasingDETFTokenRepo._initialize(args.detf, args.nftVault, args.rateAsset, args.detfNFTId);
    }

    function postDeploy(address) public pure returns (bool) {
        return true;
    }
}