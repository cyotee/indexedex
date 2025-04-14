// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";

library StandardExchangeRateProviderRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.protocols.balancer.v3.rateProvider.standardExchange");

    struct Storage {
        IStandardExchange reserveVault;
        IERC20 rateTarget;
        uint8 rateTargetDecimals;
    }

    function _layout(bytes32 slot_) internal pure returns (Storage storage layout_) {
        assembly {
            layout_.slot := slot_
        }
    }

    function _layout() internal pure returns (Storage storage) {
        return _layout(STORAGE_SLOT);
    }

    function _initialize(
        Storage storage layout_,
        IStandardExchange reserveVault_,
        IERC20 rateTarget_,
        uint8 rateTargetDecimals_
    ) internal {
        layout_.reserveVault = reserveVault_;
        layout_.rateTarget = rateTarget_;
        layout_.rateTargetDecimals = rateTargetDecimals_;
    }

    function _initialize(IStandardExchange reserveVault_, IERC20 rateTarget_, uint8 rateTargetDecimals_) internal {
        _initialize(_layout(), reserveVault_, rateTarget_, rateTargetDecimals_);
    }

    function _reserveVault(Storage storage layout_) internal view returns (IStandardExchange) {
        return layout_.reserveVault;
    }

    function _reserveVault() internal view returns (IStandardExchange) {
        return _reserveVault(_layout());
    }

    function _rateTarget(Storage storage layout_) internal view returns (IERC20) {
        return layout_.rateTarget;
    }

    function _rateTarget() internal view returns (IERC20) {
        return _rateTarget(_layout());
    }

    function _rateTargetDecimals(Storage storage layout_) internal view returns (uint8) {
        return layout_.rateTargetDecimals;
    }

    function _rateTargetDecimals() internal view returns (uint8) {
        return _rateTargetDecimals(_layout());
    }
}
