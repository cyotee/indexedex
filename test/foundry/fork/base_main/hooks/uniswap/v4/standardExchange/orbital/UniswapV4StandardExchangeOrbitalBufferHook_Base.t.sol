// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";

/**
 * @title UniswapV4StandardExchangeOrbitalBufferHook_Base
 * @notice FK2: when BASE_RPC_URL/ALCHEMY_KEY set, fork + deploy→LP→swap≥2→remove.
 */
contract UniswapV4StandardExchangeOrbitalBufferHook_Base is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    function setUp() public override {
        string memory rpc = vm.envOr("BASE_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            string memory key = vm.envOr("ALCHEMY_KEY", string(""));
            if (bytes(key).length > 0) {
                rpc = string.concat("https://base-mainnet.g.alchemy.com/v2/", key);
            }
        }
        if (bytes(rpc).length == 0) {
            return;
        }
        vm.createSelectFork(rpc);
        super.setUp();
    }

    function test_FK2_productSmoke_orSkip() public {
        if (address(hook) == address(0) || hook.code.length == 0) {
            emit log("FK2 skip: BASE_RPC_URL / ALCHEMY_KEY unset");
            return;
        }
        _assertThreePoolsLiveFromPostDeploy();
        uint256 shares = _seedThreeLeg(50 ether);
        assertGt(shares, 0);
        _swapExactIn(address(token0), address(token1), 1 ether);
        _swapExactIn(address(token0), address(token2), 1 ether);
        vm.prank(user);
        orbital.removeLiquidity(shares / 2, user, 0, 0, 0, block.timestamp + 1 hours);
    }
}
