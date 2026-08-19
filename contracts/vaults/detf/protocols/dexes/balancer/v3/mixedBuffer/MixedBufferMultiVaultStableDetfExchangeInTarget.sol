// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {
    MixedBufferMultiVaultStableDetfExchangeOutTarget
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfExchangeOutTarget.sol";
import {
    MixedBufferMultiVaultStableDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";

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
            _syncAllExpectedHoldReserves();
            return amountOut_;
        }

        revert MixedBufferMultiVaultStableDetfRepo.InvalidRoute(address(tokenIn_), address(tokenOut_));
    }

    /// @dev D11: join only non-DETF capital. D8 quote + D27 split. No DETF into the pool.
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
        _joinLiveNonDetfBuffer(bufferAmount_);
        _mintDetf(recipient_, split_.userDetf);
        if (split_.inventoryDetf > 0) _mintDetf(address(s.bondNftVault), split_.inventoryDetf);
        _tryCompoundProtocolRewards();
        return split_.userDetf;
    }

    /// @dev D11: no DETF into the pool. Buffer-only unbalanced joins shrink the MixedBuffer
    ///      invariant (virtualBuffer updates after join). Zap buffer → vault-share 0, join shares.
    function _joinLiveNonDetfBuffer(uint256 bufferAmount_) internal {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        uint256 sharesOut_ = _nestedExchangeInPush(
            s.underlyingVaults[0],
            s.bufferToken,
            bufferAmount_,
            s.vaultShares[0],
            0,
            address(this),
            block.timestamp + 1 hours
        );
        _joinReserveVaultShareOnly(0, sharesOut_);
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
        _joinReserveVaultShareOnly(legIndex_, vaultShares_);
        _mintDetf(recipient_, split_.userDetf);
        if (split_.inventoryDetf > 0) _mintDetf(address(s.bondNftVault), split_.inventoryDetf);
        _tryCompoundProtocolRewards();
        return split_.userDetf;
    }
}
