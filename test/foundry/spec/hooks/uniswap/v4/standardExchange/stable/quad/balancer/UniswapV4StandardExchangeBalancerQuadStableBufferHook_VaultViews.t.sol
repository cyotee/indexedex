// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";

contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_VaultViews is TestBase {
    function test_reserveOfToken_isLiveSharesOrFace() public {
        _firstMintEqual(100 ether);
        assertEq(IBasicVault(hook).reserveOfToken(address(token0)), quad.seBalance(0));
        assertEq(IBasicVault(hook).reserveOfToken(address(token1)), token1.balanceOf(hook));
        assertEq(IBasicVault(hook).reserveOfToken(address(token0)), quad.nativeReserve(0));
    }

    function test_vaultTokens_four() public view {
        address[] memory toks = IBasicVault(hook).vaultTokens();
        assertEq(toks.length, 4);
        assertEq(toks[0], address(token0));
    }

    function test_ensurePairPools_idempotent() public {
        uint256 n = quad.ensurePairPools();
        assertEq(n, 0);
        _assertAllDoorsLive();
    }
}
