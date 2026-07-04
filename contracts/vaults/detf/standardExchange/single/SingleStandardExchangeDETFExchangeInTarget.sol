// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {
    SingleStandardExchangeDETFExchangeOutTarget
} from "contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETFExchangeOutTarget.sol";
import {
    SingleStandardExchangeDETFRepo
} from "contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETFRepo.sol";

/// @title SingleStandardExchangeDETFExchangeInTarget
/// @notice Exact-in mint (vault shares or allowlisted assets), burn when tokenIn is DETF, and SE passthrough.
abstract contract SingleStandardExchangeDETFExchangeInTarget is SingleStandardExchangeDETFExchangeOutTarget {
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

        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();

        // Burn DETF → asset / vault shares
        if (address(tokenIn_) == address(this)) {
            return _burnDetfExactIn(amountIn_, tokenOut_, minAmountOut_, recipient_, pretransferred_, deadline_);
        }

        // Passthrough: both legs only involve the SE vault (not DETF mint/burn).
        if (address(tokenOut_) != address(this) && address(tokenIn_) != address(this)) {
            if (!_isAllowlistedTokenIn(tokenIn_) || !_isAllowlistedTokenIn(tokenOut_)) {
                revert SingleStandardExchangeDETFRepo.UnsupportedRoute(tokenIn_, tokenOut_);
            }
            uint256 pulled_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
            tokenIn_.safeTransfer(address(s.standardExchangeVault), pulled_);
            amountOut_ = s.standardExchangeVault.exchangeIn(
                tokenIn_, pulled_, tokenOut_, minAmountOut_, recipient_, true, deadline_
            );
            return amountOut_;
        }

        // Mint DETF
        if (address(tokenOut_) == address(this)) {
            _requireReserveLive();
            if (!_isMintingAllowed()) {
                revert SingleStandardExchangeDETFRepo.MintingNotAllowed(_syntheticPrice(), s.mintThreshold);
            }

            uint256 vaultShares_;
            if (address(tokenIn_) == address(s.standardExchangeVaultShare)) {
                vaultShares_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
            } else if (_isAllowlistedTokenIn(tokenIn_)) {
                uint256 pulled_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
                tokenIn_.safeTransfer(address(s.standardExchangeVault), pulled_);
                vaultShares_ = s.standardExchangeVault.exchangeIn(
                    tokenIn_,
                    pulled_,
                    s.standardExchangeVaultShare,
                    0,
                    address(this),
                    true,
                    deadline_
                );
            } else {
                revert SingleStandardExchangeDETFRepo.UnsupportedRoute(tokenIn_, tokenOut_);
            }

            amountOut_ = _mintDetfFromVaultShares(vaultShares_, recipient_);
            if (amountOut_ < minAmountOut_) {
                revert IStandardExchangeErrors.MinAmountNotMet(minAmountOut_, amountOut_);
            }
            return amountOut_;
        }

        revert SingleStandardExchangeDETFRepo.UnsupportedRoute(tokenIn_, tokenOut_);
    }

    /// @dev Quote-driven mint: mint DETF first for join (self-transfer), join shares+detf, leave BPT on diamond.
    function _mintDetfFromVaultShares(uint256 vaultShares_, address recipient_)
        internal
        returns (uint256 userOut_)
    {
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        MintSplit memory split_ = _splitMintedDetf(_quoteDetfOutForVaultShares(vaultShares_));

        // Mint full gross to this, then join DETF leg + vault shares; user/protocol/fee get DETF balances after.
        // Pattern: mint user+fee+protocol DETF; join only the curve-paired DETF amount into reserve with shares.
        // Gross DETF is the curve output; user receives userDetf free of reserve join pairing.
        // Peer pattern mints CHIR to user while adding vault shares (and sometimes DETF) to pool.
        // Here: mint gross DETF to this contract, join (detfAmount for weight pairing + vault shares),
        // transfer user/fee/protocol slices from the unjoined remainder... 

        // Cleaner peer approach for live pool: join vault shares only, mint DETF to users without joining DETF.
        // Bootstrap first bond joins both legs. Live mint: vault-share single-sided join + mint DETF to users.
        if (s.isReserveLive && IERC20(s.reservePool).totalSupply() > 0) {
            _joinReserveVaultSharesOnly(vaultShares_);
            _mintDetf(recipient_, split_.userDetf);
            if (split_.feeToDetf > 0) _mintDetf(_feeTo(), split_.feeToDetf);
            if (split_.protocolDetf > 0) _mintDetf(address(s.bondNftVault), split_.protocolDetf);
            return split_.userDetf;
        }

        // Pre-live should only happen via bond bootstrap (joins both legs). Allow mint path only if live.
        revert SingleStandardExchangeDETFRepo.ReservePoolNotInitialized();
    }
}
