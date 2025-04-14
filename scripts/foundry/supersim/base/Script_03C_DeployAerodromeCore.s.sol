// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {DeploymentBase} from "../../anvil_base_main/DeploymentBase.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {CREATE3} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/solmate/CREATE3.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IRouter as IAerodromeRouter} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IRouter.sol";
import {IPoolFactory as IAerodromePoolFactory} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPoolFactory.sol";

import {Pool as AerodromePool} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/Pool.sol";
import {PoolFactory as AerodromePoolFactory} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/factories/PoolFactory.sol";
import {FactoryRegistry as AerodromeFactoryRegistry} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/factories/FactoryRegistry.sol";
import {Router as AerodromeRouter} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/Router.sol";

contract Script_03C_DeployAerodromeCore is DeploymentBase {
    using BetterEfficientHashLib for bytes;

    string internal constant OUTPUT_FILE = "03c_aerodrome_core.json";

    ICreate3FactoryProxy private create3Factory;

    address private deployedAerodromePoolImplementation;
    address private deployedAerodromeFactory;
    address private deployedAerodromeFactoryRegistry;
    address private deployedAerodromeRouter;

    function run() external {
        _loadConfig();
        _bindBaseForkAddrs();

        create3Factory = ICreate3FactoryProxy(_readAddress("01_factories.json", "create3Factory"));
        require(address(create3Factory) != address(0), "Create3Factory not found");

        _logHeader("Base Stage 3C: Deploy Aerodrome Core");

        vm.startBroadcast();
        _deployCore();
        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _deployCore() internal {
        require(address(weth).code.length > 0, "Base Sepolia WETH9 missing");

        deployedAerodromePoolImplementation = _deployCreate3(
            type(AerodromePool).creationCode,
            _salt("BaseSepoliaAerodromePoolImplementation")
        );

        deployedAerodromeFactory = _deployWithArgs(
            type(AerodromePoolFactory).creationCode,
            abi.encode(deployedAerodromePoolImplementation),
            _salt("BaseSepoliaAerodromePoolFactory")
        );

        deployedAerodromeFactoryRegistry = _deployWithArgs(
            type(AerodromeFactoryRegistry).creationCode,
            abi.encode(
                deployedAerodromeFactory,
                deployedAerodromeFactory,
                deployedAerodromeFactory,
                deployer
            ),
            _salt("BaseSepoliaAerodromeFactoryRegistry")
        );

        deployedAerodromeRouter = _deployWithArgs(
            type(AerodromeRouter).creationCode,
            abi.encode(
                address(0),
                deployedAerodromeFactoryRegistry,
                deployedAerodromeFactory,
                address(0),
                address(weth)
            ),
            _salt("BaseSepoliaAerodromeRouter")
        );
    }

    function _salt(string memory name) internal pure returns (bytes32) {
        return abi.encode(name)._hash();
    }

    function _predictAddress(bytes32 salt) internal view returns (address) {
        return CREATE3.getDeployed(salt, address(create3Factory));
    }

    function _deployCreate3(bytes memory creationCode, bytes32 salt) internal returns (address deployed) {
        deployed = _predictAddress(salt);
        if (deployed.code.length == 0) {
            deployed = create3Factory.create3(creationCode, salt);
        }
    }

    function _deployWithArgs(bytes memory creationCode, bytes memory constructorArgs, bytes32 salt)
        internal
        returns (address deployed)
    {
        deployed = _predictAddress(salt);
        if (deployed.code.length == 0) {
            deployed = create3Factory.create3(bytes.concat(creationCode, constructorArgs), salt);
        }
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("", "aerodromePoolImplementation", deployedAerodromePoolImplementation);
        json = vm.serializeAddress("", "aerodromeFactory", deployedAerodromeFactory);
        json = vm.serializeAddress("", "aerodromeFactoryRegistry", deployedAerodromeFactoryRegistry);
        json = vm.serializeAddress("", "aerodromeRouter", deployedAerodromeRouter);
        json = vm.serializeAddress("", "weth", address(weth));
        _writeJson(json, OUTPUT_FILE);
    }

    function _logResults() internal view {
        _logAddress("AerodromePoolImplementation:", deployedAerodromePoolImplementation);
        _logAddress("AerodromeFactory:", deployedAerodromeFactory);
        _logAddress("AerodromeFactoryRegistry:", deployedAerodromeFactoryRegistry);
        _logAddress("AerodromeRouter:", deployedAerodromeRouter);
        _logAddress("Using WETH:", address(weth));
        _logComplete("Base Stage 3C");
    }
}