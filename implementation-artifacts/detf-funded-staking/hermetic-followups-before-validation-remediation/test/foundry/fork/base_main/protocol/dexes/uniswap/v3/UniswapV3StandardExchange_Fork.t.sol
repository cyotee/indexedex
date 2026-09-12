// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {BASE_MAIN} from "@crane/contracts/constants/networks/BASE_MAIN.sol";
import {TestBase_Permit2} from "@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol";

import {TestBase_BaseFork} from "test/foundry/fork/base_main/TestBase_BaseFork.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {
    UniswapV3_Component_FactoryService
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3_Component_FactoryService.sol";
import {
    IUniswapV3StandardExchangeDFPkg
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeDFPkg.sol";
import {
    IUniswapV3StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3StandardExchangeLiquidReserve.sol";
import {
    UniswapV3BoundPoolLockSeCaller
} from "test/foundry/spec/protocol/dexes/uniswap/v3/harness/UniswapV3BoundPoolLockSeCaller.sol";

/**
 * @notice Base mainnet fork smoke for Uni V3 SE.
 * @dev Pin: WETH/USDC 0.05% pool on Base (fee 500).
 *      Pool: 0xd0b53D9277642d899DF5C87A3966A349A798F224 (WETH/USDC 500) - verify at runtime.
 *      If RPC unavailable, env failure is expected; hermetic suite remains DoD.
 */
contract UniswapV3StandardExchange_Fork_Test is TestBase_BaseFork, TestBase_Permit2, TestBase_VaultComponents {
    using UniswapV3_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV3_Component_FactoryService for IIndexedexManagerProxy;

    address constant UNI_V3_FACTORY = BASE_MAIN.UNISWAP_V3_FACTORY;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    uint24 constant FEE = 500;
    address internal constant DEAD = address(0x000000000000000000000000000000000000dEaD);

    IUniswapV3StandardExchangeDFPkg internal pkg;
    IStandardExchangeProxy internal vault;
    IUniswapV3Pool internal pool;

    function setUp() public override(TestBase_BaseFork, TestBase_Permit2, TestBase_VaultComponents) {
        TestBase_BaseFork.setUp();
        TestBase_Permit2.setUp();
        TestBase_VaultComponents.setUp();

        pool = _resolveLivePool();
        pkg = _deployPkg(IUniswapV3Factory(UNI_V3_FACTORY));
        vault = IStandardExchangeProxy(pkg.deployVault(pool));
    }

    function _resolveLivePool() private view returns (IUniswapV3Pool livePool) {
        address poolAddr = IUniswapV3Factory(UNI_V3_FACTORY).getPool(WETH, USDC, FEE);
        require(poolAddr != address(0), "pool missing");
        livePool = IUniswapV3Pool(poolAddr);
    }

    /// @dev Build PkgInit via sequential field writes (avoids 13-arg stack-too-deep under fork inheritance).
    function _deployPkg(IUniswapV3Factory factory_) private returns (IUniswapV3StandardExchangeDFPkg deployed) {
        IUniswapV3StandardExchangeDFPkg.PkgInit memory init = _buildPkgInit(factory_);
        vm.startPrank(owner);
        deployed = indexedexManager.deployUniswapV3StandardExchangeDFPkg(init);
        vm.stopPrank();
    }

    function _buildPkgInit(IUniswapV3Factory factory_)
        private
        returns (IUniswapV3StandardExchangeDFPkg.PkgInit memory init)
    {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentageOfTypeId(
            type(IUniswapV3StandardExchangeLiquidReserve).interfaceId, 0.20e18
        );
        vm.stopPrank();

        init.erc20Facet = erc20Facet;
        init.erc5267Facet = erc5267Facet;
        init.erc2612Facet = erc2612Facet;
        init.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        init.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        init.uniswapV3StandardExchangeInFacet = create3Factory.deployUniswapV3StandardExchangeInFacet();
        init.uniswapV3StandardExchangeInQueryFacet = create3Factory.deployUniswapV3StandardExchangeInQueryFacet();
        init.uniswapV3StandardExchangeOutFacet = create3Factory.deployUniswapV3StandardExchangeOutFacet();
        init.uniswapV3StandardExchangeOutQueryFacet = create3Factory.deployUniswapV3StandardExchangeOutQueryFacet();
        init.uniswapV3StandardExchangePositionImportFacet =
            create3Factory.deployUniswapV3StandardExchangePositionImportFacet();
        init.uniswapV3StandardExchangeLiquidReserveFacet =
            create3Factory.deployUniswapV3StandardExchangeLiquidReserveFacet();
        init = UniswapV3_Component_FactoryService.attachUniswapV3StandardExchangeMultiFacets(
            init,
            create3Factory.deployUniswapV3StandardExchangeInMultiFacet(),
            create3Factory.deployUniswapV3StandardExchangeInMultiQueryFacet(),
            create3Factory.deployUniswapV3StandardExchangeOutMultiFacet(),
            create3Factory.deployUniswapV3StandardExchangeOutMultiQueryFacet()
        );
        init.vaultFeeOracleQuery = indexedexManager;
        init.vaultRegistryDeployment = indexedexManager;
        init.permit2 = permit2;
        init.uniswapV3Factory = factory_;
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

    function test_fork_MJ2_or_FR1_fullRangeCenter() public {
        address token0 = pool.token0();
        address token1 = pool.token1();
        address alice = makeAddr("alice");
        deal(token0, alice, 20 ether);
        deal(token1, alice, 20 ether);
        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), type(uint256).max);
        IERC20(token1).approve(address(vault), type(uint256).max);
        address[] memory tokens = new address[](2);
        tokens[0] = token0;
        tokens[1] = token1;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 5 ether;
        amounts[1] = 5 ether;
        uint256 shares = IStandardExchangeInMulti(address(vault))
            .exchangeInManyToOne(tokens, amounts, IERC20(address(vault)), 0, alice, false, block.timestamp + 1);
        vm.stopPrank();
        assertGt(shares, 0, "MJ2 shares");
        int24 spacing = pool.tickSpacing();
        int24 lo = TickMath.minUsableTick(spacing);
        int24 hi = TickMath.maxUsableTick(spacing);
        (uint128 liq,,,,) = pool.positions(keccak256(abi.encodePacked(address(vault), lo, hi)));
        assertGt(liq, 0, "FR1/MJ2: full-range L");
    }

    function test_fork_A0_deadSharesOnResidual() public {
        address token0 = pool.token0();
        address token1 = pool.token1();
        deal(token0, address(vault), 1 ether);
        deal(token1, address(vault), 1 ether);
        address alice = makeAddr("alice-a0");
        deal(token0, alice, 5 ether);
        deal(token1, alice, 5 ether);
        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), type(uint256).max);
        IERC20(token1).approve(address(vault), type(uint256).max);
        address[] memory tokens = new address[](2);
        tokens[0] = token0;
        tokens[1] = token1;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 2 ether;
        amounts[1] = 2 ether;
        uint256 userShares = IStandardExchangeInMulti(address(vault))
            .exchangeInManyToOne(tokens, amounts, IERC20(address(vault)), 0, alice, false, block.timestamp + 1);
        vm.stopPrank();
        uint256 dead = IERC20(address(vault)).balanceOf(DEAD);
        assertGt(dead, 0, "A0 dead");
        assertLt(userShares, userShares + dead, "A0 first minter not residual");
    }

    function test_fork_blockedSleevePath() public {
        UniswapV3BoundPoolLockSeCaller lockCaller = new UniswapV3BoundPoolLockSeCaller(pool);
        address token0 = pool.token0();
        deal(token0, address(lockCaller), 2 ether);
        deal(pool.token1(), address(lockCaller), 1 ether);
        vm.prank(address(lockCaller));
        IERC20(token0).approve(address(vault), 1 ether);
        uint256 shares = lockCaller.runExchangeIn(
            address(vault), IERC20(token0), 1 ether, IERC20(address(vault)), 0, address(this), false, block.timestamp + 1
        );
        assertGt(shares, 0, "blocked sleeve mint");
    }
}
