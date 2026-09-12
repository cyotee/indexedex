// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

/// @notice Source-only metadata base for the separately deployed universal DETF facets.
/// @dev Full product interfaces are advertised by the package, whose cuts compose their selectors.
abstract contract UniswapV4DetfFacet is IFacet {
    /// @inheritdoc IFacet
    function facetName() public pure virtual returns (string memory);
    /// @inheritdoc IFacet
    function facetFuncs() public pure virtual returns (bytes4[] memory);

    /// @inheritdoc IFacet
    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](0);
    }

    /// @inheritdoc IFacet
    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory funcs_)
    {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
