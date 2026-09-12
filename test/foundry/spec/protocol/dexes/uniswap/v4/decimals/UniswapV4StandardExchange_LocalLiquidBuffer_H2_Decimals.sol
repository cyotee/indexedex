// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IFacetRegistry} from "@crane/contracts/interfaces/IFacetRegistry.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC8109Introspection} from "@crane/contracts/interfaces/IERC8109Introspection.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {HookPkgArgsDecimalsLib} from "contracts/test/libs/HookPkgArgsDecimalsLib.sol";

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IUniswapV4StandardExchangeLiquidReserve} from
    "contracts/protocols/dexes/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserve.sol";
import {IUniswapV4HookStagedPairInit} from
    "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {IUniswapV4HookDiamondPackageCallBackFactory} from
    "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {UniswapV4HookDiamondPackageCallBackFactory_FactoryService as HookFactoryService} from
    "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol";
import {IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook} from
    "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage} from
    "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as PkgFactory} from
    "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {UniswapV4SeDecimalsHelpers} from
    "test/foundry/spec/protocol/dexes/uniswap/v4/decimals/UniswapV4SeDecimalsHelpers.sol";
import {UniswapV4LiquiditySeeder_ProDexUniV4} from
    "test/foundry/spec/protocol/dexes/uniswap/v4/decimals/harness/UniswapV4SeDecimalsPoolOps.sol";

/**
 * @title UniswapV4StandardExchange_LocalLiquidBuffer_H2_Decimals
 * @notice H2 real Single SE Buffer CP hook mid-swap into V4 SE. pairToken = tokenA. vaultShare stays 18.
 *         seOtherToken = tokenB. rawToken stays 18.
 */
