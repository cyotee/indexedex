// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";

/**
 * @title UniswapV4StandardExchangeOrbitalBufferHook_Robinhood
 * @notice FK3: when ROBINHOOD_RPC_URL set, fork chain 4663 + deploy→LP→swap≥2→remove.
 */
contract UniswapV4StandardExchangeOrbitalBufferHook_Robinhood is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    function setUp() public override {
        string memory rpc = vm.envOr("ROBINHOOD_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            return;
        }
        vm.createSelectFork(rpc);
        require(block.chainid == 4663, "chain 4663");
        super.setUp();
    }

    function test_FK3_productSmoke_orSkip() public {
        if (address(hook) == address(0) || hook.code.length == 0) {
            emit log("FK3 skip: ROBINHOOD_RPC_URL unset");
            return;
        }
        _assertThreePoolsLiveFromPostDeploy();
        uint256 shares = _seedThreeLeg(50 ether);
        assertGt(shares, 0);
        _swapExactIn(address(token0), address(token1), 1 ether);
        _swapExactIn(address(token1), address(token2), 1 ether);
        vm.prank(user);
        orbital.removeLiquidity(shares / 2, user, 0, 0, 0, block.timestamp + 1 hours);
    }
}
