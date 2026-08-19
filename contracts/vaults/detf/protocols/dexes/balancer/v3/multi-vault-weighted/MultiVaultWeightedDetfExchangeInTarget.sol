// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {
    MultiVaultWeightedDetfExchangeOutTarget
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfExchangeOutTarget.sol";
import {
    MultiVaultWeightedDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfRepo.sol";

/// @title MultiVaultWeightedDetfExchangeInTarget
/// @notice Exact-in mint (vault shares → DETF) and burn (DETF → vault shares). No rateAsset mint; no share↔share.
abstract contract MultiVaultWeightedDetfExchangeInTarget is MultiVaultWeightedDetfExchangeOutTarget {
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

        // Burn DETF → vault share. DETF → claim is buyClaim only.
        if (address(tokenIn_) == address(this)) {
            MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
            if (address(tokenOut_) == address(s.rebasingClaimToken)) {
                revert MultiVaultWeightedDetfRepo.InvalidRoute(address(tokenIn_), address(tokenOut_));
            }
            return _burnDetfExactIn(amountIn_, tokenOut_, minAmountOut_, recipient_, pretransferred_, deadline_);
        }

        // Mint DETF from vault share only (post-live)
        if (address(tokenOut_) == address(this)) {
            _requireReserveLive();
            MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
            if (!_isMintingAllowed()) {
                revert MultiVaultWeightedDetfRepo.MintingNotAllowed(_syntheticPrice(), s.mintThreshold);
            }

            (bool found_, uint256 legIndex_) = MultiVaultWeightedDetfRepo._findVaultShareIndex(tokenIn_);
            if (!found_) {
                // rateAsset or unconfigured → InvalidRoute
                revert MultiVaultWeightedDetfRepo.InvalidRoute(address(tokenIn_), address(tokenOut_));
            }

            uint256 vaultShares_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
            amountOut_ = _mintDetfFromVaultShares(legIndex_, vaultShares_, recipient_);
            if (amountOut_ < minAmountOut_) {
                revert IStandardExchangeErrors.MinAmountNotMet(minAmountOut_, amountOut_);
            }
            _syncAllExpectedHoldReserves();
            return amountOut_;
        }

        // share↔share and other non-closed-form routes
        revert MultiVaultWeightedDetfRepo.InvalidRoute(address(tokenIn_), address(tokenOut_));
    }

    function _mintDetfFromVaultShares(uint256 legIndex_, uint256 vaultShares_, address recipient_)
        internal
        returns (uint256 userOut_)
    {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        if (!s.isReserveLive || IERC20(s.reservePool).totalSupply() == 0) {
            revert MultiVaultWeightedDetfRepo.ReservePoolNotInitialized();
        }

        MintSplit memory split_ = _splitMintedDetf(_quoteDetfOutForVaultShares(legIndex_, vaultShares_));
        // D11: live mint joins vault shares only (no new DETF into reserve). D14: no feeTo mint.
        _joinReserveVaultShareOnly(legIndex_, vaultShares_);
        _mintDetf(recipient_, split_.userDetf);
        if (split_.inventoryDetf > 0) _mintDetf(address(s.bondNftVault), split_.inventoryDetf);
        _tryCompoundProtocolRewards();
        return split_.userDetf;
    }
}
