// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";

/**
 * @notice H12 vault discovery: reserveOfToken = face | live SE shares.
 */
contract UniswapV4StandardExchangeWeightedBufferHook_VaultViews is
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
{
    function test_vaultTokens_and_reserveOfToken() public {
        _firstMintEqual(75 ether);

        address[] memory vt = IBasicVault(hook).vaultTokens();
        assertEq(vt.length, 2);
        assertEq(vt[0], address(token0));
        assertEq(vt[1], address(token1));

        assertEq(IBasicVault(hook).reserveOfToken(address(token0)), weighted.nativeReserve(0));
        assertEq(IBasicVault(hook).reserveOfToken(address(token1)), weighted.nativeReserve(1));
        assertEq(IBasicVault(hook).reserveOfToken(address(token0)), weighted.seBalance(0));
        assertEq(IBasicVault(hook).reserveOfToken(address(token1)), token1.balanceOf(hook));
    }
}
