// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {TestBase_UniswapV4DetfMigration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {IMigrationWeightedClaims, IMigrationWeightedReceipt, IMigrationLegacyExchange} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyRecovery.sol";
import {MigrationLegacyRecoveryLib as Legacy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol";
import {MigrationRecoveryForkBase} from "./MigrationRecoveryForkBase.sol";

/// @notice An external rate currency, not a replacement legacy or new-product contract.
contract RecoveryHostileRate is SimpleMintableERC20 {
    address public parent;
    bytes[] private payloads;
    uint256 public attempts;
    bytes4[] public errors;
    bool private entered;
    constructor() SimpleMintableERC20("External hostile rate", "RATE") {}
    function accept(address parent_) external { IMultiStepOwnable(parent_).acceptOwnershipTransfer(); }
    function execute(address parent_, Recovery.Step[] calldata steps_, uint256 deadline_) external {
        Recovery(parent_).recoverMigrationNfts(steps_, deadline_);
    }
    function arm(address parent_, bytes[] calldata calls_) external {
        parent = parent_;
        payloads = calls_;
    }
    function transfer(address to_, uint256 amount_) external override returns (bool) {
        _transfer(msg.sender, to_, amount_);
        if (parent != address(0) && !entered) {
            entered = true;
            for (uint256 i_; i_ < payloads.length; ++i_) {
                (bool ok_, bytes memory reason_) = parent.call(payloads[i_]);
                require(!ok_, "reentry succeeded");
                errors.push(bytes4(reason_));
                ++attempts;
            }
        }
        return true;
    }
}

/// @notice Real DTF is acquired from a real holder's own legacy claim/conversion for fixture funding.
/// The selected recovery witness is a different NFT, surrendered to the genuine Migration proxy.
abstract contract MigrationRecoveryDonationForkBase is MigrationRecoveryForkBase {
    RecoveryHostileRate internal hostileRate;

    function _deployContributionFixture() internal pure override returns (address) { return Legacy.DTF; }
    function _fundContribution(address recipient_, uint256 amount_) internal override {
        address donor_ = IERC721(WEIGHTED).ownerOf(3);
        vm.startPrank(donor_);
        (uint256 principal_, uint256 rewards_) = IMigrationWeightedClaims(WEIGHTED).claimBond(3, donor_);
        uint256 amountIn_ = principal_ + rewards_;
        IMigrationWeightedReceipt(Legacy.WEIGHTED_RECEIPT).exchangeIn(
            Legacy.WEIGHTED_RECEIPT, amountIn_, Legacy.WEIGHTED_DETF, amountIn_, donor_, false, block.timestamp
        );
        IERC20(Legacy.WEIGHTED_DETF).approve(Legacy.WEIGHTED_DETF, amountIn_);
        IMigrationLegacyExchange(Legacy.WEIGHTED_DETF).exchangeIn(
            Legacy.WEIGHTED_DETF, amountIn_, Legacy.DTF, amount_, donor_, false, block.timestamp
        );
        IERC20(Legacy.WEIGHTED_DETF).approve(Legacy.WEIGHTED_DETF, 0);
        IERC20(Legacy.DTF).transfer(recipient_, amount_);
        vm.stopPrank();
    }
    function _seedMigrationPool(IUniswapV3Pool pool_, bytes32 salt_) internal override {
        TestBase_UniswapV4DetfMigration._seedMigrationPool(pool_, salt_);
    }
    function _fundHistoricalBook() internal override {
        IERC20[] memory tokens_ = new IERC20[](1);
        tokens_[0] = IERC20(Legacy.DTF);
        uint256[] memory amounts_ = new uint256[](1);
        amounts_[0] = 1 ether;
        migration.donateMigrationCapital(tokens_, amounts_, 0, 0, block.timestamp);
        _fundAndCapture();
        assertEq(migration.migrationDonationInventory(IERC20(Legacy.DTF)), 1 ether);
    }
    function _deployRateFixture() internal override returns (address) {
        hostileRate = RecoveryHostileRate(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "MigrationRecoveryDonation.t.sol:RecoveryHostileRate"),
            "", keccak256("recovery.external.rate")
        ));
        return address(hostileRate);
    }

    function _converted() internal returns (uint256 bond_, uint256 out_) {
        bond_ = _take(WEIGHTED, 4);
        _run(Recovery.Stage.WeightedClaim, 4, 0, 0);
        _run(Recovery.Stage.WeightedUnstake, 0, _weightedAmount(), 0);
        _run(Recovery.Stage.WeightedConvert, 0, recovery.migrationRecoveryInventory(Legacy.WEIGHTED_DETF), 1);
        out_ = recovery.migrationRecoveryInventory(Legacy.DTF);
        assertGt(out_, 1 ether);
    }
}

