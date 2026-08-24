// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchIo} from "./LaunchIo.sol";
import {LaunchState} from "./LaunchState.sol";

/// @title LaunchStageBase
/// @notice Thin Foundry Stage script base for 4663 architecture Stages.
abstract contract LaunchStageBase is LaunchIo {
    LaunchState internal s;

    function _start(string memory title) internal {
        _loadConfig();
        _requireRobinhoodChain();
        _logHeader(title);
    }
}
