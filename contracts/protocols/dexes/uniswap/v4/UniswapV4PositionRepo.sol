// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";

library UniswapV4PositionRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.protocols.dexes.uniswap.v4.position");

    struct PositionState {
        int24 tickLower;
        int24 tickUpper;
        bytes32 salt;
        bool created;
    }

    struct Storage {
        PositionState centerPosition;
        IPositionManager importedPositionManager;
        uint256 importedPositionTokenId;
        bool importedPositionActive;
        IPositionManager authorizedPositionManager;
    }

    function _layout(bytes32 slot_) internal pure returns (Storage storage layout_) {
        assembly {
            layout_.slot := slot_
        }
    }

    function _layout() internal pure returns (Storage storage layout_) {
        return _layout(STORAGE_SLOT);
    }

    function _initialize(Storage storage layout_, bytes32 salt_) internal {
        layout_.centerPosition.salt = salt_;
    }

    function _initialize(bytes32 salt_) internal {
        _initialize(_layout(), salt_);
    }

    function _createPositionIfNeeded(Storage storage layout_, int24 tickLower_, int24 tickUpper_)
        internal
    {
        PositionState storage position_ = layout_.centerPosition;
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
    }

    function _initializeImportedPosition(
        IPositionManager positionManager_,
        uint256 tokenId_,
        int24 tickLower_,
        int24 tickUpper_
    ) internal {
        _initializeImportedPosition(_layout(), positionManager_, tokenId_, tickLower_, tickUpper_);
    }

    /// @dev The emptied import NFT remains recorded, but backing uses the managed full-range book.
    function _finishImportedConversion() internal {
        Storage storage layout_ = _layout();
        layout_.importedPositionActive = false;
        layout_.centerPosition.created = false;
    }

    function _isPositionCreated(Storage storage layout_) internal view returns (bool) {
        return layout_.centerPosition.created;
    }

    function _isPositionCreated() internal view returns (bool) {
        return _isPositionCreated(_layout());
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

    function _positionTicks(Storage storage layout_) internal view returns (int24 tickLower_, int24 tickUpper_) {
        tickLower_ = layout_.centerPosition.tickLower;
        tickUpper_ = layout_.centerPosition.tickUpper;
    }

    function _positionTicks() internal view returns (int24 tickLower_, int24 tickUpper_) {
        return _positionTicks(_layout());
    }

    function _salt(Storage storage layout_) internal view returns (bytes32 salt_) {
        return layout_.centerPosition.salt;
    }

    function _salt() internal view returns (bytes32 salt_) {
        return _salt(_layout());
    }

    function _setAuthorizedPositionManager(Storage storage layout_, IPositionManager positionManager_) internal {
        layout_.authorizedPositionManager = positionManager_;
    }

    function _setAuthorizedPositionManager(IPositionManager positionManager_) internal {
        _setAuthorizedPositionManager(_layout(), positionManager_);
    }

    function _authorizedPositionManager(Storage storage layout_) internal view returns (IPositionManager manager_) {
        return layout_.authorizedPositionManager;
    }

    function _authorizedPositionManager() internal view returns (IPositionManager manager_) {
        return _authorizedPositionManager(_layout());
    }
}
