// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {
    Phase_05_Stage_02_UniswapV4TwapOracle as TwapOracleLib
} from "./Phase_05_Stage_02_UniswapV4TwapOracle.sol";

/// @title Phase_05_Stage_02_UniswapV4TwapOracle
/// @notice Skip keys: `twapOraclePkg`, `twapOracle`, `twapAdapterFactory`.
contract Phase_05_Stage_02_UniswapV4TwapOracle is LaunchStageBase {
    function run() external {
        _start("Phase 05 Stage 02: Uni V4 TWAP oracle");
        RobinhoodCanonicalLib.requireCanonicalPins();
        if (_shouldSkipStage(FILE_05_02, _skipKeys("twapOraclePkg", "twapOracle", "twapAdapterFactory"))) {
            _requireTwapOracle(s);
        } else {
            _requireDiamondFactory(s);
            _broadcast();
            TwapOracleLib.execute(s);
            vm.stopBroadcast();
        }
        _exportTwapOracle(s);
        _logAddress("twapOracleFacet:", address(s.twapOracleFacet));
        _logAddress("twapOraclePkg:", address(s.twapOraclePkg));
        _logAddress("twapOracle:", address(s.twapOracle));
        _logAddress("twapAdapterFactory:", s.twapAdapterFactory);
        _logComplete("Phase 05 Stage 02");
    }
}
