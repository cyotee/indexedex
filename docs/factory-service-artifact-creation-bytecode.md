# FactoryService artifact creation bytecode

- **Status:** planned
- **Created:** 2026-09-02
- **Updated:** 2026-09-02 (D1–D14 decided; plan written)
- **Source request:** Please take an inventory of the FactoryServices in the repo and write a PRD file for rewriting all the FactoryService libraries to load the creation code bytecode from the build artifact ABI. We don't need to be thorough, or worry about every deployment point. Just the Factory Services, and confirming that the Test bases use the Factory Service. Our aim is to drastically reduce the compilation time so we can run the tests faster. A pass of refactoring the obvious areas should be sufficient to make this execution reasonable.

## Summary

IndexedEx FactoryService libraries stop importing Facet and DFPkg **implementations** solely to read `type(C).creationCode` / `type(C).name`. They load **creation bytecode** from Foundry build artifacts (`foundry.toml` `out = 'out'`) at cheatcode time via `ArtifactCreationCode.creationCode("File.sol:ContractName")`, keep interface-only typing, and keep the same CREATE3 salts and `vm.label` names. Crane implementations those services deploy are compiled by a src seed file (`CraneFactoryArtifactSeed.sol`), not by FactoryService imports. TestBases that already `using` a FactoryService stay on that path. After this, editing production implementation source no longer invalidates the FactoryService compile unit, so the TestBase / script fan-out does not recompile. Agents must run **`forge build` then `forge test`** (or `forge script`) after production edits so `out/` is current. Do not treat `forge test` as a substitute for that build.

## Requirements

1. Shared artifact creation-bytecode loader
   - [ ] One IndexedEx library at `contracts/utils/foundry/ArtifactCreationCode.sol` wraps Foundry’s artifact loader (`vm.getCode`).
   - [ ] The library exposes exactly `function creationCode(string memory artifactId_) internal returns (bytes memory)`. Callers write `ArtifactCreationCode.creationCode("File.sol:ContractName")`. There is no `using` for `string`, and the function is not named `getCode`.
   - [ ] Callers pass an artifact id of the form `File.sol:ContractName` (source filename plus contract identifier). The helper does not hard-code a filesystem `out/` prefix; `vm.getCode` reads whatever directory `foundry.toml` sets as `out`.
   - [ ] The helper returns **creation bytecode** (artifact `.bytecode.object`). It does not return ABI JSON and does not return runtime bytecode (`vm.getDeployedCode`).
   - [ ] If the returned bytecode contains a library placeholder (`__$`), the helper reverts with a string that includes the artifact id. Unlinked contracts must not go through this helper (see requirement 2 exception). A missing artifact is `vm.getCode`’s own revert (no matching artifact), not a wrap that deploys empty bytes.
   - [ ] FactoryServices pass this bytecode into the **existing** deploy call for that helper: `create3` (execution delegates), `deployFacet`, `deployPackageWithArgs`, or `IVaultRegistryDeployment.deployPkg`. Constructor-arg concat stays as it is today (`bytes.concat(creationCode, abi.encode(executionDelegate))` on Uni V3/V4 In/Out facets). Deploy routing does not change.

2. Rewrite IndexedEx FactoryServices that currently embed `type(C).creationCode`
   - [ ] Every file listed in **Inventory → Rewrite set** no longer contains `type(...).creationCode` or `type(...).name`, except the unlinked-library exception below.
   - [ ] Those files no longer `import` Facet / DFPkg / Target **implementation** contracts used only for `type()`, except for contracts covered by that exception.
   - [ ] **Unlinked-library exception:** if the Foundry artifact for a deployed contract is unlinked (creation bytecode contains `__$` placeholders), that one deploy helper keeps `type(C).creationCode` and the implementation import. Mark it with a one-line comment (`unlinked artifact; type().creationCode required`). Do not use `type()` as a general fallback.
   - [ ] Interface imports stay (`IFacet`, `ICreate3FactoryProxy`, `I*DFPkg`, `PkgInit` / `PkgArgs` on the interface).
   - [ ] CREATE3 salts keep today’s `abi.encode(...)` argument list. Only `type(C).name` becomes the string literal `"<ContractName>"` (the Solidity contract identifier, not the file path). Facet salts that are `abi.encode(type(C).name)._hash()` become `abi.encode("ContractName")._hash()`. DFPkg salts that also encode `pkgInitArgs` (for example `abi.encode(type(FeeCollectorDFPkg).name, pkgInitArgs)._hash()`) keep those extra arguments. Do not drop extra salt components.
   - [ ] `vm.label` strings stay the same contract identifier (the literal that equals today’s `type(C).name`).
   - [ ] Public helper names and `using X for ICreate3FactoryProxy` / `IIndexedexManagerProxy` / `IVaultRegistryDeployment` surfaces stay the same so TestBases and scripts do not need call-site rewrites.

