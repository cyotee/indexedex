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

    function _layout(bytes32 slot) internal pure returns (Storage storage layout_) {
        assembly {
            layout_.slot := slot
        }
    }

    function _layout() internal pure returns (Storage storage layout_) {
        return _layout(STORAGE_SLOT);
    }

    function _initialize(Storage storage layout_, address token0_, address token1_) internal {
        layout_.token0 = token0_;
        layout_.token1 = token1_;
        layout_.opposingTokenOfToken[token0_] = token1_;
        layout_.opposingTokenOfToken[token1_] = token0_;
        layout_.reserveAssetContents._add(token0_);
        layout_.reserveAssetContents._add(token1_);
    }

    function _initialize(address token0_, address token1_) internal {
        _initialize(_layout(), token0_, token1_);
    }

    function _token0(Storage storage layout_) internal view returns (address token0_) {
        return layout_.token0;
    }

    function _token0() internal view returns (address token0_) {
        return _token0(_layout());
    }

    function _token1(Storage storage layout_) internal view returns (address token1_) {
        return layout_.token1;
    }

    function _token1() internal view returns (address token1_) {
        return _token1(_layout());
    }

    function _reserveAssetKLast(Storage storage layout_) internal view returns (uint256 reserveAssetKLast_) {
        return layout_.reserveAssetKLast;
    }

    function _reserveAssetKLast() internal view returns (uint256 reserveAssetKLast_) {
        return _reserveAssetKLast(_layout());
    }

    function _setReserveAssetKLast(Storage storage layout_, uint256 reserveAssetKLast_) internal {
        layout_.reserveAssetKLast = reserveAssetKLast_;
    }

    function _setReserveAssetKLast(uint256 reserveAssetKLast_) internal {
        _setReserveAssetKLast(_layout(), reserveAssetKLast_);
    }

    function _opposingToken(Storage storage layout_, address token_) internal view returns (address opposingToken_) {
        return layout_.opposingTokenOfToken[token_];
    }

    function _opposingToken(address token_) internal view returns (address opposingToken_) {
        return _opposingToken(_layout(), token_);
    }

    function _yieldReserveOfToken(Storage storage layout_, address token_) internal view returns (uint256 reserve_) {
        return layout_.yieldReserveOfToken[token_];
    }

    function _yieldReserveOfToken(address token_) internal view returns (uint256 reserve_) {
        return _yieldReserveOfToken(_layout(), token_);
    }

    function _setYieldReserveOfToken(Storage storage layout_, address token_, uint256 reserve_) internal {
        layout_.yieldReserveOfToken[token_] = reserve_;
    }

    function _setYieldReserveOfToken(address token_, uint256 reserve_) internal {
        _setYieldReserveOfToken(_layout(), token_, reserve_);
    }

    function _isReserveAssetContained(Storage storage layout_, address token_) internal view returns (bool contains_) {
        return layout_.reserveAssetContents._contains(token_);
    }

    function _isReserveAssetContained(address token_) internal view returns (bool contains_) {
        return _isReserveAssetContained(_layout(), token_);
    }

    function _pendingExcessToken0(Storage storage layout_) internal view returns (uint256) {
        return layout_.pendingExcessToken0;
    }

    function _pendingExcessToken0() internal view returns (uint256) {
        return _pendingExcessToken0(_layout());
    }

    function _pendingExcessToken1(Storage storage layout_) internal view returns (uint256) {
        return layout_.pendingExcessToken1;
    }

    function _pendingExcessToken1() internal view returns (uint256) {
        return _pendingExcessToken1(_layout());
    }

    function _setPendingExcessToken0(Storage storage layout_, uint256 amount_) internal {
        layout_.pendingExcessToken0 = amount_;
    }

    function _setPendingExcessToken0(uint256 amount_) internal {
        _setPendingExcessToken0(_layout(), amount_);
    }

    function _setPendingExcessToken1(Storage storage layout_, uint256 amount_) internal {
        layout_.pendingExcessToken1 = amount_;
    }

    function _setPendingExcessToken1(uint256 amount_) internal {
        _setPendingExcessToken1(_layout(), amount_);
    }

    function _addPendingExcessToken0(Storage storage layout_, uint256 amount_) internal {
        layout_.pendingExcessToken0 += amount_;
    }

    function _addPendingExcessToken0(uint256 amount_) internal {
        _addPendingExcessToken0(_layout(), amount_);
    }

    function _addPendingExcessToken1(Storage storage layout_, uint256 amount_) internal {
        layout_.pendingExcessToken1 += amount_;
    }

    function _addPendingExcessToken1(uint256 amount_) internal {
        _addPendingExcessToken1(_layout(), amount_);
    }

    function _clearPendingExcessTokens(Storage storage layout_) internal {
        layout_.pendingExcessToken0 = 0;
        layout_.pendingExcessToken1 = 0;
    }

    function _clearPendingExcessTokens() internal {
        _clearPendingExcessTokens(_layout());
    }
}
