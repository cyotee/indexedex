// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";

/**
 * @title Robinhood 4663 fork smoke.
 */
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_Robinhood_Test is TestBase {
    function setUp() public override {
        string memory rpc = vm.envOr("ROBINHOOD_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            rpc = vm.envOr("RPC_URL_4663", string(""));
        }
        if (bytes(rpc).length > 0) {
            try vm.createSelectFork(rpc) {} catch {}
        }
        TestBase.setUp();
    }

    function test_FK2_depositZapWithdrawSmoke() public {
        _seedLiveLiquidity();
        vm.prank(user);
        uint256 zapLp = single.depositSingle(address(rawToken), 10 ether, user, 0, block.timestamp + 1);
        assertGt(zapLp, 0);
        uint256 lp = IERC20(hook).balanceOf(user);
        vm.prank(user);
        single.withdrawSingle(lp / 4, address(pairToken), user, 0, block.timestamp + 1);
        assertLe(pairToken.balanceOf(hook), 10);
    }
}
