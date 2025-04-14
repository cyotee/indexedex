// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";

/* -------------------------------------------------------------------------- */
/*                                OpenZeppelin                                */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                   Crane                                    */
/* -------------------------------------------------------------------------- */

import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {IPool as IAerodromePool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {TokenConfig, TokenType} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IBalancerV3ConstantProductPoolStandardVaultPkg} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPoolStandardVaultPkg.sol";

/// @title Script_17_DeployWethTtcPools
/// @notice Deploys WETH/TTC pools across UniV2, Aerodrome (volatile), and Balancer V3 ConstProd.
contract Script_17_DeployWethTtcPools is DeploymentBase {
    /* ---------------------------------------------------------------------- */
    /*                                  Inputs                                */
    /* ---------------------------------------------------------------------- */

    IBalancerV3ConstantProductPoolStandardVaultPkg private balConstProdPkg;

    address private ttC;

    /* ---------------------------------------------------------------------- */
    /*                                 Outputs                                */
    /* ---------------------------------------------------------------------- */

    IUniswapV2Pair private uniWethcPool;
    IAerodromePool private aeroWethcPool;
    address private balancerWethcPool;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 17: Deploy WETH/TTC Pools");

        vm.startBroadcast();
        _deployPools();
        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        balConstProdPkg = IBalancerV3ConstantProductPoolStandardVaultPkg(
            _readAddress("04_dex_packages.json", "balancerV3ConstantProductPoolStandardVaultPkg")
        );
        require(address(balConstProdPkg) != address(0), "Balancer const-prod pkg not found");

        ttC = _readAddress("05_test_tokens.json", "testTokenC");
        require(ttC != address(0), "Test Token C not found");
    }

    function _standardTokenConfig(address token) internal pure returns (TokenConfig memory cfg) {
        cfg = TokenConfig({
            token: IERC20(token),
            tokenType: TokenType.STANDARD,
            rateProvider: IRateProvider(address(0)),
            paysYieldFees: false
        });
    }

    function _deployPools() internal {
        // UniV2 WETH/TTC
        address pair = uniswapV2Factory.getPair(address(weth), ttC);
        if (pair == address(0)) {
            pair = uniswapV2Factory.createPair(address(weth), ttC);
        }
        uniWethcPool = IUniswapV2Pair(pair);

        // Aerodrome volatile WETH/TTC (stable=false)
        address aeroPool = aerodromePoolFactory.getPool(address(weth), ttC, false);
        if (aeroPool == address(0)) {
            aeroPool = aerodromePoolFactory.createPool(address(weth), ttC, false);
        }
        aeroWethcPool = IAerodromePool(aeroPool);

        // Balancer V3 ConstProd WETH/TTC
        TokenConfig[] memory cfg = new TokenConfig[](2);
        cfg[0] = _standardTokenConfig(address(weth));
        cfg[1] = _standardTokenConfig(ttC);
        balancerWethcPool = balConstProdPkg.deployVault(cfg, address(0));

        vm.label(address(uniWethcPool), "UniV2 WETH/TTC");
        vm.label(address(aeroWethcPool), "Aerodrome WETH/TTC");
        vm.label(balancerWethcPool, "Balancer V3 WETH/TTC ConstProd");
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("", "uniWethcPool", address(uniWethcPool));
        json = vm.serializeAddress("", "aeroWethcPool", address(aeroWethcPool));
        json = vm.serializeAddress("", "balancerWethcPool", balancerWethcPool);
        _writeJson(json, "17_weth_ttc_pools.json");
    }

    function _logResults() internal view {
        _logAddress("UniV2 WETH/TTC Pool:", address(uniWethcPool));
        _logAddress("Aerodrome WETH/TTC Pool:", address(aeroWethcPool));
        _logAddress("Balancer WETH/TTC ConstProd Pool:", balancerWethcPool);
        _logComplete("Stage 17");
    }
}