3. Component / wrapper FactoryServices that do not embed creation code
   - [ ] Files in **Inventory → No `type().creationCode` (wrappers)** are not rewritten for bytecode loading.
   - [ ] They continue to call the Facet / Pkg FactoryServices they already wrap, so TestBases that only `using` the Component service still pick up artifact bytecode through the wrap.

4. TestBases keep using FactoryServices
   - [ ] Hermetic hub `contracts/test/IndexedexTest.sol` still deploys core facets/packages through `FeeCollectorFactoryService` and `IndexedexManagerFactoryService` (and Crane Access / Introspection services, which this PRD does not rewrite).
   - [ ] This PRD does not add new TestBases and does not migrate leftover `type().creationCode` inside TestBases.
   - [ ] `grep` of `*TestBase*.sol` plus `IndexedexTest.sol` still finds the family FactoryService name for each rewrite-set service that had TestBase or hub usage at PRD time (see **Inventory → TestBase confirmation** for the pattern).

5. Crane-sourced deploy targets compile via a src seed
   - [ ] New file `contracts/utils/foundry/CraneFactoryArtifactSeed.sol` lives under `src = 'contracts'`. It is the compile root for Crane implementations that IndexedEx FactoryServices deploy.
   - [ ] The seed imports exactly these nine implementations (paths as today): `ERC20Facet`, `ERC2612Facet`, `ERC4626Facet`, `ERC5267Facet`, `ERC4626PermitDFPkg`, `BalancerV3VaultAwareFacet`, `BalancerV3PoolTokenFacet` (file `BetterBalancerV3PoolTokenFacet.sol`), `BalancerV3AuthenticationFacet`, `BalancerV3ConstantProductPoolFacet`.
   - [ ] The seed references each imported type with `type(C).name` in one dummy `internal pure` function so solc cannot treat the imports as unused. It does not call `type(C).creationCode` and it is not a FactoryService.
   - [ ] FactoryServices, TestBases, and scripts do not `import` the seed. `VaultComponentFactoryService` and `BalancerV3ConstantProductPool_FactoryService` drop their Crane implementation imports and load bytecode with `ArtifactCreationCode.creationCode`.
   - [ ] After `forge build`, `out/` contains creation-bytecode artifacts for those nine contracts. Agents then run `forge test` / `forge script`. Do not rely on `forge test` alone to emit those artifacts.

6. Agent / compile law
   - [x] Root `CLAUDE.md` item 10 (always-on) and `docs/agent/INDEXEDEX_AGENT_LAW.md` **FactoryService creation bytecode**: FactoryService deploys read creation bytecode from `out/` via `ArtifactCreationCode`. After any production contract edit, agents run **`forge build` then `forge test`** (same for `forge script`). `forge test` alone can CREATE3-deploy stale `out/` bytecode because the test graph no longer imports the implementation. `forge build` compiles `src = 'contracts'`, including `CraneFactoryArtifactSeed.sol`, which is what emits Crane-sourced artifacts. A `forge build` is also required when artifacts are missing (empty worktree `out/`, deleted cache, or a command that skips compiling `contracts/`). Do not delete the seed. Do not import it from TestBases or FactoryServices.
   - [ ] A missing artifact fails at `vm.getCode` (no matching artifact). That is the expected failure, not a silent empty bytecode deploy.
   - [ ] Worktree seed rule (`cache_forge/` + `out/` from a warm checkout) stays in force; this rewrite makes `out/` semantically load-bearing for FactoryService deploys.

