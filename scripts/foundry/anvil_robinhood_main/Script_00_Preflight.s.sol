// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {ROBINHOOD_MAIN} from "@crane/contracts/constants/networks/ROBINHOOD_MAIN.sol";

/// @title Script_00_Preflight
/// @notice Assert chain 4663 and required RH Uni V4 / Permit2 / WETH pins. No txs.
contract Script_00_Preflight is DeploymentBase {
    string internal constant ARTIFACT_FILE = "00_preflight.json";

    function run() external {
        _loadConfig();
        _logHeader("Group 00: Preflight (Robinhood mainnet pins)");
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
        json = vm.serializeAddress("preflight", "positionManagerV4", RobinhoodCanonicalLib.positionManagerV4());
        json = vm.serializeAddress("preflight", "permit2", RobinhoodCanonicalLib.permit2());
        json = vm.serializeAddress("preflight", "weth", RobinhoodCanonicalLib.weth());
        json = vm.serializeAddress("preflight", "universalRouter", RobinhoodCanonicalLib.universalRouter());
        json = vm.serializeAddress("preflight", "deployer", deployer);
        json = vm.serializeAddress("preflight", "owner", owner);
        json = vm.serializeString("preflight", "networkProfile", _networkProfile());
        json = vm.serializeString("preflight", "notes", "V4 Protocol DETF architecture; Uni V3 not required");
        _writeJson(json, ARTIFACT_FILE);
    }

    function _logResults() internal view {
        _logUint("ChainId:", block.chainid);
        _logAddress("WETH:", RobinhoodCanonicalLib.weth());
        _logAddress("PoolManager:", RobinhoodCanonicalLib.poolManager());
        _logAddress("PositionManagerV4:", RobinhoodCanonicalLib.positionManagerV4());
        _logAddress("Deployer:", deployer);
        _logComplete("Group 00");
    }
}
