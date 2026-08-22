// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {
    UniswapV4StandardExchangeWeightedDETFExchangeOutTarget
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETFExchangeOutTarget.sol";
import {
    UniswapV4StandardExchangeWeightedDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETFRepo.sol";

/// @title UniswapV4StandardExchangeWeightedDETFExchangeInTarget
/// @notice Exact-in mint (pair/share/SE token), burn when tokenIn is DETF.
/// @dev Primary mint does NOT realize expansion or advance lastExpansionTimestamp.
abstract contract UniswapV4StandardExchangeWeightedDETFExchangeInTarget is
    UniswapV4StandardExchangeWeightedDETFExchangeOutTarget
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
        // Rate first to know which pair gate applies.
        // Settle pulls tokens; for gate check use rating path.
        if (!_isAllowlistedTokenIn(tokenIn_)) revert Repo.InvalidRoute(tokenIn_, IERC20(address(this)));
        PairLegRating memory pre_ = _rateTokenInToPairLeg(tokenIn_, amountIn_);
        _realizeExpansionIfNeeded();
        if (!_isMintingAllowed(pre_.fundedProductIndex)) {
            revert Repo.MintingNotAllowed(
                _syntheticVs(pre_.fundedProductIndex), Repo._layoutStruct().mintThreshold
            );
        }
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
        for (uint8 i; i < s.m; ++i) {
            if (
                address(tokenIn_) == address(s.pairTokens[i]) || address(tokenIn_) == address(s.vaultShares[i])
                    || (
                        address(s.standardExchanges[i]) != address(0)
                            && _tokenInSeTokens(tokenIn_, address(s.standardExchanges[i]))
                    )
            ) {
                se_ = address(s.standardExchanges[i]);
                break;
            }
        }
        if (se_ == address(0)) revert Repo.InvalidRoute(tokenIn_, tokenOut_);
        // Nested SE fund: push + pretransferred=true (L-DETF-PUSH-NESTED).
        amountOut_ = _nestedExchangeInPush(
            IStandardExchangeIn(se_), tokenIn_, pulled_, tokenOut_, minAmountOut_, recipient_, deadline_
        );
    }

    /// @dev Live mint D8+D27+D11: boost quote only; join unboosted pair to NFT (no originalShares); no feeTo.
    function _mintDetfFromPairLeg(PairLegRating memory r_, address recipient_)
        internal
        returns (uint256 userOut_)
    {
        uint256 pairBoosted_ =
            Math.mulDiv(r_.pairNotionalNative, ONE_WAD + _seigniorageIncentiveWad(), ONE_WAD);
        uint256 gross_ = _quoteDetfAgainstReserve(r_.fundedProductIndex, pairBoosted_);
        MintSplit memory split_ = _splitMintedDetf(gross_);

        address pair_ = address(Repo._layoutStruct().pairTokens[r_.fundedProductIndex]);
        _depositSingle(pair_, r_.pairNotionalNative, _bondLpHolder());

        _mintDetf(recipient_, split_.userDetf);
        _creditBondPot(split_.inventoryDetf);
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
            if (!_isAllowlistedTokenIn(tokenIn_)) return 0;
            PairLegRating memory r_ = _rateTokenInToPairLeg(tokenIn_, amountIn_);
            uint256 pairBoosted_ =
                Math.mulDiv(r_.pairNotionalNative, ONE_WAD + _seigniorageIncentiveWad(), ONE_WAD);
            uint256 gross_ = _quoteDetfAgainstReserve(r_.fundedProductIndex, pairBoosted_);
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
        for (uint8 i; i < s.m; ++i) {
            if (
                address(tokenIn_) == address(s.pairTokens[i]) || address(tokenIn_) == address(s.vaultShares[i])
                    || (
                        address(s.standardExchanges[i]) != address(0)
                            && _tokenInSeTokens(tokenIn_, address(s.standardExchanges[i]))
                    )
            ) {
                se_ = address(s.standardExchanges[i]);
                break;
            }
        }
        if (se_ == address(0)) return 0;
        return IStandardExchangeIn(se_).previewExchangeIn(tokenIn_, amountIn_, tokenOut_);
    }
}
