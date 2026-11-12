// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {MigrationRecoveryDonationForkBase} from "./MigrationRecoveryDonation.t.sol";
import {IUniswapV4DetfMigration as Migration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {MigrationLegacyRecoveryLib as Legacy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol";

/// @notice Actual authenticated historical acquisition ABI, separate from Migration recovery.
interface IDtfCustodySeAcquisition {
    function deposit(uint256 assets_, address receiver_) external returns (uint256 shares_);
    function previewDeposit(uint256 assets_) external view returns (uint256 shares_);
    function previewRedeem(uint256 shares_) external view returns (uint256 assets_);
    function redeem(uint256 shares_, address receiver_, address owner_) external returns (uint256 assets_);
    function asset() external view returns (address);
}

/// @notice Genuine source deposits by a controlled wallet; allocation components remain synthetic.
abstract contract MigrationDtfCustodySeForkBase is MigrationRecoveryDonationForkBase {
    bytes32 internal constant SE_ORIGIN = keccak256("synthetic controlled W-SD original");
    address internal seHolder;
    uint256 internal acquiredShares;

    function setUp() public virtual override {
        super.setUp();
        seHolder = vm.addr(0xD7FC0570D1);
        assertEq(seHolder.code.length, 0);
        address facet_ = 0xDbcEEFf98F2388b0eFA0C0fDA2e08cdd263Ce8f5;
        assertEq(facet_.codehash, 0x99b74f701969463d5147a782113b30bef06ef1c65f58902d410849d6d2cef616);
        assertEq(IDiamondLoupe(Legacy.DTF_CUSTODY_SE).facetAddress(IDtfCustodySeAcquisition.deposit.selector), facet_);
        assertEq(IDiamondLoupe(Legacy.DTF_CUSTODY_SE).facetAddress(IDtfCustodySeAcquisition.redeem.selector), facet_);
        assertEq(IDtfCustodySeAcquisition(Legacy.DTF_CUSTODY_SE).asset(), Legacy.DTF);
        assertEq(IERC20Metadata(Legacy.DTF_CUSTODY_SE).decimals(), 28);
        assertEq(IERC20Metadata(Legacy.DTF).decimals(), 18);
        assertEq(IERC20(Legacy.DTF_CUSTODY_SE).balanceOf(seHolder), 0);
        IERC20(Legacy.DTF).transfer(seHolder, 1 ether);
        uint256 before_ = IERC20(Legacy.DTF).balanceOf(Legacy.DTF_CUSTODY_SE);
        uint256 quoted_ = IDtfCustodySeAcquisition(Legacy.DTF_CUSTODY_SE).previewDeposit(1 ether);
        vm.startPrank(seHolder);
        IERC20(Legacy.DTF).approve(Legacy.DTF_CUSTODY_SE, 1 ether);
        acquiredShares = IDtfCustodySeAcquisition(Legacy.DTF_CUSTODY_SE).deposit(1 ether, seHolder);
        vm.stopPrank();
        assertEq(acquiredShares, quoted_);
        assertGt(acquiredShares, 1e18);
        assertEq(IERC20(Legacy.DTF_CUSTODY_SE).balanceOf(seHolder), acquiredShares);
        assertEq(IERC20(Legacy.DTF).balanceOf(seHolder), 0);
        assertEq(IERC20(Legacy.DTF).balanceOf(Legacy.DTF_CUSTODY_SE), before_ + 1 ether);
    }

    function _seInputs(address wallet_, uint256 q_)
        internal pure returns (Migration.DtfCustodySeEntitlementInput[] memory inputs_)
    {
        inputs_ = new Migration.DtfCustodySeEntitlementInput[](1);
        inputs_[0] = Migration.DtfCustodySeEntitlementInput(
            SE_ORIGIN, wallet_, Legacy.DTF_CUSTODY_SE, q_, 0, 0.6 ether,
            keccak256("synthetic W-SD original allocation, actual source acquisition"), true
        );
    }

    function _configureSe(address wallet_, uint256 q_) internal returns (uint256) {
        vm.prank(migrationOwner);
        allocation.configureDtfCustodySeEntitlements(_seInputs(wallet_, q_));
        return migration.dtfCustodySeEntitlement(SE_ORIGIN).credit;
    }

    function _surrenderSe(uint256 q_) internal returns (uint256 id_, uint256 credit_) {
        uint256 walletBefore_ = IERC20(Legacy.DTF_CUSTODY_SE).balanceOf(seHolder);
        uint256 custodyBefore_ = IERC20(Legacy.DTF_CUSTODY_SE).balanceOf(detf);
        uint256 bookedBefore_ = recovery.migrationRecoveryInventory(Legacy.DTF_CUSTODY_SE);
        uint256 start_ = vm.getBlockTimestamp();
        vm.startPrank(seHolder);
        IERC20(Legacy.DTF_CUSTODY_SE).approve(detf, q_);
        (id_, credit_) = migration.surrenderMigrationDtfCustodySe(SE_ORIGIN, q_, 1, start_);
        vm.stopPrank();
        assertEq(IERC20(Legacy.DTF_CUSTODY_SE).balanceOf(seHolder), walletBefore_ - q_);
        assertEq(IERC20(Legacy.DTF_CUSTODY_SE).balanceOf(detf), custodyBefore_ + q_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF_CUSTODY_SE), bookedBefore_ + q_);
        assertEq(IERC721(address(bonds)).ownerOf(id_), seHolder);
        assertEq(bonds.positionOf(id_).principal, credit_);
        assertEq(bonds.positionOf(id_).claimedPrincipal, 0);
        assertEq(bonds.positionOf(id_).vestingDuration, 90 days);
        assertEq(bonds.positionOf(id_).startTimestamp, start_);
        assertEq(bonds.positionOf(id_).stakingGons, credit_ * receipt.stakingState().gonsPerUnit);
        assertTrue(bonds.isMigrationPosition(id_));
        assertEq(IERC20(detf).allowance(detf, address(bonds)), 0);
    }
}
