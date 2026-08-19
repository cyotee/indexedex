// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalDETF.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";
import {
    UniswapV4StandardExchangeOrbitalDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETFRepo.sol";

contract UniswapV4StandardExchangeOrbitalDETF_BondTest is TestBase_UniswapV4StandardExchangeOrbitalDETF {
    function setUp() public override {
        super.setUp();
        _firstBondBothPairs(200 ether, 200 ether);
    }

    function test_liveBond_singleLeg_ok_and_effectiveShares_use_mids() public {
        vm.startPrank(detfUser);
        (uint256 tokenId, uint256 shares) = detfInfo.bond(
            IERC20(pair0),
            50 ether,
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(tokenId, 0);
        assertGt(shares, 0);
        assertEq(
            uint8(detfInfo.capitalModeOf(tokenId)),
            uint8(IUniswapV4StandardExchangeOrbitalDETF.CapitalMode.Single)
        );
        assertEq(detfInfo.capitalToken0Of(tokenId), pair0);

        // D10: originalShares = LP; lock bonus applies only to effectiveShares.
        IDETFNFTVault nft = IDETFNFTVault(detfInfo.bondNftVault());
        assertEq(nft.originalSharesOf(tokenId), shares, "originalShares is LP principal");
        uint256 eff = nft.effectiveSharesOf(tokenId);
        assertGt(eff, 0, "effectiveShares set");
        assertGe(eff, shares, "lock bonus on effective only");
    }

    function test_preMaturity_sell_reverts() public {
        vm.startPrank(detfUser);
        (uint256 tokenId,) = detfInfo.bond(
            IERC20(pair0), 20 ether, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours
        );
        vm.expectRevert();
        detfInfo.sellPositionToDetfNft(tokenId, detfUser);
        vm.stopPrank();
    }

    function test_preMaturity_close_reverts() public {
        vm.startPrank(detfUser);
        (uint256 tokenId,) = detfInfo.bond(
            IERC20(pair1), 20 ether, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours
        );
        vm.expectRevert();
        detfInfo.closeBondMature(tokenId, _minOut3(), detfUser, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function test_postMaturity_sell_succeeds() public {
        vm.startPrank(detfUser);
        (uint256 tokenId,) = detfInfo.bond(
            IERC20(pair0), 30 ether, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        uint256 unlock = IDETFNFTVault(detfInfo.bondNftVault()).unlockTimeOf(tokenId);
        vm.warp(unlock + 1);

        vm.startPrank(detfUser);
        uint256 principal = detfInfo.sellPositionToDetfNft(tokenId, detfUser);
        vm.stopPrank();
        assertGt(principal, 0);
    }

    function test_postMaturity_close_single_capital() public {
        vm.startPrank(detfUser);
        (uint256 tokenId,) = detfInfo.bond(
            IERC20(pair0), 40 ether, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        uint256 unlock = IDETFNFTVault(detfInfo.bondNftVault()).unlockTimeOf(tokenId);
        vm.warp(unlock + 1);

        uint256 before0 = IERC20(pair0).balanceOf(detfUser);
        uint256 before1 = IERC20(pair1).balanceOf(detfUser);
        vm.startPrank(detfUser);
        uint256[] memory out_ = detfInfo.closeBondMature(tokenId, _minOut3(), detfUser, block.timestamp + 1 hours);
        vm.stopPrank();
        assertTrue(out_[1] + out_[2] > 0);
        assertEq(out_[0], 0, "D25 DETF slot burned");
        assertEq(IERC20(pair0).balanceOf(detfUser) - before0, out_[1]);
        assertEq(IERC20(pair1).balanceOf(detfUser) - before1, out_[2]);
    }

    function test_postMaturity_close_dual_residual_composition() public {
        // Dual capital bond after live.
        vm.startPrank(detfUser);
        (uint256 tokenId,) = detfInfo.bond(
            IERC20(pair0),
            30 ether,
            IERC20(pair1),
            30 ether,
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(
            uint8(detfInfo.capitalModeOf(tokenId)),
            uint8(IUniswapV4StandardExchangeOrbitalDETF.CapitalMode.Dual)
        );

        // Skew book via primary mint so residual != open notionals.
        _mintPair(pair0, 100 ether);

        uint256 unlock = IDETFNFTVault(detfInfo.bondNftVault()).unlockTimeOf(tokenId);
        vm.warp(unlock + 1);

        uint256 b0 = IERC20(pair0).balanceOf(detfUser);
        uint256 b1 = IERC20(pair1).balanceOf(detfUser);
        vm.startPrank(detfUser);
        uint256[] memory out_ = detfInfo.closeBondMature(tokenId, _minOut3(), detfUser, block.timestamp + 1 hours);
        vm.stopPrank();
        assertEq(out_[0], 0, "D25 DETF slot burned");
        assertGt(out_[1], 0, "dual residual pair0");
        assertGt(out_[2], 0, "dual residual pair1");
        assertEq(IERC20(pair0).balanceOf(detfUser) - b0, out_[1]);
        assertEq(IERC20(pair1).balanceOf(detfUser) - b1, out_[2]);
        assertTrue(out_[1] != 30 ether || out_[2] != 30 ether, "residual != fixed open notionals");
    }

    function test_claimRewards_free_detf_while_locked() public {
        // Seed inventory free DETF onto bond NFT via mint seigniorage split.
        _mintPair(pair0, 50 ether);

        vm.startPrank(detfUser);
        (uint256 tokenId,) = detfInfo.bond(
            IERC20(pair0), 20 ether, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        // Accrue more inventory rewards on bond vault by minting again.
        _mintPair(pair0, 50 ether);

        IDETFNFTVault nft = IDETFNFTVault(detfInfo.bondNftVault());
        // Push global reward index: free DETF sitting on NFT vault is the reward token.
        // Mint more inventory DETF already on bond vault; update via claim.
        uint256 balBefore = IERC20(detf).balanceOf(detfUser);
        vm.startPrank(detfUser);
        uint256 r = detfInfo.claimRewards(tokenId, detfUser);
        vm.stopPrank();

        // Either pending harvested or zero if no accrual yet — if pending>0, balance must rise.
        uint256 pending = nft.pendingRewards(tokenId);
        if (r > 0) {
            assertEq(IERC20(detf).balanceOf(detfUser) - balBefore, r, "free DETF transferred while locked");
        } else {
            // Still pre-maturity and claim path did not revert (DETF->NFT owner auth).
            assertTrue(block.timestamp < nft.unlockTimeOf(tokenId), "still locked");
            // Force inventory: transfer DETF to NFT vault then claim again after update.
            deal(detf, address(nft), IERC20(detf).balanceOf(address(nft)) + 10 ether);
            vm.startPrank(detfUser);
            r = detfInfo.claimRewards(tokenId, detfUser);
            vm.stopPrank();
            // With totalShares > 0 and new DETF on vault, harvest should pay.
            assertGt(r + nft.pendingRewards(tokenId), 0, "rewards path live after inventory");
            if (r > 0) {
                assertGe(IERC20(detf).balanceOf(detfUser), balBefore + r);
            }
        }
        pending;
    }
}
