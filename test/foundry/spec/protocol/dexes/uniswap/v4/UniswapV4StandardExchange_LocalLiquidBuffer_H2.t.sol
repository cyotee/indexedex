// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IFacetRegistry} from "@crane/contracts/interfaces/IFacetRegistry.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC8109Introspection} from "@crane/contracts/interfaces/IERC8109Introspection.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    TestBase_UniswapV4StandardExchange
} from "contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol";
import {
    IUniswapV4StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserve.sol";
import {
    IUniswapV4HookDiamondPackageCallBackFactory
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    UniswapV4HookDiamondPackageCallBackFactory_FactoryService as HookFactoryService
} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";

/// @dev Seed external liquidity on the V4 SE underlying pool (not the hook pool).
contract H2Seeder is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;

    IPoolManager internal immutable poolManager;

    constructor(IPoolManager poolManager_) {
        poolManager = poolManager_;
    }

    function addLiquidity(PoolKey memory poolKey, int24 tickLower, int24 tickUpper, uint128 liquidity) external {
        poolManager.unlock(abi.encode(poolKey, tickLower, tickUpper, liquidity));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(poolManager), "not pm");
        (PoolKey memory poolKey, int24 tickLower, int24 tickUpper, uint128 liquidity) =
            abi.decode(data, (PoolKey, int24, int24, uint128));
        (BalanceDelta callerDelta,) = poolManager.modifyLiquidity(
            poolKey,
            ModifyLiquidityParams({
                tickLower: tickLower, tickUpper: tickUpper, liquidityDelta: int256(uint256(liquidity)), salt: bytes32(0)
            }),
            bytes("")
        );
        _settle(poolKey.currency0, callerDelta.amount0());
        _settle(poolKey.currency1, callerDelta.amount1());
        return abi.encode(callerDelta);
    }

    function _settle(Currency currency, int128 delta) internal {
        if (delta < 0) {
            uint256 amount = uint128(-delta);
            poolManager.sync(currency);
            IERC20(Currency.unwrap(currency)).transfer(address(poolManager), amount);
            poolManager.settle();
        } else if (delta > 0) {
            poolManager.take(currency, address(this), uint128(delta));
        }
    }
}

/**
 * @title UniswapV4StandardExchange_LocalLiquidBuffer_H2
 * @notice PRD D19 / plan §8 H2: real Single SE Buffer CP hook mid-swap buffers into this V4 SE
 *         while PoolManager is unlocked; outer swap completes and SE shares increase.
 */
