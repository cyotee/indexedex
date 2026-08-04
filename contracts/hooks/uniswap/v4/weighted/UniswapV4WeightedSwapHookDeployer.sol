// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ICreate3Factory} from "@crane/contracts/factories/create3/ICreate3Factory.sol";
import {
    UniswapV4WeightedSwapHook
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHook.sol";

/**
 * @title UniswapV4WeightedSwapHookDeployer
 * @notice Holds hook creationCode so FactoryService stays under EIP-170 when linked.
 */
library UniswapV4WeightedSwapHookDeployer {
    function create3Hook(address create3Factory, bytes memory ctorArgs, bytes32 salt)
        external
        returns (address hook)
    {
        hook = ICreate3Factory(create3Factory).create3WithArgs(
            type(UniswapV4WeightedSwapHook).creationCode, ctorArgs, salt
        );
    }
}
