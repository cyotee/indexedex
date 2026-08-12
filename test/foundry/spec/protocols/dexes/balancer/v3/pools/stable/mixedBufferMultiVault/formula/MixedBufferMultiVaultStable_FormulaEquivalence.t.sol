// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {StableMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/StableMath.sol";
import {IBalancerV3Pool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBalancerV3Pool.sol";
import {
    PoolSwapParams,
    SwapKind,
    Rounding
} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";

import {
    TestBase_MixedBufferMultiVaultStablePool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/bases/TestBase_MixedBufferMultiVaultStablePool.sol";

/**
 * @notice Proves onSwap / computeInvariant / computeBalance match pure StableMath on math balances
 *         (unpaired physical + virtualBuffer + derived shares).
 */
contract MixedBufferMultiVaultStable_FormulaEquivalence is TestBase_MixedBufferMultiVaultStablePool {
    function _mathBalFromPool(uint256[] memory live) internal view returns (uint256[] memory mathBal) {
        uint256 n = mbmvs().tokenCount();
        mathBal = new uint256[](n);
        uint8 u = mbmvs().unpairedCount();
        for (uint256 i; i < u; ++i) {
            uint256 idx = mbmvs().unpairedIndex(i);
            mathBal[idx] = live[idx];
        }
        mathBal[mbmvs().bufferIndex()] = mbmvs().virtualBuffer();
        uint8 vc = mbmvs().vaultCount();
        for (uint256 i; i < vc; ++i) {
            mathBal[mbmvs().shareIndex(i)] = mbmvs().derivedShareDepth(i);
        }
    }

    function test_formula_invariant_matchesStableMath() public view {
        (,, uint256[] memory balancesRaw,) = bv3Vault.getPoolTokenInfo(mbmvsPool);
        uint256 n = mbmvs().tokenCount();
        uint256[] memory live = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            live[i] = balancesRaw[i];
        }
        uint256[] memory mathBal = _mathBalFromPool(live);
        (uint256 amp,,) = mbmvs().getAmplificationParameter();
        uint256 expected = StableMath.computeInvariant(amp, mathBal);
        uint256 poolInv = IBalancerV3Pool(mbmvsPool).computeInvariant(live, Rounding.ROUND_DOWN);
        assertEq(poolInv, expected, "computeInvariant == StableMath");
    }

    function test_formula_onSwap_exactIn_fixedVector() public {
        (,, uint256[] memory balancesRaw,) = bv3Vault.getPoolTokenInfo(mbmvsPool);
        uint256 n = mbmvs().tokenCount();
        uint256[] memory live = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            live[i] = balancesRaw[i];
        }
        uint256 indexIn = mbmvs().bufferIndex();
        uint256 indexOut = mbmvs().shareIndex(0);
        uint256 amountGiven = 5e17;
        uint256[] memory mathBal = _mathBalFromPool(live);

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
        assertTrue(ok);
        uint256 poolOut = abi.decode(ret, (uint256));

        (uint256 amp,,) = mbmvs().getAmplificationParameter();
        uint256 inv = StableMath.computeInvariant(amp, mathBal);
        uint256 expected = StableMath.computeOutGivenExactIn(amp, mathBal, indexIn, indexOut, amountGiven, inv);
        assertEq(poolOut, expected, "onSwap == StableMath EXACT_IN");
    }

    function test_formula_onSwap_exactOut_fixedVector() public {
        (,, uint256[] memory balancesRaw,) = bv3Vault.getPoolTokenInfo(mbmvsPool);
        uint256 n = mbmvs().tokenCount();
        uint256[] memory live = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            live[i] = balancesRaw[i];
        }
        uint256 indexIn = mbmvs().bufferIndex();
        uint256 indexOut = mbmvs().shareIndex(0);
        uint256 amountOut = 3e17;
        uint256[] memory mathBal = _mathBalFromPool(live);

        PoolSwapParams memory params = PoolSwapParams({
            kind: SwapKind.EXACT_OUT,
            amountGivenScaled18: amountOut,
            balancesScaled18: live,
            indexIn: indexIn,
            indexOut: indexOut,
            router: address(0),
            userData: ""
        });
        (bool ok, bytes memory ret) = mbmvsPool.staticcall(abi.encodeCall(IBalancerV3Pool.onSwap, (params)));
        assertTrue(ok);
        uint256 poolIn = abi.decode(ret, (uint256));

        (uint256 amp,,) = mbmvs().getAmplificationParameter();
        uint256 inv = StableMath.computeInvariant(amp, mathBal);
        uint256 expected = StableMath.computeInGivenExactOut(amp, mathBal, indexIn, indexOut, amountOut, inv);
        assertEq(poolIn, expected, "onSwap == StableMath EXACT_OUT");
    }
}
