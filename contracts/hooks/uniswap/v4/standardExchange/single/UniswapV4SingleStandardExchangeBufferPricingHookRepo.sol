// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title UniswapV4SingleStandardExchangeBufferPricingHookRepo
 * @notice Diamond-pattern storage for hook non-immutable layout fields.
 * @dev Binding (poolManager, SE, underlying) is ctor immutables on the hook contract.
 *      wrapZeroForOne is Repo-only (D70/D73) — set once in ctor from address sort.
 */
library UniswapV4SingleStandardExchangeBufferPricingHookRepo {
    bytes32 internal constant STORAGE_SLOT =
        keccak256(abi.encode(uint256(keccak256("indexedex.hooks.uv4.single.se.buffer.pricing.storage")) - 1))
            & ~bytes32(uint256(0xff));

    struct Layout {
        bool wrapZeroForOne;
        bool initialized;
    }

    function _layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }

    function _setWrapZeroForOne(bool wrapZeroForOne_) internal {
        Layout storage l = _layout();
        require(!l.initialized, "wrapZeroForOne already set");
        l.wrapZeroForOne = wrapZeroForOne_;
        l.initialized = true;
    }

    function _wrapZeroForOne() internal view returns (bool) {
        return _layout().wrapZeroForOne;
    }
}
