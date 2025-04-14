// SPDX-License-Identifier: BUSL-1.1
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

    function _layout(bytes32 slot) internal pure returns (Storage storage layout) {
        assembly {
            layout.slot := slot
        }
    }

    function _layout() internal pure returns (Storage storage layout) {
        return _layout(STORAGE_SLOT);
    }

    function _initialize(Storage storage layout, IBalancerV3StandardExchangeRouterProxy router_) internal {
        layout.balancerV3StandardExchangeRouter = router_;
    }

    function _initialize(IBalancerV3StandardExchangeRouterProxy router_) internal {
        _initialize(_layout(), router_);
    }

    function _balancerV3StandardExchangeRouter(Storage storage layout)
        internal
        view
        returns (IBalancerV3StandardExchangeRouterProxy router_)
    {
        return layout.balancerV3StandardExchangeRouter;
    }

    function _balancerV3StandardExchangeRouter()
        internal
        view
        returns (IBalancerV3StandardExchangeRouterProxy router_)
    {
        return _balancerV3StandardExchangeRouter(_layout());
    }
}
