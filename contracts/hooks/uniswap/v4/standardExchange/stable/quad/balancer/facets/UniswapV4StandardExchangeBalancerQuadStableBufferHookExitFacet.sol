// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookExitTarget} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookExitTarget.sol";

contract UniswapV4StandardExchangeBalancerQuadStableBufferHookExitFacet is UniswapV4StandardExchangeBalancerQuadStableBufferHookExitTarget, IFacet {
    function facetName() public pure returns (string memory) { return type(UniswapV4StandardExchangeBalancerQuadStableBufferHookExitFacet).name; }
    function facetInterfaces() public pure returns (bytes4[] memory interfaces) { interfaces = new bytes4[](0); }
    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](12);
        funcs[0] = bytes4(keccak256("exitSingleAssetExactTokenOut(address,uint256,address,uint256,uint256)"));
        funcs[1] = bytes4(keccak256("withdrawSingleExactOut(address,uint256,address,uint256,uint256)"));
        funcs[2] = bytes4(keccak256("exitProportional(uint256,address,uint256[],uint256)"));
        funcs[3] = bytes4(keccak256("exitSingleAssetExactBptIn(address,uint256,address,uint256,uint256)"));
        funcs[4] = bytes4(keccak256("withdrawSingle(address,uint256,address,uint256,uint256)"));
        funcs[5] = bytes4(keccak256("exitProportionalFlexible(uint256,address,bool[],uint256[],uint256)"));
        funcs[6] = bytes4(keccak256("previewExitSingleAssetExactTokenOut(address,uint256)"));
        funcs[7] = bytes4(keccak256("previewWithdrawSingleExactOut(address,uint256)"));
        funcs[8] = bytes4(keccak256("previewExitProportional(uint256)"));
        funcs[9] = bytes4(keccak256("previewExitSingleAssetExactBptIn(address,uint256)"));
        funcs[10] = bytes4(keccak256("previewWithdrawSingle(address,uint256)"));
        funcs[11] = bytes4(keccak256("previewExitProportionalFlexible(uint256,bool[])"));
    }
    function facetMetadata() external pure returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory funcs) { return (facetName(), facetInterfaces(), facetFuncs()); }
}
