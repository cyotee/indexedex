// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {ITokenStaking} from "contracts/interfaces/ITokenStaking.sol";
import {IRebasingAwareERC4626DFPkg} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";

interface ITokenStakingDFPkg is IDiamondFactoryPackage {
    struct PkgInit {
        IFacet tokenStakingFacet;
        IFacet multiStepOwnableFacet;
        IRebasingAwareERC4626DFPkg claimVaultPkg;
        IPermit2 permit2;
    }

    struct PkgArgs {
        IERC20 stakingToken;
        uint256 rewardsDuration;
        address owner;
        uint256 ownershipBufferPeriod;
        bytes32 optionalSalt;
    }

    error NoStakingToken();
    error NoOwner();
    error NoPermit2();

    function deployStaking(IDiamondPackageCallBackFactory factory, PkgArgs memory pkgArgs)
        external
        returns (ITokenStaking staking);
}
