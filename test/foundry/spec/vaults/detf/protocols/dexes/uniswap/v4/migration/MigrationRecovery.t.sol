// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {Behavior_IFacet} from "@crane/contracts/factories/diamondPkg/Behavior_IFacet.sol";
import {TestBase_UniswapV4DetfMigration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {IUniswapV4DetfMigration as Migration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {MigrationLegacyRecoveryLib as Legacy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {MigrationHostileContribution} from "./MigrationHostileContribution.t.sol";

/// @notice Hermetic surface/authority and callback negatives; source successes belong to the real fork.
contract MigrationRecoveryTest is TestBase_UniswapV4DetfMigration {
    function test_recoveryDeclarationAndProxySurviveActivation() public {
        bytes4[] memory selectors_ = new bytes4[](26);
        selectors_[0] = Recovery.recoverMigrationNfts.selector;
        selectors_[1] = Recovery.migrationRecoveryInventory.selector;
        selectors_[2] = Recovery.migrationRecoveryGons.selector;
        selectors_[3] = Recovery.migrationNftRecovery.selector;
        selectors_[4] = Migration.claimVaultEntitlement.selector;
        selectors_[5] = Migration.claimVaultSurrender.selector;
        selectors_[6] = Migration.previewClaimVaultSurrender.selector;
        selectors_[7] = Migration.surrenderMigrationClaimVault.selector;
        selectors_[8] = Migration.weightedReceiptEntitlement.selector;
        selectors_[9] = Migration.weightedReceiptSurrender.selector;
        selectors_[10] = Migration.previewWeightedReceiptSurrender.selector;
        selectors_[11] = Migration.surrenderMigrationWeightedReceipt.selector;
        selectors_[12] = Recovery.migrationEarlierReceiptInternalShares.selector;
        selectors_[13] = Migration.earlierReceiptEntitlement.selector;
        selectors_[14] = Migration.earlierReceiptSurrender.selector;
        selectors_[15] = Migration.previewEarlierReceiptSurrender.selector;
        selectors_[16] = Migration.surrenderMigrationEarlierReceipt.selector;
        selectors_[17] = Migration.earlierLiquidEntitlement.selector;
        selectors_[18] = Migration.earlierLiquidSurrender.selector;
        selectors_[19] = Migration.previewEarlierLiquidSurrender.selector;
        selectors_[20] = Migration.surrenderMigrationEarlierLiquid.selector;
        selectors_[21] = Migration.heldSeLpEntitlement.selector;
        selectors_[22] = Migration.heldSeLpSurrender.selector;
        selectors_[23] = Migration.previewHeldSeLpSurrender.selector;
        selectors_[24] = Migration.surrenderMigrationHeldSeLp.selector;
        selectors_[25] = Recovery.migrationEarlierNftReceiptRemainder.selector;
        IFacet facet_ = IFacet(IDiamondLoupe(detf).facetAddress(selectors_[0]));
        assertTrue(Behavior_IFacet.areValid_IFacet_facetFuncs(facet_, selectors_, facet_.facetFuncs()));
        bytes4[] memory interfaces_ = new bytes4[](1);
        interfaces_[0] = type(Recovery).interfaceId;
        assertTrue(Behavior_IFacet.areValid_IFacet_facetInterfaces(facet_, interfaces_, facet_.facetInterfaces()));
        assertLe(address(facet_).code.length, 24576);
        _fundAndCapture();
        _buyOwnerFirstBond();
        vm.prank(migrationOwner);
        allocation.activateMigration();
        for (uint256 i_; i_ < selectors_.length; ++i_) {
            assertEq(IDiamondLoupe(detf).facetAddress(selectors_[i_]), address(facet_));
        }
        assertTrue(IERC165(detf).supportsInterface(type(Recovery).interfaceId));
        assertEq(Recovery(detf).migrationRecoveryInventory(Legacy.DTF), 0);
        assertEq(Recovery(detf).migrationRecoveryGons(), 0);
        assertEq(Recovery(detf).migrationEarlierReceiptInternalShares(), 0);
        assertEq(Recovery(detf).migrationEarlierNftReceiptRemainder(), 0);
        assertFalse(Recovery(detf).migrationNftRecovery(address(1), 3).sold);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, address(this)));
        Recovery(detf).recoverMigrationNfts(new Recovery.Step[](0), block.timestamp);
    }

    function test_balancesAndDonationBudgetsDoNotAuthorizeRecoverySpending() public {
        _fundAndCapture();
        vm.chainId(4663);
        Recovery.Step[] memory steps_ = new Recovery.Step[](1);
        steps_[0] = Recovery.Step(Recovery.Stage.WeightedUnstake, 0, 1, 0);
        vm.expectRevert(abi.encodeWithSelector(
            Recovery.RecoveryInventoryInsufficient.selector, Legacy.WEIGHTED_RECEIPT, 1, 0
        ));
        vm.prank(migrationOwner);
        Recovery(detf).recoverMigrationNfts(steps_, block.timestamp);
        steps_[0] = Recovery.Step(Recovery.Stage.WeightedConvert, 0, 1, 0);
        vm.expectRevert(abi.encodeWithSelector(
            Recovery.RecoveryInventoryInsufficient.selector, Legacy.WEIGHTED_DETF, 1, 0
        ));
        vm.prank(migrationOwner);
        Recovery(detf).recoverMigrationNfts(steps_, block.timestamp);
        assertEq(Recovery(detf).migrationRecoveryInventory(pairB), 0);
        assertEq(receipt.stakingState().totalGons, 0);
    }

    function test_invalidStageFieldsRejectWithoutCallingLegacy() public {
        vm.chainId(4663);
        Recovery.Step[] memory steps_ = new Recovery.Step[](1);
        steps_[0] = Recovery.Step(Recovery.Stage.WeightedClaim, 3, 1, 0);
        vm.expectRevert(Recovery.InvalidRecoveryStep.selector);
        vm.prank(migrationOwner);
        Recovery(detf).recoverMigrationNfts(steps_, block.timestamp);
        steps_[0] = Recovery.Step(Recovery.Stage.WeightedConvert, 3, 1, 0);
        vm.expectRevert(Recovery.InvalidRecoveryStep.selector);
        vm.prank(migrationOwner);
        Recovery(detf).recoverMigrationNfts(steps_, block.timestamp);
    }

    function test_fullAccountGonDebitRejectsUnbookedFractionButAllowsSmallerExit() public {
        // At divisor ten: two booked native units plus three unbooked sub-native gons.
        // The real legacy full-account rule retires all 23 gons for a two-unit exit.
        vm.expectRevert(abi.encodeWithSelector(Recovery.RecoveryGonsProtected.selector, 23, 20));
        this.checkGonDebit(23, 0, 20);
        assertEq(Legacy.requireGonDebit(23, 13, 20), 10);
        assertEq(Legacy.requireGonDebit(13, 3, 10), 10);
        // Attributed recovery fractions may retire; unrelated fractions may not.
        assertEq(Legacy.requireGonDebit(23, 0, 23), 23);
    }

    function checkGonDebit(uint256 before_, uint256 after_, uint256 attributed_) external pure returns (uint256) {
        return Legacy.requireGonDebit(before_, after_, attributed_);
    }

    /// @notice Supplemental arithmetic vectors; no source balance, state or rate is fabricated.
    function checkEarlierMeasurement(
        uint256 n_, uint256 q_, Legacy.EarlierReceiptObservation calldata before_,
        Legacy.EarlierReceiptObservation calldata after_
    ) external pure { Legacy.requireEarlierReceiptMeasurement(n_, q_, before_, after_); }

    function _observation(uint256 r_, uint256 wallet_, uint256 custody_)
        private pure returns (Legacy.EarlierReceiptObservation memory)
    {
        return Legacy.EarlierReceiptObservation(
            r_, 1, wallet_ / 1e9, custody_ / 1e9,
            Math.mulDiv(wallet_, r_, 1e27), Math.mulDiv(custody_, r_, 1e27)
        );
    }

    function test_earlierSingletonUsesFullPrecisionBeyondUintProduct() public pure {
        uint256 q_ = 1 << 200;
        Legacy.requireEarlierReceiptMeasurement(
            q_, q_, _observation(1e27, q_ + 7, 6), _observation(1e27, 7, q_ + 6)
        );
    }

    function test_earlierUnresolvedRateAndZeroExternalDeltaReject() public {
        vm.expectRevert(Migration.EarlierReceiptCustodyFailed.selector);
        this.checkEarlierMeasurement(1e18, 1e18, _observation(1e27, 1e18, 0), _observation(1e27, 0, 1e18));
        vm.expectRevert(Migration.EarlierReceiptCustodyFailed.selector);
        this.checkEarlierMeasurement(1, 1, _observation(1e27, 1, 0), _observation(1e27, 0, 1));
    }

    function test_earlierRateSupplyAndDisplayedInconsistencyReject() public {
        uint256 q_ = uint256(1e27) / 2197;
        Legacy.EarlierReceiptObservation memory before_ = _observation(2197, q_ * 4, 0);
        Legacy.EarlierReceiptObservation memory after_ = _observation(2197, q_ * 3, q_);
        after_.rate += 1;
        vm.expectRevert(Migration.EarlierReceiptCustodyFailed.selector);
        this.checkEarlierMeasurement(1, q_, before_, after_);
        after_.rate -= 1; after_.total += 1;
        vm.expectRevert(Migration.EarlierReceiptCustodyFailed.selector);
        this.checkEarlierMeasurement(1, q_, before_, after_);
        after_.total -= 1; after_.walletDisplay = 0;
        vm.expectRevert(Migration.EarlierReceiptCustodyFailed.selector);
        this.checkEarlierMeasurement(1, q_, before_, after_);
    }

    function test_earlierIntervalMultiplicationAndInverseIncrementCannotWrap() public {
        uint256 d_ = type(uint256).max / 1e9;
        Legacy.EarlierReceiptObservation memory before_ = Legacy.EarlierReceiptObservation(1, 1, d_, 0, 1, 0);
        Legacy.EarlierReceiptObservation memory after_ = Legacy.EarlierReceiptObservation(1, 1, 0, d_, 0, 1);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        this.checkEarlierMeasurement(1, d_ * 1e9, before_, after_);
        d_ = 1e18 - 1;
        before_.walletShares = d_; after_.custodyShares = d_;
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        this.checkEarlierMeasurement(type(uint256).max, d_ * 1e9, before_, after_);
    }
}

contract MigrationRecoveryCallbackTest is TestBase_UniswapV4DetfMigration {
    function _deployContributionFixture() internal override returns (address) {
        return create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "MigrationHostileContribution.t.sol:MigrationHostileContribution"),
            "", keccak256("recovery.hostile.contribution")
        );
    }

    function test_currentOwnerTokenCallbackCannotEnterRecoveryDuringDonation() public {
        _fundAndCapture();
        vm.prank(migrationOwner);
        IMultiStepOwnable(detf).initiateOwnershipTransfer(pairB);
        MigrationHostileContribution token_ = MigrationHostileContribution(pairB);
        token_.arm(false, detf, detf, abi.encodeCall(IMultiStepOwnable.acceptOwnershipTransfer, ()));
        _donate();
        assertTrue(token_.callbackSucceeded());
        assertEq(IMultiStepOwnable(detf).owner(), pairB);
        Recovery.Step[] memory steps_ = new Recovery.Step[](1);
        steps_[0] = Recovery.Step(Recovery.Stage.WeightedUnstake, 0, 1, 0);
        token_.arm(false, detf, detf, abi.encodeCall(Recovery.recoverMigrationNfts, (steps_, block.timestamp)));
        uint256 before_ = IERC20(detf).totalSupply();
        _donate();
        assertFalse(token_.callbackSucceeded());
        assertEq(Recovery(detf).migrationRecoveryInventory(Legacy.WEIGHTED_RECEIPT), 0);
        assertEq(IERC20(detf).totalSupply(), before_);
        assertEq(receipt.stakingState().totalGons, 0);
    }

    function _donate() private {
        IERC20[] memory tokens_ = new IERC20[](1);
        tokens_[0] = IERC20(pairB);
        uint256[] memory amounts_ = new uint256[](1);
        amounts_[0] = 1 ether;
        migration.donateMigrationCapital(tokens_, amounts_, 0, 1, block.timestamp);
    }
}
