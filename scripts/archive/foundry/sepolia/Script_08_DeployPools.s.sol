// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";

contract Script_08_DeployPools is DeploymentBase {
    address private ttA;
    address private ttB;
    address private ttC;

    IUniswapV2Pair private abPool;
    IUniswapV2Pair private acPool;
    IUniswapV2Pair private bcPool;

    IPool private aeroAbPool;
    IPool private aeroAcPool;
    IPool private aeroBcPool;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 8: Deploy UniV2 + Aerodrome Pools");

        vm.startBroadcast();

        _deployPools();

        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        ttA = _readAddress("07_test_tokens.json", "testTokenA");
        ttB = _readAddress("07_test_tokens.json", "testTokenB");
        ttC = _readAddress("07_test_tokens.json", "testTokenC");

        require(ttA != address(0), "Test Token A not found");
        require(ttB != address(0), "Test Token B not found");
        require(ttC != address(0), "Test Token C not found");

        // Load factory addresses from Stage 5 and 6 deployments and set via base class setters
        address uniFactory = _readAddress("05_uniswap_v2.json", "uniswapV2Factory");
        address uniRouter = _readAddress("05_uniswap_v2.json", "uniswapV2Router");
        address aeroFactory = _readAddress("06_aerodrome.json", "aerodromeFactory");
        address aeroRouter = _readAddress("06_aerodrome.json", "aerodromeRouter");

        require(uniFactory != address(0), "UniswapV2Factory not found");
        require(uniRouter != address(0), "UniswapV2Router not found");
        require(aeroFactory != address(0), "AerodromeFactory not found");
        require(aeroRouter != address(0), "AerodromeRouter not found");

        _setOurUniswapV2(uniRouter, uniFactory);
        _setOurAerodrome(aeroRouter, aeroFactory);
    }

    function _deployPools() internal {
        address abPairAddr = uniswapV2Factory.getPair(ttA, ttB);
        if (abPairAddr == address(0)) {
            abPairAddr = uniswapV2Factory.createPair(ttA, ttB);
        }
        abPool = IUniswapV2Pair(abPairAddr);

        address acPairAddr = uniswapV2Factory.getPair(ttA, ttC);
        if (acPairAddr == address(0)) {
            acPairAddr = uniswapV2Factory.createPair(ttA, ttC);
        }
        acPool = IUniswapV2Pair(acPairAddr);

        address bcPairAddr = uniswapV2Factory.getPair(ttB, ttC);
        if (bcPairAddr == address(0)) {
            bcPairAddr = uniswapV2Factory.createPair(ttB, ttC);
        }
        bcPool = IUniswapV2Pair(bcPairAddr);

        address aeroAbAddr = aerodromePoolFactory.getPool(ttA, ttB, false);
        if (aeroAbAddr == address(0)) {
            aeroAbAddr = aerodromePoolFactory.createPool(ttA, ttB, false);
        }
        aeroAbPool = IPool(aeroAbAddr);

        address aeroAcAddr = aerodromePoolFactory.getPool(ttA, ttC, false);
        if (aeroAcAddr == address(0)) {
            aeroAcAddr = aerodromePoolFactory.createPool(ttA, ttC, false);
        }
        aeroAcPool = IPool(aeroAcAddr);

        address aeroBcAddr = aerodromePoolFactory.getPool(ttB, ttC, false);
        if (aeroBcAddr == address(0)) {
            aeroBcAddr = aerodromePoolFactory.createPool(ttB, ttC, false);
        }
        aeroBcPool = IPool(aeroBcAddr);
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("", "abPool", address(abPool));
        json = vm.serializeAddress("", "acPool", address(acPool));
        json = vm.serializeAddress("", "bcPool", address(bcPool));

        json = vm.serializeAddress("", "aeroAbPool", address(aeroAbPool));
        json = vm.serializeAddress("", "aeroAcPool", address(aeroAcPool));
        json = vm.serializeAddress("", "aeroBcPool", address(aeroBcPool));
        _writeJson(json, "08_pools.json");
    }

    function _logResults() internal view {
        _logAddress("A-B Pool:", address(abPool));
        _logAddress("A-C Pool:", address(acPool));
        _logAddress("B-C Pool:", address(bcPool));

        _logAddress("Aerodrome A-B Pool:", address(aeroAbPool));
        _logAddress("Aerodrome A-C Pool:", address(aeroAcPool));
        _logAddress("Aerodrome B-C Pool:", address(aeroBcPool));
        _logComplete("Stage 8");
    }
}