abstract contract UniswapV4StandardExchange_LocalLiquidBuffer_H2_Decimals is UniswapV4SeDecimalsHelpers {
    using BetterEfficientHashLib for bytes;
    using HookFactoryService for ICreate3FactoryProxy;

    address internal constant PERMIT2_ADDR = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    MintableERC20Decimals internal pairToken;
    MintableERC20Decimals internal seOtherToken;
    MintableERC20Decimals internal rawToken;

    IStandardExchangeProxy internal seVault;
    IUniswapV4StandardExchangeLiquidReserve internal liquid;
    PoolKey internal sePoolKey;
    UniswapV4LiquiditySeeder_ProDexUniV4 internal seeder;

    IUniswapV4HookDiamondPackageCallBackFactory internal hookFactory;
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage internal hookPkg;
    address internal hook;
    IHook internal single;
    PoolKey internal hookPoolKey;
    WrapperExactOutRouter internal swapRouter;
    address internal user = address(0xBEEF);

    function setUp() public virtual override {
        super.setUp();

        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        pairToken = new MintableERC20Decimals("Pair", "PAIR", _tokenADecimals());
        seOtherToken = new MintableERC20Decimals("Other", "OTH", _tokenBDecimals());
        rawToken = new MintableERC20Decimals("Raw", "RAW", 18);

        sePoolKey = _buildPoolKey(address(pairToken), address(seOtherToken));
        uint160 seSqrt = _oneToOneHumanSqrtPrice(
            Currency.unwrap(sePoolKey.currency0), Currency.unwrap(sePoolKey.currency1)
        );
        poolManager.initialize(sePoolKey, seSqrt);
        seeder = new UniswapV4LiquiditySeeder_ProDexUniV4(poolManager);
        pairToken.mint(address(seeder), _uA(1_000_000));
        seOtherToken.mint(address(seeder), _uB(1_000_000));
        {
            (int24 tickLower, int24 tickUpper) = _seedTicksAround(seSqrt, sePoolKey.tickSpacing);
            uint128 liq = LiquidityAmounts.getLiquidityForAmounts(
                seSqrt,
                TickMath.getSqrtPriceAtTick(tickLower),
                TickMath.getSqrtPriceAtTick(tickUpper),
                _uOf(Currency.unwrap(sePoolKey.currency0), 100_000),
                _uOf(Currency.unwrap(sePoolKey.currency1), 100_000)
            );
            seeder.addLiquidity(sePoolKey, tickLower, tickUpper, liq);
        }

        seVault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(sePoolKey));
        liquid = IUniswapV4StandardExchangeLiquidReserve(address(seVault));
        assertTrue(liquid.canOpenPoolManagerUnlock(), "SE idle at deploy");
        _activateUnderlyingSe();

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
                depositSingleFacet: PkgFactory.deployDepositSingleFacet(create3Factory),
                depositPreviewFacet: PkgFactory.deployDepositPreviewFacet(create3Factory),
                withdrawFacet: withdrawFacet,
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
                multiStepOwnableFacet: multiStepOwnableFacet
            }),
            abi.encode(type(IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage).name, "v4-h2-dec")._hash()
        );

        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args =
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs({
                poolManager: address(poolManager),
                feeOracle: address(indexedexManager),
                standardExchange: address(seVault),
                pairToken: address(pairToken),
                rawToken: address(rawToken),
                pairTokenDecimals: HookPkgArgsDecimalsLib.tokenDec(address(pairToken)),
                rawTokenDecimals: address(rawToken).code.length == 0 ? uint8(18) : HookPkgArgsDecimalsLib.tokenDec(address(rawToken)),
                ownerOnlyLiquidity: false,
                owner: owner
            });
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        hook = PkgFactory.deployHook(hookPkg, args, mineNonce);
        single = IHook(hook);
        {
            IUniswapV4HookStagedPairInit staged = IUniswapV4HookStagedPairInit(hook);
            hookPoolKey = staged.deployPair(address(rawToken), address(pairToken));
            require(staged.finalizeInitialization(), "finalize");
        }
        assertEq(single.standardExchange(), address(seVault), "hook bound to V4 SE");

        rawToken.mint(user, 1_000_000 ether);
        pairToken.mint(user, _uA(1_000_000));
        vm.startPrank(user);
        rawToken.approve(hook, type(uint256).max);
        pairToken.approve(hook, type(uint256).max);
        vm.stopPrank();

        uint256 a0 = _amountForCurrency(single.currency0(), 200 ether, _uA(200));
        uint256 a1 = _amountForCurrency(single.currency1(), 200 ether, _uA(200));
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

    function test_H2_realBufferHook_midSwap_buffersIntoV4Se() public {
        assertEq(single.standardExchange(), address(seVault), "SE binding");
        assertTrue(liquid.canOpenPoolManagerUnlock(), "SE free before outer swap");

        uint256 seSupplyBefore = seVault.totalSupply();
        uint256 seSharesHookBefore = seVault.balanceOf(hook);
        uint256 amountIn = _uA(5);

        bool pairIsCurrency0 = single.currency0() == address(pairToken);
        bool zeroForOne = pairIsCurrency0;
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
        assertTrue(liquid.canOpenPoolManagerUnlock(), "PM idle after swap");
    }

    function _activateUnderlyingSe() internal {
        pairToken.mint(address(this), _uA(100));
        seOtherToken.mint(address(this), _uB(100));
        pairToken.approve(address(seVault), _uA(100));
        seOtherToken.approve(address(seVault), _uB(100));
        address[] memory tokens = new address[](2);
        tokens[0] = Currency.unwrap(sePoolKey.currency0);
        tokens[1] = Currency.unwrap(sePoolKey.currency1);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = tokens[0] == address(pairToken) ? _uA(100) : _uB(100);
        amounts[1] = tokens[1] == address(pairToken) ? _uA(100) : _uB(100);
        uint256 shares = IStandardExchangeInMulti(address(seVault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(seVault)), 0, address(this), false, block.timestamp + 1 hours
        );
        assertGt(shares, 0, "two-token SE activation before hook liquidity");
    }

    function _amountForCurrency(address currency, uint256 amtRaw, uint256 amtPair) internal view returns (uint256) {
        if (currency == address(rawToken)) return amtRaw;
        if (currency == address(pairToken)) return amtPair;
        revert("unknown currency");
    }
}
