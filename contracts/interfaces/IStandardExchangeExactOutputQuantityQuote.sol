// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

// tag::IStandardExchangeExactOutputQuantityQuote[]
/// @notice Optional exact-output quantities at a supplied opaque transition state.
/// @dev The snapshot-selected asset defines the asset face. These queries do not
/// produce a next state or promise holder shares, local cover or funded placement.
interface IStandardExchangeExactOutputQuantityQuote {
    function quoteInputForExactShares(bytes calldata state, uint256 sharesOut)
        external view returns (uint256 assetsIn);

    function quoteSharesForExactAssets(bytes calldata state, uint256 assetsOut)
        external view returns (uint256 sharesIn);
}
// end::IStandardExchangeExactOutputQuantityQuote[]
