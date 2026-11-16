// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {MigrationRecoveryDonationForkBase} from "./MigrationRecoveryDonation.t.sol";
import {IUniswapV4DetfMigration as Migration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IMigrationWeightedReceipt, IMigrationWeightedSynchronization} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyRecovery.sol";
import {MigrationLegacyRecoveryLib as Legacy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol";

/// @notice Controlled wallet genuinely stakes transferred WD; original quote inputs are synthetic.
abstract contract MigrationWeightedReceiptForkBase is MigrationRecoveryDonationForkBase {
    bytes32 internal constant WS_ORIGIN = keccak256("synthetic acquired WS original gons");
    address internal wsWallet;
    uint256 internal acquiredGons;
    IMigrationWeightedReceipt internal oldReceipt;

    function setUp() public virtual override {
        super.setUp();
        oldReceipt = IMigrationWeightedReceipt(Legacy.WEIGHTED_RECEIPT);
        wsWallet = vm.addr(0xD7F117);
        assertEq(wsWallet.code.length, 0);
        assertEq(oldReceipt.gonsOf(wsWallet), 0);
        acquiredGons = _acquireWs(wsWallet, 101);
    }

    function _settleWs() internal {
        IMigrationWeightedSynchronization(Legacy.WEIGHTED_DETF).synchronizeRewards();
    }

    function _acquireWs(address wallet_, uint256 native_) internal returns (uint256 gons_) {
        vm.prank(address(bytes20(hex"082cb14f04d9c485473dedc00d604d7e9abca303")));
        IERC20(Legacy.WEIGHTED_DETF).transfer(wallet_, native_);
        _settleWs();
        uint256 before_ = oldReceipt.gonsOf(wallet_);
        vm.startPrank(wallet_);
        IERC20(Legacy.WEIGHTED_DETF).approve(Legacy.WEIGHTED_RECEIPT, native_);
        oldReceipt.exchangeIn(
            Legacy.WEIGHTED_DETF, native_, Legacy.WEIGHTED_RECEIPT, native_, wallet_, false, block.timestamp
        );
        vm.stopPrank();
        gons_ = oldReceipt.gonsOf(wallet_) - before_;
        assertEq(gons_, native_ * oldReceipt.stakingState().gonsPerUnit);
    }

    function _wsInputs(address wallet_, uint256 q_)
        internal pure returns (Migration.WeightedReceiptEntitlementInput[] memory a_)
    {
        a_ = new Migration.WeightedReceiptEntitlementInput[](1);
        a_[0] = Migration.WeightedReceiptEntitlementInput(
            WS_ORIGIN, wallet_, Legacy.WEIGHTED_RECEIPT, q_, 0.01 ether, 0,
            keccak256("synthetic original principal allocation; genuine source acquisition"), true
        );
    }

    function _configureWs(address wallet_, uint256 q_) internal returns (uint256 c_) {
        vm.prank(migrationOwner);
        allocation.configureWeightedReceiptEntitlements(_wsInputs(wallet_, q_), pricingId);
        return migration.weightedReceiptEntitlement(WS_ORIGIN).credit;
    }

    function _surrenderWs(uint256 native_) internal returns (uint256 id_, uint256 credit_) {
        Migration.WeightedReceiptSurrender memory before_ = migration.weightedReceiptSurrender(WS_ORIGIN);
        uint256 custody_ = oldReceipt.gonsOf(detf);
        uint256 booked_ = recovery.migrationRecoveryGons();
        vm.startPrank(wsWallet);
        IERC20(Legacy.WEIGHTED_RECEIPT).approve(detf, native_);
        (id_, credit_) = migration.surrenderMigrationWeightedReceipt(WS_ORIGIN, native_, 1, block.timestamp);
        vm.stopPrank();
        uint256 q_ = native_ * oldReceipt.stakingState().gonsPerUnit;
        assertEq(credit_, q_ == before_.remainingUnits
            ? before_.remainingCredit : Math.mulDiv(before_.remainingCredit, q_, before_.remainingUnits));
        assertEq(oldReceipt.gonsOf(detf), custody_ + q_);
        assertEq(recovery.migrationRecoveryGons(), booked_ + q_);
        Migration.WeightedReceiptSurrender memory after_ = migration.weightedReceiptSurrender(WS_ORIGIN);
        assertEq(after_.remainingUnits, before_.remainingUnits - q_);
        assertEq(after_.remainingCredit, before_.remainingCredit - credit_);
        assertEq(after_.consumedUnits, before_.consumedUnits + q_);
        assertEq(after_.deliveredCredit, before_.deliveredCredit + credit_);
        assertEq(IERC721(address(bonds)).ownerOf(id_), wsWallet);
        assertEq(bonds.positionOf(id_).principal, credit_);
        assertEq(bonds.positionOf(id_).claimedPrincipal, 0);
        assertEq(bonds.positionOf(id_).vestingDuration, 90 days);
        assertEq(bonds.positionOf(id_).startTimestamp, vm.getBlockTimestamp());
        assertEq(bonds.positionOf(id_).stakingGons, credit_ * receipt.stakingState().gonsPerUnit);
        assertTrue(bonds.isMigrationPosition(id_));
        assertEq(IERC20(detf).allowance(detf, address(bonds)), 0);
        assertEq(IERC20(detf).allowance(address(bonds), address(receipt)), 0);
    }

    function _wsEconomicState(address wallet_) internal view returns (bytes32) {
        address fee_ = IERC721(WEIGHTED).ownerOf(1);
        address creator_ = IERC721(WEIGHTED).ownerOf(2);
        return keccak256(abi.encode(
            oldReceipt.stakingState(), oldReceipt.gonsOf(wallet_), oldReceipt.gonsOf(detf),
            oldReceipt.gonsOf(fee_), oldReceipt.gonsOf(creator_),
            IERC20(Legacy.WEIGHTED_RECEIPT).allowance(wallet_, detf),
            IERC20(Legacy.WEIGHTED_DETF).balanceOf(Legacy.WEIGHTED_RECEIPT),
            migration.weightedReceiptSurrender(WS_ORIGIN), recovery.migrationRecoveryGons(),
            recovery.migrationRecoveryInventory(Legacy.WEIGHTED_RECEIPT),
            IERC20(detf).totalSupply(), receipt.stakingState(), receipt.gonsOf(address(bonds)),
            IERC20(detf).balanceOf(address(receipt)), IERC20(detf).allowance(detf, address(bonds))
        ));
    }
}
