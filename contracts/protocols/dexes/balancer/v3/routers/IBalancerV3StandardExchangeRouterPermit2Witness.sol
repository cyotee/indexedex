// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IBalancerV3StandardExchangeRouterPermit2Witness {

    function WITNESS_TYPE_STRING() external view returns (string memory);

    function WITNESS_TYPEHASH() external view returns (bytes32);

}