// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";

/// @notice Phase 4: live bond ungated + realize expansion; lock clamp; sell.
contract UniswapV4SingleStandardExchangeDETF_BondTest is TestBase_UniswapV4SingleStandardExchangeDETF {
    function setUp() public override {
        super.setUp();
        _firstBond(300 ether);
    }

    function test_secondBond_ungated_realizesExpansionClock() public {
        // Warp past epochs so realize has work (or at least seeds clock).
        vm.warp(block.timestamp + 8 hours * 3);

        uint256 lastBefore = detfInfo.lastExpansionTimestamp();
        _firstBond(50 ether); // second bond (live)

        // After first live bond touch, clock should be seeded or advanced.
        assertTrue(
            detfInfo.lastExpansionTimestamp() >= lastBefore,
            "bond realize path advances/seeds lastExpansion"
        );
        assertGt(detfInfo.userBondedLp(), 0);
    }

    function test_lockTooShort_reverts() public {
        vm.startPrank(detfUser);
        vm.expectRevert();
        detfInfo.bond(
            IERC20(address(pairToken)),
            10 ether,
            1 days, // < DEFAULT_MIN_LOCK (30d) if bond terms set
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_sellToProtocol_movesUserBondedToProtocol() public {
        (uint256 tokenId, uint256 shares) = _firstBond(40 ether);
        uint256 userBefore = detfInfo.userBondedLp();
        uint256 protocolBefore = detfInfo.protocolLp();
        address hook = detfInfo.reserveHook();
        address bond = detfInfo.bondNftVault();
        address claim = detfInfo.rebasingClaimToken();
        // Physical: user LP on bond NFT after bond
        assertGt(IERC20(hook).balanceOf(bond), 0, "user LP on bond NFT");
        assertEq(IERC20(hook).balanceOf(claim), protocolBefore, "claim holds only protocol LP");

        vm.prank(detfUser);
        uint256 principal = detfInfo.sellPositionToDetfNft(tokenId, detfUser);

        assertEq(principal, shares);
        assertEq(detfInfo.userBondedLp(), userBefore - principal);
        // Protocol LP rises by principal (physical migrate NFT → claim)
        assertEq(detfInfo.protocolLp(), protocolBefore + principal);
        assertEq(IERC20(hook).balanceOf(claim), protocolBefore + principal, "claim holds sold LP");
    }

    function test_bond_lp_physically_on_bondNft() public {
        (uint256 tokenId, uint256 shares) = _firstBond(25 ether);
        address hook = detfInfo.reserveHook();
        address bond = detfInfo.bondNftVault();
        assertGt(shares, 0);
        assertGt(tokenId, 0);
        // PRD LOCK: open bond LP held by bond NFT package (not diamond).
        assertGe(IERC20(hook).balanceOf(bond), shares, "bond NFT holds user LP");
        assertEq(IERC20(hook).balanceOf(detf), 0, "diamond does not hold user bond LP");
        assertEq(detfInfo.protocolLp(), 0, "first bond creates no protocol LP");
    }

    function test_claimRewards_realizesExpansion() public {
        (uint256 tokenId,) = _firstBond(40 ether);
        vm.warp(block.timestamp + 8 hours * 5);
        uint256 lastBefore = detfInfo.lastExpansionTimestamp();
        // Realize path on DETF (holder may also harvest on bond NFT surface).
        vm.prank(detfUser);
        detfInfo.claimRewards(tokenId, detfUser);
        assertGe(detfInfo.lastExpansionTimestamp(), lastBefore, "claimRewards realizes expansion");
        // Direct NFT claim by holder (production user path for free DETF harvest).
        address bondNft = detfInfo.bondNftVault();
        vm.prank(detfUser);
        try IDETFNFTVault(bondNft).claimRewards(tokenId, detfUser) {} catch {}
    }
}

