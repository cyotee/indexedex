// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IHooks} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IHooks.sol";
import {HookFlags} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IPoolLiquidity} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IPoolLiquidity.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {StableMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/StableMath.sol";
import {IBalancerV3Pool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBalancerV3Pool.sol";
import {
    PoolSwapParams,
    SwapKind
} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {
    IMixedBufferMultiVaultStablePool
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/IMixedBufferMultiVaultStablePool.sol";
import {
    IMixedBufferMultiVaultStablePoolPkg
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolStandardVaultPkg.sol";

import {
    TestBase_MixedBufferMultiVaultStablePool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/bases/TestBase_MixedBufferMultiVaultStablePool.sol";

/**
 * @title MixedBufferMultiVaultStablePoolSpec
 * @notice C0 (U=1,N=1) lifecycle + rejects + routing + swaps + LP + CUSTOM deny.
 */
contract MixedBufferMultiVaultStablePoolSpec is TestBase_MixedBufferMultiVaultStablePool {
    function test_deploy_C0_U1N1() public view {
        assertEq(mbmvs().unpairedCount(), 1);
        assertEq(mbmvs().vaultCount(), 1);
        assertEq(mbmvs().tokenCount(), 3);
        assertEq(address(mbmvs().bufferToken()), address(dai));
        assertEq(address(mbmvs().shareToken(0)), address(seVault));
        assertEq(address(mbmvs().unpairedToken(0)), address(usdc));
        assertEq(address(mbmvs().vaultShareRateProvider(0)), address(0));
        assertEq(address(mbmvs().unpairedRateProvider(0)), address(0));
    }

    function test_hooksContract_isPool() public view {
        HookFlags memory hf = IHooks(mbmvsPool).getHookFlags();
        assertTrue(hf.shouldCallBeforeSwap);
        assertTrue(hf.shouldCallAfterSwap);
        assertTrue(hf.shouldCallBeforeInitialize);
        assertTrue(hf.shouldCallBeforeRemoveLiquidity);
    }

    function test_init_virtualBuffer_and_unpaired() public view {
        assertEq(mbmvs().virtualBuffer(), MBMVS_INIT_BUFFER);
        assertEq(mbmvs().hookShareDelta(0), 0);
        (IMixedBufferMultiVaultStablePool.TokenKind kind,) = mbmvs().resolveTokenIndex(mbmvs().unpairedIndex(0));
        assertTrue(kind == IMixedBufferMultiVaultStablePool.TokenKind.Unpaired);
    }

    function test_amp_fixed_at_deploy() public view {
        (uint256 value, bool isUpdating, uint256 precision) = mbmvs().getAmplificationParameter();
        assertEq(value, MBMVS_AMP * StableMath.AMP_PRECISION);
        assertFalse(isUpdating);
        assertEq(precision, StableMath.AMP_PRECISION);
    }

    function test_shallowest_deepest_singleVault() public view {
        assertEq(mbmvs().shallowestVault(), 0);
        assertEq(mbmvs().deepestVault(), 0);
        assertGt(mbmvs().derivedShareDepth(0), 0);
    }

    function test_swap_buffer_to_share_exactIn() public {
        uint256 amountIn = 20e18;
        dai.mint(alice, amountIn);
        uint256 shareBefore = IERC20(address(seVault)).balanceOf(alice);
        uint256 rawBefore = rawPoolBufferBalance();
        uint256 out = swapExactIn(alice, IERC20(address(dai)), IERC20(address(seVault)), amountIn);
        assertGt(out, 0);
        assertEq(IERC20(address(seVault)).balanceOf(alice), shareBefore + out);
        assertApproxEqAbs(rawPoolBufferBalance(), rawBefore, 100, "buffer-in residual");
    }

    function test_swap_share_to_buffer_exactIn() public {
        mintSharesForVault(0, alice, 5_000e18);
        uint256 amountIn = 50e18;
        uint256 bufBefore = dai.balanceOf(alice);
        uint256 out = swapExactIn(alice, IERC20(address(seVault)), IERC20(address(dai)), amountIn);
        assertGt(out, 0);
        assertEq(dai.balanceOf(alice), bufBefore + out);
    }

    function test_swap_unpaired_to_buffer_exactIn() public {
        uint256 amountIn = 10e18;
        usdc.mint(alice, amountIn);
        vm.prank(alice);
        usdc.approve(address(router), type(uint256).max);
        uint256 bufBefore = dai.balanceOf(alice);
        uint256 out = swapExactIn(alice, IERC20(address(usdc)), IERC20(address(dai)), amountIn);
        assertGt(out, 0);
        assertEq(dai.balanceOf(alice), bufBefore + out);
    }

    function test_swap_unpaired_to_share_noBufferSE_required() public {
        // Pure unpaired↔share: no buffer SE I/O required for success path.
        uint256 amountIn = 5e18;
        usdc.mint(alice, amountIn);
        vm.prank(alice);
        usdc.approve(address(router), type(uint256).max);
        uint256 shareBefore = IERC20(address(seVault)).balanceOf(alice);
        uint256 out = swapExactIn(alice, IERC20(address(usdc)), IERC20(address(seVault)), amountIn);
        assertGt(out, 0);
        assertEq(IERC20(address(seVault)).balanceOf(alice), shareBefore + out);
    }

    function test_formula_onSwap_matchesStableMath() public {
        (,, uint256[] memory balancesRaw,) = bv3Vault.getPoolTokenInfo(mbmvsPool);
        uint256 n = mbmvs().tokenCount();
        uint256[] memory live = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            live[i] = balancesRaw[i];
        }
        uint256 indexIn = mbmvs().bufferIndex();
        uint256 indexOut = mbmvs().shareIndex(0);
        uint256 amountGiven = 1e18;

        uint256[] memory mathBal = new uint256[](n);
        mathBal[mbmvs().unpairedIndex(0)] = live[mbmvs().unpairedIndex(0)];
        mathBal[indexIn] = mbmvs().virtualBuffer();
        mathBal[indexOut] = mbmvs().derivedShareDepth(0);

        PoolSwapParams memory params = PoolSwapParams({
            kind: SwapKind.EXACT_IN,
            amountGivenScaled18: amountGiven,
            balancesScaled18: live,
            indexIn: indexIn,
            indexOut: indexOut,
            router: address(0),
            userData: ""
        });
        (bool ok, bytes memory ret) = mbmvsPool.staticcall(abi.encodeCall(IBalancerV3Pool.onSwap, (params)));
        assertTrue(ok, "onSwap staticcall");
        uint256 poolOut = abi.decode(ret, (uint256));

        (uint256 amp,,) = mbmvs().getAmplificationParameter();
        uint256 invariant = StableMath.computeInvariant(amp, mathBal);
        uint256 expected = StableMath.computeOutGivenExactIn(amp, mathBal, indexIn, indexOut, amountGiven, invariant);
        assertEq(poolOut, expected, "pool onSwap == StableMath");
        assertGt(poolOut, 0);
    }

    function test_lp_proportional_scalesVirtual() public {
        uint256 vBefore = mbmvs().virtualBuffer();
        uint256 bptBefore = IERC20(mbmvsPool).totalSupply();
        mintSharesForVault(0, alice, MBMVS_INIT_SHARES * 2);
        dai.mint(alice, MBMVS_INIT_BUFFER * 2);
        usdc.mint(alice, MBMVS_INIT_UNPAIRED * 2);
        (IERC20[] memory tokens,,,) = bv3Vault.getPoolTokenInfo(mbmvsPool);
        uint256[] memory maxAmounts = new uint256[](tokens.length);
        for (uint256 t; t < tokens.length; ++t) {
            (IMixedBufferMultiVaultStablePool.TokenKind kind,) = mbmvs().resolveTokenIndex(t);
            if (kind == IMixedBufferMultiVaultStablePool.TokenKind.Buffer) {
                maxAmounts[t] = MBMVS_INIT_BUFFER;
            } else if (kind == IMixedBufferMultiVaultStablePool.TokenKind.Unpaired) {
                maxAmounts[t] = MBMVS_INIT_UNPAIRED;
            } else {
                maxAmounts[t] = MBMVS_INIT_SHARES;
            }
        }
        vm.startPrank(alice);
        dai.approve(address(router), type(uint256).max);
        usdc.approve(address(router), type(uint256).max);
        IERC20(address(seVault)).approve(address(router), type(uint256).max);
        router.addLiquidityProportional(mbmvsPool, maxAmounts, 1, false, bytes(""));
        vm.stopPrank();
        uint256 bptAfter = IERC20(mbmvsPool).totalSupply();
        assertGt(bptAfter, bptBefore, "proportional must mint BPT");
        uint256 bptOut = bptAfter - bptBefore;
        uint256 expectedBump = (bptOut * vBefore) / bptBefore;
        if (expectedBump == 0) {
            assertGe(mbmvs().virtualBuffer(), vBefore);
        } else {
            assertEq(mbmvs().virtualBuffer(), vBefore + expectedBump, "virtual scales with proportional BPT");
        }
    }

    function test_reject_R0_U0() public {
        IMixedBufferMultiVaultStablePoolPkg.PkgArgs memory args = _buildPkgArgs(0, 1);
        vm.expectRevert();
        mbmvsPkg.deployPool(args);
    }

    function test_reject_R3_N0() public {
        IMixedBufferMultiVaultStablePoolPkg.PkgArgs memory args = _buildPkgArgs(1, 1);
        args.vaultCount = 0;
        args.standardExchangeVaults = new IStandardExchange[](0);
        args.vaultShareRateProviders = new IRateProvider[](0);
        vm.expectRevert();
        mbmvsPkg.deployPool(args);
    }

    function test_reject_R4_N4() public {
        IMixedBufferMultiVaultStablePoolPkg.PkgArgs memory args = _buildPkgArgs(1, 1);
        args.vaultCount = 4;
        args.standardExchangeVaults = new IStandardExchange[](4);
        args.vaultShareRateProviders = new IRateProvider[](4);
        vm.expectRevert();
        mbmvsPkg.deployPool(args);
    }

    function test_reject_R1_T6() public {
        // U=2 N=3 would be T=6 - reject even if we only pass invalid counts without real vaults.
        IMixedBufferMultiVaultStablePoolPkg.PkgArgs memory args = _buildPkgArgs(1, 1);
        args.unpairedCount = 2;
        args.unpairedTokens = new IERC20[](2);
        args.unpairedTokens[0] = IERC20(address(usdc));
        args.unpairedTokens[1] = IERC20(address(weth));
        args.unpairedRateProviders = new IRateProvider[](2);
        args.vaultCount = 3;
        args.standardExchangeVaults = new IStandardExchange[](3);
        args.vaultShareRateProviders = new IRateProvider[](3);
        // missing real vaults 1,2 → may fail for other reasons; still must not accept layout
        vm.expectRevert();
        mbmvsPkg.deployPool(args);
    }

    function test_reject_R2_U4_T6() public {
        // R2: U=4 N=1 → T=6 exceeds StableMath max tokens.
        IMixedBufferMultiVaultStablePoolPkg.PkgArgs memory args = _buildPkgArgs(1, 1);
        args.unpairedCount = 4;
        args.unpairedTokens = new IERC20[](4);
        args.unpairedTokens[0] = IERC20(address(usdc));
        args.unpairedTokens[1] = IERC20(address(weth));
        args.unpairedTokens[2] = IERC20(address(usdt));
        args.unpairedTokens[3] = IERC20(address(wsteth));
        args.unpairedRateProviders = new IRateProvider[](4);
        vm.expectRevert(
            abi.encodeWithSelector(IMixedBufferMultiVaultStablePool.InvalidTokenLayout.selector, uint8(4), uint8(1))
        );
        mbmvsPkg.deployPool(args);
    }

    function test_reject_invalidAmp() public {
        IMixedBufferMultiVaultStablePoolPkg.PkgArgs memory args = _buildPkgArgs(1, 1);
        args.amplificationParameter = 0;
        vm.expectRevert();
        mbmvsPkg.deployPool(args);
    }

    function test_lp_unbalanced_buffer_add_growsVirtual() public {
        uint256 vBefore = mbmvs().virtualBuffer();
        uint256 bufAdd = 5e18;
        uint256 shareAdd = 5e18;
        mintSharesForVault(0, alice, shareAdd * 3);
        dai.mint(alice, bufAdd);
        (IERC20[] memory tokens,,,) = bv3Vault.getPoolTokenInfo(mbmvsPool);
        uint256[] memory maxAmounts = new uint256[](tokens.length);
        maxAmounts[mbmvs().bufferIndex()] = bufAdd;
        maxAmounts[mbmvs().shareIndex(0)] = shareAdd;
        // unpaired leg left 0 - unbalanced buffer+share add path
        vm.startPrank(alice);
        dai.approve(address(router), type(uint256).max);
        IERC20(address(seVault)).approve(address(router), type(uint256).max);
        uint256 bptOut = router.addLiquidityUnbalanced(mbmvsPool, maxAmounts, 0, false, bytes(""));
        vm.stopPrank();
        assertGt(bptOut, 0, "unbalanced add must mint BPT");
        assertEq(mbmvs().virtualBuffer(), vBefore + bufAdd, "virtual grows by buffer amount");
    }

    function test_lp_bufferOnlySingleTokenRemove_reverts() public {
        uint256 bptBal = IERC20(mbmvsPool).balanceOf(alice);
        require(bptBal > 0, "alice needs BPT");
        vm.startPrank(alice);
        IERC20(mbmvsPool).approve(address(router), type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(IMixedBufferMultiVaultStablePool.BufferOnlyRemoveDisallowed.selector));
        router.removeLiquiditySingleTokenExactIn(mbmvsPool, bptBal / 100, IERC20(address(dai)), 0, false, bytes(""));
        vm.stopPrank();
    }

    function test_D1_customRemove_NotHookCaller() public {
        address attacker = makeAddr("attacker");
        uint256[] memory minOut = new uint256[](3);
        minOut[0] = 1e18;
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IMixedBufferMultiVaultStablePool.NotHookCaller.selector, attacker));
        IPoolLiquidity(mbmvsPool).onRemoveLiquidityCustom(attacker, 0, minOut, minOut, "");
    }

    function test_D2_customAdd_NotHookCaller() public {
        address attacker = makeAddr("attacker2");
        uint256[] memory maxIn = new uint256[](3);
        maxIn[0] = 1e18;
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IMixedBufferMultiVaultStablePool.NotHookCaller.selector, attacker));
        IPoolLiquidity(mbmvsPool).onAddLiquidityCustom(attacker, maxIn, 0, maxIn, "");
    }
}

