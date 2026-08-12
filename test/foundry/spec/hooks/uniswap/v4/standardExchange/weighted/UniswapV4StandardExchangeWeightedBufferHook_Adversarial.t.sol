// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {ModifyLiquidityParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookPairPoolLib.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {
    HostileReentrantERC20
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/HostileReentrantERC20.sol";

/**
 * @notice Catalog A–H residual + H17/O11: CL blocked, pre-live swap, full-book exit, reentrancy.
 * @dev Catalog A–H (WP-ADV-HOOK-001 residual) + I1/I3 pretransfer must not free-extract SE book
 *      (L-GAPS-11 / WP-I-HOOK-SEBUF-001). Deferred P2: G composition, fork MEV.
 */
contract UniswapV4StandardExchangeWeightedBufferHook_Adversarial is
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
{
    address internal attacker;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("attacker");
    }

    /* ---------------------------------------------------------------------- */
    /*  I1: booked inventory (R==B), no new unbooked push, pretransferred=true */
    /* ---------------------------------------------------------------------- */

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
        uint256 raw1Before_ = weighted.nativeReserve(1);

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
            block.timestamp + 1 hours
        );

        assertEq(token1.balanceOf(attacker), outAttBefore_, "I1: no free raw extract");
        assertEq(IERC20(se0).balanceOf(hook), se0Before_, "I1: SE book not free-spent");
        assertEq(token0.balanceOf(hook), faceBefore_, "I1: face inventory unmoved");
        assertEq(weighted.nativeReserve(1), raw1Before_, "I1: raw1 book intact");
    }

    /// @notice I1 raw→SE-face: booked free raw (post-mint R==B); true without new push reverts U=0.
    /// @dev L-RSRV-DUST: bare donation free-credits until sync — I1 is booked inventory only.
    function test_I1_pretransferred_rawToSeFace_inventoryNoInCallTransfer_revertsDelta0() public {
        _firstMintEqual(200 ether);
        uint256 claimed_ = 5 ether;
        // Seeded free raw is end-synced (booked). Absolute B may cover claimed; U must not.
        assertGe(token1.balanceOf(hook), claimed_, "booked raw inventory present");
        assertEq(token1.balanceOf(attacker), 0, "attacker empty");
        assertEq(token1.allowance(attacker, hook), 0, "no allowance");

        uint256 se0Before_ = IERC20(se0).balanceOf(hook);
        uint256 outAttBefore_ = token0.balanceOf(attacker);
        uint256 face1Before_ = token1.balanceOf(hook);
        uint256 raw1Before_ = weighted.nativeReserve(1);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(token1)),
            claimed_,
            IERC20(address(token0)),
            0,
            attacker,
            true,
            block.timestamp + 1 hours
        );

        assertEq(token0.balanceOf(attacker), outAttBefore_, "I1: no free SE-face extract");
        assertEq(IERC20(se0).balanceOf(hook), se0Before_, "I1: SE book not free-spent");
        assertEq(token1.balanceOf(hook), face1Before_, "I1: booked raw unmoved");
        assertEq(weighted.nativeReserve(1), raw1Before_, "I1: raw book intact");
    }

    /// @notice I1 exact-out: booked free raw (post-mint R==B); true without new push reverts U=0.
    /// @dev Do not bare-donate residual for theater — L-RSRV-DUST free-credits until booked.
    function test_I1_pretransferred_exchangeOut_revertsDelta0() public {
        _firstMintEqual(200 ether);
        uint256 wantOut_ = 1 ether;

        uint256 needIn_ = IStandardExchangeOut(hook).previewExchangeOut(
            IERC20(address(token1)), IERC20(address(token0)), wantOut_
        );
        assertGt(needIn_, 0);
        assertGe(token1.balanceOf(hook), needIn_, "booked inventory covers claimed amountIn");

        uint256 outAttBefore_ = token0.balanceOf(attacker);
        uint256 face1Before_ = token1.balanceOf(hook);
        uint256 se0Before_ = IERC20(se0).balanceOf(hook);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, needIn_, uint256(0)
            )
        );
        IStandardExchangeOut(hook).exchangeOut(
            IERC20(address(token1)),
            needIn_,
            IERC20(address(token0)),
            wantOut_,
            attacker,
            true,
            block.timestamp + 1 hours
        );

        assertEq(token0.balanceOf(attacker), outAttBefore_, "I1 out: no free extract");
        assertEq(token1.balanceOf(hook), face1Before_, "I1 out: booked raw unmoved");
        assertEq(IERC20(se0).balanceOf(hook), se0Before_, "I1 out: SE book intact");
    }

    /// @notice I3: after honest raw→SE-face, booked state (U=0) cannot fund free pretransfer.
    /// @dev Bare residual donate free-credits until full balanceOf end-sync (production gap vs CP).
    ///      I3 here proves post-honest booked inventory without unbooked residual face.
    function test_I3_residualInventory_cannotFundSecondFreePretransfer_rawToSeFace() public {
        _firstMintEqual(200 ether);

        uint256 honestIn_ = 3 ether;
        token1.mint(user, honestIn_);
        vm.startPrank(user);
        token1.approve(hook, honestIn_);
        uint256 out_ = IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(token1)),
            honestIn_,
            IERC20(address(token0)),
            0,
            user,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(out_, 0, "honest raw->SE-face ok");

        // After end-sync R tracks rawReserves (booked amountIn), not bare-donated dust.
        uint256 claimed_ = 4 ether;
        assertGe(token1.balanceOf(hook), claimed_, "booked raw inventory present");
        uint256 residual_ = token1.balanceOf(hook);
        uint256 se0Before_ = IERC20(se0).balanceOf(hook);
        uint256 outAttBefore_ = token0.balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(token1)),
            claimed_,
            IERC20(address(token0)),
            0,
            attacker,
            true,
            block.timestamp + 1 hours
        );

        assertEq(token1.balanceOf(hook), residual_, "I3 residual unmoved");
        assertEq(IERC20(se0).balanceOf(hook), se0Before_, "I3 SE book not free-spent");
        assertEq(token0.balanceOf(attacker), outAttBefore_, "I3 no free extract");
    }

    function test_ensurePairPools_permissionless() public {
        uint256 doors = weighted.ensurePairPools();
        assertEq(doors, 0);
        _assertAllDoorsLive();
    }

    /// @notice H1: pre-live swap preview reverts (no book).
    function test_H1_preLive_swapReverts() public {
        assertEq(IERC20(hook).totalSupply(), 0);
        vm.expectRevert();
        weighted.previewSwapExactIn(address(token0), address(token1), 1 ether);
    }

    /// @notice E2: first mint requires both legs (zero leg amount reverts).
    function test_E2_firstMint_requiresBothLegs() public {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10 ether;
        amounts[1] = 0;
        vm.prank(user);
        vm.expectRevert();
        weighted.joinProportional(amounts, user, 0, block.timestamp + 1 hours);
    }

    /// @notice E1: full-book exit cannot zero a leg.
    function test_E1_fullBook_exitCannotZeroLeg() public {
        uint256 shares = _firstMintEqual(100 ether);
        uint256[] memory mins = new uint256[](2);
        uint256 burn = shares / 4;
        vm.prank(user);
        weighted.exitProportional(burn, user, mins, block.timestamp + 1 hours);
        assertGt(weighted.nativeReserve(0), 0);
        assertGt(weighted.nativeReserve(1), 0);
        assertTrue(weighted.isFullBook());

        uint256 remaining = IERC20(hook).balanceOf(user);
        uint256 almostAll = remaining > 10 ? remaining - 1 : remaining;
        vm.prank(user);
        vm.expectRevert();
        weighted.exitSingleAssetExactBptIn(
            address(token1), almostAll, user, 0, block.timestamp + 1 hours
        );
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

    /// @notice C1: reentrancy-hostile raw ERC20 reenters depositSingle during transferFrom → nested Reentrancy.
    function test_C1_reentrancy_join_hitsReentrancy() public {
        // SE on SimpleMintable 18-dec; hostile is raw leg.
        SimpleMintableERC20 seToken = new SimpleMintableERC20("SEPair", "SEP");
        HostileReentrantERC20 hostile = new HostileReentrantERC20("Hostile", "HST");
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
        assertTrue(weighted.isFullBook());

        // Control: unarmed single-asset join on hostile succeeds
        vm.prank(user);
        uint256 okShares =
            weighted.depositSingle(address(hostile), 5 ether, user, 0, block.timestamp + 1 hours);
        assertGt(okShares, 0, "control depositSingle works");

        // Arm: reenter depositSingle mid transferFrom
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
        // Outer completes; nested must fail with Reentrancy
        weighted.depositSingle(address(hostile), 10 ether, user, 0, block.timestamp + 1 hours);

        assertEq(hostile.reentryAttempts(), 1, "nested reentry attempted once");
        assertFalse(hostile.nestedCallSucceeded(), "nested depositSingle must not succeed");
        assertEq(
            hostile.nestedErrorSelector(),
            bytes4(keccak256("Reentrancy()")),
            "nested must revert Reentrancy"
        );
        assertGe(IERC20(hook).balanceOf(user), lpBefore, "outer path continued after blocked reentry");
    }
}
