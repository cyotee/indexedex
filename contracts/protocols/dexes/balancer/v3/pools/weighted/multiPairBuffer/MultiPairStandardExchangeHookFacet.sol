// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IHooks} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IHooks.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {BalancerV3VaultAwareRepo} from
    "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";

import {MultiPairStandardExchangeBufferHookTarget} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/MultiPairStandardExchangeBufferHookTarget.sol";
import {MultiPairStandardExchangeBufferPoolRepo as Repo} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/MultiPairStandardExchangeBufferPoolRepo.sol";

contract MultiPairStandardExchangeHookFacet is MultiPairStandardExchangeBufferHookTarget, IFacet {
    function _balancerV3Vault() internal view override returns (address) {
        return address(BalancerV3VaultAwareRepo._balancerV3Vault());
    }

    function _expectedFactory() internal view override returns (address) {
        return Repo._expectedFactory();
    }

    function facetName() public pure returns (string memory) {
        return type(MultiPairStandardExchangeHookFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory i) {
        i = new bytes4[](1);
        i[0] = type(IHooks).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory f) {
        f = new bytes4[](11);
        f[0] = IHooks.onRegister.selector;
        f[1] = IHooks.getHookFlags.selector;
        f[2] = IHooks.onBeforeInitialize.selector;
        f[3] = IHooks.onAfterInitialize.selector;
        f[4] = IHooks.onBeforeAddLiquidity.selector;
        f[5] = IHooks.onAfterAddLiquidity.selector;
        f[6] = IHooks.onBeforeRemoveLiquidity.selector;
        f[7] = IHooks.onAfterRemoveLiquidity.selector;
        f[8] = IHooks.onBeforeSwap.selector;
        f[9] = IHooks.onAfterSwap.selector;
        f[10] = IHooks.onComputeDynamicSwapFeePercentage.selector;
    }

    function facetMetadata() external pure returns (string memory n, bytes4[] memory i, bytes4[] memory funcs) {
        n = facetName();
        i = facetInterfaces();
        funcs = facetFuncs();
    }
}
