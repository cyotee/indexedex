// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ReentrancyLockRepo} from "@crane/contracts/access/reentrancy/ReentrancyLockRepo.sol";
import {IERC721Receiver} from "@crane/contracts/interfaces/IERC721Receiver.sol";
import {IERC721Errors} from "@crane/contracts/interfaces/IERC721Errors.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {DETFFundedBondTarget} from "contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol";
import {DETFFundedBondRepo as BondRepo} from "contracts/vaults/detf/common/bondNft/DETFFundedBondRepo.sol";
import {DETFFundedStakingMath as StakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {IUniswapV4DetfMigration, IUniswapV4DetfMigrationAccounting as Accounting}
    from "../interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationStakedDETF} from "../claimToken/IUniswapV4DetfMigrationStakedDETF.sol";
import {IUniswapV4DetfMigrationBondNFTVault} from "./IUniswapV4DetfMigrationBondNFTVault.sol";
import {UniswapV4DetfMigrationBondNFTRepo as MigrationRepo} from "./UniswapV4DetfMigrationBondNFTRepo.sol";

/// @notice Real funded bond custody with fresh Migration cliffs and gated reward delivery.
/// @dev Inherited claims and all three ERC721 transfers consume the synchronization overrides.
contract UniswapV4DetfMigrationBondNFTVaultTarget is DETFFundedBondTarget {
    /// @notice Ordinary active purchases retain linear terms and never acquire a Migration marker.
    function createFundedPosition(uint256 principal_, uint256 duration_, address recipient_)
        external override onlyDetf synchronized nonReentrant returns (uint256 tokenId_)
    {
        _requireActivated();
        return _createFundedPosition(principal_, duration_, recipient_);
    }

    /// @notice Only the wired parent can fund a fresh 90-day cliff, using actual pulled DETF.
    function createMigrationPosition(uint256 principal_, address recipient_)
        external onlyDetf synchronized nonReentrant returns (uint256 tokenId_)
    {
        tokenId_ = _createFundedPosition(principal_, 90 days, recipient_);
        MigrationRepo._layoutStruct().migrationPosition[tokenId_] = true;
        if (recipient_.code.length != 0) {
            if (IERC721Receiver(recipient_).onERC721Received(msg.sender, address(0), tokenId_, "")
                != IERC721Receiver.onERC721Received.selector) {
                revert IERC721Errors.ERC721InvalidReceiver(recipient_);
            }
        }
        emit IUniswapV4DetfMigrationBondNFTVault.MigrationPositionCreated(
            tokenId_, recipient_, principal_, block.timestamp, block.timestamp + 90 days
        );
    }

    /// @notice Persistent policy identity, including after canonical retirement; no eligibility cache.
    function isMigrationPosition(uint256 tokenId_) external view returns (bool) {
        return MigrationRepo._layoutStruct().migrationPosition[tokenId_];
    }

    /// @notice Actual post-debit position aggregate, read by receipt delivery and dust retirement.
    function attributedBondGons() external view returns (uint256) {
        return BondRepo._layoutStruct().attributedGons;
    }

    /// @notice Include inherited custody/donation locks, not just explicitly synchronized entries.
    function migrationAccountingPhase() external view returns (uint8) {
        return uint8(_accountingPhase());
    }

    function _calculateClaim(uint256 tokenId_, uint256 k_)
        internal view override returns (StakingMath.BondClaim memory claim_)
    {
        // Canonical math remains the sole staking-value, deficit and reward calculation.
        claim_ = super._calculateClaim(tokenId_, k_);
        if (MigrationRepo._layoutStruct().migrationPosition[tokenId_]) {
            StakingMath.BondPosition storage position_ = BondRepo._layoutStruct().positions[tokenId_];
            claim_.vestedPrincipal = block.timestamp >= position_.startTimestamp + position_.vestingDuration
                ? position_.principal : 0;
            claim_.principalDue = claim_.vestedPrincipal - position_.claimedPrincipal;
        }
    }

    function _claim(uint256 tokenId_, address recipient_, bool principalClaim_, bool rewardClaim_)
        internal override returns (uint256 principal_, uint256 rewards_)
    {
        // Combined/rewards-only requests reject even when their computed reward is zero.
        if (rewardClaim_) _requireActivated();
        return super._claim(tokenId_, recipient_, principalClaim_, rewardClaim_);
    }

    function _deliverClaim(
        IStakedDETF staking_, address recipient_, uint256 principal_, uint256 rewards_, uint256 k_
    ) internal override {
        IUniswapV4DetfMigrationStakedDETF(address(staking_)).deliverBondClaim(
            recipient_, principal_, rewards_, k_
        );
    }

    function _beforeSynchronized() internal override {
        Accounting.AccountingPhase phase_ = _accountingPhase();
        if (phase_ != Accounting.AccountingPhase.Idle) {
            revert Accounting.MigrationAccountingBusy(address(this), uint8(phase_));
        }
        MigrationRepo.Storage storage s_ = MigrationRepo._layoutStruct();
        s_.phase = Accounting.AccountingPhase.Synchronizing;
        // Also exclude inherited donation/custody entries while the parent can call out.
        // The entry's normal nonReentrant modifier takes over after synchronization.
        ReentrancyLockRepo._lock();
        super._beforeSynchronized();
        ReentrancyLockRepo._unlock();
        s_.phase = Accounting.AccountingPhase.Accounting;
    }

    function _afterSynchronized() internal override {
        MigrationRepo._layoutStruct().phase = Accounting.AccountingPhase.Idle;
    }

    function _accountingPhase() internal view returns (Accounting.AccountingPhase phase_) {
        phase_ = MigrationRepo._layoutStruct().phase;
        if (phase_ == Accounting.AccountingPhase.Idle && ReentrancyLockRepo._isLocked()) {
            return Accounting.AccountingPhase.Accounting;
        }
    }

    function _requireActivated() private view {
        if (!IUniswapV4DetfMigration(BondRepo._layoutStruct().detf).migrationActivated()) {
            revert Accounting.MigrationRewardsClosed();
        }
    }
}
