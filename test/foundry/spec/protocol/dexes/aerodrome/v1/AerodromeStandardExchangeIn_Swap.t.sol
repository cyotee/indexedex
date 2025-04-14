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
 * @title AerodromeStandardExchangeIn_Swap_Test
 * @notice Tests for Route 1: Pass-through token-to-token swaps.
 * @dev Route 1 handles swaps between the two tokens in the underlying Aerodrome pool.
 *      Both tokenIn and tokenOut must be constituents of the pool.
 */
contract AerodromeStandardExchangeIn_Swap_Test is TestBase_AerodromeStandardExchange_MultiPool {
    function _setHeldExcessTokens(address vault, uint256 excess0, uint256 excess1) internal {
        bytes32 slot = keccak256(abi.encode("indexedex.protocols.dexes.aerodrome.v1.standardexchange"));
        vm.store(vault, slot, bytes32(excess0));
        vm.store(vault, bytes32(uint256(slot) + 1), bytes32(excess1));
    }

    /* ---------------------------------------------------------------------- */
    /*                          Preview vs Math Tests                         */
    /* ---------------------------------------------------------------------- */

    function test_Route1Swap_previewVsMath_balanced_AtoB() public view {
        _test_previewVsMath(PoolConfig.Balanced, true);
    }

    function test_Route1Swap_previewVsMath_balanced_BtoA() public view {
        _test_previewVsMath(PoolConfig.Balanced, false);
    }

    function test_Route1Swap_previewVsMath_unbalanced_AtoB() public view {
        _test_previewVsMath(PoolConfig.Unbalanced, true);
    }

    function test_Route1Swap_previewVsMath_unbalanced_BtoA() public view {
        _test_previewVsMath(PoolConfig.Unbalanced, false);
    }

    function test_Route1Swap_previewVsMath_extreme_AtoB() public view {
        _test_previewVsMath(PoolConfig.Extreme, true);
    }

    function test_Route1Swap_previewVsMath_extreme_BtoA() public view {
        _test_previewVsMath(PoolConfig.Extreme, false);
    }

    function _test_previewVsMath(PoolConfig config, bool aToB) internal view {
        IStandardExchangeProxy vault = _getVault(config);
        IPool pool = _getPool(config);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(config);

        IERC20 tokenIn = aToB ? IERC20(address(tokenA)) : IERC20(address(tokenB));
        IERC20 tokenOut = aToB ? IERC20(address(tokenB)) : IERC20(address(tokenA));

        uint256 amountIn = TEST_AMOUNT;

        // Get expected from pool directly
        uint256 expectedFromPool = pool.getAmountOut(amountIn, address(tokenIn));

        // Get preview from vault
        uint256 preview = vault.previewExchangeIn(tokenIn, amountIn, tokenOut);

        assertEq(preview, expectedFromPool, "Preview should match pool.getAmountOut()");
    }

    /* ---------------------------------------------------------------------- */
    /*                       Execution vs Preview Tests                       */
    /* ---------------------------------------------------------------------- */

    function test_Route1Swap_execVsPreview_balanced_AtoB() public {
        _test_execVsPreview(PoolConfig.Balanced, true);
    }

    function test_Route1Swap_execVsPreview_balanced_BtoA() public {
        _test_execVsPreview(PoolConfig.Balanced, false);
    }

    function test_Route1Swap_execVsPreview_unbalanced_AtoB() public {
        _test_execVsPreview(PoolConfig.Unbalanced, true);
    }

    function test_Route1Swap_execVsPreview_unbalanced_BtoA() public {
        _test_execVsPreview(PoolConfig.Unbalanced, false);
    }

    function test_Route1Swap_execVsPreview_extreme_AtoB() public {
        _test_execVsPreview(PoolConfig.Extreme, true);
    }

    function test_Route1Swap_execVsPreview_extreme_BtoA() public {
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

        // Execute
        uint256 amountOut = vault.exchangeIn(
            tokenIn,
            amountIn,
            tokenOut,
            0, // minAmountOut
            recipient,
            false, // pretransferred
            _deadline()
        );

        assertEq(amountOut, preview, "Execution should match preview");
        assertEq(tokenOut.balanceOf(recipient), preview, "Recipient should receive preview amount");
    }

    /* ---------------------------------------------------------------------- */
    /*                         Balance Change Tests                           */
    /* ---------------------------------------------------------------------- */

    function test_Route1Swap_balanceChanges_balanced_AtoB() public {
        _test_balanceChanges(PoolConfig.Balanced, true);
    }

    function test_Route1Swap_balanceChanges_balanced_BtoA() public {
        _test_balanceChanges(PoolConfig.Balanced, false);
    }

    function test_Route1Swap_balanceChanges_unbalanced_AtoB() public {
        _test_balanceChanges(PoolConfig.Unbalanced, true);
    }

    function test_Route1Swap_balanceChanges_extreme_AtoB() public {
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
            "Sender tokenIn balance should decrease by amountIn"
        );
        assertEq(
            tokenOut.balanceOf(recipient),
            recipientBalanceBefore + amountOut,
            "Recipient tokenOut balance should increase by amountOut"
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                        Slippage Protection Tests                       */
    /* ---------------------------------------------------------------------- */

    function test_Route1Swap_slippageProtection_exactMinimum() public {
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

        assertEq(amountOut, preview, "Should succeed with exact minimum");
    }

    function test_Route1Swap_slippageProtection_reverts_whenMinimumTooHigh() public {
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

    function test_Route1Swap_pretransferred_true() public {
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
        assertEq(tokenA.balanceOf(address(this)), senderBalanceBefore, "No additional transfer from sender");
        assertTrue(tokenB.balanceOf(recipient) > 0, "Recipient received tokens");
    }

    function test_Route1Swap_pretransferred_true_reverts_whenOnlyReservedDust() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);

        uint256 amountIn = 777;
        address recipient = makeAddr("recipient");

        // Simulate that the vault intentionally holds dust from fee compounding.
        bool tokenInIsToken0 = address(tokenA) == pool.token0();
        _setHeldExcessTokens(address(vault), tokenInIsToken0 ? amountIn : 0, tokenInIsToken0 ? 0 : amountIn);

        // Only transfer the reserved amount to the vault.
        tokenA.mint(address(this), amountIn);
        tokenA.transfer(address(vault), amountIn);

        vm.expectRevert(bytes("BasicVaultCommon: insufficient pretransferred balance"));
        vault.exchangeIn(
            IERC20(address(tokenA)),
            amountIn,
            IERC20(address(tokenB)),
            0,
            recipient,
            true, // pretransferred
            _deadline()
        );
    }

    function test_Route1Swap_pretransferred_true_retainsReservedDust() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);

        uint256 reserved = 555;
        uint256 amountIn = TEST_AMOUNT;
        address recipient = makeAddr("recipient");

        bool tokenInIsToken0 = address(tokenA) == pool.token0();
        _setHeldExcessTokens(address(vault), tokenInIsToken0 ? reserved : 0, tokenInIsToken0 ? 0 : reserved);

        tokenA.mint(address(this), reserved + amountIn);
        tokenA.transfer(address(vault), reserved + amountIn);

        vault.exchangeIn(
            IERC20(address(tokenA)),
            amountIn,
            IERC20(address(tokenB)),
            0,
            recipient,
            true, // pretransferred
            _deadline()
        );

        assertEq(tokenA.balanceOf(address(vault)), reserved, "Vault should retain reserved dust");
    }

    function test_Route1Swap_pretransferred_false() public {
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
        assertEq(tokenA.balanceOf(address(this)), senderBalanceBefore - amountIn, "Tokens transferred from sender");
        assertTrue(tokenB.balanceOf(recipient) > 0, "Recipient received tokens");
    }

    /* ---------------------------------------------------------------------- */
    /*                             Fuzz Tests                                 */
    /* ---------------------------------------------------------------------- */

    function testFuzz_Route1Swap_balanced_AtoB(uint256 amountIn) public {
        _testFuzz_swap_balanced(true, amountIn);
    }

    function testFuzz_Route1Swap_balanced_BtoA(uint256 amountIn) public {
        _testFuzz_swap_balanced(false, amountIn);
    }

    function testFuzz_Route1Swap_unbalanced_AtoB(uint256 amountIn) public {
        _testFuzz_swap_unbalanced(true, amountIn);
    }

    function testFuzz_Route1Swap_extreme_AtoB(uint256 amountIn) public {
        _testFuzz_swap_extreme(true, amountIn);
    }

    function _testFuzz_swap_balanced(bool aToB, uint256 amountIn) internal {
        amountIn = _boundSwapAmount(aeroBalancedPool, aToB ? aeroBalancedTokenA : aeroBalancedTokenB, amountIn);
        _executeFuzzSwap(balancedVault, aeroBalancedTokenA, aeroBalancedTokenB, aToB, amountIn);
    }

    function _testFuzz_swap_unbalanced(bool aToB, uint256 amountIn) internal {
        amountIn = _boundSwapAmount(aeroUnbalancedPool, aToB ? aeroUnbalancedTokenA : aeroUnbalancedTokenB, amountIn);
        _executeFuzzSwap(unbalancedVault, aeroUnbalancedTokenA, aeroUnbalancedTokenB, aToB, amountIn);
    }

    function _testFuzz_swap_extreme(bool aToB, uint256 amountIn) internal {
        amountIn = _boundSwapAmount(aeroExtremeUnbalancedPool, aToB ? aeroExtremeTokenA : aeroExtremeTokenB, amountIn);
        _executeFuzzSwap(extremeVault, aeroExtremeTokenA, aeroExtremeTokenB, aToB, amountIn);
    }

    function _boundSwapAmount(IPool pool, ERC20PermitMintableStub tokenIn, uint256 amountIn)
        internal
        view
        returns (uint256)
    {
        (uint256 reserve0, uint256 reserve1,) = pool.getReserves();
        uint256 reserveIn = address(tokenIn) == pool.token0() ? reserve0 : reserve1;
        return bound(amountIn, MIN_TEST_AMOUNT, reserveIn / 10);
    }

    function _executeFuzzSwap(
        IStandardExchangeProxy vault,
        ERC20PermitMintableStub tokenA,
        ERC20PermitMintableStub tokenB,
        bool aToB,
        uint256 amountIn
    ) internal {
        ERC20PermitMintableStub tokenInStub = aToB ? tokenA : tokenB;
        IERC20 tokenOut = aToB ? IERC20(address(tokenB)) : IERC20(address(tokenA));
        address recipient = makeAddr("recipient");

        tokenInStub.mint(address(this), amountIn);
        tokenInStub.approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(IERC20(address(tokenInStub)), amountIn, tokenOut);
        uint256 amountOut =
            vault.exchangeIn(IERC20(address(tokenInStub)), amountIn, tokenOut, 0, recipient, false, _deadline());

        assertEq(amountOut, preview, "Fuzz: execution should match preview");
        assertEq(tokenOut.balanceOf(recipient), amountOut, "Fuzz: recipient balance correct");
    }
}
