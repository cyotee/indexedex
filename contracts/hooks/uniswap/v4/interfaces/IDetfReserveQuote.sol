// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/**
 * @title IDetfReserveQuote
 * @notice DETF quote views on every Uni V4 SE buffer hook. Hook does not read DETF storage.
 * @dev PRD DETF_INSTANCE_IO_ROUTING H18 / §15.12.
 */
interface IDetfReserveQuote {
    struct DetfQuoteCtx {
        uint256 detfTotalSupply;
        uint256 pendingExpansion;
        uint256 ownedLp;
        uint256 creationPairPerDetfWad;
    }

    function previewSynthetic(DetfQuoteCtx calldata ctx, address numeraire)
        external
        view
        returns (uint256 wad);

    function previewBurnToToken(uint256 lpAmount, address tokenOut)
        external
        view
        returns (uint256 amountOut);
}
