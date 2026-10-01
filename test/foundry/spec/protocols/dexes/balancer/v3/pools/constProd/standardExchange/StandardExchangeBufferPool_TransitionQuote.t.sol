// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {
    TestBase_StandardExchangeBufferPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";

/**
 * @title StandardExchangeBufferPool_TransitionQuote
 * @notice De-risk gate for the Balancer V3 buffer-pool `IStandardExchangeTransitionQuote`
 *         projection: a `quoteState` + single `quoteTransition` must equal the live
 *         `previewExchangeIn` / `previewExchangeOut` for the same input against the same state,
 *         to the wei (both use `BasePoolMath` over the same pool). Also asserts ERC-165 exposure
 *         (0x185ec0ef) and the `quoteState` selector (0x844c633c) route on the pool diamond.
 */
contract StandardExchangeBufferPool_TransitionQuote is TestBase_StandardExchangeBufferPool {
    IStandardExchangeTransitionQuote internal q;

    function setUp() public virtual override {
        super.setUp();
        q = IStandardExchangeTransitionQuote(bufferPool);
    }

    function test_erc165_and_selector_present() public view {
        assertTrue(
            IERC165(bufferPool).supportsInterface(type(IStandardExchangeTransitionQuote).interfaceId),
            "ERC165 IStandardExchangeTransitionQuote registered"
        );
        assertEq(type(IStandardExchangeTransitionQuote).interfaceId, bytes4(0x185ec0ef), "interfaceId 0x185ec0ef");
        assertEq(IStandardExchangeTransitionQuote.quoteState.selector, bytes4(0x844c633c), "quoteState 0x844c633c");
    }

    /// @dev Give `bob` a small BPT position through the native route so quoteState sees a routable
    ///      holder whose valuation and exit ops stay inside Balancer's minimum invariant ratio.
    function _seedBob(uint256 depositShares) internal returns (uint256 bpt) {
        mintShares(bob, depositShares);
        vm.startPrank(bob);
        IERC20(address(shares)).approve(bufferPool, type(uint256).max);
        bpt = IStandardExchangeIn(bufferPool).exchangeIn(
            IERC20(address(shares)), depositShares, IERC20(bufferPool), 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_quoteState_reverts_on_virtualBufferAsset() public {
        // TTA (DAI) is the virtual buffer token: not a valid quote asset.
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeTransitionQuote.UnsupportedQuoteAsset.selector, address(tta)));
        q.quoteState(address(tta), bob);
    }

    function test_depositExactIn_weiExact() public {
        _seedBob(20e18);
        (bytes memory state,) = q.quoteState(address(shares), bob);
        uint256 amt = 3e18;
        uint256 expected = IStandardExchangeIn(bufferPool).previewExchangeIn(IERC20(address(shares)), amt, IERC20(bufferPool));
        (, uint256 amountIn, uint256 amountOut,) =
            q.quoteTransition(state, IStandardExchangeTransitionQuote.Operation.DepositExactIn, amt);
        assertEq(amountIn, amt, "deposit amountIn == input shares");
        assertGt(expected, 0, "preview deposit nonzero");
        assertEq(amountOut, expected, "DepositExactIn BPT out == previewExchangeIn");
    }

    function test_redeemExactIn_weiExact() public {
        uint256 bpt = _seedBob(20e18);
        (bytes memory state,) = q.quoteState(address(shares), bob);
        uint256 redeem = bpt / 3;
        uint256 expected =
            IStandardExchangeIn(bufferPool).previewExchangeIn(IERC20(bufferPool), redeem, IERC20(address(shares)));
        (, uint256 amountIn, uint256 amountOut,) =
            q.quoteTransition(state, IStandardExchangeTransitionQuote.Operation.RedeemExactIn, redeem);
        assertEq(amountIn, redeem, "redeem amountIn == BPT burned");
        assertGt(expected, 0, "preview redeem nonzero");
        assertEq(amountOut, expected, "RedeemExactIn shares out == previewExchangeIn");
    }

    function test_withdrawExactOut_weiExact() public {
        _seedBob(40e18);
        (bytes memory state,) = q.quoteState(address(shares), bob);
        uint256 wantOut = 2e18;
        uint256 expected =
            IStandardExchangeOut(bufferPool).previewExchangeOut(IERC20(bufferPool), IERC20(address(shares)), wantOut);
        (, uint256 amountIn, uint256 amountOut,) =
            q.quoteTransition(state, IStandardExchangeTransitionQuote.Operation.WithdrawExactOut, wantOut);
        assertEq(amountOut, wantOut, "withdraw amountOut == requested shares");
        assertGt(expected, 0, "preview withdraw nonzero");
        assertEq(amountIn, expected, "WithdrawExactOut BPT in == previewExchangeOut");
    }

    function test_shareViews_matchProjectedState() public {
        uint256 bpt = _seedBob(20e18);
        (bytes memory state,) = q.quoteState(address(shares), bob);
        assertEq(q.quoteShareBalance(state), bpt, "quoteShareBalance == holder BPT");
        assertEq(q.quoteTotalSupply(state), IERC20(bufferPool).totalSupply(), "quoteTotalSupply == BPT supply");
        // ReceiveShares credits holder BPT without changing supply.
        (bytes memory next,,,) = q.quoteTransition(state, IStandardExchangeTransitionQuote.Operation.ReceiveShares, 1e18);
        assertEq(q.quoteShareBalance(next), bpt + 1e18, "ReceiveShares credits holder");
        assertEq(q.quoteTotalSupply(next), IERC20(bufferPool).totalSupply(), "ReceiveShares leaves supply");
    }
}
