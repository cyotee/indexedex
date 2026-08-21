// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchIo} from "./LaunchIo.sol";
import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {Stage_01_Factories} from "./Stage_01_Factories.sol";
import {Stage_02_Platform} from "./Stage_02_Platform.sol";
import {Stage_03_UniV4Packages} from "./Stage_03_UniV4Packages.sol";
import {Stage_03b_OrbitalWeightedPackages} from "./Stage_03b_OrbitalWeightedPackages.sol";
import {Stage_04_Tokens} from "./Stage_04_Tokens.sol";
import {Stage_05_LeafPoolsAndSEs} from "./Stage_05_LeafPoolsAndSEs.sol";
import {Stage_06_LeafDETFs} from "./Stage_06_LeafDETFs.sol";

/// @title Script_SimulateLaunch
/// @notice Alternate to the staged 00–06 + 09 path: runs 01–06 in one script for a gas estimate.
/// @dev Do not run after a completed staged deploy (CREATE3/CREATE2 collision). Group 09 is export-only.
contract Script_SimulateLaunch is LaunchIo {
    LaunchState internal s;

    function run() external {
        _loadConfig();
        _requireRobinhoodTestnet();
        RobinhoodCanonicalLib.requireCanonicalPins();
        _logHeader("Simulate launch: groups 01-06");

        _broadcast();
        Stage_01_Factories.execute(s, owner);
        Stage_02_Platform.execute(s, owner);
        Stage_03_UniV4Packages.execute(s);
        Stage_03b_OrbitalWeightedPackages.execute(s);
        Stage_04_Tokens.execute(s, owner, uiWallet);
        Stage_05_LeafPoolsAndSEs.execute(s, owner);
        vm.stopBroadcast();

        // Mine hook nonces off-chain. If this stays inside startBroadcast, Foundry
        // folds findMineNonce (up to 160_444 CREATE2 hashes) into eth_estimateGas.
        (, uint256 nChir) = Stage_06_LeafDETFs.premineChir(s);
        (, uint256 nDolQ) = Stage_06_LeafDETFs.premineDolQ(s);

        _broadcast();
        Stage_06_LeafDETFs.deployChir(s, owner, nChir);
        Stage_06_LeafDETFs.deployDolQ(s, owner, nDolQ);
        vm.stopBroadcast();

        _exportFactories(s);
        _exportPlatform(s);
        _exportUniV4Packages(s);
        _exportTokens(s);
        _exportLeafPools(s);
        _exportLeafDetfs(s);

        _logAddress("Create3Factory:", address(s.create3Factory));
        _logAddress("IndexedexManager:", address(s.indexedexManager));
        _logAddress("TTCHIR:", s.ttChir);
        _logAddress("TTRICHIR:", s.ttRichir);
        _logAddress("TTDOL-Q:", s.ttDolQ);
        _logComplete("SimulateLaunch 01-06");
    }
}
