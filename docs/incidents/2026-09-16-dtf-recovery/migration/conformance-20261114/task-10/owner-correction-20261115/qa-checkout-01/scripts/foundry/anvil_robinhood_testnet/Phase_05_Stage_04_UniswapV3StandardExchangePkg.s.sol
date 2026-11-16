// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {
    Phase_05_Stage_04_UniswapV3StandardExchangePkg as UniV3SePkgLib
} from "./Phase_05_Stage_04_UniswapV3StandardExchangePkg.sol";

/// @title Phase_05_Stage_04_UniswapV3StandardExchangePkg
/// @notice Skip key: `uniV3SePkg`.
contract Phase_05_Stage_04_UniswapV3StandardExchangePkg is LaunchStageBase {
    function run() external {
        _start("Phase 05 Stage 04: Uni V3 SE pkg");
        if (_shouldSkipStage(FILE_05_04, _skipKeys("uniV3SePkg"))) {
            s.uniV3SePkg = _loadAddr(FILE_05_04, "uniV3SePkg");
        } else {
            _requireDiamondFactory(s);
            _requireCommonFacets(s);
            _requireManager(s);
            _hydrateV3Factory(s);
            _broadcast();
            UniV3SePkgLib.execute(s);
            vm.stopBroadcast();
        }
        _exportPkg("p0504", FILE_05_04, "uniV3SePkg", s.uniV3SePkg);
        _logAddress("uniV3SePkg:", s.uniV3SePkg);
        _logComplete("Phase 05 Stage 04");
    }
}
