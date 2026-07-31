// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {
    MixedBufferMultiVaultStableDetfCommon
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfCommon.sol";
import {
    MixedBufferMultiVaultStableDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";

/// @title MixedBufferMultiVaultStableDetfExchangeOutTarget
/// @notice Exact-in burn DETF → bufferToken only. Vault-share outs revert InvalidRoute.
abstract contract MixedBufferMultiVaultStableDetfExchangeOutTarget is MixedBufferMultiVaultStableDetfCommon {
    using BetterSafeERC20 for IERC20;

    function _burnDetfExactInToBuffer(
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
            MixedBufferMultiVaultStableDetfRepo.Storage storage s0 =
                MixedBufferMultiVaultStableDetfRepo._layoutStruct();
            revert MixedBufferMultiVaultStableDetfRepo.BurningNotAllowed(_syntheticPrice(), s0.burnThreshold);
        }
        if (recipient_ == address(0)) recipient_ = msg.sender;

        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (address(tokenOut_) != address(s.bufferToken)) {
            revert MixedBufferMultiVaultStableDetfRepo.InvalidRoute(address(this), address(tokenOut_));
        }

        if (!pretransferred_) {
            IERC20(address(this)).safeTransferFrom(msg.sender, address(this), detfIn_);
        }

        uint256 bptIn_ = _bptForDetfShares(detfIn_);
        _burnDetf(address(this), detfIn_);

        (uint256 detfLeg_, uint256 bufferOut_, uint256[] memory vaultSharesOut_) = _exitReserveProportional(bptIn_);

        // Rejoin DETF + vault share legs so payout is buffer-only.
        if (detfLeg_ > 0) {
            _joinReserveDetfOnly(detfLeg_);
        }
        for (uint256 i; i < s.vaultCount; ++i) {
            if (vaultSharesOut_[i] > 0) {
                _joinReserveVaultShareOnly(i, vaultSharesOut_[i]);
            }
        }

        amountOut_ = bufferOut_;
        s.bufferToken.safeTransfer(recipient_, amountOut_);

        if (amountOut_ < minOut_) {
            revert IStandardExchangeErrors.MinAmountNotMet(minOut_, amountOut_);
        }
    }

    function _previewBurnDetfToBuffer(uint256 detfIn_) internal view returns (uint256 bufferOut_) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        uint256 bptIn_ = _bptForDetfShares(detfIn_);
        uint256 bptSupply_ = IERC20(s.reservePool).totalSupply();
        if (bptSupply_ == 0 || bptIn_ == 0) return 0;
        // Match execution: proportional exit buffer leg; DETF + share legs re-joined (not paid out).
        // Use live balances (same source router uses for proportional remove).
        uint256[] memory live_ = _reserveVault().getCurrentLiveBalances(s.reservePool);
        bufferOut_ = live_[s.bufferIndex] * bptIn_ / bptSupply_;
    }
}
