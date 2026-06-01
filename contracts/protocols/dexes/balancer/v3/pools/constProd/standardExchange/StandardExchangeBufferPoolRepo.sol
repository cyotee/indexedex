// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";

library StandardExchangeBufferPoolRepo {
    bytes32 internal constant STORAGE_SLOT =
        keccak256("indexedex.protocols.balancer.v3.pools.constProd.standardExchange");

    struct Storage {
        // Immutable after _initialize:
        IERC20 ttaToken;
        IERC20 shareToken;
        IStandardExchange standardExchangeVault;
        IRateProvider rateProvider;
        uint256 ttaIndex;
        uint256 sharesIndex;
        address expectedFactory;
        // Live state:
        uint256 virtualTTA;
        int256 hookSharesDelta;
        // Transient-like pre-seat state (set in onBeforeSwap, cleared in onAfterSwap).
        // pendingPreSeatS: number of shares drained from the pool during the pre-seat pass.
        // Zero means no pre-seat is in flight.
        uint256 pendingPreSeatS;
    }

    function _layout(bytes32 slot_) internal pure returns (Storage storage l) {
        assembly { l.slot := slot_ }
    }
    function _layout() internal pure returns (Storage storage) { return _layout(STORAGE_SLOT); }

    function _initialize(
        IERC20 tta,
        IERC20 shares,
        IStandardExchange seVault,
        IRateProvider rp,
        uint256 ttaIdx,
        uint256 sharesIdx,
        address expectedFactory_
    ) internal {
        Storage storage l = _layout();
        l.ttaToken = tta;
        l.shareToken = shares;
        l.standardExchangeVault = seVault;
        l.rateProvider = rp;
        l.ttaIndex = ttaIdx;
        l.sharesIndex = sharesIdx;
        l.expectedFactory = expectedFactory_;
    }

    function _expectedFactory() internal view returns (address) { return _layout().expectedFactory; }

    function _ttaToken() internal view returns (IERC20) { return _layout().ttaToken; }
    function _shareToken() internal view returns (IERC20) { return _layout().shareToken; }
    function _standardExchangeVault() internal view returns (IStandardExchange) { return _layout().standardExchangeVault; }
    function _rateProvider() internal view returns (IRateProvider) { return _layout().rateProvider; }
    function _ttaIndex() internal view returns (uint256) { return _layout().ttaIndex; }
    function _sharesIndex() internal view returns (uint256) { return _layout().sharesIndex; }

    function _virtualTTA() internal view returns (uint256) { return _layout().virtualTTA; }
    function _setVirtualTTA(uint256 v) internal { _layout().virtualTTA = v; }

    function _hookSharesDelta() internal view returns (int256) { return _layout().hookSharesDelta; }
    function _setHookSharesDelta(int256 v) internal { _layout().hookSharesDelta = v; }

    function _pendingPreSeatS() internal view returns (uint256) { return _layout().pendingPreSeatS; }
    function _setPendingPreSeatS(uint256 v) internal { _layout().pendingPreSeatS = v; }
}
