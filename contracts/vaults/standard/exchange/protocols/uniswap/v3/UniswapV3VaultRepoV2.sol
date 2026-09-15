// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/**
 * @title UniswapV3VaultRepoV2
 * @notice One vault-owned bound-pool position for Uniswap V3 Standard Exchange vaults.
 * @dev Organic books use Crane V3 `TickMath.minUsableTick` / `maxUsableTick` as the single center.
 *      Imported books convert to the same full-range center. Position keys use Uniswap V3 canonical packing:
 *      `keccak256(abi.encodePacked(owner, tickLower, tickUpper))`.
 */
library UniswapV3VaultRepoV2 {
    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.protocols.dexes.uniswap.v3.vault");

    struct Position {
        int24 tickLower;
        int24 tickUpper;
        bool created;
    }

    struct Storage {
        Position centerPosition;
    }

    function _layout(bytes32 slot) internal pure returns (Storage storage layout_) {
        assembly {
            layout_.slot := slot
        }
    }

    function _layout() internal pure returns (Storage storage layout_) {
        return _layout(STORAGE_SLOT);
    }

    function _createPositionIfNeeded(Storage storage layout_, int24 tickLower_, int24 tickUpper_) internal {
        Position storage position_ = layout_.centerPosition;
        if (position_.created) {
            return;
        }
        position_.tickLower = tickLower_;
        position_.tickUpper = tickUpper_;
        position_.created = true;
    }

    function _createPositionIfNeeded(int24 tickLower_, int24 tickUpper_) internal {
        _createPositionIfNeeded(_layout(), tickLower_, tickUpper_);
    }

    function _isPositionCreated(Storage storage layout_) internal view returns (bool) {
        return layout_.centerPosition.created;
    }

    function _isPositionCreated() internal view returns (bool) {
        return _isPositionCreated(_layout());
    }

    function _getPositionTicks(Storage storage layout_)
        internal
        view
        returns (int24 tickLower_, int24 tickUpper_)
    {
        Position storage position_ = layout_.centerPosition;
        tickLower_ = position_.tickLower;
        tickUpper_ = position_.tickUpper;
    }

    function _getPositionTicks() internal view returns (int24 tickLower_, int24 tickUpper_) {
        return _getPositionTicks(_layout());
    }

    /// @dev Canonical Uniswap V3 position key (no salt).
    function _getPositionKey(address owner_, int24 tickLower_, int24 tickUpper_) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner_, tickLower_, tickUpper_));
    }

    function _getOwnPositionKey() internal view returns (bytes32) {
        (int24 tickLower_, int24 tickUpper_) = _getPositionTicks();
        return _getPositionKey(address(this), tickLower_, tickUpper_);
    }
}
