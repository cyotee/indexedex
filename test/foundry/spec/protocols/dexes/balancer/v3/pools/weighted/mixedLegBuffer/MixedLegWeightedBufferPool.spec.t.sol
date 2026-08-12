// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IHooks} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IHooks.sol";
import {HookFlags} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IPoolLiquidity} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IPoolLiquidity.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IMixedLegWeightedBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/IMixedLegWeightedBufferPool.sol";
import {
    IMixedLegWeightedBufferPoolPkg
} from "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/MixedLegWeightedBufferPoolStandardVaultPkg.sol";

import {
    TestBase_MixedLegWeightedBufferPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/bases/TestBase_MixedLegWeightedBufferPool.sol";

/**
 * @title MixedLegWeightedBufferPoolSpec
 * @notice Default fixture: U=2 unpaired + P=1 pair (4 tokens). Registration, uniqueness, swaps, CUSTOM.
 */
contract MixedLegWeightedBufferPoolSpec is TestBase_MixedLegWeightedBufferPool {
    /* ----- Registration / init ----- */

    function test_deploy_mixed_U2_P1() public view {
        assertEq(ml().unpairedCount(), 2);
        assertEq(ml().pairCount(), 1);
        assertEq(ml().tokenCount(), 4);
        assertEq(address(ml().bufferToken(0)), address(dai));
        assertEq(address(ml().shareToken(0)), address(seVault));
        assertEq(address(ml().unpairedToken(0)), address(usdc));
        assertEq(address(ml().unpairedToken(1)), address(weth));
    }

    function test_hooksContract_isPool() public view {
        HookFlags memory hf = IHooks(mixedLegPool).getHookFlags();
        assertTrue(hf.shouldCallBeforeSwap);
        assertTrue(hf.shouldCallAfterSwap);
        assertTrue(hf.shouldCallBeforeInitialize);
    }

    function test_init_virtualBuffer_fromBufferSeed() public view {
        assertEq(ml().virtualBuffer(0), ML_INIT_BUFFER);
        assertEq(ml().hookShareDelta(0), 0);
    }

    function test_weights_sumToOne() public view {
        uint256 n = ml().tokenCount();
        uint256 sum;
        for (uint256 i; i < n; ++i) {
            sum += ml().weight(i);
        }
        assertEq(sum, 1e18);
    }

    function test_resolveTokenIndex_kinds() public view {
        uint256 n = ml().tokenCount();
        uint256 unpairedSeen;
        uint256 bufferSeen;
        uint256 shareSeen;
        for (uint256 t; t < n; ++t) {
            (IMixedLegWeightedBufferPool.TokenKind kind,) = ml().resolveTokenIndex(t);
            if (kind == IMixedLegWeightedBufferPool.TokenKind.Unpaired) ++unpairedSeen;
            else if (kind == IMixedLegWeightedBufferPool.TokenKind.Buffer) ++bufferSeen;
            else ++shareSeen;
        }
        assertEq(unpairedSeen, 2);
        assertEq(bufferSeen, 1);
        assertEq(shareSeen, 1);
    }

    /* ----- Uniqueness ----- */

    function test_reject_unpairedEqualsBuffer() public {
        // unpaired USDC + pair buffer USDC would collide if we force it - use DAI as unpaired + DAI buffer.
        IERC20[] memory unpaired = new IERC20[](1);
        IRateProvider[] memory unpairedRps = new IRateProvider[](1);
        unpaired[0] = IERC20(address(dai)); // same as buffer
        unpairedRps[0] = IRateProvider(address(0));

        IERC20[] memory buffers = new IERC20[](1);
        IStandardExchange[] memory vaults = new IStandardExchange[](1);
        IRateProvider[] memory pairRps = new IRateProvider[](1);
        buffers[0] = IERC20(address(dai));
        vaults[0] = IStandardExchange(address(seVault));
        pairRps[0] = IRateProvider(address(0));

        uint256[] memory weights = new uint256[](3);
        weights[0] = 0.34e18;
        weights[1] = 0.33e18;
        weights[2] = 0.33e18;

        IMixedLegWeightedBufferPoolPkg.PkgArgs memory args = IMixedLegWeightedBufferPoolPkg.PkgArgs({
            unpairedCount: 1,
            unpairedTokens: unpaired,
            unpairedRateProviders: unpairedRps,
            pairCount: 1,
            bufferTokens: buffers,
            standardExchangeVaults: vaults,
            pairRateProviders: pairRps,
            weights: weights
        });

        vm.expectRevert(
            abi.encodeWithSelector(IMixedLegWeightedBufferPool.DuplicatePoolToken.selector, address(dai))
        );
        mixedLegPkg.deployPool(args);
    }

    function test_reject_unpairedEqualsShare() public {
        IERC20[] memory unpaired = new IERC20[](1);
        IRateProvider[] memory unpairedRps = new IRateProvider[](1);
        unpaired[0] = IERC20(address(seVault)); // same as share
        unpairedRps[0] = IRateProvider(address(0));

        IERC20[] memory buffers = new IERC20[](1);
        IStandardExchange[] memory vaults = new IStandardExchange[](1);
        IRateProvider[] memory pairRps = new IRateProvider[](1);
        buffers[0] = IERC20(address(dai));
        vaults[0] = IStandardExchange(address(seVault));
        pairRps[0] = IRateProvider(address(0));

        uint256[] memory weights = new uint256[](3);
        weights[0] = 0.34e18;
        weights[1] = 0.33e18;
        weights[2] = 0.33e18;

        IMixedLegWeightedBufferPoolPkg.PkgArgs memory args = IMixedLegWeightedBufferPoolPkg.PkgArgs({
            unpairedCount: 1,
            unpairedTokens: unpaired,
            unpairedRateProviders: unpairedRps,
            pairCount: 1,
            bufferTokens: buffers,
            standardExchangeVaults: vaults,
            pairRateProviders: pairRps,
            weights: weights
        });

        vm.expectRevert(
            abi.encodeWithSelector(IMixedLegWeightedBufferPool.DuplicatePoolToken.selector, address(seVault))
        );
        mixedLegPkg.deployPool(args);
    }

    function test_reject_invalidLayout_tooFew() public {
        IERC20[] memory unpaired = new IERC20[](1);
        IRateProvider[] memory unpairedRps = new IRateProvider[](1);
        unpaired[0] = IERC20(address(usdc));
        unpairedRps[0] = IRateProvider(address(0));
        IERC20[] memory buffers = new IERC20[](0);
        IStandardExchange[] memory vaults = new IStandardExchange[](0);
        IRateProvider[] memory pairRps = new IRateProvider[](0);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 1e18;

        IMixedLegWeightedBufferPoolPkg.PkgArgs memory args = IMixedLegWeightedBufferPoolPkg.PkgArgs({
            unpairedCount: 1,
            unpairedTokens: unpaired,
            unpairedRateProviders: unpairedRps,
            pairCount: 0,
            bufferTokens: buffers,
            standardExchangeVaults: vaults,
            pairRateProviders: pairRps,
            weights: weights
        });

        vm.expectRevert(abi.encodeWithSelector(IMixedLegWeightedBufferPool.InvalidTokenLayout.selector, uint8(1), uint8(0)));
        mixedLegPkg.deployPool(args);
    }

    /* ----- Swaps: unpaired ↔ unpaired (no buffer SE) ----- */

    function test_swap_unpairedToUnpaired_exactIn() public {
        uint256 amountIn = 10e18;
        usdc.mint(alice, amountIn);
        vm.prank(alice);
        usdc.approve(address(permit2), type(uint256).max);

        uint256 wethBefore = weth.balanceOf(alice);
        uint256 out = swapExactIn(alice, IERC20(address(usdc)), IERC20(address(weth)), amountIn);
        assertGt(out, 0);
        assertEq(weth.balanceOf(alice), wethBefore + out);
        // pair virtual unchanged (no buffer I/O)
        assertEq(ml().virtualBuffer(0), ML_INIT_BUFFER);
    }

    /* ----- Swaps: unpaired → buffer (pre-seat) ----- */

    function test_swap_unpairedToBuffer_exactIn() public {
        uint256 amountIn = 10e18;
        usdc.mint(alice, amountIn);
        vm.prank(alice);
        usdc.approve(address(permit2), type(uint256).max);

        uint256 daiBefore = dai.balanceOf(alice);
        uint256 vtBefore = ml().virtualBuffer(0);
        uint256 out = swapExactIn(alice, IERC20(address(usdc)), IERC20(address(dai)), amountIn);
        assertGt(out, 0);
        assertEq(dai.balanceOf(alice), daiBefore + out);
        assertLt(ml().virtualBuffer(0), vtBefore);
    }

    /* ----- Swaps: buffer → unpaired (reconcile) ----- */

    function test_swap_bufferToUnpaired_exactIn() public {
        uint256 amountIn = 10e18;
        dai.mint(alice, amountIn);
        vm.prank(alice);
        dai.approve(address(permit2), type(uint256).max);

        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 vtBefore = ml().virtualBuffer(0);
        uint256 out = swapExactIn(alice, IERC20(address(dai)), IERC20(address(usdc)), amountIn);
        assertGt(out, 0);
        assertEq(usdc.balanceOf(alice), usdcBefore + out);
        assertGe(ml().virtualBuffer(0), vtBefore);
    }

    /* ----- Swaps: buffer ↔ shares (pair-local, same as multi-pair) ----- */

    function test_swap_bufferToShares_exactIn() public {
        uint256 amountIn = 10e18;
        dai.mint(alice, amountIn);
        vm.prank(alice);
        dai.approve(address(permit2), type(uint256).max);

        uint256 sharesBefore = IERC20(address(seVault)).balanceOf(alice);
        uint256 out = swapExactIn(alice, IERC20(address(dai)), IERC20(address(seVault)), amountIn);
        assertGt(out, 0);
        assertEq(IERC20(address(seVault)).balanceOf(alice), sharesBefore + out);
        assertGe(ml().virtualBuffer(0), ML_INIT_BUFFER);
    }

    function test_swap_sharesToBuffer_exactIn() public {
        uint256 amountIn = 5e18;
        mintSharesForPair(0, alice, amountIn * 2);
        uint256 daiBefore = dai.balanceOf(alice);
        uint256 out = swapExactIn(alice, IERC20(address(seVault)), IERC20(address(dai)), amountIn);
        assertGt(out, 0);
        assertEq(dai.balanceOf(alice), daiBefore + out);
        assertLt(ml().virtualBuffer(0), ML_INIT_BUFFER);
    }

    /* ----- CUSTOM NotHookCaller ----- */

    function test_customRemove_revertsNotHookCaller() public {
        uint256[] memory minOut = new uint256[](4);
        minOut[0] = 1;
        minOut[1] = 1;
        minOut[2] = 1;
        minOut[3] = 1;
        vm.expectRevert(
            abi.encodeWithSelector(IMixedLegWeightedBufferPool.NotHookCaller.selector, address(this))
        );
        IPoolLiquidity(mixedLegPool).onRemoveLiquidityCustom(address(this), 0, minOut, minOut, "");
    }

    function test_customAdd_revertsNotHookCaller() public {
        uint256[] memory maxIn = new uint256[](4);
        maxIn[0] = 1;
        maxIn[1] = 1;
        maxIn[2] = 1;
        maxIn[3] = 1;
        vm.expectRevert(
            abi.encodeWithSelector(IMixedLegWeightedBufferPool.NotHookCaller.selector, address(0xBEEF))
        );
        IPoolLiquidity(mixedLegPool).onAddLiquidityCustom(address(0xBEEF), maxIn, 0, maxIn, "");
    }

    /* ----- LP proportional scales virtual ----- */

    function test_lp_addProportional_scalesVirtual() public {
        uint256 vtBefore = ml().virtualBuffer(0);
        mintSharesForPair(0, alice, ML_INIT_SHARES * 2);
        dai.mint(alice, ML_INIT_BUFFER * 2);
        usdc.mint(alice, ML_INIT_UNPAIRED * 2);
        _mintToken(address(weth), alice, ML_INIT_UNPAIRED * 2);

        uint256 n = ml().tokenCount();
        uint256[] memory maxAmts = new uint256[](n);
        for (uint256 t; t < n; ++t) {
            (IMixedLegWeightedBufferPool.TokenKind kind,) = ml().resolveTokenIndex(t);
            if (kind == IMixedLegWeightedBufferPool.TokenKind.Unpaired) maxAmts[t] = ML_INIT_UNPAIRED;
            else if (kind == IMixedLegWeightedBufferPool.TokenKind.Buffer) maxAmts[t] = ML_INIT_BUFFER;
            else maxAmts[t] = ML_INIT_SHARES;
        }

        uint256 bptOut = IERC20(mixedLegPool).totalSupply() / 10;
        vm.startPrank(alice);
        dai.approve(address(router), type(uint256).max);
        usdc.approve(address(router), type(uint256).max);
        IERC20(address(weth)).approve(address(router), type(uint256).max);
        IERC20(address(seVault)).approve(address(router), type(uint256).max);
        router.addLiquidityProportional(mixedLegPool, maxAmts, bptOut, false, bytes(""));
        vm.stopPrank();

        assertGt(ml().virtualBuffer(0), vtBefore);
    }
}
