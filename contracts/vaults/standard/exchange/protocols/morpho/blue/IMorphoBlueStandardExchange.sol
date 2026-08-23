// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IMorpho, Id, MarketParams} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";

/**
 * @title IMorphoBlueStandardExchange
 * @notice Marker for a lend-only Morpho Blue Standard Exchange. Interface id is the LENDING fee type key.
 * @dev No `rebalance()`. One `MarketParams` per vault. `asset()` / `loanToken()` is the market loan token.
 */
interface IMorphoBlueStandardExchange {
    /// @param requested loanToken amount required to pay
    /// @param available idle + Morpho free cash usable by this vault
    error InsufficientLiquidity(uint256 requested, uint256 available);

    error MarketNotCreated(Id id);
    error ZeroMorpho();
    error ZeroLoanToken();
    error ZeroOracle();
    error ZeroIrm();

    function morpho() external view returns (IMorpho);

    function marketParams() external view returns (MarketParams memory);

    function marketId() external view returns (Id);

    function loanToken() external view returns (address);
}
