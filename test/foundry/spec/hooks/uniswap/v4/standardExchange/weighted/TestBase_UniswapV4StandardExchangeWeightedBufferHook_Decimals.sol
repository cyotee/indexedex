// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IAllowanceTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";

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
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookTestDeployLib as DeployLib
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTestDeployLib.sol";
import {HookPkgArgsDecimalsLib} from "contracts/test/libs/HookPkgArgsDecimalsLib.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookPairPoolLib.sol";

/**
 * @title TestBase_UniswapV4StandardExchangeWeightedBufferHook_Decimals
 * @notice Combo/book underlyings via `MintableERC20Decimals`. Hook LP and SE `vaultShare` stay 18.
 * @dev Does not call gold setUp (18-dec SimpleMintableERC20). pairToken constructed first; after
 *      address sort PkgArgs order may permute. Wrappers override `_pairDecimals`/`_rateDecimals`
 *      or `_bookDec`. Default n=2: lowest address is SE-buffered, other raw.
 */
abstract contract TestBase_UniswapV4StandardExchangeWeightedBufferHook_Decimals is
    TestBase_ERC4626StandardExchange
{
    using BetterEfficientHashLib for bytes;
    using HookFactoryService for ICreate3FactoryProxy;

    uint256 internal constant WAD = 1e18;
    address internal constant PERMIT2_ADDR = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    MintableERC20Decimals internal token0;
    MintableERC20Decimals internal token1;
    MintableERC20Decimals internal token2;
    MintableERC20Decimals internal token3;

    SimpleYieldERC4626 internal vault0;
    SimpleYieldERC4626 internal vault1;
    SimpleYieldERC4626 internal vault2;
    SimpleYieldERC4626 internal vault3;

    address internal se0;
    address internal se1;
    address internal se2;
    address internal se3;

    IPoolManager internal pm;
    IUniswapV4HookDiamondPackageCallBackFactory internal hookFactory;
    IUniswapV4StandardExchangeWeightedBufferHookPackage internal hookPkg;
    address internal hook;
    IUniswapV4StandardExchangeWeightedBufferHook internal weighted;
    WrapperExactOutRouter internal swapRouter;
    PoolKey internal poolKey01;

    address internal user = address(0xBEEF);
    address internal feeRecipient;

    function _pairDecimals() internal pure virtual returns (uint8) {
        return 18;
    }

    function _rateDecimals() internal pure virtual returns (uint8) {
        return 18;
    }

    /// @notice Book leg `i` (construction order: 0 = pairToken). Remaining 18 unless overridden.
    function _bookDec(uint256 i) internal pure virtual returns (uint8) {
        if (i == 0) return _pairDecimals();
        if (i == 1) return _rateDecimals();
        return 18;
    }

    function _raw(MintableERC20Decimals t, uint256 human) internal view returns (uint256) {
        return human * (10 ** uint256(t.decimals()));
    }

    function _u(uint256 i, uint256 human) internal view returns (uint256) {
        return human * (10 ** uint256(MintableERC20Decimals(weighted.token(i)).decimals()));
    }

    /// @notice 0.01% + 10 wei slack for mixed-decimal swap routes.
    function _weiSlack(uint256 v) internal pure returns (uint256) {
        return v / 10_000 + 10;
    }

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        feeRecipient = address(feeCollector);

        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        pm = IPoolManager(address(new PoolManager(address(this))));

        (hookFactory, hookPkg) = DeployLib.deployFactoryAndPackage(
            create3Factory,
            owner,
            address(indexedexManager),
            erc20Facet,
            erc5267Facet,
            erc2612Facet,
            multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet,
            multiStepOwnableFacet
        );
        vm.prank(owner);
        IVaultRegistryDeployment(address(indexedexManager)).setHookDiamondPackageFactory(address(hookFactory));

        swapRouter = new WrapperExactOutRouter(pm);
    }

    function _wrapSe(MintableERC20Decimals t) internal returns (SimpleYieldERC4626 vault, address se) {
        vault = new SimpleYieldERC4626(t);
        se = _deployERC4626SE(address(vault));
    }

    function _sortTwo(MintableERC20Decimals a, MintableERC20Decimals b)
        internal
        pure
        returns (MintableERC20Decimals, MintableERC20Decimals)
    {
        return address(a) < address(b) ? (a, b) : (b, a);
    }

    function _sortAddrs(address[] memory toks) internal pure {
        uint256 n = toks.length;
        for (uint256 i; i < n; ++i) {
            for (uint256 j; j + 1 < n; ++j) {
                if (toks[j] > toks[j + 1]) (toks[j], toks[j + 1]) = (toks[j + 1], toks[j]);
            }
        }
    }

    function _equalWeights(uint256 n) internal pure returns (uint256[] memory w) {
        w = new uint256[](n);
        uint256 sum;
        for (uint256 i; i < n; ++i) {
            if (i + 1 == n) w[i] = WAD - sum;
            else w[i] = WAD / n;
            sum += w[i];
        }
    }

    function _fundAndApproveDec(address hook_, address[] memory tokens) internal {
        for (uint256 i; i < tokens.length; ++i) {
            MintableERC20Decimals t = MintableERC20Decimals(tokens[i]);
            t.mint(user, 1_000_000_000 * (10 ** uint256(t.decimals())));
            vm.startPrank(user);
            t.approve(hook_, type(uint256).max);
            t.approve(address(swapRouter), type(uint256).max);
            t.approve(PERMIT2_ADDR, type(uint256).max);
            IAllowanceTransfer(PERMIT2_ADDR).approve(
                address(t), hook_, type(uint160).max, type(uint48).max
            );
            vm.stopPrank();
        }
    }

    function _fundAndApprove(MintableERC20Decimals t) internal {
        t.mint(user, 1_000_000_000 * (10 ** uint256(t.decimals())));
        vm.startPrank(user);
        t.approve(hook, type(uint256).max);
        t.approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    /// @notice n=2: pairToken constructed first at `_pairDecimals()`, rate at `_rateDecimals()`.
    ///         After sort, lowest address is SE-buffered (gold default).
    function _deployN2Combo()
        internal
        returns (address hook_, MintableERC20Decimals t0, MintableERC20Decimals t1)
    {
        MintableERC20Decimals pair_ = new MintableERC20Decimals("Pair", "PAIR", _pairDecimals());
        MintableERC20Decimals rate_ = new MintableERC20Decimals("Rate", "RATE", _rateDecimals());
        (t0, t1) = _sortTwo(pair_, rate_);
        (vault0, se0) = _wrapSe(t0);
        (vault1, se1) = _wrapSe(t1);

        address[] memory toks = new address[](2);
        toks[0] = address(t0);
        toks[1] = address(t1);
        uint256[] memory w = new uint256[](2);
        w[0] = 0.5e18;
        w[1] = 0.5e18;
        address[] memory ses = new address[](2);
        ses[0] = se0;
        ses[1] = t1.decimals() == 18 ? address(0) : se1;
        address[] memory rps = new address[](2);
        _deployHookWithArgs(_pkgArgs(toks, w, ses, rps));
        _fundAndApproveDec(hook, toks);

        token0 = t0;
        token1 = t1;
        hook_ = hook;
    }

    /// @notice n∈[2,8] live book. n=4 all-SE (gold `_argsN(4,true)`); otherwise SE on sorted index 0.
    function _deployNn(uint256 n)
        internal
        returns (address hook_, MintableERC20Decimals[] memory toks)
    {
        require(n >= 2 && n <= 8, "n");
        MintableERC20Decimals[] memory constructed = new MintableERC20Decimals[](n);
        address[] memory seByConstruction = new address[](n);
        SimpleYieldERC4626[] memory vaultByConstruction = new SimpleYieldERC4626[](n);
        address[] memory tokens = new address[](n);
        for (uint256 i; i < n; ++i) {
            constructed[i] = new MintableERC20Decimals(
                string(abi.encodePacked("T", vm.toString(i))),
                string(abi.encodePacked("T", vm.toString(i))),
                _bookDec(i)
            );
            tokens[i] = address(constructed[i]);
            (vaultByConstruction[i], seByConstruction[i]) = _wrapSe(constructed[i]);
        }
        _sortAddrs(tokens);

        toks = new MintableERC20Decimals[](n);
        address[] memory sesSorted = new address[](n);
        SimpleYieldERC4626[] memory vaultsSorted = new SimpleYieldERC4626[](n);
        for (uint256 i; i < n; ++i) {
            toks[i] = MintableERC20Decimals(tokens[i]);
            for (uint256 k; k < n; ++k) {
                if (address(constructed[k]) == tokens[i]) {
                    sesSorted[i] = seByConstruction[k];
                    vaultsSorted[i] = vaultByConstruction[k];
                    break;
                }
            }
        }

        uint256[] memory weights = _equalWeights(n);

        address[] memory boundSe = new address[](n);
        boundSe[0] = sesSorted[0];
        for (uint256 i; i < n; ++i) {
            if (n == 4 || toks[i].decimals() != 18) boundSe[i] = sesSorted[i];
        }
        address[] memory rps = new address[](n);
        _deployHookWithArgs(_pkgArgs(tokens, weights, boundSe, rps));
        _fundAndApproveDec(hook, tokens);

        token0 = toks[0];
        vault0 = vaultsSorted[0];
        se0 = sesSorted[0];
        token1 = toks[1];
        vault1 = vaultsSorted[1];
        se1 = sesSorted[1];
        if (n >= 3) {
            token2 = toks[2];
            vault2 = vaultsSorted[2];
            se2 = sesSorted[2];
        }
        if (n >= 4) {
            token3 = toks[3];
            vault3 = vaultsSorted[3];
            se3 = sesSorted[3];
        }
        hook_ = hook;
    }

    function _deployHookWithArgs(IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgArgs memory args)
        internal
    {
        hook = DeployLib.deployHookInstance(hookFactory, hookPkg, args);
        _ensureProductDoorsAndFinalize(hook, args.tokens);
        weighted = IUniswapV4StandardExchangeWeightedBufferHook(hook);
        poolKey01 = PairPoolLib.pairKey(
            args.tokens[0], args.tokens.length > 1 ? args.tokens[1] : args.tokens[0], 1, IHooks(hook)
        );
        _setUsageFee(0);
        _setDexFee(0);
    }

    function _ensureProductDoorsAndFinalize(address hook_, address[] memory tokens_) internal {
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(hook_);
        uint256 n = tokens_.length;
        for (uint256 i; i < n; ++i) {
            for (uint256 j = i + 1; j < n; ++j) {
                init.deployPair(tokens_[i], tokens_[j]);
            }
        }
        bool ok = init.finalizeInitialization();
        require(ok, "finalize");
    }

    function _registry() internal view returns (IVaultRegistryVaultQuery) {
        return IVaultRegistryVaultQuery(address(indexedexManager));
    }

    function _pkgOwnerOnlyLiquidity() internal view virtual returns (bool) {
        return false;
    }

    function _pkgOwner() internal view virtual returns (address) {
        return owner;
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

    function _firstMintEqualHuman(uint256 human) internal returns (uint256 shares) {
        uint256 n = weighted.numTokens();
        uint256[] memory amounts = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            amounts[i] = _u(i, human);
        }
        vm.prank(user);
        (shares,) = weighted.joinProportional(amounts, user, 0, block.timestamp + 1 days);
    }

    function _joinFull(MintableERC20Decimals[] memory toks, uint256 human) internal returns (uint256 shares) {
        uint256 n = toks.length;
        uint256[] memory amounts = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            amounts[i] = _raw(toks[i], human);
        }
        vm.prank(user);
        (shares,) = weighted.joinProportional(amounts, user, 0, block.timestamp + 1 days);
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
        a.tokenDecimals = HookPkgArgsDecimalsLib.tokenDecimals(a.tokens);
        a.seDecimals = HookPkgArgsDecimalsLib.seDecimals(a.standardExchanges);
        a.ownerOnlyLiquidity = _pkgOwnerOnlyLiquidity();
        a.owner = _pkgOwner();
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
}
