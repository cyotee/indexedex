// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {NativeStandardYieldValidation} from "./NativeStandardYieldDiscoveryTarget.sol";
import {NativeStandardYieldPreviewTarget} from "./NativeStandardYieldPreviewTarget.sol";
import {StandardExchangeInExecutionBase} from "contracts/vaults/standard/exchange/StandardExchangeInExecutionBase.sol";

/// @notice Native SY money entrypoints, independent of query implementation inheritance.
/// @dev Defined beside the aggregate to preserve its existing error namespace without an import cycle.
abstract contract NativeStandardYieldMoneyTarget is NativeStandardYieldValidation, StandardExchangeInExecutionBase {
    function deposit(address receiver_, address tokenIn_, uint256 amount_, uint256 minimum_)
        external payable returns (uint256 shares_)
    {
        if (msg.value != 0) revert NativeStandardYieldTarget.UnsupportedNativePayment();
        if (receiver_ == address(0)) revert NativeStandardYieldTarget.InvalidSYReceiver();
        if (amount_ == 0) revert NativeStandardYieldTarget.ZeroSYAmount();
        if (!isValidTokenIn(tokenIn_)) revert NativeStandardYieldTarget.InvalidSYToken(tokenIn_);
        shares_ = _standardRoute(IERC20(tokenIn_), amount_, IERC20(address(this)), minimum_, receiver_, false);
        if (shares_ == 0) revert NativeStandardYieldTarget.ZeroSYAmount();
        emit IStandardizedYield.Deposit(msg.sender, receiver_, tokenIn_, amount_, shares_);
    }

    function redeem(address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_, bool internalBalance_)
        external returns (uint256 amount_)
    {
        if (receiver_ == address(0)) revert NativeStandardYieldTarget.InvalidSYReceiver();
        if (shares_ == 0) revert NativeStandardYieldTarget.ZeroSYAmount();
        if (!isValidTokenOut(tokenOut_)) revert NativeStandardYieldTarget.InvalidSYToken(tokenOut_);
        if (internalBalance_) {
            LocalCreditLib.requirePretransferCaller(msg.sender);
            _requireVaultHeldShares(shares_);
            amount_ = _redeemVaultHeld(receiver_, shares_, tokenOut_, minimum_);
        } else {
            amount_ = _standardRoute(IERC20(address(this)), shares_, IERC20(tokenOut_), minimum_, receiver_, false);
        }
        if (amount_ < minimum_) revert NativeStandardYieldTarget.SYMinimumNotMet(minimum_, amount_);
        emit IStandardizedYield.Redeem(msg.sender, receiver_, tokenOut_, shares_, amount_);
    }

    function _standardRoute(IERC20 in_, uint256 amount_, IERC20 out_, uint256 minimum_, address receiver_, bool internal_)
        internal virtual returns (uint256 received_)
    {
        if (internal_) {
            _requireVaultHeldShares(amount_);
            received_ = _redeemVaultHeld(receiver_, amount_, address(out_), minimum_);
            if (received_ < minimum_) revert NativeStandardYieldTarget.SYMinimumNotMet(minimum_, received_);
            return received_;
        }
        received_ = _exchangeIn(in_, amount_, out_, minimum_, receiver_, false, block.timestamp);
        if (received_ < minimum_) revert NativeStandardYieldTarget.SYMinimumNotMet(minimum_, received_);
    }

    function _requireVaultHeldShares(uint256 shares_) internal view {
        uint256 held_ = _vaultHeldShares();
        if (held_ < shares_) revert ISecurePullErrors.TransferDeltaInsufficient(shares_, held_);
    }

    function _vaultHeldShares() internal view virtual returns (uint256) {
        return ERC20Repo._balanceOf(address(this));
    }

    function _redeemVaultHeld(address, uint256, address tokenOut_, uint256)
        internal virtual returns (uint256)
    {
        revert NativeStandardYieldTarget.InvalidSYToken(tokenOut_);
    }

}

abstract contract NativeStandardYieldRewardsTarget {
    function rewardIndexesCurrent() external virtual returns (uint256[] memory) { return new uint256[](0); }
    function claimRewards(address user_) external virtual returns (uint256[] memory amounts_) {
        amounts_ = new uint256[](0);
        emit IStandardizedYield.ClaimRewards(user_, new address[](0), amounts_);
    }
}

abstract contract NativeStandardYieldExecutionTarget is NativeStandardYieldMoneyTarget, NativeStandardYieldRewardsTarget {}

/// @notice Compatibility aggregate for families that host the complete native SY surface together.
/// @dev Split facets inherit only the execution or preview target. Error declarations stay here
///      so existing source-level references to NativeStandardYieldTarget errors remain valid.
abstract contract NativeStandardYieldTarget is NativeStandardYieldPreviewTarget, NativeStandardYieldExecutionTarget {
    error InvalidSYToken(address token);
    error InvalidSYReceiver();
    error ZeroSYAmount();
    error UnsupportedNativePayment();
    error SYMinimumNotMet(uint256 minimum, uint256 received);
}
