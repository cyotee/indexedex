// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import '@crane/contracts/utils/BetterEfficientHashLib.sol';

/**
 * @title SlipstreamVaultRepo - Storage library for Slipstream vault position data.
 * @author cyotee doge <doge.cyotee>
 * @notice Stores the vault's concentrated liquidity position parameters.
 * @dev Supports multiple managed positions (at least 2: one token0-side, one token1-side)
 */
library SlipstreamVaultRepo {
    using BetterEfficientHashLib for bytes;

    /// @notice Maximum number of positions the vault can manage
    uint8 constant MAX_POSITIONS = 8;

    bytes32 internal constant STORAGE_SLOT = keccak256('indexedex.vaults.slipstream');

    /// @notice Represents a single Slipstream liquidity position
    struct Position {
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
    }

    /// @notice Strategy configuration for position management
    struct StrategyConfig {
        uint24 widthMultiplier;
    }

    struct Storage {
        // Single double-sided position
        Position position;
        bool positionCreated;
        
        // Strategy configuration (widthMultiplier for position creation)
        StrategyConfig strategy;
        
        // Last known pool state for cache invalidation
        uint160 lastSqrtPriceX96;
        int24 lastTick;
        uint32 lastTimestamp;
    }

    function _layout(bytes32 slot) internal pure returns (Storage storage layout_) {
        assembly {
            layout_.slot := slot
        }
    }

    function _layout() internal pure returns (Storage storage layout_) {
        return _layout(STORAGE_SLOT);
    }

    /* ---------------------- Initialization ---------------------- */

    /// @notice Initialize with width multiplier only
    /// @dev Position is created on first deposit using derived ticks
    function _initialize(Storage storage layout_, uint24 widthMultiplier_) internal {
        require(widthMultiplier_ >= 1, "widthMultiplier must be >= 1");
        layout_.strategy = StrategyConfig({widthMultiplier: widthMultiplier_});
        layout_.positionCreated = false;
    }

    /* ---------------------- Position Creation ---------------------- */

    /// @notice Create the single double-sided position on first deposit
    /// @dev Sets the position ticks directly
    function _createPositionIfNeeded(Storage storage layout_, int24 tickLower, int24 tickUpper) internal {
        if (layout_.positionCreated) return;
        
        layout_.position = Position({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidity: 0
        });
        layout_.positionCreated = true;
    }

    function _createPositionIfNeeded(int24 tickLower, int24 tickUpper) internal {
        _createPositionIfNeeded(_layout(), tickLower, tickUpper);
    }

    /// @notice Check if position has been created
    function _isPositionCreated(Storage storage layout_) internal view returns (bool) {
        return layout_.positionCreated;
    }

    function _isPositionCreated() internal view returns (bool) {
        return _isPositionCreated(_layout());
    }

    /* ---------------------- Position Access ---------------------- */

    /// @notice Get the single position (always index 0)
    function _getPosition(Storage storage layout_) internal view returns (Position storage) {
        return layout_.position;
    }

    function _getPosition() internal view returns (Position storage) {
        return _getPosition(_layout());
    }

    /// @notice Get position ticks
    function _getPositionTicks(Storage storage layout_) internal view returns (int24 tickLower, int24 tickUpper) {
        tickLower = layout_.position.tickLower;
        tickUpper = layout_.position.tickUpper;
    }

    function _getPositionTicks() internal view returns (int24 tickLower, int24 tickUpper) {
        return _getPositionTicks(_layout());
    }

    /// @notice Update position liquidity
    function _updatePositionLiquidity(Storage storage layout_, uint128 liquidity_) internal {
        layout_.position.liquidity = liquidity_;
    }

    function _updatePositionLiquidity(uint128 liquidity_) internal {
        _updatePositionLiquidity(_layout(), liquidity_);
    }

    /* ---------------------- Position Key ---------------------- */

    /// @notice Calculate position key for the vault's single position
    function _getPositionKey(Storage storage layout_, address owner_) internal view returns (bytes32) {
        return abi.encode(owner_, layout_.position.tickLower, layout_.position.tickUpper)._hash();
    }

    function _getPositionKey(address owner_) internal view returns (bytes32) {
        return _getPositionKey(_layout(), owner_);
    }

    /// @notice Get position key for vault's own position
    function _getOwnPositionKey() internal view returns (bytes32) {
        return _getPositionKey(address(this));
    }

    /* ---------------------- Strategy Config ---------------------- */

    function _strategy(Storage storage layout_) internal view returns (StrategyConfig memory) {
        return layout_.strategy;
    }

    function _strategy() internal view returns (StrategyConfig memory) {
        return _strategy(_layout());
    }

    function _widthMultiplier(Storage storage layout_) internal view returns (uint24) {
        return layout_.strategy.widthMultiplier;
    }

    function _widthMultiplier() internal view returns (uint24) {
        return _widthMultiplier(_layout());
    }

    /* ---------------------- Cache ---------------------- */

    function _setPoolState(Storage storage layout_, uint160 sqrtPriceX96_, int24 tick_, uint32 timestamp_) internal {
        layout_.lastSqrtPriceX96 = sqrtPriceX96_;
        layout_.lastTick = tick_;
        layout_.lastTimestamp = timestamp_;
    }

    function _lastPoolState(Storage storage layout_) internal view returns (uint160 sqrtPriceX96_, int24 tick_, uint32 timestamp_) {
        return (layout_.lastSqrtPriceX96, layout_.lastTick, layout_.lastTimestamp);
    }

    /* ---------------------- Position State Checks ---------------------- */

    /// @notice Check if the position is in-range (double-sided)
    function _isPositionInRange(Storage storage layout_, int24 currentTick) internal view returns (bool) {
        return currentTick >= layout_.position.tickLower && currentTick < layout_.position.tickUpper;
    }

    /// @notice Check if the position is in-range
    function _isPositionInRange(int24 currentTick) internal view returns (bool) {
        return _isPositionInRange(_layout(), currentTick);
    }
}

// Minimal interface for slot0() - actual implementation uses full ICLPool
interface ICLPool {
    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, bool unlocked);
    function token0() external view returns (address);
    function token1() external view returns (address);
}
