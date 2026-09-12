// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {MixedBufferMultiVaultStableDetfExchangeInTarget} from "./MixedBufferMultiVaultStableDetfExchangeInTarget.sol";
import {MixedBufferMultiVaultStableDetfRepo as Repo} from "./MixedBufferMultiVaultStableDetfRepo.sol";

/// @notice Previews select the same branch after due expansion as execution.
abstract contract MixedBufferMultiVaultStableDetfExchangeQueryTarget is MixedBufferMultiVaultStableDetfExchangeInTarget {
    error MaximumInputExceeded(uint256 maximum, uint256 required);

    function _directStakingRoute(IERC20 in_, IERC20 out_) internal view returns (bool) {
        address staking_ = address(Repo._layoutStruct().rebasingClaimToken);
        return (address(in_) == address(this) && address(out_) == staking_)
            || (address(in_) == staking_ && address(out_) == address(this));
    }

    function previewExchangeIn(IERC20 in_, uint256 amount_, IERC20 out_) public view virtual returns (uint256) {
        if (_directStakingRoute(in_, out_)) return amount_;
        if (address(in_) == address(out_)) revert Repo.InvalidRoute(address(in_), address(out_));
        _requireReserveLive();
        address staking_ = address(Repo._layoutStruct().rebasingClaimToken);
        if (address(in_) == address(this) || address(in_) == staking_) {
            return _previewBurnToken(out_, amount_);
        }
        if (address(out_) == address(this) || address(out_) == staking_) {
            uint256 index_ = _paymentIndex(in_);
            return _previewPrimaryMint()
                ? _splitMintedDetf(_quoteOrdinaryDetf(in_, amount_)).userDetf
                : _quoteSwap(index_, Repo._layoutStruct().detfIndex, amount_);
        }
        revert Repo.InvalidRoute(address(in_), address(out_));
    }

    function previewExchangeOut(IERC20 in_, IERC20 out_, uint256 amount_) public view virtual returns (uint256) {
        if (!_directStakingRoute(in_, out_)) revert Repo.InvalidRoute(address(in_), address(out_));
        return amount_;
    }

    /// @dev Direct stake/unstake has an exact inverse; reserve routes retain the family's exact-in surface.
    function exchangeOut(
        IERC20 in_, uint256 maximum_, IERC20 out_, uint256 amount_, address to_, bool prepaid_, uint256 deadline_
    ) public virtual returns (uint256) {
        if (!_directStakingRoute(in_, out_)) revert Repo.InvalidRoute(address(in_), address(out_));
        if (amount_ > maximum_) revert MaximumInputExceeded(maximum_, amount_);
        return exchangeIn(in_, amount_, out_, amount_, to_, prepaid_, deadline_);
    }
}
