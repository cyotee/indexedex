// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_AerodromeStandardExchange
} from "contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_AerodromeStandardExchange.sol";

/**
 * @title TestBase_AerodromeStandardExchange_MultiPool
 * @notice Test base that deploys 3 vault instances with different pool configurations.
 * @dev Provides balanced (1:1), unbalanced (10:1), and extreme (100:1) pool configurations
 *      for comprehensive testing across different liquidity scenarios.
 */
contract TestBase_AerodromeStandardExchange_MultiPool is TestBase_AerodromeStandardExchange {
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

    /// @notice Vault backed by balanced pool (1:1 ratio)
    IStandardExchangeProxy balancedVault;

    /// @notice Vault backed by unbalanced pool (10:1 ratio)
    IStandardExchangeProxy unbalancedVault;

    /// @notice Vault backed by extreme unbalanced pool (100:1 ratio)
    IStandardExchangeProxy extremeVault;

    /* ---------------------------------------------------------------------- */
    /*                                 Setup                                  */
    /* ---------------------------------------------------------------------- */

    function setUp() public virtual override {
        TestBase_AerodromeStandardExchange.setUp();

        // Initialize pools with liquidity BEFORE deploying vaults
        _initializeAerodromeBalancedPools();
        _initializeAerodromeUnbalancedPools();
        _initializeAerodromeExtremeUnbalancedPools();

        // Deploy vaults through DFPkg.deployVault(pool) and cast to proxy interface
        balancedVault = IStandardExchangeProxy(aerodromeStandardExchangeDFPkg.deployVault(aeroBalancedPool));
        unbalancedVault = IStandardExchangeProxy(aerodromeStandardExchangeDFPkg.deployVault(aeroUnbalancedPool));
        extremeVault = IStandardExchangeProxy(aerodromeStandardExchangeDFPkg.deployVault(aeroExtremeUnbalancedPool));

        // Label for debugging
        vm.label(address(balancedVault), "BalancedVault");
        vm.label(address(unbalancedVault), "UnbalancedVault");
        vm.label(address(extremeVault), "ExtremeVault");
    }

    /* ---------------------------------------------------------------------- */
    /*                           Vault Accessors                              */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Get vault for a pool configuration.
     * @param config The pool configuration
     * @return The vault proxy interface
     */
    function _getVault(PoolConfig config) internal view returns (IStandardExchangeProxy) {
        if (config == PoolConfig.Balanced) return balancedVault;
        if (config == PoolConfig.Unbalanced) return unbalancedVault;
        return extremeVault;
    }

    /**
     * @notice Get pool for a configuration.
     * @param config The pool configuration
     * @return The Aerodrome pool
     */
    function _getPool(PoolConfig config) internal view returns (IPool) {
        if (config == PoolConfig.Balanced) return aeroBalancedPool;
        if (config == PoolConfig.Unbalanced) return aeroUnbalancedPool;
        return aeroExtremeUnbalancedPool;
    }

    /**
     * @notice Get tokens for a configuration.
     * @param config The pool configuration
     * @return tokenA The first token
     * @return tokenB The second token
     */
    function _getTokens(PoolConfig config)
        internal
        view
        returns (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB)
    {
        if (config == PoolConfig.Balanced) {
            return (aeroBalancedTokenA, aeroBalancedTokenB);
        }
        if (config == PoolConfig.Unbalanced) {
            return (aeroUnbalancedTokenA, aeroUnbalancedTokenB);
        }
        return (aeroExtremeTokenA, aeroExtremeTokenB);
    }

    /* ---------------------------------------------------------------------- */
    /*                          Test Token Helpers                            */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Mint tokens to a recipient and approve the vault.
     * @param config The pool configuration
     * @param recipient The address to mint to
     * @param amountA Amount of token A to mint
     * @param amountB Amount of token B to mint
     */
    function _mintAndApprove(PoolConfig config, address recipient, uint256 amountA, uint256 amountB) internal {
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(config);
        IStandardExchangeProxy vault = _getVault(config);

        if (amountA > 0) {
            tokenA.mint(recipient, amountA);
            vm.prank(recipient);
            tokenA.approve(address(vault), amountA);
        }
        if (amountB > 0) {
            tokenB.mint(recipient, amountB);
            vm.prank(recipient);
            tokenB.approve(address(vault), amountB);
        }
    }

    /**
     * @notice Mint LP tokens to a recipient and approve the vault.
     * @param config The pool configuration
     * @param recipient The address to mint to
     * @param amount Amount of LP tokens to transfer
     */
    function _mintLPAndApprove(PoolConfig config, address recipient, uint256 amount) internal {
        IPool pool = _getPool(config);
        IStandardExchangeProxy vault = _getVault(config);

        // Transfer LP from test contract (which has LP from initialization)
        IERC20(address(pool)).transfer(recipient, amount);
        vm.prank(recipient);
        IERC20(address(pool)).approve(address(vault), amount);
    }

    /**
     * @notice Get vault shares for a user and approve for burning.
     * @param config The pool configuration
     * @param user The user address
     * @param amount Amount to approve
     */
    function _approveVaultShares(PoolConfig config, address user, uint256 amount) internal {
        IStandardExchangeProxy vault = _getVault(config);
        vm.prank(user);
        vault.approve(address(vault), amount);
    }

    /* ---------------------------------------------------------------------- */
    /*                           Reserve Helpers                              */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Get pool reserves sorted by token address.
     * @param config The pool configuration
     * @return reserveA Reserve of token A
     * @return reserveB Reserve of token B
     */
    function _getReserves(PoolConfig config) internal view returns (uint256 reserveA, uint256 reserveB) {
        IPool pool = _getPool(config);
        (uint256 reserve0, uint256 reserve1,) = pool.getReserves();

        (ERC20PermitMintableStub tokenA,) = _getTokens(config);
        address token0 = pool.token0();

        if (address(tokenA) == token0) {
            return (reserve0, reserve1);
        }
        return (reserve1, reserve0);
    }

    /**
     * @notice Get LP token total supply.
     * @param config The pool configuration
     * @return Total LP token supply
     */
    function _getLPTotalSupply(PoolConfig config) internal view returns (uint256) {
        return IERC20(address(_getPool(config))).totalSupply();
    }

    /**
     * @notice Get LP token balance of an address.
     * @param config The pool configuration
     * @param account The address to check
     * @return LP token balance
     */
    function _getLPBalance(PoolConfig config, address account) internal view returns (uint256) {
        return IERC20(address(_getPool(config))).balanceOf(account);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Fee Generation Helper                          */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Execute trades to generate fees in the pool.
     * @param config The pool configuration
     */
    function _generatePoolFees(PoolConfig config) internal {
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(config);
        _executeAerodromeTradesToGenerateFees(tokenA, tokenB);
    }

    /* ---------------------------------------------------------------------- */
    /*                           Deadline Helper                              */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Get a valid deadline for transactions.
     * @return deadline Current block timestamp + 1 hour
     */
    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    /**
     * @notice Get an expired deadline for testing reverts.
     * @return deadline Current block timestamp - 1
     */
    function _expiredDeadline() internal view returns (uint256) {
        return block.timestamp - 1;
    }
}
