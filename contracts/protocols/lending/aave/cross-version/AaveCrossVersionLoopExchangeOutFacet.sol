// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {AaveCrossVersionLoopExchangeOutTarget} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeOutTarget.sol";

/**
 * @title AaveCrossVersionLoopExchangeOutFacet
 * @author cyotee doge <doge.cyotee>
 * @notice IFacet declaration for the cross-version loop withdraw exit (IStandardExchangeOut).
 */
contract AaveCrossVersionLoopExchangeOutFacet is AaveCrossVersionLoopExchangeOutTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(AaveCrossVersionLoopExchangeOutFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IStandardExchangeOut).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](2);
        funcs[0] = IStandardExchangeOut.previewExchangeOut.selector;
        funcs[1] = IStandardExchangeOut.exchangeOut.selector;
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
