// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice Test-only base-2^32 reference for the locked FullSpread terminal metric.
/// @dev Independent of the production Inventory/Protection arithmetic. Never truncates a product.
// tag::FullSpreadMaintenanceReferenceMath[]
library FullSpreadMaintenanceReferenceMath {
    struct Big { uint32[64] digit; uint256 length; }
    struct Fraction { Big numerator; Big denominator; }
    struct Metric { Fraction composition; Fraction sleeve; }

    function number(uint256 value) internal pure returns (Big memory out) {
        while (value != 0) {
            out.digit[out.length++] = uint32(value);
            value >>= 32;
        }
    }

    function multiply(Big memory a, Big memory b) internal pure returns (Big memory out) {
        if (a.length == 0 || b.length == 0) return out;
        require(a.length + b.length <= 64, "reference product width");
        out.length = a.length + b.length;
        for (uint256 i; i < a.length; ++i) {
            uint256 carry;
            for (uint256 j; j < b.length; ++j) {
                uint256 k = i + j;
                uint256 z = uint256(out.digit[k]) + uint256(a.digit[i]) * uint256(b.digit[j]) + carry;
                out.digit[k] = uint32(z);
                carry = z >> 32;
            }
            out.digit[i + b.length] = uint32(carry);
        }
        while (out.length != 0 && out.digit[out.length - 1] == 0) --out.length;
    }

    function compare(Big memory a, Big memory b) internal pure returns (int256) {
        if (a.length != b.length) return a.length < b.length ? int256(-1) : int256(1);
        for (uint256 i = a.length; i != 0;) {
            --i;
            if (a.digit[i] != b.digit[i]) return a.digit[i] < b.digit[i] ? int256(-1) : int256(1);
        }
        return 0;
    }

    function subtract(Big memory a, Big memory b) internal pure returns (Big memory out) {
        require(compare(a, b) >= 0, "reference subtraction underflow");
        uint256 borrow;
        out.length = a.length;
        for (uint256 i; i < a.length; ++i) {
            uint256 digit = uint256(a.digit[i]) + (uint256(1) << 32) - uint256(b.digit[i]) - borrow;
            borrow = digit < (uint256(1) << 32) ? 1 : 0;
            out.digit[i] = uint32(digit);
        }
        require(borrow == 0, "reference final borrow");
        while (out.length != 0 && out.digit[out.length - 1] == 0) --out.length;
    }

    function fraction(uint256 n, uint256 d) internal pure returns (Fraction memory) {
        require(d != 0, "reference denominator");
        return Fraction(number(n), number(d));
    }

    function compareFraction(Fraction memory a, Fraction memory b) internal pure returns (int256) {
        return compare(multiply(a.numerator, b.denominator), multiply(b.numerator, a.denominator));
    }

    function compareMetric(Metric memory a, Metric memory b) internal pure returns (int256) {
        int256 c = compareFraction(a.composition, b.composition);
        return c == 0 ? compareFraction(a.sleeve, b.sleeve) : c;
    }

    function passes(Metric memory value) internal pure returns (bool) {
        return value.composition.numerator.length == 0 && value.sleeve.numerator.length == 0;
    }

    function metric(uint256[2] memory free, uint256[2] memory principal,
        uint160 q, uint160 a, uint160 b, uint256 p, uint256[2] memory floor)
        internal pure returns (Metric memory result)
    {
        uint256[2] memory total = [free[0] + principal[0], free[1] + principal[1]];
        result.composition = composition(total, q, a, b);
        result.sleeve = fraction(0, 1);
        for (uint256 i; i < 2; ++i) {
            // Fixtures deliberately bound this native product; checked arithmetic fails closed.
            uint256 target = total[i] * p / (1e18 + p);
            uint256 band = target / 20 > floor[i] ? target / 20 : floor[i];
            uint256 deviation = free[i] > target ? free[i] - target : target - free[i];
            Fraction memory leg = fraction(deviation > band ? deviation - band : 0, total[i] == 0 ? 1 : total[i]);
            if (compareFraction(leg, result.sleeve) > 0) result.sleeve = leg;
        }
    }

    function composition(uint256[2] memory total, uint160 q, uint160 a, uint160 b)
        internal pure returns (Fraction memory result)
    {
        require(a < b, "reference range");
        if (total[0] == 0 && total[1] == 0) return fraction(0, 1);
        if (q <= a) return fraction(total[1] == 0 ? 0 : 9_999, 10_000);
        if (q >= b) return fraction(total[0] == 0 ? 0 : 9_999, 10_000);
        Big memory x = multiply(multiply(number(total[0]), number(q - a)), multiply(number(q), number(b)));
        Big memory y = multiply(multiply(number(total[1]), number(b - q)), number(uint256(1) << 192));
        bool larger = compare(x, y) >= 0;
        Big memory maximum = larger ? x : y;
        Big memory difference = larger ? subtract(x, y) : subtract(y, x);
        Big memory scaled = multiply(difference, number(10_000));
        result.numerator = compare(scaled, maximum) > 0 ? subtract(scaled, maximum) : number(0);
        result.denominator = multiply(maximum, number(10_000));
    }

    function priceWithin(uint160 start, uint160 end, uint256 bps) internal pure returns (bool) {
        uint256 high = start > end ? start : end;
        uint256 low = start > end ? end : start;
        return compare(multiply(multiply(number(high), number(high)), number(10_000)),
            multiply(multiply(number(low), number(low)), number(10_000 + bps))) <= 0;
    }
}
// end::FullSpreadMaintenanceReferenceMath[]
