// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {Phase_08_Stage_01_TokenStakingDtf as TokenStakingDtfLib} from
    "./Phase_08_Stage_01_TokenStakingDtf.sol";

/// @title Phase_08_Stage_01_TokenStakingDtf
/// @notice Skip key: `tokenStaking`. $DTF deposit/reward, 7-day duration. No notifyRewardAmount.
contract Phase_08_Stage_01_TokenStakingDtf is LaunchStageBase {
    function run() external {
        _start("Phase 08 Stage 01: $DTF TokenStaking instance");
        address dtf_ = RobinhoodCanonicalLib.dtf();
        require(_hasCode(dtf_), "Phase 08-01: $DTF has no code");
        _logAddress("stakingToken ($DTF):", dtf_);
        _logAddress("owner / deployer:", deployer);
        if (_shouldSkipStage(FILE_08_01, _skipKeys("tokenStaking"))) {
            _requireDiamondFactory(s);
            _requireTokenStakingPkg(s);
            s.tokenStaking = _loadAddr(FILE_08_01, "tokenStaking");
        } else {
            _requireDiamondFactory(s);
            _requireTokenStakingPkg(s);
            _broadcast();
            TokenStakingDtfLib.execute(s, deployer);
            vm.stopBroadcast();
        }
        _exportTokenStakingDtf(s);
        _logAddress("tokenStaking:", s.tokenStaking);
        _logString("notifyRewardAmount:", "not called (fund later as owner)");
        _logComplete("Phase 08 Stage 01");
    }
}
