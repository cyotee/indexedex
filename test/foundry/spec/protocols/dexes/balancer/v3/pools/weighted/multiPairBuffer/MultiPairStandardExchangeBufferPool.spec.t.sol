// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IHooks} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IHooks.sol";
import {HookFlags} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IPoolLiquidity} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IPoolLiquidity.sol";

import {IMultiPairStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/IMultiPairStandardExchangeBufferPool.sol";
import {
    IMultiPairStandardExchangeBufferPoolPkg
} from "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/MultiPairStandardExchangeBufferPoolStandardVaultPkg.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";

import {
    TestBase_MultiPairStandardExchangeBufferPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/bases/TestBase_MultiPairStandardExchangeBufferPool.sol";

/**
 * @title MultiPairStandardExchangeBufferPoolSpec
 * @notice Core registration, init, swap, LP, uniqueness, and hooks-in-proxy tests.
 */
contract MultiPairStandardExchangeBufferPoolSpec is TestBase_MultiPairStandardExchangeBufferPool {
    /* ----- Registration / init ----- */

    function test_deploy_pairCount1() public view {
        assertEq(mp().pairCount(), 1);
        assertEq(mp().tokenCount(), 2);
        assertEq(address(mp().bufferToken(0)), address(tta));
        assertEq(address(mp().shareToken(0)), address(seVault));
        assertEq(address(mp().standardExchangeVault(0)), address(seVault));
    }

    function test_hooksContract_isPool() public view {
        // Hook facet on same diamond: getHookFlags callable on pool (L5).
        HookFlags memory hf = IHooks(multiPairPool).getHookFlags();
        assertTrue(hf.shouldCallBeforeSwap);
        assertTrue(hf.shouldCallAfterSwap);
        assertTrue(hf.shouldCallBeforeInitialize);
    }

    function test_init_virtualBuffer_fromBufferSeed() public view {
        // L25: virtualBuffer matches buffer-leg scaled18 seed (STANDARD 18-dec ≈ raw).
        assertEq(mp().virtualBuffer(0), MP_INIT_BUFFER);
        assertEq(mp().hookShareDelta(0), 0);
    }

    function test_weights_sumToOne() public view {
        uint256 sum = mp().weight(0) + mp().weight(1);
        assertEq(sum, 1e18);
    }

    /* ----- Uniqueness ----- */

    function test_reject_duplicateBufferToken() public {
        IERC20[] memory buffers = new IERC20[](2);
        IStandardExchange[] memory vaults = new IStandardExchange[](2);
        IRateProvider[] memory rps = new IRateProvider[](2);
        buffers[0] = tta;
        buffers[1] = tta; // duplicate
        vaults[0] = IStandardExchange(address(seVault));
        // need a different vault address - use a fake distinct address that won't fully deploy
        // For processArgs validation only, call via deploy which hits processArgs.
        // Use bob as fake vault address for uniqueness check at processArgs.
        vaults[1] = IStandardExchange(bob);
        rps[0] = IRateProvider(address(0));
        rps[1] = IRateProvider(address(0));
        uint256[] memory weights = new uint256[](4);
        weights[0] = 0.25e18;
        weights[1] = 0.25e18;
        weights[2] = 0.25e18;
        weights[3] = 0.25e18;

        IMultiPairStandardExchangeBufferPoolPkg.PkgArgs memory args = IMultiPairStandardExchangeBufferPoolPkg.PkgArgs({
            pairCount: 2,
            bufferTokens: buffers,
            standardExchangeVaults: vaults,
            rateProviders: rps,
            weights: weights
        });

        vm.expectRevert(
            abi.encodeWithSelector(IMultiPairStandardExchangeBufferPool.DuplicateBufferToken.selector, address(tta))
        );
        multiPairPkg.deployPool(args);
    }

    function test_reject_duplicateVault() public {
        IERC20[] memory buffers = new IERC20[](2);
        IStandardExchange[] memory vaults = new IStandardExchange[](2);
        IRateProvider[] memory rps = new IRateProvider[](2);
        buffers[0] = tta;
        buffers[1] = ttb; // distinct buffer
        vaults[0] = IStandardExchange(address(seVault));
        vaults[1] = IStandardExchange(address(seVault)); // duplicate vault
        rps[0] = IRateProvider(address(0));
        rps[1] = IRateProvider(address(0));
        uint256[] memory weights = new uint256[](4);
        for (uint256 i; i < 4; ++i) weights[i] = 0.25e18;

        IMultiPairStandardExchangeBufferPoolPkg.PkgArgs memory args = IMultiPairStandardExchangeBufferPoolPkg.PkgArgs({
            pairCount: 2,
            bufferTokens: buffers,
            standardExchangeVaults: vaults,
            rateProviders: rps,
            weights: weights
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IMultiPairStandardExchangeBufferPool.DuplicateVaultShare.selector, address(seVault)
            )
        );
        multiPairPkg.deployPool(args);
    }

    /* ----- Swaps within pair ----- */

    function test_swap_bufferToShares_exactIn() public {
        uint256 amountIn = 10e18;
        dai.mint(alice, amountIn);
        vm.prank(alice);
        dai.approve(address(permit2), type(uint256).max);
        // permit2 already approved for router in base setUp for dai

        uint256 sharesBefore = IERC20(address(seVault)).balanceOf(alice);
        uint256 out = swapExactIn(alice, tta, IERC20(address(seVault)), amountIn);
        assertGt(out, 0);
        assertEq(IERC20(address(seVault)).balanceOf(alice), sharesBefore + out);
        // eventual-zero physical buffer on pool (approx)
        uint256 poolDai = dai.balanceOf(address(bv3Vault)); // vault holds pooled tokens
        // After reconcile, pool's registered buffer balance should be ~0 for this pool's accounting;
        // check virtual grew
        assertGe(mp().virtualBuffer(0), MP_INIT_BUFFER);
    }

    function test_swap_sharesToBuffer_exactIn() public {
        uint256 amountIn = 5e18;
        // ensure alice has shares
        mintShares(alice, amountIn * 2);
        uint256 daiBefore = dai.balanceOf(alice);
        uint256 out = swapExactIn(alice, IERC20(address(seVault)), tta, amountIn);
        assertGt(out, 0);
        assertEq(dai.balanceOf(alice), daiBefore + out);
        assertLt(mp().virtualBuffer(0), MP_INIT_BUFFER);
    }

    /* ----- LP proportional ----- */

    function test_lp_addProportional_scalesVirtual() public {
        uint256 vtBefore = mp().virtualBuffer(0);
        mintShares(alice, MP_INIT_SHARES * 2);
        dai.mint(alice, MP_INIT_BUFFER * 2);

        IMultiPairStandardExchangeBufferPool p = mp();
        uint256 bIdx = p.bufferIndex(0);
        uint256 sIdx = p.shareIndex(0);
        uint256[] memory maxAmts = new uint256[](2);
        maxAmts[bIdx] = MP_INIT_BUFFER;
        maxAmts[sIdx] = MP_INIT_SHARES;

        uint256 bptOut = IERC20(multiPairPool).totalSupply() / 10; // 10% more
        vm.startPrank(alice);
        IERC20(address(dai)).approve(address(router), type(uint256).max);
        IERC20(address(seVault)).approve(address(router), type(uint256).max);
        router.addLiquidityProportional(multiPairPool, maxAmts, bptOut, false, bytes(""));
        vm.stopPrank();

        assertGt(mp().virtualBuffer(0), vtBefore);
    }

    /* ----- CUSTOM NotHookCaller ----- */

    function test_customRemove_revertsNotHookCaller() public {
        uint256[] memory minOut = new uint256[](2);
        minOut[0] = 1;
        minOut[1] = 1;
        vm.expectRevert(
            abi.encodeWithSelector(IMultiPairStandardExchangeBufferPool.NotHookCaller.selector, address(this))
        );
        IPoolLiquidity(multiPairPool).onRemoveLiquidityCustom(address(this), 0, minOut, minOut, "");
    }

    function test_customAdd_revertsNotHookCaller() public {
        uint256[] memory maxIn = new uint256[](2);
        maxIn[0] = 1;
        maxIn[1] = 1;
        vm.expectRevert(
            abi.encodeWithSelector(IMultiPairStandardExchangeBufferPool.NotHookCaller.selector, address(0xBEEF))
        );
        IPoolLiquidity(multiPairPool).onAddLiquidityCustom(address(0xBEEF), maxIn, 0, maxIn, "");
    }

    /* ----- Donation does not free-mint BPT ----- */

    function test_donation_noBptMint_virtualUnchanged() public {
        uint256 bptBefore = IERC20(multiPairPool).totalSupply();
        uint256 vtBefore = mp().virtualBuffer(0);
        int256 hBefore = mp().hookShareDelta(0);

        dai.mint(alice, 100e18);
        IMultiPairStandardExchangeBufferPool p = mp();
        uint256[] memory amounts = new uint256[](2);
        amounts[p.bufferIndex(0)] = 100e18;

        vm.startPrank(alice);
        dai.approve(address(router), type(uint256).max);
        router.donate(multiPairPool, amounts, false, bytes(""));
        vm.stopPrank();

        assertEq(IERC20(multiPairPool).totalSupply(), bptBefore);
        assertEq(mp().virtualBuffer(0), vtBefore);
        assertEq(mp().hookShareDelta(0), hBefore);
    }
}
