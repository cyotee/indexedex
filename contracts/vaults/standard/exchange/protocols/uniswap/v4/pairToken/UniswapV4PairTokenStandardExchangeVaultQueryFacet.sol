// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {UniswapV4PairTokenStandardExchangeVaultComponentBindings as ComponentBindings} from "./UniswapV4PairTokenStandardExchangeVaultComponentBindings.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IUniswapV4PairTokenStandardExchangeVault as IVault} from "./interfaces/IUniswapV4PairTokenStandardExchangeVault.sol";
import {UniswapV4PairTokenStandardExchangeVaultQueryTarget} from "./UniswapV4PairTokenStandardExchangeVaultQueryTarget.sol";

// tag::UniswapV4PairTokenStandardExchangeVaultQueryFacet[]
/// @notice Configuration and ownership queries for the composed family interface.
contract UniswapV4PairTokenStandardExchangeVaultQueryFacet is UniswapV4PairTokenStandardExchangeVaultQueryTarget, IFacet, ComponentBindings {
    // tag::facetName-5b6f4d01[]
    /// @inheritdoc IFacet
    /// @custom:signature facetName()
    /// @custom:selector 0x5b6f4d01
    function facetName() public pure returns (string memory) { return type(UniswapV4PairTokenStandardExchangeVaultQueryFacet).name; }
    // end::facetName-5b6f4d01[]

    // tag::facetInterfaces-2ea80826[]
    /// @inheritdoc IFacet
    /// @custom:signature facetInterfaces()
    /// @custom:selector 0x2ea80826
    function facetInterfaces() public pure returns (bytes4[] memory ids_) {
        ids_ = new bytes4[](1);
        ids_[0] = type(IVault).interfaceId;
    }
    // end::facetInterfaces-2ea80826[]

    // tag::facetFuncs-574a4cff[]
    /// @inheritdoc IFacet
    /// @custom:signature facetFuncs()
    /// @custom:selector 0x574a4cff
    function facetFuncs() public pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](11);
        funcs_[0] = IVault.poolManager.selector;
        funcs_[1] = IVault.poolKey.selector;
        funcs_[2] = IVault.wrappedNative.selector;
        funcs_[3] = IVault.rateAsset.selector;
        funcs_[4] = IVault.tickLower.selector;
        funcs_[5] = IVault.tickUpper.selector;
        funcs_[6] = IVault.positionLiquidity.selector;
        funcs_[7] = IVault.localReserves.selector;
        funcs_[8] = IVault.basket.selector;
        funcs_[9] = IVault.maxZapBps.selector;
        funcs_[10] = IVault.maxZapTickMove.selector;
    }
    // end::facetFuncs-574a4cff[]

    // tag::facetMetadata-f10d7a75[]
    /// @inheritdoc IFacet
    /// @custom:signature facetMetadata()
    /// @custom:selector 0xf10d7a75
    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
    // end::facetMetadata-f10d7a75[]
}
// end::UniswapV4PairTokenStandardExchangeVaultQueryFacet[]

