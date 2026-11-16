// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MigrationLegacyClaimHandler} from "./MigrationLegacyClaimHandler.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {IUniswapV4DetfMigration as Migration} from "../interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from "../interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {IMigrationWeightedReceipt, IMigrationWeightedSynchronization} from "../legacy/IMigrationLegacyRecovery.sol";
import {IMigrationWeightedNft} from "../legacy/IMigrationLegacyNft.sol";
import {MigrationLegacyRecoveryLib as Legacy} from "../legacy/MigrationLegacyRecoveryLib.sol";

/// @notice Exact staged custody ledger. Source outputs are measured external receipts, not SUT inventory reads.
/// @dev External legacy settlement precedes output calculation; original Q/C never follows its index.
contract MigrationLegacyRecoveryHandler is MigrationLegacyClaimHandler {
    uint256 public recoveries;
    uint256 public batchRollbacks;
    uint256 public oldPrincipal;
    uint256 public oldRewards;

    constructor(Migration m_, OriginalNft[2] memory n_, uint256 c_) MigrationLegacyClaimHandler(m_, n_, c_) {}

    function redeemSy(uint256 seed_) public {
        if (syInventory == 0) { surrender(seed_); return; }
        uint256 q_ = seed_ % syInventory + 1;
        IMigrationWeightedSynchronization(Legacy.WEIGHTED_DETF).synchronizeRewards();
        uint256 divisor_ = IMigrationWeightedReceipt(Legacy.WEIGHTED_RECEIPT).stakingState().gonsPerUnit;
        uint256 expected_ = Math.mulDiv(q_, Math.mulDiv(1e36, 1e18, divisor_), 1e18);
        uint256 before_ = IMigrationWeightedReceipt(Legacy.WEIGHTED_RECEIPT).gonsOf(address(parent));
        _run(Recovery.Stage.WeightedSyRedeem, 0, q_);
        assertEq(IMigrationWeightedReceipt(Legacy.WEIGHTED_RECEIPT).gonsOf(address(parent)) - before_, expected_ * divisor_);
        syInventory -= q_;
        recoveryGons += expected_ * divisor_;
        ++recoveries; ++successes;
        assertAll();
    }

    function claimWeighted() public {
        if (!consumed[0]) { takeNft(0); return; }
        if (sourceBurned[0]) {
            address owner_ = parent.owner();
            Recovery.Step[] memory steps_ = _steps(Recovery.Stage.WeightedClaim, nft[0].id, 0);
            vm.prank(owner_);
            vm.expectRevert(abi.encodeWithSelector(Recovery.InvalidRecoveryCustody.selector, nft[0].collection, nft[0].id));
            recovery.recoverMigrationNfts(steps_, block.timestamp);
            ++rejections;
        } else {
            IMigrationWeightedSynchronization(Legacy.WEIGHTED_DETF).synchronizeRewards();
            IMigrationWeightedNft.Position memory p_ = IMigrationWeightedNft(nft[0].collection).positionOf(nft[0].id);
            uint256 divisor_ = IMigrationWeightedReceipt(Legacy.WEIGHTED_RECEIPT).stakingState().gonsPerUnit;
            uint256 elapsed_ = block.timestamp - p_.startTimestamp;
            uint256 vested_ = elapsed_ >= p_.vestingDuration ? p_.principal : p_.principal * elapsed_ / p_.vestingDuration;
            uint256 principal_ = vested_ - p_.claimedPrincipal;
            uint256 rewards_ = p_.stakingGons / divisor_ - (p_.principal - p_.claimedPrincipal);
            _run(Recovery.Stage.WeightedClaim, nft[0].id, 0);
            sourceBurned[0] = vested_ == p_.principal
                && p_.stakingGons - (principal_ + rewards_) * divisor_ < divisor_;
            recoveryGons += (principal_ + rewards_) * divisor_;
            oldPrincipal += principal_; oldRewards += rewards_;
            assertEq(recovery.migrationNftRecovery(nft[0].collection, nft[0].id).principalClaimed, oldPrincipal);
            assertEq(recovery.migrationNftRecovery(nft[0].collection, nft[0].id).rewardsClaimed, oldRewards);
            ++recoveries;
            if (principal_ + rewards_ != 0) ++successes;
        }
        assertAll();
    }

    function unstake(uint256 seed_) public {
        IMigrationWeightedSynchronization(Legacy.WEIGHTED_DETF).synchronizeRewards();
        uint256 divisor_ = IMigrationWeightedReceipt(Legacy.WEIGHTED_RECEIPT).stakingState().gonsPerUnit;
        uint256 available_ = recoveryGons / divisor_;
        if (available_ == 0) { redeemSy(seed_); return; }
        uint256 amount_ = seed_ % available_ + 1;
        uint256 debit_ = amount_ == available_ ? recoveryGons : amount_ * divisor_;
        _run(Recovery.Stage.WeightedUnstake, 0, amount_);
        recoveryGons -= debit_; liquidInventory += amount_;
        ++recoveries; ++successes;
        assertAll();
    }

    function convert(uint256 seed_) public {
        if (liquidInventory == 0) { unstake(seed_); return; }
        uint256 amount_ = seed_ % liquidInventory + 1;
        uint256 before_ = IERC20(Legacy.DTF).balanceOf(address(parent));
        _run(Recovery.Stage.WeightedConvert, 0, amount_);
        uint256 received_ = IERC20(Legacy.DTF).balanceOf(address(parent)) - before_;
        assertGt(received_, 0, "actual source conversion output");
        dtfInventory += received_; liquidInventory -= amount_;
        assertEq(IERC20(Legacy.WEIGHTED_DETF).allowance(address(parent), Legacy.WEIGHTED_DETF), 0);
        ++recoveries; ++successes;
        assertAll();
    }

    function donate(uint256 seed_) public {
        if (dtfInventory == 0) { convert(seed_); return; }
        uint256 amount_ = seed_ % dtfInventory + 1;
        // Keep the real SE donation above its one-native-share rounding boundary.
        if (amount_ < 1e10) amount_ = dtfInventory;
        uint256 before_ = IERC20(Legacy.DTF).balanceOf(address(parent));
        uint256 lp_ = IERC20(parent.hook()).balanceOf(address(bonds));
        _run(Recovery.Stage.Donate, 0, amount_);
        uint256 spent_ = before_ - IERC20(Legacy.DTF).balanceOf(address(parent));
        assertLe(spent_, amount_ + retainedDonation, "selected recovery plus existing protocol residual only");
        retainedDonation = retainedDonation + amount_ - spent_;
        dtfInventory -= amount_; donatedDtf += amount_;
        assertGt(IERC20(parent.hook()).balanceOf(address(bonds)), lp_, "fixed donation beneficiary");
        assertEq(IERC20(Legacy.DTF).allowance(address(parent), parent.hook()), 0);
        ++recoveries; ++successes;
        assertAll();
    }

    /// @notice A valid first custody conversion followed by an invalid second item must fully roll back.
    function failedRecoveryBatch() public {
        if (syInventory == 0) { surrender(31); return; }
        Recovery.Step[] memory steps_ = new Recovery.Step[](2);
        steps_[0] = Recovery.Step(Recovery.Stage.WeightedSyRedeem, 0, syInventory, 0);
        steps_[1] = Recovery.Step(Recovery.Stage.WeightedConvert, 0, type(uint256).max, 0);
        bytes32 before_ = recoveryState();
        address owner_ = parent.owner();
        vm.prank(owner_);
        vm.expectRevert(abi.encodeWithSelector(Recovery.RecoveryInventoryInsufficient.selector,
            Legacy.WEIGHTED_DETF, type(uint256).max, liquidInventory));
        recovery.recoverMigrationNfts(steps_, block.timestamp);
        assertEq(recoveryState(), before_);
        ++batchRollbacks; ++rejections;
        assertAll();
    }

    function changeOwner() public {
        address previous_ = parent.owner();
        address next_ = previous_ == OTHER ? address(0x2477) : OTHER;
        vm.prank(previous_); parent.initiateOwnershipTransfer(next_);
        vm.prank(next_); parent.acceptOwnershipTransfer();
        bytes32 before_ = recoveryState();
        Recovery.Step[] memory steps_ = _steps(Recovery.Stage.WeightedSyRedeem, 0, 1);
        vm.prank(previous_);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, previous_));
        recovery.recoverMigrationNfts(steps_, block.timestamp);
        assertEq(recoveryState(), before_);
        ++rejections; ++successes;
        assertAll();
    }

    function _steps(Recovery.Stage stage_, uint256 id_, uint256 q_) private pure returns (Recovery.Step[] memory s_) {
        s_ = new Recovery.Step[](1);
        s_[0] = Recovery.Step(stage_, id_, q_, 0);
    }

    function _run(Recovery.Stage stage_, uint256 id_, uint256 q_) private {
        bytes32 beneficiaries_ = beneficiaryBalances();
        address owner_ = parent.owner();
        Recovery.Step[] memory steps_ = _steps(stage_, id_, q_);
        vm.prank(owner_);
        recovery.recoverMigrationNfts(steps_, block.timestamp);
        assertEq(beneficiaryBalances(), beneficiaries_, "no alternative recovery recipient");
    }

    function beneficiaryBalances() public view returns (bytes32) {
        address[4] memory wallets_ = [parent.owner(), nft[0].wallet, nft[1].wallet, address(this)];
        bytes memory balances_;
        for (uint256 i_; i_ < wallets_.length; ++i_) {
            balances_ = abi.encode(balances_, IERC20(Legacy.DTF).balanceOf(wallets_[i_]),
                IERC20(Legacy.WEIGHTED_DETF).balanceOf(wallets_[i_]),
                IMigrationWeightedReceipt(Legacy.WEIGHTED_RECEIPT).gonsOf(wallets_[i_]),
                IERC20(Legacy.WEIGHTED_SY).balanceOf(wallets_[i_]));
        }
        return keccak256(balances_);
    }

    function recoveryState() public view returns (bytes32) {
        return keccak256(abi.encode(economicState(), recovery.migrationRecoveryGons(),
            IMigrationWeightedReceipt(Legacy.WEIGHTED_RECEIPT).gonsOf(address(parent)),
            IMigrationWeightedReceipt(Legacy.WEIGHTED_RECEIPT).gonsOf(Legacy.WEIGHTED_SY),
            IERC20(Legacy.WEIGHTED_DETF).balanceOf(address(parent)),
            IERC20(Legacy.DTF).balanceOf(address(parent)), beneficiaryBalances()));
    }
}
