// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {
    TestBase_UniswapV4StandardExchangeWeightedBufferHook as TestBase
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookTarget as Target
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";

/**
 * @title UniswapV4StandardExchangeWeightedBufferHook_SeBufferAbi
 * @notice Stage 03 T3.1–T3.8: shared SE buffer ABI on the weighted buffer hook.
 */
contract UniswapV4StandardExchangeWeightedBufferHook_SeBufferAbi is TestBase {
    function test_T3_1_addressSetsDisjoint_nonDetfHasSe() public view {
        address[] memory t = weighted.tokens();
        assertEq(t.length, 2, "T3.1 n");
        assertEq(t[0], address(token0), "T3.1 token0");
        assertEq(t[1], address(token1), "T3.1 token1 detf analog");
        assertEq(weighted.standardExchangeOf(address(token0)), se0, "T3.1 se of pair");
        assertEq(weighted.standardExchangeOf(address(token1)), address(0), "T3.1 detf has no se");
        assertEq(weighted.standardExchangeOf(se0), address(0), "T3.1 se not a pair");
        assertTrue(se0 != address(token0), "T3.1 disjoint");
    }

    function test_T3_2_firstJoinMustBeFullBook_singleBeforeLiveReverts() public {
        assertTrue(weighted.firstJoinMustBeFullBook(), "T3.2 flag");
        address[] memory req = weighted.requiredFirstBondTokens();
        assertEq(req.length, weighted.tokens().length, "T3.2 required = tokens");
        assertFalse(weighted.isLive(), "pre-live");
        vm.prank(user);
        vm.expectRevert();
        weighted.joinSingleAssetExactIn(address(token0), 10 ether, user, 0, block.timestamp + 1 hours);

        address[] memory ts = new address[](1);
        ts[0] = address(token0);
        uint256[] memory am = new uint256[](1);
        am[0] = 10 ether;
        vm.prank(user);
        vm.expectRevert(Target.FirstJoinMustBeFullBook.selector);
        weighted.joinUnbalanced(ts, am, user, 0, block.timestamp + 1 hours);
    }

    function test_T3_3_afterLive_joinSingleAsset_pairAndShare() public {
        _joinFullBook(80 ether, 80 ether);
        assertTrue(weighted.isLive(), "live");
        vm.prank(user);
        uint256 lpPair = weighted.joinSingleAssetExactIn(
            address(token0), 5 ether, user, 0, block.timestamp + 1 hours
        );
        assertGt(lpPair, 0, "T3.3 pair");

        uint256 seShares = _userAcquireSeShares(se0, token0, 20 ether);
        vm.prank(user);
        uint256 lpSe = weighted.joinSingleAssetExactIn(se0, seShares, user, 0, block.timestamp + 1 hours);
        assertGt(lpSe, 0, "T3.3 share");
    }

    function test_T3_4_joinUnbalanced_pairAndShare_reverts() public {
        _joinFullBook(40 ether, 40 ether);
        uint256 seShares = _userAcquireSeShares(se0, token0, 5 ether);
        address[] memory ts = new address[](3);
        ts[0] = address(token1);
        ts[1] = address(token0);
        ts[2] = se0;
        uint256[] memory am = new uint256[](3);
        am[0] = 1 ether;
        am[1] = 1 ether;
        am[2] = seShares;
        vm.prank(user);
        vm.expectRevert(Target.PairAndShareSameLeg.selector);
        weighted.joinUnbalanced(ts, am, user, 0, block.timestamp + 1 hours);
    }

    function test_T3_5_previewSynthetic_eachPair() public {
        _joinFullBook(100 ether, 100 ether);
        IDetfReserveQuote.DetfQuoteCtx memory ctx = IDetfReserveQuote.DetfQuoteCtx({
            detfTotalSupply: 1e18,
            pendingExpansion: 0,
            ownedLp: IERC20(hook).balanceOf(user) / 2,
            creationPairPerDetfWad: 1e18
        });
        address[] memory nums = weighted.syntheticNumeraires();
        assertEq(nums.length, 1, "T3.5 one pair");
        assertEq(nums[0], address(token0), "T3.5 pair0");
        uint256 s = weighted.previewSynthetic(ctx, address(token0));
        assertGt(s, 0, "T3.5 synthetic");
    }

    function test_T3_6_previewBurnToToken_h10() public {
        uint256 lp = _joinFullBook(60 ether, 60 ether);
        uint256 half = lp / 2;
        uint256 preview = weighted.previewBurnToToken(half, address(token0));
        assertGt(preview, 0, "T3.6 preview");
        uint256[] memory mins = new uint256[](2);
        vm.prank(user);
        uint256[] memory got =
            weighted.exitProportional(half, user, mins, block.timestamp + 1 hours);
        assertEq(got[0], preview, "T3.6 prop residual == preview (H10 not exitSingle)");
    }

    function test_T3_7_requiredSurface_onLoupe() public view {
        IDiamondLoupe loupe = IDiamondLoupe(hook);
        assertTrue(
            loupe.facetAddress(IUniswapV4SeBufferHook.joinUnbalanced.selector) != address(0),
            "joinUnbalanced(addr[])"
        );
        assertTrue(
            loupe.facetAddress(IUniswapV4SeBufferHook.previewSwapExactIn.selector) != address(0),
            "previewSwapExactIn"
        );
        assertTrue(loupe.facetAddress(IUniswapV4SeBufferHook.tokens.selector) != address(0), "tokens");
        assertTrue(loupe.facetAddress(IUniswapV4SeBufferHook.isLive.selector) != address(0), "isLive");
        assertTrue(
            loupe.facetAddress(IUniswapV4SeBufferHook.firstJoinMustBeFullBook.selector) != address(0),
            "firstJoinMustBeFullBook"
        );
        assertTrue(
            loupe.facetAddress(IDetfReserveQuote.previewBurnToToken.selector) != address(0),
            "previewBurnToToken"
        );
        assertTrue(
            loupe.facetAddress(IDetfReserveQuote.previewSynthetic.selector) != address(0),
            "previewSynthetic"
        );
    }

    function test_T3_8_registryDeploy_noNewPkg() public view {
        assertTrue(hook != address(0), "hook");
        assertTrue(address(hookPkg) != address(0), "pkg");
        assertTrue(IDiamondLoupe(hook).facetAddresses().length > 0, "diamond");
    }

    function test_T3_emptyBook_previewSynthetic_isZero() public view {
        IDetfReserveQuote.DetfQuoteCtx memory ctx = IDetfReserveQuote.DetfQuoteCtx({
            detfTotalSupply: 1e18,
            pendingExpansion: 0,
            ownedLp: 1e18,
            creationPairPerDetfWad: 1e18
        });
        assertEq(weighted.previewSynthetic(ctx, address(token0)), 0, "empty synthetic");
        assertEq(weighted.previewBurnToToken(1 ether, address(token0)), 0, "empty burn");
    }

    function test_T3_unknownToken_join_reverts() public {
        address[] memory ts = new address[](2);
        ts[0] = address(token1);
        ts[1] = address(0xB0B);
        uint256[] memory am = new uint256[](2);
        am[0] = 1 ether;
        am[1] = 1 ether;
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStandardExchangeErrors.InvalidRoute.selector, address(0xB0B), address(0)
            )
        );
        weighted.joinUnbalanced(ts, am, user, 0, block.timestamp + 1 hours);
    }

    function _joinFullBook(uint256 pairAmt, uint256 detfAmt) internal returns (uint256 lp) {
        address[] memory ts = new address[](2);
        ts[0] = address(token0);
        ts[1] = address(token1);
        uint256[] memory am = new uint256[](2);
        am[0] = pairAmt;
        am[1] = detfAmt;
        vm.prank(user);
        lp = weighted.joinUnbalanced(ts, am, user, 0, block.timestamp + 1 hours);
    }
}
