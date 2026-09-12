// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";
import {SingleStandardExchangeDETFExchangeOutTarget} from "./SingleStandardExchangeDETFExchangeOutTarget.sol";
import {SingleStandardExchangeDETFRepo as Repo} from "./SingleStandardExchangeDETFRepo.sol";

/// @notice Standard asset/DETF/sDETF routes with one common settlement and fee path.
abstract contract SingleStandardExchangeDETFExchangeInTarget is SingleStandardExchangeDETFExchangeOutTarget {
    using BetterSafeERC20 for IERC20;

    function exchangeIn(
        IERC20 in_, uint256 amount_, IERC20 out_, uint256 min_, address to_, bool prepaid_, uint256 deadline_
    ) public virtual nonReentrant returns (uint256 received_) {
        _requireActive(deadline_, amount_);
        if (address(in_) == address(out_)) revert Repo.UnsupportedRoute(in_, out_);
        Repo.Storage storage s_ = Repo._layoutStruct();
        IERC20 staking_ = IERC20(address(s_.rebasingClaimToken));
        if (address(in_) != address(this) && address(in_) != address(staking_)) _requireNotDisabled();
        if (to_ == address(0)) to_ = msg.sender;
        _updateExpansionMintOnRewards();

        if (address(in_) == address(staking_)) {
            _pullToken(in_, amount_, prepaid_);
            IStakedDETF(address(staking_)).exchangeIn(
                staking_, amount_, IERC20(address(this)), amount_, address(this), false, deadline_
            );
            if (address(out_) == address(this)) {
                received_ = amount_;
                out_.safeTransfer(to_, amount_);
            } else {
                received_ = _burnHeldDetf(amount_, out_, min_, to_, deadline_);
            }
        } else if (address(out_) == address(staking_)) {
            uint256 principal_ = address(in_) == address(this)
                ? _pullToken(in_, amount_, prepaid_)
                : _acquireDetf(_receiveVaultShares(in_, amount_, prepaid_, deadline_));
            IERC20(address(this)).forceApprove(address(staking_), principal_);
            received_ = IStakedDETF(address(staking_)).exchangeIn(
                IERC20(address(this)), principal_, staking_, min_, to_, false, deadline_
            );
            IERC20(address(this)).forceApprove(address(staking_), 0);
        } else if (address(in_) == address(this)) {
            received_ = _burnHeldDetf(_pullToken(in_, amount_, prepaid_), out_, min_, to_, deadline_);
        } else if (address(out_) == address(this)) {
            received_ = _acquireDetf(_receiveVaultShares(in_, amount_, prepaid_, deadline_));
            out_.safeTransfer(to_, received_);
        } else {
            if (!_isAllowlistedTokenIn(in_) || !_isAllowlistedTokenIn(out_)) revert Repo.UnsupportedRoute(in_, out_);
            received_ = _nestedExchangeInPush(
                s_.standardExchangeVault, in_, _pullToken(in_, amount_, prepaid_), out_, min_, to_, deadline_
            );
        }
        if (received_ < min_) revert IStandardExchangeErrors.MinAmountNotMet(min_, received_);
        _syncAllExpectedHoldReserves();
    }

    /// @dev Ordinary seigniorage is funded before any newly acquired DETF is staked.
    function _acquireDetf(uint256 shares_) internal returns (uint256 received_) {
        _requireReserveLive();
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (!_isMintingAllowed()) {
            return _reserveSwap(s_.reservePool, s_.standardExchangeVaultShare, IERC20(address(this)), shares_, 0);
        }
        MintSplit memory split_ = _splitMintedDetf(_quoteDetfOutForVaultShares(shares_));
        _joinReserveVaultSharesOnly(shares_);
        _mintDetf(address(this), split_.userDetf);
        _fundStakingRewards(split_.inventoryDetf);
        return split_.userDetf;
    }
    function previewJoinDonatedCapital(IERC20 token_, uint256 amount_) external view returns (uint256) {
        return _previewJoinDonatedCapital(token_, amount_);
    }
}
