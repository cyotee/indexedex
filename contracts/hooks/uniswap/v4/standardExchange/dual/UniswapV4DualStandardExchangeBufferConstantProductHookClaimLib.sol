// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib as BufferClaim}
    from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol";

/// @notice Dual and Single CP use the same sequential buffer claim and fee-dilution model.
library UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib {
    function supportsTransitionQuote(address se, address pairToken, address holder) external view returns (bool) {
        return BufferClaim.supportsTransitionQuote(se, pairToken, holder);
    }

    function previewBufferClaimIn(address se, address pairToken, uint256 amountInRaw,
        IVaultFeeOracleQuery feeOracle, address hook) external view returns (uint256)
    {
        return BufferClaim.previewBufferClaimIn(se, pairToken, amountInRaw, feeOracle, hook);
    }

    function invertBufferClaimIn(address se, address pairToken, uint256 claimInNeeded,
        IVaultFeeOracleQuery feeOracle, address hook) external view returns (uint256)
    {
        return BufferClaim.invertBufferClaimIn(se, pairToken, claimInNeeded, feeOracle, hook);
    }
}
