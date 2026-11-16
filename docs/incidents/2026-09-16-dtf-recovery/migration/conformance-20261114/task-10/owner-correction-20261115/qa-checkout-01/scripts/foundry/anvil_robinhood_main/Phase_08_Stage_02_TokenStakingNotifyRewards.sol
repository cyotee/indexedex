// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ITokenStaking} from "contracts/interfaces/ITokenStaking.sol";

/// @title Phase_08_Stage_02_TokenStakingNotifyRewards
/// @notice Owner notifies the sender's full $DTF balance as the reward reserve.
library Phase_08_Stage_02_TokenStakingNotifyRewards {
    using BetterSafeERC20 for IERC20;

    function execute(LaunchState storage s, address owner_) internal returns (uint256 amount) {
        address dtf_ = RobinhoodCanonicalLib.dtf();
        ITokenStaking staking_ = ITokenStaking(s.tokenStaking);
        require(address(staking_).code.length > 0, "Phase 08-02: tokenStaking");
        require(owner_ != address(0), "Phase 08-02: owner");
        amount = IERC20(dtf_).balanceOf(owner_);
        require(amount > 0, "Phase 08-02: deployer DTF balance is 0");
        require(amount <= type(uint160).max, "Phase 08-02: amount exceeds uint160");
        IPermit2 p2 = IPermit2(staking_.permit2());
        require(address(p2).code.length > 0, "Phase 08-02: Permit2");
        IERC20(dtf_).forceApprove(address(p2), amount);
        p2.approve(dtf_, address(staking_), uint160(amount), type(uint48).max);
        staking_.notifyRewardAmount(amount);
    }
}
