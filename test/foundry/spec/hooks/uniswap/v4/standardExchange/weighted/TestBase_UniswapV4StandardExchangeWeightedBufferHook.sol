// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacetRegistry} from "@crane/contracts/interfaces/IFacetRegistry.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC8109Introspection} from "@crane/contracts/interfaces/IERC8109Introspection.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
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
    IUniswapV4StandardExchangeWeightedBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_FactoryService.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookTestDeployLib as DeployLib
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTestDeployLib.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookPairPoolLib.sol";

/**
 * @title TestBase_UniswapV4StandardExchangeWeightedBufferHook
 * @notice Package path: ERC-4626 SE + hook factory + registry deployHookVault.
 * @dev Default n=2: token0 SE-buffered, token1 raw. Also deploys token2/3 + se matrix for n>2 tests.
 */
abstract contract TestBase_UniswapV4StandardExchangeWeightedBufferHook is TestBase_ERC4626StandardExchange {
    using BetterEfficientHashLib for bytes;
    using HookFactoryService for ICreate3FactoryProxy;

    uint256 internal constant WAD = 1e18;
    uint256 internal constant FUND = 1_000_000 ether;
    address internal constant PERMIT2_ADDR = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    SimpleMintableERC20 internal token0;
    SimpleMintableERC20 internal token1;
    SimpleMintableERC20 internal token2;
    SimpleMintableERC20 internal token3;
    // aliases used by Deploy.t.sol
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
    IUniswapV4StandardExchangeWeightedBufferHookPackage internal hookPkg;
    address internal hook;
    IUniswapV4StandardExchangeWeightedBufferHook internal weighted;
    WrapperExactOutRouter internal swapRouter;
    PoolKey internal poolKey01;

    address internal user = address(0xBEEF);
    address internal feeRecipient;

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        feeRecipient = address(feeCollector);

        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        // Four mintable tokens, sort ascending for binding convenience
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

        // External lib: keeps concrete test contracts under via_ir stack limits
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

        // Baseline: zero dual-channel fees so preview==exec tests are bit-exact.
        // Fee suites opt-in with _setUsageFee / _setDexFee.
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

    function _deployHookWithArgs(IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgArgs memory args)
        internal
    {
        hook = DeployLib.deployHookInstance(hookFactory, hookPkg, args);
        weighted = IUniswapV4StandardExchangeWeightedBufferHook(hook);
        poolKey01 = PairPoolLib.pairKey(
            args.tokens[0], args.tokens.length > 1 ? args.tokens[1] : args.tokens[0], 1, IHooks(hook)
        );
    }

    /// @notice Default: n=2, SE on token0, equal weights.
    function _defaultPkgArgs()
        internal
        view
        returns (IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgArgs memory)
    {
        address[] memory toks = new address[](2);
        toks[0] = address(token0);
        toks[1] = address(token1);
        uint256[] memory w = new uint256[](2);
        w[0] = 0.5e18;
        w[1] = 0.5e18;
        address[] memory ses = new address[](2);
        ses[0] = se0;
        ses[1] = address(0);
        address[] memory rps = new address[](2);
        return IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(indexedexManager),
            n: 2,
            tokens: toks,
            weights: w,
            standardExchanges: ses,
            rateProviders: rps
        });
    }

    function _firstMintEqual(uint256 amountEach) internal returns (uint256 shares) {
        uint256 n = weighted.numTokens();
        uint256[] memory amounts = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            amounts[i] = amountEach;
        }
        vm.prank(user);
        (shares,) = weighted.joinProportional(amounts, user, 0, block.timestamp + 1 days);
    }

    function _seedFullBook(uint256 amountEach) internal returns (uint256 shares) {
        return _firstMintEqual(amountEach);
    }

    function _assertAllDoorsLive() internal view {
        address[] memory toks = weighted.tokens();
        uint256 n = toks.length;
        uint256 expected = (n * (n - 1)) / 2;
        assertEq(weighted.pairDoorCount(), expected);
        for (uint256 i; i < n; ++i) {
            for (uint256 j = i + 1; j < n; ++j) {
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
        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: int256(amountOut),
            sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
        });
        vm.prank(user);
        swapRouter.swapExactOut(key, params, type(uint256).max, "");
    }

    /// @notice n-token args with optional all-SE; equal weights; ≥1 SE on leg 0.
    function _argsN(uint8 n, bool allSE)
        internal
        view
        returns (IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgArgs memory a)
    {
        require(n >= 2 && n <= 4, "test n");
        a.poolManager = address(pm);
        a.feeOracle = address(indexedexManager);
        a.n = n;
        a.tokens = new address[](n);
        a.weights = new uint256[](n);
        a.standardExchanges = new address[](n);
        a.rateProviders = new address[](n);
        address[4] memory toks = [address(token0), address(token1), address(token2), address(token3)];
        address[4] memory ses = [se0, se1, se2, se3];
        uint256 wEach = WAD / n;
        uint256 sum;
        for (uint8 i; i < n; ++i) {
            a.tokens[i] = toks[i];
            a.weights[i] = (i == n - 1) ? (WAD - sum) : wEach;
            sum += a.weights[i];
            if (allSE || i == 0) a.standardExchanges[i] = ses[i];
        }
    }

    function _pkgArgs(
        address[] memory toks,
        uint256[] memory weights,
        address[] memory ses,
        address[] memory rps
    ) internal view returns (IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgArgs memory a) {
        a.poolManager = address(pm);
        a.feeOracle = address(indexedexManager);
        a.n = uint8(toks.length);
        a.tokens = toks;
        a.weights = weights;
        a.standardExchanges = ses;
        a.rateProviders = rps;
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
        // feeCollector is already feeTo on manager from IndexedexTest in normal setups
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
        weighted.depositSingle(address(token1), 5 ether, user, 0, block.timestamp + 1 hours);
    }
}
