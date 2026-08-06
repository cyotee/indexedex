// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
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
 * @notice H17 / O11 adversarial: CL blocked, pre-live swap, full-book exit, reentrancy.
 */
contract UniswapV4StandardExchangeWeightedBufferHook_Adversarial is
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
{
    function test_ensurePairPools_permissionless() public {
        uint256 doors = weighted.ensurePairPools();
        assertEq(doors, 0);
        _assertAllDoorsLive();
    }

    function test_preLive_swapReverts() public {
        assertEq(IERC20(hook).totalSupply(), 0);
        vm.expectRevert();
        weighted.previewSwapExactIn(address(token0), address(token1), 1 ether);
    }

    function test_n2_firstMint_requiresBothLegs() public {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10 ether;
        amounts[1] = 0;
        vm.prank(user);
        vm.expectRevert();
        weighted.joinProportional(amounts, user, 0, block.timestamp + 1 hours);
    }

    function test_fullBook_exitCannotZeroLeg() public {
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

    /// @notice H17: reentrancy-hostile raw ERC20 reenters depositSingle during transferFrom → nested Reentrancy.
    function test_reentrancy_join_hitsReentrancy() public {
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
