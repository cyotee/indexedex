// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";
import {
    IBalancerV3UniswapV4CoordinatorRouter
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";

/// @title BalancerV3UniswapV4CoordinatorRouterRepo
/// @notice Storage for allowlist, adapter kinds, and V4 quoter reference.
library BalancerV3UniswapV4CoordinatorRouterRepo {
    using AddressSetRepo for AddressSet;

    bytes32 internal constant STORAGE_SLOT =
        bytes32(uint256(keccak256(abi.encode("indexedex.routers.balancerV3UniswapV4.coordinator"))) - 1);

    struct Layout {
        AddressSet allowedRouters;
        mapping(address => IBalancerV3UniswapV4CoordinatorRouter.AdapterKind) kindOf;
        mapping(address => bool) hasKind;
        address v4Quoter;
    }

    function _layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }

    function _setV4Quoter(address quoter_) internal {
        _layout().v4Quoter = quoter_;
    }

    function _v4Quoter() internal view returns (address) {
        return _layout().v4Quoter;
    }

    function _registerRouter(address router_, IBalancerV3UniswapV4CoordinatorRouter.AdapterKind kind_) internal {
        if (router_ == address(0)) revert IBalancerV3UniswapV4CoordinatorRouter.ZeroAddress();
        if (uint8(kind_) > uint8(IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.UniswapV4UniversalRouter)) {
            revert IBalancerV3UniswapV4CoordinatorRouter.InvalidRouterKind();
        }
        Layout storage l = _layout();
        l.allowedRouters._add(router_);
        l.kindOf[router_] = kind_;
        l.hasKind[router_] = true;
    }

    function _unregisterRouter(address router_) internal {
        Layout storage l = _layout();
        l.allowedRouters._remove(router_);
        delete l.kindOf[router_];
        delete l.hasKind[router_];
    }

    function _isRouterAllowed(address router_) internal view returns (bool) {
        return _layout().allowedRouters._contains(router_);
    }

    function _routerKind(address router_) internal view returns (IBalancerV3UniswapV4CoordinatorRouter.AdapterKind) {
        Layout storage l = _layout();
        if (!l.allowedRouters._contains(router_) || !l.hasKind[router_]) {
            revert IBalancerV3UniswapV4CoordinatorRouter.RouterNotAllowed(router_);
        }
        return l.kindOf[router_];
    }

    function _allowedRouterCount() internal view returns (uint256) {
        return _layout().allowedRouters._length();
    }

    function _allowedRouterAt(uint256 index_) internal view returns (address) {
        // AddressSetRepo._index uses 0-based array indexing (length check: index < length).
        return _layout().allowedRouters._index(index_);
    }
}