7. Done when the compile graph is cut
   - [ ] `rg 'type\([^)]+\)\.creationCode' contracts --glob '*FactoryService*.sol'` has no matches in IndexedEx `contracts/` except deploy helpers annotated with the unlinked-library exception comment. The empty stub `BalancerV3StandardExchangeRouterFactoryService.sol` stays empty.
   - [ ] `IndexedexManagerFactoryService.sol`, `VaultComponentFactoryService.sol`, and `BalancerV3ConstantProductPool_FactoryService.sol` do not import the **facet** implementations they deploy (DFPkg interface imports from co-located `*DFPkg.sol` files may remain). Crane facet imports for those deploy targets live only in `CraneFactoryArtifactSeed.sol`.
   - [ ] No compile-cache timing experiment is required.
   - [ ] No new product tests are required. Existing TestBases that already deploy through FactoryService remain the behavioral check.

## Non-goals

- Do not audit or rewrite every `type().creationCode` call site in TestBases, scripts, or helpers. Leftovers (rate-provider deploys inside some DETF / buffer-pool TestBases, ERC721 facet deploys with custom salts, stub packages) stay.
- Do not rewrite Crane submodule FactoryServices (`lib/crane/contracts/**/*FactoryService.sol`), including `AccessFacetFactoryService` and `IntrospectionFacetFactoryService` on `IndexedexTest`.
- Do not move interfaces into new files to kill remaining “import `IFoo` from `Foo.sol`” leaks.
- Do not change CREATE3 factories, vault-registry `deployPkg`, hook-factory routing, or `never new facets/DFPkgs`.
- Do not change salts, labels, or deploy helper signatures.
- Do not parse ABI to deploy. ABI is not creation bytecode.
- Do not use `vm.getDeployedCode` (runtime) as initcode.
- Do not put `vm.getCode` on an on-chain production path. FactoryServices are already Foundry-only (`Vm` / `vm.label`).
- Do not delete or “clean” `out/` / `cache_forge/` as part of this work.
- Do not enable `via_ir`.
- Do not add a CI compile-time size or benchmark gate. The product is a cheaper incremental compile graph.
- Do not import `CraneFactoryArtifactSeed.sol` from FactoryServices, TestBases, or scripts. It is a src compile root only.
- Do not compile all of `lib/crane` or add Crane paths to `src`. The seed lists the nine deploy targets only.

## Constraints

- Foundry `profile.default` / `fork`: `src = 'contracts'`, `out = 'out'`, `cache_path = 'cache_forge'`, `solc = 0.8.35`, `via_ir = false`.
- Crane first: facets via CREATE3 / FactoryService; vault and DETF packages via `indexedexManager.deploy*DFPkg` / vault registry. This rewrite only changes how initcode bytes are obtained.
- FactoryServices already depend on `forge-std/Vm.sol` and `VM_ADDRESS`. Artifact loading is the same cheatcode world.
- `vm.getCode` artifact id must be unique enough to resolve. Use `File.sol:ContractName` when two contracts share a name; never a bare ambiguous name.
- Linked-library placeholders: `ArtifactCreationCode` reverts if bytecode contains `__$`. Deploy helpers for contracts whose artifacts are unlinked keep `type(C).creationCode` (requirement 2 exception). Do not ship unlinked initcode through `vm.getCode`.
- DETF role names and product law are unchanged.
- Production-first tests: no mocks of SUT. This work does not add mocks; it changes where initcode bytes are read.
- Crane sources under `lib/crane` are not in `src`. Foundry compiles them only when a `src` / `test` / `script` file imports them. After this rewrite that importer is `CraneFactoryArtifactSeed.sol`, not the FactoryServices.

## Decisions

