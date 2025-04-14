// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {InitDevService} from "@crane/contracts/InitDevService.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";

contract Script_01_DeployFactories is DeploymentBase {
    ICreate3FactoryProxy private create3Factory;
    IDiamondPackageCallBackFactory private diamondPackageFactory;

    function run() external {
        _setup();

        _logHeader("Stage 1: Deploy Factories");

        vm.startBroadcast();

        (create3Factory, diamondPackageFactory) = InitDevService.initEnv(owner);

        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("factories", "create3Factory", address(create3Factory));
        json = vm.serializeAddress("factories", "diamondPackageFactory", address(diamondPackageFactory));
        json = vm.serializeAddress("factories", "owner", owner);
        json = vm.serializeAddress("factories", "deployer", deployer);
        _writeJson(json, "01_factories.json");
    }

    function _logResults() internal view {
        _logAddress("Create3Factory:", address(create3Factory));
        _logAddress("DiamondPackageFactory:", address(diamondPackageFactory));
        _logAddress("Owner:", owner);
        _logComplete("Stage 1");
    }
}
