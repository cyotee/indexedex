// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {Vm} from "forge-std/Vm.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
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
import {IMigrationWeightedNft, IMigrationEarlierNft} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyNft.sol";
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
    uint256 internal initialDonationFloor;

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
    function _fundHistoricalBook() internal virtual override {
        IERC20[] memory tokens_ = new IERC20[](1);
        tokens_[0] = IERC20(Legacy.DTF);
        uint256[] memory amounts_ = new uint256[](1);
        amounts_[0] = 1 ether;
        migration.donateMigrationCapital(tokens_, amounts_, 0, 0, block.timestamp);
        (, uint256 genesisRefund_) =
            IStandardExchangeIn(se1).previewExchangeIn(IERC20(Legacy.DTF), 100 ether, IERC20(se1));
        initialDonationFloor = 1 ether + genesisRefund_;
        _fundAndCapture();
        assertEq(migration.migrationDonationInventory(IERC20(Legacy.DTF)), initialDonationFloor);
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

/// @notice Positive legacy recovery custody coexists with the explicit genesis-remainder sweep.
contract MigrationRecoveryDonationRemainderTest is MigrationRecoveryDonationForkBase {
    function _fundHistoricalBook() internal override {
        IERC20[] memory tokens_ = new IERC20[](2);
        tokens_[0] = IERC20(pairA); tokens_[1] = IERC20(pairB);
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 100 ether; amounts_[1] = 100 ether;
        migration.donateMigrationCapital(tokens_, amounts_, 0, 0, block.timestamp);
        Migration.GenesisLeg[] memory legs_ = new Migration.GenesisLeg[](2);
        legs_[0] = Migration.GenesisLeg(IERC20(pairA), 50 ether, 1);
        legs_[1] = Migration.GenesisLeg(IERC20(pairB), 50 ether, 1);
        vm.prank(migrationOwner);
        allocation.bootstrapMigrationReserve(legs_, 0, 1, block.timestamp);
        _setObservedPricing();
    }

    /// @notice Only genesis books are released; recovered DTF and unsolicited DTF remain in custody.
    function test_partialBootstrapSweepPreservesRealRecoveryInventory() public {
        (uint256 bond_, uint256 recovered_) = _converted();
        assertGt(recovered_, 0);
        assertTrue(migration.migrationActivated());
        assertGt(migration.migrationDonationInventory(IERC20(pairA)), 0);
        assertGt(migration.migrationDonationInventory(IERC20(Legacy.DTF)), 0);
        IERC20(Legacy.DTF).transfer(detf, 7 ether);
        address[6] memory tokens_ = [pairA, pairB, se0, se1, detf, reserveHook];
        uint256[6] memory held_;
        uint256[6] memory booked_;
        uint256[6] memory payer_;
        uint256[6] memory recovery_;
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            held_[i_] = IERC20(tokens_[i_]).balanceOf(detf);
            booked_[i_] = migration.migrationDonationInventory(IERC20(tokens_[i_]));
            payer_[i_] = IERC20(tokens_[i_]).balanceOf(address(this));
            recovery_[i_] = recovery.migrationRecoveryInventory(tokens_[i_]);
        }
        bytes32 backing_ = keccak256(abi.encode(
            bonds.positionOf(bond_), IERC721(address(bonds)).ownerOf(bond_),
            IERC721(address(bonds)).ownerOf(bond_ + 1), IERC20(detf).totalSupply(),
            receipt.stakingState(), receipt.gonsOf(address(bonds)), bonds.attributedBondGons(),
            IERC20(detf).balanceOf(address(receipt)), migration.migrationOwnerFirstBondTokenId()
        ));
        uint256 lpBefore_ = IERC20(reserveHook).balanceOf(address(bonds));
        vm.recordLogs();
        address authority_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        vm.prank(authority_);
        migration.sweepDust();
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        assertGt(IERC20(reserveHook).balanceOf(address(bonds)), lpBefore_);
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            uint256 released_;
            uint256 incoming_;
            uint256 outgoing_;
            for (uint256 j_; j_ < logs_.length; ++j_) {
                Vm.Log memory log_ = logs_[j_];
                if (log_.emitter == detf && log_.topics.length == 2
                    && log_.topics[0] == keccak256("MigrationCapitalReleasedToResidual(address,uint256)")
                    && log_.topics[1] == bytes32(uint256(uint160(tokens_[i_])))) {
                    released_ += abi.decode(log_.data, (uint256));
                }
                if (log_.emitter == tokens_[i_] && log_.topics.length == 3
                    && log_.topics[0] == keccak256("Transfer(address,address,uint256)")) {
                    if (log_.topics[1] == bytes32(uint256(uint160(detf)))) outgoing_ += abi.decode(log_.data, (uint256));
                    if (log_.topics[2] == bytes32(uint256(uint160(detf)))) incoming_ += abi.decode(log_.data, (uint256));
                }
            }
            assertEq(released_, tokens_[i_] == detf ? 0 : booked_[i_]);
            assertEq(migration.migrationDonationInventory(IERC20(tokens_[i_])), booked_[i_] - released_);
            assertEq(IERC20(tokens_[i_]).balanceOf(detf), held_[i_] + incoming_ - outgoing_);
            assertEq(recovery.migrationRecoveryInventory(tokens_[i_]), recovery_[i_]);
            assertEq(IERC20(tokens_[i_]).balanceOf(address(this)), payer_[i_], "no caller payout");
            assertEq(IERC20(tokens_[i_]).allowance(detf, reserveHook), 0);
            assertEq(IERC20(tokens_[i_]).allowance(detf, se0), 0);
            assertEq(IERC20(tokens_[i_]).allowance(detf, se1), 0);
        }
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), recovered_);
        assertGe(IERC20(Legacy.DTF).balanceOf(detf), recovered_ + 7 ether);
        assertEq(keccak256(abi.encode(
            bonds.positionOf(bond_), IERC721(address(bonds)).ownerOf(bond_),
            IERC721(address(bonds)).ownerOf(bond_ + 1), IERC20(detf).totalSupply(),
            receipt.stakingState(), receipt.gonsOf(address(bonds)), bonds.attributedBondGons(),
            IERC20(detf).balanceOf(address(receipt)), migration.migrationOwnerFirstBondTokenId()
        )), backing_);
        // A genuine subsequent receipt exercises a fresh budget with the same recovery floor.
        IERC20[] memory laterTokens_ = new IERC20[](1);
        laterTokens_[0] = IERC20(Legacy.DTF);
        uint256[] memory laterAmounts_ = new uint256[](1);
        laterAmounts_[0] = 1 ether;
        assertGt(migration.donateMigrationCapital(laterTokens_, laterAmounts_, 0, 1, block.timestamp), 0);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), recovered_);
        assertGe(IERC20(Legacy.DTF).balanceOf(detf), recovered_ + 7 ether);
        assertEq(IERC20(Legacy.DTF).allowance(detf, reserveHook), 0);
        assertEq(IERC20(Legacy.DTF).allowance(detf, se1), 0);
    }
}

