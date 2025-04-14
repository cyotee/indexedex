# IndexedEx Test Coverage Report

*Last Updated: 2024-07-31*

This report summarizes the current test coverage for critical interfaces across the IndexedEx protocol, including `IFacet`, `IERC165`, `IDiamondLoupe`, and `ICreate2Aware`.

---

## 1. `IFacet` Coverage for Facets

The `TestBase_IFacet` provides a standardized way to test for `IFacet` compliance by checking for correct interface and function selector registration.

**Conclusion**: Coverage is inconsistent. While the pattern is correctly implemented for core standard vault and Uniswap integration facets, it is missing for all Balancer V3, Camelot, Oracle, and Registry facets. There is a clear opportunity to improve architectural consistency by creating `IFacet` tests for the uncovered components.

### `IFacet` Coverage Details

| Facet Contract | `IFacet` Test Present | Notes |
| :--- | :---: | :--- |
| **Core Vault Facets** | | |
| `StandardVaultFacet.sol` | ✅ | `test/foundry/vaults/standard/StandardVaultFacet_IFacet_Test.t.sol` |
| `ConstantProductStrategyVaultFacet.sol`| ✅ | `test/foundry/vaults/standard/ConstantProductStrategyVaultFacet_IFacet_Test.t.sol` |
| `StrategyVaultAwareFacet.sol` | ❌ | Not Found |
| **DEX Integration Facets** | | |
| `UniswapV2StandardExchangeInFacet.sol` | ✅ | `test/.../uniswap/v2/UniswapV2StandardExchangeInFacet_IFacet_Test.t.sol` |
| `UniswapV2StandardExchangeOutFacet.sol`| ✅ | `test/.../uniswap/v2/UniswapV2StandardExchangeOutFacet_IFacet_Test.t.sol`|
| `CamelotV2StandardExchangeInFacet.sol`| ❌ | Not Found |
| `CamelotV2StandardExchangeOutFacet.sol`| ❌ | Not Found |
| **Balancer V3 Facets** | | |
| `BalancerV3StrategyVaultPoolAdaptorHooksFacet.sol` | ❌ | Not Found |
| `BalancerV3StrategyVaultPoolAdaptorPoolFacet.sol` | ❌ | Not Found |
| `BalancerV3ConstantProductPoolFacet.sol` | ❌ | Not Found |
| **Oracle & Registry Facets** | | |
| `VaultFeeOracleManagerFacet.sol` | ❌ | Not Found |
| `VaultFeeOracleQueryFacet.sol` | ❌ | Not Found |
| `VaultRegistryDeploymentFacet.sol` | ❌ | Not Found |
| `VaultRegistryQueryFacet.sol` | ❌ | Not Found |
| **Rate Provider Facets** | | |
| `CamelotV2WrappedStrategyVaultRateProviderFacet.sol`| ❌ | Not Found |
| `UniswapV2WrappedStrategyVaultRateProviderFacet.sol` | ❌ | Not Found |

---

## 2. `IERC165` (supportsInterface) Coverage for Proxies

`IERC165` is critical for runtime interface detection. Correct testing involves calling `supportsInterface(bytes4 interfaceId)` and asserting the expected boolean result.

**Conclusion**: Coverage is sporadic and not standardized in a reusable base test. The pattern is implemented perfectly for the Rate Provider proxies but is missing for the main `VaultRegistry`, `VaultFeeOracle`, and the various pool proxies.

| Proxy / Package | `IERC165` Test Present | Notes |
| :--- | :---: | :--- |
| `UniswapV2WrappedStrategyVaultRateProviderPkg` | ✅ | Explicitly checks for `IWrappedStrategyVaultRateProvider` and `IRateProvider`. |
| `CamelotV2WrappedStrategyVaultRateProviderPkg` | ✅ | Explicitly checks for `IWrappedStrategyVaultRateProvider` and `IRateProvider`. |
| `VaultRegistry` Proxy | ❌ | No explicit `supportsInterface` tests found. |
| `VaultFeeOracle` Proxy | ❌ | No explicit `supportsInterface` tests found. |
| Pool Proxies (e.g. Balancer V3 Pools) | ❌ | The `BetterBalancerV3BasePoolTest` base class does not include explicit `supportsInterface` checks. |

---

## 3. `IDiamondLoupe` Coverage for Proxies

The `IDiamondLoupe` interface allows for runtime introspection of a diamond proxy's facets and functions.

**Conclusion**: Coverage is inconsistent. A good pattern exists in the `UniswapV2StandardStrategyVaultPkg` test, but it has not been systematically applied to other proxies.

| Proxy / Package | `IDiamondLoupe` Test Present | Notes |
| :--- | :---: | :--- |
| `UniswapV2StandardStrategyVaultPkg` | ✅ | Contains a `test_diamondLoupe_facetAddresses` test that correctly verifies the loupe functionality. |
| `VaultRegistry` Proxy | ❌ | No loupe tests found. |
| `VaultFeeOracle` Proxy | ❌ | No loupe tests found. |
| Pool Proxies | ❌ | No generic loupe tests in the relevant base classes. |

---

## 4. `ICreate2Aware` (CREATE3 Factory) Coverage

This interface ensures compliance with the protocol's mandatory `CREATE3` deployment architecture.

**Conclusion**: Coverage is excellent and systematic. The project contains numerous dedicated `_ICreate2Aware_Test.t.sol` test files for facets, packages, and proxies. This indicates that the core architectural requirement of using the `CREATE3` factory is well-enforced by its corresponding test pattern.

---

## Summary and Recommendations

1.  **Expand `IFacet` Testing**: The highest priority is to create `IFacet` tests for all currently uncovered facets, following the existing pattern in `StandardVaultFacet_IFacet_Test.t.sol`. This will ensure basic architectural compliance across all modular components.
2.  **Standardize `IERC165` and `IDiamondLoupe` Tests**: A new base test class for diamond proxies could be created to provide standardized tests for `IERC165` and `IDiamondLoupe`. Alternatively, the existing test patterns from the Rate Provider and Uniswap Vault packages should be replicated across all other proxies.
3.  **Maintain `ICreate2Aware` Vigilance**: Continue the excellent practice of creating dedicated `ICreate2Aware` tests for all new deployable components.
