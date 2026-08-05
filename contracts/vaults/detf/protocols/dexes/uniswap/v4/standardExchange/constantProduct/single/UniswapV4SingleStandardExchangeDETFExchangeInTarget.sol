// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    UniswapV4SingleStandardExchangeDETFExchangeOutTarget
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETFExchangeOutTarget.sol";
import {
    UniswapV4SingleStandardExchangeDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETFRepo.sol";

/// @title UniswapV4SingleStandardExchangeDETFExchangeInTarget
/// @notice Exact-in mint (pair/share/SE token), burn when tokenIn is DETF, SE passthrough.
/// @dev Primary mint does NOT realize expansion or advance lastExpansionTimestamp.
abstract contract UniswapV4SingleStandardExchangeDETFExchangeInTarget is
    UniswapV4SingleStandardExchangeDETFExchangeOutTarget
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
        if (recipient_ == address(0)) recipient_ = msg.sender;

        if (address(tokenIn_) == address(this)) {
            return _burnDetfExactIn(amountIn_, tokenOut_, minAmountOut_, recipient_, pretransferred_, deadline_);
        }
        if (address(tokenOut_) == address(this)) {
            amountOut_ = _mintPath(tokenIn_, amountIn_, recipient_, pretransferred_, deadline_);
            if (amountOut_ < minAmountOut_) {
                revert IStandardExchangeErrors.MinAmountNotMet(minAmountOut_, amountOut_);
            }
            return amountOut_;
        }
        if (address(tokenIn_) != address(this)) {
            return _sePassthrough(tokenIn_, amountIn_, tokenOut_, minAmountOut_, recipient_, pretransferred_, deadline_);
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
        userOut_ = _mintDetfFromPair(_settleToPair(tokenIn_, amountIn_, pretransferred_, deadline_), recipient_);
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
        if (!_isAllowlistedTokenIn(tokenIn_) || !_isAllowlistedTokenIn(tokenOut_)) {
            revert Repo.InvalidRoute(tokenIn_, tokenOut_);
        }
        uint256 pulled_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
        address se_ = address(Repo._layoutStruct().standardExchangeVault);
        tokenIn_.safeTransfer(se_, pulled_);
        amountOut_ = Repo._layoutStruct().standardExchangeVault.exchangeIn(
            tokenIn_, pulled_, tokenOut_, minAmountOut_, recipient_, true, deadline_
        );
    }

    /// @dev Live primary mint: seigniorage quote/split; depositSingle(pair) → protocol LP holder; free DETF legs.
    ///      Does NOT realize expansion.
    function _mintDetfFromPair(uint256 pairAmount_, address recipient_) internal returns (uint256 userOut_) {
        uint256 pairBoosted_ = Math.mulDiv(pairAmount_, ONE_WAD + _seigniorageIncentiveWad(), ONE_WAD);
        MintSplit memory split_ = _splitMintedDetf(_quoteDetfAgainstReserve(pairBoosted_));
        // Protocol LP lands on rebasing claim package when wired (PRD: protocol principal held by claim).
        _depositSinglePair(pairAmount_, _protocolLpHolder());
        _mintDetf(recipient_, split_.userDetf);
        if (split_.feeToDetf > 0) _mintDetf(_feeTo(), split_.feeToDetf);
        address bondVault_ = address(Repo._layoutStruct().bondNftVault);
        if (split_.inventoryDetf > 0 && bondVault_ != address(0)) {
            _mintDetf(bondVault_, split_.inventoryDetf);
        }
        return split_.userDetf;
    }

    function previewExchangeIn(IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_)
        public
        view
        virtual
        returns (uint256 amountOut_)
    {
        Repo.Storage storage s = Repo._layoutStruct();

        // Claim-token rate path: reserve hook LP → pair (rateAsset).
        if (address(tokenIn_) == s.reserveHook && address(tokenOut_) == address(s.pairToken)) {
            return IHook(s.reserveHook).previewWithdrawSingle(amountIn_, address(s.pairToken));
        }

        if (address(tokenIn_) == address(this)) {
            return _previewBurnDetfExactIn(amountIn_, tokenOut_);
        }
        if (address(tokenOut_) == address(this)) {
            if (!s.isReserveLive) return 0;
            // Approximate pair settlement for preview when tokenIn is pair.
            uint256 pairAmount_ = amountIn_;
            if (address(tokenIn_) != address(s.pairToken)) {
                // Best-effort SE preview
                try s.standardExchangeVault.previewExchangeIn(tokenIn_, amountIn_, s.pairToken) returns (
                    uint256 p_
                ) {
                    pairAmount_ = p_;
                } catch {
                    return 0;
                }
            }
            uint256 incentive_ = _seigniorageIncentiveWad();
            uint256 pairBoosted_ = Math.mulDiv(pairAmount_, ONE_WAD + incentive_, ONE_WAD);
            uint256 gross_ = _quoteDetfAgainstReserve(pairBoosted_);
            MintSplit memory split_ = _splitMintedDetf(gross_);
            return split_.userDetf;
        }
        if (_isAllowlistedTokenIn(tokenIn_) && _isAllowlistedTokenIn(tokenOut_)) {
            try s.standardExchangeVault.previewExchangeIn(tokenIn_, amountIn_, tokenOut_) returns (uint256 o_) {
                return o_;
            } catch {
                return 0;
            }
        }
        return 0;
    }
}
