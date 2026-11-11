// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IUniswapV4DetfMigration as Migration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {MigrationLegacyRecoveryLib as Legacy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol";
import {MigrationRecoveryForkBase} from "./MigrationRecoveryForkBase.sol";

/// @notice Selected-work measurements, not a claim that Foundry's permissive gas cap is a chain limit.
contract MigrationRecoveryGasTest is MigrationRecoveryForkBase {
    function test_selectedWorkIndependentOfTwentyFourUnrelatedSurrenders() public {
        _take(WEIGHTED, 4);
        _take(EARLIER, 4);
        Recovery.Step[] memory selected_ = _step(Recovery.Stage.WeightedClaim, 4, 0, 0);
        uint256 small_ = _measure(selected_, 2);
        selected_ = _step(Recovery.Stage.EarlierClaim, 4, 0, 0);
        uint256 earlierSmall_ = _measure(selected_, 2);
        _populate();
        selected_ = _step(Recovery.Stage.WeightedClaim, 4, 0, 0);
        uint256 large_ = _measure(selected_, 26);
        selected_ = _step(Recovery.Stage.EarlierClaim, 4, 0, 0);
        uint256 earlierLarge_ = _measure(selected_, 26);
        assertEq(large_, small_, "unrelated custody must not add selected work");
        assertEq(earlierLarge_, earlierSmall_, "earlier work must not scan custody");
        selected_ = new Recovery.Step[](8);
        for (uint256 i_; i_ < 8; ++i_) selected_[i_] = Recovery.Step(Recovery.Stage.WeightedClaim, i_ + 4, 0, 0);
        _measure(selected_, 26);
    }

    function _measure(Recovery.Step[] memory steps_, uint256 population_) private returns (uint256 gas_) {
        uint256 snapshot_ = vm.snapshotState();
        address[10] memory accounts_ = [
            detf, WEIGHTED, EARLIER, Legacy.WEIGHTED_RECEIPT, Legacy.WEIGHTED_DETF,
            address(bonds), address(receipt), address(rawSy), address(stakingSy), migration.migrationSyRewardToken()
        ];
        for (uint256 i_; i_ < accounts_.length; ++i_) {
            IDiamondLoupe.Facet[] memory facets_ = IDiamondLoupe(accounts_[i_]).facets();
            for (uint256 j_; j_ < facets_.length; ++j_) vm.cool(facets_[j_].facetAddress);
            vm.cool(accounts_[i_]);
        }
        vm.cool(Legacy.EARLIER_DETF);
        vm.prank(migrationOwner);
        recovery.recoverMigrationNfts(steps_, block.timestamp);
        gas_ = vm.lastCallGas().gasTotalUsed;
        assertGt(recovery.migrationRecoveryInventory(
            steps_[0].stage == Recovery.Stage.EarlierClaim ? Legacy.EARLIER_DETF : Legacy.WEIGHTED_RECEIPT
        ), 0);
        assertTrue(vm.revertToStateAndDelete(snapshot_));
        emit RecoveryGas(steps_[0].stage == Recovery.Stage.EarlierClaim ? bytes32("ER1_COLD") : bytes32("W1_COLD"),
            steps_.length, population_, gas_);
    }

    /// @dev Original purchase receipt joins from phase01 weighted/probe.historical-receipts.json.
    /// Only direct authenticated nonzero ETH/WETH or DTF inputs; no missing value is treated as zero.
    function _populate() private {
        Migration.NftEntitlementInput[] memory rows_ = new Migration.NftEntitlementInput[](24);
        rows_[0] = Migration.NftEntitlementInput(WEIGHTED, 5, address(bytes20(hex"ec8c4eb216cbfc5b7f49b83cfbe6e34212863ae8")), 462445599, 50000000000000000, 0, 0x1812ec8bd64c0629707c30da87cf59d786426271065b0f653501862339947293, true);
        rows_[1] = Migration.NftEntitlementInput(WEIGHTED, 6, address(bytes20(hex"ec8c4eb216cbfc5b7f49b83cfbe6e34212863ae8")), 740825635, 80000000000000000, 0, 0xeefb57d4fd369c08c6050f125d93f19c7171c557f0280270049ed4c6e613a917, true);
        rows_[2] = Migration.NftEntitlementInput(WEIGHTED, 7, address(bytes20(hex"ec8c4eb216cbfc5b7f49b83cfbe6e34212863ae8")), 1200103129, 130000000000000000, 0, 0xa19407e27f675728c094c6ee0c0f40a37d5be24baaa99b0b68dd58191a25d296, true);
        rows_[3] = Migration.NftEntitlementInput(WEIGHTED, 8, address(bytes20(hex"ec8c4eb216cbfc5b7f49b83cfbe6e34212863ae8")), 1937763154, 220000000000000000, 0, 0xce2e18987a6cd3644b52702fb9ac47fb34e34916ed7c27355c183a72414bb8cb, true);
        rows_[4] = Migration.NftEntitlementInput(WEIGHTED, 9, address(bytes20(hex"ec8c4eb216cbfc5b7f49b83cfbe6e34212863ae8")), 3147607863, 150000000000000000, 0, 0x70fb38227e885c80057c384a0ffad1a31912220b7c47d6e29957960849f11d2a, true);
        rows_[5] = Migration.NftEntitlementInput(WEIGHTED, 10, address(bytes20(hex"ec8c4eb216cbfc5b7f49b83cfbe6e34212863ae8")), 5077481904, 180000000000000000, 0, 0xf84c55aaee2784b0334e2af96ba6700242060ef5dd33844d4b18d3106f648651, true);
        rows_[6] = Migration.NftEntitlementInput(WEIGHTED, 11, address(bytes20(hex"3e01a5779cfa830794dbb9c8673a61b3c5c5608a")), 44048877, 0, 117620151493077568323998, 0xb86e32336704974be5a4c3973269bf2a7256acdb4e262badd13409e4ba174c0b, true);
        rows_[7] = Migration.NftEntitlementInput(WEIGHTED, 12, address(bytes20(hex"b2b12665da21fccfb9b8e4d4f2349a4c835fc669")), 1455956506, 0, 1000000000000000000000000, 0xbab7b6801334d28cc2805a716aac0b3d08f7d531ab888a1bbddfb8030826aec1, true);
        rows_[8] = Migration.NftEntitlementInput(WEIGHTED, 13, address(bytes20(hex"e8ca5d7b03204d110ff8a06753e7cd90defc544a")), 1915, 0, 1000000000000000000, 0x61b92972e5c140d2f79db2e8990ca8cd6d4b0590f43eeaa4abd9bfc36fdf61bb, true);
        rows_[9] = Migration.NftEntitlementInput(WEIGHTED, 14, address(bytes20(hex"5160f655bf9b567f8a47a4f107371ad938126c3c")), 191603, 0, 100000000000000000000, 0xf9698195b5d4497e0b9b719808697cf1449f3a1ccbbcbaa8cb786a55717ad2cd, true);
        rows_[10] = Migration.NftEntitlementInput(WEIGHTED, 15, address(bytes20(hex"e8ca5d7b03204d110ff8a06753e7cd90defc544a")), 1915, 0, 1000000000000000000, 0x1d01114d19123fc4672351935617087af66ffbf7150878d5ece34558bd25bc27, true);
        rows_[11] = Migration.NftEntitlementInput(WEIGHTED, 16, address(bytes20(hex"03f523d7243aaf869c44322197b4fc55e0d12cd7")), 153080136, 0, 84207000000000000000000, 0xb2bef901e7b6ff58446a79a6de19a4536b7892f14fd7160d2ae4408c23ae90c1, true);
        rows_[12] = Migration.NftEntitlementInput(WEIGHTED, 17, address(bytes20(hex"4aa38d56933887bdba2e790fa45509bfd9d1b938")), 179696, 0, 100000000000000000000, 0x95495a3c68397d245175693240a7f37889e55ca1d0431e6b2b7e47162479878b, true);
        rows_[13] = Migration.NftEntitlementInput(WEIGHTED, 18, address(bytes20(hex"dc7d32b21cfdf003b5467141bd67e1f68a732cce")), 49053117, 0, 28722838050154716955768, 0xe213477237aca92a72461478bb797b2208f79eb872fac28dfeb1130e18d5b1bd, true);
        rows_[14] = Migration.NftEntitlementInput(WEIGHTED, 21, address(bytes20(hex"ed2e9d1e229e6a78baf74abc7314bd16b9924f33")), 17650489, 0, 13638592554139803593186, 0x4f337590de70440aff4716fdd44abd1fb1dd678a211443b8eb3c1a938a93ad0d, true);
        rows_[15] = Migration.NftEntitlementInput(WEIGHTED, 22, address(bytes20(hex"8b73c11e053581620bf5d7826d0942c50cb7b9cf")), 1288034730, 0, 1010505832294964975193008, 0x412965ee1ae9b6c8e23939f443f080ee62f5204c1a40319ba23b6a78091cf4ac, true);
        rows_[16] = Migration.NftEntitlementInput(WEIGHTED, 24, address(bytes20(hex"ec8c4eb216cbfc5b7f49b83cfbe6e34212863ae8")), 1300890757, 2000000000000000000, 0, 0xcce46effe1c0877581ab82bcd32f5690b09dd9eaa782bf653c8545ff9f608352, true);
        rows_[17] = Migration.NftEntitlementInput(WEIGHTED, 26, address(bytes20(hex"c379feb4182211abe71a34858265e4bf5ff35e06")), 56299, 0, 50000000000000000000, 0x03a24910340df937a7597382909e015284f60432f266e63ffc163dc559255e0d, true);
        rows_[18] = Migration.NftEntitlementInput(WEIGHTED, 27, address(bytes20(hex"4aa38d56933887bdba2e790fa45509bfd9d1b938")), 3302546215, 0, 3638287394965303325165504, 0x343e2e392a180d5d7b325ad655b26c0af8d6e10ef393c8a63cae9afd33ead0a0, true);
        rows_[19] = Migration.NftEntitlementInput(WEIGHTED, 28, address(bytes20(hex"b63159deb0ed4b388b964c5eb5a9f2845e469a08")), 3726336268, 0, 4646962928061246692056443, 0x3c4d60f7662423e28bb9701d0d0cc86fba5f1f0a72b657bbab43c86a23ae8737, true);
        rows_[20] = Migration.NftEntitlementInput(WEIGHTED, 29, address(bytes20(hex"cb2735084b4c10343e2f54c2c7573615ccf4d97f")), 1777911406, 0, 2000000000000000000000000, 0x4657b3a4dc9d185528850a3c348328e2731f1130087464370e9963d0a41c57f1, true);
        rows_[21] = Migration.NftEntitlementInput(WEIGHTED, 30, address(bytes20(hex"ec8c4eb216cbfc5b7f49b83cfbe6e34212863ae8")), 457125470, 0, 500000000000000000000000, 0x0b710505696fd871c01a6a671eaf7899bddc3c506972d8ebe88a44f2e46f71d9, true);
        rows_[22] = Migration.NftEntitlementInput(WEIGHTED, 31, address(bytes20(hex"ec8c4eb216cbfc5b7f49b83cfbe6e34212863ae8")), 4031493805, 6190000000000000000, 0, 0x7bdfad0304c2c6b95a966cb524aa266e20c042dab687376982ae5da4b615da04, true);
        rows_[23] = Migration.NftEntitlementInput(WEIGHTED, 32, address(bytes20(hex"4dfebb21d855115d4019819393e514977e490e5d")), 54436459, 0, 56017714220190058289217, 0x66c1011955675c6927bf67fd64935a147dec659a1791e8ee86ea5cacfdd70914, true);
        vm.prank(migrationOwner);
        allocation.configureNftEntitlements(rows_);
        _returnToOriginal(WEIGHTED, 26);
        for (uint256 i_; i_ < rows_.length; ++i_) _surrender(WEIGHTED, rows_[i_].tokenId);
    }
}
