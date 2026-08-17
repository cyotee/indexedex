// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchIo} from "./LaunchIo.sol";
import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {Stage_04_Tokens} from "./Stage_04_Tokens.sol";

/// @title Script_04_Tokens
/// @notice Group 04: 13 stand-in tokens + facade + 1e12 to #0 and #1.
contract Script_04_Tokens is LaunchIo {
    LaunchState internal s;

    function run() external {
        _loadConfig();
        _requireRobinhoodTestnet();
        _requireLocalhostIfBroadcast();
        RobinhoodCanonicalLib.requireCanonicalPins();
        require(_loadFactories(s), "run Script_01_Factories first");
        _logHeader("Group 04: Tokens + facade");

        if (_artifactValid(FILE_TOKENS, "erc20MinterFacade") && _artifactValid(FILE_TOKENS, "TTUSDG")) {
            require(_loadTokens(s), "04_tokens.json incomplete");
            _exportTokens(s);
            _logComplete("Group 04 (cached)");
            return;
        }

        vm.startBroadcast();
        Stage_04_Tokens.execute(s, owner, uiWallet);
        vm.stopBroadcast();

        _exportTokens(s);
        _logAddress("erc20MinterFacade:", s.erc20MinterFacade);
        _logAddress("TTUSDG:", s.ttUSDG);
        _logComplete("Group 04");
    }
}
