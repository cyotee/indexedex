// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StableMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/StableMath.sol";
import {BasePoolMath} from "@crane/contracts/external/balancer/v3/vault/contracts/BasePoolMath.sol";
import {IBasePool} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IBasePool.sol";
import {Rounding} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookMath as Math} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookMath.sol";

/// @dev Reference-only adapter for the pinned StablePool callbacks used by actual BasePoolMath.
/// Crane 280799d7bd4c8d6ed85c6840c92afdc2d7370e18; StableMath SHA256
/// f99a2b3bb01d8ab2e97121df6849eb195f1ee2c03a45db2c88e029ea58bef256.
contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_Reference is Test {
    using FixedPoint for uint256;
    uint256 internal referenceAmp;

    function computeInvariant(uint256[] memory balances, Rounding rounding) external view returns (uint256 d) {
        (uint256 minimum, uint256 maximum) = StableMath.getMinAndMaxBalances(balances);
        StableMath.ensureBalancesWithinMaxImbalanceRange(minimum, maximum);
        d = StableMath.computeInvariant(referenceAmp, balances);
        if (d != 0 && rounding == Rounding.ROUND_UP) ++d;
    }

    function computeBalance(uint256[] memory balances, uint256 index, uint256 ratio) external view returns (uint256 b) {
        uint256 d = StableMath.computeInvariant(referenceAmp, balances);
        if (d != 0) ++d;
        b = StableMath.computeBalance(referenceAmp, balances, d.mulUp(ratio), index);
        (uint256 minimum, uint256 maximum) = StableMath.getMinAndMaxBalances(balances);
        if (b < minimum) minimum = b;
        else if (b > maximum) maximum = b;
        StableMath.ensureBalancesWithinMaxImbalanceRange(minimum, maximum);
    }

    function getMaximumInvariantRatio() external pure returns (uint256) { return StableMath.MAX_INVARIANT_RATIO; }
    function getMinimumInvariantRatio() external pure returns (uint256) { return StableMath.MIN_INVARIANT_RATIO; }

    function test_reference_all_counts_amp_endpoints_and_routes() public {
        for (uint256 n = 2; n <= 5; ++n) {
            _checkMath(n, 1_000, 0);
            _checkMath(n, 50_000_000, 123456789);
            _checkMath(n, 100_000, 314159);
        }
    }

    function testFuzz_reference_all_counts(uint64 seed, uint16 ampSeed) public {
        uint256 amp = (uint256(ampSeed) % 50_000 + 1) * 1000;
        for (uint256 n = 2; n <= 5; ++n) _checkMath(n, amp, seed);
    }

    function _checkMath(uint256 n, uint256 amp, uint256 seed) internal {
        referenceAmp = amp;
        uint256[] memory balances = new uint256[](n);
        uint256[] memory inputs = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            balances[i] = 1000 ether + uint256(keccak256(abi.encode(seed, i))) % 1000 ether;
            inputs[i] = 1 ether + uint256(keccak256(abi.encode(i, seed))) % 10 ether;
        }
        uint256 d = StableMath.computeInvariant(amp, balances);
        assertEq(Math.getD(balances, amp), d);
        assertEq(Math.firstMintShares(balances, amp) + Math.MINIMUM_LIQUIDITY, d / n);
        for (uint256 i; i < n; ++i) {
            for (uint256 j; j < n; ++j) {
                if (i == j) continue;
                assertEq(Math.quoteExactInRated(balances, i, j, 1 ether, amp), StableMath.computeOutGivenExactIn(amp, balances, i, j, 1 ether, d));
                assertEq(Math.quoteExactOutRated(balances, i, j, 1 ether, amp), StableMath.computeInGivenExactOut(amp, balances, i, j, 1 ether, d));
                uint256[] memory next = new uint256[](n);
                for (uint256 k; k < n; ++k) next[k] = balances[k];
                next[i] += 1 ether;
                assertEq(Math.getY(i, j, next[i], balances, amp, d), StableMath.computeBalance(amp, next, d, j));
            }
        }
        _checkLiquidity(balances, inputs, d / n);
    }

    function _checkLiquidity(uint256[] memory balances, uint256[] memory inputs, uint256 supply) internal view {
        IBasePool referencePool = IBasePool(address(this));
        uint256 fee = 0.003 ether;
        (uint256 expected,) = BasePoolMath.computeAddLiquidityUnbalanced(balances, inputs, supply, fee, referencePool);
        assertEq(Math.unbalancedJoinShares(balances, inputs, referenceAmp, supply, fee), expected);
        for (uint256 i; i < balances.length; ++i) {
            (expected,) = BasePoolMath.computeAddLiquiditySingleTokenExactOut(balances, i, supply / 100, supply, fee, referencePool);
            assertEq(Math.singleJoinExactOutAmountIn(balances, supply / 100, i, referenceAmp, supply, fee), expected);
            (expected,) = BasePoolMath.computeRemoveLiquiditySingleTokenExactIn(balances, i, supply / 100, supply, fee, referencePool);
            assertEq(Math.singleExitExactBptInAmountOut(balances, supply / 100, i, referenceAmp, supply, fee), expected);
            (expected,) = BasePoolMath.computeRemoveLiquiditySingleTokenExactOut(balances, i, balances[i] / 100, supply, fee, referencePool);
            assertEq(Math.singleExitExactTokenOutShares(balances, balances[i] / 100, i, referenceAmp, supply, fee), expected);
        }
    }

    function test_reference_ratio_bound_reverts_match() public {
        referenceAmp = 100_000;
        for (uint256 n = 2; n <= 5; ++n) {
            uint256[] memory balances = new uint256[](n);
            for (uint256 i; i < n; ++i) balances[i] = 1000 ether;
            bytes memory data = abi.encodeWithSelector(BasePoolMath.InvariantRatioAboveMax.selector, 6 ether, StableMath.MAX_INVARIANT_RATIO);
            vm.expectRevert(data); this.referenceJoin(balances, 5000 ether);
            vm.expectRevert(data); this.hookJoin(balances, 5000 ether);
            data = abi.encodeWithSelector(BasePoolMath.InvariantRatioBelowMin.selector, 0.5 ether, StableMath.MIN_INVARIANT_RATIO);
            vm.expectRevert(data); this.referenceExit(balances, 500 ether);
            vm.expectRevert(data); this.hookExit(balances, 500 ether);
        }
    }

    function referenceJoin(uint256[] memory b, uint256 s) external view returns (uint256 r) {
        (r,) = BasePoolMath.computeAddLiquiditySingleTokenExactOut(b, 0, s, 1000 ether, 0, IBasePool(address(this)));
    }
    function hookJoin(uint256[] memory b, uint256 s) external view returns (uint256) {
        return Math.singleJoinExactOutAmountIn(b, s, 0, referenceAmp, 1000 ether, 0);
    }
    function referenceExit(uint256[] memory b, uint256 s) external view returns (uint256 r) {
        (r,) = BasePoolMath.computeRemoveLiquiditySingleTokenExactIn(b, 0, s, 1000 ether, 0, IBasePool(address(this)));
    }
    function hookExit(uint256[] memory b, uint256 s) external view returns (uint256) {
        return Math.singleExitExactBptInAmountOut(b, s, 0, referenceAmp, 1000 ether, 0);
    }
}
