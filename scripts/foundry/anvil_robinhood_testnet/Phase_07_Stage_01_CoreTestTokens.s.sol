// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {Phase_07_Stage_01_CoreTestTokens as TokensLib} from "./Phase_07_Stage_01_CoreTestTokens.sol";

/// @title Phase_07_Stage_01_CoreTestTokens
/// @notice Skip keys: `DTF`, `TTUSDG`, `TTUSDE`, `TTWETH`.
contract Phase_07_Stage_01_CoreTestTokens is LaunchStageBase {
    function run() external {
        _start("Phase 07 Stage 01: Core test tokens");
        if (_shouldSkipStage(FILE_07_01, _skipKeys("DTF", "TTUSDG", "TTUSDE", "TTWETH"))) {
            _requireCoreTokens(s);
            s.erc20MinterFacade = _loadAddr(FILE_07_01, "erc20MinterFacade");
        } else {
            _requireDiamondFactory(s);
            _requireCommonFacets(s);
            _requireFacade(s);
            s.tokenPkg = _loadAddr(FILE_07_01, "tokenPkg");
            s.ttUSDG = _loadAddr(FILE_07_01, "TTUSDG");
            s.ttUSDE = _loadAddr(FILE_07_01, "TTUSDE");
            s.ttWETH = _loadAddr(FILE_07_01, "TTWETH");
            s.ttRICH = _loadAddr(FILE_07_01, "DTF");
            _broadcast();
            TokensLib.execute(s, owner, uiWallet);
            vm.stopBroadcast();
        }
        _exportCoreTokens(s);
        _logAddress("DTF:", s.ttRICH);
        _logAddress("TTWETH:", s.ttWETH);
        _logComplete("Phase 07 Stage 01");
    }
}
