// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {Phase_06_Stage_07_UniswapV4DetfPkg as UniV4DetfLib} from "./Phase_06_Stage_07_UniswapV4DetfPkg.sol";

/// @title Phase_06_Stage_07_UniswapV4DetfPkg
/// @notice Skip key: `uniV4DetfPkg`.
contract Phase_06_Stage_07_UniswapV4DetfPkg is LaunchStageBase {
    function run() external {
        _start("Phase 06 Stage 07: UniswapV4Detf pkg");
        RobinhoodCanonicalLib.requireCanonicalPins();
        if (_shouldSkipStage(FILE_06_07, _skipKeys("uniV4DetfPkg"))) {
            s.uniV4DetfPkg = _loadAddr(FILE_06_07, "uniV4DetfPkg");
        } else {
            _requireDiamondFactory(s);
            _requireCommonFacets(s);
            _requireManager(s);
            s.bondNftVaultPkg = _loadAddr(FILE_06_01, "bondNftVaultPkg");
            s.rebasingClaimTokenPkg = _loadAddr(FILE_06_02, "rebasingClaimTokenPkg");
            _broadcast();
            UniV4DetfLib.execute(s);
            vm.stopBroadcast();
        }
        _exportPkg("p0607", FILE_06_07, "uniV4DetfPkg", s.uniV4DetfPkg);
        _logAddress("uniV4DetfPkg:", s.uniV4DetfPkg);
        _logComplete("Phase 06 Stage 07");
    }
}
