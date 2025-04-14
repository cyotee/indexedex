# IDXEX-002 — DFPkg ↔ Spec Coverage Findings

**Date:** 2026-01-19

## Goal

Map every IndexedEx-owned Diamond Factory Package (DFPkg) under `contracts/**/*DFPkg*.sol` to at least one Foundry spec that **exercises the package deploy path** (directly or indirectly), per `tasks/IDXEX-002-review-dfpkg-spec-coverage/TASK.md`.

This document is intentionally *evidence-first*: it records where the repo currently proves deployability, and where coverage gaps remain.

## Scope

- **In scope:** IndexedEx repo packages under `contracts/**/*DFPkg*.sol`.
- **Out of scope:** DFPkgs from submodules (`lib/**`) and archival code (`old/**`, `snippets/**`).

## Method (practical)

Repo-wide searches over `test/foundry/spec/**` can time out. The effective approach was:

1. Enumerate IndexedEx-owned DFPkgs under `contracts/**/*DFPkg*.sol`.
2. Search per-subtree (DEX folder, vault folder) for DFPkg names and `deploy*DFPkg` callsites.
3. When a spec relies on a TestBase deploy in `setUp()`, treat that as **indirect deploy-path coverage** (the spec still runs those deploys).

## Coverage Map

Legend:
- ✅ **Covered**: at least one runnable spec deploys the DFPkg via factory/manager and uses it to deploy a proxy or otherwise exercises the deploy path.
- ⚠️ **Partial**: referenced or a derived/harness package is deployed, but the production DFPkg deploy path is not clearly exercised.
- ❌ **Gap**: no spec found that exercises this DFPkg’s deploy path.

| DFPkg | Status | Primary covering spec(s) | Evidence / Notes |
|---|---:|---|---|
| `FeeCollectorDFPkg.sol` | ✅ | `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_DeployWithPool.t.sol` (indirect via bases) | `contracts/test/IndexedexTest.sol` deploys `feeCollectorDFPkg` in `setUp()`. Many specs transitively inherit `IndexedexTest` via `contracts/vaults/TestBase_VaultComponents.sol`.
| `IndexedexManagerDFPkg.sol` | ✅ | `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_DeployWithPool.t.sol` (indirect via bases) | `contracts/test/IndexedexTest.sol` deploys `indexedexManagerDFPkg` + `indexedexManager` in `setUp()`.
| `AerodromeStandardExchangeDFPkg.sol` | ✅ | `test/foundry/spec/protocol/dexes/aerodrome/v1/AerodromeSetupDebug.t.sol` | Direct call: `indexedexManager.deployAerodromeStandardExchangeDFPkg(...)` with `assertTrue(address(aerodromeStandardExchangeDFPkg) != address(0))`.
| `UniswapV2StandardExchangeDFPkg.sol` | ✅ | `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_DeployWithPool.t.sol` | `contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange.sol` deploys the DFPkg via `indexedexManager.deployUniswapV2StandardExchangeDFPkg(...)`. Spec exercises `deployVault(...)`, `previewDeployVault(...)`, and revert paths.
| `CamelotV2StandardExchangeDFPkg.sol` | ✅ | `test/foundry/spec/protocol/dexes/camelot/v2/CamelotV2StandardExchange_DeployWithPool.t.sol` | `contracts/protocols/dexes/camelot/v2/TestBase_CamelotV2StandardExchange.sol` deploys the DFPkg via `indexedexManager.deployCamelotV2StandardExchangeDFPkg(...)`. Spec exercises vault deployment.
| `BalancerV3StandardExchangeRouterDFPkg.sol` | ✅ | `test/foundry/spec/protocol/vaults/seigniorage/SeigniorageDETFIntegration.t.sol` (indirect via base) | `contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol` deploys `seRouterDFPkg` via `create3Factory.deployBalancerV3StandardExchangeRouterDFPkg(...)` and then deploys the router proxy.
| `StandardExchangeRateProviderDFPkg.sol` | ✅ | `test/foundry/spec/protocol/vaults/seigniorage/SeigniorageDETFIntegration.t.sol` | `_deployStandardExchangeRateProviderPkg()` deploys via `create3Factory.deployPackageWithArgs(type(StandardExchangeRateProviderDFPkg).creationCode, ...)`.
| `SeigniorageDETFDFPkg.sol` | ✅ | `test/foundry/spec/protocol/vaults/seigniorage/SeigniorageDETFIntegration.t.sol` | Package is deployed via `Seigniorage_Component_FactoryService.deploySeigniorageDETFDFPkg(IVaultRegistryDeployment(address(indexedexManager)), pkgInit)` and then used to deploy the vault through the registry.
| `SeigniorageNFTVaultDFPkg.sol` | ⚠️ | `test/foundry/spec/protocol/vaults/seigniorage/SeigniorageDETFIntegration.t.sol` (derived mock) | Spec deploys `MockSeigniorageNFTVaultDFPkg is SeigniorageNFTVaultDFPkg` via `create3Factory.create3WithArgs(...)` and registers it, but **does not deploy the production `SeigniorageNFTVaultDFPkg` itself**.
| `ProtocolDETFDFPkg.sol` | ✅ | `test/foundry/spec/protocol/vaults/protocol/ProtocolDETFDFPkg_Deploy.t.sol` | Deploys the DFPkg via registry factory service, registers it, and deploys a Protocol DETF proxy through the registry; includes a revert-path check for `processArgs()` when not called by the registry.
| `ProtocolNFTVaultDFPkg.sol` | ✅ | `test/foundry/spec/protocol/vaults/protocol/ProtocolNFTVaultDFPkg_Deploy.t.sol` | Deploys the DFPkg via registry factory service, registers it, and deploys a Protocol NFT Vault proxy; includes a revert-path check for `processArgs()` when not called by the registry.
| `RICHIRDFPkg.sol` | ✅ | `test/foundry/spec/protocol/vaults/protocol/RICHIRDFPkg_Deploy.t.sol` | Deploys the DFPkg via registry factory service and deploys a RICHIR proxy; includes a revert-path check.

## Notes / Risks

- Some specs under `test/foundry/spec/vaults/protocol/**` are “math/specification tests” that don’t deploy contracts at all. They are valuable, but they **do not contribute deploy-path coverage** for the protocol DFPkgs.
- The Balancer router test base uses `new` for certain mock components/facets (e.g., `SenderGuardFacet`, pool factory mocks). This is test-only infra, but it’s worth keeping an eye on per the repo’s “no `new` for deployables” convention.

## Coverage Gaps (Actionable)

1. If `SeigniorageNFTVaultDFPkg.sol` has important production-only logic (salt derivation, arg processing, postDeploy hooks), add a spec that deploys **the production DFPkg** (not only a derived mock) and exercises `deployVault()`.
