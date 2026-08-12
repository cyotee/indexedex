// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {AaveCrossVersionLoopExchangeInTarget} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeInTarget.sol";

/**
 * @title AaveCrossVersionLoopExchangeInFacet
 * @author cyotee doge <doge.cyotee>
 * @notice IFacet declaration for the cross-version loop deposit entry (IStandardExchangeIn).
 */
contract AaveCrossVersionLoopExchangeInFacet is AaveCrossVersionLoopExchangeInTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(AaveCrossVersionLoopExchangeInFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IStandardExchangeIn).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](2);
        funcs[0] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs[1] = IStandardExchangeIn.exchangeIn.selector;
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
