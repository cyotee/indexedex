// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPoolLiquidity} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IPoolLiquidity.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {StandardExchangeBufferPoolLiquidityTarget} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolLiquidityTarget.sol";

contract StandardExchangeBufferPoolLiquidityFacet is StandardExchangeBufferPoolLiquidityTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(StandardExchangeBufferPoolLiquidityFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory ifs) {
        ifs = new bytes4[](1);
        ifs[0] = type(IPoolLiquidity).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory fns) {
        fns = new bytes4[](2);
        fns[0] = IPoolLiquidity.onAddLiquidityCustom.selector;
        fns[1] = IPoolLiquidity.onRemoveLiquidityCustom.selector;
    }

    function facetMetadata() external pure returns (string memory n, bytes4[] memory i, bytes4[] memory f) {
        n = facetName(); i = facetInterfaces(); f = facetFuncs();
    }
}
