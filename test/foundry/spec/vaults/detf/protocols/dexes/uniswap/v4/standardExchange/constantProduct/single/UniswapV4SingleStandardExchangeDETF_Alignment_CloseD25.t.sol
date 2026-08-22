// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeDETF,
    IUniswapV4SingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";

/// @notice D25: mature close rejoins DETF to id 0 and pays the non-DETF basket.
contract UniswapV4SingleStandardExchangeDETF_Alignment_CloseD25 is
    TestBase_UniswapV4SingleStandardExchangeDETF
{
    address internal alice;
    address internal bob;

    function setUp() public override {
        super.setUp();
        alice = makeAddr("d25alice");
        bob = makeAddr("d25bob");
        IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args_ = _openArgs();
        args_.name = "D25 UniV4 CP";
        args_.symbol = "d25cp";
        detf = _deployDetfWired(args_);
        detfInfo = IUniswapV4SingleStandardExchangeDETF(detf);
        _setBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
    }

    function _nft() internal view returns (IDETFNFTVault) {
        return _bondNftVault(detf);
    }

    function _minOut() internal pure returns (uint256[] memory m) {
        m = new uint256[](2);
    }

    function test_D25_1_userDetfOnlyFromClaimRewards() public {
        _bootstrapViaFirstBond(alice, 40 ether);
        (uint256 bobId,) = _bootstrapViaFirstBond(bob, 20 ether);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        IDETFNFTVault nft_ = _nft();
        uint256 pending_ = nft_.pendingRewards(bobId);
        uint256 detfBefore_ = IERC20(detf).balanceOf(bob);
        vm.prank(bob);
        detfInfo.closeBondMature(bobId, _minOut(), bob, block.timestamp + 1 hours);
        assertApproxEqAbs(IERC20(detf).balanceOf(bob) - detfBefore_, pending_, 1, "D25-1 pending only");
    }

    function test_D25_2_withdrawnDetfNotBurned() public {
        _bootstrapViaFirstBond(alice, 40 ether);
        (uint256 bobId,) = _bootstrapViaFirstBond(bob, 20 ether);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        vm.prank(bob);
        detfInfo.closeBondMature(bobId, _minOut(), bob, block.timestamp + 1 hours);
        assertGe(IERC20(detf).totalSupply(), supplyBefore_, "D25-2 no burn of withdrawn DETF");
    }

    function test_D25_3_id0OriginalSharesRise() public {
        _bootstrapViaFirstBond(alice, 40 ether);
        (uint256 bobId,) = _bootstrapViaFirstBond(bob, 20 ether);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        IDETFNFTVault nft_ = _nft();
        uint256 id0Before_ = nft_.originalSharesOf(nft_.detfNFTId());
        vm.prank(bob);
        detfInfo.closeBondMature(bobId, _minOut(), bob, block.timestamp + 1 hours);
        assertGt(nft_.originalSharesOf(nft_.detfNFTId()), id0Before_, "D25-3 id 0 credited");
    }

    function test_D25_4_userReceivesNonDetfBasket() public {
        _bootstrapViaFirstBond(alice, 40 ether);
        (uint256 bobId,) = _bootstrapViaFirstBond(bob, 20 ether);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        uint256 pairBefore_ = pairToken.balanceOf(bob);
        vm.prank(bob);
        uint256[] memory out_ = detfInfo.closeBondMature(bobId, _minOut(), bob, block.timestamp + 1 hours);
        assertEq(out_[0], 0, "DETF slot 0");
        assertGt(out_[1], 0, "pair basket");
        assertEq(pairToken.balanceOf(bob) - pairBefore_, out_[1], "pair paid");
    }

    function test_D25_5_ids1and2CannotClose() public {
        _bootstrapViaFirstBond(alice, 20 ether);
        vm.expectRevert();
        detfInfo.closeBondMature(DETF_FEE_TO_BOND_NFT_ID, _minOut(), alice, block.timestamp + 1 hours);
        vm.expectRevert();
        detfInfo.closeBondMature(DETF_CREATOR_BOND_NFT_ID, _minOut(), alice, block.timestamp + 1 hours);
    }

    function test_D25_6_previewEqualsExecute() public {
        _bootstrapViaFirstBond(alice, 40 ether);
        (uint256 bobId,) = _bootstrapViaFirstBond(bob, 20 ether);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        uint256[] memory preview_ = detfInfo.previewCloseBondMature(bobId);
        vm.prank(bob);
        uint256[] memory out_ = detfInfo.closeBondMature(bobId, _minOut(), bob, block.timestamp + 1 hours);
        assertEq(out_.length, preview_.length);
        assertApproxEqAbs(out_[0], preview_[0], 1);
        assertApproxEqAbs(out_[1], preview_[1], 1);
    }

    function test_D25_7_onlyUserBondClose_minRejoinLpOutGt0() public {
        (uint256 aliceId,) = _bootstrapViaFirstBond(alice, 40 ether);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        IDETFNFTVault nft_ = _nft();
        uint256 id0Before_ = nft_.originalSharesOf(nft_.detfNFTId());
        vm.prank(alice);
        detfInfo.closeBondMature(aliceId, _minOut(), alice, block.timestamp + 1 hours);
        assertGt(nft_.originalSharesOf(nft_.detfNFTId()), id0Before_, "D25-7 MIN rejoin credited id 0");
    }

    function test_D25_lastClose_feeCreatorPendingDoesNotJump() public {
        (uint256 aliceId,) = _bootstrapViaFirstBond(alice, 40 ether);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        IDETFNFTVault nft_ = _nft();
        uint256 feePending_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 creatorPending_ = nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID);
        vm.prank(alice);
        detfInfo.closeBondMature(aliceId, _minOut(), alice, block.timestamp + 1 hours);
        assertLe(
            nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID),
            feePending_ + 1,
            "D25 leftover DETF must not extract to feeTo"
        );
        assertLe(
            nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID),
            creatorPending_ + 1,
            "D25 leftover DETF must not extract to creator"
        );
    }
}