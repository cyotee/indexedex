// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes as Types} from "./UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol";

// tag::UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath[]
/// @notice Exact eight-limb arithmetic for protection decisions, never rounded reporting values.
library UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath {
    error AccountingMismatch();

    function _from(uint256 value_) internal pure returns (Types.Uint2048 memory result_) {
        result_.limb[0] = value_;
    }

    function _compare(Types.Uint2048 memory a_, Types.Uint2048 memory b_) internal pure returns (int256 result_) {
        uint256[8] memory a = a_.limb;
        uint256[8] memory b = b_.limb;
        // Fixed uint256 arrays contain eight consecutive words under pinned solc.
        // Every access stays inside those Solidity-allocated arrays.
        assembly ("memory-safe") {
            for { let offset := 0x100 } gt(offset, 0) {} {
                offset := sub(offset, 0x20)
                let left := mload(add(a, offset))
                let right := mload(add(b, offset))
                if lt(left, right) { result_ := sub(0, 1) break }
                if gt(left, right) { result_ := 1 break }
            }
        }
    }

    function _subtract(Types.Uint2048 memory a_, Types.Uint2048 memory b_)
        internal pure returns (Types.Uint2048 memory result_)
    {
        uint256 borrow;
        uint256[8] memory a = a_.limb;
        uint256[8] memory b = b_.limb;
        uint256[8] memory output = result_.limb;
        assembly ("memory-safe") {
            for { let offset := 0 } lt(offset, 0x100) { offset := add(offset, 0x20) } {
                let left := mload(add(a, offset))
                let right := mload(add(b, offset))
                let difference := sub(left, right)
                mstore(add(output, offset), sub(difference, borrow))
                borrow := or(lt(left, right), lt(difference, borrow))
            }
        }
        if (borrow != 0) revert AccountingMismatch();
    }

    function _multiply(Types.Uint2048 memory a_, Types.Uint2048 memory b_)
        internal pure returns (Types.Uint2048 memory result_)
    {
        uint256 lengthA = _length(a_);
        uint256 lengthB = _length(b_);
        for (uint256 i; i < lengthA; ++i) {
            if (a_.limb[i] == 0) continue;
            for (uint256 j; j < lengthB; ++j) {
                if (b_.limb[j] == 0) continue;
                (uint256 low, uint256 high) = _fullProduct(a_.limb[i], b_.limb[j]);
                _addWord(result_, i + j, low);
                _addWord(result_, i + j + 1, high);
            }
        }
    }

    function _scale(Types.Uint2048 memory a_, uint256 b_) internal pure returns (Types.Uint2048 memory result_) {
        uint256 carry;
        uint256 length = _length(a_);
        for (uint256 i; i < length; ++i) {
            (uint256 low, uint256 high) = _fullProduct(a_.limb[i], b_);
            unchecked {
                result_.limb[i] = low + carry;
                carry = high + (result_.limb[i] < low ? 1 : 0);
            }
        }
        if (carry != 0) {
            if (length == 8) revert AccountingMismatch();
            result_.limb[length] = carry;
        }
    }

    function _product(uint256 a_, uint256 b_, uint256 c_) internal pure returns (Types.Uint2048 memory) {
        Types.Uint2048 memory product;
        (product.limb[0], product.limb[1]) = _fullProduct(a_, b_);
        return _scale(product, c_);
    }

    function _ratioCompare(Types.Ratio memory a_, Types.Ratio memory b_) internal pure returns (int256) {
        if (_isZero(a_.denominator) || _isZero(b_.denominator)) {
            revert AccountingMismatch();
        }
        bool aZero = _isZero(a_.numerator);
        bool bZero = _isZero(b_.numerator);
        if (aZero || bZero) return aZero == bZero ? int256(0) : aZero ? int256(-1) : int256(1);
        return _compare(_multiply(a_.numerator, b_.denominator), _multiply(b_.numerator, a_.denominator));
    }

    function _priceWithin(uint160 before_, uint160 after_, uint16 limitBps_) public pure returns (bool) {
        if (before_ == 0 || after_ == 0) return false;
        uint256 high = before_ > after_ ? before_ : after_;
        uint256 low = before_ < after_ ? before_ : after_;
        return _compare(_product(high, high, 10_000), _product(low, low, 10_000 + uint256(limitBps_))) <= 0;
    }

    function _aligned(uint256 shares_, uint256 backing_, uint256 supply_, uint256 contribution_)
        internal pure returns (bool)
    {
        if (contribution_ == 0) return true;
        if (backing_ == 0 || supply_ == 0 || shares_ == 0) return false;
        return _compare(_product(10_000, shares_, backing_), _product(9_999, supply_, contribution_)) >= 0;
    }

    /// @notice Conservative rejection before a composition trial's placement.
    /// @dev At a fixed price each principal leg is linear in liquidity. Signed
    /// settlement and principal flooring lose at most one native unit per leg.
    /// Allow BOTH backing and contribution to lose a unit (a superset of the
    /// actual add/remove choices), and ignore share flooring. If even this upper
    /// bound cannot align, no placement can rescue the candidate. Degenerate
    /// books still use the complete planner's existing domain checks.
    function _canAlignAfterPlacement(uint256[2] memory backing_, uint256[2] memory contribution_)
        public pure returns (bool)
    {
        if (backing_[0] <= 1 || backing_[1] <= 1) return true;
        for (uint256 i; i < 2; ++i) {
            uint256 minimumContribution = contribution_[i] == 0 ? 0 : contribution_[i] - 1;
            if (_compare(_product(10_000, contribution_[1 - i], backing_[i]),
                _product(9_999, minimumContribution, backing_[1 - i] - 1)) < 0) return false;
        }
        return true;
    }

    function _shortfallWithin(uint256 quote_, uint256 actual_) public pure returns (bool) {
        return _compare(_scale(_from(actual_), 10_000), _scale(_from(quote_), 9_990)) >= 0;
    }

    function _fullProduct(uint256 a_, uint256 b_) private pure returns (uint256 low_, uint256 high_) {
        assembly ("memory-safe") {
            let mm := mulmod(a_, b_, not(0))
            low_ := mul(a_, b_)
            high_ := sub(sub(mm, low_), lt(mm, low_))
        }
    }

    function _length(Types.Uint2048 memory value_) private pure returns (uint256 length_) {
        length_ = 8;
        uint256[8] memory words = value_.limb;
        assembly ("memory-safe") {
            for { let offset := 0x100 } gt(offset, 0) {} {
                offset := sub(offset, 0x20)
                if mload(add(words, offset)) { break }
                length_ := sub(length_, 1)
            }
        }
    }

    function _isZero(Types.Uint2048 memory value_) private pure returns (bool zero_) {
        uint256[8] memory words = value_.limb;
        zero_ = true;
        assembly ("memory-safe") {
            for { let offset := 0 } lt(offset, 0x100) { offset := add(offset, 0x20) } {
                if mload(add(words, offset)) { zero_ := 0 break }
            }
        }
    }

    function _addWord(Types.Uint2048 memory result_, uint256 index_, uint256 value_) private pure {
        while (value_ != 0) {
            if (index_ >= 8) revert AccountingMismatch();
            uint256 old = result_.limb[index_];
            unchecked { result_.limb[index_] = old + value_; }
            value_ = result_.limb[index_] < old ? 1 : 0;
            ++index_;
        }
    }
}
// end::UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath[]
