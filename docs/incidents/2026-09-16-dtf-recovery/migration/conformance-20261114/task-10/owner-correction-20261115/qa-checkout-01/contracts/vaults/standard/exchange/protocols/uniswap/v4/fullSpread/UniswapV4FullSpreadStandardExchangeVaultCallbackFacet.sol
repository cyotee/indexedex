// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {UniswapV4FullSpreadStandardExchangeVaultCallbackTarget} from "./UniswapV4FullSpreadStandardExchangeVaultCallbackTarget.sol";

contract UniswapV4FullSpreadStandardExchangeVaultCallbackFacet is
    UniswapV4FullSpreadStandardExchangeVaultCallbackTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4FullSpreadStandardExchangeVaultCallbackFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory ids_) {
        ids_ = new bytes4[](1);
        ids_[0] = type(IUnlockCallback).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](1);
        funcs_[0] = IUnlockCallback.unlockCallback.selector;
    }

    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
