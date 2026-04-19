// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IProtocolDETFErrors} from "contracts/interfaces/IProtocolDETFErrors.sol";
import {IBaseProtocolDETFBonding} from "contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol";
import {ProtocolDETFIntegrationBase} from "test/foundry/spec/vaults/protocol/EthereumProtocolDETF_IntegrationBase.t.sol";

contract EthereumProtocolDETFUnifiedBondingTest is ProtocolDETFIntegrationBase {
    function test_acceptedBondTokens_initializedWithWethAndRich() public view {
        address[] memory tokens = IBaseProtocolDETFBonding(address(detf)).acceptedBondTokens();

        assertEq(tokens.length, 2, "accepted bond token set length");
        assertTrue(
            IBaseProtocolDETFBonding(address(detf)).isAcceptedBondToken(IERC20(address(weth9))),
            "WETH should be accepted"
        );
        assertTrue(IBaseProtocolDETFBonding(address(detf)).isAcceptedBondToken(rich), "RICH should be accepted");
    }

    function test_bond_wethTokenIn_mintsPosition() public {
        uint256 amountIn = 1e18;

        vm.startPrank(detfAlice);
        IERC20(address(weth9)).approve(address(detf), amountIn);
        (uint256 tokenId, uint256 shares) = IBaseProtocolDETFBonding(address(detf)).bond(
            IERC20(address(weth9)), amountIn, 30 days, detfAlice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertGt(tokenId, 0, "tokenId");
        assertGt(shares, 0, "shares");
        assertEq(protocolNFTVault.ownerOf(tokenId), detfAlice, "owner");
    }

    function test_bond_richTokenIn_mintsPosition() public {
        uint256 amountIn = 1_000e18;

        vm.startPrank(detfAlice);
        rich.approve(address(detf), amountIn);
        (uint256 tokenId, uint256 shares) = IBaseProtocolDETFBonding(address(detf)).bond(
            rich, amountIn, 30 days, detfAlice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertGt(tokenId, 0, "tokenId");
        assertGt(shares, 0, "shares");
        assertEq(protocolNFTVault.ownerOf(tokenId), detfAlice, "owner");
    }

    function test_bond_wethAsEth_wrapsNativeEth() public {
        uint256 amountIn = 1e18;

        vm.deal(detfAlice, amountIn + 1e18);
        vm.prank(detfAlice);
        (uint256 tokenId, uint256 shares) = IBaseProtocolDETFBonding(address(detf)).bond{value: amountIn}(
            IERC20(address(weth9)), amountIn, 30 days, detfAlice, true, block.timestamp + 1 hours
        );

        assertGt(tokenId, 0, "tokenId");
        assertGt(shares, 0, "shares");
        assertEq(protocolNFTVault.ownerOf(tokenId), detfAlice, "owner");
    }

    function test_bond_revertsForUnsupportedToken() public {
        uint256 amountIn = 1e18;

        vm.prank(detfAlice);
        vm.expectRevert(abi.encodeWithSelector(IProtocolDETFErrors.BondTokenNotSupported.selector, IERC20(address(detf))));
        IBaseProtocolDETFBonding(address(detf)).bond(
            IERC20(address(detf)), amountIn, 30 days, detfAlice, false, block.timestamp + 1 hours
        );
    }

    function test_bond_revertsForInvalidEthRoute() public {
        uint256 amountIn = 1e18;

        vm.deal(detfAlice, amountIn);
        vm.prank(detfAlice);
        vm.expectRevert(abi.encodeWithSelector(IProtocolDETFErrors.InvalidEthBondRoute.selector, rich));
        IBaseProtocolDETFBonding(address(detf)).bond{value: amountIn}(
            rich, amountIn, 30 days, detfAlice, true, block.timestamp + 1 hours
        );
    }

    function test_bond_revertsForIncorrectEthValue() public {
        uint256 amountIn = 1e18;
        uint256 sentValue = amountIn - 1;

        vm.deal(detfAlice, amountIn);
        vm.prank(detfAlice);
        vm.expectRevert(abi.encodeWithSelector(IProtocolDETFErrors.IncorrectEthValue.selector, amountIn, sentValue));
        IBaseProtocolDETFBonding(address(detf)).bond{value: sentValue}(
            IERC20(address(weth9)), amountIn, 30 days, detfAlice, true, block.timestamp + 1 hours
        );
    }

    function test_bond_revertsForUnexpectedEthValue() public {
        uint256 amountIn = 1e18;

        vm.deal(detfAlice, amountIn);
        vm.prank(detfAlice);
        vm.expectRevert(abi.encodeWithSelector(IProtocolDETFErrors.IncorrectEthValue.selector, 0, amountIn));
        IBaseProtocolDETFBonding(address(detf)).bond{value: amountIn}(
            IERC20(address(weth9)), amountIn, 30 days, detfAlice, false, block.timestamp + 1 hours
        );
    }
}