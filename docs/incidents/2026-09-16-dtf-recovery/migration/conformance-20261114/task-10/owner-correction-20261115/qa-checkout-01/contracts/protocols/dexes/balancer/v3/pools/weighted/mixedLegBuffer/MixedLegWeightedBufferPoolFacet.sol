// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IBalancerV3Pool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBalancerV3Pool.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {MixedLegWeightedBufferPoolTarget} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/MixedLegWeightedBufferPoolTarget.sol";
import {IMixedLegWeightedBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/IMixedLegWeightedBufferPool.sol";
import {MixedLegWeightedBufferPoolRepo as Repo} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/MixedLegWeightedBufferPoolRepo.sol";

contract MixedLegWeightedBufferPoolFacet is MixedLegWeightedBufferPoolTarget, IFacet {
    function unpairedCount() external view returns (uint8) {
        return Repo._unpairedCount();
    }

    function pairCount() external view returns (uint8) {
        return Repo._pairCount();
    }

    function tokenCount() external view returns (uint256) {
        return Repo._tokenCount();
    }

    function unpairedToken(uint256 i) external view returns (IERC20) {
        return Repo._unpairedToken(i);
    }

    function unpairedRateProvider(uint256 i) external view returns (IRateProvider) {
        return Repo._unpairedRateProvider(i);
    }

    function unpairedIndex(uint256 i) external view returns (uint256) {
        return Repo._unpairedIndex(i);
    }

    function bufferToken(uint256 i) external view returns (IERC20) {
        return Repo._bufferToken(i);
    }

    function shareToken(uint256 i) external view returns (IERC20) {
        return Repo._shareToken(i);
    }

    function standardExchangeVault(uint256 i) external view returns (IStandardExchange) {
        return Repo._standardExchangeVault(i);
    }

    function pairRateProvider(uint256 i) external view returns (IRateProvider) {
        return Repo._pairRateProvider(i);
    }

    function bufferIndex(uint256 i) external view returns (uint256) {
        return Repo._bufferIndex(i);
    }

    function shareIndex(uint256 i) external view returns (uint256) {
        return Repo._shareIndex(i);
    }

    function virtualBuffer(uint256 i) external view returns (uint256) {
        return Repo._virtualBuffer(i);
    }

    function hookShareDelta(uint256 i) external view returns (int256) {
        return Repo._hookShareDelta(i);
    }

    function weight(uint256 tokenIndex) external view returns (uint256) {
        return Repo._weight(tokenIndex);
    }

    function resolveTokenIndex(uint256 tokenIndex)
        external
        view
        returns (IMixedLegWeightedBufferPool.TokenKind kind, uint256 legIndex)
    {
        return Repo._resolveTokenIndex(tokenIndex);
    }

    function facetName() public pure returns (string memory) {
        return type(MixedLegWeightedBufferPoolFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory ifaces) {
        ifaces = new bytes4[](2);
        ifaces[0] = type(IBalancerV3Pool).interfaceId;
        ifaces[1] = type(IMixedLegWeightedBufferPool).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](19);
        funcs[0] = IBalancerV3Pool.computeInvariant.selector;
        funcs[1] = IBalancerV3Pool.computeBalance.selector;
        funcs[2] = IBalancerV3Pool.onSwap.selector;
        funcs[3] = this.unpairedCount.selector;
        funcs[4] = this.pairCount.selector;
        funcs[5] = this.tokenCount.selector;
        funcs[6] = this.unpairedToken.selector;
        funcs[7] = this.unpairedRateProvider.selector;
        funcs[8] = this.unpairedIndex.selector;
        funcs[9] = this.bufferToken.selector;
        funcs[10] = this.shareToken.selector;
        funcs[11] = this.standardExchangeVault.selector;
        funcs[12] = this.pairRateProvider.selector;
        funcs[13] = this.bufferIndex.selector;
        funcs[14] = this.shareIndex.selector;
        funcs[15] = this.virtualBuffer.selector;
        funcs[16] = this.hookShareDelta.selector;
        funcs[17] = this.weight.selector;
        funcs[18] = this.resolveTokenIndex.selector;
    }

    function facetMetadata() external pure returns (string memory n, bytes4[] memory i, bytes4[] memory f) {
        n = facetName();
        i = facetInterfaces();
        f = facetFuncs();
    }
}
