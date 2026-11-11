// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {TestBase_UniswapV4DetfMigration} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation}
    from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationDFPkg as MigrationPackage}
    from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationDFPkg.sol";
import {IUniswapV4DetfMigrationStakedDETF as MigrationReceipt}
    from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/claimToken/IUniswapV4DetfMigrationStakedDETF.sol";
import {IUniswapV4DetfMigrationBondNFTVault as Bonds}
    from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/bondNft/IUniswapV4DetfMigrationBondNFTVault.sol";
import {IUniswapV4DetfMigrationSY as SY}
    from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/sy/IUniswapV4DetfMigrationSY.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";

contract MigrationRetainedAccountingTest is TestBase_UniswapV4DetfMigration {
    function _adopt(MigrationPackage.PkgArgs memory args_) private {
        detf = _deployMigration(args_);
        migration = Migration(detf);
        allocation = Allocation(detf);
        receipt = MigrationReceipt(migration.rebasingClaimToken());
        bonds = Bonds(migration.bondNftVault());
        stakingSy = SY(migration.stakingSY());
        IERC20(pairA).approve(detf, type(uint256).max);
        IERC20(pairB).approve(detf, type(uint256).max);
    }

    function _donate(uint256 amount_) private {
        IERC20[] memory tokens_ = new IERC20[](2);
        tokens_[0] = IERC20(pairA); tokens_[1] = IERC20(pairB);
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = amount_; amounts_[1] = amount_;
        migration.donateMigrationCapital(tokens_, amounts_, 0, 1, block.timestamp);
    }

    function test_standingWeightsRemainParticipantsAfterAllPrincipalExits() public {
        MigrationPackage.PkgArgs memory args_ = _migrationArgs(migrationOwner);
        args_.baseArgs.mintThreshold = 10e18;
        _adopt(args_);
        _fundAndCapture();
        uint256 principal_ = _configure(address(this), 1 ether, bytes32("standing"));
        uint256 id_ = _issue(address(this));
        vm.warp(block.timestamp + 90 days);
        bonds.claimPrincipal(id_, address(this));
        receipt.exchangeIn(IERC20(address(receipt)), principal_, IERC20(detf), principal_, address(this), false, block.timestamp);
        IStakedDETF.StakingState memory empty_ = receipt.stakingState();
        assertEq(empty_.totalGons, 0);
        assertGt(empty_.feeWeight + empty_.creatorWeight, 0);
        _donate(1000 ether);
        vm.warp(vm.getBlockTimestamp() + 8 hours);
        uint256 expected_ = migration.pendingExpansionDetf();
        assertGt(expected_, 0);
        assertEq(migration.synchronizeRewards(), expected_);
        assertGt(receipt.deferredRewardGons(1, address(feeCollector)), 0);
        assertEq(receipt.balanceOf(address(feeCollector)), 0);
    }

    function test_creatorTransferDoesNotRetargetEarlierAllocations() public {
        MigrationPackage.PkgArgs memory args_ = _migrationArgs(migrationOwner);
        args_.baseArgs.creator = address(this);
        _adopt(args_);
        _fundAndCapture();
        _configure(address(this), 1 ether, bytes32("roles"));
        _issue(address(this));
        _donate(100 ether);
        vm.warp(vm.getBlockTimestamp() + 8 hours);
        migration.synchronizeRewards();
        uint256 old_ = receipt.deferredRewardGons(1, address(this));
        assertGt(old_, 0);
        address next_ = address(0xBEEF);
        IERC721(address(bonds)).transferFrom(address(this), next_, 2);
        vm.warp(vm.getBlockTimestamp() + 8 hours);
        migration.synchronizeRewards();
        assertEq(receipt.deferredRewardGons(1, address(this)), old_);
        uint256 nextGons_ = receipt.deferredRewardGons(1, next_);
        assertGt(nextGons_, 0);
        vm.prank(migrationOwner);
        allocation.activateMigration();
        uint256 k_ = receipt.stakingState().gonsPerUnit;
        assertEq(receipt.claimDeferredRoleRewards(address(this)), old_ / k_);
        assertEq(receipt.claimDeferredRoleRewards(next_), nextGons_ / k_);
    }

    function test_subRewardTokenRemainderPaysNativeUnitsWhenIndexBelowQuantum() public {
        MigrationPackage.PkgArgs memory args_ = _migrationArgs(migrationOwner);
        args_.baseArgs.creationPairPerDetfWad[0] = 1;
        args_.baseArgs.creationPairPerDetfWad[1] = 1;
        _adopt(args_);
        _fundAndCapture();
        uint256 principal_ = _configure(address(this), 1e7, bytes32("quantum"));
        uint256 id_ = _issue(address(this));
        _donate(100 ether);
        // Exercise the admitted uint64 timestamp/index domain through actual funded expansion,
        // rather than injecting a small index or pretending sub-RT gons are always native dust.
        vm.warp(vm.getBlockTimestamp() + 365 days * 10_000_000_000);
        migration.synchronizeRewards();
        assertLt(receipt.stakingState().gonsPerUnit, 1e18);
        bonds.claimPrincipal(id_, address(this));
        receipt.approve(address(stakingSy), principal_);
        stakingSy.deposit(address(this), address(receipt), principal_, principal_);
        vm.prank(migrationOwner);
        allocation.activateMigration();
        migration.bond(IERC20(pairA), 1 ether, 90 days, address(this), false, block.timestamp);
        stakingSy.transfer(address(0xBEEF), principal_);
        uint256 k_ = receipt.stakingState().gonsPerUnit;
        uint256 beforeGons_ = receipt.deferredRewardGons(2, address(this));
        uint256 expected_ = (beforeGons_ % 1e18) / k_;
        assertGt(expected_, 0);
        uint256 paid_ = stakingSy.claimRewardRemainder();
        assertEq(paid_, expected_);
        assertEq(receipt.deferredRewardGons(2, address(this)), beforeGons_ - paid_ * k_);
        assertEq(stakingSy.claimRewardRemainder(), 0);
        assertEq(stakingSy.claimRewards(address(this))[0], beforeGons_ / 1e18);
    }
}
