// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {Phase_05_Stage_06_UniswapV2StandardExchangePkg as PackageStage} from "./Phase_05_Stage_06_UniswapV2StandardExchangePkg.sol";

contract Phase_05_Stage_06_UniswapV2StandardExchangePkg is LaunchStageBase {
    function run() external {
        _start("Phase 05 Stage 06: Uniswap V2 SE pkg");
        _requireDiamondFactory(s);
        _requireCommonFacets(s);
        _requireManager(s);
        _broadcast();
        PackageStage.execute(s);
        vm.stopBroadcast();
        _exportPkg("p0506", FILE_05_06, "uniV2SePkg", s.uniV2SePkg);
        _logAddress("uniV2SePkg:", s.uniV2SePkg);
        _logComplete("Phase 05 Stage 06");
    }
}
