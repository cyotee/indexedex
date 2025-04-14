// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

// Crane IERC20 imported below

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {ISeigniorageDETFUnderwriting} from "contracts/vaults/seigniorage/SeigniorageDETFUnderwritingTarget.sol";
import {ISeigniorageNFTVault} from "contracts/interfaces/ISeigniorageNFTVault.sol";

import {TestBase_SeigniorageDETF_Fork} from "test/foundry/fork/base_main/seigniorage/TestBase_SeigniorageDETF_Fork.sol";

contract SeigniorageFork_DETFIntegration is TestBase_SeigniorageDETF_Fork {
    function testFork_Sanity_Deployed() public view {
        assertTrue(address(detf).code.length > 0, "DETF has no code");
        assertTrue(reservePoolAddress.code.length > 0, "Reserve pool has no code");
        assertEq(address(detf.reserveVaultRateTarget()), address(dai), "Reserve vault rate target mismatch");
    }

    function testFork_PreviewUnderwrite_MatchesLockInfoShares() public {
        _mintReserveVaultSharesTo(owner, 1e18);

        IERC20 reserveAsset = _reserveAsset();
        uint256 assetIn = _mintReserveAssetTo(alice, UNDERWRITE_AMOUNT);

        (uint256 originalShares, uint256 effectiveShares, uint256 bonusMultiplier) = ISeigniorageDETFUnderwriting(
                address(detf)
            ).previewUnderwrite(IERC20(address(reserveAsset)), assetIn, LOCK_DURATION);

        assertGt(originalShares, 0, "preview originalShares should be > 0");
        assertGt(effectiveShares, 0, "preview effectiveShares should be > 0");
        assertGe(bonusMultiplier, 1e18, "bonusMultiplier should be >= 1x");

        vm.startPrank(alice);
        reserveAsset.approve(address(detf), assetIn);
        uint256 tokenId = detf.underwrite(IERC20(address(reserveAsset)), assetIn, LOCK_DURATION, alice, false);
        vm.stopPrank();

        ISeigniorageNFTVault.LockInfo memory info = detf.seigniorageNFTVault().lockInfoOf(tokenId);
        assertEq(info.sharesAwarded, originalShares, "lockInfo sharesAwarded mismatch");
        assertEq(info.bonusPercentage, bonusMultiplier, "lockInfo bonusPercentage mismatch");
    }

    function testFork_Underwrite_ThenRedeem_ReturnsRateTarget() public {
        _mintReserveVaultSharesTo(owner, 1e18);

        IERC20 reserveAsset = _reserveAsset();
        uint256 assetIn = _mintReserveAssetTo(alice, UNDERWRITE_AMOUNT);
        uint256 assetBalanceBefore = reserveAsset.balanceOf(alice);

        vm.startPrank(alice);
        reserveAsset.approve(address(detf), assetIn);
        uint256 tokenId = detf.underwrite(IERC20(address(reserveAsset)), assetIn, LOCK_DURATION, alice, false);

        assertEq(
            reserveAsset.balanceOf(alice),
            assetBalanceBefore - assetIn,
            "reserve asset should be spent into underwriting"
        );

        vm.warp(block.timestamp + LOCK_DURATION + 1);
        uint256 daiOut = ISeigniorageDETFUnderwriting(address(detf)).redeem(tokenId, alice);
        vm.stopPrank();

        assertGt(daiOut, 0, "redeem should return some rate target");
        assertGt(dai.balanceOf(alice), 0, "alice should receive rate target on redeem");
    }

    function testFork_Underwrite_InvalidToken_Reverts() public {
        deal(alice, UNDERWRITE_AMOUNT);
        vm.startPrank(alice);
        weth.deposit{value: UNDERWRITE_AMOUNT}();
        weth.approve(address(detf), UNDERWRITE_AMOUNT);
        vm.expectRevert();
        detf.underwrite(IERC20(address(weth)), UNDERWRITE_AMOUNT, LOCK_DURATION, alice, false);
        vm.stopPrank();
    }

    function _mintReserveVaultSharesTo(address user, uint256 tokenAmount) internal returns (uint256 sharesOut) {
        uint256 liquidity = _mintReserveAssetTo(user, tokenAmount);
        require(liquidity > 0, "No LP minted");

        vm.startPrank(user);
        _reserveAsset().approve(address(daiUsdcVault), type(uint256).max);
        sharesOut = daiUsdcVault.deposit(liquidity, user);
        vm.stopPrank();
    }
}
