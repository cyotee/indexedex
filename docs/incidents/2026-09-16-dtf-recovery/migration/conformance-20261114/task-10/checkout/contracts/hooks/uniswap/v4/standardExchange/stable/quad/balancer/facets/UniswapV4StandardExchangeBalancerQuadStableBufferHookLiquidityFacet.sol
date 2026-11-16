// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityTarget} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityTarget.sol";

contract UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityFacet is UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityTarget, IFacet {
    function facetName() public pure returns (string memory) { return type(UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityFacet).name; }
    function facetInterfaces() public pure returns (bytes4[] memory interfaces) { interfaces = new bytes4[](0); }
    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](7);
        funcs[0] = bytes4(keccak256("joinProportional(uint256[],address,uint256,uint256)"));
        funcs[1] = bytes4(keccak256("joinUnbalanced(uint256[],address,uint256,uint256)"));
        funcs[2] = bytes4(keccak256("joinSingleAssetExactOut(address,uint256,address,uint256,uint256)"));
        funcs[3] = bytes4(keccak256("joinSingleAssetExactIn(address,uint256,address,uint256,uint256)"));
        funcs[4] = bytes4(keccak256("depositSingle(address,uint256,address,uint256,uint256)"));
        funcs[5] = bytes4(keccak256("joinProportionalFlexible(uint256[],bool[],address,uint256,uint256)"));
        funcs[6] = bytes4(keccak256("joinUnbalanced(address[],uint256[],address,uint256,uint256)"));
    }
    function facetMetadata() external pure returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory funcs) { return (facetName(), facetInterfaces(), facetFuncs()); }
}
