// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                Open Zeppelin                               */
/* -------------------------------------------------------------------------- */

// Crane IERC20 imported below

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IVault} from '@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol';
import {IRouter as IBalancerRouter} from '@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRouter.sol';
import {IWeightedPool} from '@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol';
import {
    WeightedPoolFactory
} from '@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPoolFactory.sol';
import {
    TokenConfig,
    TokenType,
    PoolRoleAccounts,
    LiquidityManagement
} from '@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol';
import {
    CastingHelpers
} from '@crane/contracts/external/balancer/v3/solidity-utils/contracts/helpers/CastingHelpers.sol';
import {ArrayHelpers} from 'contracts/test/balancer/v3/ArrayHelpers.sol';
import {FixedPoint} from '@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol';
import {IRateProvider} from '@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol';

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {BASE_MAIN} from '@crane/contracts/constants/networks/BASE_MAIN.sol';
import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {IFacet} from '@crane/contracts/interfaces/IFacet.sol';
import {ICreate3FactoryProxy} from '@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol';
import {IWETH} from '@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol';
import {ERC20PermitMintableStub} from '@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol';
import {TestBase_Permit2} from '@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol';
import {IPermit2} from '@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol';
import {SenderGuardFacet} from '@crane/contracts/protocols/dexes/balancer/v3/vault/SenderGuardFacet.sol';

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {TestBase_BaseFork} from 'test/foundry/fork/base_main/TestBase_BaseFork.sol';
import {IndexedexTest} from 'contracts/test/IndexedexTest.sol';
import {IStandardExchangeProxy} from 'contracts/interfaces/proxies/IStandardExchangeProxy.sol';
import {
    IBalancerV3StandardExchangeRouterDFPkg
} from 'contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterDFPkg.sol';
import {
    IBalancerV3StandardExchangeRouterProxy
} from 'contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol';
import {
    BalancerV3StandardExchangeRouter_FactoryService
} from 'contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_FactoryService.sol';

/**
 * @title TestBase_BalancerV3Fork
 * @notice Base test contract for Balancer V3 fork tests on Base mainnet.
 * @dev Uses live Balancer V3 Vault, Router, and Weighted Pool Factory from Base mainnet.
 *      Creates local test tokens and pools for isolated testing.
 *
 *      Key validations:
 *      - IndexedEx router can interact with live Balancer V3 Vault
 *      - Pool creation on mainnet factory works
 *      - No ABI/selector mismatches with mainnet contracts
 */
import {TestBase_SharedConstants} from '@crane/contracts/test/bases/TestBase_SharedConstants.sol';

