// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ICreate3Factory} from "@crane/contracts/factories/create3/ICreate3Factory.sol";
import {
    UniswapV4QuadStableSwapHook
} from "contracts/hooks/uniswap/v4/stable/quad/UniswapV4QuadStableSwapHook.sol";

/**
 * @title UniswapV4QuadStableSwapHookDeployer
 * @notice Holds hook creationCode so FactoryService stays under EIP-170 when linked.
 */
library UniswapV4QuadStableSwapHookDeployer {
    function create3Hook(address create3Factory, bytes memory ctorArgs, bytes32 salt)
        external
        returns (address hook)
    {
        hook = ICreate3Factory(create3Factory).create3WithArgs(
            type(UniswapV4QuadStableSwapHook).creationCode, ctorArgs, salt
        );
    }
}
