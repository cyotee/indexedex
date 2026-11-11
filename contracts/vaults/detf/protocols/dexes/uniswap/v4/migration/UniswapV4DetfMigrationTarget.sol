// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {UniswapV4DetfMigrationPolicy} from "./UniswapV4DetfMigrationPolicy.sol";
import {UniswapV4DetfMigrationRepo as Repo} from "./UniswapV4DetfMigrationRepo.sol";
import {UniswapV4DetfRepo as ParentRepo} from "../detf/UniswapV4DetfRepo.sol";
import {IUniswapV4DetfMigration as Migration} from "./interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationSnapshot as Snapshot} from "./interfaces/IUniswapV4DetfMigrationSnapshot.sol";
import {UniswapV4DetfMigrationSnapshotLib as SnapshotLib} from "./UniswapV4DetfMigrationSnapshotLib.sol";

/// @notice Permanent lifecycle reads and permissionless measured capital contributions.
contract UniswapV4DetfMigrationTarget is UniswapV4DetfMigrationPolicy {
    using BetterSafeERC20 for IERC20;
    using AddressSetRepo for AddressSet;

    function migrationActivated() external view returns (bool) { return Repo._layoutStruct().activated; }
    function migrationSyRewardToken() external view returns (address) { return Repo._layoutStruct().rewardToken; }
    function migrationBootstrapSelfMinted() external view returns (uint256) {
        return Repo._layoutStruct().bootstrapSelfMinted;
    }
    function migrationDonationInventory(IERC20 token_) external view returns (uint256) {
        return Repo._layoutStruct().donationInventory[address(token_)];
    }
    function migrationSnapshotSource() public view returns (Snapshot.Source memory) {
        Repo.Storage storage m_ = Repo._layoutStruct();
        return Snapshot.Source(address(this), address(ParentRepo._layoutStruct().feeOracle), m_.weth, m_.originalDtf);
    }
    function migrationSnapshot() external view returns (Snapshot.Snapshot memory) { return Repo._snapshot(); }
    function previewOriginalCredit(uint256 eth_, uint256 dtf_) external view returns (uint256) {
        return SnapshotLib.evaluateOriginals(Repo._snapshot(), eth_, dtf_);
    }
    function independentAllocation(address recipient_) external view returns (Migration.IndependentAllocation memory) {
        return Repo._layoutStruct().allocations[recipient_];
    }
    function independentIssuance(address recipient_) external view returns (Migration.IndependentIssuance memory) {
        return Repo._layoutStruct().issuances[recipient_];
    }

    function donateMigrationCapital(
        IERC20[] calldata tokens_, uint256[] calldata amounts_, uint256 nativeAmount_,
        uint256 minLpOut_, uint256 deadline_
    ) external payable nonReentrant returns (uint256 lpOut_) {
        _requireIdleChildren();
        _requireNotDisabled();
        if (block.timestamp > deadline_) revert ParentRepo.DeadlineExpired(deadline_);
        if (msg.value != nativeAmount_) revert Migration.UnexpectedMigrationNativeValue(nativeAmount_, msg.value);
        if (tokens_.length != amounts_.length || (tokens_.length == 0 && nativeAmount_ == 0)) {
            revert ParentRepo.ZeroAmount();
        }
        bool live_ = ParentRepo._layoutStruct().isReserveLive;
        if (!live_ && minLpOut_ != 0) revert IStandardExchangeErrors.MinAmountNotMet(minLpOut_, 0);
        Repo.Storage storage m_ = Repo._layoutStruct();
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            for (uint256 j_; j_ < i_; ++j_) {
                if (tokens_[j_] == tokens_[i_]) revert Migration.InvalidGenesisLeg(address(tokens_[i_]));
            }
            _requireDonationToken(address(tokens_[i_]));
            _requireActive(deadline_, amounts_[i_]);
            _pullToken(tokens_[i_], amounts_[i_], false);
            m_.donationInventory[address(tokens_[i_])] += amounts_[i_];
            emit Migration.MigrationCapitalReceived(msg.sender, address(tokens_[i_]), amounts_[i_]);
        }
        if (nativeAmount_ != 0) {
            _requireDonationToken(m_.weth);
            uint256 before_ = IERC20(m_.weth).balanceOf(address(this));
            IWETH(m_.weth).deposit{value: nativeAmount_}();
            if (IERC20(m_.weth).balanceOf(address(this)) - before_ != nativeAmount_) revert ParentRepo.ZeroAmount();
            m_.donationInventory[m_.weth] += nativeAmount_;
            emit Migration.MigrationCapitalReceived(msg.sender, m_.weth, nativeAmount_);
        }
        if (live_) {
            uint256 beforeLp_ = IERC20(ParentRepo._layoutStruct().hook).balanceOf(_bondLpHolder());
            _beginBudget();
            // Release only this call's receipts into the sweep budget, never older donations.
            for (uint256 i_; i_ < tokens_.length; ++i_) _releaseDonation(address(tokens_[i_]), amounts_[i_]);
            if (nativeAmount_ != 0) _releaseDonation(m_.weth, nativeAmount_);
            _sweepDustBody();
            _endBudget();
            lpOut_ = IERC20(ParentRepo._layoutStruct().hook).balanceOf(_bondLpHolder()) - beforeLp_;
            if (lpOut_ < minLpOut_) revert IStandardExchangeErrors.MinAmountNotMet(minLpOut_, lpOut_);
        }
        _syncAllExpectedHoldReserves();
    }

    function _releaseDonation(address token_, uint256 amount_) private {
        Repo.Storage storage m_ = Repo._layoutStruct();
        m_.donationInventory[token_] -= amount_;
        m_.operationFloor[token_] -= amount_;
        emit Migration.MigrationCapitalConsumed(token_, amount_);
    }

    function _requireDonationToken(address token_) private view {
        ParentRepo.Storage storage s_ = ParentRepo._layoutStruct();
        // Genesis accepts actual pair/share representations, not a broadened route enum.
        if (token_ == address(this) || !s_.donateTable.tokens._contains(token_)) {
            revert Migration.InvalidGenesisLeg(token_);
        }
        if (!s_.hookPairTokens._contains(token_) && !s_.hookStandardExchanges._contains(token_)) {
            revert Migration.InvalidGenesisLeg(token_);
        }
    }
}
