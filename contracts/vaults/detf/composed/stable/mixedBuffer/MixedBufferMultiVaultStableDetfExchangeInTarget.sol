// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {
    MixedBufferMultiVaultStableDetfExchangeOutTarget
} from "contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfExchangeOutTarget.sol";
import {
    MixedBufferMultiVaultStableDetfRepo
} from "contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";

/// @title MixedBufferMultiVaultStableDetfExchangeInTarget
/// @notice Exact-in mint (buffer or vaultShare → DETF) and burn (DETF → buffer). Share↔share / DETF→share InvalidRoute.
abstract contract MixedBufferMultiVaultStableDetfExchangeInTarget is MixedBufferMultiVaultStableDetfExchangeOutTarget {
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

        // Burn DETF → buffer only
        if (address(tokenIn_) == address(this)) {
            return _burnDetfExactInToBuffer(
                amountIn_, tokenOut_, minAmountOut_, recipient_, pretransferred_, deadline_
            );
        }

        // Mint DETF from buffer or vault share (post-live)
        if (address(tokenOut_) == address(this)) {
            _requireReserveLive();
            MixedBufferMultiVaultStableDetfRepo.Storage storage s =
                MixedBufferMultiVaultStableDetfRepo._layoutStruct();
            if (!_isMintingAllowed()) {
                revert MixedBufferMultiVaultStableDetfRepo.MintingNotAllowed(_syntheticPrice(), s.mintThreshold);
            }

            if (MixedBufferMultiVaultStableDetfRepo._isBufferToken(tokenIn_)) {
                uint256 bufferIn_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
                amountOut_ = _mintDetfFromBuffer(bufferIn_, recipient_);
            } else {
                (bool found_, uint256 legIndex_) =
                    MixedBufferMultiVaultStableDetfRepo._findVaultShareIndex(tokenIn_);
                if (!found_) {
                    revert MixedBufferMultiVaultStableDetfRepo.InvalidRoute(address(tokenIn_), address(tokenOut_));
                }
                uint256 vaultShares_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
                amountOut_ = _mintDetfFromVaultShares(legIndex_, vaultShares_, recipient_);
            }

            if (amountOut_ < minAmountOut_) {
                revert IStandardExchangeErrors.MinAmountNotMet(minAmountOut_, amountOut_);
            }
            return amountOut_;
        }

        revert MixedBufferMultiVaultStableDetfRepo.InvalidRoute(address(tokenIn_), address(tokenOut_));
    }

    /// @dev P7: unbalanced buffer + DETF self join.
    function _mintDetfFromBuffer(uint256 bufferAmount_, address recipient_)
        internal
        returns (uint256 userOut_)
    {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (!s.isReserveLive || IERC20(s.reservePool).totalSupply() == 0) {
            revert MixedBufferMultiVaultStableDetfRepo.ReservePoolNotInitialized();
        }

        MintSplit memory split_ = _splitMintedDetf(_quoteDetfOutForBuffer(bufferAmount_));
        _mintDetf(address(this), split_.grossDetf);
        _joinReserveBufferAndDetf(bufferAmount_, split_.grossDetf);
        _mintDetf(recipient_, split_.userDetf);
        if (split_.feeToDetf > 0) _mintDetf(_feeTo(), split_.feeToDetf);
        if (split_.protocolDetf > 0) _mintDetf(address(s.bondNftVault), split_.protocolDetf);
        return split_.userDetf;
    }

    function _mintDetfFromVaultShares(uint256 legIndex_, uint256 vaultShares_, address recipient_)
        internal
        returns (uint256 userOut_)
    {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (!s.isReserveLive || IERC20(s.reservePool).totalSupply() == 0) {
            revert MixedBufferMultiVaultStableDetfRepo.ReservePoolNotInitialized();
        }

        MintSplit memory split_ = _splitMintedDetf(_quoteDetfOutForVaultShares(legIndex_, vaultShares_));
        _mintDetf(address(this), split_.grossDetf);
        _joinReserveShareAndDetf(legIndex_, vaultShares_, split_.grossDetf);
        _mintDetf(recipient_, split_.userDetf);
        if (split_.feeToDetf > 0) _mintDetf(_feeTo(), split_.feeToDetf);
        if (split_.protocolDetf > 0) _mintDetf(address(s.bondNftVault), split_.protocolDetf);
        return split_.userDetf;
    }
}
