// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";

/**
 * @title Protocol growth fee / kLast / yield matrix.
 */
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_Fees_Test is TestBase {
    function test_F3_feeOff_kLastZero() public {
        _seedLiveLiquidity();
        // default: no vault dex fee → fee-off
        (address feeTo_, uint256 wad) = single.dexSwapFeeAndFeeTo();
        // may have feeTo but wad 0
        if (wad == 0) {
            assertEq(single.kLast(), 0);
        }
        feeTo_;
    }

    function test_F2_protocolFee_mintsToFeeTo_onGrowth() public {
        _enableProtocolFee(0.05e18);
        _seedLiveLiquidity();
        assertGt(single.kLast(), 0);

        // Yield grows SE claim (virtual pair) without user capital
        pairToken.mint(address(this), 20 ether);
        pairToken.approve(address(pairProtocolVault), 20 ether);
        pairProtocolVault.simulateYield(20 ether);

        address feeTo_ = _feeTo();
        uint256 feeLpBefore = IERC20(hook).balanceOf(feeTo_);
        _depositBoth(10 ether, 10 ether);
        assertGt(IERC20(hook).balanceOf(feeTo_), feeLpBefore);
        assertGt(single.kLast(), 0);
    }

    function test_Y1_yieldMovesVirtualPairWithoutSwap() public {
        _seedLiveLiquidity();
        uint256 claimBefore = single.seClaimSupply();
        pairToken.mint(address(this), 15 ether);
        pairToken.approve(address(pairProtocolVault), 15 ether);
        pairProtocolVault.simulateYield(15 ether);
        // SE claim rate rose; hook still holds same SE shares → claim supply up
        // Need to re-read seClaim via preview — balance of SE shares unchanged
        uint256 seBal = IERC20(se).balanceOf(hook);
        assertGt(seBal, 0);
        uint256 claimAfter = single.seClaimSupply();
        assertGt(claimAfter, claimBefore);
    }

    function test_F5_feeOn_depositPreviewEqualsExec() public {
        _enableProtocolFee(0.03e18);
        _seedLiveLiquidity();
        uint256 a0 = _amountForCurrency(single.currency0(), 20 ether, 20 ether);
        uint256 a1 = _amountForCurrency(single.currency1(), 20 ether, 20 ether);
        (uint256 predLp, uint256 predU0, uint256 predU1) = single.previewDeposit(a0, a1);
        vm.prank(user);
        (uint256 lp, uint256 u0, uint256 u1) = single.deposit(a0, a1, user, 0, block.timestamp + 1);
        assertApproxEqRel(lp, predLp, 0.02e18);
        assertEq(u0, predU0);
        assertEq(u1, predU1);
    }
}
