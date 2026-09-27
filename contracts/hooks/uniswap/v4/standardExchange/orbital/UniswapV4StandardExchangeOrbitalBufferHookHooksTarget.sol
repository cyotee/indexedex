// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {
    toBeforeSwapDelta,
    BeforeSwapDelta
} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BeforeSwapDelta.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";
import {ModifyLiquidityParams, SwapParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookCommon
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookRepo.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookMath.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookClaimLib as ClaimLib
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookPairPoolLib.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookBeforeInitializeLib as BeforeInitializeLib
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookBeforeInitializeLib.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";
import {
    UniswapV4SeBufferHookLegLib
} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";
import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";

/// @title UniswapV4StandardExchangeOrbitalBufferHookHooksTarget
/// @notice Role Target for orbital buffer hook size split (Option 1a).
abstract contract UniswapV4StandardExchangeOrbitalBufferHookHooksTarget is UniswapV4StandardExchangeOrbitalBufferHookCommon, IHooks {
    using SafeERC20 for IERC20;
    using AddressSetRepo for AddressSet;

    /// @notice Fixed direct-liquidity policy selected at deployment.
    function ownerOnlyLiquidity() external view returns (bool) {
        return Repo._layout().ownerOnlyLiquidity;
    }

    function poolManager() public view returns (IPoolManager) {
        return IPoolManager(Repo._layout().poolManager);
    }


    function feeOracle() public view returns (IVaultFeeOracleQuery) {
        return IVaultFeeOracleQuery(Repo._layout().feeOracle);
    }


    function standardExchange(uint8 i) public view returns (address) {
        return Repo._seAt(Repo._layout(), i);
    }


    function rateProvider(uint8 i) public view returns (address) {
        return Repo._rpAt(Repo._layout(), i);
    }

    /// @notice D60: the configured rate providers, one per leg (address(0) on a raw leg without one).
    function rateProviders() public view returns (address[] memory rps) {
        Repo.Layout storage l = Repo._layout();
        rps = new address[](3);
        for (uint8 i; i < 3; ++i) rps[i] = Repo._rpAt(l, i);
    }

    /// @notice D60: the rate provider configured for `token`, address(0) when none or unknown token.
    function rateProvider(address token_) public view returns (address) {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < 3; ++i) {
            if (Repo._tokenAt(l, i) == token_) return Repo._rpAt(l, i);
        }
        return address(0);
    }


    function isBuffered(uint8 i) public view returns (bool) {
        return Repo._seAt(Repo._layout(), i) != address(0);
    }


    function permit2() public pure returns (address) {
        return PERMIT2;
    }


    function rawReserve(uint8 i) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address t = Repo._tokenAt(l, i);
        if (Repo._seAt(l, i) != address(0)) return 0;
        return l.reserves[t];
    }


    function seBalance(uint8 i) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address se = Repo._seAt(l, i);
        if (se == address(0)) return 0;
        return IERC20(se).balanceOf(address(this));
    }


    function seClaim(uint8 i) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address se = Repo._seAt(l, i);
        if (se == address(0)) return 0;
        // D60: the held SE reserve is valued through the leg's rate provider, never through the SE's quotes.
        return ClaimLib.effectiveNative(se, Repo._rpAt(l, i), Repo._tokenAt(l, i), 0, IERC20(se).balanceOf(address(this)));
    }


    function effectiveReserve(uint8 i) public view returns (uint256) {
        return _effectiveNativeAt(i);
    }


    function effectiveReserves() public view returns (uint256 e0, uint256 e1, uint256 e2) {
        e0 = _effectiveNativeAt(0);
        e1 = _effectiveNativeAt(1);
        e2 = _effectiveNativeAt(2);
    }





    function lSquared() public view returns (uint256) {
        return Repo._layout().L_SQUARED;
    }


    function dexSwapFee() public view returns (uint256) {
        return IVaultFeeOracleQuery(Repo._layout().feeOracle).dexSwapFeeOfVault(address(this));
    }


    function usageFee() public view returns (uint256) {
        return IVaultFeeOracleQuery(Repo._layout().feeOracle).usageFeeOfVault(address(this));
    }


    function feeTo() public view returns (address) {
        return address(IVaultFeeOracleQuery(Repo._layout().feeOracle).feeTo());
    }


    function kLast() public view returns (uint256) {
        return Repo._layout().kLast;
    }


    function kLastMode() public view returns (IUniswapV4StandardExchangeOrbitalBufferHook.KLastMode) {
        return IUniswapV4StandardExchangeOrbitalBufferHook.KLastMode(Repo._layout().kLastMode);
    }


    function pairPoolTickSpacing() public view returns (int24) {
        return Repo._layout().tickSpacing;
    }


    function pairPoolSqrtPriceX96() public view returns (uint160) {
        return Repo._layout().sqrtPriceX96;
    }


    function getHookPermissions() public pure returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: true,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }


    function beforeInitialize(address, PoolKey calldata poolKey, uint160)
        external
        view
        override
        returns (bytes4)
    {
        return BeforeInitializeLib.beforeInitialize(poolKey);
    }


    function afterInitialize(address, PoolKey calldata, uint160, int24)
        external
        pure
        override
        returns (bytes4)
    {
        revert HookNotImplemented();
    }


    function beforeAddLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        external
        view
        override
        returns (bytes4)
    {
        _onlyPoolManager();
        revert LiquidityNotAllowed();
    }


    function afterAddLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure override returns (bytes4, BalanceDelta) {
        revert HookNotImplemented();
    }


    function beforeRemoveLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        bytes calldata
    ) external view override returns (bytes4) {
        _onlyPoolManager();
        revert LiquidityNotAllowed();
    }


    function afterRemoveLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure override returns (bytes4, BalanceDelta) {
        revert HookNotImplemented();
    }


    function beforeSwap(address, PoolKey calldata key, SwapParams calldata params, bytes calldata)
        external
        override
        returns (bytes4, BeforeSwapDelta swapDelta, uint24)
    {
        _onlyPoolManager();
        _lock();
        address c0 = Currency.unwrap(key.currency0);
        address c1 = Currency.unwrap(key.currency1);
        if (!_isBound(c0) || !_isBound(c1)) {
            _unlock();
            revert InvalidPoolToken();
        }

        address tokenIn = params.zeroForOne ? c0 : c1;
        address tokenOut = params.zeroForOne ? c1 : c0;
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) {
            _unlock();
            revert Math.MathDomain();
        }

        uint256 amountIn;
        uint256 amountOut;
        if (params.amountSpecified < 0) {
            amountIn = uint256(-params.amountSpecified);
            amountOut = _swapExactInExecute(tokenIn, tokenOut, amountIn, feeWad);
            swapDelta = toBeforeSwapDelta(int128(int256(amountIn)), int128(-int256(amountOut)));
        } else {
            amountOut = uint256(params.amountSpecified);
            amountIn = _swapExactOutExecute(tokenIn, tokenOut, amountOut, feeWad);
            swapDelta = toBeforeSwapDelta(int128(-int256(amountOut)), int128(int256(amountIn)));
        }

        _take(Currency.wrap(tokenIn), address(this), amountIn);
        // Buffer-last: unwrap out already done inside execute; buffer in after take
        if (_seOf(tokenIn) != address(0)) {
            _bufferToken(tokenIn, amountIn);
        } else {
            Repo._layout().reserves[tokenIn] += amountIn;
        }
        _settle(Currency.wrap(tokenOut), amountOut);
        _recomputeL2();
        _syncVaultReserves();

        emit Swap(tx.origin, tokenIn, tokenOut, amountIn, amountOut, feeWad);
        _unlock();
        return (IHooks.beforeSwap.selector, swapDelta, Math.feeOverridePips(feeWad));
    }


    function afterSwap(address, PoolKey calldata, SwapParams calldata, BalanceDelta, bytes calldata)
        external
        pure
        override
        returns (bytes4, int128)
    {
        revert HookNotImplemented();
    }


    function beforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        revert HookNotImplemented();
    }


    function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        revert HookNotImplemented();
    }


    function previewSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn)
        external
        view
        returns (uint256 amountOut)
    {
        if (amountIn == 0 || !_isLive()) return 0;
        return _previewSwapExactIn(tokenIn, tokenOut, amountIn);
    }


    function previewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        if (amountOut == 0 || !_isLive()) return 0;
        return _previewSwapExactOut(tokenIn, tokenOut, amountOut);
    }

    function tokens() public view returns (address[] memory t) {
        Repo.Layout storage l = Repo._layout();
        t = new address[](3);
        t[0] = l.token0;
        t[1] = l.token1;
        t[2] = l.token2;
    }

    function standardExchangeOf(address token) public view returns (address) {
        return Repo._layout().legs.standardExchangeOf[token];
    }

    function syntheticNumeraires() public view returns (address[] memory n) {
        Repo.Layout storage l = Repo._layout();
        uint256 count_;
        if (l.legs.pairTokens._contains(l.token0)) count_++;
        if (l.legs.pairTokens._contains(l.token1)) count_++;
        if (l.legs.pairTokens._contains(l.token2)) count_++;
        n = new address[](count_);
        uint256 w_;
        if (l.legs.pairTokens._contains(l.token0)) n[w_++] = l.token0;
        if (l.legs.pairTokens._contains(l.token1)) n[w_++] = l.token1;
        if (l.legs.pairTokens._contains(l.token2)) n[w_++] = l.token2;
    }

    function requiredFirstBondTokens() public view returns (address[] memory) {
        return tokens();
    }

    function firstJoinMustBeFullBook() public pure returns (bool) {
        return true;
    }

    function tradingFeeWad() public view returns (uint256) {
        return IVaultFeeOracleQuery(Repo._layout().feeOracle).dexSwapFeeOfVault(address(this));
    }

    function previewSwapAfterExchange(address tokenIn, address pairToken, address rawTokenOut, uint256 amountIn)
        external view returns (uint256 amountOut)
    {
        return _previewSwapAfterExchange(tokenIn, pairToken, rawTokenOut, amountIn);
    }

    function previewSynthetic(IDetfReserveQuote.DetfQuoteCtx calldata ctx, address numeraire)
        external
        view
        returns (uint256 wad)
    {
        if (ctx.ownedLp == 0 || ctx.detfTotalSupply == 0 || ctx.creationPairPerDetfWad == 0) {
            return 0;
        }
        if (!_isLive()) return 0;
        address out_ = _resolveNumeraire(numeraire);
        address detf_ = Repo._layout().legs.detfToken;
        if (out_ == address(0) || detf_ == address(0) || out_ == detf_) return 0;
        Repo.Layout storage l = Repo._layout();
        uint256 R = l.R;
        uint256 x = _toWad(detf_, _effectiveNativeOf(detf_));
        uint256 y = _toWad(out_, _effectiveNativeOf(out_));
        if (R == 0 || x >= R || y >= R || y == 0) return 0;
        // Sphere spot moves with reserve swaps. Skip pool DETF: marking it at
        // spot cancels a swap to first order. Non-DETF inventory times spot is
        // the pair-WAD NAV; outstanding DETF (expansion is minted to the NFT)
        // stays in the denominator.
        uint256 spot = ((R - x) * 1e18) / (R - y);
        if (spot == 0) return 0;
        uint256 others = y;
        if (l.token0 != detf_ && l.token0 != out_) {
            others += _toWad(l.token0, _effectiveNativeOf(l.token0));
        }
        if (l.token1 != detf_ && l.token1 != out_) {
            others += _toWad(l.token1, _effectiveNativeOf(l.token1));
        }
        if (l.token2 != detf_ && l.token2 != out_) {
            others += _toWad(l.token2, _effectiveNativeOf(l.token2));
        }
        uint256 lpSupply = _totalSupply();
        if (lpSupply == 0 || others == 0) return 0;
        uint256 pairWad = (others * ctx.ownedLp) / lpSupply;
        pairWad = (pairWad * spot) / 1e18;
        if (pairWad == 0) return 0;
        uint256 mid_ = (pairWad * 1e18) / ctx.detfTotalSupply;
        return (mid_ * 1e18) / ctx.creationPairPerDetfWad;
    }

    function _resolveNumeraire(address numeraire) private view returns (address) {
        Repo.Layout storage l = Repo._layout();
        if (numeraire == address(0)) {
            if (l.legs.pairTokens._contains(l.token0)) return l.token0;
            if (l.legs.pairTokens._contains(l.token1)) return l.token1;
            if (l.legs.pairTokens._contains(l.token2)) return l.token2;
            return address(0);
        }
        UniswapV4SeBufferHookLegLib.LegKind kind_ =
            UniswapV4SeBufferHookLegLib.classify(l.legs, numeraire);
        if (kind_ == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange) {
            return l.legs.pairOfStandardExchange[numeraire];
        }
        if (kind_ == UniswapV4SeBufferHookLegLib.LegKind.Pair) return numeraire;
        return address(0);
    }
}
