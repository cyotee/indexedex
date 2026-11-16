// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {Phase_01_Stage_04_UniswapV3 as UniV3Lib} from "./Phase_01_Stage_04_UniswapV3.sol";

/// @title Phase_01_Stage_04_UniswapV3
/// @notice Skip key: `v3Factory`. JSON is the live factory.
contract Phase_01_Stage_04_UniswapV3 is LaunchStageBase {
    function run() external {
        _start("Phase 01 Stage 04: Uniswap V3 factory");
        address v3Factory;
        bool v3Local;
        if (_shouldSkipStage(FILE_01_04, _skipKeys("v3Factory"))) {
            _hydrateV3Factory(s);
            v3Factory = s.v3Factory;
            v3Local = s.v3Local;
        } else {
            _broadcast();
            (v3Factory, v3Local) = UniV3Lib.execute();
            vm.stopBroadcast();
            s.v3Factory = v3Factory;
            s.v3Local = v3Local;
        }
        string memory json;
        json = vm.serializeAddress("p0104", "v3Factory", v3Factory);
        json = vm.serializeAddress("p0104", "uniswapV3Factory", v3Factory);
        json = vm.serializeBool("p0104", "v3Local", v3Local);
        json = vm.serializeUint("p0104", "chainId", block.chainid);
        _writeJson(json, FILE_01_04);
        _logAddress("v3Factory:", v3Factory);
        _logComplete("Phase 01 Stage 04");
    }
}
