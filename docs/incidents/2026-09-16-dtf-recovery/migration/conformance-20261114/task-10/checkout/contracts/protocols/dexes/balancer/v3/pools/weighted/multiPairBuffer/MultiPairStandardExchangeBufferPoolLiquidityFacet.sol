// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPoolLiquidity} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IPoolLiquidity.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {MultiPairStandardExchangeBufferPoolLiquidityTarget} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/MultiPairStandardExchangeBufferPoolLiquidityTarget.sol";

contract MultiPairStandardExchangeBufferPoolLiquidityFacet is
    MultiPairStandardExchangeBufferPoolLiquidityTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(MultiPairStandardExchangeBufferPoolLiquidityFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory i) {
        i = new bytes4[](1);
        i[0] = type(IPoolLiquidity).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory f) {
        f = new bytes4[](2);
        f[0] = IPoolLiquidity.onAddLiquidityCustom.selector;
        f[1] = IPoolLiquidity.onRemoveLiquidityCustom.selector;
    }

    function facetMetadata() external pure returns (string memory n, bytes4[] memory i, bytes4[] memory funcs) {
        n = facetName();
        i = facetInterfaces();
        funcs = facetFuncs();
    }
}
