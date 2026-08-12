// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    BalancerV3UniswapV4CoordinatorRouterCommon
} from "contracts/routers/balancerV3-uniswapV4/common/BalancerV3UniswapV4CoordinatorRouterCommon.sol";

/// @title BalancerV3UniswapV4CoordinatorRouterPermit2WitnessTarget
abstract contract BalancerV3UniswapV4CoordinatorRouterPermit2WitnessTarget is
    BalancerV3UniswapV4CoordinatorRouterCommon
{
    function WITNESS_TYPE_STRING() external pure returns (string memory) {
        return _WITNESS_TYPE_STRING;
    }

    function WITNESS_TYPEHASH() external pure returns (bytes32) {
        return _WITNESS_TYPEHASH;
    }
}
