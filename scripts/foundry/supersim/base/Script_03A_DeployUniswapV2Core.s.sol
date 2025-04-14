// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "../../anvil_base_main/DeploymentBase.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IUniswapV2Factory} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Factory.sol";
import {IUniswapV2Router} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Router.sol";
import {UniV2Factory} from "@crane/contracts/protocols/dexes/uniswap/v2/stubs/UniV2Factory.sol";
import {UniV2Router02} from "@crane/contracts/protocols/dexes/uniswap/v2/stubs/UniV2Router02.sol";

contract Script_03A_DeployUniswapV2Core is DeploymentBase {
    ICreate3FactoryProxy private create3Factory;
    IDiamondPackageCallBackFactory private diamondPackageFactory;

    IUniswapV2Factory private deployedUniswapV2Factory;
    IUniswapV2Router private deployedUniswapV2Router;

    function run() external {
        _loadConfig();
        _bindBaseForkAddrs();
        _loadPreviousDeployments();

        _logHeader("Base Stage 3A: Deploy Uniswap V2 Core");

        vm.startBroadcast();

        _deployUniswapV2Factory();
        _deployUniswapV2Router();

        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        create3Factory = ICreate3FactoryProxy(_readAddress("01_factories.json", "create3Factory"));
        diamondPackageFactory = IDiamondPackageCallBackFactory(_readAddress("01_factories.json", "diamondPackageFactory"));

        require(address(create3Factory) != address(0), "Create3Factory not found");
        require(address(diamondPackageFactory) != address(0), "DiamondPackageFactory not found");
        require(address(weth).code.length > 0, "Base Sepolia WETH9 missing");
    }

    function _deployUniswapV2Factory() internal {
        deployedUniswapV2Factory = new UniV2Factory(owner);
    }

    function _deployUniswapV2Router() internal {
        deployedUniswapV2Router = new UniV2Router02(address(deployedUniswapV2Factory), address(weth));
    }

    function _exportJson() internal {
        string memory json;

        json = vm.serializeAddress("", "uniswapV2Factory", address(deployedUniswapV2Factory));
        json = vm.serializeAddress("", "uniswapV2Router", address(deployedUniswapV2Router));
        json = vm.serializeAddress("", "weth", address(weth));

        _writeJson(json, "03a_uniswap_v2_core.json");
    }

    function _logResults() internal view {
        _logAddress("UniswapV2Factory:", address(deployedUniswapV2Factory));
        _logAddress("UniswapV2Router:", address(deployedUniswapV2Router));
        _logAddress("Using WETH:", address(weth));
        _logComplete("Base Stage 3A");
    }
}