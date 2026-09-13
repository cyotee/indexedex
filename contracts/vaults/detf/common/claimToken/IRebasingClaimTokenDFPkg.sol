// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";

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
