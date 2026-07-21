// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IBalancerV3Pool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBalancerV3Pool.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {CommonBufferMultiVaultWeightedPoolTarget} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPoolTarget.sol";
import {ICommonBufferMultiVaultWeightedPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/ICommonBufferMultiVaultWeightedPool.sol";
import {CommonBufferMultiVaultWeightedPoolRepo as Repo} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPoolRepo.sol";

contract CommonBufferMultiVaultWeightedPoolFacet is CommonBufferMultiVaultWeightedPoolTarget, IFacet {
    function unpairedCount() external view returns (uint8) {
        return Repo._unpairedCount();
    }

    function vaultCount() external view returns (uint8) {
        return Repo._vaultCount();
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

    function bufferToken() external view returns (IERC20) {
        return Repo._bufferToken();
    }

    function bufferIndex() external view returns (uint256) {
        return Repo._bufferIndex();
    }

    function virtualBuffer() external view returns (uint256) {
        return Repo._virtualBuffer();
    }

    function shareToken(uint256 i) external view returns (IERC20) {
        return Repo._shareToken(i);
    }

    function standardExchangeVault(uint256 i) external view returns (IStandardExchange) {
        return Repo._standardExchangeVault(i);
    }

    function vaultShareRateProvider(uint256 i) external view returns (IRateProvider) {
        return Repo._vaultShareRateProvider(i);
    }

    function shareIndex(uint256 i) external view returns (uint256) {
        return Repo._shareIndex(i);
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
        returns (ICommonBufferMultiVaultWeightedPool.TokenKind kind, uint256 legIndex)
    {
        return Repo._resolveTokenIndex(tokenIndex);
    }

    function mostNeededVault() external view returns (uint8) {
        uint8[] memory order = _rankDeposit(_liveBalances());
        return order[0];
    }

    function mostExcessVault() external view returns (uint8) {
        uint8[] memory order = _rankRedeem(_liveBalances());
        return order[0];
    }

    function depthPerWeight(uint256 vaultIndex) external view returns (uint256) {
        return _score(vaultIndex, _liveBalances());
    }

    function facetName() public pure returns (string memory) {
        return type(CommonBufferMultiVaultWeightedPoolFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory ifaces) {
        ifaces = new bytes4[](2);
        ifaces[0] = type(IBalancerV3Pool).interfaceId;
        ifaces[1] = type(ICommonBufferMultiVaultWeightedPool).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](22);
        funcs[0] = IBalancerV3Pool.computeInvariant.selector;
        funcs[1] = IBalancerV3Pool.computeBalance.selector;
        funcs[2] = IBalancerV3Pool.onSwap.selector;
        funcs[3] = this.unpairedCount.selector;
        funcs[4] = this.vaultCount.selector;
        funcs[5] = this.tokenCount.selector;
        funcs[6] = this.unpairedToken.selector;
        funcs[7] = this.unpairedRateProvider.selector;
        funcs[8] = this.unpairedIndex.selector;
        funcs[9] = this.bufferToken.selector;
        funcs[10] = this.bufferIndex.selector;
        funcs[11] = this.virtualBuffer.selector;
        funcs[12] = this.shareToken.selector;
        funcs[13] = this.standardExchangeVault.selector;
        funcs[14] = this.vaultShareRateProvider.selector;
        funcs[15] = this.shareIndex.selector;
        funcs[16] = this.hookShareDelta.selector;
        funcs[17] = this.weight.selector;
        funcs[18] = this.resolveTokenIndex.selector;
        funcs[19] = this.mostNeededVault.selector;
        funcs[20] = this.mostExcessVault.selector;
        funcs[21] = this.depthPerWeight.selector;
    }

    function facetMetadata() external pure returns (string memory n, bytes4[] memory i, bytes4[] memory f) {
        n = facetName();
        i = facetInterfaces();
        f = facetFuncs();
    }
}