contract MigrationRecoveryDonationTest is MigrationRecoveryDonationForkBase {
    function test_iterativeEarlierRewardsReachDtfWithoutSellingUnlockedNft() public {
        _configureNft(WEIGHTED, 4);
        uint256 bond_ = _take(EARLIER, 3);
        _take(WEIGHTED, 4);
        IMigrationEarlierNft.Position memory original_ = IMigrationEarlierNft(EARLIER).getPosition(3);
        IMigrationWeightedNft.Position memory weighted_ = IMigrationWeightedNft(WEIGHTED).positionOf(4);
        address registry_ = 0x09682b00D873D913ada0bB69B4D4c9631810d0bc;
        IVaultRegistryDisableQuery query_ = IVaultRegistryDisableQuery(registry_);
        (, bool byVault_, bool byPackage_) = query_.isDisabledDetailed(Legacy.EARLIER_SE);
        vm.startPrank(IMultiStepOwnable(registry_).owner());
        if (byVault_) IVaultRegistryDisableManager(registry_).setVaultAddressDisabled(Legacy.EARLIER_SE, false);
        if (byPackage_) {
            IVaultRegistryDisableManager(registry_).setPackageDisabled(query_.packageOfVault(Legacy.EARLIER_SE), false);
        }
        vm.stopPrank();
        if (block.timestamp <= original_.unlockTime) vm.warp(original_.unlockTime + 1);
        uint256 previousRewards_;
        for (uint256 cycle_; cycle_ < 3; ++cycle_) {
            if (cycle_ != 0) vm.warp(vm.getBlockTimestamp() + 8 hours);
            bytes32 protected_ = _protected(bond_);
            // Actual external income, not an assertion that time alone creates rewards.
            address donor_ = address(bytes20(hex"495d9d8bc7b1d00cfb3dfe8aa3666c64771910ed"));
            uint256 income_ = IERC20(Legacy.EARLIER_DETF).balanceOf(donor_) / 4;
            assertGt(income_, 0);
            vm.prank(donor_);
            IERC20(Legacy.EARLIER_DETF).transfer(EARLIER, income_);
            _run(Recovery.Stage.EarlierClaim, 3, 0, 0);
            Recovery.NftRecovery memory harvested_ = recovery.migrationNftRecovery(EARLIER, 3);
            assertGt(harvested_.rewardsClaimed, previousRewards_);
            previousRewards_ = harvested_.rewardsClaimed;
            assertFalse(harvested_.sold);
            uint256 rewards_ = recovery.migrationRecoveryInventory(Legacy.EARLIER_DETF);
            uint256 dtfBefore_ = recovery.migrationRecoveryInventory(Legacy.DTF);
            _run(Recovery.Stage.EarlierConvert, 0, rewards_, 1);
            uint256 received_ = recovery.migrationRecoveryInventory(Legacy.DTF) - dtfBefore_;
            assertGt(received_, 0);
            // Combine genuine reward recovery from another retained bond so the
            // reserve join need not confiscate an earlier source's sub-LP-unit dust.
            _run(Recovery.Stage.WeightedRewards, 4, 0, 0);
            _run(Recovery.Stage.WeightedUnstake, 0, _weightedAmount(), 0);
            _run(Recovery.Stage.WeightedConvert, 0, recovery.migrationRecoveryInventory(Legacy.WEIGHTED_DETF), 1);
            uint256 combined_ = recovery.migrationRecoveryInventory(Legacy.DTF);
            uint256 donation_ = combined_ > 1 ether ? 1 ether : combined_;
            _run(Recovery.Stage.Donate, 0, donation_, 1);
            assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), combined_ - donation_);
            assertEq(IMigrationEarlierNft(EARLIER).getPosition(3).originalShares, original_.originalShares);
            assertEq(IERC721(EARLIER).ownerOf(3), detf);
            assertEq(IMigrationWeightedNft(WEIGHTED).positionOf(4).principal, weighted_.principal);
            assertEq(IMigrationWeightedNft(WEIGHTED).positionOf(4).claimedPrincipal, weighted_.claimedPrincipal);
            assertEq(IERC721(WEIGHTED).ownerOf(4), detf);
            assertEq(_protected(bond_), protected_);
        }
    }

    function test_iterativeRewardHarvestDonatesDtfWithoutTakingUnlockedPrincipal() public {
        uint256 bond_ = _take(WEIGHTED, 4);
        IMigrationWeightedNft.Position memory original_ = IMigrationWeightedNft(WEIGHTED).positionOf(4);
        assertGt(original_.principal, original_.claimedPrincipal);
        uint256 unlock_ = original_.startTimestamp + original_.vestingDuration + 1;
        if (block.timestamp < unlock_) vm.warp(unlock_);
        uint256 previousRewards_;
        for (uint256 cycle_; cycle_ < 3; ++cycle_) {
            if (cycle_ != 0) vm.warp(vm.getBlockTimestamp() + 8 hours);
            bytes32 protected_ = _protected(bond_);
            _run(Recovery.Stage.WeightedRewards, 4, 0, 0);
            Recovery.NftRecovery memory harvested_ = recovery.migrationNftRecovery(WEIGHTED, 4);
            assertEq(harvested_.principalClaimed, 0);
            assertGt(harvested_.rewardsClaimed, previousRewards_);
            previousRewards_ = harvested_.rewardsClaimed;
            uint256 rewards_ = _weightedAmount();
            assertGt(rewards_, 0);
            _run(Recovery.Stage.WeightedUnstake, 0, rewards_, 0);
            uint256 dtfBefore_ = recovery.migrationRecoveryInventory(Legacy.DTF);
            _run(Recovery.Stage.WeightedConvert, 0, recovery.migrationRecoveryInventory(Legacy.WEIGHTED_DETF), 1);
            uint256 received_ = recovery.migrationRecoveryInventory(Legacy.DTF) - dtfBefore_;
            assertGt(received_, 0);
            uint256 donation_ = received_ > 1 ether ? 1 ether : received_;
            _run(Recovery.Stage.Donate, 0, donation_, 1);
            assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), dtfBefore_ + received_ - donation_);
            IMigrationWeightedNft.Position memory remaining_ = IMigrationWeightedNft(WEIGHTED).positionOf(4);
            assertEq(remaining_.principal, original_.principal);
            assertEq(remaining_.claimedPrincipal, original_.claimedPrincipal);
            assertGt(remaining_.stakingGons, 0);
            assertEq(IERC721(WEIGHTED).ownerOf(4), detf);
            assertEq(_protected(bond_), protected_);
        }
    }

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
        assertTrue(migration.migrationActivated());
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
        for (uint256 i_; i_ < 4; ++i_) {
            assertEq(hostileRate.errors(i_), i_ == 1
                ? bytes4(keccak256("NoTargetFor(bytes4)")) : bytes4(keccak256("IsLocked()")));
        }
        assertTrue(migration.migrationActivated());
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
