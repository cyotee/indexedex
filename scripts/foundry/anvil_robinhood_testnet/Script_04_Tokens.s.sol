// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchIo} from "./LaunchIo.sol";
import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {Stage_04_Tokens} from "./Stage_04_Tokens.sol";

/// @title Script_04_Tokens
/// @notice Group 04: `TTRICH` + `TTUSDG` / `TTUSDE` / `TTWETH` + facade + 1e12 to deployer and UI_WALLET.
contract Script_04_Tokens is LaunchIo {
    LaunchState internal s;

    function run() external {
        _loadConfig();
        _requireRobinhoodTestnet();
        RobinhoodCanonicalLib.requireCanonicalPins();
        require(_loadFactories(s), "run Script_01_Factories first");
        _logHeader("Group 04: Tokens + facade");

        if (_artifactValid(FILE_TOKENS, "erc20MinterFacade") && _artifactValid(FILE_TOKENS, "TTUSDG")) {
            require(_loadTokens(s), "04_tokens.json incomplete");
            if (!_hasCode(s.ttRICH) || !_hasCode(s.ttWETH)) {
                _broadcast();
                if (!_hasCode(s.ttRICH)) Stage_04_Tokens.deployAndMintTtrich(s, owner, uiWallet);
                if (!_hasCode(s.ttWETH)) Stage_04_Tokens.deployAndMintTtweth(s, owner, uiWallet);
                vm.stopBroadcast();
            }
            _exportTokens(s);
            _logAddress("TTRICH:", s.ttRICH);
            _logAddress("TTWETH:", s.ttWETH);
            _logComplete("Group 04 (cached)");
            return;
        }

        _broadcast();
        Stage_04_Tokens.execute(s, owner, uiWallet);
        vm.stopBroadcast();

        _exportTokens(s);
        _logAddress("erc20MinterFacade:", s.erc20MinterFacade);
        _logAddress("TTUSDG:", s.ttUSDG);
        _logAddress("TTWETH:", s.ttWETH);
        _logAddress("TTRICH:", s.ttRICH);
        _logComplete("Group 04");
    }
}