| ID | Decision | Status | Rationale |
|----|----------|--------|-----------|
| D1 | Scope is IndexedEx `contracts/**/*FactoryService*.sol` that today use `type().creationCode` (55 files). Crane FactoryServices are out. | Decided | Owner: IndexedEx-only. Crane Access/Introspection stay on `IndexedexTest` as a follow-on. IndexedEx production edits are the usual compile pain. |
| D2 | Load creation bytecode with `vm.getCode("File.sol:ContractName")` behind `ArtifactCreationCode`. Do not hand-parse `out/*.json` with `stdJson` in each FactoryService. | Decided | Owner: shared `vm.getCode` helper. That is Foundry’s artifact JSON loader for creation bytecode (`.bytecode.object`) and respects `foundry.toml` `out`. |
| D3 | Salts and labels become string literals equal to current `type(C).name`. | Decided | Dropping the implementation type is the compile-graph cut. Salt drift would change CREATE3 addresses. |
| D4 | TestBases are confirmation-only: they already `using` FactoryServices. Do not migrate leftover TestBase `type().creationCode`. | Decided | Original request: do not worry about every deployment point. |
| D5 | Wrapper Component / Pkg-init FactoryServices with no `type().creationCode` are not rewritten. | Decided | They already delegate to Facet/Pkg services. |
| D6 | Empty stub `BalancerV3StandardExchangeRouterFactoryService.sol` (no deploy functions) is skipped. Live file is `BalancerV3StandardExchangeRouter_FactoryService.sol`. | Decided | No creation code to load. |
| D7 | Do not relocate interfaces this pass. Co-located `IFoo` imports from `Foo.sol` (including hub `FeeCollectorDFPkg` / `IndexedexManagerDFPkg`) may remain. | Decided | Owner: leave co-located interface imports. Facet files still decouple. Hub DFPkg edits can still recompile `IndexedexTest`. |
| D8 | Helper path is `contracts/utils/foundry/ArtifactCreationCode.sol` (IndexedEx, Foundry-only). | Decided | FactoryServices already live under `contracts/` and call `Vm`. |
| D9 | Agent law lives in root `CLAUDE.md` item 10 (always-on) and `docs/agent/INDEXEDEX_AGENT_LAW.md`: after production edits, `forge build` then `forge test` / `forge script`. Artifacts in `out/` must be current. Missing artifact must revert via `vm.getCode`, not deploy empty code. | Decided | Decoupling compile from bytecode makes stale `out/` a correctness hazard. `forge test` is not a substitute for that build. |
| D10 | Keep `type(C).creationCode` only for contracts whose Foundry artifacts are unlinked. `ArtifactCreationCode` reverts on `__$` placeholders. | Decided | Owner: unlinked artifacts are the only `type()` escape hatch. Not a general fallback. |
| D11 | Done means grep + hub import check. No compile-cache smoke. | Decided | Owner: no `type().creationCode` except annotated unlinked exceptions; manager, vault-component, and Balancer V3 constant-product services do not import the facets they deploy (Crane facets go through the seed). |
| D12 | Helper API is `ArtifactCreationCode.creationCode(string memory artifactId_)` returning creation bytecode. No `using` for `string`. `__$` reverts with a string that includes the artifact id. Missing artifact is `vm.getCode`’s revert. | Decided | Review: one call shape for all rewrite-set sites; name parallels `type(C).creationCode`. |
| D13 | Salt rewrite replaces only `type(C).name` with the equal string literal. Extra `abi.encode` components (including `pkgInitArgs`) stay. Uni V3/V4 `bytes.concat(..., abi.encode(executionDelegate))` stays. Existing `create3` / `deployFacet` / `deployPackageWithArgs` / `deployPkg` routing stays. | Decided | Review: FeeCollector DFPkg salt is `abi.encode(name, pkgInitArgs)._hash()`, not name-only. Uni V3/V4 In/Out facets concat constructor args. Changing either would move CREATE3 addresses or break constructor initcode. |
| D14 | Crane-sourced FactoryService deploy targets compile via `contracts/utils/foundry/CraneFactoryArtifactSeed.sol`. The seed imports the nine Crane implementations listed in requirement 5 and references `type(C).name` so they emit `out/` artifacts. FactoryServices load those bytes with `ArtifactCreationCode.creationCode`. Do not keep `type().creationCode` for Crane sources and do not rely on copied `out/` alone. | Decided | Review: `lib/crane` is not `src`. Dropping FactoryService imports without a src compile root makes `vm.getCode` fail. The seed is that root without putting Crane on the TestBase fan-out. |

