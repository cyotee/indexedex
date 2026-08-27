// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";

/// @notice T7.12 Default close: basket, no swaps; DETF min slot 0.
contract UniswapV4Detf_Close is TestBase_UniswapV4Detf {
    function test_T7_12_defaultClose_basket_pairOut() public {
        (uint256 tokenId, uint256 shares) = _firstBond(100 ether);
        assertGt(tokenId, 0, "tokenId");
        assertGt(shares, 0, "lp");
        // Leave unassigned LP on the NFT so the hook stays live after this bond's LP exits.
        vm.startPrank(detfUser);
        detfInfo.mint(
            IERC20(address(pairToken)),
            20 ether,
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        address[] memory toks = IUniswapV4SeBufferHook(reserveHook).tokens();
        assertEq(toks[0], detf, "DETF index 0");

        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        uint256[] memory minOut = new uint256[](toks.length);
        uint256 pairBefore = IERC20(address(pairToken)).balanceOf(detfUser);

        vm.prank(detfUser);
        uint256[] memory paid = detfInfo.closeBondMature(
            tokenId, minOut, detfUser, block.timestamp + 1 hours
        );

        assertEq(paid.length, toks.length, "tokens() order");
        assertEq(paid[0], 0, "DETF slot not paid to user");
        uint256 pairPaid;
        for (uint256 i; i < toks.length; ++i) {
            if (toks[i] == address(pairToken)) pairPaid = paid[i];
        }
        assertGt(pairPaid, 0, "pair basket leg");
        assertEq(
            IERC20(address(pairToken)).balanceOf(detfUser) - pairBefore,
            pairPaid,
            "user received pair"
        );
        IDETFNFTVault nft = IDETFNFTVault(detfInfo.bondNftVault());
        assertEq(nft.originalSharesOf(tokenId), 0, "position retired");
        _assertNoJoinableDust();
    }
}
