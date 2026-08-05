// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title UniswapV4SingleStandardExchangeBufferHookRepo
 * @notice Diamond storage for Single SE Buffer Hook bindings.
 * @dev wrapZeroForOne is Repo-only (no public getter). Bindings live in storage (diamond package).
 */
library UniswapV4SingleStandardExchangeBufferHookRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256(
        abi.encode(uint256(keccak256("indexedex.hooks.uv4.single.se.buffer.hook.storage")) - 1)
    ) & ~bytes32(uint256(0xff));

    struct Layout {
        address poolManager;
        address standardExchange;
        address pairToken;
        address currency0;
        address currency1;
        bool wrapZeroForOne;
        bool bindingsInitialized;
    }

    function _layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }

    function _initialize(address poolManager_, address standardExchange_, address pairToken_) internal {
        Layout storage l = _layout();
        require(!l.bindingsInitialized, "bound");
        l.poolManager = poolManager_;
        l.standardExchange = standardExchange_;
        l.pairToken = pairToken_;
        // Address sort: wrapZeroForOne when pairToken is currency0 (pair < SE)
        bool wrapZFO = pairToken_ < standardExchange_;
        l.wrapZeroForOne = wrapZFO;
        l.currency0 = wrapZFO ? pairToken_ : standardExchange_;
        l.currency1 = wrapZFO ? standardExchange_ : pairToken_;
        l.bindingsInitialized = true;
    }

    function _poolManager() internal view returns (address) {
        return _layout().poolManager;
    }

    function _standardExchange() internal view returns (address) {
        return _layout().standardExchange;
    }

    function _pairToken() internal view returns (address) {
        return _layout().pairToken;
    }

    function _currency0() internal view returns (address) {
        return _layout().currency0;
    }

    function _currency1() internal view returns (address) {
        return _layout().currency1;
    }

    function _wrapZeroForOne() internal view returns (bool) {
        return _layout().wrapZeroForOne;
    }
}
