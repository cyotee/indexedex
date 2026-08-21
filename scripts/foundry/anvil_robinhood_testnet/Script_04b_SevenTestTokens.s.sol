// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchIo} from "./LaunchIo.sol";
import {LaunchState} from "./LaunchState.sol";
import {Stage_04b_SevenTestTokens} from "./Stage_04b_SevenTestTokens.sol";

/// @title Script_04b_SevenTestTokens
/// @notice Group 04b: Mag7 test tokens, facade as global operator, 1e6 of each plus TTWETH to deployer.
contract Script_04b_SevenTestTokens is LaunchIo {
    LaunchState internal s;

    function run() external {
        _loadConfig();
        _requireRobinhoodTestnet();
        require(_loadTokens(s), "run Script_04_Tokens first");
        _logHeader("Group 04b: Seven test tokens");

        Stage_04b_SevenTestTokens.SevenTokens memory existing;
        (
            existing.ttNVDA,
            existing.ttMSFT,
            existing.ttAAPL,
            existing.ttGOOGL,
            existing.ttAMZN,
            existing.ttMETA,
            existing.ttTSLA
        ) = _loadSevenTokens();

        _broadcast();
        Stage_04b_SevenTestTokens.SevenTokens memory tokens =
            Stage_04b_SevenTestTokens.execute(s, deployer, existing);
        vm.stopBroadcast();

        _exportSevenTokens(
            s,
            tokens.ttNVDA,
            tokens.ttMSFT,
            tokens.ttAAPL,
            tokens.ttGOOGL,
            tokens.ttAMZN,
            tokens.ttMETA,
            tokens.ttTSLA
        );
        _logAddress("TTNVDA:", tokens.ttNVDA);
        _logAddress("TTMSFT:", tokens.ttMSFT);
        _logAddress("TTAAPL:", tokens.ttAAPL);
        _logAddress("TTGOOGL:", tokens.ttGOOGL);
        _logAddress("TTAMZN:", tokens.ttAMZN);
        _logAddress("TTMETA:", tokens.ttMETA);
        _logAddress("TTTSLA:", tokens.ttTSLA);
        _logAddress("TTWETH:", s.ttWETH);
        _logComplete("Group 04b");
    }
}
