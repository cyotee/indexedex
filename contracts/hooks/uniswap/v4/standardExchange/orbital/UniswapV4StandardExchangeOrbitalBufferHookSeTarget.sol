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
import {MultiStepOwnableRepo} from "@crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";

/// @title UniswapV4StandardExchangeOrbitalBufferHookSeTarget
/// @notice Role Target for orbital buffer hook size split (Option 1a).
abstract contract UniswapV4StandardExchangeOrbitalBufferHookSeTarget is UniswapV4StandardExchangeOrbitalBufferHookCommon {
    using SafeERC20 for IERC20;

    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        return _previewSwapExactIn(address(tokenIn), address(tokenOut), amountIn);
    }


    function exchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountOut) {
        _requireDeadline(deadline);
        _requireNonZero(amountIn);
        if (recipient == address(0)) revert ZeroAddress();
        address tin = address(tokenIn);
        address tout = address(tokenOut);
        if (!_isBound(tin) || !_isBound(tout) || tin == tout) revert InvalidRoute(tin, tout);
        // Reject SE share addresses
        Repo.Layout storage l = Repo._layout();
        if (tin == l.se0 || tin == l.se1 || tin == l.se2 || tout == l.se0 || tout == l.se1 || tout == l.se2) {
            revert InvalidRoute(tin, tout);
        }

        // L-GAPS-11 / ISecurePullErrors: pretransfer credits only in-window delta (I1/I3).
        // Leftover spendable economics unchanged (surplus delta not exact-matched).
        _securePull(IERC20(tin), amountIn, pretransferred);

        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        amountOut = _previewSwapExactIn(tin, tout, amountIn);
        if (amountOut < minAmountOut) revert InsufficientTokenOut();

        // Execute book swap (no PM)
        if (_seOf(tout) != address(0)) {
            _unwrapExactTokenOut(tout, amountOut);
        } else {
            l.reserves[tout] -= amountOut;
        }
        if (_seOf(tin) != address(0)) {
            _bufferToken(tin, amountIn);
        } else {
            l.reserves[tin] += amountIn;
        }
        _recomputeL2();
        IERC20(tout).safeTransfer(recipient, amountOut);
        _syncVaultReserves();
        emit Swap(msg.sender, tin, tout, amountIn, amountOut, feeWad);
    }


    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        return _previewSwapExactOut(address(tokenIn), address(tokenOut), amountOut);
    }


    function exchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountIn) {
        _requireDeadline(deadline);
        _requireNonZero(amountOut);
        if (recipient == address(0)) revert ZeroAddress();
        address tin = address(tokenIn);
        address tout = address(tokenOut);
        if (!_isBound(tin) || !_isBound(tout) || tin == tout) revert InvalidRoute(tin, tout);

        amountIn = _previewSwapExactOut(tin, tout, amountOut);
        if (amountIn > maxAmountIn) revert InsufficientTokenOut();

        // L-GAPS-11: delta-gate claimed amountIn. Refund only in-window surplus above amountIn
        // (never absolute free inventory / book).
        uint256 observedDelta = _securePull(IERC20(tin), amountIn, pretransferred);
        if (pretransferred && observedDelta > amountIn) {
            IERC20(tin).safeTransfer(msg.sender, observedDelta - amountIn);
        }

        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        Repo.Layout storage l = Repo._layout();
        if (_seOf(tout) != address(0)) {
            _unwrapExactTokenOut(tout, amountOut);
        } else {
            l.reserves[tout] -= amountOut;
        }
        if (_seOf(tin) != address(0)) {
            _bufferToken(tin, amountIn);
        } else {
            l.reserves[tin] += amountIn;
        }
        _recomputeL2();
        IERC20(tout).safeTransfer(recipient, amountOut);
        _syncVaultReserves();
        emit Swap(msg.sender, tin, tout, amountIn, amountOut, feeWad);
    }

    /// @notice D89: owner exact-in; internal book settlement (no nested PoolManager.unlock).
    function ownerSwapExactIn(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountOut) {
        _onlyHookOwner();
        _requireDeadline(deadline);
        _requireNonZero(amountIn);
        if (!_isBound(tokenIn) || !_isBound(tokenOut) || tokenIn == tokenOut) {
            revert InvalidRoute(tokenIn, tokenOut);
        }
        amountOut = _previewSwapExactIn(tokenIn, tokenOut, amountIn);
        if (amountOut < minAmountOut) revert InsufficientTokenOut();
        _securePull(IERC20(tokenIn), amountIn, false);
        _payOwnerSwap(tokenIn, tokenOut, amountIn, amountOut);
    }

    /// @notice D89: owner exact-out; internal book settlement (no nested PoolManager.unlock).
    function ownerSwapExactOut(
        address tokenIn,
        address tokenOut,
        uint256 amountOut,
        uint256 maxAmountIn,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountIn) {
        _onlyHookOwner();
        _requireDeadline(deadline);
        _requireNonZero(amountOut);
        if (!_isBound(tokenIn) || !_isBound(tokenOut) || tokenIn == tokenOut) {
            revert InvalidRoute(tokenIn, tokenOut);
        }
        amountIn = _previewSwapExactOut(tokenIn, tokenOut, amountOut);
        if (amountIn > maxAmountIn) revert InsufficientTokenOut();
        _securePull(IERC20(tokenIn), amountIn, false);
        _payOwnerSwap(tokenIn, tokenOut, amountIn, amountOut);
    }

    function _onlyHookOwner() private view {
        if (msg.sender != MultiStepOwnableRepo._owner()) {
            revert IMultiStepOwnable.NotOwner(msg.sender);
        }
    }

    function _payOwnerSwap(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut) private {
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        Repo.Layout storage l = Repo._layout();
        if (_seOf(tokenOut) != address(0)) {
            _unwrapExactTokenOut(tokenOut, amountOut);
        } else {
            l.reserves[tokenOut] -= amountOut;
        }
        if (_seOf(tokenIn) != address(0)) {
            _bufferToken(tokenIn, amountIn);
        } else {
            l.reserves[tokenIn] += amountIn;
        }
        _recomputeL2();
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);
        _syncVaultReserves();
        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut, feeWad);
    }
}
