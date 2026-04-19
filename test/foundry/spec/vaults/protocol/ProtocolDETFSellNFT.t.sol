// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IBaseProtocolDETFBonding} from "contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol";
import {ProtocolDETFIntegrationBase} from "test/foundry/spec/vaults/protocol/ProtocolDETF_IntegrationBase.t.sol";

/**
 * @title ProtocolDETFSellNFTTest
 * @notice Integration test for the canonical Bond NFT → RICHIR route.
 */
contract ProtocolDETFSellNFTTest is ProtocolDETFIntegrationBase {
    function test_sellNFT_transfersPrincipalShares_burnsNFT_mintsRICHIRShares() public {
        uint256 amountIn = 1_000e18;
        uint256 lockDuration = 30 days;
        uint256 chirSupplyBefore = IERC20(address(detf)).totalSupply();

        vm.startPrank(detfAlice);
        IERC20(address(weth9)).approve(address(detf), amountIn);
        (uint256 tokenId, uint256 shares) = IBaseProtocolDETFBonding(address(detf))
            .bond(IERC20(address(weth9)), amountIn, lockDuration, detfAlice, false, block.timestamp + 1 hours);
        vm.stopPrank();

        assertGt(IERC20(address(detf)).totalSupply(), chirSupplyBefore, "WETH bonding should mint CHIR for paired liquidity");

        uint256 protocolId = protocolNFTVault.protocolNFTId();
        uint256 protocolPrincipalBefore = protocolNFTVault.originalSharesOf(protocolId);
        uint256 richirSharesBefore = richir.sharesOf(detfAlice);

        vm.prank(detfAlice);
        uint256 richirMinted = IBaseProtocolDETFBonding(address(detf)).sellNFT(tokenId, detfAlice);

        // Principal-only share transfer into protocol-owned position
        assertEq(protocolNFTVault.originalSharesOf(protocolId), protocolPrincipalBefore + shares);

        // RICHIR mints shares 1:1 with contributed principal shares
        assertEq(richir.sharesOf(detfAlice), richirSharesBefore + shares);

        // RICHIR balanceOf is rebasing: balance = shares * redemptionRate / 1e18
        // After the first sale, the rate is based on the WETH value of the protocol NFT's BPT
        uint256 expectedBalance = richir.balanceOf(detfAlice);
        assertGt(expectedBalance, 0);

        // The sold bond NFT is burned
        assertEq(protocolNFTVault.ownerOf(tokenId), address(0));

        // richirMinted is the RICHIR balance amount (shares * rate), not just shares
        assertEq(richirMinted, expectedBalance);
        assertGt(richirMinted, 0);
    }
}
