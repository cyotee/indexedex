// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {
    TestBase_UniswapV2_Pools
} from "@crane/contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2_Pools.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_UniswapV2StandardExchange
} from "contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange.sol";

/**
 * @title TestBase_UniswapV2StandardExchange_MultiPool
 * @notice Test base that deploys 3 vault instances with different pool configurations.
 */
contract TestBase_UniswapV2StandardExchange_MultiPool is TestBase_UniswapV2_Pools, TestBase_UniswapV2StandardExchange {
    /* ---------------------------------------------------------------------- */
    /*                               Constants                                */
    /* ---------------------------------------------------------------------- */

    /// @notice Minimum amount to avoid dust issues
    uint256 constant MIN_TEST_AMOUNT = 1e12;

    /* ---------------------------------------------------------------------- */
    /*                            Pool Configuration                          */
    /* ---------------------------------------------------------------------- */

    enum PoolConfig {
        Balanced,
        Unbalanced,
        Extreme
    }

    /* ---------------------------------------------------------------------- */
    /*                             Vault Instances                            */
    /* ---------------------------------------------------------------------- */

    IStandardExchangeProxy balancedVault;
    IStandardExchangeProxy unbalancedVault;
    IStandardExchangeProxy extremeVault;

    /* ---------------------------------------------------------------------- */
    /*                                 Setup                                  */
    /* ---------------------------------------------------------------------- */

    function setUp() public virtual override(TestBase_UniswapV2_Pools, TestBase_UniswapV2StandardExchange) {
        TestBase_UniswapV2_Pools.setUp();
        TestBase_UniswapV2StandardExchange.setUp();

        // Create + seed pools with liquidity before deploying vaults.
        _initializeUniswapBalancedPools();
        _initializeUniswapUnbalancedPools();
        _initializeUniswapExtremeUnbalancedPools();

        balancedVault = IStandardExchangeProxy(uniswapV2StandardExchangeDFPkg.deployVault(uniswapBalancedPair));
        unbalancedVault = IStandardExchangeProxy(uniswapV2StandardExchangeDFPkg.deployVault(uniswapUnbalancedPair));
        extremeVault = IStandardExchangeProxy(uniswapV2StandardExchangeDFPkg.deployVault(uniswapExtremeUnbalancedPair));

        vm.label(address(balancedVault), "UniswapBalancedVault");
        vm.label(address(unbalancedVault), "UniswapUnbalancedVault");
        vm.label(address(extremeVault), "UniswapExtremeVault");
    }

    /* ---------------------------------------------------------------------- */
    /*                           Vault Accessors                              */
    /* ---------------------------------------------------------------------- */

    function _getVault(PoolConfig config) internal view returns (IStandardExchangeProxy) {
        if (config == PoolConfig.Balanced) return balancedVault;
        if (config == PoolConfig.Unbalanced) return unbalancedVault;
        return extremeVault;
    }

    function _getPool(PoolConfig config) internal view returns (IUniswapV2Pair) {
        if (config == PoolConfig.Balanced) return uniswapBalancedPair;
        if (config == PoolConfig.Unbalanced) return uniswapUnbalancedPair;
        return uniswapExtremeUnbalancedPair;
    }

    /* ---------------------------------------------------------------------- */
    /*                           Deadline Helper                              */
    /* ---------------------------------------------------------------------- */

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }
}
