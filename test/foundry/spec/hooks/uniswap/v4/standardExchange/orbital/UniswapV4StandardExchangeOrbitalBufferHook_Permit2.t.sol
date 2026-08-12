// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";

contract UniswapV4StandardExchangeOrbitalBufferHook_Permit2Test is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    function test_permit2_address_is_wellKnown() public view {
        assertEq(orbital.permit2(), PERMIT2_ADDR);
    }

    function test_transferFrom_deposit_path() public {
        // Empty permit2Data => SafeERC20 transferFrom (canonical default)
        (uint256 shares,,,) = _addLiquidity(50 ether, 50 ether, 50 ether);
        assertGt(shares, 0);
    }
}
