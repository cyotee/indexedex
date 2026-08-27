// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";

/// @notice T7.6 live mint Gross quote + D11 no DETF into reserve.
contract UniswapV4Detf_Mint is TestBase_UniswapV4Detf {
    uint256 internal constant ONE_WAD = 1e18;

    function test_T7_6_liveMint_grossSwapQuote_d11() public {
        _firstBond(100 ether);
        uint256 mintIn = 10 ether;
        (uint256 grossPred, uint256 userPred, uint256 lpPred) =
            detfInfo.previewMint(IERC20(address(pairToken)), mintIn);
        assertGt(grossPred, 0, "gross");
        assertGt(userPred, 0, "user");
        assertGt(lpPred, 0, "lp preview");

        uint256 p = IVaultFeeOracleQuery(address(indexedexManager)).seigniorageIncentivePercentageOfVault(detf);
        uint256 boosted = Math.mulDiv(mintIn, ONE_WAD + p, ONE_WAD);
        uint256 swapQuote = IUniswapV4SeBufferHook(reserveHook).previewSwapExactIn(
            address(pairToken), detf, boosted
        );
        assertEq(grossPred, swapQuote, "Gross = previewSwapExactIn(pair, detf, pairEq*(1+p))");

        uint256 detfBefore = IERC20(detf).balanceOf(detfUser);
        uint256 nftLpBefore = IERC20(reserveHook).balanceOf(detfInfo.bondNftVault());
        uint256 supplyBefore = IERC20(detf).totalSupply();
        vm.startPrank(detfUser);
        uint256 userDetf = detfInfo.mint(
            IERC20(address(pairToken)),
            mintIn,
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(userDetf, userPred, "preview==exec user");
        assertEq(IERC20(detf).balanceOf(detfUser) - detfBefore, userDetf, "user DETF");
        uint256 nftLpDelta = IERC20(reserveHook).balanceOf(detfInfo.bondNftVault()) - nftLpBefore;
        assertGt(nftLpDelta, 0, "LP joined");
        assertGe(nftLpDelta, lpPred, "LP delta >= join preview");
        // D11: Gross is minted to the user/pot, not joined as DETF self-leg.
        assertEq(IERC20(detf).balanceOf(detfUser) - detfBefore, userPred, "D11 user Gross split");
        assertGe(IERC20(detf).totalSupply(), supplyBefore + userDetf, "D11 supply rose by minted Gross split");
        _assertNoJoinableDust();
    }
}
