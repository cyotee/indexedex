// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {ROBINHOOD_MAIN} from "@crane/contracts/constants/networks/ROBINHOOD_MAIN.sol";

/// @title Script_00_Preflight
/// @notice Assert chain id 4663 and RH Uni/Permit2/WETH pins have code; write 00_preflight.json.
contract Script_00_Preflight is DeploymentBase {
    string internal constant ARTIFACT_FILE = "00_preflight.json";

    function run() external {
        _loadConfig();
        _logHeader("Stage 00: Preflight (Robinhood fork pins)");

        _requireRobinhoodChain();
        RobinhoodCanonicalLib.requireCanonicalPins();

        _exportJson();
        _logResults();
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeUint("preflight", "chainId", block.chainid);
        json = vm.serializeUint("preflight", "forkBlockDefault", ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK);
        json = vm.serializeUint("preflight", "blockNumber", block.number);
        json = vm.serializeAddress("preflight", "poolManager", RobinhoodCanonicalLib.poolManager());
        json = vm.serializeAddress("preflight", "v3Factory", RobinhoodCanonicalLib.v3Factory());
        json = vm.serializeAddress("preflight", "v3Npm", RobinhoodCanonicalLib.v3Npm());
        json = vm.serializeAddress("preflight", "positionManagerV4", RobinhoodCanonicalLib.positionManagerV4());
        json = vm.serializeAddress("preflight", "permit2", RobinhoodCanonicalLib.permit2());
        json = vm.serializeAddress("preflight", "weth", RobinhoodCanonicalLib.weth());
        json = vm.serializeAddress("preflight", "universalRouter", RobinhoodCanonicalLib.universalRouter());
        json = vm.serializeAddress("preflight", "deployer", deployer);
        json = vm.serializeAddress("preflight", "owner", owner);
        json = vm.serializeAddress("preflight", "uiWallet", uiWallet);
        json = vm.serializeString("preflight", "networkProfile", _networkProfile());
        json = vm.serializeString("preflight", "notes", "RH Uni cores pinned; no hermetic PoolManager/V3 factory");
        _writeJson(json, ARTIFACT_FILE);
    }

    function _logResults() internal view {
        _logString("Artifact:", ARTIFACT_FILE);
        _logUint("ChainId:", block.chainid);
        _logAddress("PoolManager:", RobinhoodCanonicalLib.poolManager());
        _logAddress("V3Factory:", RobinhoodCanonicalLib.v3Factory());
        _logAddress("Deployer:", deployer);
        _logAddress("UiWallet:", uiWallet);
        _logComplete("Stage 00");
    }
}
