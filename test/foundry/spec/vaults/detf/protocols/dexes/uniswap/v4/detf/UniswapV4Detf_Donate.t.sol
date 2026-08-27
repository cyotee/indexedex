// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";

/// @notice T7.13 R12a: live donate when O>0 does not mint originalShares; convertToAssets rises.
contract UniswapV4Detf_Donate is TestBase_UniswapV4Detf {
    function test_T7_13_donatePair_Ogt0_unassignedLp() public {
        (uint256 tokenId,) = _firstBond(80 ether);
        IDETFNFTVault nft = IDETFNFTVault(detfInfo.bondNftVault());
        uint256 origBefore = nft.originalSharesOf(tokenId);
        uint256 assetsBefore = nft.convertToAssets(origBefore);
        uint256 o = nft.totalOriginalShares();
        assertGt(o, 0, "O>0");

        uint256 donateIn = 8 ether;
        pairToken.mint(detfUser, donateIn);
        vm.startPrank(detfUser);
        IERC20(address(pairToken)).approve(address(nft), donateIn);
        uint256 lpOut = IDetfNftReserveDonation(address(nft)).donate(
            IERC20(address(pairToken)),
            donateIn,
            0,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertGt(lpOut, 0, "joined LP");
        assertEq(nft.originalSharesOf(tokenId), origBefore, "no originalShares mint");
        assertEq(nft.totalOriginalShares(), o, "O unchanged");
        uint256 assetsAfter = nft.convertToAssets(origBefore);
        assertGt(assetsAfter, assetsBefore, "convertToAssets rises");
        _assertNoJoinableDust();
    }
}
