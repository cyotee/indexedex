// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {TransientSlot} from "@crane/contracts/utils/TransientSlot.sol";

library BalancerV3StandardExchangeRouterRepo {
    using TransientSlot for *;
    bytes32 internal constant STORAGE_SLOT = keccak256("protocols.dexes.balancer.v3.routers.standard.exchange");

    function _currentStandardExchangeToken() internal view returns (IStandardExchangeProxy token_) {
        token_ = IStandardExchangeProxy(STORAGE_SLOT.asAddress().tload());
    }

    function _setCurrentStandardExchangeToken(IStandardExchangeProxy token_) internal {
        STORAGE_SLOT.asAddress().tstore(address(token_));
    }
}
