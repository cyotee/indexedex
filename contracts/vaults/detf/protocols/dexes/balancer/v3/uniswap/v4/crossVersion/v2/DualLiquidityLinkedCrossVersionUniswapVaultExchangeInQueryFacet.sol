// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    DualLiquidityLinkedCrossVersionUniswapVaultExchangeInQueryTarget
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVaultExchangeInQueryTarget.sol";

/// @title DualLiquidityLinkedCrossVersionUniswapVaultExchangeInQueryFacet
/// @notice Diamond facet exposing `previewExchangeIn` for the deposit routes.
contract DualLiquidityLinkedCrossVersionUniswapVaultExchangeInQueryFacet is DualLiquidityLinkedCrossVersionUniswapVaultExchangeInQueryTarget, IFacet {
    /// @inheritdoc IFacet
    function facetName() external pure returns (string memory) {
        return "DualLiquidityLinkedCrossVersionUniswapVaultExchangeInQueryFacet";
    }

    /// @inheritdoc IFacet
    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
    }

    /// @inheritdoc IFacet
    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](1);
        funcs_[0] = IStandardExchangeIn.previewExchangeIn.selector;
    }

    /// @inheritdoc IFacet
    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory funcs_)
    {
        name_ = "DualLiquidityLinkedCrossVersionUniswapVaultExchangeInQueryFacet";
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
        funcs_ = new bytes4[](1);
        funcs_[0] = IStandardExchangeIn.previewExchangeIn.selector;
    }
}
