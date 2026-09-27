// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_RocketPoolRETHStandardExchange} from
    "contracts/test/bases/TestBase_RocketPoolRETHStandardExchange.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {TransitionQuoteAssertions} from "test/foundry/spec/vaults/standard/TransitionQuoteAssertions.sol";

/// @notice APEX matrix finding F4 (2026-09-21): the Rocket SE transition quote reads the deposit pool's
///         `version()` and `getBalance()`, the minipool queue's `getEffectiveCapacity()`, the deposit
///         settings' assign / size / fee / enabled views and two `RocketStorage.getUint` keys through hard
///         staticcalls (`_rpWord`, `_rpSnapshotProtocol`). The hermetic ports now expose them (D46 fixtures
///         on the underlying stubs, not the SUT; the registry self-registers an empty minipool queue), so
///         `quoteState(weth, holder)` answers hermetically and the orbital hook previews can run.
contract RocketPoolRETHStandardExchange_TransitionQuote is TestBase_RocketPoolRETHStandardExchange, TransitionQuoteAssertions {
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
