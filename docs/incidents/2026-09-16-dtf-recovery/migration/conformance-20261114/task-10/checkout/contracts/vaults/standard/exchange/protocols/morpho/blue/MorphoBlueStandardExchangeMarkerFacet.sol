// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IMorphoBlueStandardExchange
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/IMorphoBlueStandardExchange.sol";
import {
    MorphoBlueStandardExchangeMarkerTarget
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeMarkerTarget.sol";

import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {NativeStandardYieldSelectors} from "contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol";
import {MorphoBlueStandardYieldTarget} from "./MorphoBlueStandardYieldTarget.sol";
contract MorphoBlueStandardExchangeMarkerFacet is MorphoBlueStandardExchangeMarkerTarget, MorphoBlueStandardYieldTarget, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(MorphoBlueStandardExchangeMarkerFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[0] = type(IMorphoBlueStandardExchange).interfaceId;
        interfaces[1] = type(IStandardizedYield).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](4);
        funcs[0] = IMorphoBlueStandardExchange.morpho.selector;
        funcs[1] = IMorphoBlueStandardExchange.marketParams.selector;
        funcs[2] = IMorphoBlueStandardExchange.marketId.selector;
        funcs[3] = IMorphoBlueStandardExchange.loanToken.selector;
        funcs = NativeStandardYieldSelectors._append(funcs);
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name_ = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }
}
