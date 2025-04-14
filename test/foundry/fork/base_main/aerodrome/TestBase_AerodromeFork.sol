// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {BASE_MAIN} from '@crane/contracts/constants/networks/BASE_MAIN.sol';
import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {IFacet} from '@crane/contracts/interfaces/IFacet.sol';
import {ICreate3FactoryProxy} from '@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol';
import {IPoolFactory} from '@crane/contracts/interfaces/protocols/dexes/aerodrome/IPoolFactory.sol';
import {IPool} from '@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol';
import {IRouter} from '@crane/contracts/interfaces/protocols/dexes/aerodrome/IRouter.sol';
import {ERC20PermitMintableStub} from '@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol';
import {TestBase_Permit2} from '@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol';
import {TestBase_SharedConstants} from '@crane/contracts/test/bases/TestBase_SharedConstants.sol';

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {TestBase_BaseFork} from 'test/foundry/fork/base_main/TestBase_BaseFork.sol';
import {IndexedexTest} from 'contracts/test/IndexedexTest.sol';
import {TestBase_VaultComponents} from 'contracts/vaults/TestBase_VaultComponents.sol';
import {IStandardExchangeProxy} from 'contracts/interfaces/proxies/IStandardExchangeProxy.sol';
import {IIndexedexManagerProxy} from 'contracts/interfaces/proxies/IIndexedexManagerProxy.sol';
import {
    IAerodromeStandardExchangeDFPkg
} from 'contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol';
import {
    Aerodrome_Component_FactoryService
} from 'contracts/protocols/dexes/aerodrome/v1/Aerodrome_Component_FactoryService.sol';

/**
 * @title TestBase_AerodromeFork
 * @notice Base test contract for Aerodrome fork tests on Base mainnet.
 * @dev Uses live Aerodrome Router and Pool Factory from Base mainnet,
 *      but creates local test tokens and pools for isolated testing.
 *
 *      Key differences from spec tests:
 *      - Uses BASE_MAIN.AERODROME_ROUTER (live mainnet router)
 *      - Uses BASE_MAIN.AERODROME_POOL_FACTORY (live mainnet factory)
 *      - Creates new pools with mock tokens on the live factory
 *      - Validates that IndexedEx vaults work with real Aerodrome infrastructure
 */
