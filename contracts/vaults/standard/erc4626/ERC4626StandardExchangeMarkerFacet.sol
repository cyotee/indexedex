// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC4626StandardExchange} from "contracts/vaults/standard/erc4626/IERC4626StandardExchange.sol";
import {ERC4626StandardExchangeCommon} from "contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol";

contract ERC4626StandardExchangeMarkerFacet is ERC4626StandardExchangeCommon, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(ERC4626StandardExchangeMarkerFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IERC4626StandardExchange).interfaceId;
        return interfaces;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](1);
        funcs[0] = IERC4626StandardExchange.protocolVault.selector;
        return funcs;
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
