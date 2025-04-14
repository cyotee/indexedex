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
import {TestBase_AerodromeFork} from "./TestBase_AerodromeFork.sol";

/**
 * @title AerodromeFork_ZapIn_Test
 * @notice Fork tests for Route 2: Token to LP token zap.
 * @dev Tests zaps against live Aerodrome infrastructure on Base mainnet.
 *      Validates swapping half of tokenIn for the other pool token, then adding liquidity.
 */
contract AerodromeFork_ZapIn_Test is TestBase_AerodromeFork {
    /* ---------------------------------------------------------------------- */
    /*                       Execution vs Preview Tests                       */
    /* ---------------------------------------------------------------------- */

    function test_Route2ZapIn_execVsPreview_balanced_tokenA() public {
        _test_execVsPreview(PoolConfig.Balanced, true);
    }

    function test_Route2ZapIn_execVsPreview_balanced_tokenB() public {
        _test_execVsPreview(PoolConfig.Balanced, false);
    }

    function test_Route2ZapIn_execVsPreview_unbalanced_tokenA() public {
        _test_execVsPreview(PoolConfig.Unbalanced, true);
    }

    function test_Route2ZapIn_execVsPreview_unbalanced_tokenB() public {
        _test_execVsPreview(PoolConfig.Unbalanced, false);
    }

    function test_Route2ZapIn_execVsPreview_extreme_tokenA() public {
        _test_execVsPreview(PoolConfig.Extreme, true);
    }

    function test_Route2ZapIn_execVsPreview_extreme_tokenB() public {
        _test_execVsPreview(PoolConfig.Extreme, false);
    }

    function _test_execVsPreview(PoolConfig config, bool useTokenA) internal {
        IStandardExchangeProxy vault = _getVault(config);
        IPool pool = _getPool(config);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(config);

        ERC20PermitMintableStub tokenInStub = useTokenA ? tokenA : tokenB;
        IERC20 tokenIn = IERC20(address(tokenInStub));
        IERC20 lpToken = IERC20(address(pool));

        uint256 amountIn = TEST_AMOUNT;
        address recipient = makeAddr("recipient");

        // Mint and approve
        tokenInStub.mint(address(this), amountIn);
        tokenInStub.approve(address(vault), amountIn);

        // Get preview
        uint256 preview = vault.previewExchangeIn(tokenIn, amountIn, lpToken);
        assertTrue(preview > 0, "Preview should be non-zero");

        // Execute
        uint256 lpOut = vault.exchangeIn(tokenIn, amountIn, lpToken, 0, recipient, false, _deadline());

        assertEq(lpOut, preview, "Execution should match preview");
        assertEq(lpToken.balanceOf(recipient), preview, "Recipient should receive preview LP amount");
    }

    /* ---------------------------------------------------------------------- */
    /*                         Balance Change Tests                           */
    /* ---------------------------------------------------------------------- */

    function test_Route2ZapIn_balanceChanges_balanced_tokenA() public {
        _test_balanceChanges(PoolConfig.Balanced, true);
    }

    function test_Route2ZapIn_balanceChanges_balanced_tokenB() public {
        _test_balanceChanges(PoolConfig.Balanced, false);
    }

    function test_Route2ZapIn_balanceChanges_unbalanced_tokenA() public {
        _test_balanceChanges(PoolConfig.Unbalanced, true);
    }

    function _test_balanceChanges(PoolConfig config, bool useTokenA) internal {
        IStandardExchangeProxy vault = _getVault(config);
        IPool pool = _getPool(config);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(config);

        ERC20PermitMintableStub tokenInStub = useTokenA ? tokenA : tokenB;
        IERC20 tokenIn = IERC20(address(tokenInStub));
        IERC20 lpToken = IERC20(address(pool));

        uint256 amountIn = TEST_AMOUNT;
        address recipient = makeAddr("recipient");

        tokenInStub.mint(address(this), amountIn);
        tokenInStub.approve(address(vault), amountIn);

        uint256 senderBalanceBefore = tokenIn.balanceOf(address(this));
        uint256 recipientLPBefore = lpToken.balanceOf(recipient);
        uint256 lpTotalSupplyBefore = lpToken.totalSupply();

        uint256 lpOut = vault.exchangeIn(tokenIn, amountIn, lpToken, 0, recipient, false, _deadline());

        // Sender token decreased
        assertEq(
            tokenIn.balanceOf(address(this)), senderBalanceBefore - amountIn, "Sender token balance should decrease"
        );
        // Recipient LP increased
        assertEq(lpToken.balanceOf(recipient), recipientLPBefore + lpOut, "Recipient LP balance should increase");
        // LP total supply increased
        assertEq(lpToken.totalSupply(), lpTotalSupplyBefore + lpOut, "LP total supply should increase");
    }

    /* ---------------------------------------------------------------------- */
    /*                        Slippage Protection Tests                       */
    /* ---------------------------------------------------------------------- */

    function test_Route2ZapIn_slippageProtection_exactMinimum() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);
        (ERC20PermitMintableStub tokenA,) = _getTokens(PoolConfig.Balanced);

        uint256 amountIn = TEST_AMOUNT;
        address recipient = makeAddr("recipient");

        tokenA.mint(address(this), amountIn);
        tokenA.approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(IERC20(address(tokenA)), amountIn, IERC20(address(pool)));

        // Should succeed with exact minAmountOut
        uint256 lpOut = vault.exchangeIn(
            IERC20(address(tokenA)),
            amountIn,
            IERC20(address(pool)),
            preview, // exact minimum
            recipient,
            false,
            _deadline()
        );

        assertEq(lpOut, preview, "Should succeed with exact minimum");
    }

    function test_Route2ZapIn_slippageProtection_reverts_whenMinimumTooHigh() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);
        (ERC20PermitMintableStub tokenA,) = _getTokens(PoolConfig.Balanced);

        uint256 amountIn = TEST_AMOUNT;
        address recipient = makeAddr("recipient");

        tokenA.mint(address(this), amountIn);
        tokenA.approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(IERC20(address(tokenA)), amountIn, IERC20(address(pool)));

        // Should revert with minAmountOut too high
        vm.expectRevert();
        vault.exchangeIn(
            IERC20(address(tokenA)),
            amountIn,
            IERC20(address(pool)),
            preview + 1, // too high
            recipient,
            false,
            _deadline()
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                        Pretransferred Token Tests                      */
    /* ---------------------------------------------------------------------- */

    function test_Route2ZapIn_pretransferred_true() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);
        (ERC20PermitMintableStub tokenA,) = _getTokens(PoolConfig.Balanced);

        uint256 amountIn = TEST_AMOUNT;
        address recipient = makeAddr("recipient");

        // Transfer tokens to vault first
        tokenA.mint(address(this), amountIn);
        tokenA.transfer(address(vault), amountIn);

        uint256 senderBalanceBefore = tokenA.balanceOf(address(this));

        // Execute with pretransferred=true
        uint256 lpOut = vault.exchangeIn(
            IERC20(address(tokenA)),
            amountIn,
            IERC20(address(pool)),
            0,
            recipient,
            true, // pretransferred
            _deadline()
        );

        // Sender balance should not change
        assertEq(tokenA.balanceOf(address(this)), senderBalanceBefore, "No additional transfer from sender");
        assertTrue(lpOut > 0, "Received LP tokens");
        assertEq(IERC20(address(pool)).balanceOf(recipient), lpOut, "Recipient received LP");
    }

    /* ---------------------------------------------------------------------- */
    /*                       Pool Reserve Impact Tests                        */
    /* ---------------------------------------------------------------------- */

    function test_Route2ZapIn_reserveImpact_balanced() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);
        (ERC20PermitMintableStub tokenA,) = _getTokens(PoolConfig.Balanced);

        uint256 amountIn = TEST_AMOUNT;
        address recipient = makeAddr("recipient");

        tokenA.mint(address(this), amountIn);
        tokenA.approve(address(vault), amountIn);

        (uint256 reserve0Before, uint256 reserve1Before,) = pool.getReserves();

        vault.exchangeIn(IERC20(address(tokenA)), amountIn, IERC20(address(pool)), 0, recipient, false, _deadline());

        (uint256 reserve0After, uint256 reserve1After,) = pool.getReserves();

        // For a ZapIn with a single input token:
        // - Input token reserve should increase (net deposit)
        // - Both reserves should generally increase or stay the same
        assertTrue(reserve0After >= reserve0Before, "Reserve 0 should not decrease");
        assertTrue(reserve1After > reserve1Before, "Reserve 1 should increase (input token)");
    }

    /* ---------------------------------------------------------------------- */
    /*                             Fuzz Tests                                 */
    /* ---------------------------------------------------------------------- */

    function testFuzz_Route2ZapIn_balanced_tokenA(uint256 amountIn) public {
        _testFuzz_zapIn_balanced(true, amountIn);
    }

    function testFuzz_Route2ZapIn_balanced_tokenB(uint256 amountIn) public {
        _testFuzz_zapIn_balanced(false, amountIn);
    }

    function testFuzz_Route2ZapIn_unbalanced_tokenA(uint256 amountIn) public {
        _testFuzz_zapIn_unbalanced(true, amountIn);
    }

    function testFuzz_Route2ZapIn_extreme_tokenA(uint256 amountIn) public {
        _testFuzz_zapIn_extreme(true, amountIn);
    }

    function _testFuzz_zapIn_balanced(bool useTokenA, uint256 amountIn) internal {
        amountIn = _boundZapAmount(aeroBalancedPool, useTokenA ? aeroBalancedTokenA : aeroBalancedTokenB, amountIn);
        _executeFuzzZapIn(PoolConfig.Balanced, aeroBalancedTokenA, aeroBalancedTokenB, useTokenA, amountIn);
    }

    function _testFuzz_zapIn_unbalanced(bool useTokenA, uint256 amountIn) internal {
        amountIn =
            _boundZapAmount(aeroUnbalancedPool, useTokenA ? aeroUnbalancedTokenA : aeroUnbalancedTokenB, amountIn);
        _executeFuzzZapIn(PoolConfig.Unbalanced, aeroUnbalancedTokenA, aeroUnbalancedTokenB, useTokenA, amountIn);
    }

    function _testFuzz_zapIn_extreme(bool useTokenA, uint256 amountIn) internal {
        amountIn =
            _boundZapAmount(aeroExtremeUnbalancedPool, useTokenA ? aeroExtremeTokenA : aeroExtremeTokenB, amountIn);
        _executeFuzzZapIn(PoolConfig.Extreme, aeroExtremeTokenA, aeroExtremeTokenB, useTokenA, amountIn);
    }

    function _boundZapAmount(IPool pool, ERC20PermitMintableStub tokenIn, uint256 amountIn)
        internal
        view
        returns (uint256)
    {
        (uint256 reserve0, uint256 reserve1,) = pool.getReserves();
        uint256 reserveIn = address(tokenIn) == pool.token0() ? reserve0 : reserve1;
        // Limit to 10% of reserve to avoid excessive slippage
        return bound(amountIn, MIN_TEST_AMOUNT, reserveIn / 10);
    }

    function _executeFuzzZapIn(
        PoolConfig config,
        ERC20PermitMintableStub tokenA,
        ERC20PermitMintableStub tokenB,
        bool useTokenA,
        uint256 amountIn
    ) internal {
        IStandardExchangeProxy vault = _getVault(config);
        IPool pool = _getPool(config);

        ERC20PermitMintableStub tokenInStub = useTokenA ? tokenA : tokenB;
        IERC20 lpToken = IERC20(address(pool));
        address recipient = makeAddr("recipient");

        tokenInStub.mint(address(this), amountIn);
        tokenInStub.approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(IERC20(address(tokenInStub)), amountIn, lpToken);
        uint256 lpOut =
            vault.exchangeIn(IERC20(address(tokenInStub)), amountIn, lpToken, 0, recipient, false, _deadline());

        assertEq(lpOut, preview, "Fuzz: execution should match preview");
        assertEq(lpToken.balanceOf(recipient), lpOut, "Fuzz: recipient balance correct");
    }
}