contract TestBase_AerodromeFork is TestBase_BaseFork, TestBase_Permit2, TestBase_VaultComponents, TestBase_SharedConstants {
    using Aerodrome_Component_FactoryService for ICreate3FactoryProxy;
    using Aerodrome_Component_FactoryService for IIndexedexManagerProxy;

    /* ---------------------------------------------------------------------- */
    /*                              Constants                                 */
    /* ---------------------------------------------------------------------- */

    uint256 internal constant INITIAL_LIQUIDITY = 10_000e18;
    uint256 internal constant MIN_TEST_AMOUNT = 1e12;

    // Unbalanced pool ratios
    uint256 internal constant UNBALANCED_RATIO_A = 10_000e18;
    uint256 internal constant UNBALANCED_RATIO_B = 1_000e18;
    uint256 internal constant EXTREME_RATIO_B = 100e18;

    /* ---------------------------------------------------------------------- */
    /*                         Mainnet Contracts                              */
    /* ---------------------------------------------------------------------- */

    /// @notice Live Aerodrome Router from Base mainnet
    IRouter internal aerodromeRouter;

    /// @notice Live Aerodrome Pool Factory from Base mainnet
    IPoolFactory internal aerodromePoolFactory;

    /* ---------------------------------------------------------------------- */
    /*                            Test Tokens                                 */
    /* ---------------------------------------------------------------------- */

    // Balanced pool tokens
    ERC20PermitMintableStub internal aeroBalancedTokenA;
    ERC20PermitMintableStub internal aeroBalancedTokenB;

    // Unbalanced pool tokens
    ERC20PermitMintableStub internal aeroUnbalancedTokenA;
    ERC20PermitMintableStub internal aeroUnbalancedTokenB;

    // Extreme unbalanced pool tokens
    ERC20PermitMintableStub internal aeroExtremeTokenA;
    ERC20PermitMintableStub internal aeroExtremeTokenB;

    /* ---------------------------------------------------------------------- */
    /*                              Pools                                     */
    /* ---------------------------------------------------------------------- */

    IPool internal aeroBalancedPool;
    IPool internal aeroUnbalancedPool;
    IPool internal aeroExtremeUnbalancedPool;

    /* ---------------------------------------------------------------------- */
    /*                          Vault Components                              */
    /* ---------------------------------------------------------------------- */

    IFacet internal aerodromeStandardExchangeInFacet;
    IFacet internal aerodromeStandardExchangeOutFacet;
    IAerodromeStandardExchangeDFPkg internal aerodromeStandardExchangeDFPkg;

    /* ---------------------------------------------------------------------- */
    /*                           Vault Instances                              */
    /* ---------------------------------------------------------------------- */

    IStandardExchangeProxy internal balancedVault;
    IStandardExchangeProxy internal unbalancedVault;
    IStandardExchangeProxy internal extremeVault;

    /* ---------------------------------------------------------------------- */
    /*                            Pool Config                                 */
    /* ---------------------------------------------------------------------- */

    enum PoolConfig {
        Balanced,
        Unbalanced,
        Extreme
    }

    /* ---------------------------------------------------------------------- */
    /*                                Setup                                   */
    /* ---------------------------------------------------------------------- */

    function setUp() public virtual override(TestBase_BaseFork, TestBase_Permit2, TestBase_VaultComponents) {
        // Initialize Base fork first
        TestBase_BaseFork.setUp();

        // Initialize Permit2
        TestBase_Permit2.setUp();

        // Initialize IndexedEx infrastructure (factories, fee collector, manager)
        TestBase_VaultComponents.setUp();

        // Bind to mainnet Aerodrome contracts
        _bindMainnetContracts();

        // Create test tokens
        _createTestTokens();

        // Initialize shared constants (deploy local WETH if not already set)
        setUpSharedConstants();

        // Create pools on mainnet factory
        _createPools();

        // Initialize pools with liquidity
        _initializePoolLiquidity();

        // Deploy vault infrastructure
        _deployVaultInfrastructure();

        // Deploy vault instances
        _deployVaults();
    }

    /* ---------------------------------------------------------------------- */
    /*                      Mainnet Contract Binding                          */
    /* ---------------------------------------------------------------------- */

    function _bindMainnetContracts() internal virtual {
        aerodromeRouter = IRouter(BASE_MAIN.AERODROME_ROUTER);
        aerodromePoolFactory = IPoolFactory(BASE_MAIN.AERODROME_POOL_FACTORY);

        // Verify they exist
        _assertHasCode(address(aerodromeRouter), 'Aerodrome Router');
        _assertHasCode(address(aerodromePoolFactory), 'Aerodrome Pool Factory');
    }

    /* ---------------------------------------------------------------------- */
    /*                         Test Token Creation                            */
    /* ---------------------------------------------------------------------- */

    function _createTestTokens() internal virtual {
        // Balanced pool tokens
        aeroBalancedTokenA = new ERC20PermitMintableStub('Fork Balanced Token A', 'FBAL_A', 18, address(this), 0);
        vm.label(address(aeroBalancedTokenA), 'ForkBalancedTokenA');

        aeroBalancedTokenB = new ERC20PermitMintableStub('Fork Balanced Token B', 'FBAL_B', 18, address(this), 0);
        vm.label(address(aeroBalancedTokenB), 'ForkBalancedTokenB');

        // Unbalanced pool tokens
        aeroUnbalancedTokenA = new ERC20PermitMintableStub('Fork Unbalanced Token A', 'FUNB_A', 18, address(this), 0);
        vm.label(address(aeroUnbalancedTokenA), 'ForkUnbalancedTokenA');

        aeroUnbalancedTokenB = new ERC20PermitMintableStub('Fork Unbalanced Token B', 'FUNB_B', 18, address(this), 0);
        vm.label(address(aeroUnbalancedTokenB), 'ForkUnbalancedTokenB');

        // Extreme unbalanced pool tokens
        aeroExtremeTokenA = new ERC20PermitMintableStub('Fork Extreme Token A', 'FEXT_A', 18, address(this), 0);
        vm.label(address(aeroExtremeTokenA), 'ForkExtremeTokenA');

        aeroExtremeTokenB = new ERC20PermitMintableStub('Fork Extreme Token B', 'FEXT_B', 18, address(this), 0);
        vm.label(address(aeroExtremeTokenB), 'ForkExtremeTokenB');
    }

    /* ---------------------------------------------------------------------- */
    /*                           Pool Creation                                */
    /* ---------------------------------------------------------------------- */

    function _createPools() internal virtual {
        // Create balanced pool on mainnet factory
        address balancedPoolAddr = aerodromePoolFactory.createPool(
            address(aeroBalancedTokenA),
            address(aeroBalancedTokenB),
            false // volatile pool
        );
        aeroBalancedPool = IPool(balancedPoolAddr);
        vm.label(balancedPoolAddr, 'ForkBalancedPool');

        // Create unbalanced pool
        address unbalancedPoolAddr =
            aerodromePoolFactory.createPool(address(aeroUnbalancedTokenA), address(aeroUnbalancedTokenB), false);
        aeroUnbalancedPool = IPool(unbalancedPoolAddr);
        vm.label(unbalancedPoolAddr, 'ForkUnbalancedPool');

        // Create extreme unbalanced pool
        address extremePoolAddr =
            aerodromePoolFactory.createPool(address(aeroExtremeTokenA), address(aeroExtremeTokenB), false);
        aeroExtremeUnbalancedPool = IPool(extremePoolAddr);
        vm.label(extremePoolAddr, 'ForkExtremePool');
    }

    /* ---------------------------------------------------------------------- */
    /*                       Pool Liquidity Initialization                    */
    /* ---------------------------------------------------------------------- */

    function _initializePoolLiquidity() internal virtual {
        _initializeBalancedPool();
        _initializeUnbalancedPool();
        _initializeExtremePool();
    }

    function _initializeBalancedPool() internal {
        aeroBalancedTokenA.mint(address(this), INITIAL_LIQUIDITY);
        aeroBalancedTokenA.approve(address(aerodromeRouter), INITIAL_LIQUIDITY);
        aeroBalancedTokenB.mint(address(this), INITIAL_LIQUIDITY);
        aeroBalancedTokenB.approve(address(aerodromeRouter), INITIAL_LIQUIDITY);

        aerodromeRouter.addLiquidity(
            address(aeroBalancedTokenA),
            address(aeroBalancedTokenB),
            false, // volatile
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY,
            1, // min A
            1, // min B
            address(this),
            block.timestamp + 1 hours
        );
    }

    function _initializeUnbalancedPool() internal {
        aeroUnbalancedTokenA.mint(address(this), UNBALANCED_RATIO_A);
        aeroUnbalancedTokenA.approve(address(aerodromeRouter), UNBALANCED_RATIO_A);
        aeroUnbalancedTokenB.mint(address(this), UNBALANCED_RATIO_B);
        aeroUnbalancedTokenB.approve(address(aerodromeRouter), UNBALANCED_RATIO_B);

        aerodromeRouter.addLiquidity(
            address(aeroUnbalancedTokenA),
            address(aeroUnbalancedTokenB),
            false,
            UNBALANCED_RATIO_A,
            UNBALANCED_RATIO_B,
            1,
            1,
            address(this),
            block.timestamp + 1 hours
        );
    }

    function _initializeExtremePool() internal {
        aeroExtremeTokenA.mint(address(this), UNBALANCED_RATIO_A);
        aeroExtremeTokenA.approve(address(aerodromeRouter), UNBALANCED_RATIO_A);
        aeroExtremeTokenB.mint(address(this), EXTREME_RATIO_B);
        aeroExtremeTokenB.approve(address(aerodromeRouter), EXTREME_RATIO_B);

        aerodromeRouter.addLiquidity(
            address(aeroExtremeTokenA),
            address(aeroExtremeTokenB),
            false,
            UNBALANCED_RATIO_A,
            EXTREME_RATIO_B,
            1,
            1,
            address(this),
            block.timestamp + 1 hours
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                       Vault Infrastructure Deployment                  */
    /* ---------------------------------------------------------------------- */

    function _deployVaultInfrastructure() internal virtual {
        // Deploy facets
        aerodromeStandardExchangeInFacet = create3Factory.deployAerodromeStandardExchangeInFacet();
        aerodromeStandardExchangeOutFacet = create3Factory.deployAerodromeStandardExchangeOutFacet();

        // Deploy DFPkg as owner
        vm.startPrank(owner);
        aerodromeStandardExchangeDFPkg = indexedexManager.deployAerodromeStandardExchangeDFPkg(
            erc20Facet,
            erc2612Facet,
            erc5267Facet,
            erc4626Facet,
            erc4626BasicVaultFacet,
            erc4626StandardVaultFacet,
            aerodromeStandardExchangeInFacet,
            aerodromeStandardExchangeOutFacet,
            indexedexManager, // vaultFeeOracleQuery
            indexedexManager, // vaultRegistryDeployment
            permit2,
            aerodromeRouter, // Use mainnet router!
            aerodromePoolFactory
        );
        vm.stopPrank();
        vm.label(address(aerodromeStandardExchangeDFPkg), 'AerodromeStandardExchangeDFPkg_Fork');
    }

    /* ---------------------------------------------------------------------- */
    /*                          Vault Deployment                              */
    /* ---------------------------------------------------------------------- */

    function _deployVaults() internal virtual {
        balancedVault = IStandardExchangeProxy(aerodromeStandardExchangeDFPkg.deployVault(aeroBalancedPool));
        vm.label(address(balancedVault), 'ForkBalancedVault');

        unbalancedVault = IStandardExchangeProxy(aerodromeStandardExchangeDFPkg.deployVault(aeroUnbalancedPool));
        vm.label(address(unbalancedVault), 'ForkUnbalancedVault');

        extremeVault = IStandardExchangeProxy(aerodromeStandardExchangeDFPkg.deployVault(aeroExtremeUnbalancedPool));
        vm.label(address(extremeVault), 'ForkExtremeVault');
    }

    /* ---------------------------------------------------------------------- */
    /*                           Vault Accessors                              */
    /* ---------------------------------------------------------------------- */

    function _getVault(PoolConfig config) internal view returns (IStandardExchangeProxy) {
        if (config == PoolConfig.Balanced) return balancedVault;
        if (config == PoolConfig.Unbalanced) return unbalancedVault;
        return extremeVault;
    }

    function _getPool(PoolConfig config) internal view returns (IPool) {
        if (config == PoolConfig.Balanced) return aeroBalancedPool;
        if (config == PoolConfig.Unbalanced) return aeroUnbalancedPool;
        return aeroExtremeUnbalancedPool;
    }

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
    /*                           Helper Functions                             */
    /* ---------------------------------------------------------------------- */

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _boundSwapAmount(IPool pool, ERC20PermitMintableStub tokenIn, uint256 amountIn)
        internal
        view
        returns (uint256)
    {
        (uint256 reserve0, uint256 reserve1,) = pool.getReserves();
        uint256 reserveIn = address(tokenIn) == pool.token0() ? reserve0 : reserve1;
        return bound(amountIn, MIN_TEST_AMOUNT, reserveIn / 10);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Fork-Specific Sanity Test                      */
    /* ---------------------------------------------------------------------- */

    function test_sanity_aerodromeInfrastructureValid() public view {
        // Verify mainnet contracts are bound
        assertEq(address(aerodromeRouter), BASE_MAIN.AERODROME_ROUTER, 'Router should be mainnet');
        assertEq(address(aerodromePoolFactory), BASE_MAIN.AERODROME_POOL_FACTORY, 'Factory should be mainnet');

        // Verify pools were created
        assertTrue(_hasCode(address(aeroBalancedPool)), 'Balanced pool should exist');
        assertTrue(_hasCode(address(aeroUnbalancedPool)), 'Unbalanced pool should exist');
        assertTrue(_hasCode(address(aeroExtremeUnbalancedPool)), 'Extreme pool should exist');

        // Verify pools have liquidity
        (uint256 r0, uint256 r1,) = aeroBalancedPool.getReserves();
        assertGt(r0 + r1, 0, 'Balanced pool should have liquidity');
    }
}
