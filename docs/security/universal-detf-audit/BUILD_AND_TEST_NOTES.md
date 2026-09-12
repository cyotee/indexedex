# Build and test execution notes

Status: measurements incomplete; no compilation-speed improvement has been established yet.

The warm baseline build skipped compilation. The first close-authorization test compiled in 28.07 seconds. The subsequent hook-library rebuild selected 1,065 source files and remained CPU-active for more than 90 minutes. Its log is `evidence/forge-build-hook-fix.log`. This is a substantial iteration-time cost; silence in this run has not been treated as a compiler failure.

The separate production refresh (`forge build contracts --out out_security_validation_20260905 --cache-path cache_security_validation_20260905 --skip test --skip script`) passed: 2,331 sources, 1,563.83 seconds. The source-metadata verifier passed for 14 selected artifacts and 212 unique sources. This differs in source scope and output selection from the earlier full build, so the elapsed times are not a controlled speed comparison. The output/cache flags must remain on subsequent tests to select these refreshed artifacts.

Follow-up focused builds passed: three CP deposit facet paths compiled seven files in 4.49 seconds; the universal factory artifact seed with `--contracts contracts/utils/foundry` compiled 139 files in 17.33 seconds. All 14 selected artifacts passed source verification afterward (`artifact-freshness-followup.json`). These are useful iteration scopes, not substitutes for broad integration tests. The narrowed source root retains the production artifact seeds; ordinary imports still resolve against the repository root. Test this CLI scope against the same regression selection before adopting it as a workflow.

**Runtime experiment rejected:** using the narrowed contracts source root for tests caused all 18 selected suites to fail in setup (`vm.getCode: no matching artifact found`), despite existing artifact files. Keep the normal `contracts/` source root for factory-based runtime tests. The narrow root is only a bounded production-build scope in the measurements above.

