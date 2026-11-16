// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TokenStaking_PonsUv4Detf} from "./TokenStaking_PonsUv4Detf.t.sol";
import {Phase_08_Stage_07_StakingPrincipalMigration as Migration} from "scripts/foundry/anvil_robinhood_main/Phase_08_Stage_07_StakingPrincipalMigration.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDetfClaimPurchase} from "contracts/interfaces/IDetfClaimPurchase.sol";
import {ITokenStaking} from "contracts/interfaces/ITokenStaking.sol";

/// @notice Production staking/DETF tests of the operator's bounded conversion library.
/// @dev The inherited CP Pons fixture tests migration orchestration, not the three-leg composition.
contract TokenStakingMigrationScript is TokenStaking_PonsUv4Detf {
    function _prepareMigration() internal {
        _firstBond(80 ether);
        vm.prank(detfUser);
        staking.stake(20 ether);
        vm.prank(stakerB);
        staking.stake(20 ether);
        IERC20(launchToken).transfer(owner, 10 ether);
        vm.startPrank(owner);
        IERC20(launchToken).approve(address(staking), 10 ether);
        staking.notifyRewardAmount(10 ether);
        staking.setTargetDetf(IDetfClaimPurchase(detf));
        vm.stopPrank();
    }

    function test_runner_migratesPrincipalAndRewardsTogether() public {
        _prepareMigration();
        assertEq(staking.reserveRemaining(), 50 ether);
        uint256 ownerBefore = IERC20(launchToken).balanceOf(owner);
        vm.startPrank(owner);
        Migration.Result memory first = Migration.execute(staking, detf, 15 ether, 35 ether, 1, block.timestamp + 1 hours);
        assertEq(uint256(first.afterState.phase), uint256(ITokenStaking.Phase.Migrating));
        assertEq(first.afterState.principal, 40 ether);
        Migration.Result memory last = Migration.execute(staking, detf, 35 ether, 35 ether, 1, block.timestamp + 1 hours);
        Migration.Snapshot memory completed = Migration.verifyComplete(staking, detf);
        vm.stopPrank();
        assertEq(first.amountIn + last.amountIn, 50 ether, "rewards included");
        assertEq(completed.remaining, 0);
        assertEq(completed.principal, 40 ether, "original allocation weights");
        assertEq(IERC20(launchToken).balanceOf(owner), ownerBefore, "no rescued reward funds");
        assertEq(first.afterState.claimVault, last.afterState.claimVault);
        uint256 preview = staking.previewClaim(detfUser, 20 ether);
        vm.prank(detfUser);
        assertEq(staking.withdrawClaim(20 ether), preview);
        vm.prank(stakerB);
        assertGt(staking.withdrawClaim(20 ether), 0);
        assertEq(staking.totalSupply(), 0);
        assertEq(IERC20(completed.claimVault).balanceOf(address(staking)), 0);
    }

    function test_runner_fullCallQuoteRollsBackBeforeExecution() public {
        _prepareMigration();
        uint256 snap = vm.snapshotState();
        vm.startPrank(owner);
        Migration.Result memory quote = Migration.execute(staking, detf, 50 ether, 50 ether, 1, block.timestamp + 1 hours);
        vm.stopPrank();
        assertTrue(vm.revertToStateAndDelete(snap));
        assertEq(uint256(staking.phase()), uint256(ITokenStaking.Phase.Staking));
        assertEq(staking.reserveRemaining(), 50 ether);
        assertEq(address(staking.claimVault()), address(0));
        vm.startPrank(owner);
        Migration.Result memory result = Migration.execute(staking, detf, 50 ether, 50 ether, quote.claimOut, block.timestamp + 1 hours);
        vm.stopPrank();
        assertEq(result.claimOut, quote.claimOut);
        assertEq(result.sharesOut, quote.sharesOut);
    }

    function test_runner_rejectsUnsafeLimitsAndIncompleteFinalization() public {
        _prepareMigration();
        vm.startPrank(owner);
        vm.expectRevert("Migration: invalid chunk");
        this.invokeRunner(21 ether, 20 ether, 1, block.timestamp + 1 hours);
        vm.expectRevert("Migration: zero minimum");
        this.invokeRunner(20 ether, 20 ether, 0, block.timestamp + 1 hours);
        vm.expectRevert("Migration: expired deadline");
        this.invokeRunner(20 ether, 20 ether, 1, block.timestamp);
        vm.expectRevert("Migration: incomplete phase");
        this.verifyRunner();
        vm.stopPrank();
        assertEq(staking.reserveRemaining(), 50 ether);
        assertEq(uint256(staking.phase()), uint256(ITokenStaking.Phase.Staking));
    }

    function invokeRunner(uint256 amount, uint256 limit, uint256 minimum, uint256 deadline) external {
        Migration.execute(staking, detf, amount, limit, minimum, deadline);
    }

    function verifyRunner() external view {
        Migration.verifyComplete(staking, detf);
    }
}
