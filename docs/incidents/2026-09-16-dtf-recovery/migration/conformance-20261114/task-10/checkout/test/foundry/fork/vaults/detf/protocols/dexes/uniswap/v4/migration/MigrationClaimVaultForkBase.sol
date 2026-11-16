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

/// @notice Executed pinned acquisition ABI, separate from Migration recovery.
interface IClaimVaultAcquisition {
    function deposit(uint256 assets_, address receiver_) external returns (uint256 shares_);
    function previewDeposit(uint256 assets_) external view returns (uint256 shares_);
    function previewRedeem(uint256 shares_) external view returns (uint256 assets_);
    function redeem(uint256 shares_, address receiver_, address owner_) external returns (uint256 assets_);
    function asset() external view returns (address);
}

/// @notice Genuine source deposits by a controlled wallet; allocation components remain synthetic.
abstract contract MigrationClaimVaultForkBase is MigrationRecoveryDonationForkBase {
    bytes32 internal constant SE_ORIGIN = keccak256("synthetic controlled claim-vault original");
    address internal seHolder;
    uint256 internal acquiredShares;

    function setUp() public virtual override {
        super.setUp();
        seHolder = vm.addr(0xD7FC0570D1);
        assertEq(seHolder.code.length, 0);
        address facet_ = 0x517234F78A4BcAfc5F880024A3E45D49cF43b305;
        assertEq(facet_.codehash, 0x8c1ea71d607b09b21c4e78f850647a059dc7935b6772f7cd3aeaa700a995439f);
        assertEq(IDiamondLoupe(Legacy.CLAIM_VAULT).facetAddress(IClaimVaultAcquisition.deposit.selector), facet_);
        assertEq(IDiamondLoupe(Legacy.CLAIM_VAULT).facetAddress(IClaimVaultAcquisition.redeem.selector), facet_);
        assertEq(IClaimVaultAcquisition(Legacy.CLAIM_VAULT).asset(), Legacy.WEIGHTED_SY);
        assertEq(IERC20Metadata(Legacy.CLAIM_VAULT).decimals(), 19);
        assertEq(IERC20Metadata(Legacy.WEIGHTED_SY).decimals(), 9);
        assertEq(IERC20(Legacy.CLAIM_VAULT).balanceOf(seHolder), 0);
        vm.prank(address(bytes20(hex"11c17f25e958e4637dd26ca362adeae12e24ed5b")));
        IERC20(Legacy.WEIGHTED_SY).transfer(address(this), 12000);
        IERC20(Legacy.WEIGHTED_SY).transfer(seHolder, 3000);
        uint256 before_ = IERC20(Legacy.WEIGHTED_SY).balanceOf(Legacy.CLAIM_VAULT);
        uint256 quoted_ = IClaimVaultAcquisition(Legacy.CLAIM_VAULT).previewDeposit(3000);
        vm.startPrank(seHolder);
        IERC20(Legacy.WEIGHTED_SY).approve(Legacy.CLAIM_VAULT, 3000);
        acquiredShares = IClaimVaultAcquisition(Legacy.CLAIM_VAULT).deposit(3000, seHolder);
        vm.stopPrank();
        assertEq(acquiredShares, quoted_);
        assertEq(acquiredShares, 29999999967592);
        assertEq(IERC20(Legacy.CLAIM_VAULT).balanceOf(seHolder), acquiredShares);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(seHolder), 0);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(Legacy.CLAIM_VAULT), before_ + 3000);
    }

    function _seInputs(address wallet_, uint256 q_)
        internal pure returns (Migration.ClaimVaultEntitlementInput[] memory inputs_)
    {
        inputs_ = new Migration.ClaimVaultEntitlementInput[](1);
        inputs_[0] = Migration.ClaimVaultEntitlementInput(
            SE_ORIGIN, wallet_, Legacy.CLAIM_VAULT, q_, 0, 0.6 ether,
            keccak256("synthetic direct original, actual source acquisition"), true
        );
    }

    function _configureSe(address wallet_, uint256 q_) internal returns (uint256) {
        vm.prank(migrationOwner);
        allocation.configureClaimVaultEntitlements(_seInputs(wallet_, q_), pricingId);
        return migration.claimVaultEntitlement(SE_ORIGIN).credit;
    }

    function _surrenderSe(uint256 q_) internal returns (uint256 id_, uint256 credit_) {
        uint256 walletBefore_ = IERC20(Legacy.CLAIM_VAULT).balanceOf(seHolder);
        uint256 custodyBefore_ = IERC20(Legacy.CLAIM_VAULT).balanceOf(detf);
        uint256 bookedBefore_ = recovery.migrationRecoveryInventory(Legacy.CLAIM_VAULT);
        uint256 start_ = vm.getBlockTimestamp();
        vm.startPrank(seHolder);
        IERC20(Legacy.CLAIM_VAULT).approve(detf, q_);
        (id_, credit_) = migration.surrenderMigrationClaimVault(SE_ORIGIN, q_, 1, start_);
        vm.stopPrank();
        assertEq(IERC20(Legacy.CLAIM_VAULT).balanceOf(seHolder), walletBefore_ - q_);
        assertEq(IERC20(Legacy.CLAIM_VAULT).balanceOf(detf), custodyBefore_ + q_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.CLAIM_VAULT), bookedBefore_ + q_);
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
