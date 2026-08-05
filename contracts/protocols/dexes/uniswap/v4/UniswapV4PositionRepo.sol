// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";

library UniswapV4PositionRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.protocols.dexes.uniswap.v4.position");
    bytes32 internal constant LOWER_WING_SALT = keccak256("indexedex.protocols.dexes.uniswap.v4.position.lowerWing");
    bytes32 internal constant UPPER_WING_SALT = keccak256("indexedex.protocols.dexes.uniswap.v4.position.upperWing");
    uint16 internal constant MAX_BPS = 10_000;

    enum PositionKind {
        Center,
        LowerWing,
        UpperWing
    }

    struct PositionState {
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        bytes32 salt;
        bool created;
    }

    struct StrategyConfig {
        uint24 widthMultiplier;
        uint24 centerWidthMultiplier;
        uint16 activeLiquidityBps;
    }

    struct Storage {
        PositionState centerPosition;
        PositionState lowerWingPosition;
        PositionState upperWingPosition;
        IPositionManager importedPositionManager;
        uint256 importedPositionTokenId;
        bool importedPositionActive;
        StrategyConfig strategy;
        uint160 lastSqrtPriceX96;
        int24 lastTick;
        uint32 lastTimestamp;
    }

    function _layout(bytes32 slot_) internal pure returns (Storage storage layout_) {
        assembly {
            layout_.slot := slot_
        }
    }

    function _layout() internal pure returns (Storage storage layout_) {
        return _layout(STORAGE_SLOT);
    }

    function _initialize(Storage storage layout_, uint24 widthMultiplier_, bytes32 salt_) internal {
        require(widthMultiplier_ >= 1, "widthMultiplier must be >= 1");
        layout_.strategy =
            StrategyConfig({widthMultiplier: widthMultiplier_, centerWidthMultiplier: 2, activeLiquidityBps: 1000});
        layout_.centerPosition.salt = salt_;
        layout_.lowerWingPosition.salt = LOWER_WING_SALT;
        layout_.upperWingPosition.salt = UPPER_WING_SALT;
    }

    function _initialize(uint24 widthMultiplier_, bytes32 salt_) internal {
        _initialize(_layout(), widthMultiplier_, salt_);
    }

    function _position(Storage storage layout_, PositionKind kind_)
        internal
        view
        returns (PositionState storage position_)
    {
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
        PositionState storage position_ = _position(layout_, kind_);
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

    function _initializeImportedPosition(
        Storage storage layout_,
        IPositionManager positionManager_,
        uint256 tokenId_,
        int24 tickLower_,
        int24 tickUpper_
    ) internal {
        layout_.importedPositionManager = positionManager_;
        layout_.importedPositionTokenId = tokenId_;
        layout_.importedPositionActive = true;
        layout_.centerPosition.tickLower = tickLower_;
        layout_.centerPosition.tickUpper = tickUpper_;
        layout_.centerPosition.created = true;
        layout_.lowerWingPosition.created = false;
        layout_.upperWingPosition.created = false;
        layout_.lowerWingPosition.liquidity = 0;
        layout_.upperWingPosition.liquidity = 0;
    }

    function _initializeImportedPosition(
        IPositionManager positionManager_,
        uint256 tokenId_,
        int24 tickLower_,
        int24 tickUpper_
    ) internal {
        _initializeImportedPosition(_layout(), positionManager_, tokenId_, tickLower_, tickUpper_);
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

    function _isImportedPosition(Storage storage layout_) internal view returns (bool imported_) {
        return layout_.importedPositionActive;
    }

    function _isImportedPosition() internal view returns (bool imported_) {
        return _isImportedPosition(_layout());
    }

    function _importedPositionManager(Storage storage layout_) internal view returns (IPositionManager manager_) {
        return layout_.importedPositionManager;
    }

    function _importedPositionManager() internal view returns (IPositionManager manager_) {
        return _importedPositionManager(_layout());
    }

    function _importedPositionTokenId(Storage storage layout_) internal view returns (uint256 tokenId_) {
        return layout_.importedPositionTokenId;
    }

    function _importedPositionTokenId() internal view returns (uint256 tokenId_) {
        return _importedPositionTokenId(_layout());
    }

    function _liquidity(Storage storage layout_) internal view returns (uint128 liquidity_) {
        return
            layout_.centerPosition.liquidity + layout_.lowerWingPosition.liquidity + layout_.upperWingPosition.liquidity;
    }

    function _liquidity() internal view returns (uint128 liquidity_) {
        return _liquidity(_layout());
    }

    function _liquidity(Storage storage layout_, PositionKind kind_) internal view returns (uint128 liquidity_) {
        return _position(layout_, kind_).liquidity;
    }

    function _liquidity(PositionKind kind_) internal view returns (uint128 liquidity_) {
        return _liquidity(_layout(), kind_);
    }

    function _updateLiquidity(Storage storage layout_, uint128 liquidity_) internal {
        layout_.centerPosition.liquidity = liquidity_;
    }

    function _updateLiquidity(uint128 liquidity_) internal {
        _updateLiquidity(_layout(), liquidity_);
    }

    function _updateLiquidity(Storage storage layout_, PositionKind kind_, uint128 liquidity_) internal {
        _position(layout_, kind_).liquidity = liquidity_;
    }

    function _updateLiquidity(PositionKind kind_, uint128 liquidity_) internal {
        _updateLiquidity(_layout(), kind_, liquidity_);
    }

    function _positionTicks(Storage storage layout_) internal view returns (int24 tickLower_, int24 tickUpper_) {
        tickLower_ = layout_.centerPosition.tickLower;
        tickUpper_ = layout_.centerPosition.tickUpper;
    }

    function _positionTicks() internal view returns (int24 tickLower_, int24 tickUpper_) {
        return _positionTicks(_layout());
    }

    function _positionTicks(Storage storage layout_, PositionKind kind_)
        internal
        view
        returns (int24 tickLower_, int24 tickUpper_)
    {
        PositionState storage position_ = _position(layout_, kind_);
        tickLower_ = position_.tickLower;
        tickUpper_ = position_.tickUpper;
    }

    function _positionTicks(PositionKind kind_) internal view returns (int24 tickLower_, int24 tickUpper_) {
        return _positionTicks(_layout(), kind_);
    }

    function _salt(Storage storage layout_) internal view returns (bytes32 salt_) {
        return layout_.centerPosition.salt;
    }

    function _salt() internal view returns (bytes32 salt_) {
        return _salt(_layout());
    }

    function _salt(Storage storage layout_, PositionKind kind_) internal view returns (bytes32 salt_) {
        return _position(layout_, kind_).salt;
    }

    function _salt(PositionKind kind_) internal view returns (bytes32 salt_) {
        return _salt(_layout(), kind_);
    }

    function _widthMultiplier(Storage storage layout_) internal view returns (uint24 widthMultiplier_) {
        return layout_.strategy.widthMultiplier;
    }

    function _widthMultiplier() internal view returns (uint24 widthMultiplier_) {
        return _widthMultiplier(_layout());
    }

    function _centerWidthMultiplier(Storage storage layout_) internal view returns (uint24 centerWidthMultiplier_) {
        return layout_.strategy.centerWidthMultiplier;
    }

    function _centerWidthMultiplier() internal view returns (uint24 centerWidthMultiplier_) {
        return _centerWidthMultiplier(_layout());
    }

    function _activeLiquidityBps(Storage storage layout_) internal view returns (uint16 activeLiquidityBps_) {
        return layout_.strategy.activeLiquidityBps;
    }

    function _activeLiquidityBps() internal view returns (uint16 activeLiquidityBps_) {
        return _activeLiquidityBps(_layout());
    }

    function _inactiveLiquidityBps(Storage storage layout_) internal view returns (uint16 inactiveLiquidityBps_) {
        return MAX_BPS - layout_.strategy.activeLiquidityBps;
    }

    function _inactiveLiquidityBps() internal view returns (uint16 inactiveLiquidityBps_) {
        return _inactiveLiquidityBps(_layout());
    }

    function _setPoolState(Storage storage layout_, uint160 sqrtPriceX96_, int24 tick_, uint32 timestamp_) internal {
        layout_.lastSqrtPriceX96 = sqrtPriceX96_;
        layout_.lastTick = tick_;
        layout_.lastTimestamp = timestamp_;
    }

    function _setPoolState(uint160 sqrtPriceX96_, int24 tick_, uint32 timestamp_) internal {
        _setPoolState(_layout(), sqrtPriceX96_, tick_, timestamp_);
    }
}
