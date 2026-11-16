// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationStakedDETF as Receipt} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/claimToken/IUniswapV4DetfMigrationStakedDETF.sol";
import {TestBase_UniswapV4DetfMigration_Adversarial} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration_Adversarial.sol";
import {MigrationHostileContribution} from "./MigrationHostileContribution.t.sol";

/// @notice Genuine external contract owner; calls real parent/children during an external payment callback.
contract PaidOwnerWallet {
    Migration immutable parent;
    IERC20 immutable payment;
    uint256 public probes;
    constructor(Migration parent_, IERC20 payment_) { parent = parent_; payment = payment_; }
    function accept() external { parent.acceptOwnershipTransfer(); }
    function buy(bool pretransferred_) external returns (uint256 id_) {
        payment.approve(address(parent), 1 ether);
        (id_,) = parent.bond(payment, 1 ether, 90 days, address(this), pretransferred_, block.timestamp);
    }
    function probe() external {
        require(msg.sender == address(payment), "payment callback only");
        ++probes;
        require(parent.migrationOwnerFirstBondTokenId() == 0 && !parent.migrationActivated(), "premature completion");
        (bool active_, bytes memory reason_) = address(parent).call(abi.encodeCall(Allocation.activateMigration, ()));
        require(!active_, "callback activation");
        require(keccak256(reason_) == keccak256(abi.encodeWithSignature("IsLocked()")), "activation error");
        (bool bond_, bytes memory bondReason_) = address(parent).call(abi.encodeWithSignature(
            "bond(address,uint256,uint256,address,bool,uint256)", payment, 1 ether, 90 days, address(this), false, block.timestamp
        ));
        require(!bond_, "callback second bond");
        require(keccak256(bondReason_) == keccak256(abi.encodeWithSignature("NotAuthorized(address)", address(this))), "bond error");
        (bool mint_, bytes memory mintReason_) = address(parent).call(abi.encodeCall(IStandardExchangeIn.exchangeIn, (
            payment, 1 ether, IERC20(address(parent)), 0, address(this), false, block.timestamp
        )));
        require(!mint_, "callback acquisition");
        require(keccak256(mintReason_) == keccak256(abi.encodeWithSignature("MigrationRewardsClosed()")), "mint error");
        (bool rewards_, bytes memory rewardsReason_) = parent.rebasingClaimToken().call(
            abi.encodeCall(Receipt.claimDeferredRoleRewards, (address(this)))
        );
        require(!rewards_, "callback rewards");
        require(keccak256(rewardsReason_) == keccak256(abi.encodeWithSignature("NotAuthorized(address)", parent.rebasingClaimToken())), "reward error");
    }
}

contract MigrationOwnerBondCallbacksTest is TestBase_UniswapV4DetfMigration_Adversarial {
    /// @notice Catches publication during a payment callback and leaked purchase state after short payment.
    function test_contractOwnerPaymentCallbacksCannotPublishOrBypassAndShortReceiptRollsBack() public {
        _fundAndCapture();
        MigrationHostileContribution token_ = MigrationHostileContribution(pairB);
        PaidOwnerWallet wallet_ = new PaidOwnerWallet(migration, IERC20(pairB));
        token_.transfer(address(wallet_), 1 ether);
        vm.prank(migrationOwner);
        migration.initiateOwnershipTransfer(address(wallet_));
        wallet_.accept();
        bytes memory initial_ = abi.encode(receipt.stakingState());
        uint256 supply_ = IERC20(detf).totalSupply();
        bytes32 before_ = _adversarialState(address(wallet_), 3);
        _armContribution(true, address(wallet_), abi.encodeCall(PaidOwnerWallet.probe, ()));
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1 ether, 1 ether - 1));
        wallet_.buy(false);
        assertEq(token_.balanceOf(address(wallet_)), 1 ether);
        assertEq(token_.allowance(address(wallet_), detf), 0);
        assertEq(wallet_.probes(), 0);
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(abi.encode(receipt.stakingState()), initial_);
        assertEq(migration.migrationOwnerFirstBondTokenId(), 0);
        _assertAdversarialUnchanged(before_, address(wallet_), 3);
        vm.expectRevert(abi.encodeWithSignature("NotAuthorized(address)", address(wallet_)));
        wallet_.buy(true);
        _assertAdversarialUnchanged(before_, address(wallet_), 3);
        assertEq(migration.migrationOwnerFirstBondTokenId(), 0);
        token_.arm(false, detf, address(wallet_), abi.encodeCall(PaidOwnerWallet.probe, ()));
        uint256 id_ = wallet_.buy(false);
        assertTrue(token_.callbackSucceeded());
        assertEq(wallet_.probes(), 1);
        assertEq(token_.balanceOf(address(wallet_)), 0);
        assertEq(migration.migrationOwnerFirstBondTokenId(), id_);
        assertGt(bonds.positionOf(id_).principal, 0);
        assertFalse(bonds.isMigrationPosition(id_));
        assertFalse(migration.migrationActivated());
    }

    /// @notice I1-I3: catches booked, short, exact or reused prepaid inventory buying owner rights.
    /// @dev This entry deliberately rejects every public pretransfer; no alternate success branch exists.
    function test_I1_I2_I3_bookedAndUnbookedPretransferCannotPurchase() public {
        IERC20[] memory tokens_ = new IERC20[](1);
        tokens_[0] = IERC20(pairB);
        uint256[] memory amounts_ = new uint256[](1);
        amounts_[0] = 7 ether;
        migration.donateMigrationCapital(tokens_, amounts_, 0, 0, block.timestamp);
        _fundAndCapture();
        assertEq(migration.migrationDonationInventory(IERC20(pairB)), 7 ether, "actual booked inventory");
        PaidOwnerWallet wallet_ = new PaidOwnerWallet(migration, IERC20(pairB));
        vm.prank(migrationOwner);
        migration.initiateOwnershipTransfer(address(wallet_));
        wallet_.accept();
        for (uint256 i_; i_ < 4; ++i_) {
            if (i_ == 1) IERC20(pairB).transfer(detf, 0.5 ether);
            if (i_ == 2) IERC20(pairB).transfer(detf, 0.5 ether);
            bytes32 before_ = _adversarialState(address(wallet_), 3);
            vm.expectRevert(abi.encodeWithSignature("NotAuthorized(address)", address(wallet_)));
            wallet_.buy(true);
            _assertAdversarialUnchanged(before_, address(wallet_), 3);
        }
        assertEq(migration.migrationOwnerFirstBondTokenId(), 0);
        // A fresh authorized pull can buy exactly one bond without refunding any prior inventory.
        IERC20(pairB).transfer(address(wallet_), 1 ether);
        uint256 held_ = IERC20(pairB).balanceOf(detf);
        wallet_.buy(false);
        assertEq(IERC20(pairB).balanceOf(address(wallet_)), 0, "no refund of prior assets");
        // The V3 join can retain this call's native rounding residue. It may neither spend
        // below the old floor nor create more residual than the exact one-ether inbound.
        assertGe(IERC20(pairB).balanceOf(detf), held_, "booked and unbooked floors retained");
        assertLe(IERC20(pairB).balanceOf(detf) - held_, 1 ether, "residual capped to actual new payment");
        assertEq(migration.migrationDonationInventory(IERC20(pairB)), 7 ether);
    }
}
