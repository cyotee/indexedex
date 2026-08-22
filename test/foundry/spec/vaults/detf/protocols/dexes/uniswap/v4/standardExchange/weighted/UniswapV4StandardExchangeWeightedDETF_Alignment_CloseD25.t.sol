// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {
    TestBase_UniswapV4StandardExchangeWeightedDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedDETF.sol";
import {
    IUniswapV4StandardExchangeWeightedDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedDETF.sol";

/// @notice D25 close on Uni V4 Weighted.
contract UniswapV4StandardExchangeWeightedDETF_Alignment_CloseD25 is
    TestBase_UniswapV4StandardExchangeWeightedDETF
{
    uint256 internal constant BOND_AMT = 200 ether;
    uint256 internal constant LATER_BOND = 20 ether;

    function setUp() public override {
        _setUpPlatform();
        detf = _deployDetfWired(_openArgsUnique("d25"));
        _bindDetfPointers();
    }

    function _minOut() internal pure returns (uint256[] memory m) {
        m = new uint256[](2);
    }

    function _laterBond(uint256 amt_) internal returns (uint256 tokenId) {
        _fundPair(detf, pair0, detfUser, amt_ * 2);
        vm.startPrank(detfUser);
        (tokenId,) = detfInfo.bond(IERC20(pair0), amt_, DEFAULT_MIN_LOCK, detfUser, false, _dl());
        vm.stopPrank();
    }

    function _liveThenLater() internal returns (uint256 tokenId) {
        _firstBondOn(detf, _one(BOND_AMT), pair0);
        tokenId = _laterBond(LATER_BOND);
    }

    function test_D25_1_userDetfOnlyFromClaimRewards() public {
        uint256 tokenId = _liveThenLater();
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        IDETFNFTVault nft_ = _bondNftVault(detf);
        uint256 pending_ = nft_.pendingRewards(tokenId);
        uint256 detfBefore_ = IERC20(detf).balanceOf(detfUser);
        vm.prank(detfUser);
        detfInfo.closeBondMature(tokenId, _minOut(), detfUser, _dl());
        assertApproxEqAbs(IERC20(detf).balanceOf(detfUser) - detfBefore_, pending_, 1, "D25-1");
    }

    function test_D25_2_withdrawnDetfNotBurned() public {
        uint256 tokenId = _liveThenLater();
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        vm.prank(detfUser);
        detfInfo.closeBondMature(tokenId, _minOut(), detfUser, _dl());
        assertGe(IERC20(detf).totalSupply(), supplyBefore_, "D25-2");
    }

    function test_D25_3_id0OriginalSharesRise() public {
        uint256 tokenId = _liveThenLater();
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        IDETFNFTVault nft_ = _bondNftVault(detf);
        uint256 id0Before_ = nft_.originalSharesOf(nft_.detfNFTId());
        vm.prank(detfUser);
        detfInfo.closeBondMature(tokenId, _minOut(), detfUser, _dl());
        assertGt(nft_.originalSharesOf(nft_.detfNFTId()), id0Before_, "D25-3");
    }

    function test_D25_4_userReceivesNonDetfBasket() public {
        uint256 tokenId = _liveThenLater();
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        uint256 before0 = IERC20(pair0).balanceOf(detfUser);
        vm.prank(detfUser);
        uint256[] memory out_ = detfInfo.closeBondMature(tokenId, _minOut(), detfUser, _dl());
        assertEq(out_[detfInfo.detfBindingIndex()], 0, "DETF slot");
        assertGt(IERC20(pair0).balanceOf(detfUser), before0, "pair basket");
    }

    function test_D25_5_ids1and2CannotClose() public {
        _firstBondOn(detf, _one(BOND_AMT), pair0);
        uint256[] memory minOut_ = _minOut();
        vm.expectRevert();
        detfInfo.closeBondMature(DETF_FEE_TO_BOND_NFT_ID, minOut_, detfUser, _dl());
        vm.expectRevert();
        detfInfo.closeBondMature(DETF_CREATOR_BOND_NFT_ID, minOut_, detfUser, _dl());
    }

    function test_D25_6_previewEqualsExecute() public {
        uint256 tokenId = _liveThenLater();
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        uint256[] memory preview_ = detfInfo.previewCloseBondMature(tokenId);
        vm.prank(detfUser);
        uint256[] memory out_ = detfInfo.closeBondMature(tokenId, _minOut(), detfUser, _dl());
        assertEq(out_.length, preview_.length);
        for (uint256 i; i < out_.length; ++i) {
            assertApproxEqAbs(out_[i], preview_[i], 1);
        }
    }

    function test_D25_7_onlyUserBondClose_minRejoinLpOutGt0() public {
        (uint256 tokenId,) = _firstBondOn(detf, _one(BOND_AMT), pair0);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        IDETFNFTVault nft_ = _bondNftVault(detf);
        uint256 id0Before_ = nft_.originalSharesOf(nft_.detfNFTId());
        vm.prank(detfUser);
        detfInfo.closeBondMature(tokenId, _minOut(), detfUser, _dl());
        assertGt(nft_.originalSharesOf(nft_.detfNFTId()), id0Before_, "D25-7");
    }

    function test_D25_lastClose_feeCreatorPendingDoesNotJump() public {
        (uint256 tokenId,) = _firstBondOn(detf, _one(BOND_AMT), pair0);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        IDETFNFTVault nft_ = _bondNftVault(detf);
        uint256 feePending_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 creatorPending_ = nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID);
        vm.prank(detfUser);
        detfInfo.closeBondMature(tokenId, _minOut(), detfUser, _dl());
        assertLe(nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID), feePending_ + 1, "feeTo pending");
        assertLe(nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID), creatorPending_ + 1, "creator pending");
    }

    function _one(uint256 amt_) internal pure returns (uint256[] memory amts_) {
        amts_ = new uint256[](1);
        amts_[0] = amt_;
    }
}