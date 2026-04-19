// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IBaseProtocolDETFBonding} from "contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol";
import {ProtocolDETFIntegrationBase} from "test/foundry/spec/vaults/protocol/EthereumProtocolDETF_IntegrationBase.t.sol";

contract ProtocolDETFRedeemPositionTest is ProtocolDETFIntegrationBase {
    function test_redeemPosition_callsClaimLiquidity_burnsNFT_paysWeth() public {
        // Seed additional pool liquidity so redeeming Alice's position stays within Balancer's max-out ratio.
        _bondForReserveLiquidity(detfBob, 10_000e18);

        uint256 amountIn = 100e18;
        uint256 lockDuration = 30 days;

        vm.startPrank(detfAlice);
        IERC20(address(weth9)).approve(address(detf), amountIn);
        (uint256 tokenId,) = IBaseProtocolDETFBonding(address(detf))
            .bond(IERC20(address(weth9)), amountIn, lockDuration, detfAlice, false, block.timestamp + 1 hours);
        vm.stopPrank();

        vm.warp(block.timestamp + lockDuration + 1);

        uint256 wethBefore = IERC20(address(weth9)).balanceOf(detfAlice);

        vm.prank(detfAlice);
        uint256 wethOut = protocolNFTVault.redeemPosition(tokenId, detfAlice, block.timestamp + 1 days);

        assertGt(wethOut, 0);
        assertEq(IERC20(address(weth9)).balanceOf(detfAlice), wethBefore + wethOut);
        assertEq(protocolNFTVault.ownerOf(tokenId), address(0));
    }
}
