// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {
    TestBase_UniswapV4StandardExchangeWeightedBufferHook_Decimals
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook_Decimals.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {HostileReentrantERC20_Decimals} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/decimals/UniswapV4StandardExchangeWeightedBufferHook_N2_Decimals.sol";

/**
 * @title UniswapV4StandardExchangeWeightedBufferHook_NLeg_Decimals
 * @notice n=3 live join/swap plus n=4 live book on each `B_*`. After address sort slots permute;
 *      `_bookDec(0)` is pairToken at construction. Hook LP stays 18.
 */
abstract contract UniswapV4StandardExchangeWeightedBufferHook_NLeg_Decimals is
    TestBase_UniswapV4StandardExchangeWeightedBufferHook_Decimals
{
    function test_partialFirstMint_twoLegs_n3() public {
        _deployNn(3);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = _u(0, 100);
        amounts[1] = _u(1, 100);
        amounts[2] = 0;

        (uint256 preview,) = weighted.previewJoinProportional(amounts);
        vm.prank(user);
        (uint256 shares,) = weighted.joinProportional(amounts, user, 0, block.timestamp + 1 hours);
        assertEq(shares, preview);
        assertGt(shares, 0);
        assertEq(IERC20(hook).totalSupply(), shares + 1000);
        assertFalse(weighted.isFullBook(), "partial");
        assertGt(weighted.nativeReserve(0), 0);
        assertGt(weighted.nativeReserve(1), 0);
        assertEq(weighted.nativeReserve(2), 0);
    }

    function test_firstMint_fullBook_mintsVminusMin() public {
        _deployNn(3);
        uint256 shares = _firstMintEqualHuman(1000);
        assertGt(shares, 0);
        assertEq(IERC20(hook).balanceOf(user), shares);
        assertEq(IERC20(hook).balanceOf(address(0)), 1000);
        assertTrue(weighted.isFullBook());
        assertGt(weighted.nativeReserve(0), 0);
        assertGt(weighted.nativeReserve(1), 0);
        assertGt(weighted.nativeReserve(2), 0);
        assertEq(
            weighted.nativeReserve(0),
            weighted.isBuffered(0) ? weighted.seBalance(0) : token0.balanceOf(hook)
        );
        assertEq(
            weighted.nativeReserve(1),
            weighted.isBuffered(1) ? weighted.seBalance(1) : token1.balanceOf(hook)
        );
        assertEq(
            weighted.nativeReserve(2),
            weighted.isBuffered(2) ? weighted.seBalance(2) : token2.balanceOf(hook)
        );
    }

    function test_firstMint_fullBook_inventoryBook() public {
        MintableERC20Decimals[] memory toks;
        (, toks) = _deployNn(3);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = _raw(toks[0], 100);
        amounts[1] = _raw(toks[1], 100);
        amounts[2] = _raw(toks[2], 100);

        (uint256 previewShares, uint256[] memory previewUsed) = weighted.previewJoinProportional(amounts);
        vm.prank(user);
        (uint256 shares, uint256[] memory used) =
            weighted.joinProportional(amounts, user, 0, block.timestamp + 1 hours);

        assertEq(shares, previewShares, "preview==exec shares");
        for (uint256 i; i < 3; ++i) assertEq(used[i], previewUsed[i]);
        assertGt(shares, 0);
        assertEq(IERC20(hook).balanceOf(user), shares);
        assertEq(IERC20(hook).totalSupply(), shares + 1000);
        assertEq(weighted.nativeReserve(0), weighted.seBalance(0), "live SE shares");
        assertEq(weighted.nativeReserve(1), amounts[1], "raw face book 1");
        assertEq(weighted.nativeReserve(2), amounts[2], "raw face book 2");
        assertTrue(weighted.isFullBook());
    }

    function test_joinProportional_previewEqualsExecution() public {
        _deployNn(3);
        _firstMintEqualHuman(1000);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = _u(0, 100);
        amounts[1] = _u(1, 100);
        amounts[2] = _u(2, 100);
        (uint256 prevShares, uint256[] memory prevUsed) = weighted.previewJoinProportional(amounts);
        vm.prank(user);
        (uint256 shares, uint256[] memory used) =
            weighted.joinProportional(amounts, user, 0, block.timestamp + 1);
        assertEq(shares, prevShares);
        for (uint256 i; i < 3; ++i) assertEq(used[i], prevUsed[i]);
    }

    function test_joinUnbalanced_previewEqualsExec() public {
        _deployNn(3);
        _firstMintEqualHuman(200);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = _u(0, 10);
        amounts[1] = _u(1, 30);
        amounts[2] = _u(2, 5);
        uint256 preview = weighted.previewJoinUnbalanced(amounts);
        assertGt(preview, 0);

        uint256 lpBefore = IERC20(hook).balanceOf(user);
        vm.prank(user);
        uint256 shares = weighted.joinUnbalanced(amounts, user, 0, block.timestamp + 1 hours);
        assertEq(shares, preview, "unbalanced preview==exec");
        assertEq(IERC20(hook).balanceOf(user) - lpBefore, shares);
    }

    function test_exitProportional_previewEqualsExec() public {
        _deployNn(3);
        uint256 mintShares = _firstMintEqualHuman(100);
        uint256 burn = mintShares / 4;
        uint256[] memory preview = weighted.previewExitProportional(burn);
        uint256[] memory mins = new uint256[](3);

        uint256 bal0 = token0.balanceOf(user);
        uint256 bal1 = token1.balanceOf(user);
        uint256 bal2 = token2.balanceOf(user);
        vm.prank(user);
        uint256[] memory got =
            weighted.exitProportional(burn, user, mins, block.timestamp + 1 hours);
        assertEq(got[0], preview[0]);
        assertEq(got[1], preview[1]);
        assertEq(got[2], preview[2]);
        assertEq(token0.balanceOf(user) - bal0, got[0]);
        assertEq(token1.balanceOf(user) - bal1, got[1]);
        assertEq(token2.balanceOf(user) - bal2, got[2]);
    }

    function test_swapExactIn_v4Door_afterFirstMint() public {
        _deployNn(3);
        _firstMintEqualHuman(100);
        uint256 amountIn = _u(0, 1);
        uint256 preview = weighted.previewSwapExactIn(address(token0), address(token1), amountIn);
        assertGt(preview, 0, "preview out");

        uint256 bal1Before = token1.balanceOf(user);
        uint256 seBefore = weighted.seBalance(0);
        _swapExactIn(address(token0), address(token1), amountIn);
        uint256 got = token1.balanceOf(user) - bal1Before;
        assertGt(got, 0, "swap delivered");
        assertApproxEqAbs(got, preview, _weiSlack(preview), "swap out ~ preview");
        assertGt(weighted.seBalance(0), seBefore, "gross SE buffer on tokenIn");
    }

    function test_swapExactOut_previewAndSeExec() public {
        _deployNn(3);
        _firstMintEqualHuman(500);
        uint256 amountOut = _u(1, 1) / 10;
        if (amountOut == 0) amountOut = 1;
        uint256 previewInV4 = weighted.previewSwapExactOut(address(token0), address(token1), amountOut);
        assertGt(previewInV4, 0, "V4 exact-out quote");

        uint256 previewIn = IStandardExchangeOut(hook).previewExchangeOut(
            IERC20(address(token0)), IERC20(address(token1)), amountOut
        );
        assertGt(previewIn, 0);
        assertApproxEqAbs(previewIn, previewInV4, previewInV4 / 100 + 10, "SE vs V4 quote");

        uint256 bal0Before = token0.balanceOf(user);
        uint256 bal1Before = token1.balanceOf(user);
        vm.prank(user);
        uint256 spent = IStandardExchangeOut(hook).exchangeOut(
            IERC20(address(token0)),
            type(uint256).max,
            IERC20(address(token1)),
            amountOut,
            user,
            false,
            block.timestamp + 1 hours
        );
        assertEq(spent, previewIn, "exact-out exec==preview");
        assertEq(bal0Before - token0.balanceOf(user), spent);
        assertEq(token1.balanceOf(user) - bal1Before, amountOut);
    }

    function test_seExchangeIn_previewEqualsExec() public {
        _deployNn(3);
        _firstMintEqualHuman(100);
        uint256 amountIn = _u(1, 1);
        uint256 preview =
            weighted.previewSwapExactIn(address(token1), address(token0), amountIn);
        assertGt(preview, 0);

        uint256 bal0 = token0.balanceOf(user);
        vm.prank(user);
        uint256 out = IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(token1)),
            amountIn,
            IERC20(address(token0)),
            0,
            user,
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, preview, "SE In preview==exec");
        assertEq(token0.balanceOf(user) - bal0, out);
    }

    function test_seExchangeOut_previewEqualsExec() public {
        _deployNn(3);
        _firstMintEqualHuman(200);
        uint256 amountOut = _u(0, 1) / 4;
        if (amountOut == 0) amountOut = 1;
        uint256 previewIn = IStandardExchangeOut(hook).previewExchangeOut(
            IERC20(address(token1)), IERC20(address(token0)), amountOut
        );
        assertGt(previewIn, 0);

        uint256 bal1 = token1.balanceOf(user);
        uint256 bal0 = token0.balanceOf(user);
        vm.prank(user);
        uint256 spent = IStandardExchangeOut(hook).exchangeOut(
            IERC20(address(token1)),
            type(uint256).max,
            IERC20(address(token0)),
            amountOut,
            user,
            false,
            block.timestamp + 1 hours
        );
        assertEq(spent, previewIn, "SE Out preview==exec");
        assertEq(bal1 - token1.balanceOf(user), spent);
        assertEq(token0.balanceOf(user) - bal0, amountOut);
    }

    /// @notice Mixed-scale first mint on this book's actual decimals. Includes B_P9_* and B_P18_R6.
    function test_FIX_mixedDecimals_6and18() public {
        MintableERC20Decimals[] memory toks;
        (, toks) = _deployNn(3);
        for (uint256 i; i < 3; ++i) {
            uint8 d = toks[i].decimals();
            assertEq(weighted.ratedScale(i), 10 ** uint256(36 - d), "ratedScale");
            if (weighted.isBuffered(i)) {
                assertEq(weighted.invScale(i), 10 ** uint256(36 - 18), "SE inv share scale");
            } else {
                assertEq(weighted.invScale(i), weighted.ratedScale(i), "raw inv==rated");
            }
        }
        uint256 shares = _firstMintEqualHuman(100);
        assertGt(shares, 0, "first mint mixed decimals");
        assertTrue(weighted.isFullBook());
        for (uint256 i; i < 3; ++i) assertGt(weighted.nativeReserve(i), 0);
    }

    function test_liveSeBook_donationDilutes() public {
        _deployNn(3);
        _firstMintEqualHuman(50);
        uint256 bookBefore = weighted.nativeReserve(0);
        uint256 seBalBefore = weighted.seBalance(0);
        assertEq(bookBefore, seBalBefore);
        assertGt(bookBefore, 0);

        uint256 amountIn = _u(0, 10);
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

    function test_firstMint_fullBook_mintsVminusMin_n4() public {
        MintableERC20Decimals[] memory toks;
        (, toks) = _deployNn(4);
        uint256 shares = _joinFull(toks, 1000);
        assertGt(shares, 0);
        assertEq(IERC20(hook).balanceOf(address(0)), 1000);
        assertTrue(weighted.isFullBook());
        _assertAllDoorsLive();
        for (uint256 i; i < 4; ++i) {
            assertGt(weighted.nativeReserve(i), 0);
            assertEq(weighted.nativeReserve(i), weighted.seBalance(i));
        }
    }

    function test_joinProportional_previewEqualsExecution_n4() public {
        MintableERC20Decimals[] memory toks;
        (, toks) = _deployNn(4);
        _joinFull(toks, 1000);
        uint256[] memory amounts = new uint256[](4);
        for (uint256 i; i < 4; ++i) amounts[i] = _raw(toks[i], 100);
        (uint256 prevShares, uint256[] memory prevUsed) = weighted.previewJoinProportional(amounts);
        vm.prank(user);
        (uint256 shares, uint256[] memory used) =
            weighted.joinProportional(amounts, user, 0, block.timestamp + 1);
        assertEq(shares, prevShares);
        for (uint256 i; i < 4; ++i) assertEq(used[i], prevUsed[i]);
    }

    function test_exitProportional_previewEqualsExec_n4() public {
        MintableERC20Decimals[] memory toks;
        (, toks) = _deployNn(4);
        uint256 mintShares = _joinFull(toks, 100);
        uint256 burn = mintShares / 4;
        uint256[] memory preview = weighted.previewExitProportional(burn);
        uint256[] memory mins = new uint256[](4);
        vm.prank(user);
        uint256[] memory got =
            weighted.exitProportional(burn, user, mins, block.timestamp + 1 hours);
        for (uint256 i; i < 4; ++i) assertEq(got[i], preview[i]);
    }

    function test_swapExactIn_v4Door_afterFirstMint_n4() public {
        MintableERC20Decimals[] memory toks;
        (, toks) = _deployNn(4);
        _joinFull(toks, 100);
        uint256 amountIn = _raw(toks[0], 1);
        uint256 preview = weighted.previewSwapExactIn(address(toks[0]), address(toks[1]), amountIn);
        assertGt(preview, 0);
        uint256 bal1Before = toks[1].balanceOf(user);
        _swapExactIn(address(toks[0]), address(toks[1]), amountIn);
        uint256 got = toks[1].balanceOf(user) - bal1Before;
        assertGt(got, 0);
        assertApproxEqAbs(got, preview, _weiSlack(preview), "swap out ~ preview");
    }

    /// @notice C1: 18-dec hostile reenters join mid transferFrom; nested mutator fails; outer clean.
    function test_C1_reentrancy_join_hitsReentrancy() public {
        MintableERC20Decimals seToken = new MintableERC20Decimals("SEPair", "SEP", 18);
        HostileReentrantERC20_Decimals hostile = new HostileReentrantERC20_Decimals("Hostile", "HST");
        SimpleYieldERC4626 vault = new SimpleYieldERC4626(seToken);
        address se = _deployERC4626SE(address(vault));

        address a = address(seToken);
        address b = address(hostile);
        address[] memory toks = new address[](2);
        uint256[] memory w = new uint256[](2);
        address[] memory ses = new address[](2);
        address[] memory rps = new address[](2);
        w[0] = 0.5e18;
        w[1] = 0.5e18;
        if (a < b) {
            toks[0] = a;
            toks[1] = b;
            ses[0] = se;
            ses[1] = address(0);
        } else {
            toks[0] = b;
            toks[1] = a;
            ses[0] = address(0);
            ses[1] = se;
        }
        _deployHookWithArgs(_pkgArgs(toks, w, ses, rps));

        seToken.mint(user, 1_000_000 ether);
        hostile.mint(user, 1_000_000 ether);
        vm.startPrank(user);
        seToken.approve(hook, type(uint256).max);
        hostile.approve(hook, type(uint256).max);
        vm.stopPrank();

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100 ether;
        amounts[1] = 100 ether;
        vm.prank(user);
        (uint256 shares,) = weighted.joinProportional(amounts, user, 0, block.timestamp + 1 hours);
        assertGt(shares, 0);

        bytes memory reentry = abi.encodeWithSelector(
            IUniswapV4StandardExchangeWeightedBufferHook.depositSingle.selector,
            address(hostile),
            uint256(1 ether),
            user,
            uint256(0),
            block.timestamp + 1 hours
        );
        hostile.arm(hook, reentry);

        uint256 lpBefore = IERC20(hook).balanceOf(user);
        vm.prank(user);
        weighted.depositSingle(address(hostile), 10 ether, user, 0, block.timestamp + 1 hours);
        assertEq(hostile.reentryAttempts(), 1, "nested reentry attempted once");
        assertFalse(hostile.nestedCallSucceeded(), "nested depositSingle must not succeed");
        assertGe(IERC20(hook).balanceOf(user), lpBefore, "outer path continued after blocked reentry");
    }
}
