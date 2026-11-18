// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {ROBINHOOD_MAIN} from "@crane/contracts/constants/networks/ROBINHOOD_MAIN.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
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
        if (bytes(rpc).length == 0) rpc = vm.envOr("ROBINHOOD_RPC_ALIAS", string("robinhood_mainnet_alchemy"));
        vm.createSelectFork(rpc, vm.envOr("ROBINHOOD_FORK_BLOCK", ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK));
        assertEq(vm.getChainId(), ROBINHOOD_MAIN.CHAIN_ID);
        TestBase.setUp();
    }

    function test_FK2_depositZapWithdrawSmoke() public {
        _seedLiveLiquidity();
        vm.prank(user);
        uint256 zapLp = single.depositSingle(address(rawToken), 10 ether, user, 0, block.timestamp + 1);
        assertGt(zapLp, 0);
        uint256 lp = IERC20(hook).balanceOf(user);
        uint256 quote = single.previewWithdrawSingle(lp / 4, address(pairToken));
        uint256 beforePair = pairToken.balanceOf(user);
        vm.prank(user);
        uint256 paid = single.withdrawSingle(lp / 4, address(pairToken), user, quote, block.timestamp + 1);
        assertEq(paid, quote);
        assertEq(pairToken.balanceOf(user) - beforePair, paid, "actual recipient settlement");
        assertEq(IERC20(hook).balanceOf(user), lp - lp / 4, "actual LP burn");
        uint256 rate = IRateProvider(IUniswapV4SeBufferHook(hook).rateProvider(address(pairToken))).getRate();
        uint256 heldValue = pairToken.balanceOf(hook) + Math.mulDiv(IERC20(se).balanceOf(hook), rate, 1e18);
        assertEq(single.seClaimSupply(), heldValue, "remaining local and invested custody backs the reserve");
        assertEq(IERC20(se).allowance(hook, se), 0, "redemption approval cleared");
    }
}
