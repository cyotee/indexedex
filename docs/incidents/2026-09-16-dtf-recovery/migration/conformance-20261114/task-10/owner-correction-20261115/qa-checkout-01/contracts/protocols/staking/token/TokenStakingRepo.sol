// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IDetfClaimPurchase} from "contracts/interfaces/IDetfClaimPurchase.sol";
import {ITokenStaking} from "contracts/interfaces/ITokenStaking.sol";

library TokenStakingRepo {
    bytes32 internal constant DEFAULT_SLOT =
        bytes32(uint256(keccak256(abi.encode("indexedex.staking.token"))) - 1);

    struct Storage {
        IERC20 stakingToken;
        uint256 rewardsDuration;
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
        mapping(address => uint256) userRewardPerTokenPaid;
        mapping(address => uint256) rewards;
        uint256 totalSupply;
        mapping(address => uint256) balanceOf;
        ITokenStaking.Phase phase;
        IDetfClaimPurchase targetDetf;
        IERC4626 claimVault;
        IDiamondFactoryPackage claimVaultPkg;
    }

    function _layoutStruct(bytes32 slot) internal pure returns (Storage storage layoutStruct) {
        assembly {
            layoutStruct.slot := slot
        }
    }

    function _layoutStruct() internal pure returns (Storage storage layoutStruct) {
        return _layoutStruct(DEFAULT_SLOT);
    }

    function _initialize(IERC20 stakingToken_, uint256 rewardsDuration_, IDiamondFactoryPackage claimVaultPkg_)
        internal
    {
        Storage storage layoutStruct = _layoutStruct();
        layoutStruct.stakingToken = stakingToken_;
        layoutStruct.rewardsDuration = rewardsDuration_;
        layoutStruct.claimVaultPkg = claimVaultPkg_;
        layoutStruct.phase = ITokenStaking.Phase.Staking;
    }
}
