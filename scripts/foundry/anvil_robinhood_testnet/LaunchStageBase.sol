// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchIo} from "./LaunchIo.sol";
import {LaunchState} from "./LaunchState.sol";

/// @title LaunchStageBase
/// @notice Thin Foundry Stage script base: config, skip-if-JSON-valid, FORCE, JSON rewrite.
abstract contract LaunchStageBase is LaunchIo {
    LaunchState internal s;

    function _start(string memory title) internal {
        _loadConfig();
        _bindCreator(s);
        _requireRobinhoodTestnet();
        _logHeader(title);
    }
}
