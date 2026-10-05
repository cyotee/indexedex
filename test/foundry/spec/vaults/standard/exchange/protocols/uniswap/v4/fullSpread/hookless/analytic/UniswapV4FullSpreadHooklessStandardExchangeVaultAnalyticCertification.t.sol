// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IProtocolFees} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IProtocolFees.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticTraversalTest} from "./UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticTraversal.t.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticExecutor} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/analytic/test/UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticExecutor.sol";

/// @notice PoolManager settlement. Expected numbers are not taken from `_plan`.
contract UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticCertificationTest is
    UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticTraversalTest
{
    function test_executorSettlesBothDirectionsWithDebtAndFeeSplit() public {
        IProtocolFees fees = IProtocolFees(address(manager));
        fees.setProtocolFeeController(address(this));
        fees.setProtocolFee(key, 100 | (uint24(100) << 12));
        UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticExecutor executor =
            new UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticExecutor();
        executor.bind(manager, key, lower, upper);
        IERC20 token0 = IERC20(Currency.unwrap(key.currency0));
        IERC20 token1 = IERC20(Currency.unwrap(key.currency1));
        token0.transfer(address(executor), 1e24);
        token1.transfer(address(executor), 1e24);
        executor.open(int256(uint256(1e15)));
        uint256 swapIn = 1e15;
        for (uint256 direction; direction < 2; ++direction) {
            uint256 snapshot = vm.snapshotState();
            bool zeroForOne = direction == 0;
            uint256 protocolBefore = fees.protocolFeesAccrued(zeroForOne ? key.currency0 : key.currency1);
            UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticExecutor.Settlement memory settlement =
                executor.settle(swapIn, zeroForOne, _state(), swapIn);
            int128 input = zeroForOne ? settlement.swapDelta.amount0() : settlement.swapDelta.amount1();
            int128 output = zeroForOne ? settlement.swapDelta.amount1() : settlement.swapDelta.amount0();
            assertLt(input, 0, "input is debt");
            assertGt(output, 0, "output is receivable");
            assertEq(uint256(uint128(-input)), swapIn);
            uint256 protocolAfter = fees.protocolFeesAccrued(zeroForOne ? key.currency0 : key.currency1);
            assertGt(protocolAfter, protocolBefore, "protocol fee taken");
            assertGt(settlement.shares, 0);
            assertTrue(vm.revertToStateAndDelete(snapshot));
        }
    }
}
