// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {BalancerV3PoolLiquidationLib as Liquidation} from "./BalancerV3PoolLiquidationLib.sol";
import {BalancerV3WeightedBufferPoolQuoteLib as WeightedQuote} from "./weighted/BalancerV3WeightedBufferPoolQuoteLib.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IBalancerV3PoolLiquidityQuote} from "contracts/protocols/dexes/balancer/v3/pools/IBalancerV3PoolLiquidityQuote.sol";
import {BalancerV3VaultAwareRepo} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {IVault} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IVault.sol";
import {IBasePool} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IBasePool.sol";
import {PoolData} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {BasePoolMath} from "@crane/contracts/external/balancer/v3/vault/contracts/BasePoolMath.sol";
import {PoolConfigLib} from "@crane/contracts/external/balancer/v3/vault/contracts/lib/PoolConfigLib.sol";
import {ScalingHelpers} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/helpers/ScalingHelpers.sol";

/**
 * @title BalancerV3PoolStandardExchangeTransitionQuoteTarget
 * @notice Sequential, read-only transition quotes for the native Balancer V3 buffer-pool
 *         Standard Exchange (the pool diamond's own BPT is the SE share, D38). Mirrors the
 *         shared execution/preview target `BalancerV3PoolStandardExchangeTarget`
 *         (`_quotePoolData` / `_previewPoolLiquidity`) exactly, so a `quoteState` +
 *         single `quoteTransition` equals `previewExchangeIn` / `previewExchangeOut` to the wei.
 *
 * @dev The projection threads an opaque `Liquidation.PoolQuoteState`: the routed pool-token index, the
 *      pool's raw balances (mutable), the Vault decimal scaling factors and token rates, the
 *      static swap fee, projected BPT supply and the holder's projected BPT balance. Each op
 *      derives `balancesLiveScaled18` from the projected raw balances with the operation's
 *      rounding (add = ROUND_UP, remove = ROUND_DOWN, matching the Vault's
 *      `addLiquidity(ROUND_UP)` / `removeLiquidity(ROUND_DOWN)` loads and
 *      `_quotePoolData(joining)`), then delegates the invariant/balance math to the live pool
 *      through `IBasePool(address(this))` for the existing callback-based projections.
 *      Pools exposing IBalancerV3PoolLiquidityQuote instead own an opaque projected math/hook book. In
 *      particular stable CommonBuffer/MixedBuffer scale their virtuals after every removal;
 *      subsequent math must not read the pre-removal storage book.
 *
 *      All six buffer-pool families register every token with `paysYieldFees = false`, so the
 *      join-side yield-fee accrual in `_quotePoolData(true)` is a no-op and one raw-balance
 *      snapshot serves both join and exit. The routed asset must be a physical (non virtual
 *      buffer) pool token; a virtual buffer or unrouteable asset reverts `UnsupportedQuoteAsset`.
 */
