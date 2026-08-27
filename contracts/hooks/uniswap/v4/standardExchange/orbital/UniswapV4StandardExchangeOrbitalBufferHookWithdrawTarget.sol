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
    IUniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {
    UniswapV4SeBufferHookLegLib
} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";

/// @title UniswapV4StandardExchangeOrbitalBufferHookWithdrawTarget
/// @notice Role Target for orbital buffer hook size split (Option 1a).
abstract contract UniswapV4StandardExchangeOrbitalBufferHookWithdrawTarget is UniswapV4StandardExchangeOrbitalBufferHookCommon {
    using SafeERC20 for IERC20;

    function removeLiquidity(
        uint256 shares,
        address to,
        uint256 a0Min,
        uint256 a1Min,
        uint256 a2Min,
        uint256 deadline
    ) external onlyLiquidityOwner nonReentrant returns (uint256 a0, uint256 a1, uint256 a2) {
        return _removeLiquidity(shares, to, a0Min, a1Min, a2Min, deadline);
    }


    function previewRemoveLiquidity(uint256 shares)
        external
        view
        returns (uint256 a0, uint256 a1, uint256 a2)
    {
        return _previewRemoveLiquidity(shares);
    }


    function withdrawFlexible(
        uint256 shares,
        address to,
        bool receiveSeShare0,
        bool receiveSeShare1,
        bool receiveSeShare2,
        uint256 a0Min,
        uint256 a1Min,
        uint256 a2Min,
        uint256 deadline
    ) external onlyLiquidityOwner nonReentrant returns (uint256 a0, uint256 a1, uint256 a2) {
        WithdrawFlexibleVars memory w;
        w.shares = shares;
        w.to = to;
        w.receiveSeShare0 = receiveSeShare0;
        w.receiveSeShare1 = receiveSeShare1;
        w.receiveSeShare2 = receiveSeShare2;
        w.a0Min = a0Min;
        w.a1Min = a1Min;
        w.a2Min = a2Min;
        return _withdrawFlexible(w, deadline);
    }


    function previewWithdrawFlexible(
        uint256 shares,
        bool receiveSeShare0,
        bool receiveSeShare1,
        bool receiveSeShare2
    ) external view returns (uint256 a0, uint256 a1, uint256 a2) {
        return _previewWithdrawFlexible(shares, receiveSeShare0, receiveSeShare1, receiveSeShare2);
    }

    function exitProportional(
        uint256 shares,
        address to,
        uint256[] calldata amountsMin,
        uint256 deadline
    ) external onlyLiquidityOwner nonReentrant returns (uint256[] memory amounts) {
        uint256 min0 = amountsMin.length > 0 ? amountsMin[0] : 0;
        uint256 min1 = amountsMin.length > 1 ? amountsMin[1] : 0;
        uint256 min2 = amountsMin.length > 2 ? amountsMin[2] : 0;
        (uint256 a0, uint256 a1, uint256 a2) =
            _removeLiquidity(shares, to, min0, min1, min2, deadline);
        amounts = new uint256[](3);
        amounts[0] = a0;
        amounts[1] = a1;
        amounts[2] = a2;
    }

    function previewExitProportional(uint256 shares) external view returns (uint256[] memory amounts) {
        if (shares == 0 || ERC20Repo._totalSupply() == 0) {
            amounts = new uint256[](3);
            return amounts;
        }
        (uint256 a0, uint256 a1, uint256 a2) = _previewRemoveLiquidity(shares);
        amounts = new uint256[](3);
        amounts[0] = a0;
        amounts[1] = a1;
        amounts[2] = a2;
    }

    function exitSingleAssetExactBptIn(
        address tokenOut,
        uint256 sharesIn,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) external onlyLiquidityOwner nonReentrant returns (uint256 amountOut) {
        sharesIn;
        to;
        amountOutMin;
        deadline;
        revert InvalidRoute(tokenOut, address(0));
    }

    function previewExitSingleAssetExactBptIn(address, uint256) external view returns (uint256) {
        return 0;
    }

    function exitSingleAssetExactTokenOut(
        address tokenOut,
        uint256 amountOut,
        address to,
        uint256 sharesInMax,
        uint256 deadline
    ) external onlyLiquidityOwner nonReentrant returns (uint256 sharesIn) {
        amountOut;
        to;
        sharesInMax;
        deadline;
        revert InvalidRoute(tokenOut, address(0));
    }

    function previewExitSingleAssetExactTokenOut(address, uint256) external view returns (uint256) {
        return 0;
    }

    /// @dev H10: prop exit of `lpAmount`, convert non-tokenOut legs via swap quotes (no exitSingleAsset*).
    function previewBurnToToken(uint256 lpAmount, address tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        if (lpAmount == 0 || ERC20Repo._totalSupply() == 0 || !_isLive()) return 0;
        address resolved_ = _resolveBurnTokenOut(tokenOut);
        if (resolved_ == address(0)) return 0;
        (uint256 a0, uint256 a1, uint256 a2) = _previewRemoveLiquidity(lpAmount);
        Repo.Layout storage l = Repo._layout();
        if (resolved_ == l.token0) {
            amountOut = a0 + _tryPreviewSwap(l.token1, l.token0, a1)
                + _tryPreviewSwap(l.token2, l.token0, a2);
        } else if (resolved_ == l.token1) {
            amountOut = a1 + _tryPreviewSwap(l.token0, l.token1, a0)
                + _tryPreviewSwap(l.token2, l.token1, a2);
        } else {
            amountOut = a2 + _tryPreviewSwap(l.token0, l.token2, a0)
                + _tryPreviewSwap(l.token1, l.token2, a1);
        }
    }

    function _resolveBurnTokenOut(address tokenOut) private view returns (address) {
        Repo.Layout storage l = Repo._layout();
        UniswapV4SeBufferHookLegLib.LegKind kind_ =
            UniswapV4SeBufferHookLegLib.classify(l.legs, tokenOut);
        if (kind_ == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange) {
            return l.legs.pairOfStandardExchange[tokenOut];
        }
        if (
            kind_ == UniswapV4SeBufferHookLegLib.LegKind.Pair
                || kind_ == UniswapV4SeBufferHookLegLib.LegKind.Detf
        ) {
            return tokenOut;
        }
        return address(0);
    }

    function _tryPreviewSwap(address tokenIn, address tokenOut, uint256 amountIn)
        private
        view
        returns (uint256)
    {
        if (amountIn == 0) return 0;
        try IUniswapV4SeBufferHook(address(this)).previewSwapExactIn(tokenIn, tokenOut, amountIn)
        returns (uint256 y) {
            return y;
        } catch {
            return 0;
        }
    }
}
