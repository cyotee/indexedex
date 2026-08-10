// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {FixtureGraph} from "./FixtureGraph.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {UniswapV4LiquiditySeeder} from "scripts/foundry/shared/UniswapV4LiquiditySeeder.sol";

/// @title Script_06_DeployUniV4PoolsAndSeed
/// @notice Initialize + seed Uni V4 pools on RH PoolManager for V4 SE underlyings.
contract Script_06_DeployUniV4PoolsAndSeed is DeploymentBase {
    string internal constant TOKENS_FILE = "04_test_tokens.json";
    string internal constant ARTIFACT_FILE = "06_univ4_pools.json";

    address private tt4;
    address private tt5;
    address private tt6;
    address private tt7;
    address private seeder;
    bytes32 private v4SePoolAId;
    bytes32 private v4SePoolBId;

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        RobinhoodCanonicalLib.requireCanonicalPins();
        _loadTokens();
        _logHeader("Stage 06: Uni V4 pools + seed (RH PoolManager)");

        if (_loadExisting()) {
            _exportJson();
            _logResults();
            return;
        }

        IPoolManager pm = IPoolManager(RobinhoodCanonicalLib.poolManager());

        vm.startBroadcast();
        UniswapV4LiquiditySeeder seederC = new UniswapV4LiquiditySeeder(pm);
        seeder = address(seederC);

        PoolKey memory keyA = _buildKey(tt4, tt5);
        PoolKey memory keyB = _buildKey(tt6, tt7);

        // initialize may revert if already live — tolerate
        try pm.initialize(keyA, FixtureGraph.SQRT_PRICE_1_1) {} catch {}
        try pm.initialize(keyB, FixtureGraph.SQRT_PRICE_1_1) {} catch {}

        // Fund seeder generously (mint to deployer is 1e12 whole units).
        uint256 fund = 100_000_000e18;
        IERC20(tt4).transfer(seeder, fund);
        IERC20(tt5).transfer(seeder, fund);
        IERC20(tt6).transfer(seeder, fund);
        IERC20(tt7).transfer(seeder, fund);

        // Moderate CL range + liquidity so seed fits within fund.
        int24 tickLower = -FixtureGraph.V4_TICK_SPACING * 100;
        int24 tickUpper = FixtureGraph.V4_TICK_SPACING * 100;
        uint128 liq = 1_000_000e18;
        seederC.addLiquidity(keyA, tickLower, tickUpper, liq);
        seederC.addLiquidity(keyB, tickLower, tickUpper, liq);

        v4SePoolAId = keccak256(abi.encode(keyA));
        v4SePoolBId = keccak256(abi.encode(keyB));
        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadTokens() internal {
        tt4 = _readAddress(TOKENS_FILE, "tt4");
        tt5 = _readAddress(TOKENS_FILE, "tt5");
        tt6 = _readAddress(TOKENS_FILE, "tt6");
        tt7 = _readAddress(TOKENS_FILE, "tt7");
        require(tt4 != address(0) && tt5 != address(0) && tt6 != address(0) && tt7 != address(0), "missing tokens");
    }

    function _loadExisting() internal view returns (bool) {
        // Use seeder address as resume key
        (address s, bool ok) = _readAddressSafe(ARTIFACT_FILE, "seeder");
        return ok && s != address(0) && s.code.length > 0;
    }

    function _buildKey(address a, address b) internal pure returns (PoolKey memory key) {
        (address token0, address token1) = a < b ? (a, b) : (b, a);
        key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: FixtureGraph.V4_POOL_FEE,
            tickSpacing: FixtureGraph.V4_TICK_SPACING,
            hooks: IHooks(address(0))
        });
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("v4pools", "poolManager", RobinhoodCanonicalLib.poolManager());
        json = vm.serializeAddress("v4pools", "seeder", seeder);
        json = vm.serializeAddress("v4pools", "tt4", tt4);
        json = vm.serializeAddress("v4pools", "tt5", tt5);
        json = vm.serializeAddress("v4pools", "tt6", tt6);
        json = vm.serializeAddress("v4pools", "tt7", tt7);
        json = vm.serializeBytes32("v4pools", "v4SePoolAId", v4SePoolAId);
        json = vm.serializeBytes32("v4pools", "v4SePoolBId", v4SePoolBId);
        json = vm.serializeUint("v4pools", "fee", FixtureGraph.V4_POOL_FEE);
        json = vm.serializeUint("v4pools", "tickSpacing", uint256(int256(FixtureGraph.V4_TICK_SPACING)));
        json = vm.serializeUint("v4pools", "chainId", block.chainid);
        json = vm.serializeString("v4pools", "notes", "v4SePoolA=TT4/TT5; v4SePoolB=TT6/TT7 on RH PoolManager");
        _writeJson(json, ARTIFACT_FILE);
    }

    function _logResults() internal view {
        _logAddress("Seeder:", seeder);
        _logComplete("Stage 06");
    }
}
