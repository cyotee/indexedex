// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {NativeStandardYieldSelectors} from "contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookQueryTarget} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookQueryTarget.sol";

contract UniswapV4StandardExchangeBalancerQuadStableBufferHookQueryFacet is UniswapV4StandardExchangeBalancerQuadStableBufferHookQueryTarget, IFacet {
    function facetName() public pure returns (string memory) { return type(UniswapV4StandardExchangeBalancerQuadStableBufferHookQueryFacet).name; }
    function facetInterfaces() public pure returns (bytes4[] memory interfaces) { interfaces = new bytes4[](1); interfaces[0] = type(IStandardizedYield).interfaceId; }
    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](7);
        funcs[0] = bytes4(keccak256("previewJoinProportional(uint256[])"));
        funcs[1] = bytes4(keccak256("previewJoinUnbalanced(uint256[])"));
        funcs[2] = bytes4(keccak256("previewJoinSingleAssetExactOut(address,uint256)"));
        funcs[3] = bytes4(keccak256("previewJoinSingleAssetExactIn(address,uint256)"));
        funcs[4] = bytes4(keccak256("previewDepositSingle(address,uint256)"));
        funcs[5] = bytes4(keccak256("previewJoinProportionalFlexible(uint256[],bool[])"));
        funcs[6] = bytes4(keccak256("previewJoinUnbalanced(address[],uint256[])"));
        funcs = NativeStandardYieldSelectors._append(funcs);
    }
    function facetMetadata() external pure returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory funcs) { return (facetName(), facetInterfaces(), facetFuncs()); }
}
