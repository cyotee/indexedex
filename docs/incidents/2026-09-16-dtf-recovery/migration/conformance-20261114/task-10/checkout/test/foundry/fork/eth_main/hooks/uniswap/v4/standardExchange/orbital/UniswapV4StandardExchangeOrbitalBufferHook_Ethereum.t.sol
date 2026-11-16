// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";

/**
 * @title UniswapV4StandardExchangeOrbitalBufferHook_Ethereum
 * @notice FK1: when ETH_RPC_URL set, fork + production path deploy→LP→swap≥2 doors→remove.
 * @dev Without RPC, skips (document env gap). Hermetic suite remains hard gate.
 */
contract UniswapV4StandardExchangeOrbitalBufferHook_Ethereum is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    function setUp() public override {
        string memory rpc = vm.envOr("ETH_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            rpc = vm.envOr("MAINNET_RPC_URL", string(""));
        }
        if (bytes(rpc).length == 0) {
            // Skip full TestBase setUp when no RPC — mark via empty hook
            return;
        }
        vm.createSelectFork(rpc);
        super.setUp();
    }

    function test_FK1_productSmoke_orSkip() public {
        if (address(hook) == address(0) || hook.code.length == 0) {
            emit log("FK1 skip: ETH_RPC_URL / MAINNET_RPC_URL unset");
            return;
        }
        _assertThreeProductDoorsLive();
        uint256 shares = _seedThreeLeg(50 ether);
        assertGt(shares, 0);
        _swapExactIn(address(token0), address(token1), 1 ether);
        _swapExactIn(address(token1), address(token2), 1 ether);
        vm.prank(user);
        orbital.removeLiquidity(shares / 2, user, 0, 0, 0, block.timestamp + 1 hours);
    }
}
