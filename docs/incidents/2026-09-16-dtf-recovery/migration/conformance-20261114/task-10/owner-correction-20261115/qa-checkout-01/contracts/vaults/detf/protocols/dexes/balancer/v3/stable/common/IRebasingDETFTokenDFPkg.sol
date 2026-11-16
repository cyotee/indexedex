// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDETF} from "contracts/interfaces/IDETF.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";

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
