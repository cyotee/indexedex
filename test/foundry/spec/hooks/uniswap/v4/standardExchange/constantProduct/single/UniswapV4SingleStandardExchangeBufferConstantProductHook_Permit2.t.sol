// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IAllowanceTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";

/**
 * @title Permit2 deposit paths (real Permit2 from TestBase_Permit2).
 */
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_Permit2_Test is TestBase {
    function setUp() public override {
        TestBase.setUp();
        _seedLiveLiquidity();
    }

    function test_R1_depositWithPermit2Allowance_whenApproved() public {
        uint256 a0 = _amountForCurrency(single.currency0(), 5 ether, 5 ether);
        uint256 a1 = _amountForCurrency(single.currency1(), 5 ether, 5 ether);

        vm.startPrank(user);
        rawToken.approve(address(permit2), type(uint256).max);
        pairToken.approve(address(permit2), type(uint256).max);
        IAllowanceTransfer(address(permit2)).approve(
            address(rawToken), hook, type(uint160).max, type(uint48).max
        );
        IAllowanceTransfer(address(permit2)).approve(
            address(pairToken), hook, type(uint160).max, type(uint48).max
        );

        (uint256 lp,,) =
            single.depositWithPermit2Allowance(a0, a1, user, 0, block.timestamp + 1 hours);
        vm.stopPrank();
        assertGt(lp, 0);
    }

    function test_R1b_depositSingleWithPermit2Allowance() public {
        vm.startPrank(user);
        rawToken.approve(address(permit2), type(uint256).max);
        IAllowanceTransfer(address(permit2)).approve(
            address(rawToken), hook, type(uint160).max, type(uint48).max
        );
        uint256 lp = single.depositSingleWithPermit2Allowance(
            address(rawToken), 5 ether, user, 0, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(lp, 0);
    }
}
