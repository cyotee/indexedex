// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutTarget
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutTarget.sol";

/// @title DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutFacet
/// @notice Diamond facet exposing the exact-out `exchangeOut` route surface.
contract DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutFacet is DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutTarget, IFacet {
    /// @inheritdoc IFacet
    function facetName() external pure returns (string memory) {
        return "DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutFacet";
    }

    /// @inheritdoc IFacet
    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IStandardExchangeOut).interfaceId;
    }

    /// @inheritdoc IFacet
    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](1);
        funcs_[0] = IStandardExchangeOut.exchangeOut.selector;
    }

    /// @inheritdoc IFacet
    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory funcs_)
    {
        name_ = "DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutFacet";
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IStandardExchangeOut).interfaceId;
        funcs_ = new bytes4[](1);
        funcs_[0] = IStandardExchangeOut.exchangeOut.selector;
    }
}
