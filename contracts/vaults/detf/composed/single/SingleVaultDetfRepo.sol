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

    function _layout(bytes32 slot_) internal pure returns (Storage storage layout_) {
        assembly {
            layout_.slot := slot_
        }
    }

    function _layout() internal pure returns (Storage storage layout_) {
        return _layout(STORAGE_SLOT);
    }

    function _initialize(
        Storage storage layout_,
        IVaultFeeOracleQuery feeOracle_,
        IBalancerV3StandardExchangeRouterPrepay balancerV3PrepayRouter_,
        IERC20 richToken_,
        IERC20 wethToken_,
        uint256 mintThreshold_,
        uint256 burnThreshold_
    ) internal {
        layout_.feeOracle = feeOracle_;
        layout_.balancerV3PrepayRouter = balancerV3PrepayRouter_;
        layout_.richToken = richToken_;
        layout_.wethToken = wethToken_;
        layout_.mintThreshold = mintThreshold_;
        layout_.burnThreshold = burnThreshold_;
        layout_.acceptedBondTokens._add(address(wethToken_));
        layout_.acceptedBondTokens._add(address(richToken_));
    }

    function _initialize(
        IVaultFeeOracleQuery feeOracle_,
        IBalancerV3StandardExchangeRouterPrepay balancerV3PrepayRouter_,
        IERC20 richToken_,
        IERC20 wethToken_,
        uint256 mintThreshold_,
        uint256 burnThreshold_
    ) internal {
        _initialize(_layout(), feeOracle_, balancerV3PrepayRouter_, richToken_, wethToken_, mintThreshold_, burnThreshold_);
    }

    function _initializeDependencies(
        Storage storage layout_,
        IStandardExchange wethRichVault_,
        IRateProvider vaultRateProvider_,
        bytes32 wethRichPoolKeyHash_
    ) internal {
        layout_.wethRichVault = wethRichVault_;
        layout_.vaultRateProvider = vaultRateProvider_;
        layout_.wethRichPoolKeyHash = wethRichPoolKeyHash_;
    }

    function _initializeDependencies(
        IStandardExchange wethRichVault_,
        IRateProvider vaultRateProvider_,
        bytes32 wethRichPoolKeyHash_
    ) internal {
        _initializeDependencies(_layout(), wethRichVault_, vaultRateProvider_, wethRichPoolKeyHash_);
    }

    function _initializeDependencies(
        Storage storage layout_,
        IStandardExchange wethRichVault_,
        IRateProvider vaultRateProvider_
    ) internal {
        _initializeDependencies(layout_, wethRichVault_, vaultRateProvider_, layout_.wethRichPoolKeyHash);
    }

    function _initializeDependencies(IStandardExchange wethRichVault_, IRateProvider vaultRateProvider_) internal {
        _initializeDependencies(_layout(), wethRichVault_, vaultRateProvider_);
    }

    function _initializeReservePool(
        Storage storage layout_,
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

        layout_.reservePool = reservePool_;
        layout_.chirIndex = chirIndex_;
        layout_.vaultTokenIndex = vaultTokenIndex_;
        layout_.chirWeight = chirWeight_;
        layout_.vaultTokenWeight = vaultTokenWeight_;
        layout_.protocolNFTVault = protocolNFTVault_;
        layout_.protocolNFTId = protocolNFTId_;
        layout_.isReservePoolInitialized = true;
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
            _layout(),
            reservePool_,
            chirIndex_,
            vaultTokenIndex_,
            chirWeight_,
            vaultTokenWeight_,
            protocolNFTVault_,
            protocolNFTId_
        );
    }

    function _acceptedBondTokens(Storage storage layout_) internal view returns (address[] memory tokens_) {
        return layout_.acceptedBondTokens._asArray();
    }

    function _acceptedBondTokens() internal view returns (address[] memory tokens_) {
        return _acceptedBondTokens(_layout());
    }

    function _isAcceptedBondToken(Storage storage layout_, address token_) internal view returns (bool) {
        return layout_.acceptedBondTokens._contains(token_);
    }

    function _isAcceptedBondToken(address token_) internal view returns (bool) {
        return _isAcceptedBondToken(_layout(), token_);
    }

    function _wethRichVault(Storage storage layout_) internal view returns (IStandardExchange) {
        return layout_.wethRichVault;
    }

    function _wethRichVault() internal view returns (IStandardExchange) {
        return _wethRichVault(_layout());
    }

    function _vaultRateProvider(Storage storage layout_) internal view returns (IRateProvider) {
        return layout_.vaultRateProvider;
    }

    function _vaultRateProvider() internal view returns (IRateProvider) {
        return _vaultRateProvider(_layout());
    }

    function _feeOracle(Storage storage layout_) internal view returns (IVaultFeeOracleQuery) {
        return layout_.feeOracle;
    }

    function _feeOracle() internal view returns (IVaultFeeOracleQuery) {
        return _feeOracle(_layout());
    }

    function _protocolNFTVault(Storage storage layout_) internal view returns (IProtocolNFTVault) {
        return layout_.protocolNFTVault;
    }

    function _protocolNFTVault() internal view returns (IProtocolNFTVault) {
        return _protocolNFTVault(_layout());
    }

    function _protocolNFTId(Storage storage layout_) internal view returns (uint256) {
        return layout_.protocolNFTId;
    }

    function _protocolNFTId() internal view returns (uint256) {
        return _protocolNFTId(_layout());
    }

    function _wethToken(Storage storage layout_) internal view returns (IERC20) {
        return layout_.wethToken;
    }

    function _wethToken() internal view returns (IERC20) {
        return _wethToken(_layout());
    }

    function _richToken(Storage storage layout_) internal view returns (IERC20) {
        return layout_.richToken;
    }

    function _richToken() internal view returns (IERC20) {
        return _richToken(_layout());
    }

    function _richirToken(Storage storage layout_) internal view returns (IRICHIR) {
        return layout_.richirToken;
    }

    function _richirToken() internal view returns (IRICHIR) {
        return _richirToken(_layout());
    }

    function _setRichirToken(Storage storage layout_, IRICHIR richirToken_) internal {
        layout_.richirToken = richirToken_;
    }

    function _setRichirToken(IRICHIR richirToken_) internal {
        _setRichirToken(_layout(), richirToken_);
    }

    function _reservePool(Storage storage layout_) internal view returns (address) {
        return layout_.reservePool;
    }

    function _reservePool() internal view returns (address) {
        return _reservePool(_layout());
    }

    function _wethRichPoolKeyHash(Storage storage layout_) internal view returns (bytes32 poolKeyHash_) {
        return layout_.wethRichPoolKeyHash;
    }

    function _wethRichPoolKeyHash() internal view returns (bytes32 poolKeyHash_) {
        return _wethRichPoolKeyHash(_layout());
    }
}