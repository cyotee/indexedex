// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {
    SingleStandardExchangeDETFCommon
} from "contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETFCommon.sol";
import {
    SingleStandardExchangeDETFRepo
} from "contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETFRepo.sol";

/// @title SingleStandardExchangeDETFExchangeOutTarget
/// @notice Exact-in burn of DETF to vault shares (and optional SE redeem). Uses exchangeIn surface
///         for burn (tokenIn = self) as peer DETFs do; exchangeOut reserved for closed-form inverse.
abstract contract SingleStandardExchangeDETFExchangeOutTarget is SingleStandardExchangeDETFCommon {
    using BetterSafeERC20 for IERC20;

    /// @dev Burn path also lives on exchangeIn when tokenIn is DETF — implement here as helper.
    function _burnDetfExactIn(
        uint256 detfIn_,
        IERC20 tokenOut_,
        uint256 minOut_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) internal returns (uint256 amountOut_) {
        _requireReserveLive();
        _requireActive(deadline_, detfIn_);
        if (!_isBurningAllowed()) {
            SingleStandardExchangeDETFRepo.Storage storage s0 = SingleStandardExchangeDETFRepo._layoutStruct();
            revert SingleStandardExchangeDETFRepo.BurningNotAllowed(_syntheticPrice(), s0.burnThreshold);
        }
        if (recipient_ == address(0)) recipient_ = msg.sender;

        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        if (!pretransferred_) {
            // pull DETF via transferFrom
            IERC20(address(this)).safeTransferFrom(msg.sender, address(this), detfIn_);
        }
        // Compute BPT claim against pre-burn supply so previewExchangeIn matches execution.
        uint256 bptIn_ = _bptForDetfShares(detfIn_);
        _burnDetf(address(this), detfIn_);

        (uint256 detfLeg_, uint256 vaultSharesOut_) = _exitReserveProportional(bptIn_);

        // Exit already returned DETF ERC20 to this diamond (tokens that were in the pool).
        // Redeposit that leg so the burn pays out vault-share side only — do NOT mint extra DETF.
        if (detfLeg_ > 0) {
            _joinReserveDetfOnly(detfLeg_);
        }

        if (address(tokenOut_) == address(s.standardExchangeVaultShare)) {
            s.standardExchangeVaultShare.safeTransfer(recipient_, vaultSharesOut_);
            amountOut_ = vaultSharesOut_;
        } else if (_isAllowlistedTokenIn(tokenOut_)) {
            s.standardExchangeVaultShare.safeTransfer(address(s.standardExchangeVault), vaultSharesOut_);
            amountOut_ = s.standardExchangeVault.exchangeIn(
                s.standardExchangeVaultShare,
                vaultSharesOut_,
                tokenOut_,
                minOut_,
                recipient_,
                true,
                deadline_
            );
        } else {
            revert SingleStandardExchangeDETFRepo.UnsupportedRoute(IERC20(address(this)), tokenOut_);
        }

        if (amountOut_ < minOut_) {
            revert IStandardExchangeErrors.MinAmountNotMet(minOut_, amountOut_);
        }
    }

    function _joinReserveDetfOnly(uint256 detfAmount_) internal {
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        uint256 n_ = _reserveVault().getCurrentLiveBalances(s.reservePool).length;
        uint256[] memory amountsIn_ = new uint256[](n_);
        amountsIn_[s.detfIndex] = detfAmount_;
        IERC20(address(this)).safeTransfer(address(_reserveVault()), detfAmount_);
        _reserveRouter().prepayAddLiquidityUnbalanced(s.reservePool, amountsIn_, 0, "");
    }
}
