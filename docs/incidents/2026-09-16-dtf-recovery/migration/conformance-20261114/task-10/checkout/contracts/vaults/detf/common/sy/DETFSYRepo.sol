// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";

/// @title DETFSYRepo
/// @notice Actual backing and conversion dust for one immutable raw or staking SY.
library DETFSYRepo {
    using AddressSetRepo for AddressSet;

    bytes32 internal constant STORAGE_SLOT = bytes32(uint256(keccak256("indexedex.detf.standardized.yield")) - 1);

    struct Storage {
        IERC20 detf;
        IStakedDETF staking;
        bool isStaking;
        uint256 backingGons;
        uint256 conversionDustGons;
        uint256 rawBacking;
        AddressSet tokensIn;
        AddressSet tokensOut;
    }

    error InvalidInitialization();
    error InvalidRouteToken(address token);

    /// @notice Resolve an explicit namespace.
    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage layoutStruct_) {
        assembly { layoutStruct_.slot := slot_ }
    }

    /// @notice Resolve the canonical namespace.
    function _layoutStruct() internal pure returns (Storage storage) { return _layoutStruct(STORAGE_SLOT); }

    /// @notice Initialize immutable backing and direction-specific routes from the owning DETF.
    function _initialize(
        Storage storage s_, IERC20 detf_, IStakedDETF staking_, bool isStaking_,
        address[] memory inputs_, address[] memory outputs_
    ) internal {
        if (address(s_.detf) != address(0) || address(detf_) == address(0)
            || (isStaking_ && (address(staking_) == address(0) || staking_.detf() != address(detf_)))) {
            revert InvalidInitialization();
        }
        s_.detf = detf_;
        s_.staking = staking_;
        s_.isStaking = isStaking_;
        s_.tokensIn._add(address(detf_));
        s_.tokensOut._add(address(detf_));
        if (isStaking_) {
            s_.tokensIn._add(address(staking_));
            s_.tokensOut._add(address(staking_));
        }
        _addRoutes(s_.tokensIn, inputs_);
        _addRoutes(s_.tokensOut, outputs_);
    }

    /// @notice Initialize canonical storage.
    function _initialize(
        IERC20 detf_, IStakedDETF staking_, bool isStaking_, address[] memory inputs_, address[] memory outputs_
    ) internal {
        _initialize(_layoutStruct(), detf_, staking_, isStaking_, inputs_, outputs_);
    }

    function _addRoutes(AddressSet storage tokens_, address[] memory routes_) private {
        for (uint256 i; i < routes_.length; ++i) {
            if (routes_[i] == address(0) || routes_[i] == address(this)) revert InvalidRouteToken(routes_[i]);
            tokens_._add(routes_[i]);
        }
    }
}
