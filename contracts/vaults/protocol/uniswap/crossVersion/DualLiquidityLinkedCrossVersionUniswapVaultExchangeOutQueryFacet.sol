// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutQueryTarget
} from "contracts/vaults/protocol/uniswap/crossVersion/DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutQueryTarget.sol";

/// @title DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutQueryFacet
/// @notice Diamond facet exposing `previewExchangeOut` for the exact-out routes.
contract DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutQueryFacet is DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutQueryTarget, IFacet {
    /// @inheritdoc IFacet
    function facetName() external pure returns (string memory) {
        return "DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutQueryFacet";
    }

    /// @inheritdoc IFacet
    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IStandardExchangeOut).interfaceId;
    }

    /// @inheritdoc IFacet
    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](1);
        funcs_[0] = IStandardExchangeOut.previewExchangeOut.selector;
    }

    /// @inheritdoc IFacet
    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory funcs_)
    {
        name_ = "DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutQueryFacet";
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IStandardExchangeOut).interfaceId;
        funcs_ = new bytes4[](1);
        funcs_[0] = IStandardExchangeOut.previewExchangeOut.selector;
    }
}
