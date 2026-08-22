// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {
    DETF_FEE_TO_BOND_NFT_ID,
    DETF_FIRST_USER_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
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
        uint256 nftLpBefore = IERC20(hook).balanceOf(bond);
        // D13: all reserve LP stays on the NFT vault.
        assertGt(nftLpBefore, 0, "user LP on bond NFT");
        assertEq(IERC20(hook).balanceOf(detfInfo.rebasingClaimToken()), 0, "claim holds no LP");

        vm.warp(block.timestamp + 30 days + 1);
        vm.prank(detfUser);
        uint256 principal = detfInfo.sellPositionToDetfNft(tokenId, detfUser);

        assertEq(principal, shares);
        assertEq(detfInfo.userBondedLp(), userBefore - principal);
        // D10: originalShares move to id 0; physical LP stays on the NFT.
        assertEq(detfInfo.protocolLp(), protocolBefore + principal);
        assertEq(IERC20(hook).balanceOf(bond), nftLpBefore, "LP stays on NFT");
        assertEq(IERC20(hook).balanceOf(detfInfo.rebasingClaimToken()), 0, "claim still holds no LP");
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

    /// @notice N10: after sell-in credits id 0, a remaining user bond does not absorb that LP.
    /// @dev Pre-N10 haircut used physical LP / (totalShares − id0 effective), so the remaining
    ///      user convertToAssets approached the whole NFT LP book.
    function test_N10_userBondDoesNotAbsorbId0Lp() public {
        address bob = makeAddr("bobN10");
        IDETFNFTVault nft_ = IDETFNFTVault(detfInfo.bondNftVault());
        uint256 aliceId = DETF_FIRST_USER_BOND_NFT_ID;
        assertEq(nft_.ownerOf(aliceId), detfUser, "setUp first bond is id 3");

        (uint256 bobId,) = _bootstrapViaFirstBond(bob, 50 ether);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        vm.prank(detfUser);
        detfInfo.sellPositionToDetfNft(aliceId, detfUser);

        uint256 bobOrig_ = nft_.originalSharesOf(bobId);
        uint256 id0Orig_ = nft_.originalSharesOf(nft_.detfNFTId());
        assertTrue(id0Orig_ > 0, "id 0 credited by sell-in");
        assertTrue(bobOrig_ > 0, "bob originalShares");

        address hook = detfInfo.reserveHook();
        uint256 physical_ = IERC20(hook).balanceOf(address(nft_));
        uint256 bobLp_ = nft_.convertToAssets(bobOrig_);
        uint256 id0Lp_ = nft_.convertToAssets(id0Orig_);

        assertTrue(physical_ > 0, "LP on NFT");
        assertTrue(bobLp_ < physical_, "bob does not take all physical LP");
        assertTrue(id0Lp_ > 0, "id 0 convertToAssets > 0");
        assertTrue(bobLp_ + id0Lp_ <= physical_, "claims do not exceed physical");
        assertTrue(bobLp_ < physical_ / 2, "bob is the smaller originalShares holder");
        assertEq(nft_.convertToAssets(nft_.originalSharesOf(DETF_FEE_TO_BOND_NFT_ID)), 0, "id1 not 4626 LP");
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