abstract contract BalancerV3PoolStandardExchangeTransitionQuoteTarget is IStandardExchangeTransitionQuote {
    function _poolVault() private view returns (IVault) {
        return IVault(address(BalancerV3VaultAwareRepo._balancerV3Vault()));
    }

    /// @dev Mirrors `BalancerV3PoolStandardExchangeTarget._isVirtualBuffer`: buffer depths are
    ///      virtual pool tokens (`ttaToken()` / `bufferToken()` / `bufferToken(i)`), never a
    ///      valid SE input or output.
    function _isVirtualBuffer(address token_) private view returns (bool) {
        (bool ok_, bytes memory data_) = address(this).staticcall(abi.encodeWithSignature("ttaToken()"));
        if (ok_ && data_.length == 32) return token_ == abi.decode(data_, (address));
        (ok_, data_) = address(this).staticcall(abi.encodeWithSignature("bufferToken()"));
        if (ok_ && data_.length == 32) return token_ == abi.decode(data_, (address));
        (ok_, data_) = address(this).staticcall(abi.encodeWithSignature("pairCount()"));
        if (!ok_ || data_.length != 32) return false;
        uint256 pairs_ = abi.decode(data_, (uint256));
        for (uint256 i_; i_ < pairs_; ++i_) {
            (ok_, data_) = address(this).staticcall(abi.encodeWithSignature("bufferToken(uint256)", i_));
            if (ok_ && data_.length == 32 && token_ == abi.decode(data_, (address))) return true;
        }
        return false;
    }

    /// @dev Physical pool-token index for a routable snapshot asset; a virtual buffer or an
    ///      address that is not a pool token reverts `UnsupportedQuoteAsset`.
    function _routeIndex(address asset_) private view returns (uint256) {
        if (_isVirtualBuffer(asset_)) revert UnsupportedQuoteAsset(asset_);
        IERC20[] memory tokens_ = _poolVault().getPoolTokens(address(this));
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            if (address(tokens_[i_]) == asset_) return i_;
        }
        revert UnsupportedQuoteAsset(asset_);
    }

    /// @dev `balancesLiveScaled18` from the projected raw balances, with the op's rounding:
    ///      add loads round up, remove loads round down (Vault + `_quotePoolData` parity).
    function _liveBalances(Liquidation.PoolQuoteState memory q, bool roundUp) private pure returns (uint256[] memory live) {
        uint256 n = q.balancesRaw.length;
        live = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            live[i] = roundUp
                ? ScalingHelpers.toScaled18ApplyRateRoundUp(q.balancesRaw[i], q.scalingFactors[i], q.rates[i])
                : ScalingHelpers.toScaled18ApplyRateRoundDown(q.balancesRaw[i], q.scalingFactors[i], q.rates[i]);
        }
    }

    /// @dev The projection body, kind-for-kind identical to
    ///      `BalancerV3PoolStandardExchangeTarget._previewPoolLiquidity`, but over the projected
    ///      balances and supply. `joining` selects add vs remove; `exactOut` the direction.
    function _project(Liquidation.PoolQuoteState memory q, bool joining, bool exactOut, uint256 amount)
        private view returns (uint256 result, uint256[] memory fees)
    {
        uint256[] memory live = _liveBalances(q, joining);
        if (q.poolState.length != 0 || q.weightedState.length != 0) return _projectPoolState(q, live, joining, exactOut, amount);
        IBasePool pool = IBasePool(address(this));
        uint256 idx = q.index;
        if (joining && !exactOut) {
            uint256[] memory amounts = new uint256[](live.length);
            amounts[idx] = ScalingHelpers.toScaled18ApplyRateRoundDown(amount, q.scalingFactors[idx], q.rates[idx]);
            (result, fees) = BasePoolMath.computeAddLiquidityUnbalanced(live, amounts, q.supply, q.swapFee, pool);
        } else if (joining) {
            (result, fees) = BasePoolMath.computeAddLiquiditySingleTokenExactOut(live, idx, amount, q.supply, q.swapFee, pool);
            result = ScalingHelpers.toRawUndoRateRoundUp(result, q.scalingFactors[idx], q.rates[idx]);
        } else if (!exactOut) {
            (result, fees) = BasePoolMath.computeRemoveLiquiditySingleTokenExactIn(live, idx, amount, q.supply, q.swapFee, pool);
            result = ScalingHelpers.toRawUndoRateRoundDown(result, q.scalingFactors[idx], q.rates[idx]);
        } else {
            uint256 liveOut = ScalingHelpers.toScaled18ApplyRateRoundUp(amount, q.scalingFactors[idx], q.rates[idx]);
            (result, fees) = BasePoolMath.computeRemoveLiquiditySingleTokenExactOut(live, idx, liveOut, q.supply, q.swapFee, pool);
        }
    }

    function _projectPoolState(Liquidation.PoolQuoteState memory q, uint256[] memory live, bool joining, bool exactOut, uint256 amount)
        private view returns (uint256 result, uint256[] memory fees)
    {
        IBalancerV3PoolLiquidityQuote.LiquidityQuoteParams memory p;
        p.balancesLiveScaled18 = live;
        p.index = q.index;
        p.amountScaled18 = amount;
        p.supply = q.supply;
        p.swapFee = q.swapFee;
        p.joining = joining;
        p.exactOut = exactOut;
        if (joining && !exactOut) {
            p.amountScaled18 = ScalingHelpers.toScaled18ApplyRateRoundDown(amount, q.scalingFactors[q.index], q.rates[q.index]);
        } else if (!joining && exactOut) {
            p.amountScaled18 = ScalingHelpers.toScaled18ApplyRateRoundUp(amount, q.scalingFactors[q.index], q.rates[q.index]);
        }
        if (q.poolState.length != 0) {
            (result, fees) = IBalancerV3PoolLiquidityQuote(address(this)).quotePoolLiquidity(q.poolState, p);
        } else {
            (result, fees) = WeightedQuote.quote(q.weightedState, p);
        }
        if (!joining && !exactOut) {
            result = ScalingHelpers.toRawUndoRateRoundDown(result, q.scalingFactors[q.index], q.rates[q.index]);
        } else if (joining && exactOut) {
            result = ScalingHelpers.toRawUndoRateRoundUp(result, q.scalingFactors[q.index], q.rates[q.index]);
        }
    }

    /// @dev Native liquidation sequence, including valuation beyond execution capacity.
    ///      Successful execution must pay the quote; Vault limits may reject execution.
    function _valueShares(Liquidation.PoolQuoteState memory q, uint256 shares) private view returns (uint256) {
        if (shares == 0 || q.supply == 0) return 0;
        (,, uint256 assets,) = Liquidation.liquidate(q, shares, false);
        return assets;
    }

    function _decode(bytes memory state_) private view returns (Liquidation.PoolQuoteState memory q) {
        q = abi.decode(state_, (Liquidation.PoolQuoteState));
        if (q.pool != address(this) || q.index >= q.balancesRaw.length
            || q.balancesRaw.length != q.scalingFactors.length || q.rates.length != q.balancesRaw.length) {
            revert InvalidQuoteState();
        }
        if (IERC165(address(this)).supportsInterface(type(IBalancerV3PoolLiquidityQuote).interfaceId)
            && q.poolState.length == 0) revert InvalidQuoteState();
    }

    function quoteState(address asset_, address holder_)
        external view returns (bytes memory state_, uint256 holderAssets_)
    {
        Liquidation.PoolQuoteState memory q = Liquidation.snapshot(_poolVault(), address(this), _routeIndex(asset_));
        q.holderShares = IERC20(address(this)).balanceOf(holder_);
        holderAssets_ = _valueShares(q, q.holderShares);
        state_ = abi.encode(q);
    }

    function quoteTransition(bytes calldata state_, Operation operation_, uint256 amount_)
        external view returns (bytes memory nextState_, uint256 amountIn_, uint256 amountOut_, uint256 holderAssetsAfter_)
    {
        Liquidation.PoolQuoteState memory q = _decode(state_);
        uint256[] memory fees;
        if (operation_ == Operation.ReceiveShares) {
            q.holderShares += amount_;
            if (q.holderShares > q.supply) revert InvalidQuoteState();
            return (abi.encode(q), amount_, amount_, _valueShares(q, q.holderShares));
        }
        if (operation_ == Operation.DepositExactIn) {
            amountIn_ = amount_;
            (amountOut_, fees) = _project(q, true, false, amount_);
            q.balancesRaw[q.index] += amount_;
            q = Liquidation.afterLiquidity(q, fees, true, amountOut_);
            q.supply += amountOut_;
            q.holderShares += amountOut_;
        } else if (operation_ == Operation.RedeemExactIn) {
            amountIn_ = amount_;
            if (amount_ > q.holderShares) revert InsufficientQuoteShares(amount_, q.holderShares);
            (q,, amountOut_,) = Liquidation.liquidate(q, amount_, false);
            q.holderShares -= amount_;
        } else {
            // WithdrawExactOut: `amount_` is the exact raw asset paid to the holder.
            amountOut_ = amount_;
            (q, amountIn_,,) = Liquidation.liquidate(q, amount_, true);
            if (amountIn_ > q.holderShares) revert InsufficientQuoteShares(amountIn_, q.holderShares);
            q.holderShares -= amountIn_;
        }
        holderAssetsAfter_ = _valueShares(q, q.holderShares);
        nextState_ = abi.encode(q);
    }

    function quoteAssets(bytes calldata state_, uint256 shares_) external view returns (uint256 assets) {
        return _valueShares(_decode(state_), shares_);
    }

    function quoteShareBalance(bytes calldata state_) external view returns (uint256 shares) {
        return _decode(state_).holderShares;
    }

    function quoteTotalSupply(bytes calldata state_) external view returns (uint256 shares) {
        return _decode(state_).supply;
    }
}
