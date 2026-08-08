// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeQuadStableBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/TestBase_UniswapV4StandardExchangeQuadStableBufferHook.sol";
import {
    IUniswapV4StandardExchangeQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/interfaces/IUniswapV4StandardExchangeQuadStableBufferHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {ModifyLiquidityParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {
    UniswapV4StandardExchangeQuadStableBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/UniswapV4StandardExchangeQuadStableBufferHookPairPoolLib.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {RateProviderMock} from "contracts/test/balancer/v3/RateProviderMock.sol";
import {
    HostileReentrantERC20
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/HostileReentrantERC20.sol";

contract UniswapV4StandardExchangeQuadStableBufferHook_Adversarial is TestBase {
    function test_donation_seShares_dilutesJoin() public {
        _firstMintEqual(200 ether);
        uint256[] memory amounts = new uint256[](4);
        for (uint256 i; i < 4; ++i) amounts[i] = 20 ether;
        (uint256 sharesBefore,) = quad.previewJoinProportional(amounts);

        token0.mint(user, 200 ether);
        vm.startPrank(user);
        token0.approve(se0, type(uint256).max);
        uint256 seShares = IStandardExchangeIn(se0).exchangeIn(
            IERC20(address(token0)), 100 ether, IERC20(se0), 0, user, false, block.timestamp + 1
        );
        IERC20(se0).transfer(hook, seShares);
        vm.stopPrank();

        (uint256 sharesAfter,) = quad.previewJoinProportional(amounts);
        assertLt(sharesAfter, sharesBefore, "SE share donation must dilute subsequent join");
    }

    function test_rateProvider_failClosed_onSwapPreview() public {
        RateProviderMock rp = new RateProviderMock();
        rp.mockRate(1e18);
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
        rp.mockRate(0);
        vm.expectRevert();
        quad.previewSwapExactIn(address(token0), address(token1), 1 ether);
    }

    function test_fullBook_exitCannotZeroLeg() public {
        uint256 shares = _firstMintEqual(100 ether);
        uint256[] memory mins = new uint256[](4);
        uint256 burn = shares / 4;
        vm.prank(user);
        quad.exitProportional(burn, user, mins, block.timestamp + 1 hours);
        for (uint256 i; i < 4; ++i) {
            assertGt(quad.nativeReserve(i), 0);
        }
        assertTrue(quad.isFullBook());

        // Prop-exit all remaining user LP leaves dead MIN + residual inventory on every leg.
        uint256 remaining = IERC20(hook).balanceOf(user);
        vm.prank(user);
        quad.exitProportional(remaining, user, mins, block.timestamp + 1 hours);
        for (uint256 i; i < 4; ++i) {
            assertGt(quad.nativeReserve(i), 0, "full-book floor after full user exit");
        }
        assertEq(IERC20(hook).balanceOf(user), 0);
        assertGe(IERC20(hook).totalSupply(), 1000);
    }

    function test_clAddLiquidity_blocked() public {
        _firstMintEqual(50 ether);
        PoolKey memory key = PairPoolLib.pairKey(address(token0), address(token1), 1, IHooks(hook));
        vm.prank(address(pm));
        vm.expectRevert();
        IHooks(hook).beforeAddLiquidity(
            address(this),
            key,
            ModifyLiquidityParams({tickLower: -60, tickUpper: 60, liquidityDelta: 1, salt: bytes32(0)}),
            ""
        );
    }

    function test_clDonate_blocked() public {
        _firstMintEqual(50 ether);
        PoolKey memory key = PairPoolLib.pairKey(address(token0), address(token1), 1, IHooks(hook));
        vm.prank(address(pm));
        vm.expectRevert();
        IHooks(hook).beforeDonate(address(this), key, 1, 1, "");
    }

    /// @notice Reentrancy-hostile raw ERC20 reenters depositSingle during transferFrom → nested fail.
    function test_reentrancy_join_hitsReentrancy() public {
        SimpleMintableERC20 seToken = new SimpleMintableERC20("SEPair", "SEP");
        HostileReentrantERC20 hostile = new HostileReentrantERC20("Hostile", "HST");
        SimpleMintableERC20 t2 = new SimpleMintableERC20("T2", "T2");
        SimpleMintableERC20 t3 = new SimpleMintableERC20("T3", "T3");
        SimpleYieldERC4626 vault = new SimpleYieldERC4626(seToken);
        address se = _deployERC4626SE(address(vault));

        address[4] memory toks = [address(seToken), address(hostile), address(t2), address(t3)];
        for (uint256 i; i < 4; ++i) {
            for (uint256 j = i + 1; j < 4; ++j) {
                if (toks[j] < toks[i]) (toks[i], toks[j]) = (toks[j], toks[i]);
            }
        }
        address[4] memory ses;
        address[4] memory rps;
        for (uint8 i; i < 4; ++i) {
            if (toks[i] == address(seToken)) ses[i] = se;
        }

        _deployHookWithArgs(_pkgArgs(toks, ses, rps, DEFAULT_BASE_AMP));

        seToken.mint(user, 1_000_000 ether);
        hostile.mint(user, 1_000_000 ether);
        t2.mint(user, 1_000_000 ether);
        t3.mint(user, 1_000_000 ether);
        vm.startPrank(user);
        seToken.approve(hook, type(uint256).max);
        hostile.approve(hook, type(uint256).max);
        t2.approve(hook, type(uint256).max);
        t3.approve(hook, type(uint256).max);
        vm.stopPrank();

        uint256[] memory amounts = new uint256[](4);
        for (uint256 i; i < 4; ++i) amounts[i] = 100 ether;
        vm.prank(user);
        (uint256 shares,) = quad.joinProportional(amounts, user, 0, block.timestamp + 1 hours);
        assertGt(shares, 0);
        assertTrue(quad.isFullBook());

        vm.prank(user);
        uint256 okShares =
            quad.depositSingle(address(hostile), 5 ether, user, 0, block.timestamp + 1 hours);
        assertGt(okShares, 0, "control depositSingle works");

        bytes memory reentry = abi.encodeWithSelector(
            IUniswapV4StandardExchangeQuadStableBufferHook.depositSingle.selector,
            address(hostile),
            uint256(1 ether),
            user,
            uint256(0),
            block.timestamp + 1 hours
        );
        hostile.arm(hook, reentry);

        for (uint256 i; i < 4; ++i) amounts[i] = 10 ether;
        vm.prank(user);
        quad.joinProportional(amounts, user, 0, block.timestamp + 1 hours);
        assertGt(hostile.reentryAttempts(), 0, "reentry attempted");
        assertFalse(hostile.nestedCallSucceeded(), "nested mutator must fail reentrancy guard");
    }

    function test_feeTo_growthMintIncreasesBalance() public {
        _ensureFeeTo();
        _setUsageFee(0.05e18);
        _firstMintEqual(100 ether);
        address feeTo_ = address(quad.feeTo());
        uint256 before_ = IERC20(hook).balanceOf(feeTo_);

        token0.mint(user, 50 ether);
        vm.startPrank(user);
        token0.approve(se0, type(uint256).max);
        uint256 seOut = IStandardExchangeIn(se0).exchangeIn(
            IERC20(address(token0)), 50 ether, IERC20(se0), 0, user, false, block.timestamp + 1
        );
        IERC20(se0).transfer(hook, seOut);
        vm.stopPrank();

        uint256[] memory amounts = new uint256[](4);
        for (uint256 i; i < 4; ++i) amounts[i] = 10 ether;
        vm.prank(user);
        quad.joinProportional(amounts, user, 0, block.timestamp + 1);
        assertGt(IERC20(hook).balanceOf(feeTo_), before_, "feeTo got protocol shares");
    }

    function test_preLive_swapReverts() public {
        // fresh hook with zero supply
        _deployHookWithArgs(_defaultPkgArgs());
        _fundAndApprove(token0);
        _fundAndApprove(token1);
        _fundAndApprove(token2);
        _fundAndApprove(token3);
        assertEq(IERC20(hook).totalSupply(), 0);
        vm.expectRevert();
        quad.previewSwapExactIn(address(token0), address(token1), 1 ether);
    }

    /// @notice Unfunded pretransfer must NOT treat inventory as free (raw leg).
    function test_pretransfer_unfunded_raw_reverts() public {
        _firstMintEqual(200 ether);
        // token1 is raw in default config; book holds face but free should be 0
        vm.expectRevert();
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(token1)),
            1 ether,
            IERC20(address(token2)),
            0,
            user,
            true, // pretransferred without free funding
            block.timestamp + 1
        );
    }

    /// @notice Unfunded pretransfer on SE face (no free pair on hook) reverts.
    function test_pretransfer_unfunded_seFace_reverts() public {
        _firstMintEqual(200 ether);
        // token0 is SE-buffered; free face on hook is 0 after buffer-last joins
        assertEq(token0.balanceOf(hook), 0, "no free SE face after join");
        vm.expectRevert();
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(token0)),
            1 ether,
            IERC20(address(token1)),
            0,
            user,
            true,
            block.timestamp + 1
        );
    }

    /// @notice Funded pretransfer (free face) succeeds and is bit-exact with preview.
    function test_pretransfer_funded_raw_previewEqualsExec() public {
        _firstMintEqual(500 ether);
        uint256 amountIn = 2 ether;
        uint256 preview = IStandardExchangeIn(hook).previewExchangeIn(
            IERC20(address(token1)), amountIn, IERC20(address(token2))
        );
        // pre-send free face (donation excess relative to intentional raw book)
        token1.mint(hook, amountIn);
        uint256 outBefore = token2.balanceOf(user);
        vm.prank(user);
        uint256 out = IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(token1)),
            amountIn,
            IERC20(address(token2)),
            0,
            user,
            true,
            block.timestamp + 1
        );
        assertEq(out, preview, "funded pretransfer preview==exec");
        assertEq(token2.balanceOf(user) - outBefore, out);
    }

    /// @notice Unfunded exchangeOut pretransfer reverts (raw in).
    function test_pretransfer_unfunded_exchangeOut_reverts() public {
        _firstMintEqual(200 ether);
        vm.expectRevert();
        IStandardExchangeOut(hook).exchangeOut(
            IERC20(address(token1)),
            type(uint256).max,
            IERC20(address(token2)),
            1 ether,
            user,
            true,
            block.timestamp + 1
        );
    }
}
