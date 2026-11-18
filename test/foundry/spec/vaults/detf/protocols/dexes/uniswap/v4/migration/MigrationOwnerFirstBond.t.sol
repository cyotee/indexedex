// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV4DetfMigrationWeightedPricingV3 as PricingV3} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationWeightedPricingV3.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IERC721Metadata} from "@crane/contracts/interfaces/IERC721Metadata.sol";
import {IERC721Errors} from "@crane/contracts/interfaces/IERC721Errors.sol";
import {Base64} from "@crane/contracts/utils/Base64.sol";
import {LibString} from "@crane/contracts/utils/LibString.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {DETFFundedStakingMath as Math} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {DETFSeigniorageShareLib as Weights} from "contracts/vaults/detf/common/core/DETFSeigniorageShareLib.sol";
import {DETFFundedBondMetadata as Metadata} from "contracts/vaults/detf/common/bondNft/DETFFundedBondMetadata.sol";
import {TestBase_UniswapV4DetfMigration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAccounting as Accounting} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";

/// @notice Real paid purchase, funded economics and persistent instance prerequisite; no compensation seed.
contract MigrationOwnerFirstBondTest is TestBase_UniswapV4DetfMigration {
    function setUp() public override {
        super.setUp();
        _fundAndCapture();
    }

    function test_immediatePaidPurchaseUsesCanonicalWeightsRewardsAndOrdinaryTerms() public {
        _assertFirstPurchase();
    }

    function test_delayedPaidPurchaseHasNoUnfundedRetroactiveExpansion() public {
        vm.warp(block.timestamp + 7 days);
        assertEq(migration.pendingExpansionDetf(), 0);
        _assertFirstPurchase();
    }

    /// @notice A real paid linear bond displays only executable claims through activation and reward delivery.
    function test_paidLinearMetadataTracksPrincipalAndActivationGatedFundedRewards() public {
        uint256 id_ = _buyOwnerFirstBond();
        Math.BondPosition memory p_ = bonds.positionOf(id_);
        assertFalse(bonds.isMigrationPosition(id_));
        assertGt(bonds.previewClaim(id_).rewardsDue, 0, "witness must have funded accrued rewards");
        _assertMetadata(id_, false);
        vm.startPrank(migrationOwner);
        vm.expectRevert(Accounting.MigrationRewardsClosed.selector);
        bonds.claimRewards(id_, migrationOwner);
        vm.expectRevert(Accounting.MigrationRewardsClosed.selector);
        bonds.claimBond(id_, migrationOwner);
        vm.stopPrank();

        vm.warp(p_.startTimestamp + 45 days);
        assertEq(bonds.previewClaim(id_).principalDue, p_.principal / 2);
        _assertMetadata(id_, false);
        uint256 before_ = receipt.balanceOf(migrationOwner);
        vm.prank(migrationOwner);
        assertEq(bonds.claimPrincipal(id_, migrationOwner), p_.principal / 2);
        assertEq(receipt.balanceOf(migrationOwner) - before_, p_.principal / 2);
        assertEq(bonds.positionOf(id_).claimedPrincipal, p_.principal / 2);
        _assertMetadata(id_, false);

        vm.warp(p_.startTimestamp + 90 days);
        assertEq(bonds.previewClaim(id_).principalDue, p_.principal - p_.principal / 2);
        _assertMetadata(id_, false);
        before_ = receipt.balanceOf(migrationOwner);
        vm.prank(migrationOwner);
        assertEq(bonds.claimPrincipal(id_, migrationOwner), p_.principal - p_.principal / 2);
        assertEq(receipt.balanceOf(migrationOwner) - before_, p_.principal - p_.principal / 2);
        assertEq(bonds.positionOf(id_).claimedPrincipal, p_.principal);
        _assertMetadata(id_, false);

        vm.prank(migrationOwner);
        allocation.activateMigration();
        _assertMetadata(id_, true);
        uint256 rewards_ = bonds.previewClaim(id_).rewardsDue;
        assertGt(rewards_, 0);
        before_ = receipt.balanceOf(migrationOwner);
        vm.prank(migrationOwner);
        assertEq(bonds.claimRewards(id_, migrationOwner), rewards_);
        assertEq(receipt.balanceOf(migrationOwner) - before_, rewards_);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, id_));
        bonds.previewClaim(id_);
        emit log_named_uint("ordinary Migration rewards actually paid (native9)", rewards_);
    }

    function _assertMetadata(uint256 id_, bool open_) private {
        string memory uri_ = IERC721Metadata(address(bonds)).tokenURI(id_);
        string memory json_ = string(Base64.decode(LibString.slice(uri_, bytes("data:application/json;base64,").length)));
        Math.BondClaim memory c_ = bonds.previewClaim(id_);
        Math.BondPosition memory p_ = bonds.positionOf(id_);
        assertEq(_attribute(json_, "Claimable principal sDETF"), Metadata._amount(c_.principalDue));
        assertEq(_attribute(json_, "Claimable rewards sDETF"), Metadata._amount(open_ ? c_.rewardsDue : 0));
        assertEq(_attribute(json_, "Accrued rewards sDETF"), Metadata._amount(c_.rewardsDue));
        assertEq(_attribute(json_, "Total claimable sDETF"),
            Metadata._amount(c_.principalDue + (open_ ? c_.rewardsDue : 0)));
        assertEq(_attribute(json_, "Remaining DETF principal"), Metadata._amount(p_.principal - p_.claimedPrincipal));
        assertEq(_attribute(json_, "Claimed DETF principal"), Metadata._amount(p_.claimedPrincipal));
        assertEq(_attribute(json_, "Reward delivery"), open_ ? "Open" : "Locked until activation");
        assertEq(_attribute(json_, "Role"), "Staked DETF bond");
        string memory endPath_ = _attributePath(json_, "Vesting end");
        assertEq(vm.parseJsonUint(json_, endPath_), p_.startTimestamp + 90 days);
        assertEq(_attribute(json_, "Vesting status"),
            block.timestamp >= p_.startTimestamp + 90 days ? "Fully vested" : "Vesting");
        string memory image_ = vm.parseJsonString(json_, ".image");
        string memory svg_ = string(Base64.decode(LibString.slice(image_, bytes("data:image/svg+xml;base64,").length)));
        assertTrue(LibString.contains(svg_, Metadata._amount(c_.principalDue)));
        assertTrue(LibString.contains(svg_, Metadata._amount(c_.rewardsDue)));
        emit log_named_string(open_ ? "ordinary Migration open total sDETF" : "ordinary Migration closed principal-only total sDETF",
            _attribute(json_, "Total claimable sDETF"));
        emit log_named_string("ordinary Migration displayed reward sDETF", _attribute(json_, "Claimable rewards sDETF"));
        emit log_named_string("ordinary Migration metadata JSON", json_);
    }

    function _attribute(string memory json_, string memory trait_) private view returns (string memory) {
        return vm.parseJsonString(json_, _attributePath(json_, trait_));
    }

    function _attributePath(string memory json_, string memory trait_) private view returns (string memory) {
        string[] memory traits_ = abi.decode(vm.parseJson(json_, ".attributes[*].trait_type"), (string[]));
        for (uint256 i_; i_ < traits_.length; ++i_) {
            if (keccak256(bytes(traits_[i_])) == keccak256(bytes(trait_))) {
                return string.concat(".attributes[", LibString.toString(i_), "].value");
            }
        }
        revert(string.concat("Missing metadata trait: ", trait_));
    }

    function _assertFirstPurchase() private {
        bytes memory snapshot_ = abi.encode(PricingV3(address(migration)).migrationWeightedPricingV3());
        uint256 credit_ = _configure(address(this), 0.5 ether, bytes32("unchanged credit"));
        bytes memory config_ = abi.encode(migration.independentAllocation(address(this)));
        (, uint256 principal_, uint256 rewards_, uint256 selfLeg_) = migration.previewBond(IERC20(pairA), 1 ether, 90 days);
        uint256 supply_ = IERC20(detf).totalSupply();
        uint256 ownerPayment_ = IERC20(pairA).balanceOf(migrationOwner);
        uint256 donor_ = migration.migrationDonationInventory(IERC20(pairA));
        uint256 lp_ = IERC20(migration.hook()).balanceOf(address(bonds));
        uint256 id_ = _buyOwnerFirstBond();
        assertEq(migration.migrationOwnerFirstBondTokenId(), id_);
        assertEq(IERC20(pairA).balanceOf(migrationOwner), ownerPayment_);
        assertEq(IERC20(pairA).allowance(migrationOwner, detf), 0);
        assertEq(migration.migrationDonationInventory(IERC20(pairA)), donor_);
        assertGt(IERC20(migration.hook()).balanceOf(address(bonds)), lp_);
        assertEq(IERC20(detf).totalSupply(), supply_ + selfLeg_ + principal_ + rewards_);
        Math.BondPosition memory p_ = bonds.positionOf(id_);
        assertEq(p_.principal, principal_);
        assertEq(p_.claimedPrincipal, 0);
        assertEq(p_.stakingGons, principal_ * 1e36);
        assertEq(p_.startTimestamp, vm.getBlockTimestamp());
        assertEq(p_.vestingDuration, 90 days);
        assertFalse(bonds.isMigrationPosition(id_));
        assertEq(IERC721(address(bonds)).ownerOf(id_), migrationOwner);
        _assertEconomics(principal_, rewards_);
        assertEq(abi.encode(PricingV3(address(migration)).migrationWeightedPricingV3()), snapshot_);
        assertEq(abi.encode(migration.independentAllocation(address(this))), config_);
        assertEq(migration.previewOriginalCredit(0.5 ether, 0.5 ether), credit_);
        assertFalse(migration.independentIssuance(address(this)).issued);
        assertFalse(migration.migrationActivated());
        vm.prank(migrationOwner);
        vm.expectRevert(Accounting.MigrationRewardsClosed.selector);
        bonds.claimRewards(id_, migrationOwner);
        address feeOwner_ = IERC721(address(bonds)).ownerOf(1);
        vm.expectRevert(Accounting.MigrationRewardsClosed.selector);
        receipt.claimDeferredRoleRewards(feeOwner_);
        vm.warp(p_.startTimestamp + 45 days);
        assertEq(bonds.previewClaim(id_).principalDue, principal_ / 2);
        vm.prank(migrationOwner);
        assertEq(bonds.claimPrincipal(id_, migrationOwner), principal_ / 2);
        assertEq(migration.migrationOwnerFirstBondTokenId(), id_);
    }

    function _assertEconomics(uint256 principal_, uint256 rewards_) private view {
        (, uint256 fee_, uint256 creator_) =
            IVaultFeeOracleQuery(address(indexedexManager)).seigniorageSplitOfVault(detf);
        uint256 gons_ = principal_ * 1e36;
        (uint256 wf_, uint256 wc_) = Weights._topUpDeltas(gons_, 0, 0, fee_, creator_);
        Math.RewardAllocation memory r_ = Math._allocate(rewards_, gons_, wf_, wc_);
        (uint256 k_,, uint256 dust_) = Math._rebase(gons_, 1e36, r_.staking);
        uint256 allGons_ = gons_ + (r_.fee + r_.creator) * k_;
        (uint256 df_, uint256 dc_) = Weights._topUpDeltas(allGons_, wf_, wc_, fee_, creator_);
        IStakedDETF.StakingState memory s_ = receipt.stakingState();
        assertEq(s_.totalGons, allGons_);
        assertEq(s_.gonsPerUnit, k_);
        assertEq(s_.feeWeight, wf_ + df_);
        assertEq(s_.creatorWeight, wc_ + dc_);
        assertEq(s_.allocationDust, r_.dust);
        assertEq(s_.stakingDust, dust_);
        assertEq(s_.accountedBacking, principal_ + rewards_);
        assertEq(IERC20(detf).balanceOf(address(receipt)), principal_ + rewards_);
        address feeOwner_ = IERC721(address(bonds)).ownerOf(1);
        address creatorOwner_ = IERC721(address(bonds)).ownerOf(2);
        assertEq(receipt.deferredRewardGons(1, feeOwner_),
            (r_.fee + (feeOwner_ == creatorOwner_ ? r_.creator : 0)) * k_);
        if (feeOwner_ != creatorOwner_) assertEq(receipt.deferredRewardGons(1, creatorOwner_), r_.creator * k_);
        assertEq(receipt.balanceOf(feeOwner_), 0);
        assertEq(receipt.balanceOf(creatorOwner_), 0);
        assertEq(IERC20(detf).allowance(detf, address(bonds)), 0);
        assertEq(IERC20(detf).allowance(detf, address(receipt)), 0);
        assertEq(IERC20(detf).allowance(address(bonds), address(receipt)), 0);
    }

    function test_pendingFormerAndNonownerCannotBuyButCurrentOwnerCan() public {
        address next_ = makeAddr("next paid owner");
        vm.prank(migrationOwner);
        migration.initiateOwnershipTransfer(next_);
        _rejectBuyer(address(this));
        _rejectBuyer(next_);
        vm.prank(next_);
        migration.acceptOwnershipTransfer();
        _rejectBuyer(migrationOwner);
        uint256 id_ = _buyOwnerFirstBond();
        address finalOwner_ = makeAddr("final owner");
        vm.startPrank(next_);
        IERC721(address(bonds)).transferFrom(next_, finalOwner_, id_);
        migration.initiateOwnershipTransfer(finalOwner_);
        vm.stopPrank();
        vm.prank(finalOwner_);
        migration.acceptOwnershipTransfer();
        assertEq(migration.migrationOwnerFirstBondTokenId(), id_);
        vm.prank(next_);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, next_));
        allocation.activateMigration();
        vm.prank(finalOwner_);
        allocation.activateMigration();
        assertTrue(migration.migrationActivated());
        (uint256 ordinary_,) = migration.bond(IERC20(pairA), 1 ether, 90 days, address(this), false, block.timestamp);
        assertEq(IERC721(address(bonds)).ownerOf(ordinary_), address(this));
        assertEq(migration.migrationOwnerFirstBondTokenId(), id_);
    }

    function _rejectBuyer(address buyer_) private {
        vm.prank(buyer_);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, buyer_));
        migration.bond(IERC20(pairA), 1 ether, 90 days, buyer_, false, block.timestamp);
        assertEq(migration.migrationOwnerFirstBondTokenId(), 0);
    }

    function test_exceptionDoesNotOpenOtherAcquisitionOrSecondPurchase() public {
        vm.startPrank(migrationOwner);
        vm.expectRevert(Accounting.MigrationRewardsClosed.selector);
        detfExchangeIn.exchangeIn(IERC20(pairA), 1 ether, IERC20(detf), 0, migrationOwner, false, block.timestamp);
        vm.expectRevert(bytes4(keccak256("MigrationAcquisitionClosed()")));
        rawSy.deposit(migrationOwner, pairA, 1 ether, 0);
        vm.expectRevert(bytes4(keccak256("MigrationAcquisitionClosed()")));
        stakingSy.deposit(migrationOwner, pairA, 1 ether, 0);
        vm.stopPrank();
        uint256 id_ = _buyOwnerFirstBond();
        vm.prank(migrationOwner);
        vm.expectRevert(Accounting.MigrationRewardsClosed.selector);
        migration.bond(IERC20(pairA), 1 ether, 90 days, migrationOwner, false, block.timestamp);
        assertEq(migration.migrationOwnerFirstBondTokenId(), id_);
    }

    function test_failedPaymentAndChildMintLeaveNoPurchaseOrEconomicEffects() public {
        IERC20(pairA).transfer(migrationOwner, 1 ether);
        bytes32 before_ = _economicState();
        vm.prank(migrationOwner);
        (bool unpaid_,) = detf.call(abi.encodeWithSignature(
            "bond(address,uint256,uint256,address,bool,uint256)", pairA, 1 ether, 90 days, migrationOwner, false, block.timestamp
        ));
        assertFalse(unpaid_);
        assertEq(_economicState(), before_);
        vm.prank(migrationOwner);
        IERC20(pairA).approve(detf, 1 ether);
        before_ = _economicState();
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(bonds)));
        migration.bond(IERC20(pairA), 1 ether, 90 days, address(bonds), false, block.timestamp);
        assertEq(_economicState(), before_);
        vm.prank(migrationOwner);
        vm.expectRevert(Migration.MigrationOwnerFirstBondRequired.selector);
        allocation.activateMigration();
        vm.prank(migrationOwner);
        migration.bond(IERC20(pairA), 1 ether, 90 days, migrationOwner, false, block.timestamp);
        assertEq(migration.migrationOwnerFirstBondTokenId(), 3);
    }

    function _economicState() private view returns (bytes32) {
        return keccak256(abi.encode(
            migration.migrationOwnerFirstBondTokenId(), migration.migrationActivated(),
            IERC20(pairA).balanceOf(migrationOwner), IERC20(pairA).balanceOf(detf),
            IERC20(pairA).allowance(migrationOwner, detf), IERC20(detf).totalSupply(),
            IERC20(migration.hook()).balanceOf(address(bonds)), receipt.stakingState(),
            IERC20(detf).balanceOf(address(receipt)), IERC721(address(bonds)).ownerOf(3),
            migration.migrationDonationInventory(IERC20(pairA)), PricingV3(address(migration)).migrationWeightedPricingV3().id
        ));
    }
}
