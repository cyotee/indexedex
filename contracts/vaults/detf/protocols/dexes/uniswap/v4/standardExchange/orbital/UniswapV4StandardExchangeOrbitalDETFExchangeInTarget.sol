// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {
    UniswapV4StandardExchangeOrbitalDETFExchangeOutTarget
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETFExchangeOutTarget.sol";
import {
    UniswapV4StandardExchangeOrbitalDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETFRepo.sol";

/// @title UniswapV4StandardExchangeOrbitalDETFExchangeInTarget
/// @notice Exact-in mint (pair/share/SE token), burn when tokenIn is DETF.
/// @dev Primary mint does NOT realize expansion or advance lastExpansionTimestamp.
abstract contract UniswapV4StandardExchangeOrbitalDETFExchangeInTarget is
    UniswapV4StandardExchangeOrbitalDETFExchangeOutTarget
{
    using BetterSafeERC20 for IERC20;

    function exchangeIn(
        IERC20 tokenIn_,
        uint256 amountIn_,
        IERC20 tokenOut_,
        uint256 minAmountOut_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256 amountOut_) {
        _requireActive(deadline_, amountIn_);
        if (address(tokenIn_) != address(this)) {
            _requireNotDisabled();
        }
        if (recipient_ == address(0)) recipient_ = msg.sender;

        if (address(tokenIn_) == address(this)) {
            amountOut_ =
                _burnDetfExactIn(amountIn_, tokenOut_, minAmountOut_, recipient_, pretransferred_, deadline_);
            _syncAllExpectedHoldReserves();
            return amountOut_;
        }
        if (address(tokenOut_) == address(this)) {
            amountOut_ = _mintPath(tokenIn_, amountIn_, recipient_, pretransferred_, deadline_);
            if (amountOut_ < minAmountOut_) {
                revert IStandardExchangeErrors.MinAmountNotMet(minAmountOut_, amountOut_);
            }
            _syncAllExpectedHoldReserves();
            return amountOut_;
        }
        // SE passthrough on same SE when both allowlisted.
        if (_isAllowlistedTokenIn(tokenIn_) && _isAllowlistedTokenIn(tokenOut_)) {
            amountOut_ =
                _sePassthrough(tokenIn_, amountIn_, tokenOut_, minAmountOut_, recipient_, pretransferred_, deadline_);
            _syncAllExpectedHoldReserves();
            return amountOut_;
        }
        revert Repo.InvalidRoute(tokenIn_, tokenOut_);
    }

    function _mintPath(
        IERC20 tokenIn_,
        uint256 amountIn_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) private returns (uint256 userOut_) {
        _requireReserveLive();
        if (!_isMintingAllowed()) {
            revert Repo.MintingNotAllowed(_syntheticPrice(), Repo._layoutStruct().mintThreshold);
        }
        // Does NOT realize expansion.
        PairLegRating memory r_ = _settleToPairLeg(tokenIn_, amountIn_, pretransferred_, deadline_);
        userOut_ = _mintDetfFromPairLeg(r_, recipient_);
    }

    function _sePassthrough(
        IERC20 tokenIn_,
        uint256 amountIn_,
        IERC20 tokenOut_,
        uint256 minAmountOut_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) private returns (uint256 amountOut_) {
        uint256 pulled_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
        Repo.Storage storage s = Repo._layoutStruct();
        address se_;
        if (
            address(tokenIn_) == address(s.pairToken0) || address(tokenIn_) == address(s.vaultShare0)
                || (address(s.standardExchange0) != address(0)
                    && _tokenInSeTokens(tokenIn_, address(s.standardExchange0)))
        ) {
            se_ = address(s.standardExchange0);
        } else {
            se_ = address(s.standardExchange1);
        }
        if (se_ == address(0)) revert Repo.InvalidRoute(tokenIn_, tokenOut_);
        // Nested SE fund: push + pretransferred=true (L-DETF-PUSH-NESTED).
        amountOut_ = _nestedExchangeInPush(
            IStandardExchangeIn(se_), tokenIn_, pulled_, tokenOut_, minAmountOut_, recipient_, deadline_
        );
    }

    /// @dev Live primary mint: Q15 rating + quote + split; depositSingle(pair) → protocol LP; free DETF legs.
    function _mintDetfFromPairLeg(PairLegRating memory r_, address recipient_)
        internal
        returns (uint256 userOut_)
    {
        uint256 pairBoosted_ =
            Math.mulDiv(r_.pairNotionalNative, ONE_WAD + _seigniorageIncentiveWad(), ONE_WAD);
        // Quote against reserve uses pair notional (native); boosted applied to quote input spirit:
        // PRD: pairBoosted = pairNotional * (1+inc); gross = quote(pairBoosted).
        uint256 gross_ = _quoteDetfAgainstReserve(r_.fundedPairLeg, pairBoosted_);
        MintSplit memory split_ = _splitMintedDetf(gross_);

        address pair_ = r_.fundedPairLeg == 0
            ? address(Repo._layoutStruct().pairToken0)
            : address(Repo._layoutStruct().pairToken1);
        // D11: join non-DETF capital only; LP sits on the NFT without new originalShares.
        _depositSingle(pair_, r_.pairNotionalNative, _bondLpHolder());

        _mintDetf(recipient_, split_.userDetf);
        address bondVault_ = address(Repo._layoutStruct().bondNftVault);
        if (split_.inventoryDetf > 0 && bondVault_ != address(0)) {
            _mintDetf(bondVault_, split_.inventoryDetf);
        }
        _tryCompoundProtocolRewards();
        return split_.userDetf;
    }

    function previewExchangeIn(IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_)
        public
        view
        virtual
        returns (uint256 amountOut_)
    {
        Repo.Storage storage s = Repo._layoutStruct();

        if (address(tokenIn_) == address(this)) {
            return _previewBurnDetfExactIn(amountIn_, tokenOut_);
        }
        if (address(tokenOut_) == address(this)) {
            if (!s.isReserveLive) return 0;
            // Best-effort: invalid tokenIn returns 0 via try/catch on rating path.
            if (!_isAllowlistedTokenIn(tokenIn_)) return 0;
            PairLegRating memory r_ = _rateTokenInToPairLeg(tokenIn_, amountIn_);
            uint256 pairBoosted_ =
                Math.mulDiv(r_.pairNotionalNative, ONE_WAD + _seigniorageIncentiveWad(), ONE_WAD);
            uint256 gross_ = _quoteDetfAgainstReserve(r_.fundedPairLeg, pairBoosted_);
            return _splitMintedDetf(gross_).userDetf;
        }
        // L-PREV-1: SE passthrough preview must match execute (delegate to underlying SE).
        if (_isAllowlistedTokenIn(tokenIn_) && _isAllowlistedTokenIn(tokenOut_)) {
            return _previewSePassthrough(tokenIn_, amountIn_, tokenOut_);
        }
        return 0;
    }

    /// @dev Mirrors `_sePassthrough` SE resolution; quotes via SE `previewExchangeIn`.
    function _previewSePassthrough(IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_)
        private
        view
        returns (uint256 amountOut_)
    {
        if (amountIn_ == 0) return 0;
        Repo.Storage storage s = Repo._layoutStruct();
        address se_;
        if (
            address(tokenIn_) == address(s.pairToken0) || address(tokenIn_) == address(s.vaultShare0)
                || (address(s.standardExchange0) != address(0)
                    && _tokenInSeTokens(tokenIn_, address(s.standardExchange0)))
        ) {
            se_ = address(s.standardExchange0);
        } else {
            se_ = address(s.standardExchange1);
        }
        if (se_ == address(0)) return 0;
        return IStandardExchangeIn(se_).previewExchangeIn(tokenIn_, amountIn_, tokenOut_);
    }
}
