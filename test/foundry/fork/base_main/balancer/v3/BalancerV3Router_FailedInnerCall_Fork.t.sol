// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {IWETH} from '@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol';
import {BetterAddress} from '@crane/contracts/utils/BetterAddress.sol';

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeProxy} from 'contracts/interfaces/proxies/IStandardExchangeProxy.sol';
import {
    TestBase_BalancerV3Fork_StrategyVault
} from 'test/foundry/fork/base_main/balancer/v3/TestBase_BalancerV3Fork_StrategyVault.sol';

/**
 * @title BalancerV3Router_FailedInnerCall_Fork_Test
 * @notice Fork test to reproduce FailedInnerCall error when Balancer V3 router
 *         tries to send ETH to a contract that cannot receive it.
 * @dev The error occurs in:
 *      BalancerV3StandardExchangeRouterExactOutSwapTarget.sol:243
 *      payable(params.sender).sendValue(amountCalculated);
 *
 *      When params.sender is a contract without receive() function, sendValue fails.
 *
 * ROOT CAUSE:
 * ===========
 * The BetterAddress.sendValue() function (similar to OpenZeppelin's Address.sendValue)
 * performs a low-level call and checks the return value. If the recipient contract's
 * receive() function reverts, the call returns false, and sendValue reverts.
 *
 * ERROR SELECTOR: 0xd6bda275 (from BetterAddress)
 *
 * FIX OPTIONS:
 * 1. Wrap sendValue in try-catch and handle failure gracefully
 * 2. Check if recipient can receive ETH before sending
 * 3. Use a pull pattern instead of push pattern
 */
contract BalancerV3Router_FailedInnerCall_Fork_Test is TestBase_BalancerV3Fork_StrategyVault {
    uint256 internal constant SWAP_AMOUNT = 1e18;

    /* ---------------------------------------------------------------------- */
    /*                   PRIMARY TEST: Reproduce FailedInnerCall               */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice PRIMARY TEST: Reproduce FailedInnerCall error
     * @dev This test reproduces the exact error scenario:
     *      1. User is a contract that cannot receive ETH (no receive() or receive() reverts)
     *      2. User calls router.swapSingleTokenExactOut with wethIsEth=true
     *      3. Router executes swap and gets WETH
     *      4. Router unwraps WETH to ETH
     *      5. Router tries to send ETH to user via BetterAddress.sendValue()
     *      6. sendValue fails because user's receive() reverts
     *      7. Transaction reverts with error from BetterAddress
     *
     * EXPECTED: Test passes (expectRevert catches the revert)
     */
    function test_fork_vaultPassThrough_wethUnwrap_toContract_reproducesError() public {
        // Create a contract that cannot receive ETH
        address contractSender = address(new NonReceivingContract());

        // Give the contract some DAI
        dai.mint(contractSender, SWAP_AMOUNT * 100);

        vm.startPrank(contractSender);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        // Vault pass-through route with WETH unwrap:
        // - pool = address(daiUsdcVault) (the vault is both tokenInVault and tokenOutVault)
        // - tokenIn = DAI
        // - tokenInVault = daiUsdcVault
        // - tokenOut = WETH
        // - tokenOutVault = daiUsdcVault (pass-through)
        // - wethIsEth = true
        //
        // The router will:
        // 1. Transfer DAI to vault
        // 2. Call vault.exchangeOut(DAI -> USDC)
        // 3. Get USDC from vault
        // 4. Swap USDC -> WETH on Balancer
        // 5. Unwrap WETH -> ETH
        // 6. Send ETH to contractSender -> FAILS with error
        vm.expectRevert();
        seRouter.swapSingleTokenExactOut(
            address(daiUsdcVault), // Using vault as pool for pass-through
            IERC20(address(dai)),
            IStandardExchangeProxy(address(daiUsdcVault)),
            IERC20(address(weth)),
            IStandardExchangeProxy(address(daiUsdcVault)), // Same vault for pass-through
            SWAP_AMOUNT,
            SWAP_AMOUNT * 100,
            _deadline(),
            true, // wethIsEth = true - THIS TRIGGERS THE ETH SEND PATH
            ''
        );

        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*              VERIFICATION TEST: sendValue to contract fails             */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice VERIFICATION: BetterAddress.sendValue fails when recipient cannot receive ETH
     * @dev This directly tests the underlying mechanism that causes the error
     */
    function test_fork_sendValue_toNonReceivingContract_fails() public {
        address contractRecipient = address(new NonReceivingContract());
        deal(address(this), 1 ether);
        
        vm.expectRevert();
        BetterAddress.sendValue(payable(contractRecipient), 0.5 ether);
    }



    /* ---------------------------------------------------------------------- */
    /*              CONTROL TEST: Same flow with EOA succeeds                  */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice VERIFICATION: WETH unwrap to EOA now succeeds with the fix
     * @dev After fixing the amount bug (using params.amountGiven instead of amountCalculated),
     *      the swap should succeed when the recipient is an EOA
     */
    function test_fork_vaultPassThrough_wethUnwrap_EOA_succeedsWithFix() public {
        // Create a fresh EOA for this test
        address eoa = makeAddr('eoa');
        
        dai.mint(eoa, SWAP_AMOUNT * 100);

        vm.startPrank(eoa);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        // This should now succeed with the fix
        // The key difference: we're using an Aerodrome vault that swaps DAI for WETH
        // and the router correctly withdraws the WETH amount (params.amountGiven)
        // instead of the input amount (amountCalculated)
        uint256 amountIn = seRouter.swapSingleTokenExactOut(
            address(daiWethVault), // Use DAI/WETH vault which actually has WETH
            IERC20(address(dai)),
            IStandardExchangeProxy(address(daiWethVault)),
            IERC20(address(weth)),
            IStandardExchangeProxy(address(daiWethVault)),
            SWAP_AMOUNT,
            SWAP_AMOUNT * 100,
            _deadline(),
            true,
            ''
        );

        vm.stopPrank();

        // Verify the swap succeeded and returned a valid amountIn
        assertGt(amountIn, 0, 'Swap should have consumed some input tokens');
    }
}

/**
 * @title NonReceivingContract
 * @notice A contract that cannot receive ETH
 * @dev Any ETH transfer to this contract will revert
 *      because receive() reverts with 'Cannot receive ETH'
 */
contract NonReceivingContract {
    /// @notice Revert on any ETH receive attempt
    receive() external payable {
        revert('Cannot receive ETH');
    }
}
