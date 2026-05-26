// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from 'contracts/interfaces/IStandardExchangeIn.sol';

library WrappedStandardExchangeRateProviderRepo {
    bytes32 internal constant STORAGE_SLOT =
        keccak256("crane.contracts.protocols.dexes.balancer.v3.rateProviders.standardExchange.wrapped");

    struct Storage {
        // The vault whose shares are being rated.
        IERC4626 rateSubject;
        // Cached ERC4626 asset token (the reserve-vault share token).
        IERC20 reserveVaultToken;
        // The standard exchange to be rated.
        IStandardExchangeIn standardExchange;
        IERC20 rateTarget;
        uint8 assetDecimals;
        uint8 rateTargetDecimals;
    }

    function _layoutStruct(bytes32 slot) internal pure returns (Storage storage layoutStruct) {
        assembly {
            layoutStruct.slot := slot
        }
    }

    function _layoutStruct() internal pure returns (Storage storage) {
        return _layoutStruct(STORAGE_SLOT);
    }

    function _initialize(
        Storage storage layoutStruct_,
        IERC4626 rateSubject_,
        IERC20 reserveVaultToken_,
        IStandardExchangeIn standardExchange_,
        IERC20 rateTarget_,
        uint8 assetDecimals_,
        uint8 rateTargetDecimals_
    ) internal {
        layoutStruct_.rateSubject = rateSubject_;
        layoutStruct_.reserveVaultToken = reserveVaultToken_;
        layoutStruct_.standardExchange = standardExchange_;
        layoutStruct_.rateTarget = rateTarget_;
        layoutStruct_.assetDecimals = assetDecimals_;
        layoutStruct_.rateTargetDecimals = rateTargetDecimals_;
    }

    function _initialize(
        IERC4626 rateSubject_,
        IERC20 reserveVaultToken_,
        IStandardExchangeIn standardExchange_,
        IERC20 rateTarget_,
        uint8 assetDecimals_,
        uint8 rateTargetDecimals_
    ) internal {
        _initialize(
            _layoutStruct(),
            rateSubject_,
            reserveVaultToken_,
            standardExchange_,
            rateTarget_,
            assetDecimals_,
            rateTargetDecimals_
        );
    }

    function _rateSubject(Storage storage layoutStruct_) internal view returns (IERC4626) {
        return layoutStruct_.rateSubject;
    }

    function _rateSubject() internal view returns (IERC4626) {
        return _rateSubject(_layoutStruct());
    }

    function _reserveVaultToken(Storage storage layoutStruct_) internal view returns (IERC20) {
        return layoutStruct_.reserveVaultToken;
    }

    function _reserveVaultToken() internal view returns (IERC20) {
        return _reserveVaultToken(_layoutStruct());
    }

    function _standardExchange(Storage storage layoutStruct_) internal view returns (IStandardExchangeIn) {
        return layoutStruct_.standardExchange;
    }

    function _standardExchange() internal view returns (IStandardExchangeIn) {
        return _standardExchange(_layoutStruct());
    }

    function _rateTarget(Storage storage layoutStruct_) internal view returns (IERC20) {
        return layoutStruct_.rateTarget;
    }

    function _rateTarget() internal view returns (IERC20) {
        return _rateTarget(_layoutStruct());
    }

    function _assetDecimals(Storage storage layoutStruct_) internal view returns (uint8) {
        return layoutStruct_.assetDecimals;
    }

    function _assetDecimals() internal view returns (uint8) {
        return _assetDecimals(_layoutStruct());
    }

    function _rateTargetDecimals(Storage storage layoutStruct_) internal view returns (uint8) {
        return layoutStruct_.rateTargetDecimals;
    }

    function _rateTargetDecimals() internal view returns (uint8) {
        return _rateTargetDecimals(_layoutStruct());
    }
}