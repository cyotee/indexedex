// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVault} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IVault.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {TestBase_BalancerV3StableBufferTransitionQuote} from "contracts/protocols/dexes/balancer/v3/pools/stable/TestBase_BalancerV3StableBufferTransitionQuote.sol";
import {TestBase_MixedBufferMultiVaultStablePool} from "./bases/TestBase_MixedBufferMultiVaultStablePool.sol";
import {IMixedBufferMultiVaultStablePoolPkg} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/IMixedBufferMultiVaultStablePoolPkg.sol";

/// @notice Registry-deployed MixedBuffer SE regression, including its physical unpaired leg.
contract MixedBufferMultiVaultStablePool_TransitionQuote is
    TestBase_MixedBufferMultiVaultStablePool, TestBase_BalancerV3StableBufferTransitionQuote
{
    function _transitionFixture() internal override returns (TransitionFixture memory f) {
        f.pool = mbmvsPool;
        f.asset = IERC20(address(seVault));
        f.holder = bob;
        f.seedOwner = alice;
        f.rate = seRateProviderPkg.deployRateProvider(IStandardExchange(f.pool), f.asset);
        f.vault = IVault(address(bv3Vault));
        f.authorizer = address(authorizer);
        f.poolFacet = bufferPoolFacet;
        f.pkg = IDiamondFactoryPackage(address(mbmvsPkg));
        f.mixed = true;
    }

    function _primeTransitionBook(bool bufferIn) internal override {
        swapExactIn(alice, bufferIn ? IERC20(address(dai)) : IERC20(address(seVault)),
            bufferIn ? IERC20(address(seVault)) : IERC20(address(dai)), 1e17);
    }
}

/// @notice The same regressions with the real underlying SE rate provider (non-unit token rate).
contract MixedBufferMultiVaultStablePool_RatedTransitionQuote is MixedBufferMultiVaultStablePool_TransitionQuote {
    function _buildPkgArgs(uint8 unpairedCount, uint8 vaultCount)
        internal view override returns (IMixedBufferMultiVaultStablePoolPkg.PkgArgs memory args)
    {
        args = super._buildPkgArgs(unpairedCount, vaultCount);
        args.vaultShareRateProviders[0] = seRateProvider;
    }
}