## Inventory

Snapshot 2026-09-02. Counts are files under IndexedEx `contracts/` unless noted.

| Set | Count |
|-----|------:|
| IndexedEx `*FactoryService*.sol` | 61 |
| Of those with `type().creationCode` (**rewrite set**) | 55 |
| Wrappers with no `type().creationCode` | 5 |
| Empty stub (skip) | 1 |
| Crane `*FactoryService*.sol` (out of scope) | 10 |
| Crane implementation seed (new `src` compile root) | 1 file, 9 imports |
| `*TestBase*.sol` that mention a FactoryService | 97 of 422 |

### Rewrite set (55)

Load artifact creation bytecode; drop implementation `type()` imports.

**Hub (every hermetic test via `IndexedexTest`, not a `TestBase*` filename)**

| File | Used by |
|------|---------|
| `contracts/fee/collector/FeeCollectorFactoryService.sol` | `IndexedexTest`, launch scripts |
| `contracts/manager/IndexedexManagerFactoryService.sol` | `IndexedexTest`, launch scripts, several `*Facet_IFacet.t.sol` |

**Vaults**

| File | TestBase / hub |
|------|----------------|
| `contracts/vaults/VaultComponentFactoryService.sol` | 17 TestBases (DETF, buffer pool, router, oracle) |
| `contracts/vaults/standard/erc4626/ERC4626StandardExchange_Component_FactoryService.sol` | `TestBase_ERC4626StandardExchange` |
| `contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlue_Component_FactoryService.sol` | Morpho TestBases |

**DETF common + families**

| File | TestBase / hub |
|------|----------------|
| `contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol` | 9 DETF TestBases |
| `contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol` | 9 DETF TestBases |
| `.../single/SingleStandardExchangeDETF_Facet_FactoryService.sol` | via `SingleStandardExchangeDETF_Component_FactoryService` (6 TestBases) |
| `.../single/SingleStandardExchangeDETF_Pkg_FactoryService.sol` | 4 TestBases |
| `.../mixedBuffer/MixedBufferMultiVaultStableDetf_Facet_FactoryService.sol` | via Component wrapper (2 TestBases) |
| `.../mixedBuffer/MixedBufferMultiVaultStableDetf_Pkg_FactoryService.sol` | via Component wrapper |
| `.../multi-vault-weighted/MultiVaultWeightedDetf_Facet_FactoryService.sol` | via Component wrapper (2 TestBases) |
| `.../multi-vault-weighted/MultiVaultWeightedDetf_Pkg_FactoryService.sol` | via Component wrapper |
| `.../stable/common/ComposedStableCommonDetf_Facet_FactoryService.sol` | Composed stable TestBases |
| `.../stable/common/ComposedStableCommonDetf_Pkg_FactoryService.sol` | Composed stable TestBases |
| `.../stable/common/ComposedStableCommonDetfBondNFTVault_Facet_FactoryService.sol` | Composed stable TestBases |
| `.../stable/common/ComposedStableCommonDetfBondNFTVault_Pkg_FactoryService.sol` | Composed stable TestBases |
| `.../stable/common/RebasingDETFToken_Facet_FactoryService.sol` | Composed stable TestBases |
| `.../stable/common/RebasingDETFToken_Pkg_FactoryService.sol` | Composed stable TestBases |
| `.../uniswap/v4/detf/UniswapV4Detf_Facet_FactoryService.sol` | Uni V4 DETF TestBases |
| `.../uniswap/v4/detf/UniswapV4Detf_Pkg_FactoryService.sol` | Uni V4 DETF TestBases |

**Uni V4 hooks**

