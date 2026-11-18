// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {TestBase_UniswapV4DetfMigration} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationWeightedPricing as Pricing} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationWeightedPricing.sol";

/// @notice Executes the simulation-only mixed-book lifecycle through real proxies.
contract MigrationMixedRecordsTest is TestBase_UniswapV4DetfMigration {
    function setUp() public override {
        vm.chainId(4663);
        super.setUp();
        _fundReserve();
    }

    /// @notice Real registry/proxy mixed-book rehearsal; no legacy custody or public transaction.
    function test_MixedRecordsPreserveIssuanceAcrossBookReplacementAndActivation() public {
        Pricing.Inputs memory inputs_;
        inputs_.swapFeeWad = 3e15;
        inputs_.seigniorage = 5e16;
        inputs_.dtfIndex = 1;
        inputs_.detfIndex = 2;
        inputs_.legs = new Pricing.Leg[](3);
        inputs_.legs[0].token = pairA;
        inputs_.legs[1].token = pairB;
        inputs_.legs[2].token = detf;
        for (uint256 i_; i_ < 3; ++i_) {
            inputs_.legs[i_].weight = i_ == 2 ? 4e17 : 3e17;
            inputs_.legs[i_].invScale = i_ == 2 ? 1e27 : 1e18;
            inputs_.legs[i_].ratedScale = inputs_.legs[i_].invScale;
            inputs_.legs[i_].rawReserve = i_ == 2 ? 1000000e9 : 1000000 ether;
        }
        vm.prank(migrationOwner);
        pricingId = allocation.setMigrationWeightedPricing(inputs_);
        bytes32 a_ = pricingId;
        _configure(address(0xA11CE), 1 ether, bytes32("issued original"));
        _configure(address(0xBEEF), 2 ether, bytes32("retained original"));
        Migration.IndependentAllocation memory original_ = migration.independentAllocation(address(0xA11CE));
        bytes32 retained_ = migration.independentAllocation(address(0xBEEF)).configurationId;
        uint256 issuedBond_ = _issue(address(0xA11CE));
        console2.log("STATE_TRACE", string.concat(
            '{"state":"issued-A","bookId":"', vm.toString(a_),
            '","configurationId":"', vm.toString(original_.configurationId),
            '","bondId":"', vm.toString(issuedBond_), '"}'));

        address collection_ = 0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E;
        Migration.NftEntitlementInput[] memory nft_ = new Migration.NftEntitlementInput[](1);
        nft_[0] = Migration.NftEntitlementInput(collection_, 3, address(0xCAFE), 3772281649,
            999999000000000, 362893857600000000000, bytes32("synthetic NFT3 source"), true);
        vm.prank(migrationOwner);
        allocation.configureNftContributionEntitlements(nft_, a_);
        bytes32 origin_ = migration.nftEntitlement(collection_, 3).originalId;
        inputs_.swapFeeWad = 1e17;
        vm.prank(migrationOwner);
        pricingId = allocation.setMigrationWeightedPricing(inputs_);
        bytes32 b_ = pricingId;
        require(a_ != b_, "distinct manual books");
        require(migration.independentAllocation(address(0xBEEF)).configurationId == retained_, "retained A");
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Pricing.MigrationWeightedPricingBookMismatch.selector, a_, b_));
        allocation.configureNftContributionEntitlements(nft_, a_);
        _configure(address(0xA11CE), 1 ether, bytes32("issued original"));
        _configure(address(0xD00D), 3 ether, bytes32("new B original"));
        vm.prank(migrationOwner);
        allocation.configureNftContributionEntitlements(nft_, b_);
        Migration.IndependentIssuance memory issued_ = migration.independentIssuance(address(0xA11CE));
        require(issued_.configurationId == original_.configurationId && issued_.credit == original_.totalCredit,
            "issuance A remains immutable after configuration B");
        require(migration.independentAllocation(address(0xA11CE)).configurationId != issued_.configurationId,
            "configuration and issuance identities are independent");
        require(bonds.positionOf(issuedBond_).principal == original_.totalCredit, "issued funded principal unchanged");
        require(migration.nftEntitlement(collection_, 3).originalId == origin_, "stable NFT origin");
        require(origin_ == keccak256(abi.encode("migration.nft", block.chainid, detf, collection_, uint256(3))),
            "exact stable origin preimage");
        Migration.NftContribution[] memory parts_ = migration.nftContributions(collection_, 3);
        require(parts_.length == 2 && parts_[0].originalEth == 999999000000000 && parts_[0].originalDtf == 0
            && parts_[1].originalEth == 0 && parts_[1].originalDtf == 362893857600000000000, "separate NFT3 components");
        console2.log("STATE_TRACE", string.concat(
            '{"state":"mixed-A-B","bookId":"', vm.toString(b_), '","stableNftOrigin":"', vm.toString(origin_),
            '","nft3":[{"originalEth":"999999000000000","originalDtf":"0","credit":"', vm.toString(parts_[0].credit),
            '"},{"originalEth":"0","originalDtf":"362893857600000000000","credit":"', vm.toString(parts_[1].credit), '"}]}'));
        _buyOwnerFirstBond();
        vm.prank(migrationOwner);
        allocation.activateMigration();
        require(migration.migrationActivated(), "terminal activation");
        require(IDiamondLoupe(detf).facetAddress(Allocation.setMigrationWeightedPricing.selector) == address(0),
            "terminal setter removed");
        console2.log("STATE_TRACE", string.concat(
            '{"state":"complete","terminal":true,"bookId":"', vm.toString(b_),
            '","stableNftOrigin":"', vm.toString(origin_), '","historicalJournalImported":false,"nft3Mode":"separate-contributions"}'));
    }

}
