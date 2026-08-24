// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {
    Phase_05_Stage_03_UniswapV4StandardExchangePkg as UniV4SePkgLib
} from "./Phase_05_Stage_03_UniswapV4StandardExchangePkg.sol";

/// @title Phase_05_Stage_03_UniswapV4StandardExchangePkg
/// @notice Skip key: `uniV4SePkg`.
contract Phase_05_Stage_03_UniswapV4StandardExchangePkg is LaunchStageBase {
    function run() external {
        _start("Phase 05 Stage 03: Uni V4 SE pkg");
        RobinhoodCanonicalLib.requireCanonicalPins();
        if (_shouldSkipStage(FILE_05_03, _skipKeys("uniV4SePkg"))) {
            _requireUniV4SePkg(s);
        } else {
            _requireDiamondFactory(s);
            _requireCommonFacets(s);
            _requireManager(s);
            _requireTwapOracle(s);
            _broadcast();
            UniV4SePkgLib.execute(s);
            vm.stopBroadcast();
        }
        _exportPkg("p0503", FILE_05_03, "uniV4SePkg", address(s.uniV4SePkg));
        _logAddress("uniV4SePkg:", address(s.uniV4SePkg));
        _logComplete("Phase 05 Stage 03");
    }
}
