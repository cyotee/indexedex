// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MigrationRecoveryDonationForkBase} from "../MigrationRecoveryDonation.t.sol";
import {MigrationLegacyHandler} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/invariant/MigrationLegacyHandler.sol";
import {MigrationLegacyRecoveryHandler} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/invariant/MigrationLegacyRecoveryHandler.sol";
import {MigrationStatefulBindings} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/invariant/MigrationStatefulBindings.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationDFPkg as Package} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationDFPkg.sol";
import {IUniswapV4DetfMigrationStakedDETF as MigrationReceipt} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/claimToken/IUniswapV4DetfMigrationStakedDETF.sol";
import {IUniswapV4DetfMigrationBondNFTVault as Bonds} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/bondNft/IUniswapV4DetfMigrationBondNFTVault.sol";
import {IMigrationWeightedNft} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyNft.sol";
import {MigrationLegacyRecoveryLib as Legacy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol";
import {IUniswapV4DetfMigrationWeightedPricing as Pricing} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationWeightedPricing.sol";

/// @notice Pinned real native9 SY and both whole-NFT models with staged weighted recovery.
/// @dev Ordinary-SY contract callback only, not claimed-origin EOA preparation.
/// Standalone WS-gon/ER-internal/CV-native19/SD-native28/held-LP stateful domains
/// use the separate MigrationSourceUnitsInvariant target, not this native9 ledger.
contract MigrationLegacyInvariantTest is MigrationRecoveryDonationForkBase {
    MigrationLegacyRecoveryHandler public handler;
    uint256 public nftPricingWitnesses;

    /// @dev Catches pricing-coupled NFT originals, silent repricing on set, and minting on explicit reload.
    function _reloadNftAcrossBook(address collection_, uint256 id_, uint256 choice_) internal returns (uint256) {
        Migration.NftEntitlement memory before_ = migration.nftEntitlement(collection_, id_);
        bytes memory state_ = abi.encode(receipt.stakingState());
        uint256 supply_ = IERC20(detf).totalSupply();
        address holder_ = IERC721(collection_).ownerOf(id_);
        Pricing.Inputs memory next_ = migration.migrationWeightedPricing().inputs;
        next_.swapFeeWad = choice_ == 0 ? 1e16 : 2e16;
        vm.prank(migrationOwner);
        pricingId = allocation.setMigrationWeightedPricing(next_);
        assertEq(abi.encode(migration.nftEntitlement(collection_, id_)), abi.encode(before_),
            "setting B must leave stored A originals and credit intact");
        uint256 credit_ = _configureNft(collection_, id_);
        Migration.NftEntitlement memory after_ = migration.nftEntitlement(collection_, id_);
        assertEq(after_.originalId, before_.originalId, "economic identity survives A/B reload");
        assertEq(abi.encode(after_.original), abi.encode(before_.original));
        assertNotEq(after_.configurationId, before_.configurationId, "new configuration retains book provenance");
        assertEq(IERC20(detf).totalSupply(), supply_, "set and reload never issue");
        assertEq(abi.encode(receipt.stakingState()), state_);
        assertEq(IERC721(collection_).ownerOf(id_), holder_, "set and reload never take custody");
        ++nftPricingWitnesses;
        return credit_;
    }

    function _freshBoundedParent() internal {
        Package.PkgArgs memory args_ = _migrationArgs(migrationOwner);
        args_.baseArgs.mintThreshold = 100e18;
        detf = _deployMigration(args_);
        migration = Migration(detf); allocation = Allocation(detf);
        receipt = MigrationReceipt(migration.rebasingClaimToken()); bonds = Bonds(migration.bondNftVault());
        IERC20(pairA).approve(detf, type(uint256).max);
        IERC20(pairB).approve(detf, type(uint256).max);
        super._fundHistoricalBook();
        _buyOwnerFirstBond();
    }

    function setUp() public override {
        super.setUp();
        _freshBoundedParent();
        MigrationStatefulBindings.capture(migration, address(migrationPkg), address(indexedexManager));
        MigrationLegacyHandler.OriginalNft[2] memory originals_;
        for (uint256 i_; i_ < 2; ++i_) {
            address collection_ = i_ == 0 ? WEIGHTED : EARLIER;
            uint256 id_ = i_ == 0 ? 4 : 3;
            Migration.NftEntitlementInput memory input_ = _original(collection_, id_);
            _configureNft(collection_, id_);
            _returnToOriginal(collection_, id_);
            uint256 credit_ = _reloadNftAcrossBook(collection_, id_, i_);
            uint256 remaining_ = input_.originalUnits;
            if (i_ == 0) remaining_ -= IMigrationWeightedNft(collection_).positionOf(id_).claimedPrincipal;
            originals_[i_] = MigrationLegacyHandler.OriginalNft(
                collection_, id_, input_.originalWallet, input_.originalUnits, remaining_, credit_);
        }
        handler = new MigrationLegacyRecoveryHandler(migration, originals_, migration.previewOriginalCredit(0.01 ether, 0));
        address donor_ = address(bytes20(hex"11c17f25e958e4637dd26ca362adeae12e24ed5b"));
        uint256 quantity_ = handler.Q0();
        vm.prank(donor_); assertTrue(IERC20(Legacy.WEIGHTED_SY).transfer(address(handler), quantity_));
        Migration.WeightedSyEntitlementInput[] memory a_ = new Migration.WeightedSyEntitlementInput[](1);
        a_[0] = Migration.WeightedSyEntitlementInput(handler.ORIGIN(), address(handler), Legacy.WEIGHTED_SY,
            handler.Q0(), 0.01 ether, 0, keccak256("synthetic ordinary SY original; actual donor transfer"), true);
        vm.prank(migrationOwner); allocation.configureWeightedSyEntitlements(a_, pricingId);
        vm.expectRevert(Migration.MigrationSurrenderClosed.selector);
        handler.surrender(1);
        _activate();
        handler.assertAll();
        handler.missingRecord();
        handler.rejectNftControl(0);
        handler.rejectNftControl(1);
        handler.failedIssuance();
        handler.transferAndReject();
        handler.surrender(999);
        handler.failedRecoveryBatch();
        handler.takeNft(0);
        handler.takeNft(1);
        handler.redeemSy(9);
        handler.unstake(9);
        handler.convert(9);
        handler.donate(type(uint256).max);
        handler.changeOwner();
        // Mandatory later surrender and current-holder claim, before randomized selection.
        handler.advanceTime(29);
        handler.surrender(499);
        handler.transferBond(handler.positionCount() - 1);
        handler.claimPrincipal(handler.positionCount() - 1);
        bytes4[] memory selectors_ = new bytes4[](17);
        selectors_[0] = handler.surrender.selector;
        selectors_[1] = handler.failedIssuance.selector;
        selectors_[2] = handler.transferAndReject.selector;
        selectors_[3] = handler.takeNft.selector;
        selectors_[4] = handler.redeemSy.selector;
        selectors_[5] = handler.claimWeighted.selector;
        selectors_[6] = handler.unstake.selector;
        selectors_[7] = handler.convert.selector;
        selectors_[8] = handler.donate.selector;
        selectors_[9] = handler.failedRecoveryBatch.selector;
        selectors_[10] = handler.changeOwner.selector;
        selectors_[11] = handler.missingRecord.selector;
        selectors_[12] = handler.rejectNftControl.selector;
        selectors_[13] = handler.transferBond.selector;
        selectors_[14] = handler.claimPrincipal.selector;
        selectors_[15] = handler.claimRewards.selector;
        selectors_[16] = handler.advanceTime.selector;
        targetContract(address(handler));
        string[] memory artifacts_ = new string[](1);
        artifacts_[0] = "MigrationLegacyRecoveryHandler.sol:MigrationLegacyRecoveryHandler";
        targetInterface(FuzzInterface(address(handler), artifacts_));
        targetSelector(FuzzSelector(address(handler), selectors_));
    }

    function invariant_originalCreditCustodyFundingAndStagedRecovery() public view {
        handler.assertAll();
    }

    function afterInvariant() public {
        handler.assertAll();
        assertTrue(migration.migrationActivated(), "real activation required");
        assertGt(migration.migrationOwnerFirstBondTokenId(), 0, "real paid owner purchase required");
        assertGt(handler.callbacks(), 0, "successful funded surrender callback required");
        assertGt(handler.rollbackWitnesses(), 0, "late funding rollback required");
        assertGt(handler.recoveries(), 0, "real harvest stages required");
        assertEq(nftPricingWitnesses, 2, "both whole-NFT source identities survive repricing");
        emit log_named_uint("successful NFT original repricing and reload witnesses", nftPricingWitnesses);
        emit log_named_uint("successful legacy actions", handler.successes());
        emit log_named_uint("exact legacy rejections", handler.rejections());
        emit log_named_uint("real funded bond callbacks", handler.callbacks());
        emit log_named_uint("late funding rollback witnesses", handler.rollbackWitnesses());
        emit log_named_uint("whole batch recovery rollbacks", handler.batchRollbacks());
        emit log_named_uint("successful recovery stages", handler.recoveries());
        emit log_named_uint("surrendered principal paid", handler.principalPaid());
        emit log_named_uint("surrendered position claim actions", handler.claimActions());
        emit log_named_uint("surrendered bond transfers", handler.bondTransfers());
    }

    /// @notice Catches independently rounded partial credits losing or overpaying the terminal residue.
    /// @dev Synthetic three-unit ordinary-SY original; actual source transfer, registry proxy and funded bonds.
    function test_threeUnitsPay333Then334Then334OnActualProxy() public {
        // Same arguments reuse the CREATE3 registry instance already activated by the prelude.
        // A distinct owner is part of the production package salt and creates an independent proxy.
        migrationOwner = makeAddr("three-unit residue owner");
        _freshBoundedParent();
        uint256 low_;
        uint256 high_ = 1 ether;
        while (low_ < high_) {
            uint256 mid_ = low_ + (high_ - low_) / 2;
            if (migration.previewOriginalCredit(mid_, 0) < 1001) low_ = mid_ + 1;
            else high_ = mid_;
        }
        assertEq(migration.previewOriginalCredit(low_, 0), 1001, "exact configured native credit");
        bytes32 original_ = keccak256("synthetic three-unit residue witness");
        Migration.WeightedSyEntitlementInput[] memory a_ = new Migration.WeightedSyEntitlementInput[](1);
        a_[0] = Migration.WeightedSyEntitlementInput(original_, address(this), Legacy.WEIGHTED_SY,
            3, low_, 0, keccak256("actual source units; synthetic economic original"), true);
        uint256 supply_ = IERC20(detf).totalSupply();
        uint256 backing_ = IERC20(detf).balanceOf(address(receipt));
        vm.prank(migrationOwner);
        allocation.configureWeightedSyEntitlements(a_, pricingId);
        assertEq(IERC20(detf).totalSupply(), supply_, "loading never issues");
        assertEq(IERC20(detf).balanceOf(address(receipt)), backing_);
        address donor_ = address(bytes20(hex"11c17f25e958e4637dd26ca362adeae12e24ed5b"));
        vm.prank(donor_);
        assertTrue(IERC20(Legacy.WEIGHTED_SY).transfer(address(this), 3));
        IERC20(Legacy.WEIGHTED_SY).approve(detf, 3);
        _activate();
        for (uint256 i_; i_ < 3; ++i_) {
            uint256 expected_ = i_ == 0 ? 333 : 334;
            (uint256 id_, uint256 paid_) = migration.surrenderMigrationWeightedSy(
                original_, 1, expected_, block.timestamp);
            assertEq(paid_, expected_);
            assertEq(bonds.positionOf(id_).principal, expected_);
            assertEq(bonds.positionOf(id_).startTimestamp, block.timestamp);
            assertEq(bonds.positionOf(id_).vestingDuration, 90 days);
        }
        assertEq(IERC20(detf).totalSupply() - supply_, 1001);
        assertEq(IERC20(detf).balanceOf(address(receipt)) - backing_, 1001);
        assertEq(migration.weightedSySurrender(original_).remainingUnits, 0);
        assertEq(migration.weightedSySurrender(original_).remainingCredit, 0);
        assertEq(migration.weightedSySurrender(original_).deliveredCredit, 1001);
    }

    function test_terminalCreditAndCompleteRecoveryWitness() public {
        handler.claimWeighted();
        handler.surrender(handler.remainingQ() - 1);
        handler.redeemSy(type(uint256).max);
        handler.unstake(type(uint256).max);
        handler.convert(type(uint256).max);
        handler.donate(type(uint256).max);
        assertEq(handler.remainingQ(), 0);
        assertEq(handler.remainingC(), 0);
        assertEq(handler.delivered(), handler.C0());
        handler.assertAll();
        afterInvariant();
    }

    function test_laterSurrenderOwnCliffAndEveryPositionClaim() public {
        uint256 last_ = handler.positionCount() - 1;
        uint256 start_ = handler.positionStart(last_);
        vm.warp(start_ + 90 days - 1);
        handler.claimPrincipal(last_);
        vm.warp(start_ + 90 days);
        handler.claimPrincipal(last_);
        vm.warp(start_ + 90 days + 1);
        handler.claimPrincipal(last_);
        handler.surrender(handler.remainingQ() - 1);
        uint256 fresh_ = handler.positionCount() - 1;
        handler.transferBond(fresh_);
        handler.claimPrincipal(fresh_);
        vm.warp(handler.positionStart(fresh_) + 90 days - 1);
        handler.claimPrincipal(fresh_);
        vm.warp(handler.positionStart(fresh_) + 90 days);
        for (uint256 i_; i_ < handler.positionCount(); ++i_) {
            handler.transferBond(i_);
            handler.claimPrincipal(i_);
            handler.claimRewards(i_);
        }
        vm.warp(block.timestamp + 1);
        handler.claimPrincipal(fresh_);
        handler.claimWeighted();
        handler.assertAll();
        afterInvariant();
    }
}
