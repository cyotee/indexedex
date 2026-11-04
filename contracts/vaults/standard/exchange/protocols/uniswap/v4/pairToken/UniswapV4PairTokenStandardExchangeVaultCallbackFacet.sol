// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {UniswapV4PairTokenStandardExchangeVaultComponentBindings as ComponentBindings} from "./UniswapV4PairTokenStandardExchangeVaultComponentBindings.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {UniswapV4PairTokenStandardExchangeVaultCallbackTarget} from "./UniswapV4PairTokenStandardExchangeVaultCallbackTarget.sol";

// tag::UniswapV4PairTokenStandardExchangeVaultCallbackFacet[]
/// @notice Installs only the authenticated PoolManager callback.
contract UniswapV4PairTokenStandardExchangeVaultCallbackFacet is
    UniswapV4PairTokenStandardExchangeVaultCallbackTarget,
    IFacet, ComponentBindings
{
    // tag::facetName-5b6f4d01[]
    /// @inheritdoc IFacet
    /// @custom:signature facetName()
    /// @custom:selector 0x5b6f4d01
    function facetName() public pure returns (string memory) {
        return type(UniswapV4PairTokenStandardExchangeVaultCallbackFacet).name;
    }
    // end::facetName-5b6f4d01[]

    // tag::facetInterfaces-2ea80826[]
    /// @inheritdoc IFacet
    /// @custom:signature facetInterfaces()
    /// @custom:selector 0x2ea80826
    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IUnlockCallback).interfaceId;
    }
    // end::facetInterfaces-2ea80826[]

    // tag::facetFuncs-574a4cff[]
    /// @inheritdoc IFacet
    /// @custom:signature facetFuncs()
    /// @custom:selector 0x574a4cff
    function facetFuncs() public pure returns (bytes4[] memory functions_) {
        functions_ = new bytes4[](1);
        functions_[0] = IUnlockCallback.unlockCallback.selector;
    }
    // end::facetFuncs-574a4cff[]

    // tag::facetMetadata-f10d7a75[]
    /// @inheritdoc IFacet
    /// @custom:signature facetMetadata()
    /// @custom:selector 0xf10d7a75
    function facetMetadata()
        external pure returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory functions_)
    {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
    // end::facetMetadata-f10d7a75[]
}
// end::UniswapV4PairTokenStandardExchangeVaultCallbackFacet[]
