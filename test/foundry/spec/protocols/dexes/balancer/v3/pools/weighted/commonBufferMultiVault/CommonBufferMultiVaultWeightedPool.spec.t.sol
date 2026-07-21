// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IHooks} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IHooks.sol";
import {HookFlags} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IPoolLiquidity} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IPoolLiquidity.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {WeightedMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/WeightedMath.sol";
import {IBalancerV3Pool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBalancerV3Pool.sol";
import {PoolSwapParams, SwapKind} from
    "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {ICommonBufferMultiVaultWeightedPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/ICommonBufferMultiVaultWeightedPool.sol";
import {
    ICommonBufferMultiVaultWeightedPoolPkg
} from "contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPoolStandardVaultPkg.sol";

import {
    TestBase_CommonBufferMultiVaultWeightedPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/bases/TestBase_CommonBufferMultiVaultWeightedPool.sol";

/**
 * @title CommonBufferMultiVaultWeightedPoolSpec
 * @notice U=0 N=1 registration, routing views, buffer↔share swaps, LP, validation.
 */
contract CommonBufferMultiVaultWeightedPoolSpec is TestBase_CommonBufferMultiVaultWeightedPool {
    function test_deploy_U0_N1() public view {
        assertEq(cbmv().unpairedCount(), 0);
        assertEq(cbmv().vaultCount(), 1);
        assertEq(cbmv().tokenCount(), 2);
        assertEq(address(cbmv().bufferToken()), address(dai));
        assertEq(address(cbmv().shareToken(0)), address(seVault));
        assertEq(address(cbmv().vaultShareRateProvider(0)), address(0));
    }

    function test_hooksContract_isPool() public view {
        HookFlags memory hf = IHooks(cbmvPool).getHookFlags();
        assertTrue(hf.shouldCallBeforeSwap);
        assertTrue(hf.shouldCallAfterSwap);
        assertTrue(hf.shouldCallBeforeInitialize);
        assertTrue(hf.shouldCallBeforeRemoveLiquidity);
    }

    function test_init_virtualBuffer_fromSeed() public view {
        assertEq(cbmv().virtualBuffer(), CBMV_INIT_BUFFER);
        assertEq(cbmv().hookShareDelta(0), 0);
    }

    function test_weights_sumToOne() public view {
        uint256 n = cbmv().tokenCount();
        uint256 sum;
        for (uint256 i; i < n; ++i) {
            sum += cbmv().weight(i);
        }
        assertEq(sum, 1e18);
    }

    function test_mostNeeded_mostExcess_singleVault() public view {
        assertEq(cbmv().mostNeededVault(), 0);
        assertEq(cbmv().mostExcessVault(), 0);
        assertGt(cbmv().depthPerWeight(0), 0);
    }

    function test_swap_buffer_to_share_exactIn() public {
        uint256 amountIn = 20e18;
        dai.mint(alice, amountIn);
        uint256 shareBefore = IERC20(address(seVault)).balanceOf(alice);
        uint256 rawBefore = rawPoolBufferBalance();
        uint256 out = swapExactIn(alice, IERC20(address(dai)), IERC20(address(seVault)), amountIn);
        assertGt(out, 0);
        assertEq(IERC20(address(seVault)).balanceOf(alice), shareBefore + out);
        // L25 peer: buffer-in does not accumulate physical residual (net ~0 vs pre).
        assertApproxEqAbs(rawPoolBufferBalance(), rawBefore, 100, "buffer-in net residual");
        assertGe(cbmv().virtualBuffer(), CBMV_INIT_BUFFER);
    }

    function test_swap_share_to_buffer_exactIn() public {
        mintSharesForVault(0, alice, 5_000e18);
        uint256 amountIn = 50e18;
        uint256 bufBefore = dai.balanceOf(alice);
        uint256 rawBefore = rawPoolBufferBalance();
        uint256 out = swapExactIn(alice, IERC20(address(seVault)), IERC20(address(dai)), amountIn);
        assertGt(out, 0);
        assertEq(dai.balanceOf(alice), bufBefore + out);
        // Pre-seat donates buffer then user takes it; net physical vs before bounded.
        assertApproxEqAbs(rawPoolBufferBalance(), rawBefore, 1e18, "buffer residual after pre-seat");
    }

    function test_formula_onSwap_matchesWeightedMath() public {
        (,, uint256[] memory balancesRaw,) = bv3Vault.getPoolTokenInfo(cbmvPool);
        uint256[] memory live = new uint256[](cbmv().tokenCount());
        for (uint256 i; i < live.length; ++i) {
            live[i] = balancesRaw[i];
        }
        uint256 indexIn = cbmv().bufferIndex();
        uint256 indexOut = cbmv().shareIndex(0);
        uint256 amountGiven = 1e18;
        live[indexIn] = cbmv().virtualBuffer();
        PoolSwapParams memory params = PoolSwapParams({
            kind: SwapKind.EXACT_IN,
            amountGivenScaled18: amountGiven,
            balancesScaled18: live,
            indexIn: indexIn,
            indexOut: indexOut,
            router: address(0),
            userData: ""
        });
        // staticcall: onSwap is pure math (view) on our pool.
        (bool ok, bytes memory ret) =
            cbmvPool.staticcall(abi.encodeCall(IBalancerV3Pool.onSwap, (params)));
        assertTrue(ok, "onSwap staticcall");
        uint256 poolOut = abi.decode(ret, (uint256));
        uint256 wIn = cbmv().weight(indexIn);
        uint256 wOut = cbmv().weight(indexOut);
        uint256 expected =
            WeightedMath.computeOutGivenExactIn(live[indexIn], wIn, live[indexOut], wOut, amountGiven);
        assertEq(poolOut, expected, "pool onSwap == WeightedMath");
        assertGt(poolOut, 0);
    }

    function test_lp_proportional_scalesVirtual() public {
        uint256 vBefore = cbmv().virtualBuffer();
        uint256 bptBefore = IERC20(cbmvPool).totalSupply();
        // Proportional add: seed more of both tokens
        mintSharesForVault(0, alice, CBMV_INIT_SHARES);
        dai.mint(alice, CBMV_INIT_BUFFER);
        (IERC20[] memory tokens,,,) = bv3Vault.getPoolTokenInfo(cbmvPool);
        uint256[] memory maxAmounts = new uint256[](tokens.length);
        for (uint256 t; t < tokens.length; ++t) {
            (ICommonBufferMultiVaultWeightedPool.TokenKind kind,) = cbmv().resolveTokenIndex(t);
            if (kind == ICommonBufferMultiVaultWeightedPool.TokenKind.Buffer) {
                maxAmounts[t] = CBMV_INIT_BUFFER / 10;
            } else {
                maxAmounts[t] = CBMV_INIT_SHARES / 10;
            }
        }
        vm.startPrank(alice);
        dai.approve(address(router), type(uint256).max);
        IERC20(address(seVault)).approve(address(router), type(uint256).max);
        router.addLiquidityProportional(cbmvPool, maxAmounts, 1, false, bytes(""));
        vm.stopPrank();
        assertGt(IERC20(cbmvPool).totalSupply(), bptBefore);
        assertGt(cbmv().virtualBuffer(), vBefore);
    }

    function test_reject_vaultCountZero() public {
        ICommonBufferMultiVaultWeightedPoolPkg.PkgArgs memory args = _buildPkgArgs(2, 1);
        args.vaultCount = 0;
        args.standardExchangeVaults = new IStandardExchange[](0);
        args.vaultShareRateProviders = new IRateProvider[](0);
        args.weights = _equalWeights(2);
        vm.expectRevert();
        cbmvPkg.deployPool(args);
    }

    function test_reject_duplicateShare() public {
        // Two vaults same address
        ICommonBufferMultiVaultWeightedPoolPkg.PkgArgs memory args = _buildPkgArgs(0, 2);
        args.standardExchangeVaults[1] = args.standardExchangeVaults[0];
        vm.expectRevert();
        cbmvPkg.deployPool(args);
    }

    function test_D1_customRemove_NotHookCaller() public {
        address attacker = makeAddr("attacker");
        uint256[] memory minOut = new uint256[](2);
        minOut[0] = 1e18;
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(ICommonBufferMultiVaultWeightedPool.NotHookCaller.selector, attacker));
        IPoolLiquidity(cbmvPool).onRemoveLiquidityCustom(attacker, 0, minOut, minOut, "");
    }

    function test_D2_customAdd_NotHookCaller() public {
        address attacker = makeAddr("attacker");
        uint256[] memory maxIn = new uint256[](2);
        maxIn[0] = 1e18;
        vm.expectRevert(abi.encodeWithSelector(ICommonBufferMultiVaultWeightedPool.NotHookCaller.selector, attacker));
        IPoolLiquidity(cbmvPool).onAddLiquidityCustom(attacker, maxIn, 0, maxIn, "");
    }

    function test_A3_donation_noFreeBpt() public {
        uint256 bptBefore = IERC20(cbmvPool).totalSupply();
        uint256 vtBefore = cbmv().virtualBuffer();
        dai.mint(alice, 50e18);
        uint256[] memory amounts = new uint256[](2);
        amounts[cbmv().bufferIndex()] = 50e18;
        vm.startPrank(alice);
        dai.approve(address(router), type(uint256).max);
        router.donate(cbmvPool, amounts, false, bytes(""));
        vm.stopPrank();
        assertEq(IERC20(cbmvPool).totalSupply(), bptBefore);
        assertEq(cbmv().virtualBuffer(), vtBefore);
    }
}

/**
 * @title CommonBufferMultiVault_N2
 * @notice Multi-vault always-route smoke (U=0, N=2).
 */
contract CommonBufferMultiVault_N2 is TestBase_CommonBufferMultiVaultWeightedPool {
    function _targetVaultCount() internal pure override returns (uint8) {
        return 2;
    }

    function test_deploy_N2() public view {
        assertEq(cbmv().vaultCount(), 2);
        assertEq(cbmv().tokenCount(), 3);
        assertEq(address(cbmv().shareToken(0)), address(seVault));
        assertEq(address(cbmv().shareToken(1)), address(seVault1));
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
        uint8 need = cbmv().mostNeededVault();
        uint8 excess = cbmv().mostExcessVault();
        assertTrue(need == 0 || need == 1);
        assertTrue(excess == 0 || excess == 1);
    }
}

/**
 * @title CommonBufferMultiVault_Unpaired
 * @notice U=2 N=1 mixed layout.
 */
contract CommonBufferMultiVault_Unpaired is TestBase_CommonBufferMultiVaultWeightedPool {
    function _targetUnpairedCount() internal pure override returns (uint8) {
        return 2;
    }

    function test_deploy_U2_N1() public view {
        assertEq(cbmv().unpairedCount(), 2);
        assertEq(cbmv().vaultCount(), 1);
        assertEq(cbmv().tokenCount(), 4);
    }

    function test_swap_unpaired_to_buffer() public {
        usdc.mint(alice, 25e18);
        uint256 out = swapExactIn(alice, IERC20(address(usdc)), IERC20(address(dai)), 25e18);
        assertGt(out, 0);
    }

    function test_swap_buffer_to_unpaired() public {
        dai.mint(alice, 25e18);
        uint256 rawBefore = rawPoolBufferBalance();
        uint256 out = swapExactIn(alice, IERC20(address(dai)), IERC20(address(usdc)), 25e18);
        assertGt(out, 0);
        assertApproxEqAbs(rawPoolBufferBalance(), rawBefore, 100, "buffer-in net residual");
    }
}
