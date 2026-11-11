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
import {MigrationLegacyRecoveryLib as Legacy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {MigrationHostileContribution} from "./MigrationHostileContribution.t.sol";

/// @notice Hermetic surface/authority and callback negatives; source successes belong to the real fork.
contract MigrationRecoveryTest is TestBase_UniswapV4DetfMigration {
    function test_recoveryDeclarationAndProxySurviveActivation() public {
        bytes4[] memory selectors_ = new bytes4[](4);
        selectors_[0] = Recovery.recoverMigrationNfts.selector;
        selectors_[1] = Recovery.migrationRecoveryInventory.selector;
        selectors_[2] = Recovery.migrationRecoveryGons.selector;
        selectors_[3] = Recovery.migrationNftRecovery.selector;
        IFacet facet_ = IFacet(IDiamondLoupe(detf).facetAddress(selectors_[0]));
        assertTrue(Behavior_IFacet.areValid_IFacet_facetFuncs(facet_, selectors_, facet_.facetFuncs()));
        bytes4[] memory interfaces_ = new bytes4[](1);
        interfaces_[0] = type(Recovery).interfaceId;
        assertTrue(Behavior_IFacet.areValid_IFacet_facetInterfaces(facet_, interfaces_, facet_.facetInterfaces()));
        assertLe(address(facet_).code.length, 24576);
        _fundAndCapture();
        vm.prank(migrationOwner);
        allocation.activateMigration();
        for (uint256 i_; i_ < selectors_.length; ++i_) {
            assertEq(IDiamondLoupe(detf).facetAddress(selectors_[i_]), address(facet_));
        }
        assertTrue(IERC165(detf).supportsInterface(type(Recovery).interfaceId));
        assertEq(Recovery(detf).migrationRecoveryInventory(Legacy.DTF), 0);
        assertEq(Recovery(detf).migrationRecoveryGons(), 0);
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
