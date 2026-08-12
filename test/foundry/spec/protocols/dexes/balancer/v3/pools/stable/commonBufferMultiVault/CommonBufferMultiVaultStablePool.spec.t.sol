// SPDX-License-Identifier: BSL-1.1
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
    ICommonBufferMultiVaultStablePool
} from "contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/ICommonBufferMultiVaultStablePool.sol";
import {
    ICommonBufferMultiVaultStablePoolPkg
} from "contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolStandardVaultPkg.sol";

import {
    TestBase_CommonBufferMultiVaultStablePool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/bases/TestBase_CommonBufferMultiVaultStablePool.sol";

/**
 * @title CommonBufferMultiVaultStablePoolSpec
 * @notice N=1 registration, routing views, buffer↔share swaps, LP, validation, StableMath formula.
 */
contract CommonBufferMultiVaultStablePoolSpec is TestBase_CommonBufferMultiVaultStablePool {
    function test_deploy_N1() public view {
        assertEq(cbmvs().vaultCount(), 1);
        assertEq(cbmvs().tokenCount(), 2);
        assertEq(address(cbmvs().bufferToken()), address(dai));
        assertEq(address(cbmvs().shareToken(0)), address(seVault));
        assertEq(address(cbmvs().vaultShareRateProvider(0)), address(0));
    }

    function test_hooksContract_isPool() public view {
        HookFlags memory hf = IHooks(cbmvsPool).getHookFlags();
        assertTrue(hf.shouldCallBeforeSwap);
        assertTrue(hf.shouldCallAfterSwap);
        assertTrue(hf.shouldCallBeforeInitialize);
        assertTrue(hf.shouldCallBeforeRemoveLiquidity);
    }

    function test_init_virtualBuffer_fromSeed() public view {
        assertEq(cbmvs().virtualBuffer(), CBMVS_INIT_BUFFER);
        assertEq(cbmvs().hookShareDelta(0), 0);
    }

    function test_amp_fixed_at_deploy() public view {
        (uint256 value, bool isUpdating, uint256 precision) = cbmvs().getAmplificationParameter();
        assertEq(value, CBMVS_AMP * StableMath.AMP_PRECISION);
        assertFalse(isUpdating);
        assertEq(precision, StableMath.AMP_PRECISION);
    }

    function test_shallowest_deepest_singleVault() public view {
        assertEq(cbmvs().shallowestVault(), 0);
        assertEq(cbmvs().deepestVault(), 0);
        assertGt(cbmvs().derivedShareDepth(0), 0);
    }

    function test_swap_buffer_to_share_exactIn() public {
        uint256 amountIn = 20e18;
        dai.mint(alice, amountIn);
        uint256 shareBefore = IERC20(address(seVault)).balanceOf(alice);
        uint256 rawBefore = rawPoolBufferBalance();
        uint256 out = swapExactIn(alice, IERC20(address(dai)), IERC20(address(seVault)), amountIn);
        assertGt(out, 0);
        assertEq(IERC20(address(seVault)).balanceOf(alice), shareBefore + out);
        assertApproxEqAbs(rawPoolBufferBalance(), rawBefore, 100, "buffer-in net residual");
        assertGe(cbmvs().virtualBuffer(), CBMVS_INIT_BUFFER);
    }

    function test_swap_share_to_buffer_exactIn() public {
        mintSharesForVault(0, alice, 5_000e18);
        uint256 amountIn = 50e18;
        uint256 bufBefore = dai.balanceOf(alice);
        uint256 rawBefore = rawPoolBufferBalance();
        uint256 out = swapExactIn(alice, IERC20(address(seVault)), IERC20(address(dai)), amountIn);
        assertGt(out, 0);
        assertEq(dai.balanceOf(alice), bufBefore + out);
        assertApproxEqAbs(rawPoolBufferBalance(), rawBefore, 1e18, "buffer residual after pre-seat");
    }

    function test_formula_onSwap_matchesStableMath() public {
        (,, uint256[] memory balancesRaw,) = bv3Vault.getPoolTokenInfo(cbmvsPool);
        uint256 n = cbmvs().tokenCount();
        uint256[] memory live = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            live[i] = balancesRaw[i];
        }
        uint256 indexIn = cbmvs().bufferIndex();
        uint256 indexOut = cbmvs().shareIndex(0);
        uint256 amountGiven = 1e18;

        // Math balances: virtual buffer + derived share depth (hook deltas are 0 at rest).
        uint256[] memory mathBal = new uint256[](n);
        mathBal[indexIn] = cbmvs().virtualBuffer();
        mathBal[indexOut] = cbmvs().derivedShareDepth(0);

        PoolSwapParams memory params = PoolSwapParams({
            kind: SwapKind.EXACT_IN,
            amountGivenScaled18: amountGiven,
            balancesScaled18: live,
            indexIn: indexIn,
            indexOut: indexOut,
            router: address(0),
            userData: ""
        });
        (bool ok, bytes memory ret) = cbmvsPool.staticcall(abi.encodeCall(IBalancerV3Pool.onSwap, (params)));
        assertTrue(ok, "onSwap staticcall");
        uint256 poolOut = abi.decode(ret, (uint256));

        (uint256 amp,,) = cbmvs().getAmplificationParameter();
        uint256 invariant = StableMath.computeInvariant(amp, mathBal);
        uint256 expected = StableMath.computeOutGivenExactIn(amp, mathBal, indexIn, indexOut, amountGiven, invariant);
        assertEq(poolOut, expected, "pool onSwap == StableMath");
        assertGt(poolOut, 0);
    }

    function test_lp_proportional_scalesVirtual() public {
        uint256 vBefore = cbmvs().virtualBuffer();
        uint256 bptBefore = IERC20(cbmvsPool).totalSupply();
        // Use a substantial proportional add so (bptOut * virtual) / tPre is non-zero under integer math.
        mintSharesForVault(0, alice, CBMVS_INIT_SHARES * 2);
        dai.mint(alice, CBMVS_INIT_BUFFER * 2);
        (IERC20[] memory tokens,,,) = bv3Vault.getPoolTokenInfo(cbmvsPool);
        uint256[] memory maxAmounts = new uint256[](tokens.length);
        for (uint256 t; t < tokens.length; ++t) {
            (ICommonBufferMultiVaultStablePool.TokenKind kind,) = cbmvs().resolveTokenIndex(t);
            if (kind == ICommonBufferMultiVaultStablePool.TokenKind.Buffer) {
                maxAmounts[t] = CBMVS_INIT_BUFFER;
            } else {
                maxAmounts[t] = CBMVS_INIT_SHARES;
            }
        }
        vm.startPrank(alice);
        dai.approve(address(router), type(uint256).max);
        IERC20(address(seVault)).approve(address(router), type(uint256).max);
        router.addLiquidityProportional(cbmvsPool, maxAmounts, 1, false, bytes(""));
        vm.stopPrank();
        uint256 bptAfter = IERC20(cbmvsPool).totalSupply();
        assertGt(bptAfter, bptBefore, "proportional must mint BPT");
        uint256 bptOut = bptAfter - bptBefore;
        // Scale: virtual_new = virtual + bptOut * virtual / tPre (tPre == bptBefore at hook time)
        uint256 expectedBump = (bptOut * vBefore) / bptBefore;
        if (expectedBump == 0) {
            assertGe(cbmvs().virtualBuffer(), vBefore);
        } else {
            assertEq(cbmvs().virtualBuffer(), vBefore + expectedBump, "virtual scales with proportional BPT");
        }
    }

    function test_reject_vaultCountZero() public {
        ICommonBufferMultiVaultStablePoolPkg.PkgArgs memory args = _buildPkgArgs(1);
        args.vaultCount = 0;
        args.standardExchangeVaults = new IStandardExchange[](0);
        args.vaultShareRateProviders = new IRateProvider[](0);
        vm.expectRevert();
        cbmvsPkg.deployPool(args);
    }

    function test_reject_vaultCountAboveThree() public {
        ICommonBufferMultiVaultStablePoolPkg.PkgArgs memory args = _buildPkgArgs(1);
        args.vaultCount = 4;
        args.standardExchangeVaults = new IStandardExchange[](4);
        args.vaultShareRateProviders = new IRateProvider[](4);
        vm.expectRevert();
        cbmvsPkg.deployPool(args);
    }

    function test_reject_invalidAmp() public {
        ICommonBufferMultiVaultStablePoolPkg.PkgArgs memory args = _buildPkgArgs(1);
        args.amplificationParameter = 0;
        vm.expectRevert();
        cbmvsPkg.deployPool(args);
    }

    function test_reject_duplicateShare() public {
        ICommonBufferMultiVaultStablePoolPkg.PkgArgs memory args = _buildPkgArgs(2);
        args.standardExchangeVaults[1] = args.standardExchangeVaults[0];
        vm.expectRevert();
        cbmvsPkg.deployPool(args);
    }

    function test_D1_customRemove_NotHookCaller() public {
        address attacker = makeAddr("attacker");
        uint256[] memory minOut = new uint256[](2);
        minOut[0] = 1e18;
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(ICommonBufferMultiVaultStablePool.NotHookCaller.selector, attacker));
        IPoolLiquidity(cbmvsPool).onRemoveLiquidityCustom(attacker, 0, minOut, minOut, "");
    }

    function test_D2_customAdd_NotHookCaller() public {
        address attacker = makeAddr("attacker");
        uint256[] memory maxIn = new uint256[](2);
        maxIn[0] = 1e18;
        vm.expectRevert(abi.encodeWithSelector(ICommonBufferMultiVaultStablePool.NotHookCaller.selector, attacker));
        IPoolLiquidity(cbmvsPool).onAddLiquidityCustom(attacker, maxIn, 0, maxIn, "");
    }

    function test_A3_donation_noFreeBpt() public {
        uint256 bptBefore = IERC20(cbmvsPool).totalSupply();
        uint256 vtBefore = cbmvs().virtualBuffer();
        dai.mint(alice, 50e18);
        uint256[] memory amounts = new uint256[](2);
        amounts[cbmvs().bufferIndex()] = 50e18;
        vm.startPrank(alice);
        dai.approve(address(router), type(uint256).max);
        router.donate(cbmvsPool, amounts, false, bytes(""));
        vm.stopPrank();
        assertEq(IERC20(cbmvsPool).totalSupply(), bptBefore);
        assertEq(cbmvs().virtualBuffer(), vtBefore);
    }
}

