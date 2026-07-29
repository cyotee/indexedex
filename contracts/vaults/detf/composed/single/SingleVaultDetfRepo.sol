// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {AddressSet} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";
import {AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {IDetfErrors} from "contracts/interfaces/IDetfErrors.sol";
import {ThresholdMode} from "contracts/vaults/detf/core/DETFThresholdPolicy.sol";

library SingleVaultDetfRepo {
    using AddressSetRepo for AddressSet;

    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.vaults.detf.composed.single");

    struct Storage {
        bool isReservePoolInitialized;
        IERC20 pairToken;
        IRebasingClaimToken rebasingClaimToken;
        IERC20 rateAsset;
        IStandardExchange underlyingVault;
        IDETFNFTVault detfNFTVault;
        IVaultFeeOracleQuery feeOracle;
        IBalancerV3StandardExchangeRouterPrepay balancerV3PrepayRouter;
        IRateProvider vaultRateProvider;
        address reservePool;
        bytes32 underlyingPoolKeyHash;
        uint256 detfNFTId;
        uint256 detfIndex;
        uint256 vaultTokenIndex;
        uint256 detfWeight;
        uint256 vaultTokenWeight;
        uint256 mintThreshold;
        uint256 burnThreshold;
        ThresholdMode thresholdMode;
        AddressSet acceptedBondTokens;
    }

    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage layoutStruct_) {
        assembly {
            layoutStruct_.slot := slot_
        }
    }

    function _layoutStruct() internal pure returns (Storage storage layoutStruct_) {
        return _layoutStruct(STORAGE_SLOT);
    }

    function _initialize(
        Storage storage layoutStruct_,
        IVaultFeeOracleQuery feeOracle_,
        IBalancerV3StandardExchangeRouterPrepay balancerV3PrepayRouter_,
        IERC20 pairToken_,
        IERC20 rateAsset_,
        uint256 mintThreshold_,
        uint256 burnThreshold_,
        ThresholdMode thresholdMode_
    ) internal {
        layoutStruct_.feeOracle = feeOracle_;
        layoutStruct_.balancerV3PrepayRouter = balancerV3PrepayRouter_;
        layoutStruct_.pairToken = pairToken_;
        layoutStruct_.rateAsset = rateAsset_;
        layoutStruct_.mintThreshold = mintThreshold_;
        layoutStruct_.burnThreshold = burnThreshold_;
        layoutStruct_.thresholdMode = thresholdMode_;
        layoutStruct_.acceptedBondTokens._add(address(rateAsset_));
        layoutStruct_.acceptedBondTokens._add(address(pairToken_));
    }

    function _initialize(
        IVaultFeeOracleQuery feeOracle_,
        IBalancerV3StandardExchangeRouterPrepay balancerV3PrepayRouter_,
        IERC20 pairToken_,
        IERC20 rateAsset_,
        uint256 mintThreshold_,
        uint256 burnThreshold_,
        ThresholdMode thresholdMode_
    ) internal {
        _initialize(
            _layoutStruct(),
            feeOracle_,
            balancerV3PrepayRouter_,
            pairToken_,
            rateAsset_,
            mintThreshold_,
            burnThreshold_,
            thresholdMode_
        );
    }

    function _thresholdMode(Storage storage layoutStruct_) internal view returns (ThresholdMode thresholdMode_) {
        return layoutStruct_.thresholdMode;
    }

    function _thresholdMode() internal view returns (ThresholdMode thresholdMode_) {
        return _thresholdMode(_layoutStruct());
    }

    function _initializeDependencies(
        Storage storage layoutStruct_,
        IStandardExchange underlyingVault_,
        IRateProvider vaultRateProvider_,
        bytes32 underlyingPoolKeyHash_
    ) internal {
        layoutStruct_.underlyingVault = underlyingVault_;
        layoutStruct_.vaultRateProvider = vaultRateProvider_;
        layoutStruct_.underlyingPoolKeyHash = underlyingPoolKeyHash_;
    }

    function _initializeDependencies(
        IStandardExchange underlyingVault_,
        IRateProvider vaultRateProvider_,
        bytes32 underlyingPoolKeyHash_
    ) internal {
        _initializeDependencies(_layoutStruct(), underlyingVault_, vaultRateProvider_, underlyingPoolKeyHash_);
    }

    function _initializeDependencies(
        Storage storage layoutStruct_,
        IStandardExchange underlyingVault_,
        IRateProvider vaultRateProvider_
    ) internal {
        _initializeDependencies(layoutStruct_, underlyingVault_, vaultRateProvider_, layoutStruct_.underlyingPoolKeyHash);
    }

    function _initializeDependencies(IStandardExchange underlyingVault_, IRateProvider vaultRateProvider_) internal {
        _initializeDependencies(_layoutStruct(), underlyingVault_, vaultRateProvider_);
    }

    function _initializeReservePool(
        Storage storage layoutStruct_,
        address reservePool_,
        uint256 detfIndex_,
        uint256 vaultTokenIndex_,
        uint256 detfWeight_,
        uint256 vaultTokenWeight_,
        IDETFNFTVault detfNFTVault_,
        uint256 detfNFTId_
    ) internal {
        if (detfIndex_ > 1 || vaultTokenIndex_ > 1 || detfIndex_ == vaultTokenIndex_) {
            revert IDetfErrors.InvalidReservePoolIndices(detfIndex_, vaultTokenIndex_);
        }

        layoutStruct_.reservePool = reservePool_;
        layoutStruct_.detfIndex = detfIndex_;
        layoutStruct_.vaultTokenIndex = vaultTokenIndex_;
        layoutStruct_.detfWeight = detfWeight_;
        layoutStruct_.vaultTokenWeight = vaultTokenWeight_;
        layoutStruct_.detfNFTVault = detfNFTVault_;
        layoutStruct_.detfNFTId = detfNFTId_;
        layoutStruct_.isReservePoolInitialized = true;
    }

    function _initializeReservePool(
        address reservePool_,
        uint256 detfIndex_,
        uint256 vaultTokenIndex_,
        uint256 detfWeight_,
        uint256 vaultTokenWeight_,
        IDETFNFTVault detfNFTVault_,
        uint256 detfNFTId_
    ) internal {
        _initializeReservePool(
            _layoutStruct(),
            reservePool_,
            detfIndex_,
            vaultTokenIndex_,
            detfWeight_,
            vaultTokenWeight_,
            detfNFTVault_,
            detfNFTId_
        );
    }

    function _acceptedBondTokens(Storage storage layoutStruct_) internal view returns (address[] memory tokens_) {
        return layoutStruct_.acceptedBondTokens._asArray();
    }

    function _acceptedBondTokens() internal view returns (address[] memory tokens_) {
        return _acceptedBondTokens(_layoutStruct());
    }

    function _isAcceptedBondToken(Storage storage layoutStruct_, address token_) internal view returns (bool) {
        return layoutStruct_.acceptedBondTokens._contains(token_);
    }

    function _isAcceptedBondToken(address token_) internal view returns (bool) {
        return _isAcceptedBondToken(_layoutStruct(), token_);
    }

    function _underlyingVault(Storage storage layoutStruct_) internal view returns (IStandardExchange) {
        return layoutStruct_.underlyingVault;
    }

    function _underlyingVault() internal view returns (IStandardExchange) {
        return _underlyingVault(_layoutStruct());
    }

    function _vaultRateProvider(Storage storage layoutStruct_) internal view returns (IRateProvider) {
        return layoutStruct_.vaultRateProvider;
    }

    function _vaultRateProvider() internal view returns (IRateProvider) {
        return _vaultRateProvider(_layoutStruct());
    }

    function _feeOracle(Storage storage layoutStruct_) internal view returns (IVaultFeeOracleQuery) {
        return layoutStruct_.feeOracle;
    }

    function _feeOracle() internal view returns (IVaultFeeOracleQuery) {
        return _feeOracle(_layoutStruct());
    }

    function _detfNFTVault(Storage storage layoutStruct_) internal view returns (IDETFNFTVault) {
        return layoutStruct_.detfNFTVault;
    }

    function _detfNFTVault() internal view returns (IDETFNFTVault) {
        return _detfNFTVault(_layoutStruct());
    }

    function _detfNFTId(Storage storage layoutStruct_) internal view returns (uint256) {
        return layoutStruct_.detfNFTId;
    }

    function _detfNFTId() internal view returns (uint256) {
        return _detfNFTId(_layoutStruct());
    }

    function _rateAsset(Storage storage layoutStruct_) internal view returns (IERC20) {
        return layoutStruct_.rateAsset;
    }

    function _rateAsset() internal view returns (IERC20) {
        return _rateAsset(_layoutStruct());
    }

    function _pairToken(Storage storage layoutStruct_) internal view returns (IERC20) {
        return layoutStruct_.pairToken;
    }

    function _pairToken() internal view returns (IERC20) {
        return _pairToken(_layoutStruct());
    }

    function _rebasingClaimToken(Storage storage layoutStruct_) internal view returns (IRebasingClaimToken) {
        return layoutStruct_.rebasingClaimToken;
    }

    function _rebasingClaimToken() internal view returns (IRebasingClaimToken) {
        return _rebasingClaimToken(_layoutStruct());
    }

    function _setRebasingClaimToken(Storage storage layoutStruct_, IRebasingClaimToken rebasingClaimToken_) internal {
        layoutStruct_.rebasingClaimToken = rebasingClaimToken_;
    }

    function _setRebasingClaimToken(IRebasingClaimToken rebasingClaimToken_) internal {
        _setRebasingClaimToken(_layoutStruct(), rebasingClaimToken_);
    }

    function _reservePool(Storage storage layoutStruct_) internal view returns (address) {
        return layoutStruct_.reservePool;
    }

    function _reservePool() internal view returns (address) {
        return _reservePool(_layoutStruct());
    }

    function _underlyingPoolKeyHash(Storage storage layoutStruct_) internal view returns (bytes32 poolKeyHash_) {
        return layoutStruct_.underlyingPoolKeyHash;
    }

    function _underlyingPoolKeyHash() internal view returns (bytes32 poolKeyHash_) {
        return _underlyingPoolKeyHash(_layoutStruct());
    }
}