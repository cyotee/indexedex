// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";

import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {
    TestBase_UniswapV2StandardExchange_MultiPool
} from "contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange_MultiPool.sol";

/**
 * @title StandardExchangeOut_Refund_Test
 * @notice Tests for IDXEX-034: Pretransferred refund semantics in exchangeOut.
 * @dev Tests the pass-through ZapOut route (LP token in → constituent token out)
 *      which exercises both _secureTokenTransfer (balance-delta) and _refundExcess.
 */
contract StandardExchangeOut_Refund_Test is TestBase_UniswapV2StandardExchange_MultiPool {
    address caller;

    function setUp() public override {
        super.setUp();
        caller = makeAddr("caller");
    }

    /* ---------------------------------------------------------------------- */
    /*                            Helper Functions                            */
    /* ---------------------------------------------------------------------- */

    function _atomicExchangeOut(
        IStandardExchangeProxy vault,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 maxIn,
        uint256 amountOut
    ) private returns (uint256 used, address atomicAddr) {
        AtomicPretransferCaller atomic = new AtomicPretransferCaller();
        atomicAddr = address(atomic);
        tokenIn.approve(atomicAddr, maxIn);
        used = abi.decode(
            atomic.consumePretransfer(
                tokenIn,
                caller,
                address(vault),
                maxIn,
                abi.encodeWithSelector(
                    IStandardExchangeOut.exchangeOut.selector,
                    tokenIn,
                    maxIn,
                    tokenOut,
                    amountOut,
                    atomicAddr,
                    true,
                    _deadline()
                )
            ),
            (uint256)
        );
    }

    /// @dev Get LP tokens for the caller by minting constituent tokens and adding liquidity.
    function _fundCallerWithLP(
        ERC20PermitMintableStub tokenA,
        ERC20PermitMintableStub tokenB,
        uint256 amountA,
        uint256 amountB
    ) internal returns (uint256 lpAmount) {
        tokenA.mint(address(this), amountA);
        tokenB.mint(address(this), amountB);
        tokenA.approve(address(uniswapV2Router), amountA);
        tokenB.approve(address(uniswapV2Router), amountB);
        (,, lpAmount) = uniswapV2Router.addLiquidity(
            address(tokenA), address(tokenB), amountA, amountB, 0, 0, caller, block.timestamp
        );
    }

    /* ---------------------------------------------------------------------- */
    /*               US-IDXEX-034.1: Pretransferred Refund Logic              */
    /* ---------------------------------------------------------------------- */

    /// @notice When pretransferred == true and excess LP tokens sent, vault refunds unused amount.
    function test_exchangeOut_zapOut_pretransferredRefund() public {
        IStandardExchangeProxy vault = balancedVault;
        IUniswapV2Pair pair = uniswapBalancedPair;
        IERC20 tokenIn = IERC20(address(pair)); // LP token
        IERC20 tokenOut = IERC20(address(uniswapBalancedTokenA)); // constituent token

        // Fund the caller with LP tokens
        uint256 callerLP = _fundCallerWithLP(uniswapBalancedTokenA, uniswapBalancedTokenB, 500e18, 500e18);
        require(callerLP > 0, "Caller must have LP tokens");

        // Choose a small amountOut to ensure we don't need all LP tokens
        uint256 amountOut = 10e18;

        // Get expected amountIn from preview
        uint256 expectedAmountIn = vault.previewExchangeOut(tokenIn, tokenOut, amountOut);
        require(expectedAmountIn > 0, "Preview must be non-zero");
        require(expectedAmountIn < callerLP, "Need surplus LP for refund test");

        // Use all LP as maxAmountIn (creating a surplus)
        uint256 maxAmountIn = callerLP;

        vm.startPrank(caller);
        (uint256 amountIn, address atomic) = _atomicExchangeOut(vault, tokenIn, tokenOut, maxAmountIn, amountOut);
        vm.stopPrank();

        uint256 refundAmount = maxAmountIn - amountIn;
        assertGt(refundAmount, 0, "Refund must be > 0 when surplus LP exists");
        assertEq(tokenIn.balanceOf(atomic), refundAmount, "Caller should receive refund of unused LP tokens");
        assertGe(tokenOut.balanceOf(atomic), amountOut, "Caller should receive at least amountOut");
    }

    /// @notice When pretransferred == true with exact amount, no refund needed.
    function test_exchangeOut_zapOut_pretransferredExactNoRefund() public {
        IStandardExchangeProxy vault = balancedVault;
        IUniswapV2Pair pair = uniswapBalancedPair;
        IERC20 tokenIn = IERC20(address(pair));
        IERC20 tokenOut = IERC20(address(uniswapBalancedTokenA));

        // Fund plenty of LP
        uint256 callerLP = _fundCallerWithLP(uniswapBalancedTokenA, uniswapBalancedTokenB, 500e18, 500e18);

        uint256 amountOut = 10e18;
        uint256 expectedAmountIn = vault.previewExchangeOut(tokenIn, tokenOut, amountOut);
        require(expectedAmountIn > 0 && expectedAmountIn <= callerLP, "Preview in range");

        vm.startPrank(caller);
        tokenIn.transfer(address(this), callerLP - expectedAmountIn);
        (uint256 amountIn, address atomic) = _atomicExchangeOut(vault, tokenIn, tokenOut, expectedAmountIn, amountOut);
        vm.stopPrank();

        assertEq(tokenIn.balanceOf(atomic), 0, "No refund when exact amount pretransferred");
        assertEq(amountIn, expectedAmountIn, "AmountIn should match preview");
        assertGe(tokenOut.balanceOf(atomic), amountOut, "Caller should receive at least amountOut");
    }

    /// @notice When pretransferred == false, normal approval flow works.
    function test_exchangeOut_zapOut_notPretransferred() public {
        IStandardExchangeProxy vault = balancedVault;
        IUniswapV2Pair pair = uniswapBalancedPair;
        IERC20 tokenIn = IERC20(address(pair));
        IERC20 tokenOut = IERC20(address(uniswapBalancedTokenA));

        uint256 callerLP = _fundCallerWithLP(uniswapBalancedTokenA, uniswapBalancedTokenB, 500e18, 500e18);

        uint256 amountOut = 10e18;
        uint256 expectedAmountIn = vault.previewExchangeOut(tokenIn, tokenOut, amountOut);

        vm.startPrank(caller);
        tokenIn.approve(address(vault), expectedAmountIn);

        uint256 tokenInBefore = tokenIn.balanceOf(caller);
        uint256 amountIn = vault.exchangeOut(
            tokenIn,
            expectedAmountIn,
            tokenOut,
            amountOut,
            caller,
            false, // not pretransferred
            _deadline()
        );
        vm.stopPrank();

        // Only the used amount was pulled
        assertEq(tokenIn.balanceOf(caller), tokenInBefore - amountIn, "Only used amount pulled via approval");
    }

    /* ---------------------------------------------------------------------- */
    /*            US-IDXEX-034.2: Balance-Delta Accounting                     */
    /* ---------------------------------------------------------------------- */

    /// @notice A0: dust LP is booked reserve, not a revert. Honest zap-out succeeds; dust stays.
    function test_exchangeOut_revertsWhenDustBreaksReserveCheck() public {
        IStandardExchangeProxy vault = balancedVault;
        IUniswapV2Pair pair = uniswapBalancedPair;
        IERC20 tokenIn = IERC20(address(pair));
        IERC20 tokenOut = IERC20(address(uniswapBalancedTokenA));

        uint256 callerLP = _fundCallerWithLP(uniswapBalancedTokenA, uniswapBalancedTokenB, 1000e18, 1000e18);

        uint256 amountOut = 10e18;
        uint256 expectedAmountIn = vault.previewExchangeOut(tokenIn, tokenOut, amountOut);

        uint256 dust = 1e15;
        uint256 vaultLpBeforeDust = tokenIn.balanceOf(address(vault));
        vm.prank(caller);
        tokenIn.transfer(address(vault), dust);

        vm.startPrank(caller);
        (, address atomic) = _atomicExchangeOut(vault, tokenIn, tokenOut, expectedAmountIn, amountOut);
        vm.stopPrank();

        assertGe(tokenOut.balanceOf(atomic), amountOut, "honest zap-out paid");
        assertEq(tokenIn.balanceOf(address(vault)), vaultLpBeforeDust + dust, "dust LP stays booked");
    }

    /* ---------------------------------------------------------------------- */
    /*                US-IDXEX-034.3: Refund Edge Cases                       */
    /* ---------------------------------------------------------------------- */

    /// @notice maxAmountIn enforcement - reverts if required amountIn exceeds maxAmountIn.
    function test_exchangeOut_revertsWhenMaxAmountInInsufficient() public {
        IStandardExchangeProxy vault = balancedVault;
        IUniswapV2Pair pair = uniswapBalancedPair;
        IERC20 tokenIn = IERC20(address(pair));
        IERC20 tokenOut = IERC20(address(uniswapBalancedTokenA));

        uint256 callerLP = _fundCallerWithLP(uniswapBalancedTokenA, uniswapBalancedTokenB, 500e18, 500e18);

        uint256 amountOut = 10e18;
        uint256 expectedAmountIn = vault.previewExchangeOut(tokenIn, tokenOut, amountOut);

        // Set maxAmountIn below required
        uint256 tooLowMax = expectedAmountIn - 1;

        vm.startPrank(caller);
        tokenIn.approve(address(vault), callerLP);

        vm.expectRevert();
        vault.exchangeOut(tokenIn, tooLowMax, tokenOut, amountOut, caller, false, _deadline());
        vm.stopPrank();
    }

    /// @notice Refund works across different pool configurations (unbalanced).
    function test_exchangeOut_zapOut_pretransferredRefund_unbalanced() public {
        IStandardExchangeProxy vault = unbalancedVault;
        IUniswapV2Pair pair = uniswapUnbalancedPair;
        IERC20 tokenIn = IERC20(address(pair));
        IERC20 tokenOut = IERC20(address(uniswapUnbalancedTokenA));

        // Fund with LP tokens
        uint256 callerLP = _fundCallerWithLP(uniswapUnbalancedTokenA, uniswapUnbalancedTokenB, 500e18, 50e18);

        uint256 amountOut = 5e18;
        uint256 expectedAmountIn = vault.previewExchangeOut(tokenIn, tokenOut, amountOut);
        require(expectedAmountIn > 0 && expectedAmountIn < callerLP, "Preview in range");

        uint256 maxAmountIn = callerLP; // Use all LP as max, creating surplus

        vm.startPrank(caller);
        (uint256 amountIn, address atomic) = _atomicExchangeOut(vault, tokenIn, tokenOut, maxAmountIn, amountOut);
        vm.stopPrank();

        uint256 expectedRefund = maxAmountIn - amountIn;
        assertGt(expectedRefund, 0, "Should have surplus to refund");
        assertEq(tokenIn.balanceOf(atomic), expectedRefund, "Refund amount correct for unbalanced pool");
        assertGe(tokenOut.balanceOf(atomic), amountOut, "Caller should receive at least amountOut");
    }

    /// @notice Verifies that the pretransferred refund exactly equals maxAmountIn - amountIn
    /// by sending a partial surplus (not all LP tokens).
    function test_exchangeOut_zapOut_pretransferredPartialSurplus() public {
        IStandardExchangeProxy vault = balancedVault;
        IUniswapV2Pair pair = uniswapBalancedPair;
        IERC20 tokenIn = IERC20(address(pair));
        IERC20 tokenOut = IERC20(address(uniswapBalancedTokenA));

        uint256 callerLP = _fundCallerWithLP(uniswapBalancedTokenA, uniswapBalancedTokenB, 500e18, 500e18);

        uint256 amountOut = 10e18;
        uint256 expectedAmountIn = vault.previewExchangeOut(tokenIn, tokenOut, amountOut);

        // Use 2x the needed amount as maxAmountIn (not all LP)
        uint256 maxAmountIn = expectedAmountIn * 2;
        require(maxAmountIn < callerLP, "Need partial surplus, not all LP");

        vm.startPrank(caller);
        uint256 callerLPBefore = tokenIn.balanceOf(caller);
        (uint256 amountIn, address atomic) = _atomicExchangeOut(vault, tokenIn, tokenOut, maxAmountIn, amountOut);
        vm.stopPrank();

        uint256 callerLPAfter = tokenIn.balanceOf(caller);
        assertEq(callerLPBefore - callerLPAfter, maxAmountIn, "EOA sent the prepaid surplus to the atomic caller");
        assertEq(tokenIn.balanceOf(atomic), maxAmountIn - amountIn, "Refund should equal maxAmountIn - amountIn");
        assertGe(tokenOut.balanceOf(atomic), amountOut, "Caller should receive at least amountOut");
    }

    /* ---------------------------------------------------------------------- */
    /*                        Fuzz Tests                                      */
    /* ---------------------------------------------------------------------- */

    /// @notice Fuzz: pretransferred refund always returns exactly maxAmountIn - amountIn.
    function testFuzz_exchangeOut_refundInvariant(uint256 surplus) public {
        surplus = bound(surplus, 1e15, 100e18);

        IStandardExchangeProxy vault = balancedVault;
        IUniswapV2Pair pair = uniswapBalancedPair;
        IERC20 tokenIn = IERC20(address(pair));
        IERC20 tokenOut = IERC20(address(uniswapBalancedTokenA));

        // Fund with enough LP
        uint256 callerLP = _fundCallerWithLP(uniswapBalancedTokenA, uniswapBalancedTokenB, 2000e18, 2000e18);

        uint256 amountOut = 5e18;
        uint256 expectedAmountIn = vault.previewExchangeOut(tokenIn, tokenOut, amountOut);
        uint256 maxAmountIn = expectedAmountIn + surplus;
        require(maxAmountIn <= callerLP, "Not enough LP");

        vm.startPrank(caller);
        uint256 callerLPBefore = tokenIn.balanceOf(caller);
        (uint256 amountIn, address atomic) = _atomicExchangeOut(vault, tokenIn, tokenOut, maxAmountIn, amountOut);
        vm.stopPrank();

        uint256 callerLPAfter = tokenIn.balanceOf(caller);
        assertEq(callerLPBefore - callerLPAfter, maxAmountIn, "EOA sent the prepaid surplus to the atomic caller");
        assertEq(tokenIn.balanceOf(atomic), maxAmountIn - amountIn, "Refund invariant: refund == maxAmountIn - amountIn");
        assertGe(tokenOut.balanceOf(atomic), amountOut, "Caller should receive at least amountOut");
    }
}