Foundry 1.5.1 performs a separate ABI-only project compile for filtered test discovery before its normal logged compile; path/contract filters are applied afterward. A focused test root is being validated with `FOUNDRY_TEST=docs/security/universal-detf-audit/validation`. Its `SelectedRegression.t.sol` uses named imports of the original 15 test files, preserving their source paths and production fixtures. The first bare-import version encountered a namespace collision and was corrected before runtime. Do not treat the focused root as full coverage. Primary source: [test discovery implementation](https://github.com/foundry-rs/foundry/blob/v1.5.1/crates/forge/src/cmd/test/mod.rs#L210-L277) and [artifact-based runner](https://github.com/foundry-rs/foundry/blob/v1.5.1/crates/forge/src/multi_runner.rs#L499-L550).

The first combined runtime checkpoint executed 131 tests in 33.88 seconds after compilation (112 pass, 19 fail). The subsequent fee-only run reported 128.92 seconds of compilation but roughly eleven minutes total wall time, showing that the compiler's reported interval alone does not measure the entire preparation cost. Three of its four selected cases passed after the SE-share preview correction; the strict raw/pair preview test remains a documented failure.

## Validation order

1. Preserve the active build, `out/`, and `cache_forge/` until the compiler exits.
2. Refresh production artifacts with `forge build --skip test --skip script` before tests. Foundry's `test` and `script` skip aliases refer to `.t.sol` and `.s.sol` filenames; imported dependencies and nonmatching source files may still compile. Record the actual source count and elapsed time before claiming a speedup.
3. Run the new regression and packaging suites first, with a fixed, recorded fuzz-run setting. Resolve failures before broadening the run.
4. Run the affected CP hook, universal four-binding lifecycle/decimal/adversarial, and shared claim suites. Shared claim changes also require coverage outside the universal DETF family.
5. Measure deployed component sizes from the final artifacts and actual production-factory deployments. The old monolithic artifacts are not the size gate after splitting.

Before tests, run `verify_artifact_sources.py` in this directory with the selected facet/package artifact paths. It compares metadata source Keccak hashes with local files. Its initial check correctly detected the edited claim target against the old artifact (`evidence/artifact-freshness-before.json`). This supplements the build-before-test rule; it does not verify library addresses or onchain implementations.

Use the existing default and fork profiles; do not add package profiles or enable `via_ir`. Keep the production artifact seed: factory services that load `out/` are not an implicit source dependency and tests alone can deploy stale bytecode.

## Further optimization candidates

- Measure compilation separately from test execution and CREATE3/hook mining; optimize the measured dominant cost.
- Review remaining linked-facet `type(...).creationCode` imports in test deployment services: they can propagate production changes through large fixture inheritance trees. Any alternative must preserve library linking and real production deployment coverage.
- Foundry 1.5.1's `vm.getCode` does not link unresolved library placeholders. A future loader must patch compiler-declared link references with the same managed library addresses, reject missing/conflicting links, and honor CLI output overrides. No speculative loader change was included in this remediation.
- Keep deterministic fixtures and cached mining inputs only where package/constructor/code changes correctly invalidate them.
- Use focused CLI filters during remediation, then run the broad gate once the source is stable. A smaller test selection is an iteration tool, not evidence of complete coverage.

No global fuzz/invariant reduction or security-check removal was made to improve timing. Runtime validation of the combined remediation remains pending.


## Explicit artifact seed candidate — static analysis only, not validated

The failed narrowed-root experiment does not print which `vm.getCode` lookup failed. A source/cache import walk from `validation/SelectedRegression.t.sol` plus the existing three `contracts/utils/foundry/*.sol` files identifies **28 implementation source omissions** and **47 literal artifact IDs** in reachable FactoryServices. The first source-proven missing lookup on the shared `IndexedexTest.setUp()` path is `FeeCollectorManagerFacet.sol:FeeCollectorManagerFacet` (`contracts/test/IndexedexTest.sol:79`). This is an inference from call order and source reachability, not a traced failure. Existing artifact files alone do not prove that Foundry's current compilation-artifact map can resolve a lookup.

The walk used import edges from `cache_forge/solidity-files-cache.json` and `cache_security_validation_20260905/solidity-files-cache.json`, falling back to source imports for uncached files, and repeatedly added sources named by literal artifact IDs. It reached a fixed point at 563 initial / 634 expanded source paths. These are static dependency counts, **not** measured compiler source counts or timing predictions; cache metadata may contain older import edges. All 47 IDs resolved to unique source filenames. The only application-side computed `getCode` ID found is the five product-facet loop in `UniswapV4Detf_FacetPackaging.t.sol`; all five are already covered by the production universal seed.

The missing implementation sources are:

- `contracts/fee/collector/FeeCollectorManagerFacet.sol`
- `contracts/fee/collector/FeeCollectorSingleTokenPushFacet.sol`
- `contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory.sol`
- `contracts/hooks/uniswap/v4/factory/facets/UniswapV4HookFlagsFacet.sol`
- `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg.sol`
- `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg.sol`
- `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol`
- `contracts/oracles/fee/VaultFeeOracleManagerFacet.sol`
- `contracts/oracles/fee/VaultFeeOracleQueryFacet.sol`
- `contracts/registries/vault/VaultRegistryDeploymentFacet.sol`
- `contracts/registries/vault/VaultRegistryDisableManagerFacet.sol`
- `contracts/registries/vault/VaultRegistryDisableQueryFacet.sol`
- `contracts/registries/vault/VaultRegistryVaultManagerFacet.sol`
- `contracts/registries/vault/VaultRegistryVaultPackageManagerFacet.sol`
- `contracts/registries/vault/VaultRegistryVaultPackageQueryFacet.sol`
- `contracts/registries/vault/VaultRegistryVaultQueryFacet.sol`
- `contracts/vaults/basic/ERC4626BasedBasicVaultFacet.sol`
- `contracts/vaults/basic/MultiAssetBasicVaultFacet.sol`
- `contracts/vaults/detf/common/bondNft/DETFNFTVaultFacet.sol`
- `contracts/vaults/detf/common/claimToken/RebasingClaimTokenFacet.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFTokenFacet.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/UniswapV4DetfBondNFTVaultFacet.sol`
- `contracts/vaults/standard/ERC4626StandardVaultFacet.sol`
- `contracts/vaults/standard/MultiAssetStandardVaultFacet.sol`
- `contracts/vaults/standard/erc4626/ERC4626StandardExchangeInFacet.sol`
- `contracts/vaults/standard/erc4626/ERC4626StandardExchangeMarkerFacet.sol`
- `contracts/vaults/standard/erc4626/ERC4626StandardExchangeOutFacet.sol`

For a later isolated experiment, the following is a conservative explicit import seed for every literal artifact ID found in those reachable FactoryServices. It deliberately includes methods not necessarily called by the 15 selected test files (for example dual-hook and rebasing-DETF deployment services), and duplicates some already reachable imports to make the artifact inventory explicit. Keep both existing production seeds; keep the focused harness and all real TestBase/manager/registry/CREATE3 calls unchanged. Place a proposed extra seed under the chosen narrowed source root only after authorizing that separate experiment:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "contracts/fee/collector/FeeCollectorDFPkg.sol";
import "contracts/fee/collector/FeeCollectorManagerFacet.sol";
import "contracts/fee/collector/FeeCollectorSingleTokenPushFacet.sol";
import "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory.sol";
import "contracts/hooks/uniswap/v4/factory/facets/UniswapV4HookFlagsFacet.sol";
import "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol";
import "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg.sol";
import "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol";
import "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg.sol";
import "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol";
import "contracts/manager/IndexedexManagerDFPkg.sol";
import "contracts/oracles/fee/VaultFeeOracleManagerFacet.sol";
import "contracts/oracles/fee/VaultFeeOracleQueryFacet.sol";
import "contracts/registries/vault/VaultRegistryDeploymentFacet.sol";
import "contracts/registries/vault/VaultRegistryDisableManagerFacet.sol";
import "contracts/registries/vault/VaultRegistryDisableQueryFacet.sol";
import "contracts/registries/vault/VaultRegistryVaultManagerFacet.sol";
import "contracts/registries/vault/VaultRegistryVaultPackageManagerFacet.sol";
import "contracts/registries/vault/VaultRegistryVaultPackageQueryFacet.sol";
import "contracts/registries/vault/VaultRegistryVaultQueryFacet.sol";
import "contracts/vaults/basic/ERC4626BasedBasicVaultFacet.sol";
import "contracts/vaults/basic/MultiAssetBasicVaultFacet.sol";
import "contracts/vaults/detf/common/bondNft/DETFNFTVaultDFPkg.sol";
import "contracts/vaults/detf/common/bondNft/DETFNFTVaultFacet.sol";
import "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import "contracts/vaults/detf/common/claimToken/RebasingClaimTokenFacet.sol";
import "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFTokenDFPkg.sol";
import "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFTokenFacet.sol";
import "contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/UniswapV4DetfBondNFTVaultDFPkg.sol";
import "contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/UniswapV4DetfBondNFTVaultFacet.sol";
import "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfBondFacet.sol";
import "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfClaimFacet.sol";
import "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol";
import "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfExchangeFacet.sol";
import "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfMaintenanceFacet.sol";
import "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfQueryFacet.sol";
import "contracts/vaults/standard/ERC4626StandardVaultFacet.sol";
import "contracts/vaults/standard/MultiAssetStandardVaultFacet.sol";
import "contracts/vaults/standard/erc4626/ERC4626StandardExchangeDFPkg.sol";
import "contracts/vaults/standard/erc4626/ERC4626StandardExchangeInFacet.sol";
import "contracts/vaults/standard/erc4626/ERC4626StandardExchangeMarkerFacet.sol";
import "contracts/vaults/standard/erc4626/ERC4626StandardExchangeOutFacet.sol";
import "@crane/contracts/tokens/ERC20/ERC20Facet.sol";
import "@crane/contracts/tokens/ERC2612/ERC2612Facet.sol";
import "@crane/contracts/tokens/ERC4626/ERC4626Facet.sol";
import "@crane/contracts/tokens/ERC4626/ERC4626PermitDFPkg.sol";
import "@crane/contracts/utils/cryptography/ERC5267/ERC5267Facet.sol";
```

This proposal does not change the deployment route: it only makes dynamically loaded implementations compiler-reachable. Hook facets that currently use `type(...).creationCode` remain reached through their existing FactoryService imports, preserving compiler-managed library linking. Do not migrate those calls to `vm.getCode` as part of this optimization. The seed is limited to the current focused fixtures, **not** every gold fixture or launch script in the repository. Adding new focused tests requires repeating the artifact dependency walk.

Before adopting the narrower source root, separately compile/build and then run the same focused harness with identical source/test roots and artifact settings, verify source hashes, and confirm all real setups, selector/size checks, and regressions pass without fallback to stale or omitted artifacts. No narrowed-root runtime success is claimed. The current normal-root run should continue unchanged, and this proposal does not justify deleting or modifying caches/artifacts.

`foundry.toml` does not configure `script`; default `script/` does not exist (launch sources are under `scripts/`). Thus matching-root `forge build` does not need `--skip script` to remove a configured script directory. The important matching setting is the same `FOUNDRY_TEST=docs/security/universal-detf-audit/validation`; omitting tests changes the compilation graph. Remember that skip aliases operate on filename patterns, not only configured root directories.
