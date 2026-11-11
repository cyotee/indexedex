// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {MigrationNftForkBase} from "./MigrationNftForkBase.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";

/// @notice Admission on both authenticated legacy generations and the real funded Migration proxy.
contract MigrationOriginalWalletTest is MigrationNftForkBase {
    function test_weightedStageOneRejectsThenOriginalWalletAdmission() public { _admission(WEIGHTED); }
    function test_earlierStageOneRejectsThenOriginalWalletAdmission() public { _admission(EARLIER); }

    function _admission(address collection_) private {
        uint256 credit_ = _configureNft(collection_, 3);
        address original_ = _original(collection_, 3).originalWallet;
        address next_ = makeAddr("transferred wallet");
        address operator_ = makeAddr("approved operator");
        uint256 supply_ = IERC20(detf).totalSupply();
        bytes memory config_ = abi.encode(migration.nftEntitlement(collection_, 3));
        vm.startPrank(original_);
        IERC721(collection_).setApprovalForAll(operator_, true);
        IERC721(collection_).approve(detf, 3);
        vm.stopPrank();
        vm.prank(original_);
        vm.expectRevert(Migration.MigrationSurrenderClosed.selector);
        migration.surrenderMigrationNft(collection_, 3, 1, block.timestamp);
        _assertNotConsumed(collection_, 3, original_, supply_);
        assertEq(IERC721(collection_).getApproved(3), detf);
        assertEq(IERC721(address(bonds)).ownerOf(migration.migrationOwnerFirstBondTokenId() + 1), address(0));
        assertEq(abi.encode(migration.nftEntitlement(collection_, 3)), config_);
        _activate();
        vm.prank(operator_);
        vm.expectRevert(abi.encodeWithSelector(Migration.NotOriginalNftWallet.selector, operator_, original_));
        migration.surrenderMigrationNft(collection_, 3, 1, block.timestamp);
        _assertNotConsumed(collection_, 3, original_, supply_);
        assertEq(IERC721(address(bonds)).ownerOf(migration.migrationOwnerFirstBondTokenId() + 1), address(0));

        vm.prank(original_);
        IERC721(collection_).transferFrom(original_, next_, 3);
        vm.startPrank(next_);
        IERC721(collection_).approve(detf, 3);
        IERC721(collection_).setApprovalForAll(original_, true);
        vm.stopPrank();
        vm.prank(next_);
        vm.expectRevert(abi.encodeWithSelector(Migration.NotOriginalNftWallet.selector, next_, original_));
        migration.surrenderMigrationNft(collection_, 3, 1, block.timestamp);
        _assertNotConsumed(collection_, 3, next_, supply_);
        vm.prank(original_);
        vm.expectRevert(abi.encodeWithSelector(Migration.NotNftHolder.selector, original_, next_));
        migration.surrenderMigrationNft(collection_, 3, 1, block.timestamp);
        _assertNotConsumed(collection_, 3, next_, supply_);
        assertEq(abi.encode(migration.nftEntitlement(collection_, 3)), config_);
        assertEq(IERC721(address(bonds)).ownerOf(migration.migrationOwnerFirstBondTokenId() + 1), address(0));

        _returnToOriginal(collection_, 3);
        (uint256 id_, uint256 paid_) = _surrender(collection_, 3);
        assertEq(paid_, credit_);
        assertEq(IERC20(detf).totalSupply(), supply_ + credit_);
        assertEq(IERC20(detf).balanceOf(address(receipt)), initialBacking + credit_);
        assertEq(receipt.stakingState().accountedBacking, initialBacking + credit_);
        assertEq(bonds.positionOf(id_).stakingGons, credit_ * receipt.stakingState().gonsPerUnit);
        assertEq(migration.nftSurrender(collection_, 3).holder, original_);
        assertEq(abi.encode(migration.nftEntitlement(collection_, 3)), config_);
        vm.prank(original_);
        vm.expectRevert(abi.encodeWithSelector(Migration.NftAlreadyConsumed.selector, collection_, 3));
        migration.surrenderMigrationNft(collection_, 3, 1, block.timestamp);
    }

    function test_missingConfigurationRejectsActualApprovedOwnersBeforeAndAfterActivation() public {
        address[2] memory collections_ = [WEIGHTED, EARLIER];
        uint256 supply_ = IERC20(detf).totalSupply();
        for (uint256 phase_; phase_ < 2; ++phase_) {
            for (uint256 i_; i_ < collections_.length; ++i_) {
                address collection_ = collections_[i_];
                address holder_ = IERC721(collection_).ownerOf(3);
                vm.startPrank(holder_);
                IERC721(collection_).approve(detf, 3);
                vm.expectRevert(phase_ == 0 ? abi.encodeWithSelector(Migration.MigrationSurrenderClosed.selector)
                    : abi.encodeWithSelector(Migration.InvalidNftEntitlement.selector, collection_, 3));
                migration.surrenderMigrationNft(collection_, 3, 0, block.timestamp);
                vm.stopPrank();
                _assertNotConsumed(collection_, 3, holder_, supply_);
                assertEq(migration.nftEntitlement(collection_, 3).configurationId, bytes32(0));
                assertEq(IERC721(collection_).getApproved(3), detf);
                assertEq(IERC721(address(bonds)).ownerOf(migration.migrationOwnerFirstBondTokenId() + 1), address(0));
            }
            if (phase_ == 0) {
                vm.prank(migrationOwner);
                allocation.activateMigration();
            }
        }
    }

    function test_stageTwoCorrectionCannotReopenEitherConsumedOriginOrIndependentCredit() public {
        address[2] memory collections_ = [WEIGHTED, EARLIER];
        _configureNft(WEIGHTED, 3);
        _configureNft(EARLIER, 3);
        _activate();
        for (uint256 i_; i_ < collections_.length; ++i_) {
            address collection_ = collections_[i_];
            (uint256 id_,) = _surrender(collection_, 3);
            bytes memory surrender_ = abi.encode(migration.nftSurrender(collection_, 3));
            bytes memory custody_ = abi.encode(migration.nftCustody(collection_, 3));
            bytes memory bond_ = abi.encode(bonds.positionOf(id_));
            uint256 supply_ = IERC20(detf).totalSupply();
            Migration.NftEntitlement memory before_ = migration.nftEntitlement(collection_, 3);
            Migration.NftEntitlementInput[] memory rows_ = new Migration.NftEntitlementInput[](1);
            rows_[0] = _original(collection_, 3);
            rows_[0].originalWallet = makeAddr("corrected original");
            vm.prank(migrationOwner);
            (bool corrected_,) = detf.call(abi.encodeCall(Allocation.configureNftEntitlements, (rows_)));
            assertFalse(corrected_);
            rows_[0] = before_.original;
            vm.prank(migrationOwner);
            (bool replayed_,) = detf.call(abi.encodeCall(Allocation.configureNftEntitlements, (rows_)));
            assertFalse(replayed_);
            Migration.NftEntitlement memory after_ = migration.nftEntitlement(collection_, 3);
            assertEq(after_.configurationId, before_.configurationId);
            assertEq(after_.originalId, before_.originalId);
            assertEq(after_.credit, before_.credit);
            assertEq(abi.encode(migration.nftSurrender(collection_, 3)), surrender_);
            assertEq(abi.encode(migration.nftCustody(collection_, 3)), custody_);
            assertEq(abi.encode(bonds.positionOf(id_)), bond_);
            assertEq(IERC20(detf).totalSupply(), supply_);
            vm.prank(rows_[0].originalWallet);
            vm.expectRevert(abi.encodeWithSelector(Migration.NftAlreadyConsumed.selector, collection_, 3));
            migration.surrenderMigrationNft(collection_, 3, 0, block.timestamp);
            Migration.IndependentAllocationInput[] memory independent_ = new Migration.IndependentAllocationInput[](1);
            independent_[0].recipient = rows_[0].originalWallet;
            independent_[0].entitlements = new Migration.OriginalEntitlement[](1);
            independent_[0].entitlements[0] = Migration.OriginalEntitlement(before_.originalId, 1 ether, 0, bytes32("duplicate"));
            vm.prank(migrationOwner);
            (bool independentOk_,) = detf.call(abi.encodeCall(Allocation.configureIndependentAllocations, (independent_)));
            assertFalse(independentOk_);
            assertFalse(migration.independentIssuance(rows_[0].originalWallet).issued);
        }
    }
}
