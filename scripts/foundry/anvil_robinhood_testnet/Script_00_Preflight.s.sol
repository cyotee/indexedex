// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {ROBINHOOD_TESTNET} from "@crane/contracts/constants/networks/ROBINHOOD_TESTNET.sol";

/// @title Script_00_Preflight
/// @notice Assert chain 46630 and required RH testnet pins. Does not require Uni V3 / pons / Balancer.
contract Script_00_Preflight is DeploymentBase {
    string internal constant ARTIFACT_FILE = "00_preflight.json";

    function run() external {
        _loadConfig();
        _logHeader("Group 00: Preflight (Robinhood testnet pins)");
        _requireRobinhoodTestnet();
        RobinhoodCanonicalLib.requireCanonicalPins();
        _exportJson();
        _logResults();
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeUint("preflight", "chainId", block.chainid);
        json = vm.serializeUint("preflight", "blockNumber", block.number);
        json = vm.serializeAddress("preflight", "poolManager", RobinhoodCanonicalLib.poolManager());
        json = vm.serializeAddress("preflight", "positionManagerV4", RobinhoodCanonicalLib.positionManagerV4());
        json = vm.serializeAddress("preflight", "permit2", RobinhoodCanonicalLib.permit2());
        json = vm.serializeAddress("preflight", "weth", RobinhoodCanonicalLib.weth());
        json = vm.serializeAddress("preflight", "universalRouter", RobinhoodCanonicalLib.universalRouter());
        json = vm.serializeAddress("preflight", "morpho", RobinhoodCanonicalLib.morpho());
        json = vm.serializeAddress("preflight", "morphoBlue", RobinhoodCanonicalLib.morpho());
        json = vm.serializeAddress("preflight", "morphoIrm", RobinhoodCanonicalLib.morphoIrm());
        json = vm.serializeAddress(
            "preflight", "morphoOracleFactory", RobinhoodCanonicalLib.morphoOracleFactory()
        );
        json = vm.serializeAddress(
            "preflight", "morphoVaultV2Factory", RobinhoodCanonicalLib.morphoVaultV2Factory()
        );
        json = vm.serializeAddress(
            "preflight", "morphoVaultV1AdapterFactory", RobinhoodCanonicalLib.morphoVaultV1AdapterFactory()
        );
        json = vm.serializeAddress(
            "preflight",
            "morphoMarketV1AdapterV2Factory",
            RobinhoodCanonicalLib.morphoMarketV1AdapterV2Factory()
        );
        json = vm.serializeAddress("preflight", "morphoRegistry", RobinhoodCanonicalLib.morphoRegistry());
        json = vm.serializeAddress("preflight", "morphoBundler3", RobinhoodCanonicalLib.morphoBundler3());
        json = vm.serializeAddress(
            "preflight", "morphoGeneralAdapter1", RobinhoodCanonicalLib.morphoGeneralAdapter1()
        );
        json = vm.serializeBool("preflight", "morphoHasCode", RobinhoodCanonicalLib.morpho().code.length > 0);
        json = vm.serializeAddress("preflight", "deployer", deployer);
        json = vm.serializeAddress("preflight", "owner", owner);
        json = vm.serializeString("preflight", "networkProfile", _networkProfile());
        json = vm.serializeString(
            "preflight",
            "notes",
            "V3/pons/Balancer not required. Morpho pins match Robinhood main CREATE2; 03c deploys rehearsal Morpho if pin has no code."
        );
        json = vm.serializeAddress("preflight", "usdg", ROBINHOOD_TESTNET.USDG);
        _writeJson(json, ARTIFACT_FILE);
    }

    function _logResults() internal view {
        _logAddress("WETH:", RobinhoodCanonicalLib.weth());
        _logAddress("PoolManager:", RobinhoodCanonicalLib.poolManager());
        _logAddress("Morpho:", RobinhoodCanonicalLib.morpho());
        _logAddress("Morpho IRM:", RobinhoodCanonicalLib.morphoIrm());
        _logAddress("Morpho oracle factory:", RobinhoodCanonicalLib.morphoOracleFactory());
        _logAddress("Morpho Vault V2 factory:", RobinhoodCanonicalLib.morphoVaultV2Factory());
        _logAddress("Morpho registry:", RobinhoodCanonicalLib.morphoRegistry());
        _logAddress("Morpho Bundler3:", RobinhoodCanonicalLib.morphoBundler3());
        _logComplete("Group 00");
    }
}