contract UniswapV4StandardExchange_LocalLiquidBuffer_H2 is TestBase_UniswapV4StandardExchange {
    using BetterEfficientHashLib for bytes;
    using HookFactoryService for ICreate3FactoryProxy;

    address internal constant PERMIT2_ADDR = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    uint160 internal constant SQRT_PRICE_1_1 = 79228162514264337593543950336;

    ERC20PermitMintableStub internal pairToken;
    ERC20PermitMintableStub internal seOtherToken;
    ERC20PermitMintableStub internal rawToken;

    IStandardExchangeProxy internal seVault;
    IUniswapV4StandardExchangeLiquidReserve internal liquid;
    PoolKey internal sePoolKey;
    H2Seeder internal seeder;

    IUniswapV4HookDiamondPackageCallBackFactory internal hookFactory;
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage internal hookPkg;
    address internal hook;
    IHook internal single;
    PoolKey internal hookPoolKey;
    WrapperExactOutRouter internal swapRouter;
    address internal user = address(0xBEEF);

    function setUp() public override {
        super.setUp();

        // Product PullLib uses the Uniswap well-known Permit2 address; etch hermetic bytecode there.
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        pairToken = new ERC20PermitMintableStub("Pair", "PAIR", 18, address(this), 0);
        seOtherToken = new ERC20PermitMintableStub("Other", "OTH", 18, address(this), 0);
        rawToken = new ERC20PermitMintableStub("Raw", "RAW", 18, address(this), 0);

        // --- V4 SE underlying pool (pair + other) on the same PoolManager ---
        sePoolKey = _buildPoolKey(address(pairToken), address(seOtherToken));
        poolManager.initialize(sePoolKey, TickMath.getSqrtPriceAtTick(0));
        seeder = new H2Seeder(poolManager);
        pairToken.mint(address(seeder), 1_000_000 ether);
        seOtherToken.mint(address(seeder), 1_000_000 ether);
        {
            int24 tickLower = -120;
            int24 tickUpper = 120;
            uint128 liq = LiquidityAmounts.getLiquidityForAmounts(
                TickMath.getSqrtPriceAtTick(0),
                TickMath.getSqrtPriceAtTick(tickLower),
                TickMath.getSqrtPriceAtTick(tickUpper),
                100_000 ether,
                100_000 ether
            );
            seeder.addLiquidity(sePoolKey, tickLower, tickUpper, liq);
        }

        seVault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(sePoolKey, 60));
        liquid = IUniswapV4StandardExchangeLiquidReserve(address(seVault));
        assertTrue(liquid.canOpenPoolManagerUnlock(), "SE idle at deploy");

        // --- Real Single SE Buffer CP hook package with SE = this V4 vault ---
        IFacet hookFlagsFacet = HookFactoryService.deployUniswapV4HookFlagsFacet(create3Factory);
        IFacetRegistry facetReg = IFacetRegistry(address(create3Factory));
        hookFactory = HookFactoryService.deployUniswapV4HookDiamondPackageCallBackFactory(
            create3Factory,
            IUniswapV4HookDiamondPackageCallBackFactory.InitArgs({
                erc165Facet: facetReg.canonicalFacet(type(IERC165).interfaceId),
                diamondLoupeFacet: facetReg.canonicalFacet(type(IDiamondLoupe).interfaceId),
                erc8109IntrospectionFacet: facetReg.canonicalFacet(type(IERC8109Introspection).interfaceId),
                postDeployHookFacet: facetReg.canonicalFacet(type(IPostDeployAccountHook).interfaceId),
                hookFlagsFacet: hookFlagsFacet
            })
        );
        vm.prank(owner);
        IVaultRegistryDeployment(address(indexedexManager)).setHookDiamondPackageFactory(address(hookFactory));

        IFacet seFacet = PkgFactory.deploySeFacet(create3Factory);
        IFacet depositFacet = PkgFactory.deployDepositFacet(create3Factory);
        IFacet withdrawFacet = PkgFactory.deployWithdrawFacet(create3Factory);
        hookPkg = PkgFactory.deployPackage(
            IVaultRegistryDeployment(address(indexedexManager)),
            owner,
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgInit({
                vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
                vaultFeeOracleQuery: IVaultFeeOracleQuery(address(indexedexManager)),
                seFacet: seFacet,
                depositFacet: depositFacet,
                withdrawFacet: withdrawFacet,
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet: multiAssetStandardVaultFacet
            }),
            abi.encode(type(IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage).name, "v4-h2")._hash()
        );

        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args =
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs({
                poolManager: address(poolManager),
                feeOracle: address(indexedexManager),
                standardExchange: address(seVault),
                pairToken: address(pairToken),
                rawToken: address(rawToken)
            });
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        hook = PkgFactory.deployHook(hookPkg, args, mineNonce);
        single = IHook(hook);
        assertEq(single.standardExchange(), address(seVault), "hook bound to V4 SE");

        // Hook pool (raw ↔ pair) on same PM; seed live book via proportional deposit (buffers pair → V4 SE).
        hookPoolKey = PoolKey({
            currency0: Currency.wrap(single.currency0()),
            currency1: Currency.wrap(single.currency1()),
            fee: 0,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });
        poolManager.initialize(hookPoolKey, SQRT_PRICE_1_1);

        rawToken.mint(user, 1_000_000 ether);
        pairToken.mint(user, 1_000_000 ether);
        vm.startPrank(user);
        rawToken.approve(hook, type(uint256).max);
        pairToken.approve(hook, type(uint256).max);
        vm.stopPrank();

        uint256 a0 = single.currency0() == address(rawToken) ? 200 ether : 200 ether;
        uint256 a1 = 200 ether;
        // deposit(amount0, amount1) expects currency order
        a0 = _amountForCurrency(single.currency0(), 200 ether, 200 ether);
        a1 = _amountForCurrency(single.currency1(), 200 ether, 200 ether);
        vm.prank(user);
        (uint256 lp,,) = single.deposit(a0, a1, user, 0, block.timestamp + 1 hours);
        assertGt(lp, 0, "hook LP seed");
        assertTrue(single.isLive(), "hook live");
        assertGt(seVault.totalSupply(), 0, "V4 SE shares from seed buffer");

        swapRouter = new WrapperExactOutRouter(poolManager);
        vm.startPrank(user);
        rawToken.approve(address(swapRouter), type(uint256).max);
        pairToken.approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    /**
     * @notice H2 DoD: pair→raw exact-in on the real buffer CP hook runs beforeSwap while PM is unlocked,
     *         buffer-last `_bufferPair` deposits into this V4 SE sleeve path; outer swap completes; SE shares ↑.
     */
    function test_H2_realBufferHook_midSwap_buffersIntoV4Se() public {
        assertEq(single.standardExchange(), address(seVault), "SE binding");
        assertTrue(liquid.canOpenPoolManagerUnlock(), "SE free before outer swap");

        uint256 seSupplyBefore = seVault.totalSupply();
        uint256 seSharesHookBefore = seVault.balanceOf(hook);
        uint256 amountIn = 5 ether;

        // Pair in → raw out: beforeSwap takes pair, quotes, then `_bufferPair` → SE.exchangeIn under outer unlock.
        bool pairIsCurrency0 = single.currency0() == address(pairToken);
        bool zeroForOne = pairIsCurrency0; // pair → raw
        address raw = address(rawToken);
        uint256 rawBefore = IERC20(raw).balanceOf(user);

        vm.prank(user);
        swapRouter.swapExactIn(
            hookPoolKey,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(amountIn),
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            ""
        );

        uint256 rawAfter = IERC20(raw).balanceOf(user);
        assertGt(rawAfter, rawBefore, "outer swap completed: user received raw");
        assertGt(seVault.totalSupply(), seSupplyBefore, "V4 SE shares increased via mid-swap buffer");
        assertGt(seVault.balanceOf(hook), seSharesHookBefore, "hook holds more SE shares after buffer-last");
        // After outer unlock ends, SE gate is free again.
        assertTrue(liquid.canOpenPoolManagerUnlock(), "PM idle after swap");
    }

    function _amountForCurrency(address currency, uint256 amtRaw, uint256 amtPair) internal view returns (uint256) {
        if (currency == address(rawToken)) return amtRaw;
        if (currency == address(pairToken)) return amtPair;
        revert("unknown currency");
    }

    function _buildPoolKey(address token0Candidate, address token1Candidate) internal pure returns (PoolKey memory) {
        (address token0, address token1) =
            token0Candidate < token1Candidate ? (token0Candidate, token1Candidate) : (token1Candidate, token0Candidate);
        return PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
    }
}
