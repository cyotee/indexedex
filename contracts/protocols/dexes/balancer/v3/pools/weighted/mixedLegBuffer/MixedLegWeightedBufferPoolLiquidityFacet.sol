// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPoolLiquidity} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IPoolLiquidity.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {MixedLegWeightedBufferPoolLiquidityTarget} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/MixedLegWeightedBufferPoolLiquidityTarget.sol";

contract MixedLegWeightedBufferPoolLiquidityFacet is MixedLegWeightedBufferPoolLiquidityTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(MixedLegWeightedBufferPoolLiquidityFacet).name;
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
