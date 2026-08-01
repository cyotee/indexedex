// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_Permit2} from "@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol";

import {TestBase_BaseFork} from "test/foundry/fork/base_main/TestBase_BaseFork.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    UniswapV3_Component_FactoryService
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3_Component_FactoryService.sol";
import {
    IUniswapV3StandardExchangeDFPkg
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeDFPkg.sol";

/**
 * @notice Base mainnet fork smoke for Uni V3 SE.
 * @dev Pin: WETH/USDC 0.05% pool on Base (fee 500).
 *      Pool: 0xd0b53D9277642d899DF5C87A3966A349A798F224 (WETH/USDC 500) - verify at runtime.
 *      If RPC unavailable, env failure is expected; hermetic suite remains DoD.
 */
contract UniswapV3StandardExchange_Fork_Test is TestBase_BaseFork, TestBase_Permit2, TestBase_VaultComponents {
    using UniswapV3_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV3_Component_FactoryService for IFacet;
    using UniswapV3_Component_FactoryService for IIndexedexManagerProxy;

    // Base mainnet Uniswap V3 factory
    address constant UNI_V3_FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    uint24 constant FEE = 500;

    IUniswapV3StandardExchangeDFPkg internal pkg;
    IStandardExchangeProxy internal vault;
    IUniswapV3Pool internal pool;

    function setUp() public override(TestBase_BaseFork, TestBase_Permit2, TestBase_VaultComponents) {
        TestBase_BaseFork.setUp();
        TestBase_Permit2.setUp();
        TestBase_VaultComponents.setUp();

        IUniswapV3Factory factory = IUniswapV3Factory(UNI_V3_FACTORY);
        address poolAddr = factory.getPool(WETH, USDC, FEE);
        require(poolAddr != address(0), "pool missing");
        pool = IUniswapV3Pool(poolAddr);

        IFacet inFacet = create3Factory.deployUniswapV3StandardExchangeInFacet();
        IFacet inQueryFacet = create3Factory.deployUniswapV3StandardExchangeInQueryFacet();
        IFacet outFacet = create3Factory.deployUniswapV3StandardExchangeOutFacet();
        IFacet importFacet = create3Factory.deployUniswapV3StandardExchangePositionImportFacet();

        vm.startPrank(owner);
        pkg = indexedexManager.deployUniswapV3StandardExchangeDFPkg(
            erc20Facet.buildArgsUniswapV3StandardExchangePkgInit(
                erc5267Facet,
                erc2612Facet,
                multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet,
                inFacet,
                inQueryFacet,
                outFacet,
                importFacet,
                indexedexManager,
                indexedexManager,
                permit2,
                factory
            )
        );
        vm.stopPrank();

        vault = IStandardExchangeProxy(pkg.deployVault(pool, 10));
    }

    function test_fork_directSwap_and_zap() public {
        address token0 = pool.token0();
        address token1 = pool.token1();
        address alice = makeAddr("alice");

        // Fund via deal.
        deal(token0, alice, 10 ether);
        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), type(uint256).max);

        // Direct swap smoke.
        uint256 out = vault.exchangeIn(IERC20(token0), 0.1 ether, IERC20(token1), 0, alice, false, block.timestamp + 1);
        assertGt(out, 0, "direct swap");

        // Zap smoke.
        uint256 shares =
            vault.exchangeIn(IERC20(token0), 1 ether, IERC20(address(vault)), 0, alice, false, block.timestamp + 1);
        assertGt(shares, 0, "zap");
        vm.stopPrank();
    }
}
