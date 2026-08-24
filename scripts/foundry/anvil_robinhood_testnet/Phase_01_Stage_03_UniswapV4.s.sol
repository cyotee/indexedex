// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {Phase_01_Stage_03_UniswapV4 as UniV4Lib} from "./Phase_01_Stage_03_UniswapV4.sol";

/// @title Phase_01_Stage_03_UniswapV4
/// @notice Skip keys: `poolManager`, `positionManagerV4`, `universalRouter`.
contract Phase_01_Stage_03_UniswapV4 is LaunchStageBase {
    function run() external {
        _start("Phase 01 Stage 03: Uniswap V4 pin");
        UniV4Lib.Pins memory pins;
        if (_shouldSkipStage(FILE_01_03, _skipKeys("poolManager", "positionManagerV4", "universalRouter"))) {
            pins.poolManager = _loadAddr(FILE_01_03, "poolManager");
            pins.positionManagerV4 = _loadAddr(FILE_01_03, "positionManagerV4");
            pins.universalRouter = _loadAddr(FILE_01_03, "universalRouter");
            pins.quoter = _loadAddr(FILE_01_03, "quoter");
            pins.stateView = _loadAddr(FILE_01_03, "stateView");
        } else {
            pins = UniV4Lib.execute();
        }
        string memory json;
        json = vm.serializeAddress("p0103", "poolManager", pins.poolManager);
        json = vm.serializeAddress("p0103", "positionManagerV4", pins.positionManagerV4);
        json = vm.serializeAddress("p0103", "universalRouter", pins.universalRouter);
        json = vm.serializeAddress("p0103", "quoter", pins.quoter);
        json = vm.serializeAddress("p0103", "stateView", pins.stateView);
        json = vm.serializeUint("p0103", "chainId", block.chainid);
        _writeJson(json, FILE_01_03);
        _logAddress("poolManager:", pins.poolManager);
        _logComplete("Phase 01 Stage 03");
    }
}
