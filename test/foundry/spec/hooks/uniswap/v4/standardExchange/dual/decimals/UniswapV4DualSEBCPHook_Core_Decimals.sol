// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_UniswapV4DualSEBCPHook_Decimals} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook_Decimals.sol";

/**
 * @title UniswapV4DualSEBCPHook_Core_Decimals
 * @notice Dual Core money-paths on ERC-4626×ERC-4626 cells `D_U{left}_U{right}`.
 * @dev Left SE underlying `_leftDecimals()`, right `_rightDecimals()`. After PoolKey sort,
 *      `currency0`/`currency1` may swap legs; amounts are `_uA`/`_uB` via `_humanFor`.
 *      Hook LP stays 18. Do not compare a 6-dec transfer to `1 ether`.
 */
abstract contract UniswapV4DualSEBCPHook_Core_Decimals is TestBase_UniswapV4DualSEBCPHook_Decimals {
    function test_P1_firstDeposit_mintsLpAndMinLiquidity() public {
        uint256 lp = _depositBoth(_uA(100), _uB(100));
        assertGt(lp, 0);
        assertEq(IERC20(hook).balanceOf(address(0)), 1000); // MINIMUM_LIQUIDITY
        assertGt(dual.claimSupplyCurrency0(), 0);
        assertGt(dual.claimSupplyCurrency1(), 0);
    }

    function test_P3_subsequentDeposit_previewEqualsExecution() public {
        _depositBoth(_uA(100), _uB(100));
        uint256 a0 = _humanFor(dual.currency0(), 50);
        uint256 a1 = _humanFor(dual.currency1(), 50);
        (uint256 predLp, uint256 predU0, uint256 predU1) = dual.previewDeposit(a0, a1);
        vm.prank(user);
        (uint256 lp, uint256 u0, uint256 u1) = dual.deposit(a0, a1, user, 0, block.timestamp + 1);
        assertApproxEqAbs(lp, predLp, DUST);
        assertEq(u0, predU0);
        assertEq(u1, predU1);
    }

    function test_W1_withdraw_unwrapBoth() public {
        uint256 lp = _depositBoth(_uA(100), _uB(100));
        uint256 bal0Before = IERC20(dual.currency0()).balanceOf(user);
        uint256 bal1Before = IERC20(dual.currency1()).balanceOf(user);
        (uint256 pred0, uint256 pred1) = dual.previewWithdraw(lp / 2);
        vm.prank(user);
        (uint256 a0, uint256 a1) = dual.withdraw(lp / 2, user, 0, 0, block.timestamp + 1);
        assertApproxEqAbs(a0, pred0, DUST);
        assertApproxEqAbs(a1, pred1, DUST);
        assertEq(IERC20(dual.currency0()).balanceOf(user) - bal0Before, a0);
        assertEq(IERC20(dual.currency1()).balanceOf(user) - bal1Before, a1);
    }

    function test_F2_protocolFee_mintsToFeeTo() public {
        _enableProtocolFee(0.05e18);
        _depositBoth(_uA(100), _uB(100));
        tokenA.mint(address(this), _uA(10));
        tokenB.mint(address(this), _uB(10));
        tokenA.approve(address(vaultA), _uA(10));
        tokenB.approve(address(vaultB), _uB(10));
        vaultA.simulateYield(_uA(10));
        vaultB.simulateYield(_uB(10));
        address feeTo_ = dual.feeTo();
        uint256 feeLpBefore = IERC20(hook).balanceOf(feeTo_);
        _depositBoth(_uA(10), _uB(10));
        assertGt(IERC20(hook).balanceOf(feeTo_), feeLpBefore);
        assertGt(dual.kLast(), 0);
    }
}
