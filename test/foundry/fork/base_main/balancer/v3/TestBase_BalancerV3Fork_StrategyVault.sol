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

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {TestBase_BalancerV3Fork} from 'test/foundry/fork/base_main/balancer/v3/TestBase_BalancerV3Fork.sol';
import {VaultComponentFactoryService} from 'contracts/vaults/VaultComponentFactoryService.sol';
import {IStandardExchangeProxy} from 'contracts/interfaces/proxies/IStandardExchangeProxy.sol';
import {
    IAerodromeStandardExchangeDFPkg
} from 'contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol';
import {
    Aerodrome_Component_FactoryService
} from 'contracts/protocols/dexes/aerodrome/v1/Aerodrome_Component_FactoryService.sol';
import {IIndexedexManagerProxy} from 'contracts/interfaces/proxies/IIndexedexManagerProxy.sol';

/**
 * @title TestBase_BalancerV3Fork_StrategyVault
 * @notice Extends Balancer V3 fork setup with a live Aerodrome-backed strategy vault.
 * @dev Many Balancer router routes (VaultDeposit/VaultWithdrawal/VaultPassThrough) require a strategy vault.
 *      This base deploys an Aerodrome StandardExchange vault that wraps an Aerodrome pool created on Base mainnet.
 */
contract TestBase_BalancerV3Fork_StrategyVault is TestBase_BalancerV3Fork {
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    using Aerodrome_Component_FactoryService for ICreate3FactoryProxy;
    using Aerodrome_Component_FactoryService for IIndexedexManagerProxy;

    /* ---------------------------------------------------------------------- */
    /*                         Mainnet Aerodrome                              */
    /* ---------------------------------------------------------------------- */

    IRouter internal aerodromeRouter;
    IPoolFactory internal aerodromePoolFactory;

    /* ---------------------------------------------------------------------- */
    /*                          Strategy Vault Setup                          */
    /* ------------------------------------------------------------------ */

    IPool internal aeroDaiUsdcPool;
    IPool internal aeroDaiWethPool;

    // Vault facets
    IFacet internal erc20Facet;
    IFacet internal erc5267Facet;
    IFacet internal erc2612Facet;
    IFacet internal erc4626Facet;
    IFacet internal erc4626BasicVaultFacet;
    IFacet internal erc4626StandardVaultFacet;

    // Aerodrome exchange facets + package + vault
    IFacet internal aerodromeStandardExchangeInFacet;
    IFacet internal aerodromeStandardExchangeOutFacet;
    IAerodromeStandardExchangeDFPkg internal aerodromeStandardExchangeDFPkg;

    IStandardExchangeProxy internal daiUsdcVault;
    IStandardExchangeProxy internal daiWethVault;

    function setUp() public virtual override {
        super.setUp();

        _bindAerodromeMainnet();
        _createAerodromePools();
        _seedAerodromeLiquidity();

        _deployVaultFacets();
        _deployAerodromeVaultPackage();
        _deployStrategyVaults();
    }

    function _bindAerodromeMainnet() internal {
        aerodromeRouter = IRouter(BASE_MAIN.AERODROME_ROUTER);
        aerodromePoolFactory = IPoolFactory(BASE_MAIN.AERODROME_POOL_FACTORY);

        _assertHasCode(address(aerodromeRouter), 'Aerodrome Router');
        _assertHasCode(address(aerodromePoolFactory), 'Aerodrome Pool Factory');
    }

    function _createAerodromePools() internal {
        // DAI/USDC pool
        address daiUsdcPoolAddr = aerodromePoolFactory.createPool(address(dai), address(usdc), false);
        aeroDaiUsdcPool = IPool(daiUsdcPoolAddr);
        vm.label(daiUsdcPoolAddr, 'Fork_Aero_DAI_USDC_Pool');
        _assertHasCode(daiUsdcPoolAddr, 'Aerodrome DAI/USDC Pool');

        // DAI/WETH pool
        address daiWethPoolAddr = aerodromePoolFactory.createPool(address(dai), address(weth), false);
        aeroDaiWethPool = IPool(daiWethPoolAddr);
        vm.label(daiWethPoolAddr, 'Fork_Aero_DAI_WETH_Pool');
        _assertHasCode(daiWethPoolAddr, 'Aerodrome DAI/WETH Pool');
    }

    function _seedAerodromeLiquidity() internal {
        // Mint to this contract and seed the pools.
        dai.mint(address(this), TEST_AMOUNT * 2);
        usdc.mint(address(this), TEST_AMOUNT);
        deal(address(weth), address(this), TEST_AMOUNT);

        // DAI/USDC liquidity
        dai.approve(address(aerodromeRouter), TEST_AMOUNT);
        usdc.approve(address(aerodromeRouter), TEST_AMOUNT);
        aerodromeRouter.addLiquidity(
            address(dai), address(usdc), false, TEST_AMOUNT, TEST_AMOUNT, 1, 1, address(this), _deadline()
        );

        // DAI/WETH liquidity
        dai.approve(address(aerodromeRouter), TEST_AMOUNT);
        weth.approve(address(aerodromeRouter), TEST_AMOUNT);
        aerodromeRouter.addLiquidity(
            address(dai), address(weth), false, TEST_AMOUNT, TEST_AMOUNT, 1, 1, address(this), _deadline()
        );
    }

    function _deployVaultFacets() internal {
        erc20Facet = create3Factory.deployERC20Facet();
        erc2612Facet = create3Factory.deployERC2612Facet();
        erc5267Facet = create3Factory.deployERCC5267Facet();
        erc4626Facet = create3Factory.deployERC4626Facet();
        erc4626BasicVaultFacet = create3Factory.deployERC4626BasedBasicVaultFacet();
        erc4626StandardVaultFacet = create3Factory.deployERC4626StandardVaultFacet();

        aerodromeStandardExchangeInFacet = create3Factory.deployAerodromeStandardExchangeInFacet();
        aerodromeStandardExchangeOutFacet = create3Factory.deployAerodromeStandardExchangeOutFacet();
    }

    function _deployAerodromeVaultPackage() internal {
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
            indexedexManager,
            indexedexManager,
            permit2,
            aerodromeRouter,
            aerodromePoolFactory
        );
        vm.stopPrank();

        vm.label(address(aerodromeStandardExchangeDFPkg), 'AerodromeStandardExchangeDFPkg_BalancerFork');
    }

    function _deployStrategyVaults() internal {
        daiUsdcVault = IStandardExchangeProxy(aerodromeStandardExchangeDFPkg.deployVault(aeroDaiUsdcPool));
        vm.label(address(daiUsdcVault), 'Fork_Aero_DAI_USDC_Vault');

        daiWethVault = IStandardExchangeProxy(aerodromeStandardExchangeDFPkg.deployVault(aeroDaiWethPool));
        vm.label(address(daiWethVault), 'Fork_Aero_DAI_WETH_Vault');
    }
}
