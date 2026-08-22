// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID,
    DETF_FIRST_USER_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalDETF.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";

/// @notice D25 close on Uni V4 Orbital.
contract UniswapV4StandardExchangeOrbitalDETF_Alignment_CloseD25 is
    TestBase_UniswapV4StandardExchangeOrbitalDETF
{
    function setUp() public override {
        super.setUp();
        detf = _deployDetfWired(_openArgsUnique("d25"));
        _bindDetfPointers();
        _firstBondBothPairs(200 ether, 200 ether);
    }

    function test_D25_1_userDetfOnlyFromClaimRewards() public {
        vm.startPrank(detfUser);
        (uint256 tokenId,) = detfInfo.bond(
            IERC20(pair0), 40 ether, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        IDETFNFTVault nft_ = IDETFNFTVault(detfInfo.bondNftVault());
        uint256 pending_ = nft_.pendingRewards(tokenId);
        uint256 detfBefore_ = IERC20(detf).balanceOf(detfUser);
        vm.prank(detfUser);
        detfInfo.closeBondMature(tokenId, _minOut3(), detfUser, block.timestamp + 1 hours);
        assertApproxEqAbs(IERC20(detf).balanceOf(detfUser) - detfBefore_, pending_, 1, "D25-1");
    }

    function test_D25_2_withdrawnDetfNotBurned() public {
        vm.startPrank(detfUser);
        (uint256 tokenId,) = detfInfo.bond(
            IERC20(pair0), 40 ether, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        vm.prank(detfUser);
        detfInfo.closeBondMature(tokenId, _minOut3(), detfUser, block.timestamp + 1 hours);
        assertGe(IERC20(detf).totalSupply(), supplyBefore_, "D25-2");
    }

    function test_D25_3_id0OriginalSharesRise() public {
        vm.startPrank(detfUser);
        (uint256 tokenId,) = detfInfo.bond(
            IERC20(pair0), 40 ether, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        IDETFNFTVault nft_ = IDETFNFTVault(detfInfo.bondNftVault());
        uint256 id0Before_ = nft_.originalSharesOf(nft_.detfNFTId());
        vm.prank(detfUser);
        detfInfo.closeBondMature(tokenId, _minOut3(), detfUser, block.timestamp + 1 hours);
        assertGt(nft_.originalSharesOf(nft_.detfNFTId()), id0Before_, "D25-3");
    }

    function test_D25_4_userReceivesNonDetfBasket() public {
        vm.startPrank(detfUser);
        (uint256 tokenId,) = detfInfo.bond(
            IERC20(pair0), 40 ether, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        uint256 before0 = IERC20(pair0).balanceOf(detfUser);
        uint256 before1 = IERC20(pair1).balanceOf(detfUser);
        vm.prank(detfUser);
        uint256[] memory out_ = detfInfo.closeBondMature(tokenId, _minOut3(), detfUser, block.timestamp + 1 hours);
        assertEq(out_[0], 0, "DETF slot");
        assertEq(IERC20(pair0).balanceOf(detfUser) - before0, out_[1]);
        assertEq(IERC20(pair1).balanceOf(detfUser) - before1, out_[2]);
        assertGt(out_[1] + out_[2], 0, "basket");
    }

    function test_D25_5_ids1and2CannotClose() public {
        vm.expectRevert();
        detfInfo.closeBondMature(DETF_FEE_TO_BOND_NFT_ID, _minOut3(), detfUser, block.timestamp + 1 hours);
        vm.expectRevert();
        detfInfo.closeBondMature(DETF_CREATOR_BOND_NFT_ID, _minOut3(), detfUser, block.timestamp + 1 hours);
    }

    function test_D25_6_previewEqualsExecute() public {
        vm.startPrank(detfUser);
        (uint256 tokenId,) = detfInfo.bond(
            IERC20(pair0), 40 ether, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        uint256[] memory preview_ = detfInfo.previewCloseBondMature(tokenId);
        vm.prank(detfUser);
        uint256[] memory out_ = detfInfo.closeBondMature(tokenId, _minOut3(), detfUser, block.timestamp + 1 hours);
        assertEq(out_.length, preview_.length);
        assertApproxEqAbs(out_[1], preview_[1], 1);
        assertApproxEqAbs(out_[2], preview_[2], 1);
    }

    function test_D25_7_onlyUserBondClose_minRejoinLpOutGt0() public {
        uint256 tokenId = DETF_FIRST_USER_BOND_NFT_ID;
        IDETFNFTVault nft_ = IDETFNFTVault(detfInfo.bondNftVault());
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        uint256 id0Before_ = nft_.originalSharesOf(nft_.detfNFTId());
        vm.prank(detfUser);
        detfInfo.closeBondMature(tokenId, _minOut3(), detfUser, block.timestamp + 1 hours);
        assertGt(nft_.originalSharesOf(nft_.detfNFTId()), id0Before_, "D25-7");
    }

    function test_D25_lastClose_feeCreatorPendingDoesNotJump() public {
        uint256 tokenId = DETF_FIRST_USER_BOND_NFT_ID;
        IDETFNFTVault nft_ = IDETFNFTVault(detfInfo.bondNftVault());
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        uint256 feePending_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 creatorPending_ = nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID);
        vm.prank(detfUser);
        detfInfo.closeBondMature(tokenId, _minOut3(), detfUser, block.timestamp + 1 hours);
        assertLe(nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID), feePending_ + 1, "feeTo pending");
        assertLe(nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID), creatorPending_ + 1, "creator pending");
    }
}