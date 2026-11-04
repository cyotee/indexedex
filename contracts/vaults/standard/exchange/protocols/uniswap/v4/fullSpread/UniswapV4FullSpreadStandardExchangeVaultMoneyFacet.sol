// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IOperable} from "@crane/contracts/access/operable/IOperable.sol";
import {UniswapV4FullSpreadStandardExchangeVaultMoneyTarget} from "./UniswapV4FullSpreadStandardExchangeVaultMoneyTarget.sol";
import {IUniswapV4FullSpreadStandardExchangeVault as IVault} from "./interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {
    IStandardExchangeBundleIn,
    IStandardExchangeBundleOut
} from "./interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";

contract UniswapV4FullSpreadStandardExchangeVaultMoneyFacet is UniswapV4FullSpreadStandardExchangeVaultMoneyTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(UniswapV4FullSpreadStandardExchangeVaultMoneyFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory ids_) {
        ids_ = new bytes4[](4);
        ids_[0] = type(IStandardExchangeIn).interfaceId;
        ids_[1] = type(IStandardExchangeBundleIn).interfaceId;
        ids_[2] = type(IStandardExchangeBundleOut).interfaceId;
        ids_[3] = type(IVault).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](7);
        funcs_[0] = IStandardExchangeIn.exchangeIn.selector;
        funcs_[1] = IStandardExchangeBundleIn.exchangeBundleInForSingleOut.selector;
        funcs_[2] = IStandardExchangeBundleOut.exchangeBundleOut.selector;
        funcs_[3] = IVault.donate.selector;
        funcs_[4] = IVault.compound.selector;
        funcs_[5] = IOperable.setOperator.selector;
        funcs_[6] = IOperable.setOperatorFor.selector;
    }

    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
