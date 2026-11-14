// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation}
    from "../interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from "../interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {IUniswapV4DetfMigrationBondNFTVault as Bonds} from "../bondNft/IUniswapV4DetfMigrationBondNFTVault.sol";
import {IUniswapV4DetfMigrationStakedDETF as MigrationReceipt} from "../claimToken/IUniswapV4DetfMigrationStakedDETF.sol";
import {IMigrationWeightedReceipt, IMigrationEarlierReceipt} from "../legacy/IMigrationLegacyRecovery.sol";
import {MigrationLegacyRecoveryLib as Legacy} from "../legacy/MigrationLegacyRecoveryLib.sol";

/// @notice Ten fixed admitted sources; their original units are never summed or normalized.
/// @dev ABI-equivalent original/surrender tuples share encoding only, not unit arithmetic.
abstract contract MigrationSourceUnitsLedger is Test {
    struct Row {
        bytes32 origin;
        uint256 originalQ;
        uint256 originalC;
        uint256 q;
        uint256 c;
        uint256 delivered;
        uint256 walletFloor;
        uint256 custodyFloor;
        uint256 inventory;
        bytes32 configuration;
        bytes32 entitlementHash;
        uint256 allowance;
    }
    struct Position {
        uint256 id;
        uint256 principal;
        uint256 claimed;
        uint256 gons;
        uint256 start;
        address holder;
        bool retired;
    }
    Migration public parent;
    Recovery public recovery;
    Bonds public bonds;
    MigrationReceipt public receipt;
    Row[10] internal rows;
    Position[] internal positions;
    uint256 internal baseSupply;
    uint256 internal baseBacking;
    uint256 internal baseGons;
    uint256 internal issued;
    uint256 internal positionGons;
    uint256 internal k;
    uint256 internal dtfFloor;
    uint256 internal dtfRecovered;
    uint256 internal syFloor;
    uint256 internal syRecovered;
    uint256 internal wsNative;
    uint256 public earlierExternalShares;
    uint256 public earlierRewards;
    bool internal earlierTaken;
    bool internal earlierSold;
    bytes32 internal independentHistory;
    bytes32 internal independentConfiguration;
    address internal constant EARLIER_NFT = 0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391;
    bytes32 internal snapshot;
    address public currentOwner;
    uint256[10] public surrenderSuccesses;
    uint256[10] public rejectionCounts;
    uint256[10] public fundingRollbacks;
    uint256 public recoveries;
    uint256 public principalPaid;
    uint256 public transfers;
    address internal constant OTHER = address(0x24CC);

    constructor(Migration parent_) {
        parent = parent_; recovery = Recovery(address(parent_));
        bonds = Bonds(parent_.bondNftVault()); receipt = MigrationReceipt(parent_.rebasingClaimToken());
        baseSupply = IERC20(address(parent_)).totalSupply();
        baseBacking = IERC20(address(parent_)).balanceOf(address(receipt));
        baseGons = receipt.gonsOf(address(bonds));
        k = receipt.stakingState().gonsPerUnit;
        snapshot = keccak256(abi.encode(parent_.migrationSnapshot()));
        currentOwner = parent_.owner();
        dtfFloor = IERC20(Legacy.DTF).balanceOf(address(parent_));
        syFloor = IERC20(Legacy.WEIGHTED_SY).balanceOf(address(parent_));
    }

    function source(uint256 i_) public pure returns (address) {
        address[10] memory sources_ = [Legacy.WEIGHTED_DETF, Legacy.EARLIER_DETF,
            Legacy.WEIGHTED_RECEIPT, Legacy.EARLIER_RECEIPT, Legacy.CLAIM_VAULT,
            Legacy.DTF_CUSTODY_SE, Legacy.WEIGHTED_WETH_SE, Legacy.EARLIER_LP, Legacy.WEIGHTED_LP, Legacy.EARLIER_SE];
        return sources_[i_];
    }

    function surrenderSelector(uint256 i_) public pure returns (bytes4) {
        bytes4[10] memory selectors_ = [Migration.surrenderMigrationWeightedLiquid.selector,
            Migration.surrenderMigrationEarlierLiquid.selector, Migration.surrenderMigrationWeightedReceipt.selector,
            Migration.surrenderMigrationEarlierReceipt.selector, Migration.surrenderMigrationClaimVault.selector,
            Migration.surrenderMigrationDtfCustodySe.selector, Migration.surrenderMigrationHeldSeLp.selector,
            Migration.surrenderMigrationHeldSeLp.selector, Migration.surrenderMigrationHeldSeLp.selector, Migration.surrenderMigrationHeldSeLp.selector];
        return selectors_[i_];
    }

    function querySelector(uint256 i_) public pure returns (bytes4) {
        bytes4[10] memory selectors_ = [Migration.weightedLiquidSurrender.selector, Migration.earlierLiquidSurrender.selector,
            Migration.weightedReceiptSurrender.selector, Migration.earlierReceiptSurrender.selector,
            Migration.claimVaultSurrender.selector, Migration.dtfCustodySeSurrender.selector,
            Migration.heldSeLpSurrender.selector, Migration.heldSeLpSurrender.selector, Migration.heldSeLpSurrender.selector, Migration.heldSeLpSurrender.selector];
        return selectors_[i_];
    }

    function configSelector(uint256 i_) public pure returns (bytes4) {
        bytes4[10] memory selectors_ = [Allocation.configureWeightedLiquidEntitlements.selector,
            Allocation.configureEarlierLiquidEntitlements.selector, Allocation.configureWeightedReceiptEntitlements.selector,
            Allocation.configureEarlierReceiptEntitlements.selector, Allocation.configureClaimVaultEntitlements.selector,
            Allocation.configureDtfCustodySeEntitlements.selector, Allocation.configureHeldSeLpEntitlements.selector,
            Allocation.configureHeldSeLpEntitlements.selector, Allocation.configureHeldSeLpEntitlements.selector, Allocation.configureHeldSeLpEntitlements.selector];
        return selectors_[i_];
    }

    function entitlementSelector(uint256 i_) public pure returns (bytes4) {
        bytes4[10] memory selectors_ = [Migration.weightedLiquidEntitlement.selector, Migration.earlierLiquidEntitlement.selector,
            Migration.weightedReceiptEntitlement.selector, Migration.earlierReceiptEntitlement.selector,
            Migration.claimVaultEntitlement.selector, Migration.dtfCustodySeEntitlement.selector,
            Migration.heldSeLpEntitlement.selector, Migration.heldSeLpEntitlement.selector, Migration.heldSeLpEntitlement.selector, Migration.heldSeLpEntitlement.selector];
        return selectors_[i_];
    }

    function invalidRecord(uint256 i_) public pure returns (bytes4) {
        bytes4[10] memory errors_ = [Migration.InvalidWeightedLiquidEntitlement.selector, Migration.InvalidEarlierLiquidEntitlement.selector,
            Migration.InvalidWeightedReceiptEntitlement.selector, Migration.InvalidEarlierReceiptEntitlement.selector,
            Migration.InvalidClaimVaultEntitlement.selector, Migration.InvalidDtfCustodySeEntitlement.selector,
            Migration.InvalidHeldSeLpEntitlement.selector, Migration.InvalidHeldSeLpEntitlement.selector,
            Migration.InvalidHeldSeLpEntitlement.selector, Migration.InvalidHeldSeLpEntitlement.selector];
        return errors_[i_];
    }

    function wrongWallet(uint256 i_) public pure returns (bytes4) {
        bytes4[10] memory errors_ = [Migration.NotOriginalWeightedLiquidWallet.selector, Migration.NotOriginalEarlierLiquidWallet.selector,
            Migration.NotOriginalWeightedReceiptWallet.selector, Migration.NotOriginalEarlierReceiptWallet.selector,
            Migration.NotOriginalClaimVaultWallet.selector, Migration.NotOriginalDtfCustodySeWallet.selector,
            Migration.NotOriginalHeldSeLpWallet.selector, Migration.NotOriginalHeldSeLpWallet.selector,
            Migration.NotOriginalHeldSeLpWallet.selector, Migration.NotOriginalHeldSeLpWallet.selector];
        return errors_[i_];
    }

    function quantityError(uint256 i_) public pure returns (bytes4) {
        bytes4[10] memory errors_ = [Migration.InvalidWeightedLiquidQuantity.selector, Migration.InvalidEarlierLiquidQuantity.selector,
            Migration.InvalidWeightedReceiptQuantity.selector, Migration.InvalidEarlierReceiptQuantity.selector,
            Migration.InvalidClaimVaultQuantity.selector, Migration.InvalidDtfCustodySeQuantity.selector,
            Migration.InvalidHeldSeLpQuantity.selector, Migration.InvalidHeldSeLpQuantity.selector,
            Migration.InvalidHeldSeLpQuantity.selector, Migration.InvalidHeldSeLpQuantity.selector];
        return errors_[i_];
    }

    /// @dev Read-only independent diagnostic, matching the admitted historical ER layout.
    /// There is no fictitious internal-share ABI and no source storage write.
    function units(uint256 i_, address wallet_) public view returns (uint256) {
        if (i_ == 2) return IMigrationWeightedReceipt(source(i_)).gonsOf(wallet_);
        if (i_ == 3) {
            uint256 slot_ = uint256(keccak256("indexedex.vaults.protocol.richir")) + 5;
            return uint256(vm.load(source(i_), keccak256(abi.encode(wallet_, slot_))));
        }
        return IERC20(source(i_)).balanceOf(wallet_);
    }

    function nativeMaximum(uint256 i_) public view returns (uint256) {
        uint256 q_ = rows[i_].q;
        if (i_ == 2) return q_ / IMigrationWeightedReceipt(source(i_)).stakingState().gonsPerUnit;
        if (i_ == 3) return ((q_ + 1) * IMigrationEarlierReceipt(source(i_)).redemptionRate() - 1) / 1e27;
        return q_;
    }

    function eligibleUnits(uint256 i_, uint256 native_) public view returns (uint256) {
        if (i_ == 2) return native_ * IMigrationWeightedReceipt(source(i_)).stakingState().gonsPerUnit;
        if (i_ == 3) return Math.mulDiv(native_, 1e27, IMigrationEarlierReceipt(source(i_)).redemptionRate());
        return native_;
    }

    function row(uint256 i_) external view returns (Row memory) { return rows[i_]; }
    function positionCount() external view returns (uint256) { return positions.length; }
    function positionStart(uint256 i_) external view returns (uint256) { return positions[i_].start; }

    function assertAll() public view {
        assertEq(parent.owner(), currentOwner);
        assertEq(keccak256(abi.encode(parent.migrationSnapshot())), snapshot);
        assertEq(IERC20(address(parent)).totalSupply(), baseSupply + issued);
        assertEq(IERC20(address(parent)).balanceOf(address(receipt)), baseBacking + issued);
        assertEq(receipt.stakingState().gonsPerUnit, k);
        assertEq(receipt.gonsOf(address(bonds)), baseGons + positionGons);
        if (independentHistory != bytes32(0)) {
            assertEq(keccak256(abi.encode(parent.independentIssuance(OTHER))), independentHistory);
            assertEq(parent.independentAllocation(OTHER).configurationId, independentConfiguration);
        }
        for (uint256 i_; i_ < 10; ++i_) {
            Row memory r_ = rows[i_];
            (bool ok_, bytes memory state_) = address(parent).staticcall(abi.encodeWithSelector(querySelector(i_), r_.origin));
            assertTrue(ok_);
            assertEq(state_, abi.encode(r_.originalQ - r_.q, r_.delivered, r_.q, r_.c), "exact source-unit Q/C recurrence");
            (ok_, state_) = address(parent).staticcall(abi.encodeWithSelector(entitlementSelector(i_), r_.origin));
            assertTrue(ok_);
            assertEq(keccak256(state_), r_.entitlementHash, "input-derived frozen original identity and configuration");
            assertEq(r_.delivered + r_.c, r_.originalC);
            assertEq(units(i_, address(this)), r_.walletFloor + r_.q);
            assertEq(units(i_, address(parent)),
                r_.custodyFloor + r_.inventory + (i_ == 3 ? earlierExternalShares * 1e9 : 0));
            assertEq(units(i_, OTHER), 0);
            assertEq(IERC20(source(i_)).allowance(address(this), address(parent)), r_.allowance);
            if (i_ == 2) {
                assertEq(recovery.migrationRecoveryGons(), r_.inventory);
                assertEq(recovery.migrationRecoveryInventory(source(i_)), wsNative);
            } else if (i_ == 3) {
                assertEq(recovery.migrationEarlierReceiptInternalShares(), r_.inventory);
                assertEq(recovery.migrationRecoveryInventory(source(i_)), earlierExternalShares, "separate NFT external shares");
                assertEq(IMigrationEarlierReceipt(source(i_)).sharesOf(address(parent)),
                    (r_.custodyFloor + r_.inventory) / 1e9 + earlierExternalShares);
            } else assertEq(recovery.migrationRecoveryInventory(source(i_)), r_.inventory);
        }
        assertEq(IERC20(Legacy.DTF).balanceOf(address(parent)), dtfFloor + dtfRecovered);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), dtfRecovered);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(address(parent)), syFloor + syRecovered);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_SY), syRecovered);
        if (earlierTaken) {
            assertEq(IERC721(EARLIER_NFT).ownerOf(3), earlierSold ? address(0) : address(parent));
            assertTrue(parent.nftSurrender(EARLIER_NFT, 3).consumed);
            assertEq(recovery.migrationNftRecovery(EARLIER_NFT, 3).sold, earlierSold);
            assertEq(recovery.migrationNftRecovery(EARLIER_NFT, 3).receiptShares, earlierExternalShares);
            assertEq(recovery.migrationNftRecovery(EARLIER_NFT, 3).rewardsClaimed, earlierRewards);
        }
        for (uint256 i_; i_ < positions.length; ++i_) {
            Position memory p_ = positions[i_];
            assertEq(IERC721(address(bonds)).ownerOf(p_.id), p_.retired ? address(0) : p_.holder);
            if (p_.retired) continue;
            assertEq(bonds.positionOf(p_.id).principal, p_.principal);
            assertEq(bonds.positionOf(p_.id).claimedPrincipal, p_.claimed);
            assertEq(bonds.positionOf(p_.id).stakingGons, p_.gons);
            assertEq(bonds.positionOf(p_.id).startTimestamp, p_.start);
            assertEq(bonds.positionOf(p_.id).vestingDuration, 90 days);
            assertGe(p_.gons / k, p_.principal - p_.claimed);
            if (block.timestamp < p_.start + 90 days) assertEq(bonds.previewClaim(p_.id).principalDue, 0);
        }
    }
}
