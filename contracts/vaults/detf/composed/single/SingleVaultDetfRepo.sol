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

import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {IRICHIR} from "contracts/interfaces/IRICHIR.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {IProtocolDETFErrors} from "contracts/interfaces/IProtocolDETFErrors.sol";

library SingleVaultDetfRepo {
    using AddressSetRepo for AddressSet;

    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.vaults.detf.composed.single");

    struct Storage {
        bool isReservePoolInitialized;
        IERC20 richToken;
        IRICHIR richirToken;
        IERC20 wethToken;
        IStandardExchange wethRichVault;
        IProtocolNFTVault protocolNFTVault;
        IVaultFeeOracleQuery feeOracle;
        IBalancerV3StandardExchangeRouterPrepay balancerV3PrepayRouter;
        IRateProvider vaultRateProvider;
        address reservePool;
        bytes32 wethRichPoolKeyHash;
        uint256 protocolNFTId;
        uint256 chirIndex;
        uint256 vaultTokenIndex;
        uint256 chirWeight;
        uint256 vaultTokenWeight;
        uint256 mintThreshold;
        uint256 burnThreshold;
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
        IERC20 richToken_,
        IERC20 wethToken_,
        uint256 mintThreshold_,
        uint256 burnThreshold_
    ) internal {
        layoutStruct_.feeOracle = feeOracle_;
        layoutStruct_.balancerV3PrepayRouter = balancerV3PrepayRouter_;
        layoutStruct_.richToken = richToken_;
        layoutStruct_.wethToken = wethToken_;
        layoutStruct_.mintThreshold = mintThreshold_;
        layoutStruct_.burnThreshold = burnThreshold_;
        layoutStruct_.acceptedBondTokens._add(address(wethToken_));
        layoutStruct_.acceptedBondTokens._add(address(richToken_));
    }

    function _initialize(
        IVaultFeeOracleQuery feeOracle_,
        IBalancerV3StandardExchangeRouterPrepay balancerV3PrepayRouter_,
        IERC20 richToken_,
        IERC20 wethToken_,
        uint256 mintThreshold_,
        uint256 burnThreshold_
    ) internal {
        _initialize(_layoutStruct(), feeOracle_, balancerV3PrepayRouter_, richToken_, wethToken_, mintThreshold_, burnThreshold_);
    }

    function _initializeDependencies(
        Storage storage layoutStruct_,
        IStandardExchange wethRichVault_,
        IRateProvider vaultRateProvider_,
        bytes32 wethRichPoolKeyHash_
    ) internal {
        layoutStruct_.wethRichVault = wethRichVault_;
        layoutStruct_.vaultRateProvider = vaultRateProvider_;
        layoutStruct_.wethRichPoolKeyHash = wethRichPoolKeyHash_;
    }

    function _initializeDependencies(
        IStandardExchange wethRichVault_,
        IRateProvider vaultRateProvider_,
        bytes32 wethRichPoolKeyHash_
    ) internal {
        _initializeDependencies(_layoutStruct(), wethRichVault_, vaultRateProvider_, wethRichPoolKeyHash_);
    }

    function _initializeDependencies(
        Storage storage layoutStruct_,
        IStandardExchange wethRichVault_,
        IRateProvider vaultRateProvider_
    ) internal {
        _initializeDependencies(layoutStruct_, wethRichVault_, vaultRateProvider_, layoutStruct_.wethRichPoolKeyHash);
    }

    function _initializeDependencies(IStandardExchange wethRichVault_, IRateProvider vaultRateProvider_) internal {
        _initializeDependencies(_layoutStruct(), wethRichVault_, vaultRateProvider_);
    }

    function _initializeReservePool(
        Storage storage layoutStruct_,
        address reservePool_,
        uint256 chirIndex_,
        uint256 vaultTokenIndex_,
        uint256 chirWeight_,
        uint256 vaultTokenWeight_,
        IProtocolNFTVault protocolNFTVault_,
        uint256 protocolNFTId_
    ) internal {
        if (chirIndex_ > 1 || vaultTokenIndex_ > 1 || chirIndex_ == vaultTokenIndex_) {
            revert IProtocolDETFErrors.InvalidReservePoolIndices(chirIndex_, vaultTokenIndex_);
        }

        layoutStruct_.reservePool = reservePool_;
        layoutStruct_.chirIndex = chirIndex_;
        layoutStruct_.vaultTokenIndex = vaultTokenIndex_;
        layoutStruct_.chirWeight = chirWeight_;
        layoutStruct_.vaultTokenWeight = vaultTokenWeight_;
        layoutStruct_.protocolNFTVault = protocolNFTVault_;
        layoutStruct_.protocolNFTId = protocolNFTId_;
        layoutStruct_.isReservePoolInitialized = true;
    }

    function _initializeReservePool(
        address reservePool_,
        uint256 chirIndex_,
        uint256 vaultTokenIndex_,
        uint256 chirWeight_,
        uint256 vaultTokenWeight_,
        IProtocolNFTVault protocolNFTVault_,
        uint256 protocolNFTId_
    ) internal {
        _initializeReservePool(
            _layoutStruct(),
            reservePool_,
            chirIndex_,
            vaultTokenIndex_,
            chirWeight_,
            vaultTokenWeight_,
            protocolNFTVault_,
            protocolNFTId_
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

    function _wethRichVault(Storage storage layoutStruct_) internal view returns (IStandardExchange) {
        return layoutStruct_.wethRichVault;
    }

    function _wethRichVault() internal view returns (IStandardExchange) {
        return _wethRichVault(_layoutStruct());
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

    function _protocolNFTVault(Storage storage layoutStruct_) internal view returns (IProtocolNFTVault) {
        return layoutStruct_.protocolNFTVault;
    }

    function _protocolNFTVault() internal view returns (IProtocolNFTVault) {
        return _protocolNFTVault(_layoutStruct());
    }

    function _protocolNFTId(Storage storage layoutStruct_) internal view returns (uint256) {
        return layoutStruct_.protocolNFTId;
    }

    function _protocolNFTId() internal view returns (uint256) {
        return _protocolNFTId(_layoutStruct());
    }

    function _wethToken(Storage storage layoutStruct_) internal view returns (IERC20) {
        return layoutStruct_.wethToken;
    }

    function _wethToken() internal view returns (IERC20) {
        return _wethToken(_layoutStruct());
    }

    function _richToken(Storage storage layoutStruct_) internal view returns (IERC20) {
        return layoutStruct_.richToken;
    }

    function _richToken() internal view returns (IERC20) {
        return _richToken(_layoutStruct());
    }

    function _richirToken(Storage storage layoutStruct_) internal view returns (IRICHIR) {
        return layoutStruct_.richirToken;
    }

    function _richirToken() internal view returns (IRICHIR) {
        return _richirToken(_layoutStruct());
    }

    function _setRichirToken(Storage storage layoutStruct_, IRICHIR richirToken_) internal {
        layoutStruct_.richirToken = richirToken_;
    }

    function _setRichirToken(IRICHIR richirToken_) internal {
        _setRichirToken(_layoutStruct(), richirToken_);
    }

    function _reservePool(Storage storage layoutStruct_) internal view returns (address) {
        return layoutStruct_.reservePool;
    }

    function _reservePool() internal view returns (address) {
        return _reservePool(_layoutStruct());
    }

    function _wethRichPoolKeyHash(Storage storage layoutStruct_) internal view returns (bytes32 poolKeyHash_) {
        return layoutStruct_.wethRichPoolKeyHash;
    }

    function _wethRichPoolKeyHash() internal view returns (bytes32 poolKeyHash_) {
        return _wethRichPoolKeyHash(_layoutStruct());
    }
}