// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_MigrationSourceUnits} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/invariant/TestBase_MigrationSourceUnits.sol";
import {MigrationSourceUnitsLedger} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/invariant/MigrationSourceUnitsLedger.sol";

/// @notice W-L/E-L/W-R/E-R/C/W-SD/W-SW/E-P/W-P/E-S each execute real custody in every prelude.
/// @dev No raw-weight surrender, claimed-origin preparation or disabled conversion admission.
contract MigrationSourceUnitsInvariantTest is TestBase_MigrationSourceUnits {
    function invariant_exactOriginalUnitsCustodyAndFreshEscrow() public view { handler.assertAll(); }

    function afterInvariant() public {
        handler.assertAll();
        for (uint256 i_; i_ < 10; ++i_) {
            assertGt(handler.surrenderSuccesses(i_), 0, "each source must actually surrender");
            assertGt(handler.fundingRollbacks(i_), 0, "each source must reach late funded-child failure");
            emit log_named_address("source-unit counter address", handler.source(i_));
            emit log_named_uint("source successful surrenders", handler.surrenderSuccesses(i_));
            emit log_named_uint("source exact rejected operations", handler.rejectionCounts(i_));
            emit log_named_uint("source late funded receipt rollbacks", handler.fundingRollbacks(i_));
            MigrationSourceUnitsLedger.Row memory r_ = handler.row(i_);
            emit log_named_uint("remaining eligible original units", r_.q);
            emit log_named_uint("remaining frozen credit", r_.c);
        }
        emit log_named_uint("canonical competing enrollment rejections", handler.enrollmentRejections());
        emit log_named_uint("successful admitted recovery stages", handler.recoveries());
        assertGt(handler.recoveries(), 0, "real harvest stages required");
        assertGt(handler.batchRollbacks(), 0, "whole harvest rollback required");
        emit log_named_uint("late whole recovery batch rollbacks", handler.batchRollbacks());
        emit log_named_uint("whole position principal paid", handler.principalPaid());
        emit log_named_uint("real source and bond transfers", handler.transfers());
        emit log_named_uint("actual ER source rate increases", handler.sourceRateChanges());
        emit log_named_uint("separate NFT-sale external ER shares", handler.earlierExternalShares());
    }

    /// @notice Scalar terminal credit and explicit nonrepresentable receipt residue, never confiscation.
    function test_allUnitsTerminalOrRetainedResidueAndLaterOwnCliffs() public {
        for (uint256 i_; i_ < 10; ++i_) {
            handler.surrender(i_, 0);
            MigrationSourceUnitsLedger.Row memory r_ = handler.row(i_);
            if (i_ == 2 || i_ == 3) {
                assertGt(r_.q, 0, "explicit retained nonrepresentable source units");
                assertGt(r_.c, 0, "explicit retained frozen credit");
                assertEq(handler.nativeMaximum(i_), 0);
            } else {
                assertEq(r_.q, 0); assertEq(r_.c, 0);
                assertEq(r_.delivered, r_.originalC);
            }
            handler.rejectExcess(i_);
            handler.removedConfiguration(i_);
        }
        uint256 count_ = handler.positionCount();
        uint256 lastStart_ = handler.positionStart(count_ - 1);
        vm.warp(lastStart_ + 90 days - 1);
        for (uint256 i_ = laterFirst; i_ < count_; ++i_) handler.claimPrincipal(i_);
        vm.warp(lastStart_ + 90 days);
        for (uint256 i_; i_ < count_; ++i_) {
            handler.transferBond(i_);
            handler.claimPrincipal(i_);
        }
        vm.warp(lastStart_ + 90 days + 1);
        for (uint256 i_; i_ < count_; ++i_) handler.claimPrincipal(i_);
        handler.assertAll();
        afterInvariant();
    }
}