contract TestBase_BalancerV3Fork is TestBase_BaseFork, TestBase_Permit2, IndexedexTest, TestBase_SharedConstants {
    using CastingHelpers for address[];
    using FixedPoint for uint256;
    using ArrayHelpers for *;
    using BalancerV3StandardExchangeRouter_FactoryService for *;

    /* ---------------------------------------------------------------------- */
    /*                              Constants                                 */
    /* ---------------------------------------------------------------------- */

    uint256 internal constant POOL_INIT_AMOUNT = 10_000e18;

    /* ---------------------------------------------------------------------- */
    /*                         Mainnet Contracts                              */
    /* ---------------------------------------------------------------------- */

    /// @notice Live Balancer V3 Vault from Base mainnet
    IVault internal vault;

    /// @notice Live Balancer V3 Router from Base mainnet
    IBalancerRouter internal balancerRouter;

    /// @notice Live Balancer V3 Weighted Pool Factory from Base mainnet
    WeightedPoolFactory internal weightedPoolFactory;

    /// @notice Live WETH from Base mainnet
    // IWETH internal weth; // provided by TestBase_SharedConstants

    /* ---------------------------------------------------------------------- */
    /*                            Test Tokens                                 */
    /* ---------------------------------------------------------------------- */

    ERC20PermitMintableStub internal dai;
    ERC20PermitMintableStub internal usdc;

    /* ---------------------------------------------------------------------- */
    /*                              Pools                                     */
    /* ---------------------------------------------------------------------- */

    /// @notice DAI/USDC pool created on mainnet factory
    address internal daiUsdcPool;

    /* ---------------------------------------------------------------------- */
    /*                          Router Components                             */
    /* ---------------------------------------------------------------------- */

    IFacet internal senderGuardFacet;
    IFacet internal exactInQueryFacet;
    IFacet internal exactInSwapFacet;
    IFacet internal exactOutQueryFacet;
    IFacet internal exactOutSwapFacet;
    IFacet internal batchExactInFacet;
    IFacet internal batchExactOutFacet;
    IFacet internal prepayFacet;
    IFacet internal prepayHooksFacet;
    IFacet internal permit2WitnessFacet;

    IBalancerV3StandardExchangeRouterDFPkg internal seRouterDFPkg;
    IBalancerV3StandardExchangeRouterProxy internal seRouter;

    /* ---------------------------------------------------------------------- */
    /*                             Test Users                                 */
    /* ---------------------------------------------------------------------- */

    address internal alice;
    address internal bob;
    address internal lp;
    address[] internal users;

    /* ---------------------------------------------------------------------- */
    /*                                Setup                                   */
    /* ---------------------------------------------------------------------- */

    function setUp() public virtual override(TestBase_BaseFork, TestBase_Permit2, IndexedexTest) {
        // Initialize Base fork first
        TestBase_BaseFork.setUp();

        // Use mainnet Permit2 (canonical address on all EVM chains)
        permit2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

        // Initialize Permit2 - will skip deployment since permit2 is already set
        TestBase_Permit2.setUp();

        // Initialize IndexedEx infrastructure
        IndexedexTest.setUp();

        // Setup test users
        _setupUsers();

        // Bind to mainnet Balancer contracts
        _bindMainnetContracts();

        // Initialize shared constants (deploy local WETH if not already set)
        setUpSharedConstants();

        // Create test tokens
        _createTestTokens();

        // Deploy router components
        _deployRouterFacets();
        _deployRouterPackage();
        _deployRouter();

        // Approve router for all users
        _approveRouterForAllUsers();

        // Create test pool on mainnet factory
        _createTestPool();
    }

    /* ---------------------------------------------------------------------- */
    /*                            User Setup                                  */
    /* ---------------------------------------------------------------------- */

    function _setupUsers() internal virtual {
        alice = makeAddr('alice');
        bob = makeAddr('bob');
        lp = makeAddr('lp');
        users.push(alice);
        users.push(bob);
        users.push(lp);
    }

    /* ---------------------------------------------------------------------- */
    /*                      Mainnet Contract Binding                          */
    /* ---------------------------------------------------------------------- */

    function _bindMainnetContracts() internal virtual {
        vault = IVault(BASE_MAIN.BALANCER_V3_VAULT);
        balancerRouter = IBalancerRouter(BASE_MAIN.BALANCER_V3_ROUTER);
        weightedPoolFactory = WeightedPoolFactory(BASE_MAIN.BALANCER_V3_WEIGHTED_POOL_FACTORY);
        weth = IWETH(BASE_MAIN.WETH9);

        // Verify they exist
        _assertHasCode(address(vault), 'Balancer V3 Vault');
        _assertHasCode(address(balancerRouter), 'Balancer V3 Router');
        _assertHasCode(address(weightedPoolFactory), 'Balancer V3 Weighted Pool Factory');
        _assertHasCode(address(weth), 'WETH');
    }

    /* ---------------------------------------------------------------------- */
    /*                         Test Token Creation                            */
    /* ---------------------------------------------------------------------- */

    function _createTestTokens() internal virtual {
        dai = new ERC20PermitMintableStub('Fork DAI Stablecoin', 'fDAI', 18, address(this), 0);
        vm.label(address(dai), 'ForkDAI');

        usdc = new ERC20PermitMintableStub('Fork USD Coin', 'fUSDC', 18, address(this), 0);
        vm.label(address(usdc), 'ForkUSDC');
    }

    /* ---------------------------------------------------------------------- */
    /*                        Router Deployment                               */
    /* ---------------------------------------------------------------------- */

    function _deployRouterFacets() internal virtual {
        // Deploy SenderGuardFacet directly
        senderGuardFacet = IFacet(address(new SenderGuardFacet()));
        vm.label(address(senderGuardFacet), 'SenderGuardFacet');

        exactInQueryFacet = create3Factory.deployBalancerV3StandardExchangeRouterExactInQueryFacet();
        exactInSwapFacet = create3Factory.deployBalancerV3StandardExchangeRouterExactInSwapFacet();
        exactOutQueryFacet = create3Factory.deployBalancerV3StandardExchangeRouterExactOutQueryFacet();
        exactOutSwapFacet = create3Factory.deployBalancerV3StandardExchangeRouterExactOutSwapFacet();
        batchExactInFacet = create3Factory.deployBalancerV3StandardExchangeBatchRouterExactInFacet();
        batchExactOutFacet = create3Factory.deployBalancerV3StandardExchangeBatchRouterExactOutFacet();
        prepayFacet = create3Factory.deployBalancerV3StandardExchangeRouterPrepayFacet();
        prepayHooksFacet = create3Factory.deployBalancerV3StandardExchangeRouterPrepayHooksFacet();
        permit2WitnessFacet = create3Factory.deployBalancerV3StandardExchangeRouterPermit2WitnessFacet();
    }

    function _deployRouterPackage() internal virtual {
        // seRouterDFPkg = create3Factory.deployBalancerV3StandardExchangeRouterDFPkg(
        //     senderGuardFacet,
        //     exactInQueryFacet,
        //     exactOutQueryFacet,
        //     exactInSwapFacet,
        //     exactOutSwapFacet,
        //     prepayFacet,
        //     prepayHooksFacet,
        //     batchExactInFacet,
        //     batchExactOutFacet,
        //     permit2WitnessFacet,
        //     vault, // Use mainnet vault!
        //     permit2,
        //     weth // Use mainnet WETH!
        // );
        IBalancerV3StandardExchangeRouterDFPkg.PkgInit memory pkgInit;
        {
            pkgInit.senderGuardFacet = senderGuardFacet;
            pkgInit.balancerV3StandardExchangeRouterExactInQueryFacet = exactInQueryFacet;
            pkgInit.balancerV3StandardExchangeRouterExactInSwapFacet = exactInSwapFacet;
            pkgInit.balancerV3StandardExchangeRouterExactOutQueryFacet = exactOutQueryFacet;
            pkgInit.balancerV3StandardExchangeRouterExactOutSwapFacet = exactOutSwapFacet;
            pkgInit.balancerV3StandardExchangeBatchRouterExactInFacet = batchExactInFacet;
            pkgInit.balancerV3StandardExchangeBatchRouterExactOutFacet = batchExactOutFacet;
            pkgInit.balancerV3StandardExchangeRouterPrepayFacet = prepayFacet;
            pkgInit.balancerV3StandardExchangeRouterPrepayHooksFacet = prepayHooksFacet;
            pkgInit.balancerV3StandardExchangePermit2WitnessFacet = permit2WitnessFacet;
            pkgInit.balancerV3Vault = vault;
            pkgInit.permit2 = permit2;
            pkgInit.weth = weth;
        }
        seRouterDFPkg = create3Factory.deployBalancerV3StandardExchangeRouterDFPkg(
            pkgInit
        );

        vm.label(address(seRouterDFPkg), 'BalancerV3StandardExchangeRouterDFPkg_Fork');
    }

    function _deployRouter() internal virtual {
        seRouter = diamondPackageFactory.deployBalancerV3StandardExchangeRouter(seRouterDFPkg);
        vm.label(address(seRouter), 'BalancerV3StandardExchangeRouter_Fork');
    }

    /* ---------------------------------------------------------------------- */
    /*                          Approval Helpers                              */
    /* ---------------------------------------------------------------------- */

    function _approveRouterForAllUsers() internal virtual {
        _approveSpenderForAllUsers(address(seRouter));
    }

    function _approveSpenderForAllUsers(address spender) internal virtual {
        for (uint256 i = 0; i < users.length; ++i) {
            address user = users[i];
            vm.startPrank(user);

            dai.approve(address(permit2), type(uint256).max);
            permit2.approve(address(dai), spender, type(uint160).max, type(uint48).max);

            usdc.approve(address(permit2), type(uint256).max);
            permit2.approve(address(usdc), spender, type(uint160).max, type(uint48).max);

            vm.stopPrank();
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                          Pool Creation                                 */
    /* ---------------------------------------------------------------------- */

    function _createTestPool() internal virtual {
        // Sort tokens by address (Balancer requirement)
        address[] memory tokens = new address[](2);
        if (address(dai) < address(usdc)) {
            tokens[0] = address(dai);
            tokens[1] = address(usdc);
        } else {
            tokens[0] = address(usdc);
            tokens[1] = address(dai);
        }

        // Create token configs (no rate providers for simple tokens)
        TokenConfig[] memory tokenConfigs = new TokenConfig[](2);
        tokenConfigs[0] = TokenConfig({
            token: IERC20(tokens[0]),
            tokenType: TokenType.STANDARD,
            rateProvider: IRateProvider(address(0)),
            paysYieldFees: false
        });
        tokenConfigs[1] = TokenConfig({
            token: IERC20(tokens[1]),
            tokenType: TokenType.STANDARD,
            rateProvider: IRateProvider(address(0)),
            paysYieldFees: false
        });

        // 50/50 weights
        uint256[] memory weights = new uint256[](2);
        weights[0] = 0.5e18;
        weights[1] = 0.5e18;

        // Create pool on mainnet factory
        PoolRoleAccounts memory roleAccounts;
        daiUsdcPool = weightedPoolFactory.create(
            'Fork DAI-USDC Pool',
            'fDAI-fUSDC-BPT',
            tokenConfigs,
            weights,
            roleAccounts,
            0.003e18, // 0.3% swap fee
            address(0), // no hooks
            false, // not donation enabled
            false, // not liquidity bootstrapping
            bytes32(keccak256(abi.encodePacked(block.timestamp, 'fork-pool'))) // unique salt
        );
        vm.label(daiUsdcPool, 'ForkDaiUsdcPool');

        // Initialize pool with liquidity
        _initPool();
    }

    function _initPool() internal virtual {
        // Mint tokens to LP
        dai.mint(lp, POOL_INIT_AMOUNT);
        usdc.mint(lp, POOL_INIT_AMOUNT);

        vm.startPrank(lp);

        // Balancer V3 Router uses Permit2 for token transfers
        // Step 1: Approve Permit2 to spend tokens
        dai.approve(address(permit2), type(uint256).max);
        usdc.approve(address(permit2), type(uint256).max);

        // Step 2: Give Router allowance via Permit2 (with max expiration)
        permit2.approve(address(dai), address(balancerRouter), type(uint160).max, type(uint48).max);
        permit2.approve(address(usdc), address(balancerRouter), type(uint160).max, type(uint48).max);

        // Get sorted token order for the pool
        (IERC20[] memory tokens,,,) = vault.getPoolTokenInfo(daiUsdcPool);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = POOL_INIT_AMOUNT;
        amounts[1] = POOL_INIT_AMOUNT;

        // Initialize pool using mainnet router
        balancerRouter.initialize(
            daiUsdcPool,
            tokens,
            amounts,
            0, // min BPT out
            false, // wethIsEth
            bytes('') // userData
        );

        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                           Query Helpers                                */
    /* ---------------------------------------------------------------------- */

    function _queryExactIn(
        address pool,
        IERC20 tokenIn,
        IStandardExchangeProxy tokenInVault,
        IERC20 tokenOut,
        IStandardExchangeProxy tokenOutVault,
        uint256 exactAmountIn
    ) internal returns (uint256 amountOut) {
        // Snapshot state before query - the Balancer V3 quote mechanism modifies state
        // even though it's meant to be read-only. On real pools (vs mocks), this matters
        // because the AMM math depends on pool balances.
        uint256 snapshot = vm.snapshotState();

        vm.prank(address(0), address(0));
        amountOut = seRouter.querySwapSingleTokenExactIn(
            pool, tokenIn, tokenInVault, tokenOut, tokenOutVault, exactAmountIn, lp, ''
        );

        // Restore state after query
        vm.revertToState(snapshot);
    }

    function _queryExactOut(
        address pool,
        IERC20 tokenIn,
        IStandardExchangeProxy tokenInVault,
        IERC20 tokenOut,
        IStandardExchangeProxy tokenOutVault,
        uint256 exactAmountOut
    ) internal returns (uint256 amountIn) {
        // Snapshot state before query - same reason as _queryExactIn
        uint256 snapshot = vm.snapshotState();

        vm.prank(address(0), address(0));
        amountIn = seRouter.querySwapSingleTokenExactOut(
            pool, tokenIn, tokenInVault, tokenOut, tokenOutVault, exactAmountOut, lp, ''
        );

        // Restore state after query
        vm.revertToState(snapshot);
    }

    /* ---------------------------------------------------------------------- */
    /*                           Swap Helpers                                 */
    /* ---------------------------------------------------------------------- */

    function _swapExactIn(
        address pool,
        IERC20 tokenIn,
        IStandardExchangeProxy tokenInVault,
        IERC20 tokenOut,
        IStandardExchangeProxy tokenOutVault,
        uint256 exactAmountIn,
        uint256 minAmountOut
    ) internal returns (uint256 amountOut) {
        amountOut = seRouter.swapSingleTokenExactIn(
            pool, tokenIn, tokenInVault, tokenOut, tokenOutVault, exactAmountIn, minAmountOut, _deadline(), false, ''
        );
    }

    function _swapExactOut(
        address pool,
        IERC20 tokenIn,
        IStandardExchangeProxy tokenInVault,
        IERC20 tokenOut,
        IStandardExchangeProxy tokenOutVault,
        uint256 exactAmountOut,
        uint256 maxAmountIn
    ) internal returns (uint256 amountIn) {
        amountIn = seRouter.swapSingleTokenExactOut(
            pool, tokenIn, tokenInVault, tokenOut, tokenOutVault, exactAmountOut, maxAmountIn, _deadline(), false, ''
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                          Utility Helpers                               */
    /* ---------------------------------------------------------------------- */

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _noVault() internal pure returns (IStandardExchangeProxy) {
        return IStandardExchangeProxy(address(0));
    }

    function _mintAndApprove(address token, address to, uint256 amount) internal {
        if (token == address(dai)) {
            dai.mint(to, amount);
        } else if (token == address(usdc)) {
            usdc.mint(to, amount);
        }

        vm.prank(to);
        IERC20(token).approve(address(permit2), type(uint256).max);
        vm.prank(to);
        permit2.approve(token, address(seRouter), type(uint160).max, type(uint48).max);
    }

    function _getPoolTokens(address pool) internal view returns (IERC20 token0, IERC20 token1) {
        (IERC20[] memory tokens,,,) = vault.getPoolTokenInfo(pool);
        return (tokens[0], tokens[1]);
    }

    /* ---------------------------------------------------------------------- */
    /*                       Fork-Specific Sanity Test                        */
    /* ---------------------------------------------------------------------- */

    function test_sanity_balancerInfrastructureValid() public view {
        // Verify mainnet contracts are bound
        assertEq(address(vault), BASE_MAIN.BALANCER_V3_VAULT, 'Vault should be mainnet');
        assertEq(address(balancerRouter), BASE_MAIN.BALANCER_V3_ROUTER, 'Router should be mainnet');
        assertEq(address(weightedPoolFactory), BASE_MAIN.BALANCER_V3_WEIGHTED_POOL_FACTORY, 'Factory should be mainnet');

        // Verify pool was created
        assertTrue(_hasCode(daiUsdcPool), 'Pool should exist');

        // Verify pool has liquidity
        (IERC20[] memory tokens,, uint256[] memory balances,) = vault.getPoolTokenInfo(daiUsdcPool);
        assertEq(tokens.length, 2, 'Pool should have 2 tokens');
        assertGt(balances[0], 0, 'Token0 balance should be > 0');
        assertGt(balances[1], 0, 'Token1 balance should be > 0');
    }
}
