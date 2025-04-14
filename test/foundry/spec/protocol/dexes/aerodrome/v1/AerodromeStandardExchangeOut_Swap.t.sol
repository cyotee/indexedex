// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_AerodromeStandardExchange_MultiPool
} from "contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_AerodromeStandardExchange_MultiPool.sol";

/**
 * @title AerodromeStandardExchangeOut_Swap_Test
 * @notice Tests for IDXEX-059: Fix Aerodrome pass-through swap exact-out semantics.
 * @dev Tests the pass-through swap route (token A -> token B, both pool constituents)
 *      using exchangeOut with exact-out semantics and pretransferred refund behavior.
 */
contract AerodromeStandardExchangeOut_Swap_Test is TestBase_AerodromeStandardExchange_MultiPool {
    address caller;

    /// @notice Small test amount that works for all pool configurations
    uint256 constant SMALL_AMOUNT_OUT = 10e18;

    function setUp() public override {
        super.setUp();
        caller = makeAddr("caller");
    }

    /// @dev Get a safe amountOut that is within pool reserves for the given direction.
    function _safeAmountOut(PoolConfig config, bool aToB) internal view returns (uint256) {
        IPool pool = _getPool(config);
        (ERC20PermitMintableStub tokenA,) = _getTokens(config);
        (uint256 reserve0, uint256 reserve1,) = pool.getReserves();
        // tokenOut reserve
        uint256 reserveOut = aToB
            ? (address(tokenA) == pool.token0() ? reserve1 : reserve0)
            : (address(tokenA) == pool.token0() ? reserve0 : reserve1);
        // Use 1% of the output reserve to stay well within bounds
        uint256 safe = reserveOut / 100;
        return safe > SMALL_AMOUNT_OUT ? SMALL_AMOUNT_OUT : safe;
    }

    /* ---------------------------------------------------------------------- */
    /*                   Preview vs Execution (Exact-Out)                     */
    /* ---------------------------------------------------------------------- */

    function test_exchangeOut_swap_balanced_AtoB() public {
        _test_exchangeOut_swap(PoolConfig.Balanced, true);
    }

    function test_exchangeOut_swap_balanced_BtoA() public {
        _test_exchangeOut_swap(PoolConfig.Balanced, false);
    }

    function test_exchangeOut_swap_unbalanced_AtoB() public {
        _test_exchangeOut_swap(PoolConfig.Unbalanced, true);
    }

    function test_exchangeOut_swap_unbalanced_BtoA() public {
        _test_exchangeOut_swap(PoolConfig.Unbalanced, false);
    }

    function test_exchangeOut_swap_extreme_AtoB() public {
        _test_exchangeOut_swap(PoolConfig.Extreme, true);
    }

    function test_exchangeOut_swap_extreme_BtoA() public {
        _test_exchangeOut_swap(PoolConfig.Extreme, false);
    }

    function _test_exchangeOut_swap(PoolConfig config, bool aToB) internal {
        IStandardExchangeProxy vault = _getVault(config);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(config);

        ERC20PermitMintableStub tokenInStub = aToB ? tokenA : tokenB;
        IERC20 tokenIn = IERC20(address(tokenInStub));
        IERC20 tokenOut = aToB ? IERC20(address(tokenB)) : IERC20(address(tokenA));

        uint256 amountOut = _safeAmountOut(config, aToB);
        address recipient = makeAddr("recipient");

        // Preview to get expected amountIn
        uint256 expectedAmountIn = vault.previewExchangeOut(tokenIn, tokenOut, amountOut);

        // Mint and approve
        tokenInStub.mint(address(this), expectedAmountIn);
        tokenInStub.approve(address(vault), expectedAmountIn);

        // Execute
        uint256 amountIn = vault.exchangeOut(
            tokenIn,
            expectedAmountIn,
            tokenOut,
            amountOut,
            recipient,
            false, // not pretransferred
            _deadline()
        );

        assertEq(amountIn, expectedAmountIn, "AmountIn should match preview");
        assertGe(tokenOut.balanceOf(recipient), amountOut, "Recipient should receive at least amountOut");
    }

    /* ---------------------------------------------------------------------- */
    /*        Pretransferred Refund: Surplus -> Refund Occurs (IDXEX-059)     */
    /* ---------------------------------------------------------------------- */

    function test_exchangeOut_swap_pretransferredRefund_balanced_AtoB() public {
        _test_pretransferredRefund(PoolConfig.Balanced, true);
    }

    function test_exchangeOut_swap_pretransferredRefund_balanced_BtoA() public {
        _test_pretransferredRefund(PoolConfig.Balanced, false);
    }

    function test_exchangeOut_swap_pretransferredRefund_unbalanced_AtoB() public {
        _test_pretransferredRefund(PoolConfig.Unbalanced, true);
    }

    function test_exchangeOut_swap_pretransferredRefund_extreme_AtoB() public {
        _test_pretransferredRefund(PoolConfig.Extreme, true);
    }

    function _test_pretransferredRefund(PoolConfig config, bool aToB) internal {
        IStandardExchangeProxy vault = _getVault(config);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(config);

        ERC20PermitMintableStub tokenInStub = aToB ? tokenA : tokenB;
        IERC20 tokenIn = IERC20(address(tokenInStub));
        IERC20 tokenOut = aToB ? IERC20(address(tokenB)) : IERC20(address(tokenA));

        uint256 amountOut = _safeAmountOut(config, aToB);

        // Preview to get expected amountIn
        uint256 expectedAmountIn = vault.previewExchangeOut(tokenIn, tokenOut, amountOut);
        require(expectedAmountIn > 0, "Preview must be non-zero");

        // Create surplus: send 2x the needed amount
        uint256 maxAmountIn = expectedAmountIn * 2;
        tokenInStub.mint(caller, maxAmountIn);

        vm.startPrank(caller);
        // Pretransfer all tokens to the vault
        tokenIn.transfer(address(vault), maxAmountIn);

        uint256 callerTokenInBefore = tokenIn.balanceOf(caller);
        assertEq(callerTokenInBefore, 0, "Caller should have 0 tokenIn after pretransfer");

        // Execute exchangeOut with pretransferred = true
        uint256 amountIn = vault.exchangeOut(
            tokenIn,
            maxAmountIn,
            tokenOut,
            amountOut,
            caller,
            true, // pretransferred
            _deadline()
        );
        vm.stopPrank();

        // Verify the surplus was refunded
        uint256 callerTokenInAfter = tokenIn.balanceOf(caller);
        uint256 refundAmount = maxAmountIn - amountIn;
        assertGt(refundAmount, 0, "Refund must be > 0 when surplus exists");
        assertEq(callerTokenInAfter, refundAmount, "Caller should receive refund of unused tokens");

        // Verify the output was received
        assertGe(tokenOut.balanceOf(caller), amountOut, "Caller should receive at least amountOut");
    }

    /* ---------------------------------------------------------------------- */
    /*     Pretransferred Exact: No Refund, No Revert (IDXEX-059)            */
    /* ---------------------------------------------------------------------- */

    function test_exchangeOut_swap_pretransferredExactNoRefund_balanced() public {
        _test_pretransferredExactNoRefund(PoolConfig.Balanced, true);
    }

    function test_exchangeOut_swap_pretransferredExactNoRefund_unbalanced() public {
        _test_pretransferredExactNoRefund(PoolConfig.Unbalanced, true);
    }

    function _test_pretransferredExactNoRefund(PoolConfig config, bool aToB) internal {
        IStandardExchangeProxy vault = _getVault(config);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(config);

        ERC20PermitMintableStub tokenInStub = aToB ? tokenA : tokenB;
        IERC20 tokenIn = IERC20(address(tokenInStub));
        IERC20 tokenOut = aToB ? IERC20(address(tokenB)) : IERC20(address(tokenA));

        uint256 amountOut = _safeAmountOut(config, aToB);

        // Preview to get exact amountIn needed
        uint256 expectedAmountIn = vault.previewExchangeOut(tokenIn, tokenOut, amountOut);

        // Mint exactly the needed amount
        tokenInStub.mint(caller, expectedAmountIn);

        vm.startPrank(caller);
        // Pretransfer exactly the needed amount
        tokenIn.transfer(address(vault), expectedAmountIn);

        // Execute exchangeOut with exact amount pretransferred
        uint256 amountIn = vault.exchangeOut(
            tokenIn,
            expectedAmountIn,
            tokenOut,
            amountOut,
            caller,
            true, // pretransferred
            _deadline()
        );
        vm.stopPrank();

        // No refund because exact amount was used
        assertEq(tokenIn.balanceOf(caller), 0, "No refund when exact amount pretransferred");
        assertEq(amountIn, expectedAmountIn, "AmountIn should match preview");
        assertGe(tokenOut.balanceOf(caller), amountOut, "Caller should receive at least amountOut");
    }

    /* ---------------------------------------------------------------------- */
    /*                         Slippage Protection                           */
    /* ---------------------------------------------------------------------- */

    function test_exchangeOut_swap_revertsWhenMaxAmountInInsufficient() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);

        IERC20 tokenIn = IERC20(address(tokenA));
        IERC20 tokenOut = IERC20(address(tokenB));

        uint256 amountOut = _safeAmountOut(PoolConfig.Balanced, true);
        uint256 expectedAmountIn = vault.previewExchangeOut(tokenIn, tokenOut, amountOut);

        // Set maxAmountIn below required
        uint256 tooLowMax = expectedAmountIn - 1;

        tokenA.mint(address(this), expectedAmountIn);
        tokenA.approve(address(vault), expectedAmountIn);

        vm.expectRevert();
        vault.exchangeOut(tokenIn, tooLowMax, tokenOut, amountOut, address(this), false, _deadline());
    }

    /* ---------------------------------------------------------------------- */
    /*                              Fuzz Tests                               */
    /* ---------------------------------------------------------------------- */

    function testFuzz_exchangeOut_swap_refundInvariant(uint256 surplus) public {
        surplus = bound(surplus, 1e12, 100e18);

        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);

        IERC20 tokenIn = IERC20(address(tokenA));
        IERC20 tokenOut = IERC20(address(tokenB));

        uint256 amountOut = _safeAmountOut(PoolConfig.Balanced, true);
        uint256 expectedAmountIn = vault.previewExchangeOut(tokenIn, tokenOut, amountOut);
        uint256 maxAmountIn = expectedAmountIn + surplus;

        tokenA.mint(caller, maxAmountIn);

        vm.startPrank(caller);
        uint256 callerTokenInBefore = tokenIn.balanceOf(caller);
        tokenIn.transfer(address(vault), maxAmountIn);

        uint256 amountIn = vault.exchangeOut(tokenIn, maxAmountIn, tokenOut, amountOut, caller, true, _deadline());
        vm.stopPrank();

        // Invariant: the net tokens spent by the caller is exactly amountIn
        uint256 callerTokenInAfter = tokenIn.balanceOf(caller);
        uint256 netSpent = callerTokenInBefore - callerTokenInAfter;
        assertEq(netSpent, amountIn, "Refund invariant: caller net spent == amountIn");

        // Equivalently, the refund was maxAmountIn - amountIn
        uint256 refundReceived = callerTokenInAfter - (callerTokenInBefore - maxAmountIn);
        assertEq(refundReceived, maxAmountIn - amountIn, "Refund invariant: refund == maxAmountIn - amountIn");
    }
}
