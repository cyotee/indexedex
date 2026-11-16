// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title WeirMathOracle
/// @notice Independent integer oracle for the Weir import. It does not import Weir,
/// the copied LiquidityAmounts, previewRedeem, FullMath, or ConstProdUtils.
library WeirMathOracle {
    uint256 internal constant Q96 = 2 ** 96;
    uint256 internal constant Q128 = 2 ** 128;
    uint256 internal constant K = 2 ** 20;
    uint256 internal constant MIN_SQRT_PRICE = 4295128739;
    uint256 internal constant MAX_SQRT_PRICE = 1461446703485210103287273052203988822378723970342;

    function md(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 result) {
        unchecked {
            if (d == 0) {
                assembly {
                    revert(0, 0)
                }
            }
            uint256 prod0 = x * y;
            uint256 prod1;
            assembly {
                let mm := mulmod(x, y, not(0))
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }
            if (prod1 == 0) return prod0 / d;
            if (d <= prod1) {
                assembly {
                    revert(0, 0)
                }
            }
            uint256 remainder;
            assembly {
                remainder := mulmod(x, y, d)
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }
            uint256 twos = (0 - d) & d;
            assembly {
                d := div(d, twos)
                prod0 := div(prod0, twos)
                twos := add(div(sub(0, twos), twos), 1)
            }
            prod0 |= prod1 * twos;
            uint256 inv = (3 * d) ^ 2;
            inv *= 2 - d * inv;
            inv *= 2 - d * inv;
            inv *= 2 - d * inv;
            inv *= 2 - d * inv;
            inv *= 2 - d * inv;
            inv *= 2 - d * inv;
            result = prod0 * inv;
        }
    }

    function u128(uint256 x) internal pure returns (uint128) {
        if (x > type(uint128).max) revert("liquidity overflow");
        return uint128(x);
    }

    function sort(uint160 a, uint160 b) internal pure returns (uint160, uint160) {
        return a > b ? (b, a) : (a, b);
    }

    function l0(uint160 a, uint160 b, uint256 amount) internal pure returns (uint128) {
        (a, b) = sort(a, b);
        return u128(md(amount, md(a, b, Q96), uint256(b) - uint256(a)));
    }

    function l1(uint160 a, uint160 b, uint256 amount) internal pure returns (uint128) {
        (a, b) = sort(a, b);
        return u128(md(amount, Q96, uint256(b) - uint256(a)));
    }

    function liquidityForAmounts(uint160 p, uint160 a, uint160 b, uint256 amount0, uint256 amount1)
        internal
        pure
        returns (uint128)
    {
        (a, b) = sort(a, b);
        if (p <= a) return l0(a, b, amount0);
        if (p < b) {
            uint128 left = l0(p, b, amount0);
            uint128 right = l1(a, p, amount1);
            return left < right ? left : right;
        }
        return l1(a, b, amount1);
    }

    function a0(uint160 a, uint160 b, uint128 liquidity) internal pure returns (uint256) {
        (a, b) = sort(a, b);
        return md(uint256(liquidity) * Q96, uint256(b) - uint256(a), b) / a;
    }

    function a1(uint160 a, uint160 b, uint128 liquidity) internal pure returns (uint256) {
        (a, b) = sort(a, b);
        return md(liquidity, uint256(b) - uint256(a), Q96);
    }

    function amountsForLiquidity(uint160 p, uint160 a, uint160 b, uint128 liquidity)
        internal
        pure
        returns (uint256 amount0, uint256 amount1)
    {
        (a, b) = sort(a, b);
        if (p <= a) return (a0(a, b, liquidity), 0);
        if (p < b) return (a0(p, b, liquidity), a1(a, p, liquidity));
        return (0, a1(a, b, liquidity));
    }

    function cushion(uint256 amount) internal pure returns (uint256) {
        return amount > 2 ? amount - 2 : 0;
    }

    function genesisShares(uint128 liquidity) internal pure returns (uint256 userShares, uint256 totalShares) {
        if (liquidity <= 1000) revert("ZeroShares");
        userShares = uint256(liquidity) - 1000;
        totalShares = liquidity;
    }

    function laterShares(uint128 liquidity, uint256 totalShares, uint256 positionLiquidity) internal pure returns (uint256) {
        return (uint256(liquidity) * totalShares) / positionLiquidity;
    }

    function feeCut(uint256 gross, uint256 bps) internal pure returns (uint256) {
        return (gross * bps) / 10_000;
    }

    function idleUpdate(uint256 oldIdle, int256 net) internal pure returns (uint256) {
        return uint256(int256(oldIdle) + net);
    }

    function balanceInput(uint256 amount0, uint256 amount1, uint160 price)
        internal
        pure
        returns (bool zeroForOne, uint256 amountIn)
    {
        uint256 value = md(md(amount0, price, Q96), price, Q96);
        if (value > amount1) {
            amountIn = (amount0 - md(md(amount1, Q96, price), Q96, price)) / 2;
            return (true, amountIn);
        }
        if (amount1 > value) return (false, (amount1 - value) / 2);
        return (false, 0);
    }

    function f0Liquidity() internal pure returns (uint128) {
        return liquidityForAmounts(
            uint160(Q96), uint160(MIN_SQRT_PRICE), uint160(MAX_SQRT_PRICE), K, K
        );
    }
}
