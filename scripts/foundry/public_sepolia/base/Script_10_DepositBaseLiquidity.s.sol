// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {console2} from "forge-std/console2.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {IPool as IAerodromePool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {InputHelpers} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/helpers/InputHelpers.sol";

import {BridgeTokenPlanning} from "../shared/BridgeTokenPlanning.sol";

contract Script_10_DepositBaseLiquidity is DeploymentBase {
    uint256 internal constant INITIAL_LIQUIDITY = 10_000e18;
    uint256 internal constant UNBALANCED_RATIO_B = 1_000e18;
    uint256 internal constant UNBALANCED_RATIO_C = 100e18;

    address private ttA;
    address private ttB;
    address private ttC;

    IUniswapV2Pair private abPool;
    IUniswapV2Pair private acPool;
    IUniswapV2Pair private bcPool;

    IAerodromePool private aeroAbPool;
    IAerodromePool private aeroAcPool;
    IAerodromePool private aeroBcPool;

    address private balAbPool;
    address private balAcPool;
    address private balBcPool;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 10: Deposit Base Liquidity");
        console2.log("[Stage 10] deployer", deployer);

        vm.startBroadcast();
        _assertBridgedBalances();
        console2.log("[Stage 10] approvals");
        _approveRoutersAndVault();
        console2.log("[Stage 10] seeding UniV2");
        _seedUniV2();
        console2.log("[Stage 10] seeding Aerodrome");
        _seedAerodrome();
        console2.log("[Stage 10] seeding Balancer");
        _seedBalancer();
        console2.log("[Stage 10] broadcast stop");
        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        ttA = _readAddress("05_test_tokens.json", "testTokenA");
        ttB = _readAddress("05_test_tokens.json", "testTokenB");
        ttC = _readAddress("05_test_tokens.json", "testTokenC");

        abPool = IUniswapV2Pair(_readAddress("06_pools.json", "abPool"));
        acPool = IUniswapV2Pair(_readAddress("06_pools.json", "acPool"));
        bcPool = IUniswapV2Pair(_readAddress("06_pools.json", "bcPool"));

        aeroAbPool = IAerodromePool(_readAddress("06_pools.json", "aeroAbPool"));
        aeroAcPool = IAerodromePool(_readAddress("06_pools.json", "aeroAcPool"));
        aeroBcPool = IAerodromePool(_readAddress("06_pools.json", "aeroBcPool"));

        address tmp;
        bool ok;
        (tmp, ok) = _readAddressSafe("09_balancer_const_prod_pools.json", "balancerAbPool");
        if (ok) balAbPool = tmp;
        (tmp, ok) = _readAddressSafe("09_balancer_const_prod_pools.json", "balancerAcPool");
        if (ok) balAcPool = tmp;
        (tmp, ok) = _readAddressSafe("09_balancer_const_prod_pools.json", "balancerBcPool");
        if (ok) balBcPool = tmp;

        require(ttA != address(0) && ttB != address(0) && ttC != address(0), "Test tokens missing");
        require(address(abPool) != address(0) && address(acPool) != address(0) && address(bcPool) != address(0), "UniV2 pools missing");
        require(
            address(aeroAbPool) != address(0) && address(aeroAcPool) != address(0) && address(aeroBcPool) != address(0),
            "Aerodrome pools missing"
        );
        require(balAbPool != address(0) && balAcPool != address(0) && balBcPool != address(0), "Balancer pools missing (run Stage 9)");
    }

    function _assertBridgedBalances() internal view {
        require(IERC20(ttA).balanceOf(deployer) >= BridgeTokenPlanning.bridgeAmountTTA(), "Insufficient bridged TTA");
        require(IERC20(ttB).balanceOf(deployer) >= BridgeTokenPlanning.bridgeAmountTTB(), "Insufficient bridged TTB");
        require(IERC20(ttC).balanceOf(deployer) >= BridgeTokenPlanning.bridgeAmountTTC(), "Insufficient bridged TTC");
    }

    function _approveMax(address token, address spender) internal {
        IERC20(token).approve(spender, 0);
        IERC20(token).approve(spender, type(uint256).max);
    }

    function _approveRoutersAndVault() internal {
        _approveMax(ttA, address(uniswapV2Router));
        _approveMax(ttB, address(uniswapV2Router));
        _approveMax(ttC, address(uniswapV2Router));

        _approveMax(ttA, address(aerodromeRouter));
        _approveMax(ttB, address(aerodromeRouter));
        _approveMax(ttC, address(aerodromeRouter));

        _approveMax(ttA, address(balancerV3Vault));
        _approveMax(ttB, address(balancerV3Vault));
        _approveMax(ttC, address(balancerV3Vault));

        _approvePermit2(ttA);
        _approvePermit2(ttB);
        _approvePermit2(ttC);
    }

    function _approvePermit2(address token) internal {
        IERC20(token).approve(address(permit2), type(uint256).max);
        permit2.approve(address(token), address(balancerV3Router), type(uint160).max, type(uint48).max);
    }

    function _seedUniV2() internal {
        uint256 deadline = block.timestamp + 1 hours;

        {
            (uint112 r0, uint112 r1,) = abPool.getReserves();
            if (r0 == 0 && r1 == 0) {
                uniswapV2Router.addLiquidity(ttA, ttB, INITIAL_LIQUIDITY, INITIAL_LIQUIDITY, 0, 0, deployer, deadline);
            }
        }
        {
            (uint112 r0, uint112 r1,) = acPool.getReserves();
            if (r0 == 0 && r1 == 0) {
                uniswapV2Router.addLiquidity(ttA, ttC, INITIAL_LIQUIDITY, UNBALANCED_RATIO_B, 0, 0, deployer, deadline);
            }
        }
        {
            (uint112 r0, uint112 r1,) = bcPool.getReserves();
            if (r0 == 0 && r1 == 0) {
                uniswapV2Router.addLiquidity(ttB, ttC, INITIAL_LIQUIDITY, UNBALANCED_RATIO_C, 0, 0, deployer, deadline);
            }
        }
    }

    function _seedAerodrome() internal {
        uint256 deadline = block.timestamp + 1 hours;

        {
            uint256 r0 = aeroAbPool.reserve0();
            uint256 r1 = aeroAbPool.reserve1();
            if (r0 == 0 && r1 == 0) {
                aerodromeRouter.addLiquidity(ttA, ttB, false, INITIAL_LIQUIDITY, INITIAL_LIQUIDITY, 0, 0, deployer, deadline);
            }
        }
        {
            uint256 r0 = aeroAcPool.reserve0();
            uint256 r1 = aeroAcPool.reserve1();
            if (r0 == 0 && r1 == 0) {
                aerodromeRouter.addLiquidity(ttA, ttC, false, INITIAL_LIQUIDITY, UNBALANCED_RATIO_B, 0, 0, deployer, deadline);
            }
        }
        {
            uint256 r0 = aeroBcPool.reserve0();
            uint256 r1 = aeroBcPool.reserve1();
            if (r0 == 0 && r1 == 0) {
                aerodromeRouter.addLiquidity(ttB, ttC, false, INITIAL_LIQUIDITY, UNBALANCED_RATIO_C, 0, 0, deployer, deadline);
            }
        }
    }

    function _seedBalancerPool(address pool, address tokenX, uint256 amountX, address tokenY, uint256 amountY) internal {
        console2.log("[Stage 10] initialize pool", pool);
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(tokenX);
        tokens[1] = IERC20(tokenY);
        tokens = InputHelpers.sortTokens(tokens);

        uint256[] memory exactAmountsIn = new uint256[](2);
        if (tokens[0] == IERC20(tokenX)) {
            exactAmountsIn[0] = amountX;
            exactAmountsIn[1] = amountY;
        } else {
            exactAmountsIn[0] = amountY;
            exactAmountsIn[1] = amountX;
        }

        balancerV3Router.initialize(pool, tokens, exactAmountsIn, 0, false, bytes(""));
    }

    function _seedBalancer() internal {
        _seedBalancerPool(balAbPool, ttA, INITIAL_LIQUIDITY, ttB, INITIAL_LIQUIDITY);
        _seedBalancerPool(balAcPool, ttA, INITIAL_LIQUIDITY, ttC, UNBALANCED_RATIO_B);
        _seedBalancerPool(balBcPool, ttB, INITIAL_LIQUIDITY, ttC, UNBALANCED_RATIO_C);
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeUint("", "initialLiquidity", INITIAL_LIQUIDITY);
        json = vm.serializeUint("", "unbalancedRatioB", UNBALANCED_RATIO_B);
        json = vm.serializeUint("", "unbalancedRatioC", UNBALANCED_RATIO_C);
        _writeJson(json, "10_base_liquidity.json");
    }

    function _logResults() internal view {
        _logAddress("UniV2 AB:", address(abPool));
        _logAddress("UniV2 AC:", address(acPool));
        _logAddress("UniV2 BC:", address(bcPool));
        _logAddress("Aerodrome AB:", address(aeroAbPool));
        _logAddress("Aerodrome AC:", address(aeroAcPool));
        _logAddress("Aerodrome BC:", address(aeroBcPool));
        _logAddress("Balancer AB:", balAbPool);
        _logAddress("Balancer AC:", balAcPool);
        _logAddress("Balancer BC:", balBcPool);
        _logComplete("Stage 10");
    }
}