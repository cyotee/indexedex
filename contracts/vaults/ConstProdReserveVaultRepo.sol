// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";

library ConstProdReserveVaultRepo {
    using AddressSetRepo for AddressSet;

    bytes32 internal constant STORAGE_SLOT = keccak256(abi.encode("indexedex.vaults.constprodreserve"));

    struct Storage {
        address token0;
        address token1;
        uint256 reserveAssetKLast;
        mapping(address token => address opposingToken) opposingTokenOfToken;
        mapping(address token => uint256 reserve) yieldReserveOfToken;
        AddressSet reserveAssetContents;
        // Excess tokens held for next compound cycle (below dust threshold)
        uint256 pendingExcessToken0;
        uint256 pendingExcessToken1;
    }

    function _layoutStruct(bytes32 slot) internal pure returns (Storage storage layoutStruct_) {
        assembly {
            layoutStruct_.slot := slot
        }
    }

    function _layoutStruct() internal pure returns (Storage storage layoutStruct_) {
        return _layoutStruct(STORAGE_SLOT);
    }

    function _initialize(Storage storage layoutStruct_, address token0_, address token1_) internal {
        layoutStruct_.token0 = token0_;
        layoutStruct_.token1 = token1_;
        layoutStruct_.opposingTokenOfToken[token0_] = token1_;
        layoutStruct_.opposingTokenOfToken[token1_] = token0_;
        layoutStruct_.reserveAssetContents._add(token0_);
        layoutStruct_.reserveAssetContents._add(token1_);
    }

    function _initialize(address token0_, address token1_) internal {
        _initialize(_layoutStruct(), token0_, token1_);
    }

    function _token0(Storage storage layoutStruct_) internal view returns (address token0_) {
        return layoutStruct_.token0;
    }

    function _token0() internal view returns (address token0_) {
        return _token0(_layoutStruct());
    }

    function _token1(Storage storage layoutStruct_) internal view returns (address token1_) {
        return layoutStruct_.token1;
    }

    function _token1() internal view returns (address token1_) {
        return _token1(_layoutStruct());
    }

    function _reserveAssetKLast(Storage storage layoutStruct_) internal view returns (uint256 reserveAssetKLast_) {
        return layoutStruct_.reserveAssetKLast;
    }

    function _reserveAssetKLast() internal view returns (uint256 reserveAssetKLast_) {
        return _reserveAssetKLast(_layoutStruct());
    }

    function _setReserveAssetKLast(Storage storage layoutStruct_, uint256 reserveAssetKLast_) internal {
        layoutStruct_.reserveAssetKLast = reserveAssetKLast_;
    }

    function _setReserveAssetKLast(uint256 reserveAssetKLast_) internal {
        _setReserveAssetKLast(_layoutStruct(), reserveAssetKLast_);
    }

    function _opposingToken(Storage storage layoutStruct_, address token_) internal view returns (address opposingToken_) {
        return layoutStruct_.opposingTokenOfToken[token_];
    }

    function _opposingToken(address token_) internal view returns (address opposingToken_) {
        return _opposingToken(_layoutStruct(), token_);
    }

    function _yieldReserveOfToken(Storage storage layoutStruct_, address token_) internal view returns (uint256 reserve_) {
        return layoutStruct_.yieldReserveOfToken[token_];
    }

    function _yieldReserveOfToken(address token_) internal view returns (uint256 reserve_) {
        return _yieldReserveOfToken(_layoutStruct(), token_);
    }

    function _setYieldReserveOfToken(Storage storage layoutStruct_, address token_, uint256 reserve_) internal {
        layoutStruct_.yieldReserveOfToken[token_] = reserve_;
    }

    function _setYieldReserveOfToken(address token_, uint256 reserve_) internal {
        _setYieldReserveOfToken(_layoutStruct(), token_, reserve_);
    }

    function _isReserveAssetContained(Storage storage layoutStruct_, address token_) internal view returns (bool contains_) {
        return layoutStruct_.reserveAssetContents._contains(token_);
    }

    function _isReserveAssetContained(address token_) internal view returns (bool contains_) {
        return _isReserveAssetContained(_layoutStruct(), token_);
    }

    function _pendingExcessToken0(Storage storage layoutStruct_) internal view returns (uint256) {
        return layoutStruct_.pendingExcessToken0;
    }

    function _pendingExcessToken0() internal view returns (uint256) {
        return _pendingExcessToken0(_layoutStruct());
    }

    function _pendingExcessToken1(Storage storage layoutStruct_) internal view returns (uint256) {
        return layoutStruct_.pendingExcessToken1;
    }

    function _pendingExcessToken1() internal view returns (uint256) {
        return _pendingExcessToken1(_layoutStruct());
    }

    function _setPendingExcessToken0(Storage storage layoutStruct_, uint256 amount_) internal {
        layoutStruct_.pendingExcessToken0 = amount_;
    }

    function _setPendingExcessToken0(uint256 amount_) internal {
        _setPendingExcessToken0(_layoutStruct(), amount_);
    }

    function _setPendingExcessToken1(Storage storage layoutStruct_, uint256 amount_) internal {
        layoutStruct_.pendingExcessToken1 = amount_;
    }

    function _setPendingExcessToken1(uint256 amount_) internal {
        _setPendingExcessToken1(_layoutStruct(), amount_);
    }

    function _addPendingExcessToken0(Storage storage layoutStruct_, uint256 amount_) internal {
        layoutStruct_.pendingExcessToken0 += amount_;
    }

    function _addPendingExcessToken0(uint256 amount_) internal {
        _addPendingExcessToken0(_layoutStruct(), amount_);
    }

    function _addPendingExcessToken1(Storage storage layoutStruct_, uint256 amount_) internal {
        layoutStruct_.pendingExcessToken1 += amount_;
    }

    function _addPendingExcessToken1(uint256 amount_) internal {
        _addPendingExcessToken1(_layoutStruct(), amount_);
    }

    function _clearPendingExcessTokens(Storage storage layoutStruct_) internal {
        layoutStruct_.pendingExcessToken0 = 0;
        layoutStruct_.pendingExcessToken1 = 0;
    }

    function _clearPendingExcessTokens() internal {
        _clearPendingExcessTokens(_layoutStruct());
    }
}
