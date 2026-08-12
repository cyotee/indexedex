// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {StableMath} from
    "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/StableMath.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookMath.sol";

/**
 * @title UniswapV4StandardExchangeBalancerQuadStableBufferHook_Math
 * @notice Pure Math fixtures: AMP_PRECISION=1e3 and identity with Crane StableMath.
 * @dev Proves D2: not classic Curve-100 pin for this product.
 */
contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_Math is Test {
    /// @dev FIX-AMP: product constant is Balancer 1e3, not Curve 100.
    function test_FIX_AMP_precisionIs1e3() public pure {
        assertEq(Math.AMP_PRECISION, 1e3);
        assertTrue(Math.AMP_PRECISION != 100);
        assertEq(Math.MAX_AMP, 50_000);
    }

    function test_getD_matchesStableMath_balanced() public pure {
        uint256 baseAmp = 100;
        uint256 amp = baseAmp * Math.AMP_PRECISION; // 100_000
        uint256[4] memory xp = [uint256(1e18), 1e18, 1e18, 1e18];
        uint256 d = Math.getD(xp, amp);

        uint256[] memory bal = new uint256[](4);
        bal[0] = 1e18;
        bal[1] = 1e18;
        bal[2] = 1e18;
        bal[3] = 1e18;
        assertEq(d, StableMath.computeInvariant(amp, bal));
        // Balanced pool: D ≈ sum of balances
        assertApproxEqAbs(d, 4e18, 10);
    }

    function test_quoteExactInRated_positiveOut() public pure {
        uint256 amp = 100 * Math.AMP_PRECISION;
        uint256[4] memory xp = [uint256(100e18), 100e18, 100e18, 100e18];
        uint256 out = Math.quoteExactInRated(xp, 0, 1, 1e18, amp);
        assertGt(out, 0);
        // Near-peg stable: out slightly below 1e18 (favor protocol -1 wei style)
        assertLe(out, 1e18);
        assertGe(out, 0.99e18);
    }

    function test_quoteExactOutRated_positiveIn() public pure {
        uint256 amp = 100 * Math.AMP_PRECISION;
        uint256[4] memory xp = [uint256(100e18), 100e18, 100e18, 100e18];
        uint256 amountIn = Math.quoteExactOutRated(xp, 0, 1, 1e18, amp);
        assertGt(amountIn, 0);
        assertGe(amountIn, 1e18);
        assertLe(amountIn, 1.01e18);
    }

    function test_firstMintShares_geoMean() public pure {
        uint256[4] memory inv = [uint256(100e18), 100e18, 100e18, 100e18];
        uint256 shares = Math.firstMintShares(inv);
        assertEq(shares, 100e18 - Math.MINIMUM_LIQUIDITY);
    }
}