/// @notice C1: U=1 free + N=2 vaults (T=4)
contract MixedBufferMultiVaultStable_C1_Spec is TestBase_MixedBufferMultiVaultStablePool {
    function _targetVaultCount() internal pure override returns (uint8) {
        return 2;
    }

    function test_C1_deploy_and_routing() public view {
        assertEq(mbmvs().unpairedCount(), 1);
        assertEq(mbmvs().vaultCount(), 2);
        assertEq(mbmvs().tokenCount(), 4);
        // equal init depths → lowest index wins ties
        assertEq(mbmvs().shallowestVault(), 0);
        assertEq(mbmvs().deepestVault(), 0);
    }

    function test_C1_swap_buffer_share() public {
        uint256 amountIn = 15e18;
        dai.mint(alice, amountIn);
        uint256 out = swapExactIn(alice, IERC20(address(dai)), IERC20(address(seVault)), amountIn);
        assertGt(out, 0);
    }
}

/// @notice C2: U=1 free + N=3 vaults (T=5)
contract MixedBufferMultiVaultStable_C2_Spec is TestBase_MixedBufferMultiVaultStablePool {
    function _targetVaultCount() internal pure override returns (uint8) {
        return 3;
    }

    function test_C2_deploy() public view {
        assertEq(mbmvs().unpairedCount(), 1);
        assertEq(mbmvs().vaultCount(), 3);
        assertEq(mbmvs().tokenCount(), 5);
    }

    function test_C2_swap_buffer_share() public {
        dai.mint(alice, 10e18);
        assertGt(swapExactIn(alice, IERC20(address(dai)), IERC20(address(seVault)), 10e18), 0);
    }
}

