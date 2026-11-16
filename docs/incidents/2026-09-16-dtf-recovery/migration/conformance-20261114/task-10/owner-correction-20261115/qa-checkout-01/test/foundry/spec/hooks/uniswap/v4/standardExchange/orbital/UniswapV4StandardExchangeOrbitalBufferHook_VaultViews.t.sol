// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";

contract UniswapV4StandardExchangeOrbitalBufferHook_VaultViewsTest is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    function test_vaultTokens_threeBound() public {
        _seedThreeLeg(50 ether);
        address[] memory tokens = IBasicVault(hook).vaultTokens();
        assertEq(tokens.length, 3);
        assertEq(tokens[0], address(token0));
        assertEq(tokens[1], address(token1));
        assertEq(tokens[2], address(token2));
    }

    function test_reserveOfToken_effective() public {
        _seedThreeLeg(80 ether);
        assertEq(IBasicVault(hook).reserveOfToken(address(token0)), orbital.effectiveReserve(0));
        assertEq(IBasicVault(hook).reserveOfToken(address(token1)), orbital.effectiveReserve(1));
        assertEq(IBasicVault(hook).reserveOfToken(address(token2)), orbital.effectiveReserve(2));
    }

    function test_standardVault_surface() public view {
        // vaultTypes / vaultConfig present via shared facet
        bytes4[] memory types = IStandardVault(hook).vaultTypes();
        assertGt(types.length, 0);
    }
}
