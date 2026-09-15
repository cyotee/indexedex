// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangePretransfer as IPretransfer} from "./IStandardExchangePretransfer.sol";

/// @notice Transaction-scoped delivery credits shared by the new V3/V4 vaults.
/// @dev No pool prices, deployed amounts, accrued fees or historical total-reserve snapshots
/// participate in delivery validation. A pending commitment blocks other economic operations.
library StandardExchangeDeliveryRepo {
    bytes32 internal constant SLOT = keccak256("indexedex.standard.exchange.delivery.v2");
    // Transient words: caller, calldata hash, count, executing, then two (token,balance,amount) records.

    function _get(uint256 offset) private view returns (uint256 value) {
        bytes32 slot = bytes32(uint256(SLOT) + offset);
        assembly ("memory-safe") { value := tload(slot) }
    }

    function _set(uint256 offset, uint256 value) private {
        bytes32 slot = bytes32(uint256(SLOT) + offset);
        assembly ("memory-safe") { tstore(slot, value) }
    }

    function _prepare(address[] calldata tokens, uint256[] calldata amounts, bytes32 callHash) internal {
        if (_get(0) != 0 || _get(3) != 0) revert IPretransfer.PretransferPending();
        if (tokens.length == 0 || tokens.length > 2 || tokens.length != amounts.length || callHash == bytes32(0)) {
            revert IPretransfer.InvalidPretransfer();
        }
        _set(0, uint160(msg.sender));
        _set(1, uint256(callHash));
        _set(2, tokens.length);
        for (uint256 i; i < tokens.length; ++i) {
            if (amounts[i] == 0 || tokens[i] == address(0) || (i != 0 && tokens[i] == tokens[0])) {
                revert IPretransfer.InvalidPretransfer();
            }
            _set(4 + i * 3, uint160(tokens[i]));
            _set(5 + i * 3, IERC20(tokens[i]).balanceOf(address(this)));
            _set(6 + i * 3, amounts[i]);
        }
    }

    function _begin() internal {
        if (_get(3) != 0) revert IPretransfer.PretransferPending();
        uint256 caller = _get(0);
        if (caller != 0) {
            if (address(uint160(caller)) != msg.sender || bytes32(_get(1)) != keccak256(msg.data)) {
                revert IPretransfer.PretransferCallMismatch();
            }
            // Validate all inputs before any route can collect fees, wrap, swap or remove liquidity.
            for (uint256 i; i < _get(2); ++i) {
                address token = address(uint160(_get(4 + i * 3)));
                uint256 beforeBalance = _get(5 + i * 3);
                uint256 balance = IERC20(token).balanceOf(address(this));
                uint256 actual = balance > beforeBalance ? balance - beforeBalance : 0;
                uint256 expected = _get(6 + i * 3);
                if (actual != expected) revert IPretransfer.PretransferAmountMismatch(token, expected, actual);
            }
        }
        _set(3, 1);
    }

    function _consume(address token, uint256 amount) internal returns (uint256) {
        if (_get(0) == 0 || _get(3) != 1) revert IPretransfer.PretransferNotPrepared();
        for (uint256 i; i < _get(2); ++i) {
            if (address(uint160(_get(4 + i * 3))) != token) continue;
            uint256 credited = _get(6 + i * 3);
            if (credited == 0 || amount != credited) {
                revert IPretransfer.PretransferAmountMismatch(token, credited, amount);
            }
            _set(6 + i * 3, 0);
            return amount;
        }
        revert IPretransfer.PretransferNotPrepared();
    }

    function _requirePull() internal view {
        if (_get(0) != 0) revert IPretransfer.PretransferPending();
    }

    function _end() internal {
        for (uint256 i; i < _get(2); ++i) {
            if (_get(6 + i * 3) != 0) revert IPretransfer.PretransferNotConsumed();
        }
        for (uint256 i; i < 10; ++i) _set(i, 0);
    }
}
