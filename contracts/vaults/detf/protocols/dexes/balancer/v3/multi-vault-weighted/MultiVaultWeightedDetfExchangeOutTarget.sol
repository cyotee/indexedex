// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {
    MultiVaultWeightedDetfCommon
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfCommon.sol";
import {
    MultiVaultWeightedDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfRepo.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";

/// @title MultiVaultWeightedDetfExchangeOutTarget
/// @notice Exact-in burn of DETF to a configured vault share. Exact-out binary-search routes revert InvalidRoute.
abstract contract MultiVaultWeightedDetfExchangeOutTarget is MultiVaultWeightedDetfCommon {
    using BetterSafeERC20 for IERC20;

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
            MultiVaultWeightedDetfRepo.Storage storage s0 = MultiVaultWeightedDetfRepo._layoutStruct();
            revert MultiVaultWeightedDetfRepo.BurningNotAllowed(_syntheticPrice(), s0.burnThreshold);
        }
        if (recipient_ == address(0)) recipient_ = msg.sender;

        (bool found_, uint256 legIndex_) = MultiVaultWeightedDetfRepo._findVaultShareIndex(tokenOut_);
        if (!found_) {
            revert MultiVaultWeightedDetfRepo.InvalidRoute(address(this), address(tokenOut_));
        }

        // Reserve-delta detfToken pull (L-DETF-LOCAL-PUSH / L-GAPS-9).
        uint256 actualIn_ = _pullToken(IERC20(address(this)), detfIn_, pretransferred_);

        uint256 bptIn_ = _bptForDetfShares(actualIn_);
        _burnDetf(address(this), actualIn_);

        (uint256 detfLeg_, uint256[] memory vaultSharesOut_) = _exitReserveProportional(bptIn_);

        // Redeposit DETF leg and other vault legs so payout is single-sided target share.
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        if (detfLeg_ > 0) {
            _joinReserveDetfOnly(detfLeg_);
        }
        for (uint256 i; i < s.vaultCount; ++i) {
            if (i == legIndex_) continue;
            if (vaultSharesOut_[i] > 0) {
                _joinReserveVaultShareOnly(i, vaultSharesOut_[i]);
            }
        }

        amountOut_ = vaultSharesOut_[legIndex_];
        s.vaultShares[legIndex_].safeTransfer(recipient_, amountOut_);

        if (amountOut_ < minOut_) {
            revert IStandardExchangeErrors.MinAmountNotMet(minOut_, amountOut_);
        }
        _syncAllExpectedHoldReserves();
    }

    /// @dev Preview burn DETF → vault share (proportional BPT claim on target leg only after re-join others).
    function _previewBurnDetfToVaultShare(uint256 detfIn_, uint256 legIndex_)
        internal
        view
        returns (uint256 vaultSharesOut_)
    {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        uint256 bptIn_ = _bptForDetfShares(detfIn_);
        uint256 bptSupply_ = IERC20(s.reservePool).totalSupply();
        if (bptSupply_ == 0 || bptIn_ == 0) return 0;
        (,, uint256[] memory balancesRaw_,) = _reserveVault().getPoolTokenInfo(s.reservePool);
        // Proportional exit then re-join detf + other shares leaves target leg amount ≈ proportional claim.
        vaultSharesOut_ = balancesRaw_[s.vaultShareIndexes[legIndex_]] * bptIn_ / bptSupply_;
    }
}
