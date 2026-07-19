// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {TransientSlot} from "@crane/contracts/utils/TransientSlot.sol";

/**
 * @title BalancerV3StandardExchangeRouterRepo
 * @notice Transient storage for strategy-SE bookkeeping and prepay session auth stack.
 * @dev Prepay session (D1–D7):
 *      - sessionActive + stack of authorized principals
 *      - Router begins session and pushes path pools / direct SE vaults
 *      - Nested SE gains rights only via passPrepayAuth / restorePrepayAuth
 *      - Transient storage is cleared on call-frame revert (EIP-1153)
 */
library BalancerV3StandardExchangeRouterRepo {
    using TransientSlot for *;

    uint256 internal constant MAX_PREPAY_AUTH_DEPTH = 16;

    bytes32 internal constant STORAGE_SLOT = keccak256("protocols.dexes.balancer.v3.routers.standard.exchange");

    bytes32 internal constant PREPAY_SESSION_ACTIVE_SLOT =
        keccak256("protocols.dexes.balancer.v3.routers.standard.exchange.prepay.sessionActive");

    bytes32 internal constant PREPAY_AUTH_DEPTH_SLOT =
        keccak256("protocols.dexes.balancer.v3.routers.standard.exchange.prepay.depth");

    bytes32 internal constant PREPAY_AUTH_STACK_BASE =
        keccak256("protocols.dexes.balancer.v3.routers.standard.exchange.prepay.stack");

    error PrepayAuthDepthExceeded(uint256 depth);
    error NotPrepayAuthTop(address caller, address top);
    error NotAuthorizedToPass(address caller, address top);
    error NotAuthorizedToRestore(address caller, address expectedParent);
    error PrepayNotAuthorized(address caller);
    error InvalidPrepayPassTarget(address next);

    /* ---------------------------------------------------------------------- */
    /*                         Current strategy SE token                        */
    /* ---------------------------------------------------------------------- */

    function _currentStandardExchangeToken() internal view returns (IStandardExchangeProxy token_) {
        token_ = IStandardExchangeProxy(STORAGE_SLOT.asAddress().tload());
    }

    function _setCurrentStandardExchangeToken(IStandardExchangeProxy token_) internal {
        STORAGE_SLOT.asAddress().tstore(address(token_));
    }

    /* ---------------------------------------------------------------------- */
    /*                            Prepay session stack                          */
    /* ---------------------------------------------------------------------- */

    function _prepaySessionActive() internal view returns (bool) {
        return PREPAY_SESSION_ACTIVE_SLOT.asBoolean().tload();
    }

    function _prepayAuthDepth() internal view returns (uint256) {
        return PREPAY_AUTH_DEPTH_SLOT.asUint256().tload();
    }

    function _prepayAuthStackSlot(uint256 index) private pure returns (TransientSlot.AddressSlot) {
        return keccak256(abi.encode(PREPAY_AUTH_STACK_BASE, index)).asAddress();
    }

    function _prepayAuthAt(uint256 index) internal view returns (address) {
        return _prepayAuthStackSlot(index).tload();
    }

    function _prepayAuthTop() internal view returns (address) {
        uint256 depth = _prepayAuthDepth();
        if (depth == 0) return address(0);
        return _prepayAuthAt(depth - 1);
    }

    function _sessionBegin() internal {
        PREPAY_SESSION_ACTIVE_SLOT.asBoolean().tstore(true);
        // Force empty stack for a clean session.
        PREPAY_AUTH_DEPTH_SLOT.asUint256().tstore(0);
    }

    function _sessionEnd() internal {
        PREPAY_AUTH_DEPTH_SLOT.asUint256().tstore(0);
        PREPAY_SESSION_ACTIVE_SLOT.asBoolean().tstore(false);
    }

    function _pushPrepayAuth(address principal) internal {
        if (principal == address(0)) revert InvalidPrepayPassTarget(principal);
        uint256 depth = _prepayAuthDepth();
        if (depth >= MAX_PREPAY_AUTH_DEPTH) revert PrepayAuthDepthExceeded(depth);
        _prepayAuthStackSlot(depth).tstore(principal);
        PREPAY_AUTH_DEPTH_SLOT.asUint256().tstore(depth + 1);
    }

    function _popPrepayAuth() internal returns (address popped) {
        uint256 depth = _prepayAuthDepth();
        if (depth == 0) return address(0);
        popped = _prepayAuthAt(depth - 1);
        _prepayAuthStackSlot(depth - 1).tstore(address(0));
        PREPAY_AUTH_DEPTH_SLOT.asUint256().tstore(depth - 1);
    }

    /**
     * @notice Enter a strategy / route principal under an active session.
     * @dev Sets legacy currentSE pointer and pushes onto the prepay auth stack.
     *      If another principal is already current and is stack top, it is popped first.
     */
    function _enterStrategyPrincipal(IStandardExchangeProxy principal) internal {
        address p = address(principal);
        address prev = address(_currentStandardExchangeToken());
        if (_prepaySessionActive() && prev != address(0) && prev != p && _prepayAuthTop() == prev) {
            _popPrepayAuth();
        }
        _setCurrentStandardExchangeToken(principal);
        if (_prepaySessionActive() && p != address(0)) {
            // Avoid double-push if already top (re-entrancy into same principal).
            if (_prepayAuthTop() != p) {
                _pushPrepayAuth(p);
            }
        }
    }

    /**
     * @notice Exit strategy principal: clear currentSE and pop if it matches top.
     * @dev `expected` may be address(0) meaning "clear whatever is current".
     */
    function _exitStrategyPrincipal(IStandardExchangeProxy expected) internal {
        address current = address(_currentStandardExchangeToken());
        address toMatch = address(expected) == address(0) ? current : address(expected);
        if (_prepaySessionActive() && toMatch != address(0) && _prepayAuthTop() == toMatch) {
            _popPrepayAuth();
        }
        _setCurrentStandardExchangeToken(IStandardExchangeProxy(address(0)));
    }

    /**
     * @notice Push a path pool (e.g. Buffer pool) as route principal under an active session.
     */
    function _pushRoutePrincipal(address principal) internal {
        if (!_prepaySessionActive()) return;
        if (principal == address(0)) return;
        if (_prepayAuthTop() == principal) return;
        _pushPrepayAuth(principal);
    }

    function _popRoutePrincipal(address principal) internal {
        if (!_prepaySessionActive()) return;
        if (_prepayAuthTop() == principal) {
            _popPrepayAuth();
        }
    }

    /**
     * @notice Pass prepay auth to `next`. No-op when session inactive.
     * @dev Caller must be stack top when session is active.
     */
    function _passPrepayAuth(address caller, address next) internal returns (bool) {
        if (!_prepaySessionActive()) return true;
        if (next == address(0)) revert InvalidPrepayPassTarget(next);
        address top = _prepayAuthTop();
        if (caller != top) revert NotAuthorizedToPass(caller, top);
        _pushPrepayAuth(next);
        return true;
    }

    /**
     * @notice Restore prepay auth after nested call. No-op when session inactive.
     * @dev Caller must be parent (stack[depth-2]); pops child (top).
     */
    function _restorePrepayAuth(address caller) internal returns (bool) {
        if (!_prepaySessionActive()) return true;
        uint256 depth = _prepayAuthDepth();
        if (depth < 2) revert NotAuthorizedToRestore(caller, address(0));
        address parent = _prepayAuthAt(depth - 2);
        if (caller != parent) revert NotAuthorizedToRestore(caller, parent);
        _popPrepayAuth();
        return true;
    }

    /**
     * @notice Gate prepay entry points.
     * @dev Session on  → msg.sender must be stack top.
     *      Session off → self-root: contracts only (EOAs blocked). Caller prepays for itself.
     */
    function _onlyPrepayAuthorized(address caller) internal view {
        if (_prepaySessionActive()) {
            address top = _prepayAuthTop();
            if (caller != top) revert NotPrepayAuthTop(caller, top);
            return;
        }
        // D6 self-root: EOAs cannot prepay when no session.
        if (caller.code.length == 0) {
            revert PrepayNotAuthorized(caller);
        }
    }
}
