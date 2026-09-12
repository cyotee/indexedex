// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Quad} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad.sol";

/// @notice T8.3 Quad: first bond four legs; Custom close one pair.
contract UniswapV4Detf_Quad is TestBase_UniswapV4Detf_Quad {
    /// @notice Custom settlement must not swap unrelated pair inventory for a closing holder.
    function test_E6_customClose_doesNotSwapPriorPairInventory() public {
        IUniswapV4Detf info = IUniswapV4Detf(_deployQuadHookThenDetf(_fundedClaimArgs()));
        vm.startPrank(detfUser);
        pair0.approve(address(info), type(uint256).max);
        pair1.approve(address(info), type(uint256).max);
        pair2.approve(address(info), type(uint256).max);
        (uint256 tokenId,) = info.bond(
            IERC20(address(pair0)), 80 ether, DEFAULT_MIN_LOCK, detfUser,
            false, block.timestamp + 1 hours
        );
        info.bond(
            IERC20(address(pair1)), 40 ether, DEFAULT_MIN_LOCK, detfUser,
            false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        IDETFFundedRewards(address(info)).synchronizeRewards();
        IDetfBondNFT nft_ = IDetfBondNFT(info.bondNftVault());
        uint256 checkpoint_ = vm.snapshotState();
        vm.prank(detfUser);
        (uint256 cleanPrincipal_, uint256 cleanRewards_) = nft_.claimBond(tokenId, detfUser);
        assertTrue(vm.revertToState(checkpoint_));
        address donor_ = makeAddr("unrelatedQuadInventoryDonor");
        pair1.mint(donor_, 10 ether);
        vm.prank(donor_);
        pair1.transfer(address(info), 10 ether);
        IStakedDETF receipt_ = IStakedDETF(info.rebasingClaimToken());
        uint256 before_ = receipt_.balanceOf(detfUser);
        uint256 pairBefore_ = pair0.balanceOf(detfUser);
        uint256 lpBefore_ = IERC20(info.hook()).balanceOf(address(nft_));
        vm.prank(detfUser);
        (uint256 principal_, uint256 rewards_) = nft_.claimBond(tokenId, detfUser);
        assertEq(principal_, cleanPrincipal_, "unrelated reserve gift cannot inflate funded principal");
        assertEq(rewards_, cleanRewards_, "unallocated inventory is not staking income");
        assertEq(receipt_.balanceOf(detfUser) - before_, principal_ + rewards_, "only funded sDETF paid");
        assertEq(pair0.balanceOf(detfUser), pairBefore_, "no unrelated settlement payout");
        assertGe(pair1.balanceOf(address(info)), 10 ether, "gift retained by protocol");
        assertEq(IERC20(info.hook()).balanceOf(address(nft_)), lpBefore_, "protocol LP retained");
    }

    function test_T8_3_firstBond_fourLegs() public {
        address[] memory toks = IUniswapV4SeBufferHook(reserveHook).tokens();
        assertEq(toks.length, 4, "quad n=4");
        assertEq(detfInfo.creationPairPerDetfWad().length, 3, "n-1");
        (uint256 tokenId, uint256 shares) = _firstBond(100 ether);
        assertGt(tokenId, 0, "tokenId");
        assertGt(shares, 0, "lp");
        assertTrue(detfInfo.isReserveLive(), "live");
        _assertNoJoinableDust();
    }

    function test_T8_3_fundedClaim_retainsWholeReserve() public {
        IUniswapV4Detf.PkgArgs memory args = _fundedClaimArgs();
        address customDetf = _deployQuadHookThenDetf(args);
        IUniswapV4Detf info = IUniswapV4Detf(customDetf);

        vm.startPrank(detfUser);
        IERC20(address(pair0)).approve(customDetf, type(uint256).max);
        IERC20(address(pair1)).approve(customDetf, type(uint256).max);
        IERC20(address(pair2)).approve(customDetf, type(uint256).max);
        (uint256 tokenId, uint256 shares) = info.bond(
            IERC20(address(pair0)),
            80 ether,
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(info.isReserveLive(), "live");
        assertGt(tokenId, 0, "tokenId");
        assertGt(shares, 0, "lp");

        vm.startPrank(detfUser);
        info.bond(
            IERC20(address(pair1)),
            40 ether,
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        _assertFundedMatureClaim(customDetf, tokenId, detfUser);
    }
}
