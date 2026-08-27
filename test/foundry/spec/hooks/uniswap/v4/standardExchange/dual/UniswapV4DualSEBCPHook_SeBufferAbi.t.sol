// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {TestBase_UniswapV4DualSEBCPHook as TestBase} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookCommon as DualCommon
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol";

/**
 * @title UniswapV4DualSEBCPHook_SeBufferAbi
 * @notice Stage 05 T5.1–T5.5: shared SE buffer ABI on Dual (no DETF bind).
 */
contract UniswapV4DualSEBCPHook_SeBufferAbi is TestBase {
    function test_T5_1_tokens_twoPairs_noDetf_disjointSets() public view {
        address[] memory t = dual.tokens();
        assertEq(t.length, 2, "T5.1 length");
        assertEq(t[0], dual.currency0(), "T5.1 c0");
        assertEq(t[1], dual.currency1(), "T5.1 c1");
        assertTrue(t[0] != address(hook) && t[1] != address(hook), "T5.1 no DETF");
        assertTrue(t[0] != seA && t[0] != seB && t[1] != seA && t[1] != seB, "T5.1 pairs not SE");

        address se0 = dual.standardExchangeOf(t[0]);
        address se1 = dual.standardExchangeOf(t[1]);
        assertTrue(se0 != address(0) && se1 != address(0), "T5.1 two SEs");
        assertTrue(se0 != se1, "T5.1 distinct SE");
        assertTrue(se0 != t[0] && se0 != t[1] && se1 != t[0] && se1 != t[1], "T5.1 disjoint");
        assertEq(dual.standardExchangeOf(se0), address(0), "T5.1 se not pair");
        assertEq(dual.standardExchangeOf(se1), address(0), "T5.1 se not pair");
        assertEq(dual.standardExchangeOf(address(hook)), address(0), "T5.1 detf unbound");
        assertTrue(dual.firstJoinMustBeFullBook(), "T5.1 full book");
        address[] memory req = dual.requiredFirstBondTokens();
        assertEq(req.length, 2, "T5.1 required length");
        assertEq(req[0], t[0], "T5.1 required0");
        assertEq(req[1], t[1], "T5.1 required1");
    }

    function test_T5_2_fullBookFirstJoin_singleAssetBeforeLiveReverts() public {
        assertFalse(dual.isLive(), "pre-live");
        vm.prank(user);
        vm.expectRevert(DualCommon.NotLive.selector);
        dual.joinSingleAssetExactIn(address(tokenA), 10 ether, user, 0, block.timestamp + 1 hours);

        address[] memory ts = new address[](1);
        ts[0] = dual.currency0();
        uint256[] memory am = new uint256[](1);
        am[0] = 10 ether;
        vm.prank(user);
        vm.expectRevert(DualCommon.FirstJoinMustBeFullBook.selector);
        dual.joinUnbalanced(ts, am, user, 0, block.timestamp + 1 hours);

        uint256 lp = _joinFullBook(50 ether, 50 ether);
        assertGt(lp, 0, "T5.2 lp");
        assertTrue(dual.isLive(), "T5.2 live");
        assertEq(IERC20(hook).balanceOf(user), lp, "T5.2 to");
    }

    function test_T5_3_afterLive_joinSingleAsset_pairAndShare() public {
        _joinFullBook(80 ether, 80 ether);
        vm.prank(user);
        uint256 lpPair = dual.joinSingleAssetExactIn(
            address(tokenA), 5 ether, user, 0, block.timestamp + 1 hours
        );
        assertGt(lpPair, 0, "T5.3 pair");

        uint256 seShares = _userAcquireSeShares(seA, tokenA, 20 ether);
        vm.prank(user);
        uint256 lpSe = dual.joinSingleAssetExactIn(seA, seShares, user, 0, block.timestamp + 1 hours);
        assertGt(lpSe, 0, "T5.3 share");
    }

    function test_T5_4_implementsSharedAbi_oldNamesRemainWrappers() public view {
        IDiamondLoupe loupe = IDiamondLoupe(hook);
        assertTrue(loupe.facetAddress(IUniswapV4SeBufferHook.joinUnbalanced.selector) != address(0), "joinUnbalanced");
        assertTrue(
            loupe.facetAddress(IUniswapV4SeBufferHook.previewSwapExactIn.selector) != address(0),
            "previewSwapExactIn(addr)"
        );
        assertTrue(loupe.facetAddress(IUniswapV4SeBufferHook.tokens.selector) != address(0), "tokens");
        assertTrue(loupe.facetAddress(IUniswapV4SeBufferHook.firstJoinMustBeFullBook.selector) != address(0), "fullBook");
        assertTrue(loupe.facetAddress(IDetfReserveQuote.previewBurnToToken.selector) != address(0), "previewBurnToToken");
        assertTrue(loupe.facetAddress(IDetfReserveQuote.previewSynthetic.selector) != address(0), "previewSynthetic");
        // Family names stay as wrappers of the same internals.
        assertTrue(loupe.facetAddress(dual.deposit.selector) != address(0), "deposit wrapper");
        assertTrue(loupe.facetAddress(dual.withdraw.selector) != address(0), "withdraw wrapper");
        assertTrue(loupe.facetAddress(dual.depositSingle.selector) != address(0), "depositSingle wrapper");
    }

    function test_T5_4b_previewSynthetic_zeroWhenNoDetfLeg() public view {
        IDetfReserveQuote.DetfQuoteCtx memory ctx = IDetfReserveQuote.DetfQuoteCtx({
            detfTotalSupply: 1e18,
            pendingExpansion: 0,
            ownedLp: 1e18,
            creationPairPerDetfWad: 1e18
        });
        assertEq(dual.previewSynthetic(ctx, address(tokenA)), 0, "T5.4b pair numeraire");
        assertEq(dual.previewSynthetic(ctx, address(hook)), 0, "T5.4b detf not in tokens");
        assertEq(dual.previewSwapExactIn(address(tokenA), address(tokenB), 1 ether), 0, "T5.4b empty swap");
    }

    function test_T5_5_registryDeploy_noNewPkg() public view {
        assertTrue(hook != address(0), "hook");
        assertTrue(address(hookPkg) != address(0), "pkg");
        assertTrue(IVaultRegistryVaultQuery(address(indexedexManager)).isVault(hook), "registry isVault");
        assertTrue(IDiamondLoupe(hook).facetAddresses().length > 0, "diamond");
    }

    function test_T5_unknownToken_join_reverts() public {
        address[] memory ts = new address[](2);
        ts[0] = dual.currency0();
        ts[1] = address(0xB0B);
        uint256[] memory am = new uint256[](2);
        am[0] = 1 ether;
        am[1] = 1 ether;
        vm.prank(user);
        vm.expectRevert(DualCommon.InvalidRoute.selector);
        dual.joinUnbalanced(ts, am, user, 0, block.timestamp + 1 hours);
    }

    function test_T5_joinUnbalanced_pairAndShareSameLeg_reverts() public {
        _joinFullBook(40 ether, 40 ether);
        uint256 seShares = _userAcquireSeShares(seA, tokenA, 5 ether);
        address[] memory ts = new address[](3);
        ts[0] = address(tokenA);
        ts[1] = seA;
        ts[2] = address(tokenB);
        uint256[] memory am = new uint256[](3);
        am[0] = 1 ether;
        am[1] = seShares;
        am[2] = 1 ether;
        vm.prank(user);
        vm.expectRevert(DualCommon.PairAndShareSameLeg.selector);
        dual.joinUnbalanced(ts, am, user, 0, block.timestamp + 1 hours);
    }

    function _joinFullBook(uint256 amtA, uint256 amtB) internal returns (uint256 lp) {
        address[] memory ts = new address[](2);
        ts[0] = address(tokenA);
        ts[1] = address(tokenB);
        uint256[] memory am = new uint256[](2);
        am[0] = amtA;
        am[1] = amtB;
        vm.prank(user);
        lp = dual.joinUnbalanced(ts, am, user, 0, block.timestamp + 1 hours);
    }
}
