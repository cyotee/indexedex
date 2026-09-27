// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";
import {MultiVaultWeightedDetfExchangeOutTarget} from "./MultiVaultWeightedDetfExchangeOutTarget.sol";
import {MultiVaultWeightedDetfRepo as Repo} from "./MultiVaultWeightedDetfRepo.sol";

/// @notice Configured shares route through the reserve; raw DETF and sDETF use funded staking.
abstract contract MultiVaultWeightedDetfExchangeInTarget is MultiVaultWeightedDetfExchangeOutTarget {
    using BetterSafeERC20 for IERC20;

    function exchangeIn(
        IERC20 in_, uint256 amount_, IERC20 out_, uint256 minimum_, address to_, bool prepaid_, uint256 deadline_
    ) public virtual nonReentrant returns (uint256 received_) {
        _requireActive(deadline_, amount_);
        if (address(in_) == address(out_)) revert Repo.InvalidRoute(address(in_), address(out_));
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
            } else received_ = _burnHeldDetf(amount_, out_, minimum_, to_);
        } else if (address(out_) == address(staking_)) {
            uint256 principal_ = address(in_) == address(this)
                ? _pullToken(in_, amount_, prepaid_) : _acquireDetf(in_, amount_, prepaid_);
            IERC20(address(this)).forceApprove(address(staking_), principal_);
            received_ = IStakedDETF(address(staking_)).exchangeIn(
                IERC20(address(this)), principal_, staking_, minimum_, to_, false, deadline_
            );
            IERC20(address(this)).forceApprove(address(staking_), 0);
        } else if (address(in_) == address(this)) {
            received_ = _burnHeldDetf(_pullToken(in_, amount_, prepaid_), out_, minimum_, to_);
        } else if (address(out_) == address(this)) {
            received_ = _acquireDetf(in_, amount_, prepaid_);
            out_.safeTransfer(to_, received_);
        } else revert Repo.InvalidRoute(address(in_), address(out_));
        if (received_ < minimum_) revert IStandardExchangeErrors.MinAmountNotMet(minimum_, received_);
        _syncAllExpectedHoldReserves();
    }

    function _acquireDetf(IERC20 in_, uint256 amount_, bool prepaid_) internal returns (uint256) {
        _requireReserveLive();
        (bool found_, uint256 leg_) = Repo._findVaultShareIndex(in_);
        if (!found_) revert Repo.InvalidRoute(address(in_), address(this));
        uint256 shares_ = _pullToken(in_, amount_, prepaid_);
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (!_isMintingAllowed()) {
            return _reserveSwap(s_.reservePool, in_, IERC20(address(this)), shares_, 0);
        }
        MintSplit memory split_ = _splitMintedDetf(_quoteDetfOutForVaultShares(leg_, shares_));
        _custodyBptOnNft(_joinReserveVaultShareOnly(leg_, shares_));
        _mintDetf(address(this), split_.userDetf);
        _fundStakingRewards(split_.inventoryDetf);
        return split_.userDetf;
    }
}
