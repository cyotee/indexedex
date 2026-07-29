// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IBalancerV3Pool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBalancerV3Pool.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {StableMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/StableMath.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {
    CommonBufferMultiVaultStablePoolTarget
} from "contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolTarget.sol";
import {
    ICommonBufferMultiVaultStablePool
} from "contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/ICommonBufferMultiVaultStablePool.sol";
import {
    CommonBufferMultiVaultStablePoolRepo as Repo
} from "contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolRepo.sol";

contract CommonBufferMultiVaultStablePoolFacet is CommonBufferMultiVaultStablePoolTarget, IFacet {
    function vaultCount() external view returns (uint8) {
        return Repo._vaultCount();
    }

    function tokenCount() external view returns (uint256) {
        return Repo._tokenCount();
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

    function resolveTokenIndex(uint256 tokenIndex)
        external
        view
        returns (ICommonBufferMultiVaultStablePool.TokenKind kind, uint256 legIndex)
    {
        return Repo._resolveTokenIndex(tokenIndex);
    }

    function shallowestVault() external view returns (uint8) {
        uint8[] memory order = _rankDeposit(_liveBalances());
        return order[0];
    }

    function deepestVault() external view returns (uint8) {
        uint8[] memory order = _rankRedeem(_liveBalances());
        return order[0];
    }

    function derivedShareDepth(uint256 vaultIndex) external view returns (uint256) {
        return _derivedShareDepth(vaultIndex, _liveBalances());
    }

    function getAmplificationParameter() external view returns (uint256 value, bool isUpdating, uint256 precision) {
        (value, isUpdating) = Repo._getAmplificationParameter();
        precision = StableMath.AMP_PRECISION;
    }

    function facetName() public pure returns (string memory) {
        return type(CommonBufferMultiVaultStablePoolFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory ifaces) {
        ifaces = new bytes4[](2);
        ifaces[0] = type(IBalancerV3Pool).interfaceId;
        ifaces[1] = type(ICommonBufferMultiVaultStablePool).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](18);
        funcs[0] = IBalancerV3Pool.computeInvariant.selector;
        funcs[1] = IBalancerV3Pool.computeBalance.selector;
        funcs[2] = IBalancerV3Pool.onSwap.selector;
        funcs[3] = this.vaultCount.selector;
        funcs[4] = this.tokenCount.selector;
        funcs[5] = this.bufferToken.selector;
        funcs[6] = this.bufferIndex.selector;
        funcs[7] = this.virtualBuffer.selector;
        funcs[8] = this.shareToken.selector;
        funcs[9] = this.standardExchangeVault.selector;
        funcs[10] = this.vaultShareRateProvider.selector;
        funcs[11] = this.shareIndex.selector;
        funcs[12] = this.hookShareDelta.selector;
        funcs[13] = this.resolveTokenIndex.selector;
        funcs[14] = this.shallowestVault.selector;
        funcs[15] = this.deepestVault.selector;
        funcs[16] = this.derivedShareDepth.selector;
        funcs[17] = this.getAmplificationParameter.selector;
    }

    function facetMetadata() external pure returns (string memory n, bytes4[] memory i, bytes4[] memory f) {
        n = facetName();
        i = facetInterfaces();
        f = facetFuncs();
    }
}
