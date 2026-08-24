// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {Phase_05_Stage_01_SeRateProviderPkg as RatePkgLib} from "./Phase_05_Stage_01_SeRateProviderPkg.sol";

/// @title Phase_05_Stage_01_SeRateProviderPkg
/// @notice Skip key: `rateProviderPkg`.
contract Phase_05_Stage_01_SeRateProviderPkg is LaunchStageBase {
    function run() external {
        _start("Phase 05 Stage 01: SE rate provider pkg");
        if (_shouldSkipStage(FILE_05_01, _skipKeys("rateProviderPkg"))) {
            _requireRateProviderPkg(s);
        } else {
            _requireDiamondFactory(s);
            _broadcast();
            RatePkgLib.execute(s);
            vm.stopBroadcast();
        }
        _exportPkg("p0501", FILE_05_01, "rateProviderPkg", address(s.rateProviderPkg));
        _logAddress("rateProviderPkg:", address(s.rateProviderPkg));
        _logComplete("Phase 05 Stage 01");
    }
}
