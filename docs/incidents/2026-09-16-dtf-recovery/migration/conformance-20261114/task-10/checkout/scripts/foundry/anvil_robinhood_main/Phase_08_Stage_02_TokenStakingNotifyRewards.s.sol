// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {LaunchStageBase} from "./LaunchStageBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {ITokenStaking} from "contracts/interfaces/ITokenStaking.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Phase_08_Stage_02_TokenStakingNotifyRewards as NotifyLib} from
    "./Phase_08_Stage_02_TokenStakingNotifyRewards.sol";

/// @title Phase_08_Stage_02_TokenStakingNotifyRewards
/// @notice notifyRewardAmount(sender $DTF balance). Skip if a reward period is already live.
contract Phase_08_Stage_02_TokenStakingNotifyRewards is LaunchStageBase {
    function run() external {
        _start("Phase 08 Stage 02: notify $DTF reward reserve");
        address dtf_ = RobinhoodCanonicalLib.dtf();
        require(_hasCode(dtf_), "Phase 08-02: $DTF has no code");
        s.tokenStaking = _loadAddr(FILE_08_01, "tokenStaking");
        require(_hasCode(s.tokenStaking), "run Phase 08 Stage 01 first");
        _logAddress("tokenStaking:", s.tokenStaking);
        _logAddress("stakingToken ($DTF):", dtf_);
        _logAddress("owner / deployer:", deployer);
        uint256 held = IERC20(dtf_).balanceOf(deployer);
        console2.log("deployer DTF balance:", held);

        uint256 notified;
        ITokenStaking staking_ = ITokenStaking(s.tokenStaking);
        if (!_force() && staking_.periodFinish() > block.timestamp) {
            notified = staking_.rewardReserve();
            console2.log("skip: reward period already live; rewardReserve:", notified);
        } else {
            _broadcast();
            notified = NotifyLib.execute(s, deployer);
            vm.stopBroadcast();
        }
        _exportTokenStakingNotify(s, notified);
        console2.log("notifiedAmount:", notified);
        _logComplete("Phase 08 Stage 02");
    }
}
