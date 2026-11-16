// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVault} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IVault.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {TestBase_BalancerV3StableBufferTransitionQuote} from "contracts/protocols/dexes/balancer/v3/pools/stable/TestBase_BalancerV3StableBufferTransitionQuote.sol";
import {TestBase_CommonBufferMultiVaultStablePool} from "./bases/TestBase_CommonBufferMultiVaultStablePool.sol";
import {ICommonBufferMultiVaultStablePoolPkg} from "contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/ICommonBufferMultiVaultStablePoolPkg.sol";

/// @notice Registry-deployed CommonBuffer SE regression; no DETF or consumer implementation involved.
contract CommonBufferMultiVaultStablePool_TransitionQuote is
    TestBase_CommonBufferMultiVaultStablePool, TestBase_BalancerV3StableBufferTransitionQuote
{
    function _transitionFixture() internal override returns (TransitionFixture memory f) {
        f.pool = cbmvsPool;
        f.asset = IERC20(address(seVault));
        f.holder = bob;
        f.seedOwner = alice;
        f.rate = seRateProviderPkg.deployRateProvider(IStandardExchange(f.pool), f.asset);
        f.vault = IVault(address(bv3Vault));
        f.authorizer = address(authorizer);
        f.poolFacet = bufferPoolFacet;
        f.pkg = IDiamondFactoryPackage(address(cbmvsPkg));
    }

    function _primeTransitionBook(bool bufferIn) internal override {
        swapExactIn(alice, bufferIn ? IERC20(address(dai)) : IERC20(address(seVault)),
            bufferIn ? IERC20(address(seVault)) : IERC20(address(dai)), 1e17);
    }
}

/// @notice The same regressions with the real underlying SE rate provider (non-unit token rate).
contract CommonBufferMultiVaultStablePool_RatedTransitionQuote is CommonBufferMultiVaultStablePool_TransitionQuote {
    function _buildPkgArgs(uint8 vaultCount)
        internal view override returns (ICommonBufferMultiVaultStablePoolPkg.PkgArgs memory args)
    {
        args = super._buildPkgArgs(vaultCount);
        args.vaultShareRateProviders[0] = seRateProvider;
    }
}
