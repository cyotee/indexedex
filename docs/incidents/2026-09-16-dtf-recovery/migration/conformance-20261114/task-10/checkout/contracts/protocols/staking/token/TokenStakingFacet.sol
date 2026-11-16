// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {ITokenStaking} from "contracts/interfaces/ITokenStaking.sol";
import {TokenStakingTarget} from "contracts/protocols/staking/token/TokenStakingTarget.sol";

contract TokenStakingFacet is TokenStakingTarget, IFacet {
    function facetName() external pure returns (string memory) {
        return type(TokenStakingFacet).name;
    }

    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(ITokenStaking).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](33);
        funcs_[0] = ITokenStaking.stakingToken.selector;
        funcs_[1] = ITokenStaking.rewardsDuration.selector;
        funcs_[2] = ITokenStaking.periodFinish.selector;
        funcs_[3] = ITokenStaking.rewardRate.selector;
        funcs_[4] = ITokenStaking.lastUpdateTime.selector;
        funcs_[5] = ITokenStaking.rewardPerTokenStored.selector;
        funcs_[6] = ITokenStaking.userRewardPerTokenPaid.selector;
        funcs_[7] = ITokenStaking.rewards.selector;
        funcs_[8] = ITokenStaking.totalSupply.selector;
        funcs_[9] = ITokenStaking.balanceOf.selector;
        funcs_[10] = ITokenStaking.lastTimeRewardApplicable.selector;
        funcs_[11] = ITokenStaking.rewardPerToken.selector;
        funcs_[12] = ITokenStaking.earned.selector;
        funcs_[13] = ITokenStaking.phase.selector;
        funcs_[14] = ITokenStaking.targetDetf.selector;
        funcs_[15] = ITokenStaking.reserveRemaining.selector;
        funcs_[16] = ITokenStaking.rewardReserve.selector;
        funcs_[17] = ITokenStaking.permit2.selector;
        funcs_[18] = ITokenStaking.claimVault.selector;
        funcs_[19] = ITokenStaking.previewClaim.selector;
        funcs_[20] = ITokenStaking.stake.selector;
        funcs_[21] = ITokenStaking.withdraw.selector;
        funcs_[22] = ITokenStaking.getReward.selector;
        funcs_[23] = ITokenStaking.exit.selector;
        funcs_[24] = ITokenStaking.reassign.selector;
        funcs_[25] = ITokenStaking.notifyRewardAmount.selector;
        funcs_[26] = ITokenStaking.setRewardsDuration.selector;
        funcs_[27] = ITokenStaking.setTargetDetf.selector;
        funcs_[28] = ITokenStaking.migrateToClaimVault.selector;
        funcs_[29] = ITokenStaking.withdrawClaim.selector;
        funcs_[30] = ITokenStaking.recoverERC20.selector;
        funcs_[31] = ITokenStaking.rescueRewardReserve.selector;
        funcs_[32] = ITokenStaking.completeWrap.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name_ = type(TokenStakingFacet).name;
        interfaces = new bytes4[](1);
        interfaces[0] = type(ITokenStaking).interfaceId;
        functions = facetFuncs();
    }
}
