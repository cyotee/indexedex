// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {BetterPermit2} from "@crane/contracts/protocols/utils/permit2/BetterPermit2.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {
    UniversalRouter
} from "@crane/contracts/external/uniswap/universal-router/UniversalRouter.sol";
import {
    RouterParameters
} from "@crane/contracts/external/uniswap/universal-router/types/RouterParameters.sol";
import {
    IUniversalRouter
} from "@crane/contracts/external/uniswap/universal-router/interfaces/IUniversalRouter.sol";
import {
    Commands
} from "@crane/contracts/external/uniswap/universal-router/libraries/Commands.sol";

/// @notice M0 smoke: vendored Uniswap Universal Router (2.1.1) deploys and exposes execute.
/// @dev Hermetic under default profile: forge test --match-contract UniversalRouter_VendorSmoke -vv
contract UniversalRouter_VendorSmoke_Test is Test {
    function test_vendorDeployAndCommandsConstant() public {
        IPermit2 permit2 = IPermit2(address(new BetterPermit2()));
        // PoolManager constructor takes initial owner / protocol fee controller params per Crane port
        // Use a minimal deploy if available; otherwise skip manager-specific path and only assert Commands.
        assertEq(Commands.V4_SWAP, 0x10);

        // Deploy PoolManager with this test as owner (Crane PoolManager API)
        PoolManager manager = new PoolManager(address(this));
        RouterParameters memory params = RouterParameters({
            permit2: address(permit2),
            weth9: address(0xBEEF),
            v2Factory: address(0),
            v3Factory: address(0),
            pairInitCodeHash: bytes32(0),
            poolInitCodeHash: bytes32(0),
            v4PoolManager: address(manager),
            v3NFTPositionManager: address(0),
            v4PositionManager: address(0),
            spokePool: address(0)
        });
        IUniversalRouter ur = IUniversalRouter(address(new UniversalRouter(params)));
        assertTrue(address(ur) != address(0));
        // Empty execute reverts LengthMismatch or succeeds with 0 commands — zero-length should pass loop
        bytes memory commands = "";
        bytes[] memory inputs = new bytes[](0);
        ur.execute(commands, inputs, block.timestamp + 1);
    }
}
