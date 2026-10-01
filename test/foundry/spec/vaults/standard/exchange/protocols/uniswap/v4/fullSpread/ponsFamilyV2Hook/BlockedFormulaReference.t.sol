// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {StandardExchangeConstantProduct as ConstantProduct} from "contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol";

// tag::BlockedFormulaReferenceTest[]
/// @notice Independent small-integer controls for the selected F0/F1/F2 primitives.
contract UniswapV4FullSpreadPonsFamilyHookBlockedFormulaReferenceTest is Test {
    function test_exhaustiveF1MinimalInverse() public pure {
        for (uint256 input = 1; input <= 8; ++input) {
            for (uint256 other; other <= 8; ++other) {
                for (uint256 supply = 1; supply <= 8; ++supply) {
                    for (uint256 shares = 1; shares <= 4; ++shares) {
                        uint256 required = ConstantProduct._amountInForShares(input, other, shares, supply);
                        uint256 referenceInput;
                        while (_forward(input, other, referenceInput, supply) < shares) ++referenceInput;
                        assertEq(required, referenceInput);
                        assertGe(_forward(input, other, required, supply), shares);
                        assertLt(_forward(input, other, required - 1, supply), shares);
                        assertEq(ConstantProduct._sharesForDeposit(required, 0, supply, input, other),
                            _forward(input, other, required, supply));
                    }
                }
            }
        }
    }

    function test_F2IntegerRadicalCounterexample() public pure {
        assertEq(ConstantProduct._singleExit(100, 100, 6, 1_000), 0);
        assertEq(ConstantProduct._singleExit(100, 100, 7, 1_000), 0);
        assertEq(ConstantProduct._singleExit(100, 100, 9, 1_000), 0);
        assertEq(ConstantProduct._singleExit(100, 100, 10, 1_000), 1);
    }

    function testFuzz_F2ForwardMatchesEntitlementReference(uint32 out_, uint32 other_, uint16 shares_, uint16 supply_) public pure {
        uint256 supply = uint256(supply_) + 1;
        uint256 shares = uint256(shares_) % supply;
        uint256 u = uint256(out_) * shares / supply;
        uint256 v = uint256(other_) * shares / supply;
        uint256 expected = u + (v == 0 ? 0 : (uint256(out_) - u) * v / other_);
        assertEq(ConstantProduct._singleExit(out_, other_, shares, supply), expected);
    }

    function test_F0DecimalMinimumAndProportionalFloor() public pure {
        assertEq(ConstantProduct._minimumLiquidity(18, 18), 1e15);
        assertEq(ConstantProduct._minimumLiquidity(6, 18), 1e9);
        assertEq(ConstantProduct._minimumLiquidity(6, 6), 1e3);
        assertEq(ConstantProduct._minimumLiquidity(6, 9), 1e4);
        assertEq(ConstantProduct._minimumLiquidity(0, 0), 1);
        assertEq(ConstantProduct._initialShares(100, 400, 10), 190);
        assertEq(ConstantProduct._sharesForDeposit(7, 8, 100, 30, 40), 20);
    }

    function _forward(uint256 input_, uint256 other_, uint256 credit_, uint256 supply_) private pure returns (uint256) {
        if (other_ == 0) return credit_ * supply_ / input_;
        uint256 k = _sqrt(input_ * other_);
        if (k * k < input_ * other_) ++k;
        uint256 a = _sqrt((input_ + credit_) * other_);
        return a > k ? supply_ * (a - k) / k : 0;
    }

    function _sqrt(uint256 value_) private pure returns (uint256 root_) {
        while ((root_ + 1) * (root_ + 1) <= value_) ++root_;
    }
}
// end::BlockedFormulaReferenceTest[]
