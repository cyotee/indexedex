// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    BalancerV3StandardExchangeRouterCommon
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterCommon.sol";
import {IBalancerV3StandardExchangeRouterPermit2Witness} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPermit2Witness.sol";

contract BalancerV3StandardExchangeRouterPermit2WitnessTarget is BalancerV3StandardExchangeRouterCommon, IBalancerV3StandardExchangeRouterPermit2Witness {

    function WITNESS_TYPE_STRING() public pure returns (string memory) {
        return _WITNESS_TYPE_STRING;
    }

    function WITNESS_TYPEHASH() public pure returns (bytes32) {
        return _WITNESS_TYPEHASH;
    }

}