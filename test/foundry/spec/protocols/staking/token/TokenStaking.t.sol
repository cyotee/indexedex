// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";

import {IDetfClaimPurchase} from "contracts/interfaces/IDetfClaimPurchase.sol";
import {ITokenStaking} from "contracts/interfaces/ITokenStaking.sol";
import {TestBase_TokenStaking} from "contracts/protocols/staking/token/TestBase_TokenStaking.sol";

/// @dev Deferred: I1–I3 N/A (no pretransfer). E6 N/A (no surplus refund). CROPS N/A.
///      L2 FoT underlying forbidden. M* no router. O* Permit2 allowance notify covered;
///      no signature-transfer path.
contract TokenStaking_Test is TestBase_TokenStaking {
    function test_stake_withdraw_roundtrip() public {
        vm.startPrank(stakerA);
        stakeToken.approve(address(staking), 100e18);
        staking.stake(100e18);
        vm.stopPrank();

        assertEq(staking.balanceOf(stakerA), 100e18);
        assertEq(staking.totalSupply(), 100e18);
        assertEq(stakeToken.balanceOf(address(staking)), 100e18);

        vm.prank(stakerA);
        staking.withdraw(40e18);

        assertEq(staking.balanceOf(stakerA), 60e18);
        assertEq(stakeToken.balanceOf(stakerA), 940e18);
    }

    function test_notifyRewardAmount_same_token_streams() public {
        vm.startPrank(stakerA);
        stakeToken.approve(address(staking), 100e18);
        staking.stake(100e18);
        vm.stopPrank();

        vm.startPrank(owner);
        stakeToken.approve(address(staking), 700e18);
        staking.notifyRewardAmount(700e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);
        uint256 earned_ = staking.earned(stakerA);
        assertApproxEqAbs(earned_, 100e18, 1e5);

        vm.prank(stakerA);
        staking.getReward();
        assertApproxEqAbs(stakeToken.balanceOf(stakerA), 1000e18, 1e5);
        assertEq(staking.rewards(stakerA), 0);
    }

    function test_reassign_moves_stake_and_pending_rewards() public {
        vm.startPrank(stakerA);
        stakeToken.approve(address(staking), 100e18);
        staking.stake(100e18);
        vm.stopPrank();

        vm.startPrank(owner);
        stakeToken.approve(address(staking), 700e18);
        staking.notifyRewardAmount(700e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.prank(stakerA);
        staking.reassign(stakerB, 100e18);

        assertEq(staking.balanceOf(stakerA), 0);
        assertEq(staking.balanceOf(stakerB), 100e18);
        assertApproxEqAbs(staking.earned(stakerB), 100e18, 1e5);
        assertEq(staking.earned(stakerA), 0);
    }





    function test_migrateToClaimVault_reverts_when_unset() public {
        vm.prank(owner);
        vm.expectRevert(ITokenStaking.TargetDetfUnset.selector);
        staking.migrateToClaimVault(1e18, 0, block.timestamp + 1);
    }









    function test_rebasing_vault_live_balance() public {
        ERC20PermitMintableStub claimToken = new ERC20PermitMintableStub("Claim", "CLM", 18, address(this), 0);
        claimToken.mint(address(this), 100e18);
        IERC4626 vault = claimVaultPkg.deployVault(IERC20Metadata(address(claimToken)));
        claimToken.approve(address(vault), 100e18);
        uint256 shares = vault.deposit(100e18, address(this));
        assertGt(shares, 0);
        claimToken.mint(address(vault), 50e18);
        assertEq(vault.totalAssets(), 150e18);
        uint256 assets = vault.redeem(shares, address(this), address(this));
        assertApproxEqAbs(assets, 150e18, 2);
    }

    function test_stake_via_permit2_allowance() public {
        vm.startPrank(stakerA);
        stakeToken.approve(address(permit2), 100e18);
        permit2.approve(address(stakeToken), address(staking), uint160(100e18), type(uint48).max);
        staking.stake(100e18);
        vm.stopPrank();

        assertEq(staking.balanceOf(stakerA), 100e18);
        assertEq(stakeToken.balanceOf(address(staking)), 100e18);
        assertEq(staking.permit2(), address(permit2));
    }

    function test_rescue_reward_reserve_leaves_principal() public {
        vm.startPrank(stakerA);
        stakeToken.approve(address(staking), 100e18);
        staking.stake(100e18);
        vm.stopPrank();

        vm.startPrank(owner);
        stakeToken.approve(address(staking), 700e18);
        staking.notifyRewardAmount(700e18);
        vm.stopPrank();

        assertEq(staking.rewardReserve(), 700e18);

        uint256 ownerBefore = stakeToken.balanceOf(owner);
        vm.prank(owner);
        staking.rescueRewardReserve(700e18);

        assertEq(stakeToken.balanceOf(owner), ownerBefore + 700e18);
        assertEq(staking.rewardReserve(), 0);
        assertEq(staking.totalSupply(), 100e18);
        assertEq(staking.rewardRate(), 0);

        vm.prank(stakerA);
        staking.withdraw(100e18);
        assertEq(stakeToken.balanceOf(stakerA), 1000e18);
        assertEq(staking.balanceOf(stakerA), 0);
    }

    function test_rescue_cannot_take_principal() public {
        vm.startPrank(stakerA);
        stakeToken.approve(address(staking), 100e18);
        staking.stake(100e18);
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ITokenStaking.AmountExceedsReserve.selector, 1, 0));
        staking.rescueRewardReserve(1);
    }

    function test_rescue_only_owner() public {
        vm.prank(stakerA);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, stakerA));
        staking.rescueRewardReserve(1);
    }

    function test_notifyRewardAmount_via_permit2_streams() public {
        vm.startPrank(stakerA);
        stakeToken.approve(address(staking), 100e18);
        staking.stake(100e18);
        vm.stopPrank();

        vm.startPrank(owner);
        stakeToken.approve(address(permit2), 700e18);
        permit2.approve(address(stakeToken), address(staking), uint160(700e18), type(uint48).max);
        staking.notifyRewardAmount(700e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);
        assertApproxEqAbs(staking.earned(stakerA), 100e18, 1e5);
    }

    function test_two_stakers_split_stream() public {
        vm.startPrank(stakerA);
        stakeToken.approve(address(staking), 100e18);
        staking.stake(100e18);
        vm.stopPrank();
        vm.startPrank(stakerB);
        stakeToken.approve(address(staking), 100e18);
        staking.stake(100e18);
        vm.stopPrank();

        vm.startPrank(owner);
        stakeToken.approve(address(staking), 700e18);
        staking.notifyRewardAmount(700e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);
        assertApproxEqAbs(staking.earned(stakerA), 50e18, 1e5);
        assertApproxEqAbs(staking.earned(stakerB), 50e18, 1e5);
    }

    function test_donate_does_not_mint_stake() public {
        stakeToken.mint(address(this), 50e18);
        stakeToken.transfer(address(staking), 50e18);
        assertEq(staking.rewardReserve(), 50e18);
        assertEq(staking.totalSupply(), 0);

        vm.startPrank(stakerA);
        stakeToken.approve(address(staking), 100e18);
        staking.stake(100e18);
        vm.stopPrank();

        assertEq(staking.balanceOf(stakerA), 100e18);
        assertEq(staking.totalSupply(), 100e18);
        assertEq(staking.rewardReserve(), 50e18);
        assertEq(stakeToken.balanceOf(address(staking)), 150e18);
    }

    function test_stake_zero_reverts() public {
        vm.prank(stakerA);
        vm.expectRevert(ITokenStaking.AmountZero.selector);
        staking.stake(0);
    }

    function test_notify_zero_reverts() public {
        vm.prank(owner);
        vm.expectRevert(ITokenStaking.AmountZero.selector);
        staking.notifyRewardAmount(0);
    }

    function test_withdraw_over_balance_reverts() public {
        vm.startPrank(stakerA);
        stakeToken.approve(address(staking), 10e18);
        staking.stake(10e18);
        vm.expectRevert(
            abi.encodeWithSelector(ITokenStaking.InsufficientStake.selector, stakerA, 11e18, 10e18)
        );
        staking.withdraw(11e18);
        vm.stopPrank();
    }

    function test_notify_not_owner_reverts() public {
        vm.prank(stakerA);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, stakerA));
        staking.notifyRewardAmount(1e18);
    }

    function test_exit_returns_principal_and_reward() public {
        vm.startPrank(stakerA);
        stakeToken.approve(address(staking), 100e18);
        staking.stake(100e18);
        vm.stopPrank();

        vm.startPrank(owner);
        stakeToken.approve(address(staking), 700e18);
        staking.notifyRewardAmount(700e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);
        uint256 earned_ = staking.earned(stakerA);
        vm.prank(stakerA);
        staking.exit();

        assertEq(staking.balanceOf(stakerA), 0);
        assertEq(staking.rewards(stakerA), 0);
        assertApproxEqAbs(stakeToken.balanceOf(stakerA), 1000e18 + earned_, 1e5);
    }

    function test_setRewardsDuration_live_period_then_after_finish() public {
        vm.startPrank(stakerA);
        stakeToken.approve(address(staking), 100e18);
        staking.stake(100e18);
        vm.stopPrank();
        vm.startPrank(owner);
        stakeToken.approve(address(staking), 700e18);
        staking.notifyRewardAmount(700e18);
        vm.expectRevert(ITokenStaking.RewardsPeriodNotFinished.selector);
        staking.setRewardsDuration(14 days);
        vm.stopPrank();

        vm.warp(staking.periodFinish() + 1);
        vm.prank(owner);
        staking.setRewardsDuration(14 days);
        assertEq(staking.rewardsDuration(), 14 days);
    }

    function test_second_notify_during_period_extends() public {
        vm.startPrank(stakerA);
        stakeToken.approve(address(staking), 100e18);
        staking.stake(100e18);
        vm.stopPrank();
        vm.startPrank(owner);
        stakeToken.approve(address(staking), 1400e18);
        staking.notifyRewardAmount(700e18);
        vm.warp(block.timestamp + 1 days);
        uint256 leftover_ = (staking.periodFinish() - block.timestamp) * staking.rewardRate();
        staking.notifyRewardAmount(700e18);
        vm.stopPrank();

        assertEq(staking.periodFinish(), block.timestamp + 7 days);
        assertEq(staking.rewardRate(), (700e18 + leftover_) / 7 days);
    }

    function test_notify_while_totalSupply_zero_empty_period_not_credited() public {
        vm.startPrank(owner);
        stakeToken.approve(address(staking), 700e18);
        staking.notifyRewardAmount(700e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);
        vm.startPrank(stakerA);
        stakeToken.approve(address(staking), 100e18);
        staking.stake(100e18);
        vm.stopPrank();
        assertEq(staking.earned(stakerA), 0);

        vm.warp(block.timestamp + 1 days);
        assertApproxEqAbs(staking.earned(stakerA), 100e18, 1e5);
    }

    function test_recoverERC20_staking_token_reverts() public {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(ITokenStaking.CannotRecoverReservedToken.selector, IERC20(address(stakeToken)))
        );
        staking.recoverERC20(IERC20(address(stakeToken)), 1);
    }



    function test_completeWrap_reverts_in_staking_phase() public {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITokenStaking.InvalidPhase.selector, ITokenStaking.Phase.Staking, ITokenStaking.Phase.Migrating
            )
        );
        staking.completeWrap(owner);
    }



    function test_J1_facetFuncs_include_completeWrap() public view {
        bytes4[] memory funcs_ = IFacet(address(tokenStakingFacet)).facetFuncs();
        assertEq(funcs_.length, 33);
        bool found_;
        for (uint256 i; i < funcs_.length; ++i) {
            if (funcs_[i] == ITokenStaking.completeWrap.selector) found_ = true;
        }
        assertTrue(found_, "J1 completeWrap");
    }

    function test_J2_proxyLoupe_allProductSelectors() public view {
        IDiamondLoupe loupe_ = IDiamondLoupe(address(staking));
        bytes4[] memory funcs_ = IFacet(address(tokenStakingFacet)).facetFuncs();
        for (uint256 i; i < funcs_.length; ++i) {
            address facetAddr_ = loupe_.facetAddress(funcs_[i]);
            assertTrue(facetAddr_ != address(0), "J2 loupe zero facet");
            assertTrue(facetAddr_ != address(staking), "J2 facet != proxy");
        }
    }

    function test_J3_proxyCallable_smoke() public {
        assertEq(address(staking.stakingToken()), address(stakeToken));
        assertEq(uint256(staking.phase()), uint256(ITokenStaking.Phase.Staking));
        assertEq(staking.permit2(), address(permit2));
        vm.startPrank(stakerA);
        stakeToken.approve(address(staking), 1e18);
        staking.stake(1e18);
        staking.withdraw(1e18);
        vm.stopPrank();
        assertEq(staking.balanceOf(stakerA), 0);
    }
}
