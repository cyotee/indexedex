// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchIo} from "./LaunchIo.sol";
import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {Stage_01_Factories} from "./Stage_01_Factories.sol";
import {Stage_02_Platform} from "./Stage_02_Platform.sol";
import {Stage_03_UniV4Packages} from "./Stage_03_UniV4Packages.sol";
import {Stage_04_Tokens} from "./Stage_04_Tokens.sol";
import {Stage_05_LeafPoolsAndSEs} from "./Stage_05_LeafPoolsAndSEs.sol";
import {Stage_06_LeafDETFs} from "./Stage_06_LeafDETFs.sol";
import {Stage_07_NestDETFs} from "./Stage_07_NestDETFs.sol";
import {Stage_08_FeeSink} from "./Stage_08_FeeSink.sol";

/// @title Script_SimulateLaunch
/// @notice Runs groups 01–08. Premine windows sit between broadcasts. Omit `--broadcast` for gas estimate.
/// @dev Group 09 is export-only and is not inside this script.
contract Script_SimulateLaunch is LaunchIo {
    LaunchState internal s;

    function run() external {
        _loadConfig();
        _requireRobinhoodTestnet();
        _requireLocalhostIfBroadcast();
        RobinhoodCanonicalLib.requireCanonicalPins();
        _logHeader("Simulate launch: groups 01-08");

        vm.startBroadcast();
        Stage_01_Factories.execute(s, owner);
        Stage_02_Platform.execute(s, owner);
        Stage_03_UniV4Packages.execute(s);
        Stage_04_Tokens.execute(s, owner, uiWallet);
        Stage_05_LeafPoolsAndSEs.execute(s, owner);
        vm.stopBroadcast();

        // Mine hook nonces off-chain. If this stays inside startBroadcast, Foundry
        // folds findMineNonce (up to 160_444 CREATE2 hashes) into eth_estimateGas.
        (, uint256 nNvdaS) = Stage_06_LeafDETFs.premineNvdaS(s);
        (, uint256 nNvdaSmhO) = Stage_06_LeafDETFs.premineNvdaSmhO(s);
        (, uint256 nIdxQ) = Stage_06_LeafDETFs.premineIdxQ(s);
        (, uint256 nDolQ) = Stage_06_LeafDETFs.premineDolQ(s);

        vm.startBroadcast();
        Stage_06_LeafDETFs.deployNvdaS(s, owner, nNvdaS);
        Stage_06_LeafDETFs.deployNvdaSmhO(s, owner, nNvdaSmhO);
        Stage_06_LeafDETFs.deployIdxQ(s, owner, nIdxQ);
        Stage_06_LeafDETFs.deployDolQ(s, owner, nDolQ);
        Stage_07_NestDETFs.deployPoolsAndSes(s);
        Stage_07_NestDETFs.ensureBondCapital(s, owner);
        vm.stopBroadcast();

        (, uint256 nBetaO) = Stage_07_NestDETFs.premineBetaO(s);
        (, uint256 nIdxWrap) = Stage_07_NestDETFs.premineIdxWrap(s);

        vm.startBroadcast();
        Stage_07_NestDETFs.deployBetaO(s, owner, nBetaO);
        Stage_07_NestDETFs.deployIdxWrap(s, owner, nIdxWrap);
        Stage_08_FeeSink.deployTtrichInfra(s, owner, uiWallet);
        vm.stopBroadcast();

        (, uint256 nRichS) = Stage_08_FeeSink.premineRichS(s);

        vm.startBroadcast();
        Stage_08_FeeSink.deployRichS(s, owner, nRichS);
        vm.stopBroadcast();

        _exportFactories(s);
        _exportPlatform(s);
        _exportUniV4Packages(s);
        _exportTokens(s);
        _exportLeafPools(s);
        _exportLeafDetfs(s);
        _exportNestDetfs(s);
        _exportFeeSink(s);

        _logAddress("Create3Factory:", address(s.create3Factory));
        _logAddress("IndexedexManager:", address(s.indexedexManager));
        _logAddress("TTNVDA-S:", s.ttNvdaS);
        _logAddress("TTRICH-S:", s.ttRichS);
        _logComplete("SimulateLaunch 01-08");
    }
}
