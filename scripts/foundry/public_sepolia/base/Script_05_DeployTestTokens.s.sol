// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";

contract Script_05_DeployTestTokens is DeploymentBase {
    address private ttA;
    address private ttB;
    address private ttC;
    address private demoWeth;
    address private richToken;

    function run() external {
        _setup();
        _loadBridgeTokens();
        _exportJson();
    }

    function _loadBridgeTokens() internal {
        ttA = _readAddress("05_bridge_tokens.json", "testTokenA");
        ttB = _readAddress("05_bridge_tokens.json", "testTokenB");
        ttC = _readAddress("05_bridge_tokens.json", "testTokenC");
        demoWeth = _readAddress("05_bridge_tokens.json", "demoWeth");
        richToken = _readAddress("05_bridge_tokens.json", "richToken");

        require(ttA.code.length > 0, "Bridge token TTA missing");
        require(ttB.code.length > 0, "Bridge token TTB missing");
        require(ttC.code.length > 0, "Bridge token TTC missing");
        require(demoWeth.code.length > 0, "Bridge token DemoWETH missing");
        require(richToken.code.length > 0, "Bridge token RICH missing");
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("tokens", "testTokenA", ttA);
        json = vm.serializeAddress("tokens", "testTokenB", ttB);
        json = vm.serializeAddress("tokens", "testTokenC", ttC);
        json = vm.serializeAddress("tokens", "demoWeth", demoWeth);
        json = vm.serializeAddress("tokens", "richToken", richToken);
        _writeJson(json, "05_test_tokens.json");
    }
}