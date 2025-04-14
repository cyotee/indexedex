// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {betterconsole as console} from '@crane/contracts/utils/vm/foundry/tools/betterconsole.sol';
import {BASE_MAIN} from "@crane/contracts/constants/networks/BASE_MAIN.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {ICLFactory} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/ICLFactory.sol";
import {ICLPool} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/ICLPool.sol";
import {TestBase_Permit2} from "@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol";
import {TestBase_SharedConstants} from "@crane/contracts/test/bases/TestBase_SharedConstants.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                  */
/* -------------------------------------------------------------------------- */

import {TestBase_BaseFork} from "test/foundry/fork/base_main/TestBase_BaseFork.sol";
import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    ISlipstreamStandardExchangeDFPkg,
    SlipstreamStandardExchangeDFPkg
} from "contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeDFPkg.sol";
import {
    Slipstream_Component_FactoryService
} from "contracts/protocols/dexes/aerodrome/slipstream/Slipstream_Component_FactoryService.sol";

/**
 * @title TestBase_SlipstreamFork
 * @notice Base test contract for Slipstream fork tests on Base mainnet.
 * @dev Combines Crane's Slipstream fork infrastructure with IndexedEx vault
 *      infrastructure. Uses existing Slipstream pools from Base mainnet for
 *      isolated vault integration testing.
 *
 *      Key differences from spec tests:
 *      - Fork against live Base mainnet via 'base_mainnet_alchemy' RPC
 *      - Uses BASE_MAIN Slipstream factory, quoter, and swap router
 *      - Works with existing Slipstream pools (WETH/USDC, cbBTC/WETH, etc.)
 *      - Deploys IndexedEx vault infrastructure (owner, factories, manager)
 *      - Creates vault instances wrapping live Slipstream CL pools
 *
 *      Inheritance chain:
 *      - TestBase_BaseFork: Base mainnet fork setup and RPC binding
 *      - TestBase_Permit2: Permit2 contract setup
 *      - TestBase_VaultComponents: Core vault facets (ERC20, ERC4626, etc.)
 *      - TestBase_SharedConstants: Shared test constants
 */
