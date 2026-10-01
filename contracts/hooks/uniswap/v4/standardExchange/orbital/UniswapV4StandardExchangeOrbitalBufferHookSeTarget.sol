// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4BufferHookLiquidityRouteLib as LiquidityRoute} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol";
import {NativeStandardYieldTarget} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
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
abstract contract UniswapV4StandardExchangeOrbitalBufferHookSeTarget is UniswapV4StandardExchangeOrbitalBufferHookCommon, NativeStandardYieldTarget {
    using SafeERC20 for IERC20;

    function getTokensIn() public view override returns (address[] memory tokens) {
        Repo.Layout storage l = Repo._layout();
        uint256 count = 3;
        for (uint8 i; i < 3; ++i) if (Repo._seAt(l, i) != address(0)) ++count;
        tokens = new address[](count);
        count = 3;
        for (uint8 i; i < 3; ++i) {
            tokens[i] = Repo._tokenAt(l, i);
            address se = Repo._seAt(l, i);
            if (se != address(0)) tokens[count++] = se;
        }
    }
    function getTokensOut() public view override returns (address[] memory) { return getTokensIn(); }
    function yieldToken() external pure override returns (address) { return address(0); }
    function assetInfo() external view override returns (IStandardizedYield.AssetType, address, uint8) {
        return (IStandardizedYield.AssetType.LIQUIDITY, address(this), 18);
    }
    function exchangeRate() external view override returns (uint256) {
        (, uint256 supply) = _previewProtocolMintShares();
        if (supply == 0) return 1e18;
        (uint256 x, uint256 y, uint256 z) = _effectiveWad();
        (,, uint256 root) = _measureK(x, y, z);
        return FullMath.mulDiv(root, 1e18, supply);
    }

    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        if (LiquidityRoute.isLiquidityRoute(tokenIn, tokenOut)) return LiquidityRoute.previewIn(tokenIn, amountIn, tokenOut);
        return _previewSwapExactIn(address(tokenIn), address(tokenOut), amountIn);
    }


    /// @dev Exact-in credits the requested amount and refunds nothing. `pretransferred=true`
    ///      is for integrating contracts only and reverts `EOAPretransferNotAllowed` for a
    ///      caller with no bytecode. Resting unbooked face is D12 credit, not this call's refund.
    function exchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut, uint256 minAmountOut, address recipient, bool pretransferred, uint256 deadline) external returns (uint256 amountOut) {
        if (LiquidityRoute.isLiquidityRoute(tokenIn, tokenOut)) return LiquidityRoute.exchangeIn(tokenIn, amountIn, tokenOut, minAmountOut, recipient, pretransferred, deadline);
        return _swapExchangeIn(tokenIn, amountIn, tokenOut, minAmountOut, recipient, pretransferred, deadline);
    }

    function _swapExchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) internal nonReentrant returns (uint256 amountOut) {
        _requireDeadline(deadline);
        _requireNonZero(amountIn);
        if (recipient == address(0)) revert ZeroAddress();
        address tin = address(tokenIn);
        address tout = address(tokenOut);
        if (!_isBound(tin) || !_isBound(tout) || tin == tout) revert InvalidRoute(tin, tout);
        // Reject SE share addresses
        {
            Repo.Layout storage l = Repo._layout();
            if (tin == l.se0 || tin == l.se1 || tin == l.se2 || tout == l.se0 || tout == l.se1 || tout == l.se2) {
                revert InvalidRoute(tin, tout);
            }
        }

        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        ExactInOutput memory output = _previewSwapExactInPlan(tin, tout, amountIn, feeWad);
        amountOut = output.amountOut;
        if (amountOut < minAmountOut) revert InsufficientTokenOut();
        // Delta-gate funding only after the complete forward payout is known.
        _securePull(IERC20(tin), amountIn, pretransferred);

        // Execute book swap (no PM)
        amountOut = _receiveExactInOutput(tout, output);
        if (amountOut < minAmountOut) revert InsufficientTokenOut();
        _finishSwap(tin, tout, amountIn, amountOut, recipient, feeWad);
    }


    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        if (LiquidityRoute.isLiquidityRoute(tokenIn, tokenOut)) return LiquidityRoute.previewOut(tokenIn, tokenOut, amountOut);
        return _previewSwapExactOut(address(tokenIn), address(tokenOut), amountOut);
    }


    /// @dev Exact-out refunds `credit - used` on `pretransferred=true` only, where
    ///      `credit = min(unbooked, maxAmountIn)`. False-flag pulls `used` and refunds nothing.
    ///      EOA pretransfer reverts `EOAPretransferNotAllowed`. Resting unbooked face beyond the credit is
    ///      D12 pretransfer credit, never this call's refund; what the SE returns during this call is counted
    ///      once, and an identity buffer's SE-share backing is not face to refund.
    function exchangeOut(IERC20 tokenIn, uint256 maxAmountIn, IERC20 tokenOut, uint256 amountOut, address recipient, bool pretransferred, uint256 deadline) external returns (uint256 amountIn) {
        if (LiquidityRoute.isLiquidityRoute(tokenIn, tokenOut)) return LiquidityRoute.exchangeOut(tokenIn, maxAmountIn, tokenOut, amountOut, recipient, pretransferred, deadline);
        return _swapExchangeOut(tokenIn, maxAmountIn, tokenOut, amountOut, recipient, pretransferred, deadline);
    }

    function _swapExchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) internal nonReentrant returns (uint256 amountIn) {
        _requireDeadline(deadline);
        _requireNonZero(amountOut);
        if (recipient == address(0)) revert ZeroAddress();
        address tin = address(tokenIn);
        address tout = address(tokenOut);
        if (!_isBound(tin) || !_isBound(tout) || tin == tout) revert InvalidRoute(tin, tout);

        amountIn = _previewSwapExactOut(tin, tout, amountOut);
        if (amountIn > maxAmountIn) revert InsufficientTokenOut();

        _pullExactOutInput(IERC20(tin), amountIn, maxAmountIn, pretransferred);

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
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        ExactInOutput memory output = _previewSwapExactInPlan(tokenIn, tokenOut, amountIn, feeWad);
        amountOut = output.amountOut;
        if (amountOut < minAmountOut) revert InsufficientTokenOut();
        _securePull(IERC20(tokenIn), amountIn, false);
        amountOut = _receiveExactInOutput(tokenOut, output);
        if (amountOut < minAmountOut) revert InsufficientTokenOut();
        _finishOwnerSwap(tokenIn, tokenOut, amountIn, amountOut, feeWad);
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
        _finishOwnerSwap(tokenIn, tokenOut, amountIn, amountOut, feeWad);
    }

    function _finishOwnerSwap(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut, uint256 feeWad) private {
        _finishSwap(tokenIn, tokenOut, amountIn, amountOut, msg.sender, feeWad);
    }

    function _finishSwap(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut, address recipient, uint256 feeWad) private {
        Repo.Layout storage l = Repo._layout();
        if (_seOf(tokenIn) != address(0)) {
            _bufferToken(tokenIn, amountIn);
        } else {
            l.reserves[tokenIn] += amountIn;
        }
        _recomputeL2();
        IERC20(tokenOut).safeTransfer(recipient, amountOut);
        _syncVaultReserves();
        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut, feeWad);
    }
}
