// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ConstantProductStandardYieldExecutionTarget} from "contracts/vaults/standard/sy/ConstantProductStandardYieldTarget.sol";
import {ConstantProductStandardYieldPreviewCallsTarget as ConstantProductStandardYieldPreviewTarget} from "contracts/vaults/standard/sy/ConstantProductStandardYieldTarget.sol";
import {NativeStandardYieldSelectors} from "contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    AerodromeStandardExchangeInTarget
} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeInTarget.sol";

contract AerodromeStandardExchangeInFacet is AerodromeStandardExchangeInTarget, ConstantProductStandardYieldExecutionTarget, IFacet {
    function _redeemConstantProduct(address holder_, address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_)
        internal override nonReentrant returns (uint256)
    {
        return _redeemLpSharesFrom(holder_, receiver_, shares_, tokenOut_, minimum_);
    }

    function facetName() public pure returns (string memory name) {
        return type(AerodromeStandardExchangeInFacet).name;
    }

    function facetInterfaces()
        public
        pure
        virtual
        returns (
            // override
            bytes4[] memory interfaces
        )
    {
        interfaces = new bytes4[](1);

        interfaces[0] = type(IStandardExchangeIn).interfaceId;
    }

    function facetFuncs()
        public
        pure
        virtual
        returns (
            // override
            bytes4[] memory funcs
        )
    {
        funcs = new bytes4[](2);
        funcs[0] = IStandardExchangeIn.exchangeIn.selector;
        funcs[1] = bytes4(keccak256("heldExcessTokens()"));
        funcs = NativeStandardYieldSelectors._appendExecution(funcs);
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
