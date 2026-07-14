// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {Math} from '@crane/contracts/utils/Math.sol';

import {IDETF} from 'contracts/interfaces/IDETF.sol';
import {IDETFNFTVault} from 'contracts/interfaces/IDETFNFTVault.sol';

library RebasingDETFTokenRepo {
    using Math for uint256;

    bytes32 internal constant STORAGE_SLOT = keccak256('indexedex.vaults.detf.composed.stable.common.rebasing.token');

    uint256 internal constant SHARE_SCALE = 1e9;
    uint256 internal constant SHARE_UNIT = 1e18 * SHARE_SCALE;

    struct Storage {
        IDETF detf;
        IDETFNFTVault nftVault;
        IERC20 rateAsset;
        uint256 detfNFTId;
        uint256 totalShares;
        mapping(address account => uint256 shares) sharesOf;
        uint256 cachedRedemptionRate;
        uint256 lastRateUpdateBlock;
    }

    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage layoutStruct_) {
        assembly {
            layoutStruct_.slot := slot_
        }
    }

    function _layoutStruct() internal pure returns (Storage storage) {
        return _layoutStruct(STORAGE_SLOT);
    }

    function _shareScale() internal pure returns (uint256) {
        return SHARE_SCALE;
    }

    function _shareUnit() internal pure returns (uint256) {
        return SHARE_UNIT;
    }

    function _initialize(
        Storage storage layoutStruct_,
        IDETF detf_,
        IDETFNFTVault nftVault_,
        IERC20 rateAsset_,
        uint256 detfNFTId_
    ) internal {
        layoutStruct_.detf = detf_;
        layoutStruct_.nftVault = nftVault_;
        layoutStruct_.rateAsset = rateAsset_;
        layoutStruct_.detfNFTId = detfNFTId_;
        layoutStruct_.cachedRedemptionRate = 1e18;
    }

    function _initialize(IDETF detf_, IDETFNFTVault nftVault_, IERC20 rateAsset_, uint256 detfNFTId_) internal {
        _initialize(_layoutStruct(), detf_, nftVault_, rateAsset_, detfNFTId_);
    }

    function _detf(Storage storage layoutStruct_) internal view returns (IDETF) {
        return layoutStruct_.detf;
    }

    function _detf() internal view returns (IDETF) {
        return _detf(_layoutStruct());
    }

    function _setDetf(Storage storage layoutStruct_, IDETF detf_) internal {
        layoutStruct_.detf = detf_;
    }

    function _setDetf(IDETF detf_) internal {
        _setDetf(_layoutStruct(), detf_);
    }

    function _nftVault(Storage storage layoutStruct_) internal view returns (IDETFNFTVault) {
        return layoutStruct_.nftVault;
    }

    function _nftVault() internal view returns (IDETFNFTVault) {
        return _nftVault(_layoutStruct());
    }

    function _rateAsset(Storage storage layoutStruct_) internal view returns (IERC20) {
        return layoutStruct_.rateAsset;
    }

    function _rateAsset() internal view returns (IERC20) {
        return _rateAsset(_layoutStruct());
    }

    function _detfNFTId(Storage storage layoutStruct_) internal view returns (uint256) {
        return layoutStruct_.detfNFTId;
    }

    function _detfNFTId() internal view returns (uint256) {
        return _detfNFTId(_layoutStruct());
    }

    function _totalShares(Storage storage layoutStruct_) internal view returns (uint256) {
        return layoutStruct_.totalShares;
    }

    function _totalShares() internal view returns (uint256) {
        return _totalShares(_layoutStruct());
    }

    function _sharesOf(Storage storage layoutStruct_, address account_) internal view returns (uint256) {
        return layoutStruct_.sharesOf[account_];
    }

    function _sharesOf(address account_) internal view returns (uint256) {
        return _sharesOf(_layoutStruct(), account_);
    }

    function _cachedRedemptionRate(Storage storage layoutStruct_) internal view returns (uint256) {
        return layoutStruct_.cachedRedemptionRate;
    }

    function _lastRateUpdateBlock(Storage storage layoutStruct_) internal view returns (uint256) {
        return layoutStruct_.lastRateUpdateBlock;
    }

    function _setCachedRedemptionRate(Storage storage layoutStruct_, uint256 rate_) internal {
        layoutStruct_.cachedRedemptionRate = rate_;
        layoutStruct_.lastRateUpdateBlock = block.number;
    }

    function _mintShares(Storage storage layoutStruct_, address account_, uint256 shares_) internal {
        layoutStruct_.sharesOf[account_] += shares_;
        layoutStruct_.totalShares += shares_;
    }

    function _burnShares(Storage storage layoutStruct_, address account_, uint256 shares_) internal {
        require(layoutStruct_.sharesOf[account_] >= shares_, 'RebasingDETFToken: insufficient shares');
        layoutStruct_.sharesOf[account_] -= shares_;
        layoutStruct_.totalShares -= shares_;
    }

    function _transferShares(Storage storage layoutStruct_, address from_, address to_, uint256 shares_) internal {
        require(layoutStruct_.sharesOf[from_] >= shares_, 'RebasingDETFToken: insufficient shares');
        layoutStruct_.sharesOf[from_] -= shares_;
        layoutStruct_.sharesOf[to_] += shares_;
    }

    function _externalSharesToInternal(uint256 externalShares_) internal pure returns (uint256) {
        return externalShares_ * SHARE_SCALE;
    }

    function _internalSharesToExternal(uint256 internalShares_) internal pure returns (uint256) {
        return internalShares_ / SHARE_SCALE;
    }

    function _sharesToBalance(uint256 internalShares_, uint256 redemptionRate_) internal pure returns (uint256) {
        return internalShares_.mulDiv(redemptionRate_, SHARE_UNIT);
    }

    function _balanceToShares(uint256 balance_, uint256 redemptionRate_) internal pure returns (uint256) {
        if (redemptionRate_ == 0) return 0;
        return balance_.mulDiv(SHARE_UNIT, redemptionRate_);
    }
}