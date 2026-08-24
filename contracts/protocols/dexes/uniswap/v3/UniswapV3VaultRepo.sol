// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/**
 * @title UniswapV3VaultRepo
 * @notice Strategy + one vault-owned bound-pool position for Uniswap V3 Standard Exchange vaults.
 * @dev Organic books use Crane V3 `TickMath.minUsableTick` / `maxUsableTick` as the single center.
 *      Imported books keep the NFT ticks as that center. `widthMultiplier` is ABI-only (`>= 1`) and
 *      does not size ticks. Position keys use Uniswap V3 canonical packing:
 *      `keccak256(abi.encodePacked(owner, tickLower, tickUpper))`.
 */
library UniswapV3VaultRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.protocols.dexes.uniswap.v3.vault");

    struct Position {
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        bool created;
    }

    /// @dev `widthMultiplier` is required at deploy (`>= 1`) and ignored for tick geometry (D30/D31).
    struct StrategyConfig {
        uint24 widthMultiplier;
    }

    struct Storage {
        Position centerPosition;
        StrategyConfig strategy;
        uint160 lastSqrtPriceX96;
        int24 lastTick;
        uint32 lastTimestamp;
        address importedPositionManager;
        uint256 importedPositionTokenId;
        bool importedPositionActive;
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
        layout_.strategy = StrategyConfig({widthMultiplier: widthMultiplier_});
    }

    function _initialize(uint24 widthMultiplier_) internal {
        _initialize(_layout(), widthMultiplier_);
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

    /// @notice Mark the imported NFT range as the single center (ticks as-is; D34).
    function _initializeImportedCenter(
        Storage storage layout_,
        address positionManager_,
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
        layout_.centerPosition.liquidity = 0;
    }

    function _initializeImportedCenter(address positionManager_, uint256 tokenId_, int24 tickLower_, int24 tickUpper_)
        internal
    {
        _initializeImportedCenter(_layout(), positionManager_, tokenId_, tickLower_, tickUpper_);
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

    function _updatePositionLiquidity(Storage storage layout_, uint128 liquidity_) internal {
        layout_.centerPosition.liquidity = liquidity_;
    }

    function _updatePositionLiquidity(uint128 liquidity_) internal {
        _updatePositionLiquidity(_layout(), liquidity_);
    }

    /// @dev Canonical Uniswap V3 position key (no salt).
    function _getPositionKey(address owner_, int24 tickLower_, int24 tickUpper_) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner_, tickLower_, tickUpper_));
    }

    function _getOwnPositionKey() internal view returns (bytes32) {
        (int24 tickLower_, int24 tickUpper_) = _getPositionTicks();
        return _getPositionKey(address(this), tickLower_, tickUpper_);
    }

    function _strategy() internal view returns (StrategyConfig memory) {
        return _layout().strategy;
    }

    function _widthMultiplier() internal view returns (uint24) {
        return _layout().strategy.widthMultiplier;
    }

    function _setPoolState(uint160 sqrtPriceX96_, int24 tick_, uint32 timestamp_) internal {
        Storage storage layout_ = _layout();
        layout_.lastSqrtPriceX96 = sqrtPriceX96_;
        layout_.lastTick = tick_;
        layout_.lastTimestamp = timestamp_;
    }

    function _importedPositionManager() internal view returns (address) {
        return _layout().importedPositionManager;
    }

    function _importedPositionTokenId() internal view returns (uint256) {
        return _layout().importedPositionTokenId;
    }

    function _importedPositionActive() internal view returns (bool) {
        return _layout().importedPositionActive;
    }
}
