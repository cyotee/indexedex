// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
import {
    IUniswapV4StandardExchangeBalancerQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {ModifyLiquidityParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookPairPoolLib.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {RateProviderMock} from "contracts/test/balancer/v3/RateProviderMock.sol";
import {
    HostileReentrantERC20
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/HostileReentrantERC20.sol";

/**
 * @dev Catalog A–H residual (WP-ADV-HOOK-001) + I1/I3 pretransfer must not free-extract SE book
 *      (L-GAPS-11 / WP-I-HOOK-SEBUF-001). Deferred P2: G composition, fork MEV.
 */
contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_Adversarial is TestBase {
    address internal attacker;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("attacker");
    }

    /// @notice A1: SE share donation dilutes subsequent join (no free LP credit).
    function test_A1_donation_seShares_dilutesJoin() public {
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

    /// @notice E1: full-book exit cannot zero a leg.
    function test_E1_fullBook_exitCannotZeroLeg() public {
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

    /// @notice H3: native CL addLiquidity always blocked.
    function test_H3_clAddLiquidity_blocked() public {
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

    /// @notice H4: native CL donate blocked.
    function test_H4_clDonate_blocked() public {
        _firstMintEqual(50 ether);
        PoolKey memory key = PairPoolLib.pairKey(address(token0), address(token1), 1, IHooks(hook));
        vm.prank(address(pm));
        vm.expectRevert();
        IHooks(hook).beforeDonate(address(this), key, 1, 1, "");
    }

    /// @notice C1: reentrancy-hostile raw ERC20 reenters depositSingle during transferFrom → nested fail.
    function test_C1_reentrancy_join_hitsReentrancy() public {
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
            IUniswapV4StandardExchangeBalancerQuadStableBufferHook.depositSingle.selector,
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

    /// @notice B1: feeTo growth mint increases feeTo LP balance.
    function test_B1_feeTo_growthMintIncreasesBalance() public {
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

    /// @notice H1: pre-live swap preview reverts.
    function test_H1_preLive_swapReverts() public {
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

    /* ---------------------------------------------------------------------- */
    /*  I1: booked inventory (R==B), no new unbooked push, pretransferred=true */
    /* ---------------------------------------------------------------------- */

    /// @notice I1 raw→raw: booked free raw (post-mint R==B); true without new push reverts U=0.
    /// @dev L-RSRV-DUST: bare donation free-credits until sync — I1 is booked inventory only.
    function test_I1_pretransferred_rawToRaw_inventoryNoInCallTransfer_revertsDelta0() public {
        _firstMintEqual(200 ether);
        uint256 claimed_ = 5 ether;
        // Seeded free raw is end-synced (booked). Absolute B may cover claimed; U must not.
        assertGe(token1.balanceOf(hook), claimed_, "booked raw inventory present");
        assertEq(token1.balanceOf(attacker), 0, "attacker empty");
        assertEq(token1.allowance(attacker, hook), 0, "no allowance");

        uint256 outAttBefore_ = token2.balanceOf(attacker);
        uint256 face1Before_ = token1.balanceOf(hook);
        uint256 n2Before_ = quad.nativeReserve(2);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(token1)),
            claimed_,
            IERC20(address(token2)),
            0,
            attacker,
            true,
            block.timestamp + 1
        );

        assertEq(token2.balanceOf(attacker), outAttBefore_, "I1: no free extract");
        assertEq(token1.balanceOf(hook), face1Before_, "I1: booked raw unmoved");
        assertEq(quad.nativeReserve(2), n2Before_, "I1: book not free-spent");
    }

    /// @notice I1 SE-face→raw: no unbooked face (virtual seClaim R); true without push reverts U=0.
    /// @dev Do not donate SE face — free face is intentional unbooked U (L-RSRV-DUST).
    function test_I1_pretransferred_seFaceToRaw_inventoryNoInCallTransfer_revertsDelta0() public {
        _firstMintEqual(200 ether);
        uint256 claimed_ = 5 ether;
        // token0 is SE-buffered — do not donate face (that would free-credit under virtual R).
        assertEq(token0.balanceOf(attacker), 0, "attacker empty");
        assertEq(token0.allowance(attacker, hook), 0);

        uint256 se0Before_ = IERC20(se0).balanceOf(hook);
        uint256 outAttBefore_ = token1.balanceOf(attacker);
        uint256 faceBefore_ = token0.balanceOf(hook);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(token0)),
            claimed_,
            IERC20(address(token1)),
            0,
            attacker,
            true,
            block.timestamp + 1
        );

        assertEq(token1.balanceOf(attacker), outAttBefore_, "I1: no free raw extract");
        assertEq(IERC20(se0).balanceOf(hook), se0Before_, "I1: SE book not free-spent");
        assertEq(token0.balanceOf(hook), faceBefore_, "I1: face inventory unmoved");
    }

    /// @notice I1 exact-out: booked free raw (post-mint R==B); true without new push reverts U=0.
    /// @dev Do not bare-donate residual for theater — L-RSRV-DUST free-credits until booked.
    function test_I1_pretransferred_exchangeOut_revertsDelta0() public {
        _firstMintEqual(200 ether);
        uint256 wantOut_ = 1 ether;

        uint256 needIn_ = IStandardExchangeOut(hook).previewExchangeOut(
            IERC20(address(token1)), IERC20(address(token2)), wantOut_
        );
        assertGt(needIn_, 0);
        assertGe(token1.balanceOf(hook), needIn_, "booked inventory covers claimed amountIn");

        uint256 outAttBefore_ = token2.balanceOf(attacker);
        uint256 face1Before_ = token1.balanceOf(hook);
        uint256 n2Before_ = quad.nativeReserve(2);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, needIn_, uint256(0)
            )
        );
        IStandardExchangeOut(hook).exchangeOut(
            IERC20(address(token1)),
            needIn_,
            IERC20(address(token2)),
            wantOut_,
            attacker,
            true,
            block.timestamp + 1
        );

        assertEq(token2.balanceOf(attacker), outAttBefore_, "I1 out: no free extract");
        assertEq(token1.balanceOf(hook), face1Before_, "I1 out: booked raw unmoved");
        assertEq(quad.nativeReserve(2), n2Before_, "I1 out: book intact");
    }

    /// @notice I3: after honest raw→raw, booked state (U=0) cannot fund free pretransfer.
    /// @dev Bare residual donate free-credits until full balanceOf end-sync (production gap vs CP).
    ///      I3 here proves post-honest booked inventory without unbooked residual face.
    function test_I3_residualInventory_cannotFundSecondFreePretransfer_rawToRaw() public {
        _firstMintEqual(200 ether);

        uint256 honestIn_ = 3 ether;
        token1.mint(user, honestIn_);
        vm.startPrank(user);
        token1.approve(hook, honestIn_);
        uint256 out_ = IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(token1)),
            honestIn_,
            IERC20(address(token2)),
            0,
            user,
            false,
            block.timestamp + 1
        );
        vm.stopPrank();
        assertGt(out_, 0, "honest raw->raw ok");

        // After end-sync R tracks rawReserves (booked amountIn), not bare-donated dust.
        uint256 claimed_ = 4 ether;
        assertGe(token1.balanceOf(hook), claimed_, "booked raw inventory present");
        uint256 residual_ = token1.balanceOf(hook);
        uint256 n2Before_ = quad.nativeReserve(2);
        uint256 outAttBefore_ = token2.balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(token1)),
            claimed_,
            IERC20(address(token2)),
            0,
            attacker,
            true,
            block.timestamp + 1
        );

        assertEq(token1.balanceOf(hook), residual_, "I3 residual unmoved");
        assertEq(quad.nativeReserve(2), n2Before_, "I3 book not free-spent");
        assertEq(token2.balanceOf(attacker), outAttBefore_, "I3 no free extract");
    }

    /// @notice Unfunded pretransfer must NOT treat booked inventory as free (raw leg).
    function test_pretransfer_unfunded_raw_reverts() public {
        _firstMintEqual(200 ether);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, uint256(1 ether), uint256(0)
            )
        );
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(token1)),
            1 ether,
            IERC20(address(token2)),
            0,
            user,
            true,
            block.timestamp + 1
        );
    }

    /// @notice Unfunded pretransfer on SE face reverts (no unbooked face after join).
    function test_pretransfer_unfunded_seFace_reverts() public {
        _firstMintEqual(200 ether);
        assertEq(token0.balanceOf(hook), 0, "no free SE face after join");
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, uint256(1 ether), uint256(0)
            )
        );
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

    /// @notice I1 booked free raw: absolute inventory may cover claimed but U=0 without new push.
    /// @dev L-RSRV-DUST: bare donation free-credits until sync — I1 is booked inventory only.
    function test_I1_pretransfer_donatedFreeInventory_revertsDelta0() public {
        _firstMintEqual(500 ether);
        uint256 amountIn = 2 ether;
        // Post-mint raw is end-synced (booked). Do not bare-donate (that would free-credit).
        assertGe(token1.balanceOf(hook), amountIn, "booked inventory covers claimed");
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, amountIn, uint256(0)
            )
        );
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(token1)),
            amountIn,
            IERC20(address(token2)),
            0,
            user,
            true,
            block.timestamp + 1
        );
    }

    /// @notice Unfunded exchangeOut pretransfer reverts (raw in, booked inventory U=0).
    function test_pretransfer_unfunded_exchangeOut_reverts() public {
        _firstMintEqual(200 ether);
        uint256 need_ = IStandardExchangeOut(hook).previewExchangeOut(
            IERC20(address(token1)), IERC20(address(token2)), 1 ether
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, need_, uint256(0)
            )
        );
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
