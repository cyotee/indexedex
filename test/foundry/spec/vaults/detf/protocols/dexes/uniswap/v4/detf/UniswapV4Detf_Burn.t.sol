// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";

/// @notice T7.9 live burn: previewBurn == burn exec; DETF burned; leftover LP on NFT.
contract UniswapV4Detf_Burn is TestBase_UniswapV4Detf {
    function test_T7_9_liveBurn_previewEqExec_pair() public {
        _firstBond(100 ether);
        vm.startPrank(detfUser);
        uint256 minted = detfInfo.mint(
            IERC20(address(pairToken)),
            20 ether,
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(minted, 0, "need DETF to burn");

        uint256 burnIn = minted / 2;
        require(burnIn > 0, "burnIn");
        uint256 preview = detfInfo.previewBurn(burnIn, IERC20(address(pairToken)));
        assertGt(preview, 0, "preview pair out");

        uint256 pairBefore = IERC20(address(pairToken)).balanceOf(detfUser);
        uint256 supplyBefore = IERC20(detf).totalSupply();
        uint256 nftLpBefore = IERC20(reserveHook).balanceOf(detfInfo.bondNftVault());

        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, burnIn);
        uint256 amountOut = detfInfo.burn(
            burnIn,
            IERC20(address(pairToken)),
            0,
            detfUser,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertEq(amountOut, preview, "previewBurn == burn exec");
        assertEq(IERC20(address(pairToken)).balanceOf(detfUser) - pairBefore, amountOut, "pair received");
        assertEq(IERC20(detf).totalSupply(), supplyBefore - burnIn, "DETF burned");
        assertEq(IERC20(reserveHook).balanceOf(detf), 0, "leftover LP not on diamond");
        assertGt(IERC20(reserveHook).balanceOf(detfInfo.bondNftVault()), 0, "LP still on NFT");
        nftLpBefore;
        _assertNoJoinableDust();
    }

    function test_T7_9_previewExitProp_is_not_withdrawSingle() public {
        _firstBond(80 ether);
        vm.startPrank(detfUser);
        uint256 minted = detfInfo.mint(
            IERC20(address(pairToken)),
            15 ether,
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        uint256 burnIn = minted / 3;
        uint256 lpOut = (burnIn * IERC20(reserveHook).balanceOf(detfInfo.bondNftVault()))
            / IERC20(detf).totalSupply();
        uint256[] memory prop = IUniswapV4SeBufferHook(reserveHook).previewExitProportional(lpOut);
        address[] memory toks = IUniswapV4SeBufferHook(reserveHook).tokens();
        uint256 pairProp;
        for (uint256 i; i < toks.length; ++i) {
            if (toks[i] == address(pairToken)) pairProp = prop[i];
        }
        uint256 preview = detfInfo.previewBurn(burnIn, IERC20(address(pairToken)));
        assertEq(preview, pairProp, "quote is prop pair residual, not single-asset withdraw");
    }
}
