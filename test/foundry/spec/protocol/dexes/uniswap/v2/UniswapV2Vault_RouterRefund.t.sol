// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_UniswapV2StandardExchange_MultiPool
} from "contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange_MultiPool.sol";

/**
 * @title UniswapV2Vault_RouterRefund_Test
 * @notice Tests for reproducing FailedInnerCall error when Balancer V3 router
 *         calls Uniswap V2 vault's exchangeOut with pretransferred=true.
 * @dev This test specifically targets the refund mechanism where:
 *      1. Router calls vault.exchangeOut with pretransferred=true
 *      2. Vault executes swap and transfers output to router (recipient)
 *      3. Vault calls _refundExcess to refund excess tokenIn to msg.sender (router)
 *      4. If router is a contract that can't receive tokens, this could fail
 *
 * THE ROOT CAUSE OF FailedInnerCall:
 * ================================
 * The error likely originates from BalancerV3StandardExchangeRouterExactOutSwapTarget.sol:243
 * where the router calls `payable(params.sender).sendValue(amountCalculated)` after unwrapping
 * WETH to ETH. If params.sender is a contract without a receive() function, this low-level
 * call will fail with FailedInnerCall (OpenZeppelin's Address library error).
 *
 * To reproduce the exact error:
 * 1. Set up Balancer V3 router with Uniswap V2 vault
 * 2. Call router.swapSingleTokenExactOut with wethIsEth=true and tokenOut=WETH
 * 3. Set params.sender to a contract without receive() function
 * 4. The sendValue call will fail with FailedInnerCall
 */
contract UniswapV2Vault_RouterRefund_Test is TestBase_UniswapV2StandardExchange_MultiPool {
    /* ---------------------------------------------------------------------- */
    /*                       Test: Pass-Through Swap via Router                */
    /* ---------------------------------------------------------------------- */

    /// @notice Test that vault.exchangeOut works when called with pretransferred=true
    ///         This simulates what happens when Balancer V3 router calls the vault
    function test_exchangeOut_withPretransferred_true() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        
        ERC20PermitMintableStub token0 = ERC20PermitMintableStub(pair.token0());
        ERC20PermitMintableStub token1 = ERC20PermitMintableStub(pair.token1());
        
        // Use token0 as input, token1 as output
        IERC20 tokenIn = IERC20(address(token0));
        IERC20 tokenOut = IERC20(address(token1));
        
        uint256 amountOut = 1e18;
        address recipient = makeAddr("recipient");
        
        // Get expected amountIn from preview
        uint256 expectedAmountIn = vault.previewExchangeOut(tokenIn, tokenOut, amountOut);
        assertGt(expectedAmountIn, 0, "Preview must return non-zero amountIn");
        
        // Mint tokens to this contract (simulating router has the tokens)
        token0.mint(address(this), expectedAmountIn);
        
        // Transfer tokens to the vault first (this is what the router does)
        // The router transfers tokens to the vault BEFORE calling exchangeOut
        token0.transfer(address(vault), expectedAmountIn);
        
        // Call exchangeOut with pretransferred=true
        // This is what the Balancer V3 router does
        uint256 actualAmountIn = vault.exchangeOut(
            tokenIn,
            expectedAmountIn,  // maxAmountIn
            tokenOut,
            amountOut,
            recipient,  // direct to recipient
            true,       // pretransferred=true - tokens already in vault
            _deadline()
        );
        
        assertEq(actualAmountIn, expectedAmountIn, "AmountIn must match");
        assertGe(token1.balanceOf(recipient), amountOut, "Recipient must receive amountOut");
    }

    /// @notice Test that vault.exchangeOut works when recipient is a contract
    ///         that cannot receive tokens (simulating router behavior)
    function test_exchangeOut_withContractRecipient() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        
        ERC20PermitMintableStub token0 = ERC20PermitMintableStub(pair.token0());
        ERC20PermitMintableStub token1 = ERC20PermitMintableStub(pair.token1());
        
        // Use token0 as input, token1 as output
        IERC20 tokenIn = IERC20(address(token0));
        IERC20 tokenOut = IERC20(address(token1));
        
        uint256 amountOut = 1e18;
        
        // Create a contract that cannot receive tokens as recipient
        address contractRecipient = address(new NonReceivingContract());
        
        // Get expected amountIn from preview
        uint256 expectedAmountIn = vault.previewExchangeOut(tokenIn, tokenOut, amountOut);
        assertGt(expectedAmountIn, 0, "Preview must return non-zero amountIn");
        
        // Mint tokens to this contract and transfer to vault first
        token0.mint(address(this), expectedAmountIn);
        token0.transfer(address(vault), expectedAmountIn);
        
        // This should work because the vault transfers tokenOut (not tokenIn) to recipient
        // The refund of excess tokenIn goes to msg.sender (this contract), not recipient
        uint256 actualAmountIn = vault.exchangeOut(
            tokenIn,
            expectedAmountIn,
            tokenOut,
            amountOut,
            contractRecipient,  // contract that can't receive
            true,              // pretransferred=true
            _deadline()
        );
        
        assertEq(actualAmountIn, expectedAmountIn, "AmountIn must match");
    }

    /// @notice Test refund mechanism when excess tokens are returned
    function test_exchangeOut_refundExcess() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        
        ERC20PermitMintableStub token0 = ERC20PermitMintableStub(pair.token0());
        ERC20PermitMintableStub token1 = ERC20PermitMintableStub(pair.token1());
        
        IERC20 tokenIn = IERC20(address(token0));
        IERC20 tokenOut = IERC20(address(token1));
        
        uint256 amountOut = 1e18;
        address recipient = makeAddr("recipient");
        
        // Get expected amountIn from preview
        uint256 expectedAmountIn = vault.previewExchangeOut(tokenIn, tokenOut, amountOut);
        
        // Mint MORE than needed (simulating what happens when maxAmountIn > actual needed)
        uint256 excessAmount = expectedAmountIn + 1e17; // 10% excess
        token0.mint(address(this), excessAmount);
        
        // Transfer excess to vault first (this is what router does)
        token0.transfer(address(vault), excessAmount);
        
        // Call with maxAmountIn > actual needed - this triggers refund
        uint256 actualAmountIn = vault.exchangeOut(
            tokenIn,
            excessAmount,      // maxAmountIn > actual needed
            tokenOut,
            amountOut,
            recipient,
            true,              // pretransferred=true
            _deadline()
        );
        
        // The vault should refund the excess back to msg.sender
        assertEq(actualAmountIn, expectedAmountIn, "AmountIn should be actual needed");
        assertGe(token0.balanceOf(address(this)), excessAmount - expectedAmountIn, "Should receive refund");
    }
}

/**
 * @title NonReceivingContract
 * @notice A contract that cannot receive ERC20 tokens or ETH
 * @dev This simulates a user that would cause FailedInnerCall when router tries to send ETH
 */
contract NonReceivingContract {
    // Does not implement receive() or any token receive functions
    // Any ETH transfer to this contract will revert
}
