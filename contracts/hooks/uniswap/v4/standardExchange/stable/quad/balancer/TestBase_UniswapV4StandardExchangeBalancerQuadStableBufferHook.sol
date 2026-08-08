// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {RateProviderMock} from "contracts/test/balancer/v3/RateProviderMock.sol";

import {
    IUniswapV4HookDiamondPackageCallBackFactory
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    UniswapV4HookDiamondPackageCallBackFactory_FactoryService as HookFactoryService
} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol";
import {
    IUniswapV4StandardExchangeBalancerQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
import {
    IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_FactoryService.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHookTestDeployLib as DeployLib
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookTestDeployLib.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookPairPoolLib.sol";

/**
 * @title TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook
 * @notice Package path: ERC-4626 SE + hook factory + registry deployHookVault.
 * @dev Default: 4 tokens, SE on leg 0, baseAmp=100 (A'=baseAmp*1e3 Balancer). Matrix helpers for 1–4 SE.
 */
abstract contract TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook is TestBase_ERC4626StandardExchange {
    using BetterEfficientHashLib for bytes;
    using HookFactoryService for ICreate3FactoryProxy;

    uint256 internal constant WAD = 1e18;
    uint256 internal constant FUND = 1_000_000 ether;
    uint256 internal constant DEFAULT_BASE_AMP = 100;
    address internal constant PERMIT2_ADDR = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    SimpleMintableERC20 internal token0;
    SimpleMintableERC20 internal token1;
    SimpleMintableERC20 internal token2;
    SimpleMintableERC20 internal token3;
    SimpleMintableERC20 internal tokenA;
    SimpleMintableERC20 internal tokenB;

    SimpleYieldERC4626 internal vault0;
    SimpleYieldERC4626 internal vault1;
    SimpleYieldERC4626 internal vault2;
    SimpleYieldERC4626 internal vault3;

    address internal se0;
    address internal se1;
    address internal se2;
    address internal se3;
    address internal seA;

    IPoolManager internal pm;
    IUniswapV4HookDiamondPackageCallBackFactory internal hookFactory;
    IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage internal hookPkg;
    address internal hook;
    IUniswapV4StandardExchangeBalancerQuadStableBufferHook internal quad;
    // alias used by some tests copied from weighted
    IUniswapV4StandardExchangeBalancerQuadStableBufferHook internal weighted;
    WrapperExactOutRouter internal swapRouter;
    PoolKey internal poolKey01;

    address internal user = address(0xBEEF);
    address internal feeRecipient;

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        feeRecipient = address(feeCollector);

        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        SimpleMintableERC20[4] memory raw;
        raw[0] = new SimpleMintableERC20("T0", "T0");
        raw[1] = new SimpleMintableERC20("T1", "T1");
        raw[2] = new SimpleMintableERC20("T2", "T2");
        raw[3] = new SimpleMintableERC20("T3", "T3");
        for (uint256 i; i < 4; ++i) {
            for (uint256 j = i + 1; j < 4; ++j) {
                if (address(raw[j]) < address(raw[i])) {
                    (raw[i], raw[j]) = (raw[j], raw[i]);
                }
            }
        }
        token0 = raw[0];
        token1 = raw[1];
        token2 = raw[2];
        token3 = raw[3];
        tokenA = token0;
        tokenB = token1;

        vault0 = new SimpleYieldERC4626(token0);
        vault1 = new SimpleYieldERC4626(token1);
        vault2 = new SimpleYieldERC4626(token2);
        vault3 = new SimpleYieldERC4626(token3);
        se0 = _deployERC4626SE(address(vault0));
        se1 = _deployERC4626SE(address(vault1));
        se2 = _deployERC4626SE(address(vault2));
        se3 = _deployERC4626SE(address(vault3));
        seA = se0;

        pm = IPoolManager(address(new PoolManager(address(this))));

        (hookFactory, hookPkg) = DeployLib.deployFactoryAndPackage(
            create3Factory,
            owner,
            address(indexedexManager),
            erc20Facet,
            erc5267Facet,
            erc2612Facet,
            multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet
        );
        vm.prank(owner);
        IVaultRegistryDeployment(address(indexedexManager)).setHookDiamondPackageFactory(address(hookFactory));

        _deployHookWithArgs(_defaultPkgArgs());

        swapRouter = new WrapperExactOutRouter(pm);
        poolKey01 = PairPoolLib.pairKey(address(token0), address(token1), 1, IHooks(hook));

        _setUsageFee(0);
        _setDexFee(0);

        _fundAndApprove(token0);
        _fundAndApprove(token1);
        _fundAndApprove(token2);
        _fundAndApprove(token3);
    }

    function _fundAndApprove(SimpleMintableERC20 t) internal {
        t.mint(user, FUND);
        vm.startPrank(user);
        t.approve(hook, type(uint256).max);
        t.approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    function _deployHookWithArgs(IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage.PkgArgs memory args)
        internal
    {
        hook = DeployLib.deployHookInstance(hookFactory, hookPkg, args);
        quad = IUniswapV4StandardExchangeBalancerQuadStableBufferHook(hook);
        weighted = quad;
        poolKey01 = PairPoolLib.pairKey(args.tokens[0], args.tokens[1], 1, IHooks(hook));
    }

    /// @notice Default: 4 tokens, SE on token0, baseAmp=100.
    function _defaultPkgArgs()
        internal
        view
        returns (IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage.PkgArgs memory)
    {
        address[4] memory toks;
        toks[0] = address(token0);
        toks[1] = address(token1);
        toks[2] = address(token2);
        toks[3] = address(token3);
        address[4] memory ses;
        ses[0] = se0;
        address[4] memory rps;
        return IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(indexedexManager),
            tokens: toks,
            standardExchanges: ses,
            rateProviders: rps,
            baseAmp: DEFAULT_BASE_AMP
        });
    }

    function _firstMintEqual(uint256 amountEach) internal returns (uint256 shares) {
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = amountEach;
        amounts[1] = amountEach;
        amounts[2] = amountEach;
        amounts[3] = amountEach;
        vm.prank(user);
        (shares,) = quad.joinProportional(amounts, user, 0, block.timestamp + 1 days);
    }

    function _seedFullBook(uint256 amountEach) internal returns (uint256 shares) {
        return _firstMintEqual(amountEach);
    }

    function _assertAllDoorsLive() internal view {
        address[] memory toks = quad.tokens();
        assertEq(toks.length, 4);
        assertEq(quad.pairDoorCount(), 6);
        for (uint256 i; i < 4; ++i) {
            for (uint256 j = i + 1; j < 4; ++j) {
                PoolKey memory key = PairPoolLib.pairKey(toks[i], toks[j], 1, IHooks(hook));
                assertTrue(PairPoolLib.isPoolLive(pm, key), "door live");
            }
        }
    }

    function _swapExactIn(address tokenIn, address tokenOut, uint256 amountIn) internal {
        bool zeroForOne = tokenIn < tokenOut;
        PoolKey memory key = PairPoolLib.pairKey(tokenIn, tokenOut, 1, IHooks(hook));
        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: -int256(amountIn),
            sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
        });
        vm.prank(user);
        swapRouter.swapExactIn(key, params, "");
    }

    function _swapExactOut(address tokenIn, address tokenOut, uint256 amountOut) internal {
        bool zeroForOne = tokenIn < tokenOut;
        PoolKey memory key = PairPoolLib.pairKey(tokenIn, tokenOut, 1, IHooks(hook));
        // Bound maxAmountIn to a real preview (type(uint256).max would transferFrom entire max).
        uint256 previewIn = IUniswapV4StandardExchangeBalancerQuadStableBufferHook(hook).previewSwapExactOut(
            tokenIn, tokenOut, amountOut
        );
        uint256 maxIn = previewIn + (previewIn / 10) + 1 ether; // slack for fee/rounding
        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: int256(amountOut),
            sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
        });
        vm.prank(user);
        swapRouter.swapExactOut(key, params, maxIn, "");
    }

    /// @notice SE matrix: `seCount` first legs buffered (1–4), rest raw.
    function _argsSeCount(uint8 seCount)
        internal
        view
        returns (IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage.PkgArgs memory a)
    {
        require(seCount >= 1 && seCount <= 4, "seCount");
        a.poolManager = address(pm);
        a.feeOracle = address(indexedexManager);
        a.baseAmp = DEFAULT_BASE_AMP;
        a.tokens[0] = address(token0);
        a.tokens[1] = address(token1);
        a.tokens[2] = address(token2);
        a.tokens[3] = address(token3);
        address[4] memory sesAll = [se0, se1, se2, se3];
        for (uint8 i; i < seCount; ++i) {
            a.standardExchanges[i] = sesAll[i];
        }
    }

    function _pkgArgs(
        address[4] memory toks,
        address[4] memory ses,
        address[4] memory rps,
        uint256 baseAmp
    ) internal view returns (IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage.PkgArgs memory a) {
        a.poolManager = address(pm);
        a.feeOracle = address(indexedexManager);
        a.tokens = toks;
        a.standardExchanges = ses;
        a.rateProviders = rps;
        a.baseAmp = baseAmp;
    }

    function _setDexFee(uint256 feeWad) internal {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setVaultDexSwapFee(hook, feeWad);
    }

    function _setUsageFee(uint256 feeWad) internal {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(hook, feeWad);
    }

    function _ensureFeeTo() internal {
        address ft = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        if (ft == address(0)) {
            vm.prank(owner);
            IVaultFeeOracleManager(address(indexedexManager)).setFeeTo(IFeeCollectorProxy(address(feeCollector)));
        }
    }

    function _reserveOf(address token) internal view returns (uint256) {
        return IBasicVault(hook).reserveOfToken(token);
    }

    function _smokeDeployMintSwapSingle() internal {
        _assertAllDoorsLive();
        _firstMintEqual(100 ether);
        _swapExactIn(address(token0), address(token1), 1 ether);
        vm.prank(user);
        quad.depositSingle(address(token1), 5 ether, user, 0, block.timestamp + 1 hours);
    }
}
