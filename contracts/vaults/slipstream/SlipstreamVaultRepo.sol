// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@crane/contracts/utils/BetterEfficientHashLib.sol";

library SlipstreamVaultRepo {
    using BetterEfficientHashLib for bytes;

    uint16 internal constant MAX_BPS = 10_000;
    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.vaults.slipstream");

    enum PositionKind {
        Center,
        LowerWing,
        UpperWing
    }

    struct Position {
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        bool created;
    }

    struct StrategyConfig {
        uint24 widthMultiplier;
        uint24 centerWidthMultiplier;
        uint16 activeLiquidityBps;
    }

    struct Storage {
        Position centerPosition;
        Position lowerWingPosition;
        Position upperWingPosition;
        StrategyConfig strategy;
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

    function _initialize(Storage storage layout_, uint24 widthMultiplier_) internal {
        require(widthMultiplier_ >= 1, "widthMultiplier must be >= 1");
        layout_.strategy = StrategyConfig({widthMultiplier: widthMultiplier_, centerWidthMultiplier: 2, activeLiquidityBps: 1000});
    }

    function _initialize(uint24 widthMultiplier_) internal {
        _initialize(_layout(), widthMultiplier_);
    }

    function _position(Storage storage layout_, PositionKind kind_) internal view returns (Position storage position_) {
        if (kind_ == PositionKind.Center) {
            return layout_.centerPosition;
        }
        if (kind_ == PositionKind.LowerWing) {
            return layout_.lowerWingPosition;
        }
        return layout_.upperWingPosition;
    }

    function _createPositionIfNeeded(Storage storage layout_, PositionKind kind_, int24 tickLower_, int24 tickUpper_)
        internal
    {
        Position storage position_ = _position(layout_, kind_);
        if (position_.created) {
            return;
        }

        position_.tickLower = tickLower_;
        position_.tickUpper = tickUpper_;
        position_.created = true;
    }

    function _createPositionIfNeeded(PositionKind kind_, int24 tickLower_, int24 tickUpper_) internal {
        _createPositionIfNeeded(_layout(), kind_, tickLower_, tickUpper_);
    }

    function _isPositionCreated(Storage storage layout_) internal view returns (bool) {
        return layout_.centerPosition.created || layout_.lowerWingPosition.created || layout_.upperWingPosition.created;
    }

    function _isPositionCreated() internal view returns (bool) {
        return _isPositionCreated(_layout());
    }

    function _isPositionCreated(Storage storage layout_, PositionKind kind_) internal view returns (bool) {
        return _position(layout_, kind_).created;
    }

    function _isPositionCreated(PositionKind kind_) internal view returns (bool) {
        return _isPositionCreated(_layout(), kind_);
    }

    function _getPosition(Storage storage layout_, PositionKind kind_) internal view returns (Position storage) {
        return _position(layout_, kind_);
    }

    function _getPosition(PositionKind kind_) internal view returns (Position storage) {
        return _getPosition(_layout(), kind_);
    }

    function _getPositionTicks(Storage storage layout_, PositionKind kind_)
        internal
        view
        returns (int24 tickLower_, int24 tickUpper_)
    {
        Position storage position_ = _position(layout_, kind_);
        tickLower_ = position_.tickLower;
        tickUpper_ = position_.tickUpper;
    }

    function _getPositionTicks(PositionKind kind_) internal view returns (int24 tickLower_, int24 tickUpper_) {
        return _getPositionTicks(_layout(), kind_);
    }

    function _updatePositionLiquidity(Storage storage layout_, PositionKind kind_, uint128 liquidity_) internal {
        _position(layout_, kind_).liquidity = liquidity_;
    }

    function _updatePositionLiquidity(PositionKind kind_, uint128 liquidity_) internal {
        _updatePositionLiquidity(_layout(), kind_, liquidity_);
    }

    function _getPositionKey(Storage storage layout_, PositionKind kind_, address owner_)
        internal
        view
        returns (bytes32)
    {
        Position storage position_ = _position(layout_, kind_);
        return abi.encode(owner_, position_.tickLower, position_.tickUpper)._hash();
    }

    function _getPositionKey(PositionKind kind_, address owner_) internal view returns (bytes32) {
        return _getPositionKey(_layout(), kind_, owner_);
    }

    function _getOwnPositionKey(PositionKind kind_) internal view returns (bytes32) {
        return _getPositionKey(kind_, address(this));
    }

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

    function _centerWidthMultiplier(Storage storage layout_) internal view returns (uint24) {
        return layout_.strategy.centerWidthMultiplier;
    }

    function _centerWidthMultiplier() internal view returns (uint24) {
        return _centerWidthMultiplier(_layout());
    }

    function _activeLiquidityBps(Storage storage layout_) internal view returns (uint16) {
        return layout_.strategy.activeLiquidityBps;
    }

    function _activeLiquidityBps() internal view returns (uint16) {
        return _activeLiquidityBps(_layout());
    }

    function _inactiveLiquidityBps(Storage storage layout_) internal view returns (uint16) {
        return MAX_BPS - layout_.strategy.activeLiquidityBps;
    }

    function _inactiveLiquidityBps() internal view returns (uint16) {
        return _inactiveLiquidityBps(_layout());
    }

    function _setPoolState(Storage storage layout_, uint160 sqrtPriceX96_, int24 tick_, uint32 timestamp_) internal {
        layout_.lastSqrtPriceX96 = sqrtPriceX96_;
        layout_.lastTick = tick_;
        layout_.lastTimestamp = timestamp_;
    }

    function _lastPoolState(Storage storage layout_)
        internal
        view
        returns (uint160 sqrtPriceX96_, int24 tick_, uint32 timestamp_)
    {
        return (layout_.lastSqrtPriceX96, layout_.lastTick, layout_.lastTimestamp);
    }

    function _isPositionInRange(Storage storage layout_, PositionKind kind_, int24 currentTick) internal view returns (bool) {
        Position storage position_ = _position(layout_, kind_);
        return position_.created && currentTick >= position_.tickLower && currentTick < position_.tickUpper;
    }

    function _isPositionInRange(PositionKind kind_, int24 currentTick) internal view returns (bool) {
        return _isPositionInRange(_layout(), kind_, currentTick);
    }
}
