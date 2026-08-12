// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookMath.sol";
import {
    MintableERC20Decimals
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/MintableERC20Decimals.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {RateProviderMock} from "contracts/test/balancer/v3/RateProviderMock.sol";

contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_Scale is TestBase {
    function test_geoMean4_firstMintDomain() public pure {
        uint256 g = Math.geometricMean4(1e18, 1e18, 1e18, 1e18);
        assertEq(g, 1e18);
        uint256 shares = Math.firstMintShares([uint256(1e21), 1e21, 1e21, 1e21]);
        assertEq(shares, 1e21 - 1000);
    }

    function test_dualScale_seVsRaw() public {
        assertGt(quad.invScale(0), 0);
        assertGt(quad.ratedScale(0), 0);
        _firstMintEqual(100 ether);
        assertEq(quad.nativeReserve(0), quad.seBalance(0));
        assertGt(quad.ratedBalance(0), 0);
    }

    function test_seMatrix_1to4() public {
        for (uint8 n = 1; n <= 4; ++n) {
            _deployHookWithArgs(_argsSeCount(n));
            _fundAndApprove(token0);
            _fundAndApprove(token1);
            _fundAndApprove(token2);
            _fundAndApprove(token3);
            _assertAllDoorsLive();
            uint256 shares = _firstMintEqual(50 ether);
            assertGt(shares, 0);
        }
    }

    /// @notice FIX-SCALE-6-18: one raw 6-dec + three 18-dec (one SE-wrapped).
    function test_FIX_SCALE_6_18_mixedDecimalsFirstMint() public {
        MintableERC20Decimals t6 = new MintableERC20Decimals("Six", "SIX", 6);
        SimpleMintableERC20 t18a = new SimpleMintableERC20("E18a", "E18A");
        SimpleMintableERC20 t18b = new SimpleMintableERC20("E18b", "E18B");
        SimpleMintableERC20 t18c = new SimpleMintableERC20("E18c", "E18C");
        SimpleYieldERC4626 vault = new SimpleYieldERC4626(t18a);
        address se18 = _deployERC4626SE(address(vault));

        address[4] memory toks = [address(t6), address(t18a), address(t18b), address(t18c)];
        for (uint256 i; i < 4; ++i) {
            for (uint256 j = i + 1; j < 4; ++j) {
                if (toks[j] < toks[i]) (toks[i], toks[j]) = (toks[j], toks[i]);
            }
        }
        address[4] memory ses;
        address[4] memory rps;
        uint8 i6;
        uint8 iSe;
        for (uint8 i; i < 4; ++i) {
            if (toks[i] == address(t6)) i6 = i;
            if (toks[i] == address(t18a)) {
                iSe = i;
                ses[i] = se18;
            }
        }

        _deployHookWithArgs(_pkgArgs(toks, ses, rps, DEFAULT_BASE_AMP));

        t6.mint(user, 1_000_000e6);
        t18a.mint(user, 1_000_000 ether);
        t18b.mint(user, 1_000_000 ether);
        t18c.mint(user, 1_000_000 ether);
        vm.startPrank(user);
        t6.approve(hook, type(uint256).max);
        t18a.approve(hook, type(uint256).max);
        t18b.approve(hook, type(uint256).max);
        t18c.approve(hook, type(uint256).max);
        vm.stopPrank();

        assertEq(quad.ratedScale(i6), 10 ** uint256(36 - 6), "ratedScale 6dec");
        assertEq(quad.invScale(i6), quad.ratedScale(i6), "raw 6 inv==rated");
        assertEq(quad.invScale(iSe), 10 ** uint256(36 - 18), "SE inv share 18");
        assertTrue(quad.ratedScale(i6) != quad.ratedScale(iSe), "cross-leg scales differ");

        uint256[] memory amounts = new uint256[](4);
        for (uint8 i; i < 4; ++i) {
            amounts[i] = toks[i] == address(t6) ? 100_000e6 : 100 ether;
        }
        (uint256 prev,) = quad.previewJoinProportional(amounts);
        vm.prank(user);
        (uint256 shares,) = quad.joinProportional(amounts, user, 0, block.timestamp + 1 hours);
        assertEq(shares, prev);
        assertGt(shares, 0, "first mint mixed decimals");
        assertTrue(quad.isFullBook());
        assertEq(IERC20(hook).balanceOf(address(0)), 1000);
    }

    function test_donation_rawFace_dilutesJoin() public {
        _firstMintEqual(200 ether);
        uint256[] memory amounts = new uint256[](4);
        for (uint256 i; i < 4; ++i) amounts[i] = 20 ether;
        (uint256 sharesBefore,) = quad.previewJoinProportional(amounts);
        token1.mint(hook, 100 ether);
        assertEq(quad.nativeReserve(1), token1.balanceOf(hook), "live face");
        (uint256 sharesAfter,) = quad.previewJoinProportional(amounts);
        assertLt(sharesAfter, sharesBefore, "raw donation dilutes join mint");
    }

    function test_FIX_RATED_RP_nonOneRate() public {
        RateProviderMock rp = new RateProviderMock();
        rp.mockRate(1.25e18);
        address[4] memory toks = [address(token0), address(token1), address(token2), address(token3)];
        address[4] memory ses;
        ses[0] = se0;
        address[4] memory rps;
        rps[0] = address(rp);
        _deployHookWithArgs(_pkgArgs(toks, ses, rps, DEFAULT_BASE_AMP));
        _fundAndApprove(token0);
        _fundAndApprove(token1);
        _fundAndApprove(token2);
        _fundAndApprove(token3);
        _firstMintEqual(200 ether);
        uint256 seBal = quad.seBalance(0);
        uint256 rated = quad.ratedBalance(0);
        // rated = seBal * rate / 1e18 in pair units (before scale display)
        assertEq(rated, (seBal * 1.25e18) / 1e18, "rated uses seBal*rate");
        uint256 preview = quad.previewSwapExactIn(address(token0), address(token1), 1 ether);
        assertGt(preview, 0);
        uint256 b1 = token1.balanceOf(user);
        _swapExactIn(address(token0), address(token1), 1 ether);
        assertEq(token1.balanceOf(user) - b1, preview);
    }

    function test_faceDustOnSeLeg_notBook() public {
        _firstMintEqual(50 ether);
        uint256 bookMid = quad.nativeReserve(0);
        token0.mint(hook, 5); // free pair dust on SE leg
        assertEq(quad.nativeReserve(0), bookMid, "face dust not book");
        assertEq(quad.nativeReserve(0), quad.seBalance(0), "still SE shares");
    }
}
