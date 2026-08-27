// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookDepositTarget as DepositTarget
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositTarget.sol";

/**
 * @title UniswapV4SingleStandardExchangeBufferConstantProductHook_SeBufferAbi
 * @notice Stage 01 T1.1–T1.14: shared SE buffer ABI on the CP pathfinder hook.
 */
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_SeBufferAbi is TestBase {
    function test_T1_1_tokens_length2_rawAndPair() public view {
        address[] memory t = single.tokens();
        assertEq(t.length, 2, "T1.1 length");
        bool hasRaw = t[0] == address(rawToken) || t[1] == address(rawToken);
        bool hasPair = t[0] == address(pairToken) || t[1] == address(pairToken);
        assertTrue(hasRaw && hasPair, "T1.1 raw+pair");
    }

    function test_T1_2_standardExchangeOf_pair_disjointSets() public view {
        assertEq(single.standardExchangeOf(address(pairToken)), se, "T1.2 se of pair");
        assertEq(single.standardExchangeOf(address(rawToken)), address(0), "T1.2 raw has no se");
        assertTrue(single.standardExchangeOf(address(pairToken)) != address(pairToken), "T1.2 disjoint");
    }

    function test_T1_3_firstJoinMustBeFullBook() public view {
        assertTrue(single.firstJoinMustBeFullBook(), "T1.3");
    }

    function test_T1_4_joinSingleAssetExactIn_beforeLive_reverts() public {
        assertFalse(single.isLive(), "pre-live");
        vm.prank(user);
        vm.expectRevert();
        single.joinSingleAssetExactIn(address(pairToken), 10 ether, user, 0, block.timestamp + 1 hours);
    }

    function test_T1_5_firstJoinUnbalanced_missingLeg_reverts() public {
        address[] memory ts = new address[](1);
        ts[0] = address(pairToken);
        uint256[] memory am = new uint256[](1);
        am[0] = 10 ether;
        vm.prank(user);
        vm.expectRevert(DepositTarget.FirstJoinMustBeFullBook.selector);
        single.joinUnbalanced(ts, am, user, 0, block.timestamp + 1 hours);
    }

    function test_T1_6_firstJoinUnbalanced_fullBook_isLive() public {
        uint256 lp = _joinFullBook(50 ether, 50 ether);
        assertGt(lp, 0, "T1.6 lp");
        assertTrue(single.isLive(), "T1.6 live");
        assertEq(IERC20(hook).balanceOf(user), lp, "T1.6 to");
    }

    function test_T1_7_afterLive_joinSingleAsset_pairAndShare() public {
        _joinFullBook(80 ether, 80 ether);
        vm.prank(user);
        uint256 lpPair = single.joinSingleAssetExactIn(
            address(pairToken), 5 ether, user, 0, block.timestamp + 1 hours
        );
        assertGt(lpPair, 0, "T1.7 pair");

        uint256 seShares = _mintSeSharesToUser(20 ether);
        vm.prank(user);
        uint256 lpSe = single.joinSingleAssetExactIn(se, seShares, user, 0, block.timestamp + 1 hours);
        assertGt(lpSe, 0, "T1.7 share");
    }

    function test_T1_8_joinUnbalanced_pairAndShare_reverts() public {
        _joinFullBook(40 ether, 40 ether);
        uint256 seShares = _mintSeSharesToUser(5 ether);
        address[] memory ts = new address[](3);
        ts[0] = address(rawToken);
        ts[1] = address(pairToken);
        ts[2] = se;
        uint256[] memory am = new uint256[](3);
        am[0] = 1 ether;
        am[1] = 1 ether;
        am[2] = seShares;
        vm.prank(user);
        vm.expectRevert(DepositTarget.PairAndShareSameLeg.selector);
        single.joinUnbalanced(ts, am, user, 0, block.timestamp + 1 hours);
    }

    function test_T1_9_previewSwapExactIn_eq_ownerSwapExactIn() public {
        _joinFullBook(100 ether, 100 ether);
        uint256 x = 1 ether;
        uint256 preview = single.previewSwapExactIn(address(pairToken), address(rawToken), x);
        assertGt(preview, 0, "T1.9 preview");

        pairToken.mint(owner, x);
        vm.startPrank(owner);
        pairToken.approve(hook, x);
        uint256 out = single.ownerSwapExactIn(
            address(pairToken), address(rawToken), x, preview, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(out, preview, "T1.9 preview==exec");
    }

    function test_T1_10_emptyBook_previewSynthetic_and_swap_areZero() public view {
        assertFalse(single.isLive(), "empty");
        IDetfReserveQuote.DetfQuoteCtx memory ctx = IDetfReserveQuote.DetfQuoteCtx({
            detfTotalSupply: 1e18,
            pendingExpansion: 0,
            ownedLp: 1e18,
            creationPairPerDetfWad: 1e18
        });
        assertEq(single.previewSynthetic(ctx, address(pairToken)), 0, "T1.10 synthetic");
        assertEq(single.previewSwapExactIn(address(pairToken), address(rawToken), 1 ether), 0, "T1.10 swap");
    }

    function test_T1_11_previewBurnToToken_afterLive() public {
        uint256 lp = _joinFullBook(60 ether, 60 ether);
        uint256 preview = single.previewBurnToToken(lp / 2, address(pairToken));
        assertGt(preview, 0, "T1.11 preview");
        vm.prank(user);
        uint256 got = single.exitSingleAssetExactBptIn(
            address(pairToken), lp / 2, user, 0, block.timestamp + 1 hours
        );
        assertEq(got, preview, "T1.11 preview==exec");
    }

    function test_T1_12_requiredSurface_onLoupe_noZeroForOneOnSeBufferAbi() public view {
        IDiamondLoupe loupe = IDiamondLoupe(hook);
        assertTrue(loupe.facetAddress(IUniswapV4SeBufferHook.joinUnbalanced.selector) != address(0), "joinUnbalanced");
        assertTrue(
            loupe.facetAddress(IUniswapV4SeBufferHook.previewSwapExactIn.selector) != address(0),
            "previewSwapExactIn(addr)"
        );
        assertTrue(loupe.facetAddress(IUniswapV4SeBufferHook.tokens.selector) != address(0), "tokens");
        assertTrue(loupe.facetAddress(IDetfReserveQuote.previewBurnToToken.selector) != address(0), "previewBurnToToken");
    }

    function test_T1_13_unknownToken_join_reverts() public {
        address[] memory ts = new address[](2);
        ts[0] = address(rawToken);
        ts[1] = address(0xB0B);
        uint256[] memory am = new uint256[](2);
        am[0] = 1 ether;
        am[1] = 1 ether;
        vm.prank(user);
        vm.expectRevert(DepositTarget.InvalidRoute.selector);
        single.joinUnbalanced(ts, am, user, 0, block.timestamp + 1 hours);
    }

    function test_T1_14_registryDeploy_noNewPkg() public view {
        assertTrue(hook != address(0), "hook");
        assertTrue(address(hookPkg) != address(0), "pkg");
        assertTrue(indexedexManager.isVault(hook) || IDiamondLoupe(hook).facetAddresses().length > 0, "diamond");
    }

    function _joinFullBook(uint256 rawAmt, uint256 pairAmt) internal returns (uint256 lp) {
        address[] memory ts = new address[](2);
        ts[0] = address(rawToken);
        ts[1] = address(pairToken);
        uint256[] memory am = new uint256[](2);
        am[0] = rawAmt;
        am[1] = pairAmt;
        vm.prank(user);
        lp = single.joinUnbalanced(ts, am, user, 0, block.timestamp + 1 hours);
    }
}
