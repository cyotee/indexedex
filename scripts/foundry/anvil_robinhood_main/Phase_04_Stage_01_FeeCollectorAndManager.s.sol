// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {
    Phase_04_Stage_01_FeeCollectorAndManager as FeeMgrLib
} from "./Phase_04_Stage_01_FeeCollectorAndManager.sol";

/// @title Phase_04_Stage_01_FeeCollectorAndManager
/// @notice Skip keys: `feeCollector`, `indexedexManager`.
contract Phase_04_Stage_01_FeeCollectorAndManager is LaunchStageBase {
    function run() external {
        _start("Phase 04 Stage 01: FeeCollector + Manager");
        RobinhoodCanonicalLib.requireCanonicalPins();
        if (_shouldSkipStage(FILE_04_01, _skipKeys("feeCollector", "indexedexManager"))) {
            _requireManager(s);
            _requireHookFactory(s);
        } else {
            _requireDiamondFactory(s);
            _requireHookFactory(s);
            _requireCommonFacets(s);
            _broadcast();
            FeeMgrLib.execute(s, owner);
            vm.stopBroadcast();
        }
        _exportFeeCollectorAndManager(s);
        _logAddress("feeCollector:", address(s.feeCollector));
        _logAddress("indexedexManager:", address(s.indexedexManager));
        _logComplete("Phase 04 Stage 01");
    }
}