| File | TestBase / hub |
|------|----------------|
| `contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol` | 25 hook / DETF TestBases |
| `.../orbital/UniswapV4OrbitalSwapHook_FactoryService.sol` | Orbital hook TestBases |
| `.../weighted/UniswapV4WeightedSwapHook_FactoryService.sol` | Weighted swap hook TestBase |
| `.../stable/quad/balancer/UniswapV4BalancerQuadStableSwapHook_FactoryService.sol` | Balancer quad hook TestBases |
| `.../stable/quad/curve/UniswapV4CurveQuadStableSwapHook_FactoryService.sol` | Curve quad hook TestBases |
| `.../standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol` | 12 TestBases |
| `.../standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService.sol` | Dual SE hook TestBases |
| `.../standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_FactoryService.sol` | SE orbital hook TestBases |
| `.../standardExchange/single/UniswapV4SingleStandardExchangeBufferHook_FactoryService.sol` | Single SE buffer hook TestBases |
| `.../standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_FactoryService.sol` | SE weighted hook TestBases |
| `.../standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_FactoryService.sol` | SE balancer quad hook TestBases |
| `.../standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService.sol` | SE curve quad hook TestBases |

**DEX / lending / staking / oracles / routers**

| File | TestBase / hub |
|------|----------------|
| `contracts/oracles/uniswap/v4/twap/UniswapV4TwapOracleFactoryService.sol` | TWAP oracle TestBases |
| `contracts/protocols/dexes/aerodrome/v1/Aerodrome_Component_FactoryService.sol` | Aerodrome + buffer-pool TestBases |
| `contracts/protocols/dexes/aerodrome/slipstream/Slipstream_Component_FactoryService.sol` | Slipstream TestBases / fork |
| `contracts/protocols/dexes/uniswap/v2/UniswapV2_Component_FactoryService.sol` | Uni V2 + buffer-pool TestBases |
| `contracts/protocols/dexes/uniswap/v3/UniswapV3_Component_FactoryService.sol` | Uni V3 TestBases / fork |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol` | Uni V4 component TestBase |
| `contracts/protocols/dexes/camelot/v2/CamelotV2_Component_FactoryService.sol` | `TestBase_CamelotV2StandardExchange` |
| `contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPool_FactoryService.sol` | Buffer-pool / comparative TestBases |
| `.../constProd/standardExchange/StandardExchangeBufferPool_FactoryService.sol` | SE buffer-pool TestBases |
| `.../stable/commonBufferMultiVault/CommonBufferMultiVaultStablePool_FactoryService.sol` | Common-buffer stable TestBases |
| `.../stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePool_FactoryService.sol` | Mixed-buffer stable TestBases |
| `.../weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPool_FactoryService.sol` | Common-buffer weighted TestBases |
| `.../weighted/mixedLegBuffer/MixedLegWeightedBufferPool_FactoryService.sol` | Mixed-leg weighted TestBases |
| `.../weighted/multiPairBuffer/MultiPairStandardExchangeBufferPool_FactoryService.sol` | Multi-pair buffer TestBases |
| `.../rateProviders/standardExchange/StandardExchangeRateProvider_FactoryService.sol` | Scripts + some tests; several TestBases still call `type()` directly (out of this PRD) |
| `.../routers/BalancerV3StandardExchangeRouter_FactoryService.sol` | Router TestBases / coordinator tests |
| `contracts/routers/balancerV3-uniswapV4/BalancerV3UniswapV4CoordinatorRouter_FactoryService.sol` | Coordinator TestBase / tests |
| `contracts/protocols/lending/aave/v3.6/AaveV3Stata_Component_FactoryService.sol` | `TestBase_AaveV3StataStandardExchange` |
| `contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoop_Component_FactoryService.sol` | Aave cross-version `*.t.sol` (not named TestBase) |
| `contracts/protocols/staking/lido/LidoWstETH_Component_FactoryService.sol` | `TestBase_LidoWstETHStandardExchange` |
| `contracts/protocols/staking/etherfi/EtherFiWeETH_Component_FactoryService.sol` | `TestBase_EtherFiWeETHStandardExchange` |
| `contracts/protocols/staking/rocket-pool/RocketPoolRETH_Component_FactoryService.sol` | `TestBase_RocketPoolRETHStandardExchange` |

### No `type().creationCode` (wrappers, do not rewrite)

These only compose other FactoryServices or build `PkgInit`. They stay. TestBases that `using` them still benefit once the wrapped Facet/Pkg services load artifacts.

- `contracts/vaults/detf/common/factory/DetfComponentFactoryService.sol`
- `.../single/SingleStandardExchangeDETF_Component_FactoryService.sol`
- `.../mixedBuffer/MixedBufferMultiVaultStableDetf_Component_FactoryService.sol`
- `.../multi-vault-weighted/MultiVaultWeightedDetf_Component_FactoryService.sol`
- `.../stable/common/ComposedStableCommonDetf_Component_FactoryService.sol`

### Skip

- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterFactoryService.sol` — empty library; live deploys are in `BalancerV3StandardExchangeRouter_FactoryService.sol`.

