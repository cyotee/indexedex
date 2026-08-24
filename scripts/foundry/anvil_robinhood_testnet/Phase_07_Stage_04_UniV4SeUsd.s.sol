// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {Phase_07_Stage_04_UniV4SeUsd as UsdSeLib} from "./Phase_07_Stage_04_UniV4SeUsd.sol";

/// @title Phase_07_Stage_04_UniV4SeUsd
/// @notice Skip keys: `seUsdeWeth`, `seUsdgWeth`, `seUsdgUsde`.
contract Phase_07_Stage_04_UniV4SeUsd is LaunchStageBase {
    function run() external {
        _start("Phase 07 Stage 04: Uni V4 USD SEs");
        RobinhoodCanonicalLib.requireCanonicalPins();
        if (_shouldSkipStage(FILE_07_04, _skipKeys("seUsdeWeth", "seUsdgWeth", "seUsdgUsde"))) {
            _requireUsdSes(s);
        } else {
            _requireCreate3(s);
            _requireUniV4SePkg(s);
            _requireRateProviderPkg(s);
            _requireCoreTokens(s);
            _broadcast();
            UsdSeLib.execute(s, owner);
            vm.stopBroadcast();
        }
        _exportUsdSes(s);
        _logAddress("seUsdeWeth:", s.seUsdeWeth);
        _logComplete("Phase 07 Stage 04");
    }
}
