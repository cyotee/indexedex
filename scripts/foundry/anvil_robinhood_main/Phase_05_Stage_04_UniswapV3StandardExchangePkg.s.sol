// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {Phase_05_Stage_04_UniswapV3StandardExchangePkg as PackageStage} from "./Phase_05_Stage_04_UniswapV3StandardExchangePkg.sol";

contract Phase_05_Stage_04_UniswapV3StandardExchangePkg is LaunchStageBase {
    function run() external {
        _start("Phase 05 Stage 04: Uniswap V3 SE pkg");
        _requireDiamondFactory(s);
        _requireCommonFacets(s);
        _requireManager(s);
        _broadcast();
        PackageStage.execute(s);
        vm.stopBroadcast();
        _exportPkg("p0504", FILE_05_04, "uniV3SePkg", s.uniV3SePkg);
        _logAddress("uniV3SePkg:", s.uniV3SePkg);
        _logComplete("Phase 05 Stage 04");
    }
}
