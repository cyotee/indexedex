// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";

/// @notice T7.19 / T7.20 R19 diamond dust sweep.
contract UniswapV4Detf_Dust is TestBase_UniswapV4Detf {
    function test_T7_19_afterMint_diamondHasNoJoinableBalances() public {
        _firstBond(80 ether);
        vm.startPrank(detfUser);
        detfInfo.mint(
            IERC20(address(pairToken)),
            10 ether,
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        _assertNoJoinableDust();
        assertEq(IERC20(reserveHook).balanceOf(detfInfo.rebasingClaimToken()), 0, "no LP on claim");
    }

    function test_T7_20_sweepDust_joinsPairDust_unassignedLp() public {
        (uint256 tokenId,) = _firstBond(80 ether);
        IDETFNFTVault nft = IDETFNFTVault(detfInfo.bondNftVault());
        uint256 origBefore = nft.originalSharesOf(tokenId);
        uint256 assetsBefore = nft.convertToAssets(origBefore);
        uint256 nftLpBefore = IERC20(reserveHook).balanceOf(address(nft));
        uint256 o = nft.totalOriginalShares();
        assertGt(o, 0, "O>0");

        pairToken.mint(detf, 5 ether);
        assertGt(IERC20(address(pairToken)).balanceOf(detf), 0, "dust parked");

        detfInfo.sweepDust();

        assertEq(IERC20(address(pairToken)).balanceOf(detf), 0, "pair dust joined");
        uint256 nftLpAfter = IERC20(reserveHook).balanceOf(address(nft));
        assertGt(nftLpAfter, nftLpBefore, "NFT LP up");
        assertEq(nft.originalSharesOf(tokenId), origBefore, "no originalShares mint");
        uint256 assetsAfter = nft.convertToAssets(origBefore);
        assertGt(assetsAfter, assetsBefore, "convertToAssets rises");
        _assertNoJoinableDust();
    }

    function test_T7_20_afterBond_noJoinableDust() public {
        _firstBond(50 ether);
        _assertNoJoinableDust();
    }
}
