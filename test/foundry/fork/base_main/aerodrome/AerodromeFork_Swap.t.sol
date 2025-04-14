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
import {TestBase_AerodromeFork} from "test/foundry/fork/base_main/aerodrome/TestBase_AerodromeFork.sol";

/**
 * @title AerodromeFork_Swap_Test
 * @notice Fork tests for Aerodrome Standard Exchange swaps on Base mainnet.
 * @dev Mirrors tests from AerodromeStandardExchangeIn_Swap.t.sol but runs
 *      against live Base mainnet Aerodrome infrastructure.
 *
 *      Key validations:
 *      - Preview matches execution on live Aerodrome router
 *      - Balance changes are correct
 *      - Slippage protection works
 *      - No ABI/selector mismatches with mainnet contracts
 */
contract AerodromeFork_Swap_Test is TestBase_AerodromeFork {
    /* ---------------------------------------------------------------------- */
    /*                          Preview vs Math Tests                         */
    /* ---------------------------------------------------------------------- */

    function test_fork_Route1Swap_previewVsMath_balanced_AtoB() public view {
        _test_previewVsMath(PoolConfig.Balanced, true);
    }

    function test_fork_Route1Swap_previewVsMath_balanced_BtoA() public view {
        _test_previewVsMath(PoolConfig.Balanced, false);
    }

    function test_fork_Route1Swap_previewVsMath_unbalanced_AtoB() public view {
        _test_previewVsMath(PoolConfig.Unbalanced, true);
    }

    function test_fork_Route1Swap_previewVsMath_unbalanced_BtoA() public view {
        _test_previewVsMath(PoolConfig.Unbalanced, false);
    }

    function test_fork_Route1Swap_previewVsMath_extreme_AtoB() public view {
        _test_previewVsMath(PoolConfig.Extreme, true);
    }

    function test_fork_Route1Swap_previewVsMath_extreme_BtoA() public view {
        _test_previewVsMath(PoolConfig.Extreme, false);
    }

    function _test_previewVsMath(PoolConfig config, bool aToB) internal view {
        IStandardExchangeProxy vault = _getVault(config);
        IPool pool = _getPool(config);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(config);

        IERC20 tokenIn = aToB ? IERC20(address(tokenA)) : IERC20(address(tokenB));
        IERC20 tokenOut = aToB ? IERC20(address(tokenB)) : IERC20(address(tokenA));

        uint256 amountIn = TEST_AMOUNT;

        // Get expected from pool directly (mainnet pool!)
        uint256 expectedFromPool = pool.getAmountOut(amountIn, address(tokenIn));

        // Get preview from vault
        uint256 preview = vault.previewExchangeIn(tokenIn, amountIn, tokenOut);

        assertEq(preview, expectedFromPool, "Fork: Preview should match pool.getAmountOut()");
    }

    /* ---------------------------------------------------------------------- */
    /*                       Execution vs Preview Tests                       */
    /* ---------------------------------------------------------------------- */

    function test_fork_Route1Swap_execVsPreview_balanced_AtoB() public {
        _test_execVsPreview(PoolConfig.Balanced, true);
    }

    function test_fork_Route1Swap_execVsPreview_balanced_BtoA() public {
        _test_execVsPreview(PoolConfig.Balanced, false);
    }

    function test_fork_Route1Swap_execVsPreview_unbalanced_AtoB() public {
        _test_execVsPreview(PoolConfig.Unbalanced, true);
    }

    function test_fork_Route1Swap_execVsPreview_unbalanced_BtoA() public {
        _test_execVsPreview(PoolConfig.Unbalanced, false);
    }

    function test_fork_Route1Swap_execVsPreview_extreme_AtoB() public {
        _test_execVsPreview(PoolConfig.Extreme, true);
    }

    function test_fork_Route1Swap_execVsPreview_extreme_BtoA() public {
        _test_execVsPreview(PoolConfig.Extreme, false);
    }

    function _test_execVsPreview(PoolConfig config, bool aToB) internal {
        IStandardExchangeProxy vault = _getVault(config);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(config);

        ERC20PermitMintableStub tokenInStub = aToB ? tokenA : tokenB;
        IERC20 tokenIn = IERC20(address(tokenInStub));
        IERC20 tokenOut = aToB ? IERC20(address(tokenB)) : IERC20(address(tokenA));

        uint256 amountIn = TEST_AMOUNT;
        address recipient = makeAddr("recipient");

        // Mint and approve
        tokenInStub.mint(address(this), amountIn);
        tokenInStub.approve(address(vault), amountIn);

        // Get preview
        uint256 preview = vault.previewExchangeIn(tokenIn, amountIn, tokenOut);

        // Execute on mainnet infrastructure
        uint256 amountOut = vault.exchangeIn(
            tokenIn,
            amountIn,
            tokenOut,
            0, // minAmountOut
            recipient,
            false, // pretransferred
            _deadline()
        );

        assertEq(amountOut, preview, "Fork: Execution should match preview");
        assertEq(tokenOut.balanceOf(recipient), preview, "Fork: Recipient should receive preview amount");
    }

    /* ---------------------------------------------------------------------- */
    /*                         Balance Change Tests                           */
    /* ---------------------------------------------------------------------- */

    function test_fork_Route1Swap_balanceChanges_balanced_AtoB() public {
        _test_balanceChanges(PoolConfig.Balanced, true);
    }

    function test_fork_Route1Swap_balanceChanges_balanced_BtoA() public {
        _test_balanceChanges(PoolConfig.Balanced, false);
    }

    function test_fork_Route1Swap_balanceChanges_unbalanced_AtoB() public {
        _test_balanceChanges(PoolConfig.Unbalanced, true);
    }

    function test_fork_Route1Swap_balanceChanges_extreme_AtoB() public {
        _test_balanceChanges(PoolConfig.Extreme, true);
    }

    function _test_balanceChanges(PoolConfig config, bool aToB) internal {
        IStandardExchangeProxy vault = _getVault(config);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(config);

        ERC20PermitMintableStub tokenInStub = aToB ? tokenA : tokenB;
        IERC20 tokenIn = IERC20(address(tokenInStub));
        IERC20 tokenOut = aToB ? IERC20(address(tokenB)) : IERC20(address(tokenA));

        uint256 amountIn = TEST_AMOUNT;
        address recipient = makeAddr("recipient");

        // Mint and approve
        tokenInStub.mint(address(this), amountIn);
        tokenInStub.approve(address(vault), amountIn);

        uint256 senderBalanceBefore = tokenIn.balanceOf(address(this));
        uint256 recipientBalanceBefore = tokenOut.balanceOf(recipient);

        // Execute
        uint256 amountOut = vault.exchangeIn(tokenIn, amountIn, tokenOut, 0, recipient, false, _deadline());

        // Verify balance changes
        assertEq(
            tokenIn.balanceOf(address(this)),
            senderBalanceBefore - amountIn,
            "Fork: Sender tokenIn balance should decrease by amountIn"
        );
        assertEq(
            tokenOut.balanceOf(recipient),
            recipientBalanceBefore + amountOut,
            "Fork: Recipient tokenOut balance should increase by amountOut"
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                        Slippage Protection Tests                       */
    /* ---------------------------------------------------------------------- */

    function test_fork_Route1Swap_slippageProtection_exactMinimum() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);

        uint256 amountIn = TEST_AMOUNT;
        address recipient = makeAddr("recipient");

        tokenA.mint(address(this), amountIn);
        tokenA.approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(IERC20(address(tokenA)), amountIn, IERC20(address(tokenB)));

        // Should succeed with exact minAmountOut
        uint256 amountOut = vault.exchangeIn(
            IERC20(address(tokenA)),
            amountIn,
            IERC20(address(tokenB)),
            preview, // exact minimum
            recipient,
            false,
            _deadline()
        );

        assertEq(amountOut, preview, "Fork: Should succeed with exact minimum");
    }

    function test_fork_Route1Swap_slippageProtection_reverts_whenMinimumTooHigh() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);

        uint256 amountIn = TEST_AMOUNT;
        address recipient = makeAddr("recipient");

        tokenA.mint(address(this), amountIn);
        tokenA.approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(IERC20(address(tokenA)), amountIn, IERC20(address(tokenB)));

        // Should revert with minAmountOut too high
        vm.expectRevert();
        vault.exchangeIn(
            IERC20(address(tokenA)),
            amountIn,
            IERC20(address(tokenB)),
            preview + 1, // too high
            recipient,
            false,
            _deadline()
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                        Pretransferred Token Tests                      */
    /* ---------------------------------------------------------------------- */

    function test_fork_Route1Swap_pretransferred_true() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);

        uint256 amountIn = TEST_AMOUNT;
        address recipient = makeAddr("recipient");

        // Transfer tokens to vault first
        tokenA.mint(address(this), amountIn);
        tokenA.transfer(address(vault), amountIn);

        uint256 senderBalanceBefore = tokenA.balanceOf(address(this));

        // Execute with pretransferred=true
        vault.exchangeIn(
            IERC20(address(tokenA)),
            amountIn,
            IERC20(address(tokenB)),
            0,
            recipient,
            true, // pretransferred
            _deadline()
        );

        // Sender balance should not change (tokens were already transferred)
        assertEq(tokenA.balanceOf(address(this)), senderBalanceBefore, "Fork: No additional transfer from sender");
        assertTrue(tokenB.balanceOf(recipient) > 0, "Fork: Recipient received tokens");
    }

    function test_fork_Route1Swap_pretransferred_false() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);

        uint256 amountIn = TEST_AMOUNT;
        address recipient = makeAddr("recipient");

        tokenA.mint(address(this), amountIn);
        tokenA.approve(address(vault), amountIn);

        uint256 senderBalanceBefore = tokenA.balanceOf(address(this));

        // Execute with pretransferred=false
        vault.exchangeIn(
            IERC20(address(tokenA)),
            amountIn,
            IERC20(address(tokenB)),
            0,
            recipient,
            false, // not pretransferred
            _deadline()
        );

        // Sender balance should decrease
        assertEq(
            tokenA.balanceOf(address(this)), senderBalanceBefore - amountIn, "Fork: Tokens transferred from sender"
        );
        assertTrue(tokenB.balanceOf(recipient) > 0, "Fork: Recipient received tokens");
    }

    /* ---------------------------------------------------------------------- */
    /*                             Fuzz Tests                                 */
    /* ---------------------------------------------------------------------- */

    function testFuzz_fork_Route1Swap_balanced_AtoB(uint256 amountIn) public {
        _testFuzz_swap(PoolConfig.Balanced, true, amountIn);
    }

    function testFuzz_fork_Route1Swap_balanced_BtoA(uint256 amountIn) public {
        _testFuzz_swap(PoolConfig.Balanced, false, amountIn);
    }

    function testFuzz_fork_Route1Swap_unbalanced_AtoB(uint256 amountIn) public {
        _testFuzz_swap(PoolConfig.Unbalanced, true, amountIn);
    }

    function testFuzz_fork_Route1Swap_extreme_AtoB(uint256 amountIn) public {
        _testFuzz_swap(PoolConfig.Extreme, true, amountIn);
    }

    function _testFuzz_swap(PoolConfig config, bool aToB, uint256 amountIn) internal {
        IStandardExchangeProxy vault = _getVault(config);
        IPool pool = _getPool(config);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(config);

        ERC20PermitMintableStub tokenInStub = aToB ? tokenA : tokenB;
        amountIn = _boundSwapAmount(pool, tokenInStub, amountIn);

        IERC20 tokenOut = aToB ? IERC20(address(tokenB)) : IERC20(address(tokenA));
        address recipient = makeAddr("recipient");

        tokenInStub.mint(address(this), amountIn);
        tokenInStub.approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(IERC20(address(tokenInStub)), amountIn, tokenOut);
        uint256 amountOut =
            vault.exchangeIn(IERC20(address(tokenInStub)), amountIn, tokenOut, 0, recipient, false, _deadline());

        assertEq(amountOut, preview, "Fork fuzz: execution should match preview");
        assertEq(tokenOut.balanceOf(recipient), amountOut, "Fork fuzz: recipient balance correct");
    }

    /* ---------------------------------------------------------------------- */
    /*                    Fork-Specific Integration Tests                     */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Test that vault interacts correctly with mainnet router.
     * @dev Validates no ABI mismatches or selector issues.
     */
    function test_fork_mainnetRouterIntegration() public {
        // This test validates that our vault can correctly call mainnet router
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);

        uint256 amountIn = TEST_AMOUNT;
        address recipient = makeAddr("integration_recipient");

        tokenA.mint(address(this), amountIn);
        tokenA.approve(address(vault), amountIn);

        // Execute swap - this goes through mainnet Aerodrome router
        uint256 amountOut = vault.exchangeIn(
            IERC20(address(tokenA)), amountIn, IERC20(address(tokenB)), 0, recipient, false, _deadline()
        );

        // Verify successful execution with mainnet infrastructure
        assertGt(amountOut, 0, "Fork: Should receive tokens from mainnet router swap");
        assertEq(tokenB.balanceOf(recipient), amountOut, "Fork: Recipient balance correct");
        assertEq(tokenA.balanceOf(address(this)), 0, "Fork: All input tokens consumed");
    }

    /**
     * @notice Test that vault correctly handles mainnet pool reserves.
     * @dev Verifies reserve queries work against mainnet pool.
     */
    function test_fork_mainnetPoolReservesQuery() public view {
        IPool pool = _getPool(PoolConfig.Balanced);

        (uint256 reserve0, uint256 reserve1,) = pool.getReserves();

        // Pool should have liquidity from our initialization
        assertGt(reserve0, 0, "Fork: Pool should have reserve0");
        assertGt(reserve1, 0, "Fork: Pool should have reserve1");
    }
}
