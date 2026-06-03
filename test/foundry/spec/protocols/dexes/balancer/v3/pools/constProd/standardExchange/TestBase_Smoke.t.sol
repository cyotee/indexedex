// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";

contract TestBase_Smoke is TestBase_StandardExchangeBufferPool {
    function test_setup_poolDeployed() public view {
        assertTrue(bufferPool != address(0), "pool address must be non-zero");
    }

    function test_setup_poolRegisteredWithBv3Vault() public view {
        // If the pool is registered, getPoolTokenInfo will not revert.
        (IERC20[] memory tokens,,,) = bv3Vault.getPoolTokenInfo(bufferPool);
        assertEq(tokens.length, 2, "pool must have exactly two tokens");
    }

    function test_setup_initializesVirtualTTA() public view {
        IStandardExchangeBufferPool p = IStandardExchangeBufferPool(bufferPool);
        assertGt(p.virtualTTA(), 0, "virtualTTA must be seeded > 0 after initialization");
    }

    function test_setup_hookSharesDeltaZeroAfterInit() public view {
        IStandardExchangeBufferPool p = IStandardExchangeBufferPool(bufferPool);
        assertEq(p.hookSharesDelta(), 0, "hookSharesDelta must be 0 immediately after initialization");
    }

    function test_setup_ttaTokenMatchesDai() public view {
        IStandardExchangeBufferPool p = IStandardExchangeBufferPool(bufferPool);
        assertEq(address(p.ttaToken()), address(tta), "ttaToken must match the configured TTA");
    }

    function test_setup_shareTokenMatchesSeVault() public view {
        IStandardExchangeBufferPool p = IStandardExchangeBufferPool(bufferPool);
        assertEq(address(p.shareToken()), address(shares), "shareToken must match the SE vault shares");
    }

    function test_setup_rateProviderSet() public view {
        IStandardExchangeBufferPool p = IStandardExchangeBufferPool(bufferPool);
        assertEq(
            address(p.rateProvider()),
            address(seRateProvider),
            "rateProvider must match the canonical StandardExchangeRateProviderDFPkg-deployed instance"
        );
    }

    function test_setup_standardExchangeVaultSet() public view {
        IStandardExchangeBufferPool p = IStandardExchangeBufferPool(bufferPool);
        assertEq(
            address(p.standardExchangeVault()),
            address(seVault),
            "standardExchangeVault must match the deployed SE vault"
        );
    }

    /// @notice Proves Change 2 idempotency: the pool's stored rate provider equals the canonical
    ///         address returned by `seRateProviderPkg.deployRateProvider(seVault, tta)`.
    function test_rateProviderIsCanonical() public view {
        address fromPool = address(IStandardExchangeBufferPool(bufferPool).rateProvider());
        address fromDFPkg = address(seRateProvider);
        assertEq(fromPool, fromDFPkg, "pool RP must equal canonical RP for the (seVault, tta) pair");
    }
}
