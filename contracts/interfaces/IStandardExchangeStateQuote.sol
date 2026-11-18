// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

// tag::IStandardExchangeStateQuote[]
/// @notice Compose exact-input Standard Exchange previews against one evolving vault/pool state.
/// @dev State is opaque to consumers and belongs to the vault that captured it. It describes
/// hypothetical operations against an unchanged external-liquidity baseline, never authorizes
/// execution, and does not credit a particular holder. Consumers track their own share inventory.
/// Implementing this interface does not change ordinary exchange pricing or LP ownership.
interface IStandardExchangeStateQuote {
    error InvalidQuoteState();

    /// @notice Capture the live state needed to quote successive exact-input operations.
    function quoteExchangeState() external view returns (bytes memory state);

    /// @notice Quote the standard exact-input route and return the resulting hypothetical state.
    /// @dev Output and refund retain the ordinary preview's native units and rounding.
    /// Unsupported or unavailable operations follow the ordinary preview's zero-result behavior.
    /// A refunded, unexecuted candidate must leave the supplied state unchanged.
    function quoteExchangeIn(bytes calldata state, IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external view returns (bytes memory nextState, uint256 amountOut, uint256 amountRefunded);

    /// @notice Return issued share supply at the supplied state, including fee and locked shares.
    function quoteExchangeSupply(bytes calldata state) external view returns (uint256 totalShares);
}
// end::IStandardExchangeStateQuote[]
