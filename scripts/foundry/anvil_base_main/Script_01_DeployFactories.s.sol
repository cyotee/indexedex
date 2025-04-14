// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {InitDevService} from "@crane/contracts/InitDevService.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";

/// @title Script_01_DeployFactories
/// @notice Deploys Create3Factory and DiamondPackageCallBackFactory
/// @dev Run: forge script scripts/foundry/anvil_base_main/Script_01_DeployFactories.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --unlocked --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
contract Script_01_DeployFactories is DeploymentBase {
    ICreate3FactoryProxy private create3Factory;
    IDiamondPackageCallBackFactory private diamondPackageFactory;

    function run() external {
        _loadConfig();

        _logHeader("Stage 1: Deploy Factories");

        if (_loadExistingFactories()) {
            _exportJson();
            _logResults();
            return;
        }

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

    function _loadExistingFactories() internal returns (bool) {
        (address create3FactoryAddr, bool hasCreate3Factory) = _readAddressSafe("01_factories.json", "create3Factory");
        (address diamondPackageFactoryAddr, bool hasDiamondPackageFactory) =
            _readAddressSafe("01_factories.json", "diamondPackageFactory");

        if (!hasCreate3Factory || !hasDiamondPackageFactory) {
            return false;
        }

        if (create3FactoryAddr.code.length == 0 || diamondPackageFactoryAddr.code.length == 0) {
            return false;
        }

        create3Factory = ICreate3FactoryProxy(create3FactoryAddr);
        diamondPackageFactory = IDiamondPackageCallBackFactory(diamondPackageFactoryAddr);

        return true;
    }

    function _logResults() internal view {
        _logAddress("Create3Factory:", address(create3Factory));
        _logAddress("DiamondPackageFactory:", address(diamondPackageFactory));
        _logAddress("Owner:", owner);
        _logComplete("Stage 1");
    }
}
