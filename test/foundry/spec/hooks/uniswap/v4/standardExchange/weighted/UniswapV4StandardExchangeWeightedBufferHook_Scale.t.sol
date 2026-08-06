// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {
    MintableERC20Decimals
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/MintableERC20Decimals.sol";

/**
 * @notice H15 dual-scale FIX + live SE book donations dilute.
 */
contract UniswapV4StandardExchangeWeightedBufferHook_Scale is
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
{
    function test_dualScale_invVsRated() public view {
        uint256 inv0 = weighted.invScale(0);
        uint256 rated0 = weighted.ratedScale(0);
        assertGt(inv0, 0);
        assertGt(rated0, 0);
        assertEq(weighted.invScale(1), weighted.ratedScale(1));
    }

    /// @notice FIX-mixed: real 6-decimal raw leg + 18-decimal SE leg; scales differ; first mint works.
    function test_FIX_mixedDecimals_6and18() public {
        MintableERC20Decimals t6 = new MintableERC20Decimals("Six", "SIX", 6);
        SimpleMintableERC20 t18 = new SimpleMintableERC20("Eighteen", "E18");
        // SE wraps 18-dec SimpleMintable (SimpleYieldERC4626 requires SimpleMintableERC20)
        SimpleYieldERC4626 vault18 = new SimpleYieldERC4626(t18);
        address se18 = _deployERC4626SE(address(vault18));

        address a6 = address(t6);
        address a18 = address(t18);
        address[] memory toks = new address[](2);
        uint256[] memory w = new uint256[](2);
        address[] memory ses = new address[](2);
        address[] memory rps = new address[](2);
        w[0] = 0.5e18;
        w[1] = 0.5e18;

        uint8 i6;
        uint8 i18;
        if (a6 < a18) {
            toks[0] = a6;
            toks[1] = a18;
            ses[0] = address(0); // raw 6-dec
            ses[1] = se18; // SE on 18-dec
            i6 = 0;
            i18 = 1;
        } else {
            toks[0] = a18;
            toks[1] = a6;
            ses[0] = se18;
            ses[1] = address(0);
            i18 = 0;
            i6 = 1;
        }

        _deployHookWithArgs(_pkgArgs(toks, w, ses, rps));

        t6.mint(user, 1_000_000e6);
        t18.mint(user, 1_000_000 ether);
        vm.startPrank(user);
        t6.approve(hook, type(uint256).max);
        t18.approve(hook, type(uint256).max);
        vm.stopPrank();

        // ratedScale = 10^(36 - pairDecimals)
        assertEq(weighted.ratedScale(i6), 10 ** uint256(36 - 6), "ratedScale 6dec");
        assertEq(weighted.ratedScale(i18), 10 ** uint256(36 - 18), "ratedScale 18dec");
        // Raw 6-dec: invScale == ratedScale; SE leg invScale from share decimals (18)
        assertEq(weighted.invScale(i6), weighted.ratedScale(i6), "raw inv==rated");
        assertEq(weighted.invScale(i18), 10 ** uint256(36 - 18), "SE inv share scale");
        assertTrue(weighted.ratedScale(i6) != weighted.ratedScale(i18), "cross-leg scales differ");

        uint256[] memory amounts = new uint256[](2);
        amounts[i6] = 100_000e6;
        amounts[i18] = 100 ether;
        vm.prank(user);
        (uint256 shares,) = weighted.joinProportional(amounts, user, 0, block.timestamp + 1 hours);
        assertGt(shares, 0, "first mint mixed decimals");
        assertTrue(weighted.isFullBook());
        assertGt(weighted.nativeReserve(i6), 0);
        assertGt(weighted.nativeReserve(i18), 0);
    }

    function test_liveSeBook_donationDilutes() public {
        _firstMintEqual(50 ether);
        uint256 bookBefore = weighted.nativeReserve(0);
        uint256 seBalBefore = weighted.seBalance(0);
        assertEq(bookBefore, seBalBefore);
        assertGt(bookBefore, 0);

        uint256 amountIn = 10 ether;
        token0.mint(user, amountIn);
        vm.startPrank(user);
        token0.approve(se0, type(uint256).max);
        uint256 seOut = IStandardExchangeIn(se0).exchangeIn(
            IERC20(address(token0)), amountIn, IERC20(se0), 0, user, false, block.timestamp + 1 hours
        );
        assertGt(seOut, 0, "minted SE shares");
        IERC20(se0).transfer(hook, seOut);
        vm.stopPrank();

        uint256 bookAfter = weighted.nativeReserve(0);
        assertEq(bookAfter, weighted.seBalance(0), "book == live SE bal");
        assertEq(bookAfter, seBalBefore + seOut, "donation increased live book");
        assertGt(bookAfter, bookBefore, "dilution: book rose without LP mint");

        uint256 bookMid = weighted.nativeReserve(0);
        token0.mint(hook, 5);
        assertEq(weighted.nativeReserve(0), bookMid, "face dust not book");
        assertEq(weighted.nativeReserve(0), weighted.seBalance(0), "still SE shares");
    }

    function test_reserveOfToken_matchesNativeBook() public {
        _firstMintEqual(25 ether);
        assertEq(_reserveOf(address(token0)), weighted.nativeReserve(0));
        assertEq(_reserveOf(address(token1)), weighted.nativeReserve(1));
        assertEq(_reserveOf(address(token0)), weighted.seBalance(0));
        assertEq(token1.balanceOf(hook), weighted.nativeReserve(1));
    }
}
