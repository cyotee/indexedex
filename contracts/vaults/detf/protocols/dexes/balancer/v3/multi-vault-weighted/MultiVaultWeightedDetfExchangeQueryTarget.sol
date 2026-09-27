// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {MultiVaultWeightedDetfExchangeInTarget} from "./MultiVaultWeightedDetfExchangeInTarget.sol";
import {MultiVaultWeightedDetfRepo as Repo} from "./MultiVaultWeightedDetfRepo.sol";

/// @notice Previews select the same branch after due expansion as execution.
abstract contract MultiVaultWeightedDetfExchangeQueryTarget is MultiVaultWeightedDetfExchangeInTarget {
    using BetterSafeERC20 for IERC20;

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
            (bool found_, uint256 leg_) = Repo._findVaultShareIndex(out_);
            if (!found_) revert Repo.InvalidRoute(address(in_), address(out_));
            return _previewPrimaryBurn()
                ? _previewBptUnwind(leg_, _bptForDetfShares(amount_, true))
                : _quoteReserveSwap(leg_, true, amount_);
        }
        if (address(out_) == address(this) || address(out_) == staking_) {
            (bool found_, uint256 leg_) = Repo._findVaultShareIndex(in_);
            if (!found_) revert Repo.InvalidRoute(address(in_), address(out_));
            return _previewPrimaryMint()
                ? _splitMintedDetf(_quoteDetfOutForVaultShares(leg_, amount_)).userDetf
                : _quoteReserveSwap(leg_, false, amount_);
        }
        revert Repo.InvalidRoute(address(in_), address(out_));
    }

    function previewExchangeOut(IERC20 in_, IERC20 out_, uint256 amount_) public view virtual returns (uint256) {
        if (!_directStakingRoute(in_, out_)) revert Repo.InvalidRoute(address(in_), address(out_));
        return amount_;
    }

    /// @dev Direct stake/unstake has an exact inverse; reserve routes retain the family's exact-in surface.
    function exchangeOut(
        IERC20 in_,
        uint256 maximum_,
        IERC20 out_,
        uint256 amount_,
        address to_,
        bool prepaid_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256) {
        if (!_directStakingRoute(in_, out_)) revert Repo.InvalidRoute(address(in_), address(out_));
        if (amount_ > maximum_) revert MaximumInputExceeded(maximum_, amount_);
        uint256 credit_;
        if (prepaid_) {
            LocalCreditLib.requirePretransferCaller(msg.sender);
            credit_ = LocalCreditLib.budget(
                LocalCreditLib.available(
                    in_.balanceOf(address(this)), MultiAssetBasicVaultRepo._reserveOfToken(address(in_))
                ),
                maximum_
            );
            if (amount_ > credit_) revert ISecurePullErrors.TransferDeltaInsufficient(amount_, credit_);
        }
        // Capture the bounded public credit before the shared body synchronizes books.
        _exchangeIn(in_, amount_, out_, amount_, to_, prepaid_, deadline_);
        if (prepaid_ && credit_ > amount_) in_.safeTransfer(msg.sender, credit_ - amount_);
        _syncAllExpectedHoldReserves();
        return amount_;
    }
}
