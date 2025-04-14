// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title AerodromeStandardExchangeRepo
 * @notice Storage library for Aerodrome Standard Exchange vault state.
 * @dev Tracks excess tokens (dust) from fee compounding operations that were
 *      too small to ZapIn efficiently. These are held until the next compound cycle.
 */
library AerodromeStandardExchangeRepo {
    bytes32 internal constant STORAGE_SLOT =
        keccak256(abi.encode("indexedex.protocols.dexes.aerodrome.v1.standardexchange"));

    struct Storage {
        /// @notice Excess token0 amount held from previous compound (below dust threshold)
        uint256 excessToken0;
        /// @notice Excess token1 amount held from previous compound (below dust threshold)
        uint256 excessToken1;
    }

    function _layout(bytes32 slot) internal pure returns (Storage storage layout_) {
        assembly {
            layout_.slot := slot
        }
    }

    function _layout() internal pure returns (Storage storage layout_) {
        return _layout(STORAGE_SLOT);
    }

    /* ------ Excess Token0 ------ */

    function _excessToken0(Storage storage layout_) internal view returns (uint256) {
        return layout_.excessToken0;
    }

    function _excessToken0() internal view returns (uint256) {
        return _excessToken0(_layout());
    }

    function _setExcessToken0(Storage storage layout_, uint256 amount_) internal {
        layout_.excessToken0 = amount_;
    }

    function _setExcessToken0(uint256 amount_) internal {
        _setExcessToken0(_layout(), amount_);
    }

    function _addExcessToken0(Storage storage layout_, uint256 amount_) internal {
        layout_.excessToken0 += amount_;
    }

    function _addExcessToken0(uint256 amount_) internal {
        _addExcessToken0(_layout(), amount_);
    }

    function _clearExcessToken0(Storage storage layout_) internal returns (uint256 cleared_) {
        cleared_ = layout_.excessToken0;
        layout_.excessToken0 = 0;
    }

    function _clearExcessToken0() internal returns (uint256 cleared_) {
        return _clearExcessToken0(_layout());
    }

    /* ------ Excess Token1 ------ */

    function _excessToken1(Storage storage layout_) internal view returns (uint256) {
        return layout_.excessToken1;
    }

    function _excessToken1() internal view returns (uint256) {
        return _excessToken1(_layout());
    }

    function _setExcessToken1(Storage storage layout_, uint256 amount_) internal {
        layout_.excessToken1 = amount_;
    }

    function _setExcessToken1(uint256 amount_) internal {
        _setExcessToken1(_layout(), amount_);
    }

    function _addExcessToken1(Storage storage layout_, uint256 amount_) internal {
        layout_.excessToken1 += amount_;
    }

    function _addExcessToken1(uint256 amount_) internal {
        _addExcessToken1(_layout(), amount_);
    }

    function _clearExcessToken1(Storage storage layout_) internal returns (uint256 cleared_) {
        cleared_ = layout_.excessToken1;
        layout_.excessToken1 = 0;
    }

    function _clearExcessToken1() internal returns (uint256 cleared_) {
        return _clearExcessToken1(_layout());
    }

    /* ------ Convenience ------ */

    function _clearExcessTokens(Storage storage layout_) internal returns (uint256 cleared0_, uint256 cleared1_) {
        cleared0_ = _clearExcessToken0(layout_);
        cleared1_ = _clearExcessToken1(layout_);
    }

    function _clearExcessTokens() internal returns (uint256 cleared0_, uint256 cleared1_) {
        return _clearExcessTokens(_layout());
    }
}
