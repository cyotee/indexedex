// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ITokenStaking} from "contracts/interfaces/ITokenStaking.sol";
import {ITokenStakingDFPkg} from "contracts/protocols/staking/token/ITokenStakingDFPkg.sol";
import {TestBase_TokenStaking} from "contracts/protocols/staking/token/TestBase_TokenStaking.sol";
import {TaxedERC20Harness} from "contracts/test/stubs/TaxedERC20Harness.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";

contract TokenStaking_APEX_Recurrence is TestBase_TokenStaking {
    function _taxFixture() internal returns (TaxedERC20Harness token, ITokenStaking product) {
        token = new TaxedERC20Harness("Taxed stake", "TAX", 18, 0);
        product = tokenStakingPkg.deployStaking(
            diamondPackageFactory,
            ITokenStakingDFPkg.PkgArgs({
                stakingToken: IERC20(address(token)), rewardsDuration: 7 days,
                owner: owner, ownershipBufferPeriod: 2 days, optionalSalt: bytes32(0)
            })
        );
        token.mint(stakerA, 100 ether);
        token.mint(owner, 100 ether);
    }

    function _stakeRejectsTax(bool viaPermit2) internal {
        (TaxedERC20Harness token, ITokenStaking product) = _taxFixture();
        vm.startPrank(stakerA);
        if (viaPermit2) {
            token.approve(address(permit2), 100 ether);
            permit2.approve(address(token), address(product), uint160(100 ether), type(uint48).max);
        } else {
            token.approve(address(product), 100 ether);
        }
        vm.stopPrank();
        uint256 snapshot = vm.snapshotState();
        vm.prank(stakerA);
        product.stake(100 ether);
        assertEq(product.totalSupply(), 100 ether, "untaxed positive control");
        assertEq(token.balanceOf(address(product)), 100 ether);
        assertTrue(vm.revertToState(snapshot));
        token.setTaxBps(1000);
        vm.prank(stakerA);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 100 ether, 90 ether));
        product.stake(100 ether);
        assertEq(product.totalSupply(), 0);
        assertEq(product.balanceOf(stakerA), 0);
        assertEq(token.balanceOf(address(product)), 0);
    }

    function test_RECURRENCE_tokenStaking_FoTForbiddenDirect() public { _stakeRejectsTax(false); }
    function test_RECURRENCE_tokenStaking_FoTForbiddenPermit2() public { _stakeRejectsTax(true); }

    function test_RECURRENCE_tokenStaking_FoTForbiddenRewards() public {
        (TaxedERC20Harness token, ITokenStaking product) = _taxFixture();
        vm.prank(owner);
        token.approve(address(product), 100 ether);
        uint256 snapshot = vm.snapshotState();
        vm.prank(owner);
        product.notifyRewardAmount(100 ether);
        assertGt(product.rewardRate(), 0, "untaxed positive control");
        assertEq(token.balanceOf(address(product)), 100 ether);
        assertTrue(vm.revertToState(snapshot));
        token.setTaxBps(1000);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 100 ether, 90 ether));
        product.notifyRewardAmount(100 ether);
        assertEq(product.rewardRate(), 0);
        assertEq(token.balanceOf(address(product)), 0);
    }
}
