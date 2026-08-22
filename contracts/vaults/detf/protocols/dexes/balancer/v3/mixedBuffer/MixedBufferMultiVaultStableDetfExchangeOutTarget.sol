// SPDX-License-Identifier: BSL-1.1
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
/// @notice Exact-in burn DETF → bufferToken or a vault-share reserve leg (D12/D20).
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
        _updateExpansionMintOnRewards();
        if (!_isBurningAllowed()) {
            MixedBufferMultiVaultStableDetfRepo.Storage storage s0 =
                MixedBufferMultiVaultStableDetfRepo._layoutStruct();
            revert MixedBufferMultiVaultStableDetfRepo.BurningNotAllowed(_syntheticPrice(), s0.burnThreshold);
        }
        if (recipient_ == address(0)) recipient_ = msg.sender;

        uint256 outKind_ = _burnTokenOutKind(tokenOut_);
        uint256 actualIn_ = _pullToken(IERC20(address(this)), detfIn_, pretransferred_);
        uint256 bptIn_ = _bptForDetfShares(actualIn_);
        _burnDetf(address(this), actualIn_);

        (uint256 detfLeg_, uint256 bufOut_, uint256[] memory vaultSharesOut_) = _exitReserveProportional(bptIn_);
        _rejoinBurnNonOut(outKind_, detfLeg_, bufOut_, vaultSharesOut_);
        amountOut_ = _payBurnTokenOut(outKind_, bufOut_, vaultSharesOut_, recipient_);

        if (amountOut_ < minOut_) {
            revert IStandardExchangeErrors.MinAmountNotMet(minOut_, amountOut_);
        }
        _syncAllExpectedHoldReserves();
    }

    /// @dev 0 = bufferToken; 1+ = vault-share leg index + 1.
    function _burnTokenOutKind(IERC20 tokenOut_) private view returns (uint256 outKind_) {
        if (MixedBufferMultiVaultStableDetfRepo._isBufferToken(tokenOut_)) return 0;
        (bool found_, uint256 leg_) = MixedBufferMultiVaultStableDetfRepo._findVaultShareIndex(tokenOut_);
        if (!found_) {
            revert MixedBufferMultiVaultStableDetfRepo.InvalidRoute(address(this), address(tokenOut_));
        }
        return leg_ + 1;
    }

    function _rejoinBurnNonOut(
        uint256 outKind_,
        uint256 detfLeg_,
        uint256 bufOut_,
        uint256[] memory vaultSharesOut_
    ) private {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        uint256 rejoinBuf_ = outKind_ == 0 ? 0 : bufOut_;
        uint256[] memory rejoinShares_ = new uint256[](s.vaultCount);
        bool anyRejoin_ = detfLeg_ > 0 || rejoinBuf_ > 0;
        for (uint256 i; i < s.vaultCount; ++i) {
            rejoinShares_[i] = (outKind_ == i + 1) ? 0 : vaultSharesOut_[i];
            if (rejoinShares_[i] > 0) anyRejoin_ = true;
        }
        if (anyRejoin_) {
            _joinReserveLegs(detfLeg_, rejoinBuf_, rejoinShares_);
        }
    }

    function _payBurnTokenOut(
        uint256 outKind_,
        uint256 bufOut_,
        uint256[] memory vaultSharesOut_,
        address recipient_
    ) private returns (uint256 amountOut_) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (outKind_ == 0) {
            amountOut_ = bufOut_;
            if (amountOut_ > 0) s.bufferToken.safeTransfer(recipient_, amountOut_);
            return amountOut_;
        }
        uint256 leg_ = outKind_ - 1;
        amountOut_ = vaultSharesOut_[leg_];
        if (amountOut_ > 0) s.vaultShares[leg_].safeTransfer(recipient_, amountOut_);
    }

    function _previewBurnDetfToBuffer(uint256 detfIn_) internal view returns (uint256 bufferOut_) {
        return _previewBurnDetfToToken(MixedBufferMultiVaultStableDetfRepo._layoutStruct().bufferToken, detfIn_);
    }

    function _previewBurnDetfToToken(IERC20 tokenOut_, uint256 detfIn_) internal view returns (uint256 amountOut_) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        uint256 bptIn_ = _bptForDetfShares(detfIn_);
        uint256 bptSupply_ = IERC20(s.reservePool).totalSupply();
        if (bptSupply_ == 0 || bptIn_ == 0) return 0;
        uint256[] memory live_ = _reserveVault().getCurrentLiveBalances(s.reservePool);
        if (MixedBufferMultiVaultStableDetfRepo._isBufferToken(tokenOut_)) {
            return live_[s.bufferIndex] * bptIn_ / bptSupply_;
        }
        (bool found_, uint256 legIndex_) = MixedBufferMultiVaultStableDetfRepo._findVaultShareIndex(tokenOut_);
        if (!found_) return 0;
        return live_[s.shareIndexes[legIndex_]] * bptIn_ / bptSupply_;
    }
}