/**
 * @title CommonBufferMultiVaultStable_N2
 * @notice Multi-vault always-route smoke (N=2).
 */
contract CommonBufferMultiVaultStable_N2 is TestBase_CommonBufferMultiVaultStablePool {
    function _targetVaultCount() internal pure override returns (uint8) {
        return 2;
    }

    function test_deploy_N2() public view {
        assertEq(cbmvs().vaultCount(), 2);
        assertEq(cbmvs().tokenCount(), 3);
        assertEq(address(cbmvs().shareToken(0)), address(seVault));
        assertEq(address(cbmvs().shareToken(1)), address(seVault1));
    }

    function test_swap_buffer_to_share0() public {
        dai.mint(alice, 30e18);
        uint256 rawBefore = rawPoolBufferBalance();
        uint256 out = swapExactIn(alice, IERC20(address(dai)), IERC20(address(seVault)), 30e18);
        assertGt(out, 0);
        assertApproxEqAbs(rawPoolBufferBalance(), rawBefore, 100, "buffer-in net residual");
    }

    function test_swap_share0_to_share1() public {
        mintSharesForVault(0, alice, 5_000e18);
        uint256 inAmt = 40e18;
        uint256 out = swapExactIn(alice, IERC20(address(seVault)), IERC20(address(seVault1)), inAmt);
        assertGt(out, 0);
    }

    function test_routing_views() public view {
        uint8 shallow = cbmvs().shallowestVault();
        uint8 deep = cbmvs().deepestVault();
        assertTrue(shallow == 0 || shallow == 1);
        assertTrue(deep == 0 || deep == 1);
    }

    /// @notice Deposit fan-out may target vault ≠ trade leg (always-route by depth).
    function test_deposit_targets_shallowest_not_tokenOut() public {
        mintSharesForVault(0, alice, 12_000e18);
        mintSharesForVault(1, alice, 12_000e18);

        // Thin vault1 relative to vault0: sell share0 → share1 repeatedly.
        for (uint256 i; i < 6; ++i) {
            uint256 sell = 120e18;
            if (IERC20(address(seVault)).balanceOf(alice) < sell) mintSharesForVault(0, alice, 8_000e18);
            swapExactIn(alice, IERC20(address(seVault)), IERC20(address(seVault1)), sell);
        }

        uint8 need = cbmvs().shallowestVault();
        assertEq(need, 1, "skew must make vault1 shallowest");

        int256 d1Before = cbmvs().hookShareDelta(1);
        uint256 vBefore = cbmvs().virtualBuffer();
        uint256 rawBefore = rawPoolBufferBalance();

        uint256 amountIn = 40e18;
        dai.mint(alice, amountIn);
        // tokenOut = share0 - deposit still to shallowest (vault1)
        uint256 out = swapExactIn(alice, IERC20(address(dai)), IERC20(address(seVault)), amountIn);
        assertGt(out, 0);
        assertEq(cbmvs().virtualBuffer(), vBefore + amountIn, "virtual += amountIn");
        assertGt(cbmvs().hookShareDelta(1), d1Before, "deposit donation on shallowest vault1");
        assertApproxEqAbs(rawPoolBufferBalance(), rawBefore, 100, "buffer-in net residual");
    }

    function test_lp_unbalanced_buffer_add_growsVirtual() public {
        uint256 vBefore = cbmvs().virtualBuffer();
        uint256 bufAdd = 5e18;
        uint256 shareAdd = 5e18;
        mintSharesForVault(0, alice, shareAdd * 3);
        dai.mint(alice, bufAdd);
        (IERC20[] memory tokens,,,) = bv3Vault.getPoolTokenInfo(cbmvsPool);
        uint256[] memory maxAmounts = new uint256[](tokens.length);
        maxAmounts[cbmvs().bufferIndex()] = bufAdd;
        maxAmounts[cbmvs().shareIndex(0)] = shareAdd;
        vm.startPrank(alice);
        dai.approve(address(router), type(uint256).max);
        IERC20(address(seVault)).approve(address(router), type(uint256).max);
        uint256 bptOut = router.addLiquidityUnbalanced(cbmvsPool, maxAmounts, 0, false, bytes(""));
        vm.stopPrank();
        assertGt(bptOut, 0, "unbalanced add must mint BPT");
        assertEq(cbmvs().virtualBuffer(), vBefore + bufAdd, "virtual grows by buffer amount");
    }
}

/**
 * @title CommonBufferMultiVaultStable_N3
 * @notice Max v1 config (N=3).
 */
contract CommonBufferMultiVaultStable_N3 is TestBase_CommonBufferMultiVaultStablePool {
    function _targetVaultCount() internal pure override returns (uint8) {
        return 3;
    }

    function test_deploy_N3() public view {
        assertEq(cbmvs().vaultCount(), 3);
        assertEq(cbmvs().tokenCount(), 4);
        assertEq(address(cbmvs().shareToken(2)), address(seVault2));
    }

    function test_swap_buffer_to_share2() public {
        dai.mint(alice, 25e18);
        uint256 rawBefore = rawPoolBufferBalance();
        uint256 out = swapExactIn(alice, IERC20(address(dai)), IERC20(address(seVault2)), 25e18);
        assertGt(out, 0);
        assertApproxEqAbs(rawPoolBufferBalance(), rawBefore, 100);
    }

    function test_routing_tie_prefers_lowest_index() public view {
        // At equal init depths, shallowest and deepest should both prefer index 0.
        assertEq(cbmvs().shallowestVault(), 0, "equal depth: lowest index deposit");
        assertEq(cbmvs().deepestVault(), 0, "equal depth: lowest index redeem");
    }
}
