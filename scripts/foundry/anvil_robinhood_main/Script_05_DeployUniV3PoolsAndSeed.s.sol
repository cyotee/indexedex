// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {FixtureGraph} from "./FixtureGraph.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {
    INonfungiblePositionManager
} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/interfaces/INonfungiblePositionManager.sol";

/// @title Script_05_DeployUniV3PoolsAndSeed
/// @notice Create + seed Uni V3 pools on RH factory for TT graph.
contract Script_05_DeployUniV3PoolsAndSeed is DeploymentBase {
    string internal constant TOKENS_FILE = "04_test_tokens.json";
    string internal constant ARTIFACT_FILE = "05_univ3_pools.json";

    uint256 internal constant SEED_AMOUNT = 1_000_000e18;

    address[8] private tokens;
    address private v3SePoolA;
    address private v3SePoolB;
    uint256 private poolCount;

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        RobinhoodCanonicalLib.requireCanonicalPins();
        _loadTokens();
        _logHeader("Stage 05: Uni V3 pools + seed (RH factory)");

        if (_loadExisting()) {
            _exportJson();
            _logResults();
            return;
        }

        IUniswapV3Factory factory = IUniswapV3Factory(RobinhoodCanonicalLib.v3Factory());
        int24 spacing = factory.feeAmountTickSpacing(FixtureGraph.V3_FEE);
        require(spacing != 0, "V3 fee 3000 not enabled on RH factory");

        vm.startBroadcast();
        _createAndSeedAll(factory, spacing);
        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadTokens() internal {
        tokens[0] = _readAddress(TOKENS_FILE, "tt0");
        tokens[1] = _readAddress(TOKENS_FILE, "tt1");
        tokens[2] = _readAddress(TOKENS_FILE, "tt2");
        tokens[3] = _readAddress(TOKENS_FILE, "tt3");
        tokens[4] = _readAddress(TOKENS_FILE, "tt4");
        tokens[5] = _readAddress(TOKENS_FILE, "tt5");
        tokens[6] = _readAddress(TOKENS_FILE, "tt6");
        tokens[7] = _readAddress(TOKENS_FILE, "tt7");
        for (uint8 i; i < 8; ++i) {
            require(tokens[i] != address(0), "missing token");
        }
    }

    function _loadExisting() internal returns (bool) {
        (address a, bool okA) = _readAddressSafe(ARTIFACT_FILE, "v3SePoolA");
        (address b, bool okB) = _readAddressSafe(ARTIFACT_FILE, "v3SePoolB");
        if (!okA || !okB || a.code.length == 0 || b.code.length == 0) return false;
        v3SePoolA = a;
        v3SePoolB = b;
        return true;
    }

    function _createAndSeedAll(IUniswapV3Factory factory, int24 spacing) internal {
        INonfungiblePositionManager npm = INonfungiblePositionManager(RobinhoodCanonicalLib.v3Npm());

        // Approve all tokens to NPM once
        for (uint8 i; i < 8; ++i) {
            IERC20(tokens[i]).approve(address(npm), type(uint256).max);
        }

        (uint8[] memory left, uint8[] memory right) = FixtureGraph.v3PoolEdges();
        poolCount = left.length;

        for (uint256 i; i < left.length; ++i) {
            address pool = _createInitSeed(factory, npm, tokens[left[i]], tokens[right[i]], spacing);
            // Named SE underlyings
            if (left[i] == 0 && right[i] == 1) {
                v3SePoolA = pool;
                vm.label(pool, "v3SePoolA_TT0_TT1");
            }
            if (left[i] == 2 && right[i] == 3) {
                v3SePoolB = pool;
                vm.label(pool, "v3SePoolB_TT2_TT3");
            }
        }

        // Ensure named pools exist even if edge list changes
        if (v3SePoolA == address(0)) {
            v3SePoolA = _createInitSeed(factory, npm, tokens[0], tokens[1], spacing);
        }
        if (v3SePoolB == address(0)) {
            v3SePoolB = _createInitSeed(factory, npm, tokens[2], tokens[3], spacing);
        }
    }

    function _createInitSeed(
        IUniswapV3Factory factory,
        INonfungiblePositionManager npm,
        address tokenA,
        address tokenB,
        int24 spacing
    ) internal returns (address pool) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        pool = factory.getPool(token0, token1, FixtureGraph.V3_FEE);
        if (pool == address(0)) {
            pool = factory.createPool(token0, token1, FixtureGraph.V3_FEE);
        }
        // Initialize at 1:1 when not yet live (reverts if already initialized).
        try IUniswapV3Pool(pool).initialize(FixtureGraph.SQRT_PRICE_1_1) {} catch {}

        int24 tickLower = (-887220 / spacing) * spacing;
        int24 tickUpper = (887220 / spacing) * spacing;
        if (tickLower >= tickUpper) {
            tickLower = -spacing * 1000;
            tickUpper = spacing * 1000;
        }

        npm.mint(
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: FixtureGraph.V3_FEE,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: SEED_AMOUNT,
                amount1Desired: SEED_AMOUNT,
                amount0Min: 0,
                amount1Min: 0,
                recipient: deployer,
                deadline: block.timestamp + 1 hours
            })
        );
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("v3pools", "v3SePoolA", v3SePoolA);
        json = vm.serializeAddress("v3pools", "v3SePoolB", v3SePoolB);
        json = vm.serializeAddress("v3pools", "v3Factory", RobinhoodCanonicalLib.v3Factory());
        json = vm.serializeAddress("v3pools", "v3Npm", RobinhoodCanonicalLib.v3Npm());
        json = vm.serializeUint("v3pools", "fee", FixtureGraph.V3_FEE);
        json = vm.serializeUint("v3pools", "poolCount", poolCount);
        json = vm.serializeUint("v3pools", "chainId", block.chainid);
        _writeJson(json, ARTIFACT_FILE);
    }

    function _logResults() internal view {
        _logAddress("v3SePoolA:", v3SePoolA);
        _logAddress("v3SePoolB:", v3SePoolB);
        _logComplete("Stage 05");
    }
}
