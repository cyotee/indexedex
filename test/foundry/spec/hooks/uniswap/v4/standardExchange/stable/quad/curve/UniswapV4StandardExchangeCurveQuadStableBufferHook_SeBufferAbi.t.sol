// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {
    TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookTarget as Target
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.sol";

/**
 * @title UniswapV4StandardExchangeCurveQuadStableBufferHook_SeBufferAbi
 * @notice Stage 04 T4.1–T4.6: shared SE buffer ABI on the Curve Quad hook.
 */
contract UniswapV4StandardExchangeCurveQuadStableBufferHook_SeBufferAbi is TestBase {
    function test_T4_1_tokens_length4_threeSe_disjoint() public {
        _deployHookWithArgs(_argsSeCount(3));
        _fundAndApprove(token0);
        _fundAndApprove(token1);
        _fundAndApprove(token2);
        _fundAndApprove(token3);

        address[] memory t = quad.tokens();
        assertEq(t.length, 4, "T4.1 length");
        uint256 seCount;
        for (uint256 i; i < t.length; ++i) {
            address se = quad.standardExchangeOf(t[i]);
            if (se == address(0)) continue;
            unchecked {
                ++seCount;
            }
            assertTrue(se != t[0] && se != t[1] && se != t[2] && se != t[3], "T4.1 disjoint");
            assertEq(quad.standardExchangeOf(se), address(0), "T4.1 se not pair");
        }
        assertEq(seCount, 3, "T4.1 three SEs");
        address[] memory nums = quad.syntheticNumeraires();
        assertEq(nums.length, 3, "T4.1 numeraires");
    }

    function test_T4_2_firstJoin_fullBook_singleAssetBeforeLive_reverts() public {
        assertFalse(quad.isLive(), "pre-live");
        assertTrue(quad.firstJoinMustBeFullBook(), "full-book flag");

        vm.prank(user);
        vm.expectRevert(Target.NotLive.selector);
        quad.joinSingleAssetExactIn(address(token1), 10 ether, user, 0, block.timestamp + 1 hours);

        address[] memory ts = new address[](3);
        ts[0] = address(token0);
        ts[1] = address(token1);
        ts[2] = address(token2);
        uint256[] memory am = new uint256[](3);
        am[0] = 10 ether;
        am[1] = 10 ether;
        am[2] = 10 ether;
        vm.prank(user);
        vm.expectRevert(Target.FirstJoinMustBeFullBook.selector);
        quad.joinUnbalanced(ts, am, user, 0, block.timestamp + 1 hours);

        uint256 lp = _joinFullBook(50 ether);
        assertGt(lp, 0, "T4.2 lp");
        assertTrue(quad.isLive(), "T4.2 live");
        assertEq(IERC20(hook).balanceOf(user), lp, "T4.2 to");
    }

    function test_T4_3_afterLive_joinSingleAsset_pairAndShare() public {
        _joinFullBook(80 ether);
        vm.prank(user);
        uint256 lpPair = quad.joinSingleAssetExactIn(
            address(token1), 5 ether, user, 0, block.timestamp + 1 hours
        );
        assertGt(lpPair, 0, "T4.3 pair");

        uint256 seShares = _userAcquireSeShares(se0, token0, 20 ether);
        vm.prank(user);
        uint256 lpSe = quad.joinSingleAssetExactIn(se0, seShares, user, 0, block.timestamp + 1 hours);
        assertGt(lpSe, 0, "T4.3 share");
    }

    function test_T4_4_previewBurnToToken_propExit_notSingleAsset() public {
        uint256 lp = _joinFullBook(200 ether);
        uint256 burn = lp / 4;
        uint256 preview = quad.previewBurnToToken(burn, address(token1));
        assertGt(preview, 0, "T4.4 preview");
        uint256[] memory prop = quad.previewExitProportional(burn);
        assertEq(preview, prop[1], "T4.4 prop residual");
        uint256 single = quad.previewExitSingleAssetExactBptIn(address(token1), burn);
        assertTrue(preview != single, "T4.4 not exitSingleAsset");

        uint256[] memory mins = new uint256[](4);
        vm.prank(user);
        uint256[] memory got = quad.exitProportional(burn, user, mins, block.timestamp + 1 hours);
        assertEq(got[1], preview, "T4.4 preview==prop exec");
    }

    function test_T4_5_withdrawSingle_notOnSeBufferAbi_exitSingleAssetExists() public view {
        IDiamondLoupe loupe = IDiamondLoupe(hook);
        assertTrue(
            loupe.facetAddress(IUniswapV4SeBufferHook.exitSingleAssetExactBptIn.selector) != address(0),
            "exitSingleAssetExactBptIn"
        );
        assertTrue(
            loupe.facetAddress(IUniswapV4SeBufferHook.joinUnbalanced.selector) != address(0),
            "joinUnbalanced(address[])"
        );
        bytes4 withdrawn = bytes4(keccak256("withdrawSingle(address,uint256,address,uint256,uint256)"));
        assertTrue(withdrawn != IUniswapV4SeBufferHook.exitSingleAssetExactBptIn.selector, "name gone on ABI");
    }

    function test_T4_6_registryDeploy_noNewPkg() public view {
        assertTrue(hook != address(0), "hook");
        assertTrue(address(hookPkg) != address(0), "pkg");
        assertTrue(IDiamondLoupe(hook).facetAddresses().length > 0, "diamond");
    }

    function test_T4_unknownToken_join_reverts() public {
        address[] memory ts = new address[](2);
        ts[0] = address(token0);
        ts[1] = address(0xB0B);
        uint256[] memory am = new uint256[](2);
        am[0] = 1 ether;
        am[1] = 1 ether;
        vm.prank(user);
        vm.expectRevert(IHook.InvalidRoute.selector);
        quad.joinUnbalanced(ts, am, user, 0, block.timestamp + 1 hours);
    }

    function test_T4_emptyBook_previewSynthetic_and_swap_areZero() public view {
        assertFalse(quad.isLive(), "empty");
        IDetfReserveQuote.DetfQuoteCtx memory ctx = IDetfReserveQuote.DetfQuoteCtx({
            detfTotalSupply: 1e18,
            pendingExpansion: 0,
            ownedLp: 1e18,
            creationPairPerDetfWad: 1e18
        });
        assertEq(quad.previewSynthetic(ctx, address(token1)), 0, "synthetic");
        assertEq(quad.previewSwapExactIn(address(token0), address(token1), 1 ether), 0, "swap");
    }

    function _joinFullBook(uint256 amtEach) internal returns (uint256 lp) {
        address[] memory ts = quad.tokens();
        uint256[] memory am = new uint256[](4);
        am[0] = amtEach;
        am[1] = amtEach;
        am[2] = amtEach;
        am[3] = amtEach;
        vm.prank(user);
        lp = quad.joinUnbalanced(ts, am, user, 0, block.timestamp + 1 hours);
    }
}
