// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_EtherFiWeETHStandardExchange} from
    "contracts/test/bases/TestBase_EtherFiWeETHStandardExchange.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {TransitionQuoteAssertions} from "test/foundry/spec/vaults/standard/TransitionQuoteAssertions.sol";

/// @notice APEX matrix finding F4 (2026-09-21): the EtherFi SE transition quote reads `totalShares()` on eETH,
///         `totalValueInLp()` on the liquidity pool and `tokenToRedemptionInfo(address)` on the redemption
///         manager through hard staticcalls (`_efWord`, `_efSnapshotRedemption`). The hermetic ports now
///         expose them (D46 fixtures on the underlying stubs, not the SUT), so `quoteState(weth, holder)`
///         answers hermetically and the orbital hook previews that plan through it can run.
contract EtherFiWeETHStandardExchange_TransitionQuote is TestBase_EtherFiWeETHStandardExchange, TransitionQuoteAssertions {
    function test_F4_quoteState_answersHermetically() public {
        (bytes memory state, uint256 holderAssets) =
            IStandardExchangeTransitionQuote(seVault).quoteState(address(hermeticWeth), address(this));
        assertGt(state.length, 0, "quoteState returns an encoded snapshot");
        assertEq(holderAssets, 0, "no shares held yet");
    }

    function test_F4_depositExactIn_transitionMatchesPreviewAndExecution() public {
        uint256 amount = 10 ether;
        _dealWeth(address(this), amount);
        IStandardExchangeTransitionQuote quote = IStandardExchangeTransitionQuote(seVault);
        (bytes memory state,) = quote.quoteState(address(hermeticWeth), address(this));
        (, uint256 input, uint256 output,) =
            quote.quoteTransition(state, IStandardExchangeTransitionQuote.Operation.DepositExactIn, amount);
        assertEq(input, amount, "exact-in consumes the whole input");
        uint256 preview = seIn.previewExchangeIn(IERC20(address(hermeticWeth)), amount, IERC20(seVault));
        assertEq(output, preview, "transition quote agrees with previewExchangeIn");
        hermeticWeth.approve(seVault, amount);
        uint256 minted = seIn.exchangeIn(
            IERC20(address(hermeticWeth)), amount, IERC20(seVault), output, address(this), false, block.timestamp + 1 hours
        );
        assertEq(minted, output, "execution mints the quoted shares");
    }

    /// @dev Gold sequence shared with the ERC-4626 and Morpho SEs: quote four operations up front, execute
    ///      them, and require every projected state field to match execution.
    function test_F4_quoteSequence_projectsExecution() public {
        _dealWeth(address(this), 1_000 ether);
        _assertQuoteSequence(seVault, IERC20(address(hermeticWeth)), address(this), 1 ether);
    }
}
