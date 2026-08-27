// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookCommon as Common
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol";

/**
 * @title UniswapV4StandardExchangeOrbitalBufferHook_SeBufferAbi
 * @notice Stage 02 T2.1–T2.10: shared SE buffer ABI on the Orbital hook. n=3, two SEs.
 */
contract UniswapV4StandardExchangeOrbitalBufferHook_SeBufferAbi is TestBase {
    function _defaultPkgArgs()
        internal
        view
        override
        returns (IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory)
    {
        return _argsWithSE(false, true, true);
    }

    function test_T2_1_tokens_length3_twoSes_disjoint() public view {
        address[] memory t = orbital.tokens();
        assertEq(t.length, 3, "T2.1 length");
        assertEq(t[0], address(token0), "T2.1 token0 detf");
        assertEq(t[1], address(token1), "T2.1 pair0");
        assertEq(t[2], address(token2), "T2.1 pair1");
        assertEq(orbital.standardExchangeOf(address(token0)), address(0), "T2.1 detf no se");
        assertEq(orbital.standardExchangeOf(address(token1)), se1, "T2.1 se of pair0");
        assertEq(orbital.standardExchangeOf(address(token2)), se2, "T2.1 se of pair1");
        assertTrue(se1 != address(token1) && se2 != address(token2), "T2.1 disjoint");
        assertTrue(se1 != se2, "T2.1 two ses");
    }

    function test_T2_2_firstJoinMustBeFullBook_requiredAllThree() public view {
        assertTrue(orbital.firstJoinMustBeFullBook(), "T2.2 flag");
        address[] memory req = orbital.requiredFirstBondTokens();
        assertEq(req.length, 3, "T2.2 required length");
        assertEq(req[0], address(token0));
        assertEq(req[1], address(token1));
        assertEq(req[2], address(token2));
    }

    function test_T2_3_joinSingleAssetExactIn_beforeLive_reverts() public {
        assertFalse(orbital.isLive(), "pre-live");
        vm.prank(user);
        vm.expectRevert();
        orbital.joinSingleAssetExactIn(address(token1), 10 ether, user, 0, block.timestamp + 1 hours);
    }

    function test_T2_4_firstJoinUnbalanced_fullBook_isLive() public {
        uint256 lp = _joinFullBook(50 ether, 50 ether, 50 ether);
        assertGt(lp, 0, "T2.4 lp");
        assertTrue(orbital.isLive(), "T2.4 live");
        assertEq(IERC20(hook).balanceOf(user), lp, "T2.4 to");
    }

    function test_T2_5_afterLive_joinSingleAsset_pairsAndShares() public {
        _joinFullBook(80 ether, 80 ether, 80 ether);
        vm.prank(user);
        uint256 lpPair0 = orbital.joinSingleAssetExactIn(
            address(token1), 5 ether, user, 0, block.timestamp + 1 hours
        );
        assertGt(lpPair0, 0, "T2.5 pair0");

        vm.prank(user);
        uint256 lpPair1 = orbital.joinSingleAssetExactIn(
            address(token2), 5 ether, user, 0, block.timestamp + 1 hours
        );
        assertGt(lpPair1, 0, "T2.5 pair1");

        uint256 seShares0 = _mintSeSharesToUser(se1, token1, 20 ether);
        vm.prank(user);
        uint256 lpSe0 = orbital.joinSingleAssetExactIn(se1, seShares0, user, 0, block.timestamp + 1 hours);
        assertGt(lpSe0, 0, "T2.5 share0");

        uint256 seShares1 = _mintSeSharesToUser(se2, token2, 20 ether);
        vm.prank(user);
        uint256 lpSe1 = orbital.joinSingleAssetExactIn(se2, seShares1, user, 0, block.timestamp + 1 hours);
        assertGt(lpSe1, 0, "T2.5 share1");
    }

    function test_T2_6_joinUnbalanced_pairAndShare_sameLeg_reverts() public {
        _joinFullBook(40 ether, 40 ether, 40 ether);
        uint256 seShares = _mintSeSharesToUser(se1, token1, 5 ether);
        address[] memory ts = new address[](4);
        ts[0] = address(token0);
        ts[1] = address(token1);
        ts[2] = se1;
        ts[3] = address(token2);
        uint256[] memory am = new uint256[](4);
        am[0] = 1 ether;
        am[1] = 1 ether;
        am[2] = seShares;
        am[3] = 1 ether;
        vm.prank(user);
        vm.expectRevert(Common.PairAndShareSameLeg.selector);
        orbital.joinUnbalanced(ts, am, user, 0, block.timestamp + 1 hours);
    }

    function test_T2_7_previewSynthetic_perPath() public {
        _joinFullBook(100 ether, 100 ether, 100 ether);
        IDetfReserveQuote.DetfQuoteCtx memory ctx = IDetfReserveQuote.DetfQuoteCtx({
            detfTotalSupply: 1e18,
            pendingExpansion: 0,
            ownedLp: 1e18,
            creationPairPerDetfWad: 1e18
        });
        uint256 s0 = orbital.previewSynthetic(ctx, address(token1));
        uint256 s1 = orbital.previewSynthetic(ctx, address(token2));
        assertGt(s0, 0, "T2.7 pair0");
        assertGt(s1, 0, "T2.7 pair1");
    }

    function test_T2_8_previewBurnToToken_propRejoin_notExitSingle() public {
        uint256 lp = _joinFullBook(60 ether, 60 ether, 60 ether);
        uint256 preview = orbital.previewBurnToToken(lp / 2, address(token1));
        assertGt(preview, 0, "T2.8 preview");
        uint256[] memory prop = orbital.previewExitProportional(lp / 2);
        assertEq(prop.length, 3, "T2.8 prop");
        assertGt(prop[1], 0, "T2.8 pair0 face");
        assertTrue(preview >= prop[1], "T2.8 burn includes pair0 plus converted residual");
        assertEq(orbital.previewExitSingleAssetExactBptIn(address(token1), lp / 2), 0, "T2.8 no single-asset path");
    }

    function test_T2_9_requiredSurface_onLoupe() public view {
        IDiamondLoupe loupe = IDiamondLoupe(hook);
        assertTrue(loupe.facetAddress(IUniswapV4SeBufferHook.joinUnbalanced.selector) != address(0), "joinUnbalanced");
        assertTrue(
            loupe.facetAddress(IUniswapV4SeBufferHook.previewSwapExactIn.selector) != address(0),
            "previewSwapExactIn(addr)"
        );
        assertTrue(loupe.facetAddress(IUniswapV4SeBufferHook.tokens.selector) != address(0), "tokens");
        assertTrue(loupe.facetAddress(IDetfReserveQuote.previewBurnToToken.selector) != address(0), "previewBurnToToken");
        assertTrue(
            loupe.facetAddress(IUniswapV4SeBufferHook.joinSingleAssetExactIn.selector) != address(0),
            "joinSingleAssetExactIn"
        );
    }

    function test_T2_10_registryDeploy_noNewPkg() public view {
        assertTrue(hook != address(0), "hook");
        assertTrue(address(hookPkg) != address(0), "pkg");
        assertTrue(_registry().isVault(hook) || IDiamondLoupe(hook).facetAddresses().length > 0, "diamond");
    }

    function test_T2_unknownToken_join_reverts() public {
        address[] memory ts = new address[](3);
        ts[0] = address(token0);
        ts[1] = address(token1);
        ts[2] = address(0xB0B);
        uint256[] memory am = new uint256[](3);
        am[0] = 1 ether;
        am[1] = 1 ether;
        am[2] = 1 ether;
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Common.InvalidRoute.selector, address(0xB0B), address(0)));
        orbital.joinUnbalanced(ts, am, user, 0, block.timestamp + 1 hours);
    }

    function test_T2_emptyBook_previewSynthetic_isZero() public view {
        assertFalse(orbital.isLive(), "empty");
        IDetfReserveQuote.DetfQuoteCtx memory ctx = IDetfReserveQuote.DetfQuoteCtx({
            detfTotalSupply: 1e18,
            pendingExpansion: 0,
            ownedLp: 1e18,
            creationPairPerDetfWad: 1e18
        });
        assertEq(orbital.previewSynthetic(ctx, address(token1)), 0, "T2 synthetic");
        assertEq(orbital.previewSwapExactIn(address(token1), address(token0), 1 ether), 0, "T2 swap");
    }

    function _joinFullBook(uint256 detfAmt, uint256 pair0Amt, uint256 pair1Amt)
        internal
        returns (uint256 lp)
    {
        address[] memory ts = new address[](3);
        ts[0] = address(token0);
        ts[1] = address(token1);
        ts[2] = address(token2);
        uint256[] memory am = new uint256[](3);
        am[0] = detfAmt;
        am[1] = pair0Amt;
        am[2] = pair1Amt;
        vm.prank(user);
        lp = orbital.joinUnbalanced(ts, am, user, 0, block.timestamp + 1 hours);
    }
}