/// @notice C3: U=2 free + N=2 vaults (T=5)
contract MixedBufferMultiVaultStable_C3_Spec is TestBase_MixedBufferMultiVaultStablePool {
    function _targetUnpairedCount() internal pure override returns (uint8) {
        return 2;
    }

    function _targetVaultCount() internal pure override returns (uint8) {
        return 2;
    }

    function test_C3_deploy() public view {
        assertEq(mbmvs().unpairedCount(), 2);
        assertEq(mbmvs().vaultCount(), 2);
        assertEq(mbmvs().tokenCount(), 5);
    }

    function test_C3_swap_unpaired0_to_buffer() public {
        usdc.mint(alice, 8e18);
        vm.prank(alice);
        usdc.approve(address(router), type(uint256).max);
        assertGt(swapExactIn(alice, IERC20(address(usdc)), IERC20(address(dai)), 8e18), 0);
    }
}

/// @notice C4: U=3 free + N=1 vault (T=5)
contract MixedBufferMultiVaultStable_C4_Spec is TestBase_MixedBufferMultiVaultStablePool {
    function _targetUnpairedCount() internal pure override returns (uint8) {
        return 3;
    }

    function test_C4_deploy() public view {
        assertEq(mbmvs().unpairedCount(), 3);
        assertEq(mbmvs().vaultCount(), 1);
        assertEq(mbmvs().tokenCount(), 5);
    }

    function test_C4_swap_buffer_share() public {
        dai.mint(alice, 12e18);
        assertGt(swapExactIn(alice, IERC20(address(dai)), IERC20(address(seVault)), 12e18), 0);
    }
}