### Crane implementation seed (new file)

`lib/crane` is not `src`. After rewrite-set FactoryServices drop `@crane` implementation imports, this file is the only IndexedEx `src` importer of the Crane contracts those services deploy.

- `contracts/utils/foundry/CraneFactoryArtifactSeed.sol`

It imports:

| Contract | Source |
|----------|--------|
| `ERC20Facet` | `@crane/contracts/tokens/ERC20/ERC20Facet.sol` |
| `ERC2612Facet` | `@crane/contracts/tokens/ERC2612/ERC2612Facet.sol` |
| `ERC4626Facet` | `@crane/contracts/tokens/ERC4626/ERC4626Facet.sol` |
| `ERC5267Facet` | `@crane/contracts/utils/cryptography/ERC5267/ERC5267Facet.sol` |
| `ERC4626PermitDFPkg` | `@crane/contracts/tokens/ERC4626/ERC4626PermitDFPkg.sol` |
| `BalancerV3VaultAwareFacet` | `@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareFacet.sol` |
| `BalancerV3PoolTokenFacet` | `@crane/contracts/protocols/dexes/balancer/v3/vault/BetterBalancerV3PoolTokenFacet.sol` |
| `BalancerV3AuthenticationFacet` | `@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3AuthenticationFacet.sol` |
| `BalancerV3ConstantProductPoolFacet` | `@crane/contracts/protocols/dexes/balancer/v3/pool-constProd/BalancerV3ConstantProductPoolFacet.sol` |

Today those imports live in `VaultComponentFactoryService.sol` (first five) and `BalancerV3ConstantProductPool_FactoryService.sol` (last four).

### Crane FactoryServices (out of scope; compile-hub note)

`IndexedexTest` still imports:

- `lib/crane/contracts/access/AccessFacetFactoryService.sol`
- `lib/crane/contracts/introspection/IntrospectionFacetFactoryService.sol`

Those two still use `type().creationCode`. Editing those Crane facets will still recompile `IndexedexTest` and therefore the hermetic suite. Other Crane FactoryServices (Gyro, Sky, Superchain, Create3FactoryService as CREATE3 primitive) are unused by IndexedEx TestBases or are not initcode loaders.

### TestBase confirmation (pattern, not every file)

Package TestBases under `contracts/**/TestBase_*.sol` and `test/foundry/**/TestBase_*.sol` already import the family FactoryService and `using` it for `ICreate3FactoryProxy` and, where needed, `IIndexedexManagerProxy` / `IVaultRegistryDeployment`. Examples:

- `contracts/test/IndexedexTest.sol` → FeeCollector + IndexedexManager (+ Crane Access/Introspection)
- `contracts/test/bases/TestBase_LidoWstETHStandardExchange.sol` (and EtherFi / Rocket Pool / Aave V3 Stata / ERC4626 SE)
- `contracts/vaults/detf/**/TestBase_*Detf*.sol` → DetfFacet / DetfPkg / DetfComponent + family Component/Facet/Pkg
- `contracts/hooks/uniswap/v4/**/TestBase_*.sol` → hook FactoryService + hook diamond factory FactoryService
- `test/foundry/spec/protocols/dexes/balancer/v3/pools/**/bases/TestBase_*.sol` → pool FactoryServices + often `VaultComponentFactoryService`

A minority of those TestBases also contain leftover `type().creationCode` (Standard Exchange rate provider, ERC721 facet with a custom salt, one DFPkg). That is **not** this PRD.

## Execute

Implementation plan: `./factory-service-artifact-creation-bytecode.plan.md`

Run: `/goal docs/factory-service-artifact-creation-bytecode.plan.md`
