// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {Phase_07_Stage_03_UniV4SeDtfWeth as DtfWethSeLib} from "./Phase_07_Stage_03_UniV4SeDtfWeth.sol";

/// @title Phase_07_Stage_03_UniV4SeDtfWeth
/// @notice Skip key: `seRichWeth`.
contract Phase_07_Stage_03_UniV4SeDtfWeth is LaunchStageBase {
    function run() external {
        _start("Phase 07 Stage 03: Uni V4 SE DTF/TTWETH");
        RobinhoodCanonicalLib.requireCanonicalPins();
        if (_shouldSkipStage(FILE_07_03, _skipKeys("seRichWeth"))) {
            _requireDtfWethSe(s);
        } else {
            _requireCreate3(s);
            _requireUniV4SePkg(s);
            _requireRateProviderPkg(s);
            _requireCoreTokens(s);
            s.v4Seeder = _loadAddr(FILE_07_03, "v4Seeder");
            _broadcast();
            DtfWethSeLib.execute(s, owner);
            vm.stopBroadcast();
        }
        _exportDtfWethSe(s);
        _logAddress("seRichWeth:", s.seRichWeth);
        _logComplete("Phase 07 Stage 03");
    }
}
