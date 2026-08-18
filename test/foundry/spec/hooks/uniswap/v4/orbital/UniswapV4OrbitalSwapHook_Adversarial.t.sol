// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {CustomRevert} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/CustomRevert.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from
    "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {ModifyLiquidityParams, SwapParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {Proxy} from "@crane/contracts/proxies/Proxy.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {TestBase_UniswapV4OrbitalSwapHook} from
    "test/foundry/spec/hooks/uniswap/v4/orbital/TestBase_UniswapV4OrbitalSwapHook.sol";
import {
    UniswapV4OrbitalSwapHookRepo as Repo
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookRepo.sol";
import {
    UniswapV4OrbitalSwapHookTarget
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookTarget.sol";
import {
    IUniswapV4OrbitalSwapHook
} from "contracts/hooks/uniswap/v4/orbital/interfaces/IUniswapV4OrbitalSwapHook.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    IUniswapV4OrbitalSwapHookPackage
} from "contracts/hooks/uniswap/v4/orbital/interfaces/IUniswapV4OrbitalSwapHookPackage.sol";
import {
    UniswapV4OrbitalSwapHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookPairPoolLib.sol";

contract _OrbitalModifyLiqUnlock is IUnlockCallback {
    IPoolManager public immutable pm;

    constructor(IPoolManager pm_) {
        pm = pm_;
    }

    function go(PoolKey memory key) external {
        pm.unlock(abi.encode(key));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        PoolKey memory key = abi.decode(data, (PoolKey));
        pm.modifyLiquidity(
            key,
            ModifyLiquidityParams({tickLower: -60, tickUpper: 60, liquidityDelta: 1, salt: bytes32(0)}),
            ""
        );
        return "";
    }
}

/**
 * @title UniswapV4OrbitalSwapHook_Adversarial_Test
 * @notice Catalog A–H residual (WP-ADV-HOOK-001): donations ignored for pricing; R sticky; radius invariant.
 * @dev Deferred P2: G composition; fork MEV sandwich reconstructions.
 */
contract UniswapV4OrbitalSwapHook_Adversarial_Test is TestBase_UniswapV4OrbitalSwapHook {
    /// @notice A1: donations ignored for pricing / reserveOf (Repo SoT).
    function test_A1_donationsIgnored_reserveOfUnchanged() public {
        _seedThreeLeg(100 ether);
        uint256 r0 = orbital.reserveOf(address(token0));
        uint256 bal = token0.balanceOf(hook);

        token0.mint(hook, 50 ether);

        assertEq(orbital.reserveOf(address(token0)), r0, "Repo SoT ignores donations");
        assertEq(token0.balanceOf(hook), bal + 50 ether, "physical balance rose");

        (uint256 shares,,,) = orbital.previewAddLiquidity(10 ether, 10 ether, 10 ether);
        assertGt(shares, 0);
    }

    /// @notice E1: post-swap reserves strictly under radius (capacity invariant).
    function test_E1_postState_reservesStrictlyUnderRadius() public {
        _seedThreeLeg(100 ether);
        _setDexFee(0);
        for (uint256 i; i < 10; i++) {
            _swapExactIn(address(token0), address(token1), 2 ether);
            _swapExactIn(address(token1), address(token2), 2 ether);
            _swapExactIn(address(token2), address(token0), 2 ether);
        }
        uint256 R = orbital.radius();
        assertLt(orbital.reserveOf(address(token0)), R);
        assertLt(orbital.reserveOf(address(token1)), R);
        assertLt(orbital.reserveOf(address(token2)), R);
        // L² consistent with sphere parameter
        assertGt(orbital.lSquared(), 0);
    }

    /// @notice H1: full exit leaves R sticky + min dust; subsequent add works.
    function test_H1_fullExit_R_sticky_and_minDust() public {
        (uint256 shares,,,) = _addLiquidity(100 ether, 100 ether, 100 ether);
        uint256 userShares = IERC20(hook).balanceOf(user);
        assertEq(userShares, shares);

        uint256 R = orbital.radius();
        vm.prank(user);
        orbital.removeLiquidity(userShares, user, 0, 0, 0, block.timestamp + 1);

        assertEq(IERC20(hook).totalSupply(), Repo.MINIMUM_LIQUIDITY);
        assertEq(IERC20(hook).balanceOf(address(0)), Repo.MINIMUM_LIQUIDITY);
        assertEq(orbital.radius(), R);

        uint256 sumPos = orbital.reserveOf(address(token0)) + orbital.reserveOf(address(token1))
            + orbital.reserveOf(address(token2));
        assertGt(sumPos, 0);

        (uint256 s2,,,) = _addLiquidity(10 ether, 10 ether, 10 ether);
        assertGt(s2, 0);
        assertEq(orbital.radius(), R, "R still sticky after subsequent add");
    }

    /// @notice F3: hook flags include liquidity bans + swap surface.
    function test_F3_hookFlags_includeLiquidityBans() public view {
        uint160 flags = _requiredFlags();
        assertTrue(flags & Hooks.BEFORE_ADD_LIQUIDITY_FLAG != 0);
        assertTrue(flags & Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG != 0);
        assertTrue(flags & Hooks.BEFORE_SWAP_FLAG != 0);
        assertTrue(flags & Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG != 0);
    }

    function test_J_swapBeforeFinalize_unmatched() public {
        (address h, IUniswapV4HookStagedPairInit init, address t0, address t1,) = _freshBootstrap();
        assertEq(IDiamondLoupe(h).facetAddress(IHooks.beforeSwap.selector), address(0));
        PoolKey memory key = init.deployPair(t0, t1);
        SimpleMintableERC20(t0).mint(user, 10 ether);
        SimpleMintableERC20(t1).mint(user, 10 ether);
        vm.startPrank(user);
        SimpleMintableERC20(t0).approve(address(swapRouter), type(uint256).max);
        SimpleMintableERC20(t1).approve(address(swapRouter), type(uint256).max);
        bool zeroForOne = t0 == Currency.unwrap(key.currency0);
        vm.expectRevert();
        swapRouter.swapExactIn(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(1 ether),
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            ""
        );
        vm.stopPrank();
    }

    function test_J_addLiquidityBeforeFinalize_unmatched() public {
        (address h,,,,) = _freshBootstrap();
        assertEq(
            IDiamondLoupe(h).facetAddress(IUniswapV4OrbitalSwapHook.addLiquidity.selector),
            address(0)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                Proxy.NoTargetFor.selector, IUniswapV4OrbitalSwapHook.addLiquidity.selector
            )
        );
        IUniswapV4OrbitalSwapHook(h).addLiquidity(1, 1, 1, user, 0, block.timestamp + 1, "");
    }

    function test_J_modifyLiquidityBeforeFinalize() public {
        (address h, IUniswapV4HookStagedPairInit init, address t0, address t1,) = _freshBootstrap();
        assertEq(IDiamondLoupe(h).facetAddress(IHooks.beforeAddLiquidity.selector), address(0));
        PoolKey memory key = init.deployPair(t0, t1);
        _OrbitalModifyLiqUnlock caller = new _OrbitalModifyLiqUnlock(pm);
        bytes memory hookReason =
            abi.encodeWithSelector(Proxy.NoTargetFor.selector, IHooks.beforeAddLiquidity.selector);
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                h,
                IHooks.beforeAddLiquidity.selector,
                hookReason,
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        caller.go(key);
    }

    function test_J_afterFinalize_noInitSelectors() public view {
        IDiamondLoupe loupe = IDiamondLoupe(hook);
        assertEq(loupe.facetAddress(IUniswapV4HookStagedPairInit.deployPair.selector), address(0));
        assertEq(
            loupe.facetAddress(IUniswapV4HookStagedPairInit.finalizeInitialization.selector),
            address(0)
        );
        assertEq(loupe.facetAddress(IUniswapV4HookStagedPairInit.isPairPoolLive.selector), address(0));
        assertEq(loupe.facetAddress(IUniswapV4HookStagedPairInit.pairPoolKey.selector), address(0));
        assertEq(
            loupe.facetAddress(IUniswapV4HookStagedPairInit.isInitializationFinalized.selector),
            address(0)
        );
        assertEq(loupe.facetAddress(IHooks.beforeInitialize.selector), address(hookPkg.HOOKS_FACET()));
    }

    function test_J_afterFinalize_noDiamondCut() public view {
        bytes4 cutSel = bytes4(keccak256("diamondCut((address,uint8,bytes4[])[],address,bytes)"));
        assertEq(IDiamondLoupe(hook).facetAddress(cutSel), address(0));
    }

    function test_beforeInitialize_sameChecks_afterFinalize() public {
        PoolKey memory badFee = poolKey01;
        badFee.fee = 3000;
        vm.prank(address(pm));
        vm.expectRevert(UniswapV4OrbitalSwapHookTarget.InvalidPoolFee.selector);
        IHooks(hook).beforeInitialize(address(this), badFee, TickMath.getSqrtPriceAtTick(0));

        PoolKey memory unbound =
            PairPoolLib.pairKey(address(token0), address(0xB0B0), 60, IHooks(hook));
        vm.prank(address(pm));
        vm.expectRevert(UniswapV4OrbitalSwapHookTarget.InvalidPoolToken.selector);
        IHooks(hook).beforeInitialize(address(this), unbound, TickMath.getSqrtPriceAtTick(0));
    }

    function test_permissionlessFinalizeRace() public {
        (, IUniswapV4HookStagedPairInit init, address t0, address t1, address t2) = _freshBootstrap();
        init.deployPair(t0, t1);
        init.deployPair(t1, t2);
        init.deployPair(t0, t2);
        address a1 = address(0xA11CE);
        address a2 = address(0xA22CE);
        vm.prank(a1);
        assertTrue(init.finalizeInitialization());
        vm.prank(a2);
        vm.expectRevert(
            abi.encodeWithSelector(
                Proxy.NoTargetFor.selector,
                IUniswapV4HookStagedPairInit.finalizeInitialization.selector
            )
        );
        init.finalizeInitialization();
    }

    function _freshBootstrap()
        internal
        returns (
            address h,
            IUniswapV4HookStagedPairInit init,
            address t0,
            address t1,
            address t2
        )
    {
        SimpleMintableERC20 a = new SimpleMintableERC20("JA", "JA");
        SimpleMintableERC20 b = new SimpleMintableERC20("JB", "JB");
        SimpleMintableERC20 c = new SimpleMintableERC20("JC", "JC");
        t0 = address(a);
        t1 = address(b);
        t2 = address(c);
        IUniswapV4OrbitalSwapHookPackage.PkgArgs memory args = IUniswapV4OrbitalSwapHookPackage.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(indexedexManager),
            token0: t0,
            token1: t1,
            token2: t2,
            tickSpacing: 0,
            sqrtPriceX96: 0
        });
        h = _deployBootstrapOnly(args);
        init = IUniswapV4HookStagedPairInit(h);
    }
}
