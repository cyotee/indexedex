// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_MigrationStateful} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/invariant/TestBase_MigrationStateful.sol";

/// @notice Stateful native properties 3/4/6/7/8/9/10/12, including separate real instances.
/// @dev Legacy custody properties 1/2/5/11 require pinned source targets, not this native ledger.
contract MigrationNativeInvariantTest is TestBase_MigrationStateful {
    function invariant_nativeLedgerAndPermanentLifecycle() public view {
        handler.assertAll();
    }

    function afterInvariant() public {
        handler.assertAll();
        emit log_named_uint("successful SUT actions", handler.successes());
        emit log_named_uint("exact rejected SUT actions", handler.rejections());
        emit log_named_uint("zero-valued valid claims (not positive witnesses)", handler.zeroClaims());
        emit log_named_uint("market action groups", handler.marketActions());
        emit log_named_uint("successful owner transitions", handler.ownershipActions());
        emit log_named_uint("actual later paid bonds", handler.laterPaidBonds());
        emit log_named_uint("actual later funded native rewards", handler.laterFundedRewards());
    }

    /// @notice Deterministic cliff boundaries and reward release do not rely on the random stream.
    function test_successfulWitnessCliffAndActivationSequence() public {
        uint256 start_ = block.timestamp;
        handler.claimPrincipal(0);
        vm.warp(start_ + 90 days - 1);
        handler.claimPrincipal(0);
        vm.warp(start_ + 90 days);
        handler.claimPrincipal(0);
        handler.claimRewards(0);
        handler.activate();
        handler.claimRewards(0);
        handler.rejectRoleRewards();
        handler.configure(0, 1);
        handler.issue(3);
        handler.activate();
        handler.transferOwner();
        handler.assertAll();
        afterInvariant();
    }

    /// @notice Later issuance has its own cliff; every position can transfer and claim.
    function test_allPositionsFreshCliffsAndLaterPaidGrowth() public {
        vm.warp(block.timestamp + 30 days);
        handler.issue(3);
        uint256 later_ = handler.positionCount() - 1;
        uint256 start_ = handler.positionStart(later_);
        handler.transferBond(later_);
        handler.claimPrincipal(later_);
        vm.warp(start_ + 90 days - 1);
        handler.claimPrincipal(later_);
        vm.warp(start_ + 90 days);
        handler.claimPrincipal(later_);
        vm.warp(start_ + 90 days + 1);
        handler.claimPrincipal(later_);
        handler.activate();
        handler.paidBond(127);
        handler.paidBond(249);
        uint256 count_ = handler.positionCount();
        for (uint256 i_; i_ < count_; ++i_) {
            handler.transferBond(i_);
            handler.claimPrincipal(i_);
            handler.claimRewards(i_);
        }
        vm.warp(block.timestamp + 90 days);
        for (uint256 i_; i_ < count_; ++i_) {
            handler.claimPrincipal(i_);
            handler.claimRewards(i_);
        }
        handler.rejectRoleRewards();
        handler.assertAll();
        afterInvariant();
    }
}

/// @notice The active state machine starts with mandatory later paid/rebase witnesses.
contract MigrationNativeActiveInvariantTest is TestBase_MigrationStateful {
    function setUp() public override {
        super.setUp();
        vm.warp(block.timestamp + 30 days);
        handler.issue(3);
        handler.transferBond(handler.positionCount() - 1);
        handler.claimPrincipal(handler.positionCount() - 1);
        handler.activate();
        handler.paidBond(127);
        handler.paidBond(249);
        handler.claimRewards(0);
    }

    function invariant_laterFundingAndAllPositionClaims() public view {
        handler.assertAll();
    }

    function afterInvariant() public {
        handler.assertAll();
        emit log_named_uint("successful active actions", handler.successes());
        emit log_named_uint("exact active rejections", handler.rejections());
        emit log_named_uint("actual later paid bonds", handler.laterPaidBonds());
        emit log_named_uint("actual later funded native rewards", handler.laterFundedRewards());
    }
}
