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

import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {IPool as IAerodromePool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";

/* -------------------------------------------------------------------------- */
/*                                 Balancer                                   */
/* -------------------------------------------------------------------------- */

import {InputHelpers} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/helpers/InputHelpers.sol";

/* -------------------------------------------------------------------------- */
/*                                 Permit2                                   */
/* -------------------------------------------------------------------------- */

import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";

/// @title Script_19_SeedWethTtcBaseLiquidity
/// @notice Seeds small initial liquidity into the WETH/TTC pools across UniV2, Aerodrome, and Balancer.
contract Script_19_SeedWethTtcBaseLiquidity is DeploymentBase {
    /* ---------------------------------------------------------------------- */
    /*                                 Config                                 */
    /* ---------------------------------------------------------------------- */

    uint256 internal constant MINT_TTC = 1_000_000e18;

    // Keep WETH deposits small so we still have WETH available for manual wrap/unwrap testing.
    uint256 internal constant INITIAL_WETH = 10e18;
    uint256 internal constant INITIAL_TTC = 10_000e18;

    /* ---------------------------------------------------------------------- */
    /*                                  Inputs                                */
    /* ---------------------------------------------------------------------- */

    address private ttC;

    IUniswapV2Pair private uniWethcPool;
    IAerodromePool private aeroWethcPool;
    address private balancerWethcPool;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 19: Seed WETH/TTC Base Liquidity");

        vm.startBroadcast();
        _mintAndWrap();
        _approve();
        _seedUniV2();
        _seedAerodrome();
        _seedBalancer();
        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        ttC = _readAddress("05_test_tokens.json", "testTokenC");
        require(ttC != address(0), "Test Token C not found");

        uniWethcPool = IUniswapV2Pair(_readAddress("17_weth_ttc_pools.json", "uniWethcPool"));
        aeroWethcPool = IAerodromePool(_readAddress("17_weth_ttc_pools.json", "aeroWethcPool"));
        balancerWethcPool = _readAddress("17_weth_ttc_pools.json", "balancerWethcPool");

        require(address(uniWethcPool) != address(0), "UniV2 WETH/TTC pool not found");
        require(address(aeroWethcPool) != address(0), "Aerodrome WETH/TTC pool not found");
        require(balancerWethcPool != address(0), "Balancer WETH/TTC pool not found");
    }

    function _mintAndWrap() internal {
        // Mint TTC to deployer.
        IERC20MintBurn(ttC).mint(deployer, MINT_TTC);

        // Wrap ETH into WETH. (Only wrap if we don't already have enough.)
        uint256 haveWeth = IERC20(address(weth)).balanceOf(deployer);
        if (haveWeth < 3 * INITIAL_WETH) {
            uint256 toWrap = (3 * INITIAL_WETH) - haveWeth;
            weth.deposit{value: toWrap}();
        }
    }

    function _approveMax(address token, address spender) internal {
        IERC20(token).approve(spender, 0);
        IERC20(token).approve(spender, type(uint256).max);
    }

    function _approve() internal {
        _approveMax(address(weth), address(uniswapV2Router));
        _approveMax(ttC, address(uniswapV2Router));

        _approveMax(address(weth), address(aerodromeRouter));
        _approveMax(ttC, address(aerodromeRouter));

        _approveMax(address(weth), address(balancerV3Vault));
        _approveMax(ttC, address(balancerV3Vault));

        // Permit2 for Balancer Router
        _approvePermit2(address(weth));
        _approvePermit2(ttC);
    }

    function _approvePermit2(address token) internal {
        IERC20(token).approve(address(permit2), type(uint256).max);
        permit2.approve(address(token), address(balancerV3Router), type(uint160).max, type(uint48).max);
    }

    function _seedUniV2() internal {
        (uint112 r0, uint112 r1,) = uniWethcPool.getReserves();
        if (r0 != 0 || r1 != 0) return;

        uint256 deadline = block.timestamp + 1 hours;
        uniswapV2Router.addLiquidity(address(weth), ttC, INITIAL_WETH, INITIAL_TTC, 0, 0, deployer, deadline);
    }

    function _seedAerodrome() internal {
        uint256 r0 = aeroWethcPool.reserve0();
        uint256 r1 = aeroWethcPool.reserve1();
        if (r0 != 0 || r1 != 0) return;

        uint256 deadline = block.timestamp + 1 hours;
        // volatile (stable=false)
        aerodromeRouter.addLiquidity(address(weth), ttC, false, INITIAL_WETH, INITIAL_TTC, 0, 0, deployer, deadline);
    }

    function _seedBalancerPool(address pool, address tokenX, uint256 amountX, address tokenY, uint256 amountY) internal {
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(tokenX);
        tokens[1] = IERC20(tokenY);

        // Sort tokens to match pool's internal ordering
        tokens = InputHelpers.sortTokens(tokens);

        // Map amounts to sorted token order
        uint256[] memory exactAmountsIn = new uint256[](2);
        if (tokens[0] == IERC20(tokenX)) {
            exactAmountsIn[0] = amountX;
            exactAmountsIn[1] = amountY;
        } else {
            exactAmountsIn[0] = amountY;
            exactAmountsIn[1] = amountX;
        }

        // First initialize the pool (this also adds initial liquidity)
        balancerV3Router.initialize(pool, tokens, exactAmountsIn, 0, false, bytes(""));
    }

    function _seedBalancer() internal {
        _seedBalancerPool(balancerWethcPool, address(weth), INITIAL_WETH, ttC, INITIAL_TTC);
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeUint("", "initialWeth", INITIAL_WETH);
        json = vm.serializeUint("", "initialTtc", INITIAL_TTC);
        _writeJson(json, "19_weth_ttc_base_liquidity.json");
    }

    function _logResults() internal view {
        _logAddress("UniV2 WETH/TTC Pool:", address(uniWethcPool));
        _logAddress("Aerodrome WETH/TTC Pool:", address(aeroWethcPool));
        _logAddress("Balancer WETH/TTC Pool:", balancerWethcPool);
        _logComplete("Stage 19");
    }
}
