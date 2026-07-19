// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IBalancerV3Pool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBalancerV3Pool.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {MultiPairStandardExchangeBufferPoolTarget} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/MultiPairStandardExchangeBufferPoolTarget.sol";
import {IMultiPairStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/IMultiPairStandardExchangeBufferPool.sol";
import {MultiPairStandardExchangeBufferPoolRepo as Repo} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/MultiPairStandardExchangeBufferPoolRepo.sol";

contract MultiPairStandardExchangeBufferPoolFacet is MultiPairStandardExchangeBufferPoolTarget, IFacet {
    function pairCount() external view returns (uint8) {
        return Repo._pairCount();
    }

    function bufferToken(uint256 pairIndex) external view returns (IERC20) {
        return Repo._bufferToken(pairIndex);
    }

    function shareToken(uint256 pairIndex) external view returns (IERC20) {
        return Repo._shareToken(pairIndex);
    }

    function standardExchangeVault(uint256 pairIndex) external view returns (IStandardExchange) {
        return Repo._standardExchangeVault(pairIndex);
    }

    function rateProvider(uint256 pairIndex) external view returns (IRateProvider) {
        return Repo._rateProvider(pairIndex);
    }

    function bufferIndex(uint256 pairIndex) external view returns (uint256) {
        return Repo._bufferIndex(pairIndex);
    }

    function shareIndex(uint256 pairIndex) external view returns (uint256) {
        return Repo._shareIndex(pairIndex);
    }

    function virtualBuffer(uint256 pairIndex) external view returns (uint256) {
        return Repo._virtualBuffer(pairIndex);
    }

    function hookShareDelta(uint256 pairIndex) external view returns (int256) {
        return Repo._hookShareDelta(pairIndex);
    }

    function weight(uint256 tokenIndex) external view returns (uint256) {
        return Repo._weight(tokenIndex);
    }

    function tokenCount() external view returns (uint256) {
        return Repo._tokenCount();
    }

    function facetName() public pure returns (string memory) {
        return type(MultiPairStandardExchangeBufferPoolFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory ifaces) {
        ifaces = new bytes4[](2);
        ifaces[0] = type(IBalancerV3Pool).interfaceId;
        ifaces[1] = type(IMultiPairStandardExchangeBufferPool).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](14);
        funcs[0] = IBalancerV3Pool.computeInvariant.selector;
        funcs[1] = IBalancerV3Pool.computeBalance.selector;
        funcs[2] = IBalancerV3Pool.onSwap.selector;
        funcs[3] = this.pairCount.selector;
        funcs[4] = this.bufferToken.selector;
        funcs[5] = this.shareToken.selector;
        funcs[6] = this.standardExchangeVault.selector;
        funcs[7] = this.rateProvider.selector;
        funcs[8] = this.bufferIndex.selector;
        funcs[9] = this.shareIndex.selector;
        funcs[10] = this.virtualBuffer.selector;
        funcs[11] = this.hookShareDelta.selector;
        funcs[12] = this.weight.selector;
        funcs[13] = this.tokenCount.selector;
    }

    function facetMetadata() external pure returns (string memory n, bytes4[] memory i, bytes4[] memory f) {
        n = facetName();
        i = facetInterfaces();
        f = facetFuncs();
    }
}
