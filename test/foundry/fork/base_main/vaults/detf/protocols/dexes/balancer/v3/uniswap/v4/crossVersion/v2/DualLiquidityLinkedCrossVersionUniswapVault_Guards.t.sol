// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {DualLiquidityLinkedCrossVersionUniswapVaultRepo} from
    "contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVaultRepo.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice Slippage, deadline, and recipient≠caller guards across deposit/swap/redeem/exact-out.
contract DualLiquidityLinkedCrossVersionUniswapVault_Guards is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    address internal caller = makeAddr("guardCaller");
    address internal recipient = makeAddr("guardRecipient");
    IERC20 internal shareToken;

    function setUp() public override {
        super.setUp();
        _bootstrapReserve();
        shareToken = IERC20(linkedVault);
    }

    /* ---------------------------- Slippage --------------------------------- */

    function test_guard_swap_minAmountOut_reverts() public {
        uint256 amount = 100e18;
        _fund(tokenA, caller, amount);
        uint256 preview = IStandardExchangeIn(linkedVault).previewExchangeIn(tokenA, amount, tokenB);
        vm.startPrank(caller);
        tokenA.approve(linkedVault, amount);
        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeErrors.MinAmountNotMet.selector, preview + 1, preview)
        );
        IStandardExchangeIn(linkedVault).exchangeIn(
            tokenA, amount, tokenB, preview + 1, caller, false, block.timestamp
        );
        vm.stopPrank();
    }

    function test_guard_redeem_minAmountOut_reverts() public {
        uint256 minted = _depositCommon(caller, LEG_SEED);
        address pool = _reservePool();
        uint256 preview =
            IStandardExchangeIn(linkedVault).previewExchangeIn(shareToken, minted / 4, IERC20(pool));
        vm.startPrank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeErrors.MinAmountNotMet.selector, preview + 1, preview)
        );
        IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, minted / 4, IERC20(pool), preview + 1, caller, false, block.timestamp
        );
        vm.stopPrank();
    }

    function test_guard_exactOut_maxAmountIn_reverts() public {
        uint256 probe = 50e18;
        uint256 amountOut = IStandardExchangeIn(linkedVault).previewExchangeIn(commonToken, probe, tokenA);
        amountOut = amountOut > 1 ? amountOut / 2 : amountOut;
        if (amountOut == 0) return;
        uint256 need =
            IStandardExchangeOut(linkedVault).previewExchangeOut(commonToken, tokenA, amountOut);
        _fund(commonToken, caller, need);
        vm.startPrank(caller);
        commonToken.approve(linkedVault, need);
        vm.expectRevert(); // MaxAmountExceeded or similar
        IStandardExchangeOut(linkedVault).exchangeOut(
            commonToken, need > 0 ? need - 1 : 0, tokenA, amountOut, caller, false, block.timestamp
        );
        vm.stopPrank();
    }

    /* ---------------------------- Deadline --------------------------------- */

    function test_guard_swap_expiredDeadline_reverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                DualLiquidityLinkedCrossVersionUniswapVaultRepo.DeadlineExpired.selector, block.timestamp - 1
            )
        );
        IStandardExchangeIn(linkedVault).exchangeIn(
            tokenA, 1e18, tokenB, 0, caller, false, block.timestamp - 1
        );
    }

    function test_guard_redeem_expiredDeadline_reverts() public {
        uint256 minted = _depositCommon(caller, LEG_SEED);
        vm.expectRevert(
            abi.encodeWithSelector(
                DualLiquidityLinkedCrossVersionUniswapVaultRepo.DeadlineExpired.selector, block.timestamp - 1
            )
        );
        vm.prank(caller);
        IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, minted / 10, commonToken, 0, caller, false, block.timestamp - 1
        );
    }

    function test_guard_exactOut_expiredDeadline_reverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                DualLiquidityLinkedCrossVersionUniswapVaultRepo.DeadlineExpired.selector, block.timestamp - 1
            )
        );
        IStandardExchangeOut(linkedVault).exchangeOut(
            commonToken, 1e18, tokenA, 1, caller, false, block.timestamp - 1
        );
    }

    /* ---------------------------- Recipient -------------------------------- */

    function test_guard_deposit_toThirdPartyRecipient() public {
        _fund(commonToken, caller, LEG_SEED);
        vm.startPrank(caller);
        commonToken.approve(linkedVault, LEG_SEED);
        uint256 minted = IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, LEG_SEED, shareToken, 0, recipient, false, block.timestamp
        );
        vm.stopPrank();
        assertGt(minted, 0);
        assertEq(shareToken.balanceOf(recipient), minted, "recipient got shares");
        assertEq(shareToken.balanceOf(caller), 0, "caller got none");
    }

    function test_guard_swap_toThirdPartyRecipient() public {
        _fund(tokenA, caller, 100e18);
        vm.startPrank(caller);
        tokenA.approve(linkedVault, 100e18);
        uint256 out = IStandardExchangeIn(linkedVault).exchangeIn(
            tokenA, 100e18, tokenB, 0, recipient, false, block.timestamp
        );
        vm.stopPrank();
        assertGt(out, 0);
        assertEq(tokenB.balanceOf(recipient), out);
        assertEq(tokenB.balanceOf(caller), 0);
    }

    function test_guard_redeem_toThirdPartyRecipient() public {
        uint256 minted = _depositCommon(caller, LEG_SEED);
        address pool = _reservePool();
        vm.startPrank(caller);
        uint256 bpt = IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, minted / 3, IERC20(pool), 0, recipient, false, block.timestamp
        );
        vm.stopPrank();
        assertGt(bpt, 0);
        assertEq(IERC20(pool).balanceOf(recipient), bpt);
        assertEq(IERC20(pool).balanceOf(caller), 0);
    }

    function test_guard_deposit_feeStillToFeeTo_whenRecipientThirdParty() public {
        _setUsageFee(5e16);
        address feeTo = _feeTo();
        uint256 feeBefore = shareToken.balanceOf(feeTo);
        _fund(commonToken, caller, LEG_SEED);
        vm.startPrank(caller);
        commonToken.approve(linkedVault, LEG_SEED);
        IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, LEG_SEED, shareToken, 0, recipient, false, block.timestamp
        );
        vm.stopPrank();
        assertGt(shareToken.balanceOf(feeTo), feeBefore, "fee still to feeTo not recipient");
        assertGt(shareToken.balanceOf(recipient), 0);
    }
}
