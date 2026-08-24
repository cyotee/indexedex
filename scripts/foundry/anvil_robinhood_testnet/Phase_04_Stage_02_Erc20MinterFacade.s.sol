// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {Phase_04_Stage_02_Erc20MinterFacade as FacadeLib} from "./Phase_04_Stage_02_Erc20MinterFacade.sol";

/// @title Phase_04_Stage_02_Erc20MinterFacade
/// @notice Skip key: `erc20MinterFacade`.
contract Phase_04_Stage_02_Erc20MinterFacade is LaunchStageBase {
    function run() external {
        _start("Phase 04 Stage 02: ERC20 minter facade");
        if (_shouldSkipStage(FILE_04_02, _skipKeys("erc20MinterFacade"))) {
            _requireFacade(s);
        } else {
            _requireDiamondFactory(s);
            _broadcast();
            FacadeLib.execute(s);
            vm.stopBroadcast();
        }
        _exportFacade(s);
        _logAddress("erc20MinterFacade:", s.erc20MinterFacade);
        _logComplete("Phase 04 Stage 02");
    }
}
