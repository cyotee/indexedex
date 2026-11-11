// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {MigrationNftForkBase} from "./MigrationNftForkBase.sol";
import {IUniswapV4DetfMigration as Migration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";

/// @notice Admission on both authenticated legacy generations and the real funded Migration proxy.
contract MigrationOriginalWalletTest is MigrationNftForkBase {
    function test_weightedAdmissionBeforeActivation() public { _admission(WEIGHTED, false); }
    function test_weightedAdmissionAfterActivation() public { _admission(WEIGHTED, true); }
    function test_earlierAdmissionBeforeActivation() public { _admission(EARLIER, false); }
    function test_earlierAdmissionAfterActivation() public { _admission(EARLIER, true); }

    function _admission(address collection_, bool activate_) private {
        uint256 credit_ = _configureNft(collection_, 3);
        address original_ = _original(collection_, 3).originalWallet;
        address next_ = makeAddr("transferred wallet");
        address operator_ = makeAddr("approved operator");
        if (activate_) {
            vm.prank(migrationOwner);
            allocation.activateMigration();
        }
        uint256 supply_ = IERC20(detf).totalSupply();
        bytes memory config_ = abi.encode(migration.nftEntitlement(collection_, 3));
        vm.startPrank(original_);
        IERC721(collection_).setApprovalForAll(operator_, true);
        IERC721(collection_).approve(detf, 3);
        vm.stopPrank();
        vm.prank(operator_);
        vm.expectRevert(abi.encodeWithSelector(Migration.NotOriginalNftWallet.selector, operator_, original_));
        migration.surrenderMigrationNft(collection_, 3, 1, block.timestamp);
        _assertNotConsumed(collection_, 3, original_, supply_);
        assertEq(IERC721(address(bonds)).ownerOf(3), address(0));

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
        assertEq(IERC721(address(bonds)).ownerOf(3), address(0));

        _returnToOriginal(collection_, 3);
        (uint256 id_, uint256 paid_) = _surrender(collection_, 3);
        assertEq(paid_, credit_);
        assertEq(IERC20(detf).totalSupply(), supply_ + credit_);
        assertEq(IERC20(detf).balanceOf(address(receipt)), credit_);
        assertEq(receipt.stakingState().accountedBacking, credit_);
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
                vm.expectRevert(abi.encodeWithSelector(Migration.InvalidNftEntitlement.selector, collection_, 3));
                migration.surrenderMigrationNft(collection_, 3, 0, block.timestamp);
                vm.stopPrank();
                _assertNotConsumed(collection_, 3, holder_, supply_);
                assertEq(migration.nftEntitlement(collection_, 3).configurationId, bytes32(0));
                assertEq(IERC721(collection_).getApproved(3), detf);
                assertEq(IERC721(address(bonds)).ownerOf(3), address(0));
            }
            if (phase_ == 0) {
                vm.prank(migrationOwner);
                allocation.activateMigration();
            }
        }
    }

    function test_walletCorrectionCannotReopenEitherConsumedOriginOrIndependentCredit() public {
        address[2] memory collections_ = [WEIGHTED, EARLIER];
        for (uint256 i_; i_ < collections_.length; ++i_) {
            address collection_ = collections_[i_];
            _configureNft(collection_, 3);
            (uint256 id_,) = _surrender(collection_, 3);
            bytes memory surrender_ = abi.encode(migration.nftSurrender(collection_, 3));
            bytes memory custody_ = abi.encode(migration.nftCustody(collection_, 3));
            bytes memory bond_ = abi.encode(bonds.positionOf(id_));
            uint256 supply_ = IERC20(detf).totalSupply();
            Migration.NftEntitlement memory before_ = migration.nftEntitlement(collection_, 3);
            Migration.NftEntitlementInput[] memory rows_ = new Migration.NftEntitlementInput[](1);
            rows_[0] = _original(collection_, 3);
            rows_[0].originalWallet = makeAddr("corrected original");
            vm.startPrank(migrationOwner);
            allocation.configureNftEntitlements(rows_);
            allocation.configureNftEntitlements(rows_);
            vm.stopPrank();
            Migration.NftEntitlement memory after_ = migration.nftEntitlement(collection_, 3);
            assertNotEq(after_.configurationId, before_.configurationId);
            assertEq(after_.originalId, before_.originalId);
            assertEq(after_.credit, before_.credit);
            assertEq(abi.encode(migration.nftSurrender(collection_, 3)), surrender_);
            assertEq(abi.encode(migration.nftCustody(collection_, 3)), custody_);
            assertEq(abi.encode(bonds.positionOf(id_)), bond_);
            assertEq(IERC20(detf).totalSupply(), supply_);
            vm.prank(rows_[0].originalWallet);
            vm.expectRevert(abi.encodeWithSelector(Migration.NftAlreadyConsumed.selector, collection_, 3));
            migration.surrenderMigrationNft(collection_, 3, 0, block.timestamp);
            vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, before_.originalId));
            _configure(rows_[0].originalWallet, 1 ether, before_.originalId);
        }
    }
}
