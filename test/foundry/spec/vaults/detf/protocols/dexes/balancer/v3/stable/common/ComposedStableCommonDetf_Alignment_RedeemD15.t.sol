// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IComposedStableCommonDetfBonding} from "contracts/interfaces/IComposedStableCommonDetfBonding.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    ComposedStableCommonDetf_IntegratedDeploy_Test
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_IntegratedDeploy.t.sol";

contract ComposedStableCommonDetf_Alignment_RedeemD15 is ComposedStableCommonDetf_IntegratedDeploy_Test {
    uint256 internal constant MIN_LOCK = 30 days;

    function _composedThresholdMode() internal pure override returns (ThresholdMode) {
        return ThresholdMode.Open;
    }

    function test_D15_8_tokenOutNotDetfReverts() public {
        _bootstrapReserveGraph();
        deal(address(dai), alice, 500e18, true);
        vm.startPrank(alice);
        dai.approve(deployedDetfVault, 500e18);
        (uint256 tokenId_,) =
            IComposedStableCommonDetfBonding(deployedDetfVault).bond(dai, 500e18, MIN_LOCK, alice, block.timestamp + 1 hours);
        vm.stopPrank();
        vm.warp(block.timestamp + MIN_LOCK + 1);
        vm.prank(alice);
        IComposedStableCommonDetfBonding(deployedDetfVault).sellPositionToDetfNft(tokenId_, 0, alice);
        uint256 claimBal_ = rebasingDetfToken.balanceOf(alice);
        vm.prank(alice);
        vm.expectRevert();
        IComposedStableCommonDetfBonding(deployedDetfVault).redeemClaim(
            claimBal_ / 3, dai, 0, alice, block.timestamp + 1 hours
        );
    }
}
