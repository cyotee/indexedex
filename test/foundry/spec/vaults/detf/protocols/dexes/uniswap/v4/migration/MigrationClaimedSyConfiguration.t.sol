// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV4DetfMigrationWeightedPricingV3 as PricingV3, IUniswapV4DetfMigrationWeightedPricingAllocationV3 as AllocationV3} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationWeightedPricingV3.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {TestBase_UniswapV4DetfMigration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {MigrationLegacyRecoveryLib as Legacy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol";

import {IUniswapV4DetfMigrationWeightedPricing as Pricing} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationWeightedPricing.sol";

/// @notice Synthetic eligibility fractions, not evidence of approved historical exclusions or allocations.
contract MigrationClaimedSyConfigurationTest is TestBase_UniswapV4DetfMigration {
    bytes32 constant ORIGIN = bytes32("synthetic remaining original");

    function setUp() public override {
        vm.chainId(4663);
        super.setUp();
        _fundAndCapture();
    }

    function _input() private view returns (Migration.ClaimedSyEntitlementInput[] memory a_) {
        a_ = new Migration.ClaimedSyEntitlementInput[](1);
        a_[0] = Migration.ClaimedSyEntitlementInput(
            Migration.WeightedSyEntitlementInput(
                ORIGIN, address(this), Legacy.WEIGHTED_SY, 7, 1 ether, 1 ether, bytes32("synthetic evidence"), true
            ), 3 ether, 2 ether
        );
    }

    /// @notice Scaling the whole frozen quote differs from quoting scaled contributions.
    function test_fullOriginalQuoteThenFractionAndHashBindBothWeights() public {
        Migration.ClaimedSyEntitlementInput[] memory a_ = _input();
        uint256 full_ = migration.previewOriginalCredit(1 ether, 1 ether);
        uint256 expected_ = full_ * 2 / 3;
        uint256 requoted_ = migration.previewOriginalCredit(uint256(2 ether) / 3, uint256(2 ether) / 3);
        assertNotEq(expected_, requoted_);
        uint256 supply_ = IERC20(detf).totalSupply();
        vm.prank(migrationOwner);
        allocation.configureClaimedSyEntitlements(a_, pricingId);
        Migration.WeightedSyEntitlement memory c_ = migration.weightedSyEntitlement(ORIGIN);
        assertEq(c_.credit, expected_);
        assertEq(c_.original.originalEth, 1 ether);
        assertEq(c_.original.originalDtf, 1 ether);
        assertEq(c_.original.originalUnits, 7);
        assertEq(c_.configurationId, keccak256(abi.encode(block.chainid, detf, PricingV3(address(migration)).migrationWeightedPricingV3().id, a_[0])));
        (uint256 original_, uint256 eligible_) = migration.claimedSyWeights(ORIGIN);
        assertEq(original_, 3 ether);
        assertEq(eligible_, 2 ether);
        assertEq(migration.weightedSySurrender(ORIGIN).remainingCredit, expected_);
        assertEq(migration.previewWeightedSySurrender(ORIGIN, 7), expected_);
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(receipt.stakingState().totalGons, 0);
    }

    /// @notice 512-bit products are accepted; zero, inverted bounds and zero-credit dust reject.
    function test_weightBoundsZeroCreditAndOverflowSafeProduct() public {
        Migration.ClaimedSyEntitlementInput[] memory a_ = _input();
        uint256 full_ = migration.previewOriginalCredit(1 ether, 1 ether);
        a_[0].originalWeight = type(uint256).max - 1;
        a_[0].eligibleWeight = (type(uint256).max - 1) / 2;
        assertGt(full_, type(uint256).max / a_[0].eligibleWeight);
        vm.prank(migrationOwner);
        allocation.configureClaimedSyEntitlements(a_, pricingId);
        assertEq(migration.weightedSyEntitlement(ORIGIN).credit, full_ / 2);
        a_[0].eligibleWeight = a_[0].originalWeight;
        vm.prank(migrationOwner);
        allocation.configureClaimedSyEntitlements(a_, pricingId);
        assertEq(migration.weightedSyEntitlement(ORIGIN).credit, full_);
        bytes memory before_ = abi.encode(migration.weightedSyEntitlement(ORIGIN));
        for (uint256 i_; i_ < 5; ++i_) {
            a_ = _input();
            if (i_ == 0) a_[0].originalWeight = 0;
            else if (i_ == 1) a_[0].eligibleWeight = 0;
            else if (i_ == 2) a_[0].eligibleWeight = a_[0].originalWeight + 1;
            else if (i_ == 3) {
                a_[0].originalWeight = type(uint256).max;
                a_[0].eligibleWeight = 1;
            } else {
                a_[0].original.originalEth = 0;
                a_[0].original.originalDtf = 0;
            }
            vm.prank(migrationOwner);
            vm.expectRevert(abi.encodeWithSelector(Migration.InvalidWeightedSyEntitlement.selector, ORIGIN));
            allocation.configureClaimedSyEntitlements(a_, pricingId);
            assertEq(abi.encode(migration.weightedSyEntitlement(ORIGIN)), before_);
        }
    }

    /// @notice Ordinary and partial loaders replace one ledger, never add a second credit allowance.
    function test_crossLoaderReplacementClearsWeightsAndNeverIssues() public {
        Migration.ClaimedSyEntitlementInput[] memory a_ = _input();
        Migration.WeightedSyEntitlementInput[] memory ordinary_ = new Migration.WeightedSyEntitlementInput[](1);
        ordinary_[0] = a_[0].original;
        uint256 supply_ = IERC20(detf).totalSupply();
        uint256 full_ = migration.previewOriginalCredit(1 ether, 1 ether);
        vm.startPrank(migrationOwner);
        allocation.configureWeightedSyEntitlements(ordinary_, pricingId);
        allocation.configureClaimedSyEntitlements(a_, pricingId);
        allocation.configureClaimedSyEntitlements(a_, pricingId);
        vm.stopPrank();
        assertEq(migration.weightedSySurrender(ORIGIN).remainingCredit, full_ * 2 / 3);
        assertEq(migration.weightedSySurrender(ORIGIN).remainingUnits, 7);
        vm.prank(migrationOwner);
        allocation.configureWeightedSyEntitlements(ordinary_, pricingId);
        (uint256 original_, uint256 eligible_) = migration.claimedSyWeights(ORIGIN);
        assertEq(original_, 0);
        assertEq(eligible_, 0);
        assertEq(migration.weightedSySurrender(ORIGIN).remainingCredit, full_);
        assertEq(migration.weightedSyEntitlement(ORIGIN).configurationId,
            keccak256(abi.encode(block.chainid, detf, PricingV3(address(migration)).migrationWeightedPricingV3().id, ordinary_[0])));
        assertEq(migration.weightedSySurrender(ORIGIN).deliveredCredit, 0);
        assertEq(migration.weightedSySurrender(ORIGIN).consumedUnits, 0);
        assertEq(IERC20(detf).totalSupply(), supply_);
    }

    /// @notice Shared source and owner checks also protect the nested loader and atomic batches.
    function test_sourceAuthorityAndInvalidSecondInputRollbackBothWeightsAndCredit() public {
        Migration.ClaimedSyEntitlementInput[] memory a_ = _input();
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, address(this)));
        allocation.configureClaimedSyEntitlements(a_, pricingId);
        a_[0].original.source = Legacy.WEIGHTED_DETF;
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.UnsupportedWeightedSySource.selector, 4663, Legacy.WEIGHTED_DETF));
        allocation.configureClaimedSyEntitlements(a_, pricingId);
        a_ = _input();
        vm.prank(migrationOwner);
        allocation.configureClaimedSyEntitlements(a_, pricingId);
        bytes memory before_ = abi.encode(migration.weightedSyEntitlement(ORIGIN));
        Migration.ClaimedSyEntitlementInput[] memory batch_ = new Migration.ClaimedSyEntitlementInput[](2);
        batch_[0] = a_[0];
        batch_[0].eligibleWeight = 1 ether;
        batch_[1] = a_[0];
        batch_[1].original.originalId = bytes32("invalid second");
        batch_[1].original.contributionsKnown = false;
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidWeightedSyEntitlement.selector, batch_[1].original.originalId));
        allocation.configureClaimedSyEntitlements(batch_, pricingId);
        assertEq(abi.encode(migration.weightedSyEntitlement(ORIGIN)), before_);
        (uint256 original_, uint256 eligible_) = migration.claimedSyWeights(ORIGIN);
        assertEq(original_, 3 ether);
        assertEq(eligible_, 2 ether);
        assertFalse(migration.weightedSyEntitlement(batch_[1].original.originalId).configured);
    }

    /// @notice The economic identity excludes wallet corrections and cannot cross independent/token loaders.
    function test_partialOriginCollidesWithIndependentAndLiquidInBothDirections() public {
        Migration.ClaimedSyEntitlementInput[] memory a_ = _input();
        vm.prank(migrationOwner);
        allocation.configureClaimedSyEntitlements(a_, pricingId);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, ORIGIN));
        _configure(address(this), 1 ether, ORIGIN);
        Migration.WeightedLiquidEntitlementInput[] memory d_ = new Migration.WeightedLiquidEntitlementInput[](1);
        d_[0] = Migration.WeightedLiquidEntitlementInput(
            ORIGIN, address(0xBEEF), Legacy.WEIGHTED_DETF, 7, 1 ether, 1 ether, bytes32("alias"), true
        );
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, ORIGIN));
        allocation.configureWeightedLiquidEntitlements(d_, pricingId);
        d_[0].originalId = bytes32("liquid first");
        vm.prank(migrationOwner);
        allocation.configureWeightedLiquidEntitlements(d_, pricingId);
        a_[0].original.originalId = d_[0].originalId;
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, d_[0].originalId));
        allocation.configureClaimedSyEntitlements(a_, pricingId);
        bytes32 independent_ = bytes32("independent first");
        _configure(address(this), 1 ether, independent_);
        a_[0].original.originalId = independent_;
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, independent_));
        allocation.configureClaimedSyEntitlements(a_, pricingId);
    }

    /// @notice Both loaders retire while the bound weights, hash and remaining ledger stay readable.
    function test_activationRemovesBothLoadersAndRetainsBoundWeights() public {
        Migration.ClaimedSyEntitlementInput[] memory a_ = _input();
        vm.prank(migrationOwner);
        allocation.configureClaimedSyEntitlements(a_, pricingId);
        bytes memory before_ = abi.encode(migration.weightedSyEntitlement(ORIGIN));
        _buyOwnerFirstBond();
        vm.prank(migrationOwner);
        allocation.activateMigration();
        assertEq(IDiamondLoupe(detf).facetAddress(Allocation.configureClaimedSyEntitlements.selector), address(0));
        assertEq(IDiamondLoupe(detf).facetAddress(Allocation.configureWeightedSyEntitlements.selector), address(0));
        assertNotEq(IDiamondLoupe(detf).facetAddress(Migration.claimedSyWeights.selector), address(0));
        (bool ok_,) = detf.call(abi.encodeCall(Allocation.configureClaimedSyEntitlements, (a_, pricingId)));
        assertFalse(ok_);
        assertEq(abi.encode(migration.weightedSyEntitlement(ORIGIN)), before_);
        (uint256 original_, uint256 eligible_) = migration.claimedSyWeights(ORIGIN);
        assertEq(original_, 3 ether);
        assertEq(eligible_, 2 ether);
    }

    /// @notice A-prepared rows cannot clear or reprice storage after installing B; explicit B reload replaces only configuration.
    function test_StaleBook_ClaimedSyReplacementPreservesRecords() public {
        Migration.ClaimedSyEntitlementInput[] memory a_ = _input();
        bytes32 old_ = pricingId;
        vm.prank(migrationOwner); allocation.configureClaimedSyEntitlements(a_, old_);
        bytes memory record_ = abi.encode(migration.weightedSyEntitlement(ORIGIN));
        bytes memory remaining_ = abi.encode(migration.weightedSySurrender(ORIGIN));
        uint256 supply_ = IERC20(detf).totalSupply();
        Pricing.InputsV3 memory next_ = PricingV3(address(migration)).migrationWeightedPricingV3().inputs;
        next_.swapFeeWad = 1e17;
        vm.prank(migrationOwner); pricingId = AllocationV3(address(allocation)).setMigrationWeightedPricingV3(next_);
        assertEq(abi.encode(migration.weightedSyEntitlement(ORIGIN)), record_);
        assertEq(abi.encode(migration.weightedSySurrender(ORIGIN)), remaining_);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Pricing.MigrationWeightedPricingBookMismatch.selector, old_, pricingId));
        allocation.configureClaimedSyEntitlements(a_, old_);
        assertEq(abi.encode(migration.weightedSyEntitlement(ORIGIN)), record_);
        assertEq(abi.encode(migration.weightedSySurrender(ORIGIN)), remaining_);
        vm.prank(migrationOwner); allocation.configureClaimedSyEntitlements(a_, pricingId);
        assertEq(migration.weightedSyEntitlement(ORIGIN).configurationId, keccak256(abi.encode(block.chainid, detf, pricingId, a_[0])));
        assertNotEq(abi.encode(migration.weightedSyEntitlement(ORIGIN)), record_);
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(receipt.stakingState().totalGons, 0);
    }
}
