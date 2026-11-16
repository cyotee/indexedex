// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ConstantProductStandardYieldExecutionTarget} from "contracts/vaults/standard/sy/ConstantProductStandardYieldTarget.sol";
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
    UniswapV2StandardExchangeInTarget
} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInTarget.sol";

contract UniswapV2StandardExchangeInFacet is UniswapV2StandardExchangeInTarget, ConstantProductStandardYieldExecutionTarget, IFacet {
    function _redeemConstantProduct(address holder_, address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_)
        internal override nonReentrant returns (uint256)
    {
        return _redeemLpSharesFrom(holder_, receiver_, shares_, tokenOut_, minimum_);
    }

    function facetName() public pure returns (string memory name) {
        return type(UniswapV2StandardExchangeInFacet).name;
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

        funcs[0] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs[1] = IStandardExchangeIn.exchangeIn.selector;
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
