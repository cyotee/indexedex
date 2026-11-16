// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;
import {BufferPoolInvariantHandler, IBufferInvariantFunding} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/invariant/BufferPoolInvariantHandler.sol";

contract Handler_MixedBufferMultiVaultStablePool is BufferPoolInvariantHandler {
    constructor(Config memory config_) BufferPoolInvariantHandler(config_) {}
}
