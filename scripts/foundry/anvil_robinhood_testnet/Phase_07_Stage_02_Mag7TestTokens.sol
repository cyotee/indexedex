// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchState} from "./LaunchState.sol";
import {Mag7TestTokensLib} from "./Mag7TestTokensLib.sol";

/// @title Phase_07_Stage_02_Mag7TestTokens
/// @notice Mag7 TTNVDA…TTTSLA. Same facade operator + mint policy as current 04b.
library Phase_07_Stage_02_Mag7TestTokens {
    function execute(LaunchState storage s, address deployer_) internal {
        Mag7TestTokensLib.SevenTokens memory existing;
        existing.ttNVDA = s.ttNVDA;
        existing.ttMSFT = s.ttMSFT;
        existing.ttAAPL = s.ttAAPL;
        existing.ttGOOGL = s.ttGOOGL;
        existing.ttAMZN = s.ttAMZN;
        existing.ttMETA = s.ttMETA;
        existing.ttTSLA = s.ttTSLA;
        Mag7TestTokensLib.SevenTokens memory tokens = Mag7TestTokensLib.execute(s, deployer_, existing);
        s.ttNVDA = tokens.ttNVDA;
        s.ttMSFT = tokens.ttMSFT;
        s.ttAAPL = tokens.ttAAPL;
        s.ttGOOGL = tokens.ttGOOGL;
        s.ttAMZN = tokens.ttAMZN;
        s.ttMETA = tokens.ttMETA;
        s.ttTSLA = tokens.ttTSLA;
    }
}