contract MigrationRecoveryDonationTest is MigrationRecoveryDonationForkBase {
    function test_actualRecoveredDtfDonationProtectsUnrelatedInventoryAndBacking() public {
        (uint256 bond_, uint256 out_) = _converted();
        IERC20(Legacy.DTF).transfer(detf, 7 ether);
        bytes32 protected_ = _protected(bond_);
        uint256 before_ = IERC20(Legacy.DTF).balanceOf(detf);
        uint256 lpBefore_ = IERC20(reserveHook).balanceOf(address(bonds));
        uint256 start_ = gasleft();
        _run(Recovery.Stage.Donate, 0, 1 ether, 1);
        emit RecoveryGas("W4", 1, 1, start_ - gasleft());
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), out_ - 1 ether);
        assertGe(IERC20(Legacy.DTF).balanceOf(detf), before_ - 1 ether);
        assertGe(IERC20(Legacy.DTF).balanceOf(detf), 7 ether + out_ - 1 ether);
        assertGt(IERC20(reserveHook).balanceOf(address(bonds)), lpBefore_);
        assertEq(IERC20(Legacy.DTF).allowance(detf, reserveHook), 0);
        assertEq(IERC20(Legacy.DTF).allowance(detf, se1), 0);
        assertEq(_protected(bond_), protected_);
        vm.prank(migrationOwner);
        allocation.activateMigration();
        _run(Recovery.Stage.Donate, 0, 1 ether, 1);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), out_ - 2 ether);
        assertEq(_protected(bond_), protected_);
    }

    function test_failedDonationLeavesCompletedConversionsAndSmallerRetry() public {
        (uint256 bond_, uint256 out_) = _converted();
        bytes32 protected_ = _protected(bond_);
        uint256 heldBefore_ = IERC20(Legacy.DTF).balanceOf(detf);
        uint256 lpBefore_ = IERC20(reserveHook).balanceOf(address(bonds));
        Recovery.Step[] memory steps_ = _step(Recovery.Stage.Donate, 0, 1 ether, type(uint256).max);
        vm.prank(migrationOwner);
        (bool ok_,) = detf.call(abi.encodeCall(Recovery.recoverMigrationNfts, (steps_, block.timestamp)));
        assertFalse(ok_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), out_);
        assertEq(IERC20(Legacy.DTF).balanceOf(detf), heldBefore_);
        assertEq(IERC20(reserveHook).balanceOf(address(bonds)), lpBefore_);
        assertEq(IERC20(Legacy.DTF).allowance(detf, reserveHook), 0);
        assertEq(_protected(bond_), protected_);
        _run(Recovery.Stage.Donate, 0, 1 ether, 1);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), out_ - 1 ether);
    }

    function test_registryDisableBlocksDonationButNotSelectedClaimHolding() public {
        _take(WEIGHTED, 4);
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(detf, true);
        _run(Recovery.Stage.WeightedClaim, 4, 0, 0);
        _run(Recovery.Stage.WeightedUnstake, 0, _weightedAmount(), 0);
        _run(Recovery.Stage.WeightedConvert, 0, recovery.migrationRecoveryInventory(Legacy.WEIGHTED_DETF), 1);
        uint256 out_ = recovery.migrationRecoveryInventory(Legacy.DTF);
        vm.expectRevert(abi.encodeWithSignature("VaultDisabled(address)", detf));
        _run(Recovery.Stage.Donate, 0, 1 ether, 1);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), out_);
    }

    function test_donationExternalCallbackCannotEnterAnyParentMoneyStage() public {
        (uint256 bond_,) = _converted();
        bytes32 protected_ = _protected(bond_);
        vm.prank(migrationOwner);
        IMultiStepOwnable(detf).initiateOwnershipTransfer(address(hostileRate));
        hostileRate.accept(detf);
        Recovery.Step[] memory steps_ = _step(Recovery.Stage.Donate, 0, 1 ether, 1);
        bytes[] memory calls_ = new bytes[](4);
        calls_[0] = abi.encodeCall(Recovery.recoverMigrationNfts, (steps_, block.timestamp));
        calls_[1] = abi.encodeCall(Allocation.activateMigration, ());
        calls_[2] = abi.encodeCall(Migration.surrenderMigrationNft, (WEIGHTED, 4, 0, block.timestamp));
        calls_[3] = abi.encodeCall(Migration.donateMigrationCapital,
            (new IERC20[](0), new uint256[](0), 0, 0, block.timestamp));
        hostileRate.arm(detf, calls_);
        hostileRate.execute(detf, steps_, block.timestamp);
        assertEq(hostileRate.attempts(), 4);
        for (uint256 i_; i_ < 4; ++i_) assertEq(hostileRate.errors(i_), bytes4(keccak256("IsLocked()")));
        assertFalse(migration.migrationActivated());
        assertEq(_protected(bond_), protected_);
    }

    function test_finalDonationFailureRollsBackEntireSelectedRecoveryTransaction() public {
        uint256 bond_ = _take(WEIGHTED, 4);
        bytes32 protected_ = _protected(bond_);
        uint256 snapshot_ = vm.snapshotState();
        _run(Recovery.Stage.WeightedClaim, 4, 0, 0);
        uint256 amount_ = _weightedAmount();
        assertTrue(vm.revertToStateAndDelete(snapshot_));
        Recovery.Step[] memory steps_ = new Recovery.Step[](4);
        steps_[0] = Recovery.Step(Recovery.Stage.WeightedClaim, 4, 0, 0);
        steps_[1] = Recovery.Step(Recovery.Stage.WeightedUnstake, 0, amount_, 0);
        steps_[2] = Recovery.Step(Recovery.Stage.WeightedConvert, 0, amount_, 1);
        steps_[3] = Recovery.Step(Recovery.Stage.Donate, 0, 1 ether, type(uint256).max);
        vm.prank(migrationOwner);
        (bool ok_, bytes memory reason_) = detf.call(abi.encodeCall(Recovery.recoverMigrationNfts, (steps_, block.timestamp)));
        assertFalse(ok_);
        assertEq(bytes4(reason_), bytes4(keccak256("MinAmountNotMet(uint256,uint256)")));
        assertEq(recovery.migrationNftRecovery(WEIGHTED, 4).principalClaimed, 0);
        assertEq(_weightedAmount(), 0);
        assertEq(recovery.migrationRecoveryGons(), 0);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_DETF), 0);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), 0);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).allowance(detf, Legacy.WEIGHTED_DETF), 0);
        assertEq(_protected(bond_), protected_);
        steps_[3].minimum = 1;
        vm.prank(migrationOwner);
        recovery.recoverMigrationNfts(steps_, block.timestamp);
        assertGt(recovery.migrationRecoveryInventory(Legacy.DTF), 0);
        assertEq(_protected(bond_), protected_);
    }

    function test_recoveryProtectsActualStakingSyPacketsAndSelfLegInventory() public {
        uint256 credit_ = _configure(address(this), 1e15, bytes32("recovery.packet.fixture"));
        uint256 packetBond_ = _issue(address(this));
        vm.warp(vm.getBlockTimestamp() + 90 days);
        assertEq(bonds.claimPrincipal(packetBond_, address(this)), credit_);
        receipt.approve(address(stakingSy), credit_ / 2);
        stakingSy.deposit(address(this), address(receipt), credit_ / 2, credit_ / 2);
        receipt.exchangeIn(IERC20(address(receipt)), credit_ - credit_ / 2, IERC20(detf), 1,
            address(this), false, block.timestamp);
        IERC20(detf).approve(address(rawSy), credit_ / 4);
        rawSy.deposit(address(this), detf, credit_ / 4, credit_ / 4);
        IERC20(detf).transfer(detf, 1);
        uint256 syBalance_ = stakingSy.balanceOf(address(this));
        uint256 rawBalance_ = rawSy.balanceOf(address(this));
        uint256 backing_ = receipt.gonsOf(address(stakingSy));
        assertGt(backing_, 0);
        (uint256 bond_,) = _converted();
        bytes32 protected_ = _protected(bond_);
        _run(Recovery.Stage.Donate, 0, 1 ether, 1);
        assertEq(_protected(bond_), protected_);
        assertEq(receipt.gonsOf(address(stakingSy)), backing_);
        assertEq(stakingSy.balanceOf(address(this)), syBalance_);
        assertEq(rawSy.balanceOf(address(this)), rawBalance_);
        assertGe(IERC20(detf).balanceOf(detf), 1);
    }
}
