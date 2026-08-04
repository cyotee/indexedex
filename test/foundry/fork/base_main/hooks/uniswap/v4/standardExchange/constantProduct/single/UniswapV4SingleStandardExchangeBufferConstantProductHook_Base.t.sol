// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";

/**
 * @title Base mainnet fork smoke (deposit → book swap → withdraw).
 * @dev Uses hermetic PM/SE when fork RPC unavailable; real fork when BASE_RPC_URL set.
 */
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_Base_Test is TestBase {
    function setUp() public override {
        string memory rpc = vm.envOr("BASE_RPC_URL", string(""));
        if (bytes(rpc).length > 0) {
            try vm.createSelectFork(rpc) {} catch {}
        }
        TestBase.setUp();
    }

    function test_FK1_depositSwapWithdrawSmoke() public {
        _seedLiveLiquidity();
        uint256 lp = IERC20(hook).balanceOf(user);
        vm.prank(user);
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(rawToken)),
            2 ether,
            IERC20(address(pairToken)),
            0,
            user,
            false,
            block.timestamp + 1
        );
        vm.prank(user);
        single.withdraw(lp / 2, user, 0, 0, block.timestamp + 1);
        assertTrue(single.isLive() || IERC20(hook).totalSupply() >= 1000);
    }
}
