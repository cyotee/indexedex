// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchIo} from "./LaunchIo.sol";
import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {Stage_01_Factories} from "./Stage_01_Factories.sol";
import {Stage_02_Platform} from "./Stage_02_Platform.sol";
import {Stage_03_UniV4Packages} from "./Stage_03_UniV4Packages.sol";

/// @title Script_SimulateArchitecture
/// @notice Single Foundry script wrapping groups 01–03 for one architecture gas estimate.
/// @dev Run without `--broadcast` so Foundry reports one simulation total. The shell wrapper
///      uses EIP-1559 (no `--legacy` / `--gas-price`) and quotes deployer funding from the
///      fork source fee market. Do not run after a completed staged deploy (CREATE3 / CREATE2
///      collision). No tokens. No DETF instances.
contract Script_SimulateArchitecture is LaunchIo {
    LaunchState internal s;

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        RobinhoodCanonicalLib.requireCanonicalPins();
        _logHeader("Simulate architecture: groups 01-03");

        _broadcast();
        Stage_01_Factories.execute(s, owner);
        Stage_02_Platform.execute(s, owner);
        Stage_03_UniV4Packages.execute(s);
        vm.stopBroadcast();

        _exportFactories(s);
        _exportPlatform(s);
        _exportUniV4Packages(s);

        _logAddress("Create3Factory:", address(s.create3Factory));
        _logAddress("IndexedexManager:", address(s.indexedexManager));
        _logAddress("uniV4SePkg:", address(s.uniV4SePkg));
        _logAddress("cpDetfPkg:", s.cpDetfPkg);
        _logAddress("curveQuadDetfPkg:", s.curveQuadDetfPkg);
        _logComplete("SimulateArchitecture 01-03");
    }
}
