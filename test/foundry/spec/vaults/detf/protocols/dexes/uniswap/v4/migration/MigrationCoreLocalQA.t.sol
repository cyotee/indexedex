// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {SafeTransferLib} from "@crane/contracts/tokens/ERC20/utils/SafeTransferLib.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {DETFFundedStakingMath as Math} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {UniswapV4DetfRepo as ParentRepo} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfRepo.sol";
import {TestBase_UniswapV4DetfMigration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation,
    IUniswapV4DetfMigrationAccounting as Accounting} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {MigrationCoreLocalOwner} from
    "scripts/foundry/recovery/dtf-migration/MigrationCoreLocalQA.s.sol";

/// @notice Actual external QA owner calls a real registry Migration with freshly wrapped fixture WETH.
contract MigrationCoreLocalQATest is TestBase_UniswapV4DetfMigration {
    MigrationCoreLocalOwner internal helper;
    uint256 internal donationA;
    uint256 internal donationB;
    uint256 internal compensationId;

    /// @notice Bootstrap the gold infrastructure, binding the actual helper as the initial owner.
    function setUp() public override {
        TestBase_ERC4626StandardExchange.setUp();
        payer = address(this);
        vm.deal(payer, 1_000_000 ether);
        helper = MigrationCoreLocalOwner(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "MigrationCoreLocalQA.s.sol:MigrationCoreLocalOwner"),
            abi.encode(address(this)), keccak256("migration.qa.helper.test")
        ));
        migrationOwner = address(helper);
        _migrationEnvironment();
        helper.bind(migration);
        IERC20[] memory tokens_ = new IERC20[](2);
        tokens_[0] = IERC20(pairA);
        tokens_[1] = IERC20(pairB);
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 100 ether;
        amounts_[1] = 100 ether;
        migration.donateMigrationCapital(tokens_, amounts_, 0, 0, block.timestamp + 1 hours);
        Migration.GenesisLeg[] memory legs_ = new Migration.GenesisLeg[](2);
        legs_[0] = Migration.GenesisLeg(IERC20(pairA), 50 ether, 1);
        legs_[1] = Migration.GenesisLeg(IERC20(pairB), 50 ether, 1);
        helper.bootstrap(legs_);
        donationA = migration.migrationDonationInventory(IERC20(pairA));
        donationB = migration.migrationDonationInventory(IERC20(pairB));
        assertGt(donationA, 0);
        assertGt(donationB, 0);
        (uint256 credit_, uint256 issuedId_) = helper.setConfigureIssue(1 ether, 1 ether, _manualInputs());
        compensationId = migration.independentIssuance(address(this)).bondTokenId;
        assertEq(compensationId, issuedId_);
        assertEq(compensationId, 3);
        assertEq(bonds.positionOf(compensationId).principal, credit_);
        assertEq(receipt.stakingState().accountedBacking, credit_);
        assertEq(IERC20(detf).balanceOf(address(receipt)), credit_);
        IERC20(pairA).approve(address(helper), 1 ether);
    }

    /// @notice Compensation issuance alone cannot satisfy the real paid activation guard.
    function test_helperMissingPurchaseRejectsActivationAtomically() public {
        bytes32 before_ = _economicState();
        vm.expectRevert(Migration.MigrationOwnerFirstBondRequired.selector);
        helper.activate();
        assertEq(_economicState(), before_);
        assertFalse(migration.migrationActivated());
        assertEq(migration.migrationOwnerFirstBondTokenId(), 0);
        assertTrue(IDiamondLoupe(detf).facetAddress(Allocation.activateMigration.selector) != address(0));
    }

    /// @notice Fresh controller payment creates a separate funded linear bond and enables real activation.
    function test_helperFreshPullFundsOrdinaryBondAndActivation() public {
        uint256 paidId_ = _assertHonestPurchase(0);
        vm.warp(bonds.positionOf(compensationId).startTimestamp + 90 days);
        vm.expectRevert(Accounting.MigrationRewardsClosed.selector);
        bonds.claimRewards(compensationId, address(this));
        vm.expectRevert(Accounting.MigrationRewardsClosed.selector);
        bonds.claimBond(compensationId, address(this));
        uint256 principal_ = bonds.positionOf(compensationId).principal;
        uint256 balance_ = receipt.balanceOf(address(this));
        assertEq(bonds.claimPrincipal(compensationId, address(this)), principal_);
        assertEq(receipt.balanceOf(address(this)) - balance_, principal_);
        assertEq(migration.migrationDonationInventory(IERC20(pairA)), donationA);
        assertEq(migration.migrationDonationInventory(IERC20(pairB)), donationB);
        helper.activate();
        assertTrue(migration.migrationActivated());
        assertEq(IDiamondLoupe(detf).facetAddress(Allocation.activateMigration.selector), address(0));
        assertEq(migration.migrationOwnerFirstBondTokenId(), paidId_);
        uint256 rewards_ = bonds.previewClaim(compensationId).rewardsDue;
        assertGt(rewards_, 0, "funded rewards remain claimable without a sweep");
        balance_ = receipt.balanceOf(address(this));
        assertEq(bonds.claimRewards(compensationId, address(this)), rewards_);
        assertEq(receipt.balanceOf(address(this)) - balance_, rewards_);
        assertEq(migration.migrationDonationInventory(IERC20(pairA)), donationA);
        assertEq(migration.migrationDonationInventory(IERC20(pairB)), donationB);
    }

    /// @notice Existing helper inventory never replaces or subsidizes the fresh controller pull.
    function test_helperPreservesPreexistingTokenSurplus() public {
        IERC20(pairA).transfer(address(helper), 7 ether);
        _assertHonestPurchase(7 ether);
    }

    /// @notice An unrelated caller cannot spend the controller's granted approval.
    function test_helperWrongControllerRollsBack() public {
        bytes32 before_ = _economicState();
        vm.prank(makeAddr("unrelated helper caller"));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "controller"));
        helper.buyOwnerFirstBond(IERC20(pairA), 1 ether, 90 days, block.timestamp + 1 hours);
        assertEq(_economicState(), before_);
    }

    /// @notice Even a stocked helper must reject a controller who has not approved its fresh pull.
    function test_helperMissingApprovalRollsBackWithSurplus() public {
        IERC20(pairA).transfer(address(helper), 7 ether);
        IERC20(pairA).approve(address(helper), 0);
        bytes32 before_ = _economicState();
        vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
        helper.buyOwnerFirstBond(IERC20(pairA), 1 ether, 90 days, block.timestamp + 1 hours);
        assertEq(_economicState(), before_);
    }

    /// @notice An approval cannot spend helper surplus when the controller lacks the full payment.
    function test_helperInsufficientControllerBalanceRollsBack() public {
        IERC20(pairA).transfer(address(helper), 7 ether);
        IERC20(pairA).transfer(makeAddr("fixture WETH holder"), IERC20(pairA).balanceOf(address(this)) - 0.5 ether);
        bytes32 before_ = _economicState();
        vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
        helper.buyOwnerFirstBond(IERC20(pairA), 1 ether, 90 days, block.timestamp + 1 hours);
        assertEq(_economicState(), before_);
    }

    /// @notice A downstream deadline rejection restores the fresh pull and both allowances.
    function test_helperExpiredDeadlineRollsBackFreshPull() public {
        vm.warp(block.timestamp + 1 days);
        uint256 deadline_ = block.timestamp - 1;
        bytes32 before_ = _economicState();
        vm.expectRevert(abi.encodeWithSelector(ParentRepo.DeadlineExpired.selector, deadline_));
        helper.buyOwnerFirstBond(IERC20(pairA), 1 ether, 90 days, deadline_);
        assertEq(_economicState(), before_);
    }

    /// @notice The single Stage 1 exception cannot fund another purchase or consume another fresh pull.
    function test_helperRepeatedStageOnePurchaseRollsBackFreshPull() public {
        uint256 paidId_ = _assertHonestPurchase(0);
        IERC20(pairA).approve(address(helper), 1 ether);
        bytes32 before_ = _economicState();
        vm.expectRevert(Accounting.MigrationRewardsClosed.selector);
        helper.buyOwnerFirstBond(IERC20(pairA), 1 ether, 90 days, block.timestamp + 1 hours);
        assertEq(_economicState(), before_);
        assertEq(migration.migrationOwnerFirstBondTokenId(), paidId_);
    }

    function _assertHonestPurchase(uint256 surplus_) private returns (uint256 paidId_) {
        (, uint256 principal_, uint256 rewards_, uint256 selfLeg_) =
            migration.previewBond(IERC20(pairA), 1 ether, 90 days);
        uint256 payment_ = IERC20(pairA).balanceOf(address(this));
        uint256 supply_ = IERC20(detf).totalSupply();
        uint256 backing_ = receipt.stakingState().accountedBacking;
        uint256 lp_ = IERC20(migration.hook()).balanceOf(address(bonds));
        vm.recordLogs();
        (uint256 returnedId_, uint256 lpOut_) =
            helper.buyOwnerFirstBond(IERC20(pairA), 1 ether, 90 days, block.timestamp + 1 hours);
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        uint256 mintedLp_;
        uint256 purchasedLp_;
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].emitter == migration.hook() && logs_[i_].topics.length == 3
                && logs_[i_].topics[0] == keccak256("Transfer(address,address,uint256)")
                && logs_[i_].topics[1] == bytes32(0)
                && logs_[i_].topics[2] == bytes32(uint256(uint160(address(bonds))))) {
                uint256 amount_ = abi.decode(logs_[i_].data, (uint256));
                if (mintedLp_ == 0) purchasedLp_ = amount_;
                mintedLp_ += amount_;
            }
        }
        paidId_ = migration.migrationOwnerFirstBondTokenId();
        assertEq(paidId_, returnedId_);
        assertEq(paidId_, 4);
        assertEq(IERC20(pairA).balanceOf(address(this)), payment_ - 1 ether);
        assertEq(IERC20(pairA).balanceOf(address(helper)), surplus_);
        assertEq(IERC20(pairA).allowance(address(this), address(helper)), 0);
        assertEq(IERC20(pairA).allowance(address(helper), detf), 0);
        assertGt(lpOut_, 0);
        assertEq(purchasedLp_, lpOut_, "returned LP is the paid join");
        assertEq(mintedLp_, lpOut_, "ordinary purchase must not mint additional sweep LP");
        assertEq(IERC20(migration.hook()).balanceOf(address(bonds)), lp_ + lpOut_,
            "only the paid join changes reserve LP during purchase");
        assertEq(IERC20(detf).totalSupply(), supply_ + principal_ + rewards_ + selfLeg_);
        assertEq(receipt.stakingState().accountedBacking, backing_ + principal_ + rewards_);
        assertEq(IERC20(detf).balanceOf(address(receipt)), backing_ + principal_ + rewards_);
        Math.BondPosition memory position_ = bonds.positionOf(paidId_);
        assertGt(position_.principal, 0);
        assertEq(position_.principal, principal_);
        assertEq(position_.claimedPrincipal, 0);
        assertEq(position_.stakingGons, principal_ * 1e36);
        assertEq(position_.startTimestamp, vm.getBlockTimestamp());
        assertEq(position_.vestingDuration, 90 days);
        assertFalse(bonds.isMigrationPosition(paidId_));
        assertEq(IERC721(address(bonds)).ownerOf(paidId_), address(this));
        assertTrue(bonds.isMigrationPosition(compensationId));
        assertEq(bonds.positionOf(compensationId).vestingDuration, 90 days);
        assertEq(IERC721(address(bonds)).ownerOf(compensationId), address(this));
        assertEq(migration.migrationDonationInventory(IERC20(pairA)), donationA);
        assertEq(migration.migrationDonationInventory(IERC20(pairB)), donationB);
        emit log_named_uint("queried compensation bond ID", migration.independentIssuance(address(this)).bondTokenId);
        emit log_named_uint("queried owner-first paid bond ID", paidId_);
    }

    function _economicState() private view returns (bytes32) {
        return keccak256(abi.encode(
            migration.migrationOwnerFirstBondTokenId(), migration.migrationActivated(),
            migration.owner(), address(helper.parent()), helper.controller(),
            IERC20(pairA).balanceOf(address(this)), IERC20(pairA).balanceOf(address(helper)),
            IERC20(pairA).balanceOf(detf), IERC20(pairB).balanceOf(detf),
            IERC20(pairA).allowance(address(this), address(helper)),
            IERC20(pairA).allowance(address(helper), detf),
            IERC20(detf).totalSupply(), IERC20(detf).balanceOf(address(receipt)),
            IERC20(migration.hook()).balanceOf(address(bonds)), IERC20(migration.hook()).totalSupply(),
            receipt.stakingState(), receipt.balanceOf(address(this)), bonds.positionOf(compensationId),
            migration.independentIssuance(address(this)),
            migration.migrationDonationInventory(IERC20(pairA)), migration.migrationDonationInventory(IERC20(pairB)),
            IDiamondLoupe(detf).facetAddress(Allocation.activateMigration.selector)
        ));
    }
}