contract TestBase_SlipstreamFork is TestBase_BaseFork, TestBase_Permit2, TestBase_VaultComponents, TestBase_SharedConstants {
    using Slipstream_Component_FactoryService for ICreate3FactoryProxy;
    using BetterEfficientHashLib for bytes;
    using BetterEfficientHashLib for bytes32;

    /* ---------------------------------------------------------------------- */
    /*                              Constants                                  */
    /* ---------------------------------------------------------------------- */

    /// @notice Default width multiplier for vault position range
    /// @dev tickRange = widthMultiplier * tickSpacing
    uint24 constant DEFAULT_WIDTH_MULTIPLIER = 10;

    /// @notice Slipstream fee tiers in pips (1 pip = 0.0001%)
    uint24 constant FEE_LOW = 100; // 0.01%
    uint24 constant FEE_MEDIUM = 500; // 0.05%
    uint24 constant FEE_HIGH = 3000; // 0.30%
    uint24 constant FEE_HIGHEST = 10000; // 1.00%

    /// @notice Well-known token addresses on Base
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant CB_BTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;

    /* ---------------------------------------------------------------------- */
    /*                         Slipstream Mainnet Contracts                     */
    /* ---------------------------------------------------------------------- */

    /// @notice Live Slipstream CL Factory from Base mainnet
    ICLFactory internal slipstreamFactory;

    /// @notice Live Slipstream QuoterV2 from Base mainnet
    address internal slipstreamQuoter;

    /// @notice Live Slipstream Swap Router from Base mainnet
    address internal slipstreamSwapRouter;

    /* ---------------------------------------------------------------------- */
    /*                          Well-Known Pools                               */
    /* ---------------------------------------------------------------------- */

    /// @notice WETH/USDC pool at 0.05% fee tier (most liquid)
    ICLPool internal wethUsdcPool;

    /// @notice cbBTC/WETH pool at 0.05% fee tier
    ICLPool internal cbBtcWethPool;

    /* ---------------------------------------------------------------------- */
    /*                          Vault Components                               */
    /* ---------------------------------------------------------------------- */

    IFacet internal slipstreamStandardExchangeInFacet;
    IFacet internal slipstreamStandardExchangeOutFacet;
    ISlipstreamStandardExchangeDFPkg internal slipstreamStandardExchangeDFPkg;

    /* ---------------------------------------------------------------------- */
    /*                           Vault Instances                               */
    /* ---------------------------------------------------------------------- */

    IStandardExchangeProxy internal wethUsdcVault;
    IStandardExchangeProxy internal cbBtcWethVault;

    /* ---------------------------------------------------------------------- */
    /*                           Vault Config                                 */
    /* ---------------------------------------------------------------------- */

    enum VaultConfig {
        WethUsdc,
        CbBtcWeth
    }

    /* ---------------------------------------------------------------------- */
    /*                                Setup                                    */
    /* ---------------------------------------------------------------------- */

    function setUp() public virtual override(TestBase_BaseFork, TestBase_Permit2, TestBase_VaultComponents) {
        // Initialize Base mainnet fork
        TestBase_BaseFork.setUp();

        // Initialize Permit2
        TestBase_Permit2.setUp();

        // Initialize IndexedEx infrastructure (factories, fee collector, manager)
        TestBase_VaultComponents.setUp();

        // Initialize shared constants (deploy local WETH if not already set)
        setUpSharedConstants();

        // Bind to live Slipstream contracts
        _bindSlipstreamContracts();

        // Retrieve existing pools from production factory
        _getExistingPools();

        // Deploy Slipstream vault infrastructure
        _deployVaultInfrastructure();

        // Deploy vault instances for existing pools
        _deployVaults();
    }

    /* ---------------------------------------------------------------------- */
    /*                    Slipstream Contract Binding                          */
    /* ---------------------------------------------------------------------- */

    function _bindSlipstreamContracts() internal virtual {
        slipstreamFactory = ICLFactory(BASE_MAIN.AERODROME_SLIPSTREAM_POOL_FACTORY);
        slipstreamQuoter = BASE_MAIN.AERODROME_SLIPSTREAM_QUOTER_V2;
        slipstreamSwapRouter = BASE_MAIN.AERODROME_SLIPSTREAM_SWAP_ROUTER;

        // Verify contracts have code
        _assertHasCode(address(slipstreamFactory), "Slipstream Factory");
        _assertHasCode(slipstreamQuoter, "Slipstream QuoterV2");
        _assertHasCode(slipstreamSwapRouter, "Slipstream Swap Router");

        // Label for debugging
        vm.label(address(slipstreamFactory), "SlipstreamFactory");
        vm.label(slipstreamQuoter, "SlipstreamQuoterV2");
        vm.label(slipstreamSwapRouter, "SlipstreamSwapRouter");
    }

    /* ---------------------------------------------------------------------- */
    /*                       Pool Discovery                                    */
    /* ---------------------------------------------------------------------- */

    function _getExistingPools() internal virtual {
        // Common token addresses on Base (not in BASE_MAIN, use well-known constants)
        // USDC: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
        // cbBTC: 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf
        address usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        address cbBtc = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;

        // WETH/USDC pool at tickSpacing 1 (0.05% fee)
        address wethUsdcAddr = slipstreamFactory.getPool(BASE_MAIN.WETH9, usdc, 1);
        if (wethUsdcAddr != address(0)) {
            wethUsdcPool = ICLPool(wethUsdcAddr);
            vm.label(wethUsdcAddr, "WETH_USDC_CL");
            vm.label(usdc, "USDC");
        }

        // cbBTC/WETH pool at tickSpacing 1 (0.05% fee)
        address cbBtcWethAddr = slipstreamFactory.getPool(cbBtc, BASE_MAIN.WETH9, 1);
        if (cbBtcWethAddr != address(0)) {
            cbBtcWethPool = ICLPool(cbBtcWethAddr);
            vm.label(cbBtcWethAddr, "cbBTC_WETH_CL");
            vm.label(cbBtc, "cbBTC");
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                       Vault Infrastructure Deployment                   */
    /* ---------------------------------------------------------------------- */

    function _deployVaultInfrastructure() internal virtual {
        // Deploy Slipstream exchange facets via CREATE3
        slipstreamStandardExchangeInFacet = create3Factory.deploySlipstreamStandardExchangeInFacet();
        slipstreamStandardExchangeOutFacet = create3Factory.deploySlipstreamStandardExchangeOutFacet();

        // Deploy DFPkg as owner via IndexedexManager
        vm.startPrank(owner);
        ISlipstreamStandardExchangeDFPkg.PkgInit memory pkgInit = ISlipstreamStandardExchangeDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
            slipstreamStandardExchangeInFacet: slipstreamStandardExchangeInFacet,
            slipstreamStandardExchangeOutFacet: slipstreamStandardExchangeOutFacet,
            vaultFeeOracleQuery: IVaultFeeOracleQuery(address(indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
            permit2: permit2,
            slipstreamFactory: slipstreamFactory
        });

        // Use vault registry deployment to deploy the DFPkg
        // This follows the same pattern as Aerodrome via IVaultRegistryDeployment
        IVaultRegistryDeployment vaultRegistry = IVaultRegistryDeployment(address(indexedexManager));
        bytes32 salt = abi.encode(type(SlipstreamStandardExchangeDFPkg).name)._hash();

        // address dfPkgAddr = vaultRegistry.deployPkg(
        //     type(SlipstreamStandardExchangeDFPkg).creationCode,
        //     abi.encode(pkgInit),
        //     salt
        // );

        slipstreamStandardExchangeDFPkg = ISlipstreamStandardExchangeDFPkg(
            vaultRegistry.deployPkg(
                type(SlipstreamStandardExchangeDFPkg).creationCode,
                abi.encode(pkgInit),
                salt
            )
        );
        vm.stopPrank();

        vm.label(address(slipstreamStandardExchangeDFPkg), "SlipstreamStandardExchangeDFPkg");
    }

    /* ---------------------------------------------------------------------- */
    /*                          Vault Deployment                              */
    /* ---------------------------------------------------------------------- */

    function _deployVaults() internal virtual {
        // Deploy vault for WETH/USDC pool if pool exists
        console.log("Deploying vaults for existing Slipstream pools...");
        console.log("WETH/USDC pool address:", address(wethUsdcPool));
        console.log("Deploying WETH/USDC vault with width multiplier:", DEFAULT_WIDTH_MULTIPLIER);
        if (address(wethUsdcPool) != address(0)) {
            wethUsdcVault = IStandardExchangeProxy(
                slipstreamStandardExchangeDFPkg.deployVault(wethUsdcPool, DEFAULT_WIDTH_MULTIPLIER)
            );
            vm.label(address(wethUsdcVault), "WETH_USDC_Vault");
        }
        console.log("Deployed WETH/USDC vault at:", address(wethUsdcVault));

        // Deploy vault for cbBTC/WETH pool if pool exists
        console.log("cbBTC/WETH pool address:", address(cbBtcWethPool));
        console.log("Deploying cbBTC/WETH vault with width multiplier:", DEFAULT_WIDTH_MULTIPLIER);
        if (address(cbBtcWethPool) != address(0)) {
            cbBtcWethVault = IStandardExchangeProxy(
                slipstreamStandardExchangeDFPkg.deployVault(cbBtcWethPool, DEFAULT_WIDTH_MULTIPLIER)
            );
            vm.label(address(cbBtcWethVault), "cbBTC_WETH_Vault");
        }
        console.log("Deployed cbBTC/WETH vault at:", address(cbBtcWethVault));
    }

    /* ---------------------------------------------------------------------- */
    /*                           Vault Accessors                              */
    /* ---------------------------------------------------------------------- */

    function _getVault(VaultConfig config) internal view returns (IStandardExchangeProxy) {
        if (config == VaultConfig.WethUsdc) return wethUsdcVault;
        if (config == VaultConfig.CbBtcWeth) return cbBtcWethVault;
        revert("Unknown vault config");
    }

    function _getPool(VaultConfig config) internal view returns (ICLPool) {
        if (config == VaultConfig.WethUsdc) return wethUsdcPool;
        if (config == VaultConfig.CbBtcWeth) return cbBtcWethPool;
        revert("Unknown pool config");
    }

    /* ---------------------------------------------------------------------- */
    /*                           Helper Functions                             */
    /* ---------------------------------------------------------------------- */

    /// @notice Get a Slipstream pool from the production factory
    /// @param tokenA First token address
    /// @param tokenB Second token address
    /// @param tickSpacing The tick spacing
    /// @return pool The pool address, or ICLPool(address(0)) if not found
    function _getSlipstreamPool(address tokenA, address tokenB, int24 tickSpacing)
        internal
        view
        returns (ICLPool pool)
    {
        address poolAddr = slipstreamFactory.getPool(tokenA, tokenB, tickSpacing);
        if (poolAddr != address(0)) {
            pool = ICLPool(poolAddr);
        }
    }

    /// @notice Get nearest tick aligned to tick spacing
    /// @param tick The tick to align
    /// @param tickSpacing The tick spacing
    /// @return Aligned tick bounded to TickMath limits
    function _nearestUsableTick(int24 tick, int24 tickSpacing) internal pure returns (int24) {
        int24 rounded = (tick / tickSpacing) * tickSpacing;
        if (rounded < TickMath.MIN_TICK) return TickMath.MIN_TICK;
        if (rounded > TickMath.MAX_TICK) return TickMath.MAX_TICK;
        return rounded;
    }

    /// @notice Check if a pool exists and has liquidity
    /// @param pool The pool to check
    /// @return True if pool has non-zero liquidity
    function _poolHasLiquidity(ICLPool pool) internal view returns (bool) {
        try pool.liquidity() returns (uint128 liq) {
            return liq > 0;
        } catch {
            return false;
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                         Fork-Specific Sanity Tests                     */
    /* ---------------------------------------------------------------------- */

    function test_sanity_slipstreamInfrastructureValid() public view {
        // Verify Slipstream factory is bound correctly
        assertEq(
            address(slipstreamFactory),
            BASE_MAIN.AERODROME_SLIPSTREAM_POOL_FACTORY,
            "Factory should match BASE_MAIN"
        );

        // Verify Slipstream contracts have code
        assertTrue(_hasCode(address(slipstreamFactory)), "Slipstream Factory should have code");
        assertTrue(_hasCode(slipstreamQuoter), "Slipstream QuoterV2 should have code");
        assertTrue(_hasCode(slipstreamSwapRouter), "Slipstream Swap Router should have code");

        // Verify pools were retrieved
        assertTrue(address(wethUsdcPool) != address(0), "WETH/USDC pool should exist");
        assertTrue(address(cbBtcWethPool) != address(0), "cbBTC/WETH pool should exist");

        // Verify pools have liquidity
        assertTrue(_poolHasLiquidity(wethUsdcPool), "WETH/USDC pool should have liquidity");
        assertTrue(_poolHasLiquidity(cbBtcWethPool), "cbBTC/WETH pool should have liquidity");

        // Verify vaults were deployed
        assertTrue(address(wethUsdcVault) != address(0), "WETH/USDC vault should be deployed");
        assertTrue(address(cbBtcWethVault) != address(0), "cbBTC/WETH vault should be deployed");
    }

    function test_sanity_slipstreamPoolState() public {
        // Log WETH/USDC pool state for debugging
        if (address(wethUsdcPool) != address(0)) {
            (uint160 sqrtPriceX96, int24 tick,,, uint16 cardinalityNext,) = wethUsdcPool.slot0();
            emit log_named_uint("WETH/USDC sqrtPriceX96", sqrtPriceX96);
            emit log_named_int("WETH/USDC tick", tick);
            emit log_named_uint("WETH/USDC liquidity", wethUsdcPool.liquidity());
            emit log_named_uint("WETH/USDC fee", wethUsdcPool.fee());
            emit log_named_int("WETH/USDC tickSpacing", wethUsdcPool.tickSpacing());
            emit log_named_uint("WETH/USDC cardinalityNext", cardinalityNext);
        }
    }
}
