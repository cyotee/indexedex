// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    IBalancerV3StandardExchangeRouterProxy
} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";

library BalancerV3StandardExchangeRouterAwareRepo {
    bytes32 internal constant STORAGE_SLOT =
        keccak256("indexedex.protocols.dexes.balancer.v3.routers.balancer.v3.standard.exchange.router.aware");

    struct Storage {
        IBalancerV3StandardExchangeRouterProxy balancerV3StandardExchangeRouter;
    }

    function _layoutStruct(bytes32 slot) internal pure returns (Storage storage layoutStruct) {
        assembly {
            layoutStruct.slot := slot
        }
    }

    function _layoutStruct() internal pure returns (Storage storage layoutStruct) {
        return _layoutStruct(STORAGE_SLOT);
    }

    function _initialize(Storage storage layoutStruct, IBalancerV3StandardExchangeRouterProxy router_) internal {
        layoutStruct.balancerV3StandardExchangeRouter = router_;
    }

    function _initialize(IBalancerV3StandardExchangeRouterProxy router_) internal {
        _initialize(_layoutStruct(), router_);
    }

    function _balancerV3StandardExchangeRouter(Storage storage layoutStruct)
        internal
        view
        returns (IBalancerV3StandardExchangeRouterProxy router_)
    {
        return layoutStruct.balancerV3StandardExchangeRouter;
    }

    function _balancerV3StandardExchangeRouter()
        internal
        view
        returns (IBalancerV3StandardExchangeRouterProxy router_)
    {
        return _balancerV3StandardExchangeRouter(_layoutStruct());
    }
}
