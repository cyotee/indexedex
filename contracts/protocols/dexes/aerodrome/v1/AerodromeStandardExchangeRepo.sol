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

    function _layoutStruct(bytes32 slot) internal pure returns (Storage storage layoutStruct_) {
        assembly {
            layoutStruct_.slot := slot
        }
    }

    function _layoutStruct() internal pure returns (Storage storage layoutStruct_) {
        return _layoutStruct(STORAGE_SLOT);
    }

    /* ------ Excess Token0 ------ */

    function _excessToken0(Storage storage layoutStruct_) internal view returns (uint256) {
        return layoutStruct_.excessToken0;
    }

    function _excessToken0() internal view returns (uint256) {
        return _excessToken0(_layoutStruct());
    }

    function _setExcessToken0(Storage storage layoutStruct_, uint256 amount_) internal {
        layoutStruct_.excessToken0 = amount_;
    }

    function _setExcessToken0(uint256 amount_) internal {
        _setExcessToken0(_layoutStruct(), amount_);
    }

    function _addExcessToken0(Storage storage layoutStruct_, uint256 amount_) internal {
        layoutStruct_.excessToken0 += amount_;
    }

    function _addExcessToken0(uint256 amount_) internal {
        _addExcessToken0(_layoutStruct(), amount_);
    }

    function _clearExcessToken0(Storage storage layoutStruct_) internal returns (uint256 cleared_) {
        cleared_ = layoutStruct_.excessToken0;
        layoutStruct_.excessToken0 = 0;
    }

    function _clearExcessToken0() internal returns (uint256 cleared_) {
        return _clearExcessToken0(_layoutStruct());
    }

    /* ------ Excess Token1 ------ */

    function _excessToken1(Storage storage layoutStruct_) internal view returns (uint256) {
        return layoutStruct_.excessToken1;
    }

    function _excessToken1() internal view returns (uint256) {
        return _excessToken1(_layoutStruct());
    }

    function _setExcessToken1(Storage storage layoutStruct_, uint256 amount_) internal {
        layoutStruct_.excessToken1 = amount_;
    }

    function _setExcessToken1(uint256 amount_) internal {
        _setExcessToken1(_layoutStruct(), amount_);
    }

    function _addExcessToken1(Storage storage layoutStruct_, uint256 amount_) internal {
        layoutStruct_.excessToken1 += amount_;
    }

    function _addExcessToken1(uint256 amount_) internal {
        _addExcessToken1(_layoutStruct(), amount_);
    }

    function _clearExcessToken1(Storage storage layoutStruct_) internal returns (uint256 cleared_) {
        cleared_ = layoutStruct_.excessToken1;
        layoutStruct_.excessToken1 = 0;
    }

    function _clearExcessToken1() internal returns (uint256 cleared_) {
        return _clearExcessToken1(_layoutStruct());
    }

    /* ------ Convenience ------ */

    function _clearExcessTokens(Storage storage layoutStruct_) internal returns (uint256 cleared0_, uint256 cleared1_) {
        cleared0_ = _clearExcessToken0(layoutStruct_);
        cleared1_ = _clearExcessToken1(layoutStruct_);
    }

    function _clearExcessTokens() internal returns (uint256 cleared0_, uint256 cleared1_) {
        return _clearExcessTokens(_layoutStruct());
    }
}
