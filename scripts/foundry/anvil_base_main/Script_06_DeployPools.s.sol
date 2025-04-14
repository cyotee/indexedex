// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";

/// @title Script_06_DeployPools
/// @notice Creates UniswapV2 liquidity pools for test tokens
/// @dev Run: forge script scripts/foundry/anvil_base_main/Script_06_DeployPools.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --unlocked --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
contract Script_06_DeployPools is DeploymentBase {
    // From previous deployments
    address private ttA;
    address private ttB;
    address private ttC;

    // Deployed pools
    IUniswapV2Pair private abPool;
    IUniswapV2Pair private acPool;
    IUniswapV2Pair private bcPool;

    IPool private aeroAbPool;
    IPool private aeroAcPool;
    IPool private aeroBcPool;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 6: Deploy UniV2 + Aerodrome Pools");

        vm.startBroadcast();

        _deployPools();

        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        ttA = _readAddress("05_test_tokens.json", "testTokenA");
        ttB = _readAddress("05_test_tokens.json", "testTokenB");
        ttC = _readAddress("05_test_tokens.json", "testTokenC");

        require(ttA != address(0), "Test Token A not found");
        require(ttB != address(0), "Test Token B not found");
        require(ttC != address(0), "Test Token C not found");
    }

    function _deployPools() internal {
        // Create A-B pool
        address abPairAddr = uniswapV2Factory.getPair(ttA, ttB);
        if (abPairAddr == address(0)) {
            abPairAddr = uniswapV2Factory.createPair(ttA, ttB);
        }
        abPool = IUniswapV2Pair(abPairAddr);

        // Create A-C pool
        address acPairAddr = uniswapV2Factory.getPair(ttA, ttC);
        if (acPairAddr == address(0)) {
            acPairAddr = uniswapV2Factory.createPair(ttA, ttC);
        }
        acPool = IUniswapV2Pair(acPairAddr);

        // Create B-C pool
        address bcPairAddr = uniswapV2Factory.getPair(ttB, ttC);
        if (bcPairAddr == address(0)) {
            bcPairAddr = uniswapV2Factory.createPair(ttB, ttC);
        }
        bcPool = IUniswapV2Pair(bcPairAddr);

        // Create Aerodrome volatile pools (stable=false)
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
        _writeJson(json, "06_pools.json");
    }

    function _logResults() internal view {
        _logAddress("A-B Pool:", address(abPool));
        _logAddress("A-C Pool:", address(acPool));
        _logAddress("B-C Pool:", address(bcPool));

        _logAddress("Aerodrome A-B Pool:", address(aeroAbPool));
        _logAddress("Aerodrome A-C Pool:", address(aeroAcPool));
        _logAddress("Aerodrome B-C Pool:", address(aeroBcPool));
        _logComplete("Stage 6");
    }
}
