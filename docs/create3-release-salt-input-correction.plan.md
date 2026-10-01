# Implementation plan: CREATE3 release salt input correction

- **PRD:** [create3-release-salt-input-correction.md](./create3-release-salt-input-correction.md)
- **Created:** 2026-09-16
- **Status:** implemented and validated; V1–V5 and the Crane build passed

This is the execute artifact. Follow this plan and its PRD without reopening locked decisions. Plan creation does not implement the correction or claim its tests have passed. Paths are repository-relative unless a link says otherwise.

## Objective

Remove creation bytecode and constructor data from every in-scope CREATE3 component salt. Retain artifact loading, constructor payloads, factory authorization, manager/registry routing, and occupied-address reuse. Use the ABI-encoded contract identifier, source-qualified for automatically linked libraries; runtime hashing uses `BetterEfficientHashLib._hash`, and constant initializers may use `keccak256`. Keep the documented Crane/test exceptions and proxy algorithms unchanged. Deliver complete inventory, regression evidence, corrected deployment guidance, and the Crane revision/submodule pin.

## Execution context

Read `CLAUDE.md`, `.github/ASSISTANT_RULES.md`, `.github/ASSISTANT_CODING.md`, `.github/ASSISTANT_DEPLOYMENT.md`, `.github/ASSISTANT_TESTS.md`, and `docs/testing/ARTIFACT_BUILDS.md`. Apply canonical `lib/crane/.claude/skills/crane-architecture/SKILL.md`, `lib/crane/.claude/skills/crane-deployment/SKILL.md`, `lib/crane/.claude/skills/crane-testing/SKILL.md`, and `.agents/skills/indexedex-testing/SKILL.md`. Consult `docs/agent/INDEXEDEX_AGENT_LAW.md` for deployment/test law; this PRD explicitly supersedes its bytecode-dependent library-salt guidance.

Planning snapshot: IndexedEx HEAD `ee7827f137e2a4d7d9a8fee65902f9ba930819bc`; Crane `d87c74b76ad30f6055211e6a37089c600d3ab3c3`. The checkout contains unrelated and uncommitted work, including completed FullSpread changes. Preserve it. Record working-tree context in addition to commit IDs; do not reset the checkout or use HEAD alone as the source baseline.

The FullSpread plan at `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.plan.md` now records completion. Its `VALIDATION.md` reports 654 passing tests across 49 suites, and all 96 preserved-source hashes. During planning, those 96 hashes and its production/test fingerprints matched the current files. This supersedes earlier PRD review snapshots that described FullSpread as unfinished; execution must still repeat Step 1 against its own checkout. No Forge command was run to create this plan.

## In scope

- Component salt producers and their consumers in `contracts/`, `scripts/`, `test/`, and the relevant Crane FactoryServices/tests/scripts; include archived script source corrections.
- Shared and independent helpers, upstream namespace composition, eleven hook helper signatures and callers, deployment aliases/predictions, and automatic library linking.
- Real-factory regression tests, affected maintained-script compilation, Crane's compile-only fork source, documentation, inventory, validation, and submodule pin.

## Out of scope

- Do not implement Uniswap liquidity-leak fixes, rename additional products, or change vault economics.
- Do not remove creation bytecode or constructor arguments from the deployment payload itself.
- Do not replace the CREATE3 primitive, add automatic version counters, append compiler/build hashes, or generate fallback salts when an address is occupied.
- Do not perform a live deployment, upgrade, migration, address-registry repointing, or release broadcast.
- Do not retain raw/packed-name hashing or extra release-label fields in D3 production component salts. Runtime hashing uses `abi.encode(name)._hash()` via `BetterEfficientHashLib`; D14 permits `keccak256(abi.encode(name))` constant initializers. D11 direct test/TestBase keys retain their existing encodings as specified in requirement 5. New runtime salt expressions this effort writes, including new D11 keys, use `_hash()`; constant initializers may use `keccak256` under D14.
- Do not change proxy deployment, `PkgArgs`, `calcSalt`, `processArgs`, proxy initialization, proxy salts, or actual CREATE2 behavior. These are excluded, not deferred design questions.
- Do not edit historical transaction receipts, rehearsal address tables, or audit results to imply they were produced with corrected salts. Updating a runbook's current salt-formula row under D9 is not rewriting those records.
- Do not repair unrelated pre-existing archived-script compilation failures, including missing `DeploymentBase.sol` imports. Correct their in-scope salt expressions and document source-level validation and existing blockers under requirement 5.
- Do not rewrite unrelated Crane vendored protocol internals, CREATE2 address formulas, storage-slot hashes, or Crane factory-primitive tests that pass arbitrary caller salts. Do not convert already-name-only Crane script or FactoryService salts (including packed version labels with no creation-bytecode or constructor-data contribution) to a new encoding. Do not defer Crane CREATE3 package-salt corrections that still include `PkgInit` or constructor data.
- Do not convert explicit instance-keyed test salts to canonical name salts, add isolated CREATE3 factories per coexisting test instance, or add creation-code or constructor-blob hashes to any test salt (D11). D11 does not apply to IndexedEx scripts, including `scripts/foundry/research/`; those follow D3.
- Do not keep an unused `bytes32 salt` (or equivalent namespace) parameter on production FactoryService component deploy helpers after the D3 identity is computed internally.
- Do not execute Script 24 or the Crane superchain fork test as a gate for this effort; compile them only (D10).

## Decisions (locked)

| ID | Decision | Status | Rationale |
|---|---|---|---|
| D1 | Remove creation-code and constructor-argument contributions from contract deployment salts through the CREATE3 Factory, including independently written and indirect formulas; exclude proxy deployment. | Decided | Owner requested correction everywhere within CREATE3 Factory deployment scope and explicitly ruled out changing how proxies are deployed. |
| D2 | Retain `ArtifactCreationCode.releaseSalt` with a single namespace argument and no bytecode/constructor parameters. | Decided (derived from owner direction) | Owner permits keeping the helper; the single argument makes the prohibited inputs unnecessary at every caller. |
| D3 | Standardize all component-name salts to `abi.encode(name)._hash()` via `BetterEfficientHashLib` (`using BetterEfficientHashLib for bytes`), including FullSpread. Linked libraries use their source-qualified artifact name as the single string identity with the same `_hash()`. IndexedEx scripts under `scripts/foundry/research/` follow this rule, not D11. Use `_hash()` for runtime salt hashing; D14 permits value-equal `keccak256(abi.encode(name))` constant initializers. | Decided | Owner explicitly chose the ABI-encoded name standard over preserving existing encodings; this supersedes FullSpread's earlier raw-name formula. Owner later classified research fixtures as IndexedEx deployment scripts, same as LocalTesting / RhTestnet / FeeDetf aliases. Owner then required `_hash()` as the written hash helper rather than builtin `keccak256`. |
| D4 | Proxy deployment is outside scope. Do not change `PkgArgs`, `calcSalt`, proxy initialization, or proxy deployment salt formulas. | Decided | Owner clarified that this effort concerns CREATE3 Factory contract deployments, not how proxies are deployed. The earlier instance-key question incorrectly broadened the scope and is withdrawn. |
| D5 | Separate this work from FullSpread and implement it after FullSpread validation. | Decided (scope separation) | Keeps global helper changes and preserved deployment-glue exceptions out of the liquidity-fix implementors' touch set. |
| D6 | Keep existing occupied-salt reuse semantics; remove contrary auto-new-address tests and document unchanged live deployments. | Decided (derived from D1 and factory behavior) | Removing code/constructor dependence cannot also promise that changed payloads select fresh addresses. |
| D7 | Correct already-broken archived scripts' salt expressions and accept documented source-level validation plus existing compile blockers; require compilation and tests for maintained callers. | Decided | Owner chose this validation boundary to keep unrelated archive repairs outside the salt-correction effort. |
| D8 | Correct every Crane CREATE3 package salt that still includes `PkgInit` or constructor data, including Crane-only tests and scripts; leave already-name-only Crane salts as inventory-only. | Decided | Owner chose to patch all Crane CREATE3 package salts rather than IndexedEx-only call sites. Proxy `deploy()`, CREATE2, and unrelated Crane internals remain excluded under D4. |
| D9 | Update the salt-formula rows in the funded-staking public deployment runbooks to D3; keep recorded hashes, addresses, and rehearsal results as historical with a note that they used the old formula. | Decided | Owner chose formula update plus retained history so operators do not follow the obsolete bytecode-sensitive row. |
| D10 | Add a hermetic IndexedEx test (`test/foundry/spec/protocols/l2s/superchain/SuperchainBridgeInfra_Create3Salt.t.sol`) that deploys the three superchain DFPkgs through the corrected Crane FactoryServices and asserts D3 salts, `PkgInit` delivery, and D6 reuse. Script 24 and the Crane fork test are compile-only. | Decided | Script 24 is a SuperSim broadcast script and the only Crane coverage is a fork test, so without this test the D8 corrections would have no hermetic runtime evidence. Owner chose an IndexedEx-side test over compile-only or a Crane-side test. |
| D11 | Tests and TestBases that call the CREATE3 factory or registry directly may keep explicit identity fields (pool address, scenario label) in a salt; they are inventory-only. Production FactoryServices, Init* services, and IndexedEx scripts (including `scripts/foundry/research/`) stay name-only under D3. No caller may hash creation code or the constructor blob. An explicit field that also appears among constructor arguments (a pool address) is permitted; hashing the encoded constructor blob is not. New runtime D11 keys this effort writes use `abi.encode(...)._hash()`; D14 permits `keccak256` in constant initializers. Existing D11 source encodings stay as inventoried. | Decided | Owner chose explicit test keys over one isolated factory per coexisting instance; per-pool adapter fixtures and variant-package tests keep working without changing production salt policy. Supersedes the earlier isolated-factory rule for those fixtures. Research fixtures are scripts, not tests, and follow D3. |
| D12 | Runtime in-scope CREATE3 salt expressions this effort writes hash through `BetterEfficientHashLib._hash`. Constant initializers may use Solidity `keccak256` under D14. Callers import the library and use `using BetterEfficientHashLib for bytes` so salts are `abi.encode(...)._hash()`. Do not call Solidity `keccak256` in runtime salt expressions. D8 already-name-only Crane inventory and existing D11 source encodings are not rewritten solely to replace `keccak256` with `_hash`. | Decided | Owner required `_hash` as the hash helper for this salt standard. `_hash(bytes)` is keccak256 of the encoded bytes, so `abi.encode(name)._hash()` equals `keccak256(abi.encode(name))` in value. |
| D13 | The compile-only gate for `TokenTransferRelayer_Superchain.t.sol` runs `forge build` from the `lib/crane` checkout with Crane's default profile, no fork profile, no RPC. | Decided (derived from repository configuration) | Crane's default `foundry.toml` sets `test = 'test'`, which includes `test/foundry/fork/`; IndexedEx's root build never compiles `lib/crane/test/`, so an IndexedEx-root gate cannot prove that file compiles. |
| D14 | Permit Solidity `keccak256` in constant initializers; the D12 restriction applies to runtime salt hashing. Keep existing D3-compliant `keccak256(abi.encode(name))` constants unchanged and inventory them as compliant. | Decided | Owner clarified that `keccak256` is allowed when setting a constant. This preserves the ABI-encoded name standard without forcing constants into runtime expressions; `_hash()` is not a valid Solidity constant initializer. |

## File sets and edit boundary

These sets describe permitted files, not permission to rewrite every file in a directory. Every source edit must have an inventory entry tied to R1–R5. A newly discovered producer/consumer is included only when its traced call path meets the PRD's existing scope. Record its exact path and disposition before editing it. Changes outside these bounded sets require a PRD update, not an invented architecture.

- **E — evidence (new):** `docs/create3-release-salt-input-inventory.md` and `docs/create3-release-salt-input-validation.md`. Update this plan's execution record and acceptance boxes only with supporting evidence.
- **C — core:** `contracts/utils/foundry/ArtifactCreationCode.sol`, the shared-helper consumers listed below, the three independent services, and both renamed FullSpread component services. Additional direct in-scope producers discovered under `contracts/` belong here; only deployment glue can change.
- **H — hooks:** the eleven `deployPackage(..., bytes32 salt)` services under `contracts/hooks/uniswap/v4/standardExchange/{orbital,weighted,constantProduct/single,dual,single,stable/quad/balancer,stable/quad/curve}/` and `contracts/hooks/uniswap/v4/{orbital,weighted,stable/quad/balancer,stable/quad/curve}/`. Update their Solidity callers in `contracts/`, `test/`, and `scripts/`, retaining the production helper path.
- **S — scripts:** salt producers/prediction consumers under `scripts/foundry/` and source-corrected producers under `scripts/archive/`; the PRD Discovery baseline and Step 4 enumerate known cases. Include importing stage wrappers as compilation roots. Preserve launch-state fingerprints and proxy/CREATE2 salts.
- **K — Crane:** `lib/crane/contracts/protocols/l2s/superchain/relayers/token/TokenTransferRelayerFactoryService.sol`, `lib/crane/contracts/protocols/l2s/superchain/registries/message/sender/ApprovedMessageSenderRegistryFactoryService.sol`, `lib/crane/contracts/protocols/l2s/superchain/registries/token/bridge/SuperChainBridgeTokenRegistryFactoryService.sol`, and `lib/crane/test/foundry/fork/protocols/l2s/superchain/TokenTransferRelayer_Superchain.t.sol`. Include equivalent forbidden-input producers discovered in Crane FactoryServices/tests/scripts under D1/D8; exclude primitives and unrelated vendored protocol internals. The root `lib/crane` gitlink is part of delivery.
- **T — regression sources:** the exact existing test files in Step 6, their existing TestBases for deployment-only adjustments, affected hook TestBases/TestDeployLib callers, and the new D10 file `test/foundry/spec/protocols/l2s/superchain/SuperchainBridgeInfra_Create3Salt.t.sol`. Equivalent contrary address-policy tests discovered in `test/` are included; no vault accounting changes.
- **D — documentation:** only the eight current-guidance/history files listed in Step 7. FullSpread's original evidence files are read-only; put new glue exceptions and hashes in E.

### Shared-helper consumer snapshot

Re-inventory at execution; this list is a starting point, not a fixed allowlist. It contains the observed 25 files/113 calls before this correction.

- `contracts/fee/collector/FeeCollectorFactoryService.sol`
- `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol`
- `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_FactoryService.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_FactoryService.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService.sol`
- `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_FactoryService.sol`
- `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProvider_FactoryService.sol`
- `contracts/protocols/dexes/camelot/v2/CamelotV2_Component_FactoryService.sol`
- `contracts/protocols/dexes/uniswap/v2/UniswapV2_Component_FactoryService.sol`
- `contracts/protocols/dexes/uniswap/v3/UniswapV3_Component_FactoryService.sol`
- `contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol`
- `contracts/protocols/lending/aave/v3.6/AaveV3Stata_Component_FactoryService.sol`
- `contracts/protocols/staking/etherfi/EtherFiWeETH_Component_FactoryService.sol`
- `contracts/protocols/staking/lido/LidoWstETH_Component_FactoryService.sol`
- `contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol`
- `contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Facet_FactoryService.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Pkg_FactoryService.sol`
- `contracts/vaults/standard/erc4626/ERC4626StandardExchange_Component_FactoryService.sol`
- `contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlue_Component_FactoryService.sol`
- `scripts/foundry/anvil_robinhood_main/Phase_06_Stage_03_CpBufferHookPkg.sol`
- `scripts/foundry/anvil_robinhood_main/Phase_06_Stage_04_WeightedBufferHookPkg.sol`
- `scripts/foundry/anvil_robinhood_main/Phase_06_Stage_05_OrbitalBufferHookPkg.sol`
- `scripts/foundry/anvil_robinhood_main/Phase_06_Stage_06_CurveQuadBufferHookPkg.sol`
- `scripts/foundry/anvil_robinhood_main/Phase_06_Stage_09_BalancerStableBufferHookPkg.sol`

## Work order

### Step 1: Verify the prerequisite and capture the execution baseline

- **Files:** create E; read FullSpread's PRD, plan, `VALIDATION.md`, `REGRESSION_RESULTS.txt`, `VALIDATED_ARTIFACTS.json`, `VERSION_SOURCE_MAP.json`, `PRESERVED_SOURCE_SHA256.json`, and `PRESERVED_BUILD_CONTEXT.json` beside that PRD. Read current root/Crane Git state and Foundry configs.
- **Do:** run V1. Require completed FullSpread validation whose recorded source fingerprints match the checkout, a successful feature regression log, and all 96 preserved hashes matching before this correction. If the prerequisite is absent or does not match, stop code changes and report the evidence mismatch; do not implement FullSpread as part of this plan. Record the starting revisions, working-tree diff/status, hashes of all eight evidence/PRD-plan records, source fingerprints, and preserved manifest/build context. Store snapshots outside tracked source and record their location; also record baseline hashes in E so final checks do not depend solely on the temporary snapshot.
- **Tests:** V1 is read-only. No prerequisite rerun is necessary when current source fingerprints and completion evidence match. If evidence is stale, this plan cannot claim the prerequisite passed.
- **Done when:** E identifies the exact validated starting sources, preserves unrelated work, and records a passing prerequisite check. Before any compile in a new/empty worktree, seed both `out/` and `cache_forge/` from a warm checkout using the actual paths in `foundry.toml`; never delete shared artifacts or change compiler paths/settings.

### Step 2: Build the complete inventory and verification inputs

- **Files:** E; inspect C/H/S/K/T and already-compliant producers.
- **Do:** run V2's searches and follow every call to the actual CREATE3 or proxy/CREATE2 primitive. Inventory direct salts, helper namespaces, library links, script predictions, caller-supplied hook salts, and constructor payloads. Use columns: inventory ID, source path, function, kind, factory call, current expression, replacement expression, code/constructor dependencies, consumers/predictions, disposition, validation/test evidence. Each entry has exactly one of the six PRD dispositions. Add the D7 `source-validated, compilation blocked` label only for already-broken archived callers, with the existing blocker and source evidence.
- **Do:** populate one fenced `json` block under `## Execution inputs` in the inventory. It contains `edited_sources` (all edited production Solidity sources in C/H/K, excluding tests/TestBases/scripts), `focused_test_roots` (Step 6's seven test files plus affected hermetic suites), `maintained_script_roots` (every affected producer and its maintained script entrypoints), `crane_hermetic_test_roots` (existing hermetic tests covering corrected Crane producers; empty only with a documented search result), and `preserved_glue_exceptions` (exact paths in the old preservation manifest that this correction changes). Arrays contain repository-relative paths, without globs; all exist by verification time. Script entrypoints can import edited stage libraries; record those edges, not just directly edited scripts. Keep this block synchronized with the inventory and final diff. It is verification input, not a separate backlog.
- **Do:** classify all six Robinhood Phase 02 package-salt constants as D3-compliant under D14. Preserve D8 name/label-only Crane salts and D11 direct test keys, including constructor fields used as explicit identity keys; forbid encoded constructor blobs and code contributions. Distinguish helper callers from direct test factory/registry callers. Record proxy/CREATE2 lookalikes as out of scope without changing them.
- **Tests:** verify each producer has a consumer/prediction entry and each correction has a test or compile/source-validation gate. Recount shared-helper calls for the record without treating 113 as a completion target.
- **Done when:** no discovered in-scope producer is unclassified; every source edit and verification root is traceable to an entry. R1's inventory breadth does not authorize unrelated runtime fixes.

### Step 3: Correct core helpers, component producers, and library linking

- **Files:** C and H. Independent files: `contracts/protocols/dexes/aerodrome/v1/Aerodrome_Component_FactoryService.sol`, `contracts/protocols/staking/rocket-pool/RocketPoolRETH_Component_FactoryService.sol`, `contracts/protocols/staking/rebasingVault/RebasingAwareERC4626_Component_FactoryService.sol`. FullSpread files: `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.sol` and the V4 counterpart in `v4/`.
- **Do:** change the shared API to `releaseSalt(bytes32 namespace_) internal pure returns (bytes32)` returning its argument; remove the old overload. Update all callers and their upstream namespaces together. FeeCollector passes only `abi.encode("FeeCollectorDFPkg")._hash()` to this helper; its encoded `PkgInit` still goes to deployment. Independent services use the same D3 identity. RebasingAware's helper becomes `releaseSalt(string memory componentName)` with no release ID, code, or constructor arguments; preserve the package's separate `releaseIdentifier()` and stage runtime checks.
- **Do:** in `_linkSource`, replace the library salt with `abi.encode(id_)._hash()`, where `id_` is the existing full `source:Library` identifier. Preserve recursive artifact resolution, linking, validation, and deployment payloads. Update source comments that incorrectly promise code-sensitive addresses or automatic replacement. `_matchesSource` and verification-only hashes are not salt producers and do not need this normalization.
- **Do:** replace all eleven hook helper `salt` parameters with their internal DFPkg identifier expression, including helpers currently forwarding `salt` straight to registry `deployPkg`. Drop the argument at every caller while retaining helper use. Do not add test namespace overloads. For FullSpread, changing runtime `keccak256(abi.encode(name))` to `_hash()` must preserve the bytes32. For preserved V3/V4, edit only component deployment glue; list the manifest exceptions in E.
- **Tests:** implement Step 6 before running V3; do not compile while shared signatures and their callers are deliberately inconsistent between steps. Inspect the final call graph to confirm deployment payloads remain unchanged.
- **Done when:** all shared calls have one salt-helper argument, no in-scope indirect code/constructor contribution remains, independent helpers agree with D3, and all hook helper callers match the new signatures.

### Step 4: Normalize script aliases and update their consumers

- **Files:** S plus H's test/TestBase call sites. Source-correct archived callers under D7; preserve the six Phase 02 constants.
- **Do:** apply the exact identity replacements in PRD R2 and its Discovery baseline. Required groups are Robinhood main/testnet Phase 06 hook stages and Phase 07 core test-token components; main Phase 06 Stage 10's RebasingAware helper; `PoolSeedLib.sol`; bond-NFT `ERC721Facet` aliases; fee-DETF Scripts 07/08; local-testing Scripts 03/06/12; SuperSim Base Scripts 03B/03C; sepolia Script 07 and its archived equivalent; both named research fixtures; and SuperSim Script 24. The artifact contract identifier governs: notably `BasicAuthorizerMock`, `Pool`, `PoolFactory`, `FactoryRegistry`, `Router`, `WeightedPoolFactory`, `PoolManager`, and `UniswapV4LiquiditySeeder`. No interface aliases, release namespaces, or chain labels remain in D3 component salts.
- **Do:** Script 24's three package salts lose `pkgInitArgs`; `_deployFacet` uses runtime `_hash()`. Keep its deployment payloads, runtime-artifact preparation, and compile-only status. Update predictions to exactly the corrected salt. When downstream diamond predictions change because a package address changed, pass that address to the existing prediction API; do not alter proxy formulas or hook mining.
- **Do:** hook callers using `"v1"`, `"pons"`, `"AnvilFeeDetf"`, or `FixtureEconomics.SALT_NS` through production helpers drop the salt argument. This includes the Weighted, Balancer Quad, and Curve Quad `*TestDeployLib.sol` files under `test/foundry/spec/hooks/uniswap/v4/standardExchange/`. Direct D11 instance keys remain unchanged. Keep token `deployToken`/`optionalSalt`, Pons CREATE2, CREATE3-factory bootstrap CREATE2, and verification fingerprints untouched.
- **Tests:** V4 compiles every maintained affected script/root and prepares runtime artifacts; archive entries receive D7 source evidence. Step 6 preserves stage rejection tests.
- **Done when:** each script/prediction inventory row has the exact replacement and unchanged payload/routing, all helper callers compile, and no script has been run or broadcast.

### Step 5: Correct Crane producers and add the hermetic bridge test

- **Files:** K, E, and new `test/foundry/spec/protocols/l2s/superchain/SuperchainBridgeInfra_Create3Salt.t.sol`.
- **Do:** correct the three Crane superchain package helper salts and the fork test's `ERC20PermitDFPkg` salt to `abi.encode(<deployed contract identifier>)._hash()`. Preserve `abi.encode(pkgInit)` as the constructor payload. Correct equivalent forbidden-input producers found during Step 2; do not normalize already-name-only Crane code.
- **Do:** the new test inherits `IndexedexTest, DeployPermit2`, calls parent setup and `deployPermit2()`, uses `multiStepOwnableFacet`, `AccessFacetFactoryService.deployOperableFacet(create3Factory)`, and each service's own `deploy*Facet(create3Factory)`. Pass operable only to the registry packages and canonical Permit2 only to the relayer. Use the precise helper signatures and public immutable names from PRD R5.
- **Tests:** for each of the three packages assert the expected address with `Creation._create3AddressFromOf(address(create3Factory), abi.encode(name)._hash())`, all initial bindings, and repeat deployment with changed `PkgInit` reusing the address and original bindings. For the changed inputs, deploy a second real `MultiStepOwnableFacet` directly with the D11 key `abi.encode("SuperchainBridgeInfra_Create3Salt.alternateOwnable")._hash()` and change only `ownableFacet`; keep every other dependency real and nonzero. Recompute Script 24's expected expression from the literal name inside the test; do not import, inherit, instantiate, or execute Script 24. Verify factory package registration through its existing registry query surface.
- **Tests:** V3 runs the new hermetic suite; V4 builds Crane with its default profile and records successful compilation of the fork source without RPC/setup/test execution. Run an existing Crane hermetic suite only when Step 2 finds coverage of a corrected producer.
- **Done when:** all three real helper paths pass identity, initial binding, and reuse assertions; both compile-only sources have successful evidence. When preparing the implementation change set, commit only this effort's Crane changes, record that revision, and update the root gitlink to it; leave unrelated submodule changes untouched. Deliver the Crane revision with the root change set, not as a deferred follow-up. This plan does not authorize a live deployment or automatic merge.

### Step 6: Complete helper, occupied-address, and constructor regressions

- **Files:** T and E. Extend these existing files; add test functions without changing product runtime code:

| Coverage | Existing test file / required change |
|---|---|
| Shared helper and automatic libraries | `test/foundry/spec/utils/foundry/ArtifactCreationCode.t.sol`: namespace passthrough, D3 vs raw/packed vectors, repeat/distinct identities, real deployment with different payloads at one identity, fresh and occupied library links, recursive links, source-qualified identity separation, and retained loader failure cases. |
| Facet/package reuse and stage checks | `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_FacetPackaging.t.sol`: replace the two contrary address-change tests with exact reuse assertions; preserve all stage rejection behavior. |
| Nested FeeCollector namespace | `test/foundry/spec/fee/collector/FeeCollectorProxy_Selectors.t.sol`: add real factory package salt, constructor-delivery, and changed-input reuse assertions; use `facetAddresses()`/`facetCuts()` to observe private constructor-bound facets, without mocking the package. |
| Independent Aerodrome service | `test/foundry/spec/protocol/dexes/aerodrome/v1/AerodromeStandardExchange_DeployWithPool.t.sol`: canonical facet/package prediction, manager registration, constructor bindings visible through package cuts and a real proxy, and reuse under a changed facet binding. |
| Independent RocketPool service | `test/foundry/spec/protocol/staking/rocket-pool/RocketPoolRETHStandardExchange_Core.t.sol`: canonical prediction, package public immutable bindings, manager registration, and changed-input reuse. |
| Independent RebasingAware service | `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Packaging.t.sol`: local helper vectors without `RELEASE_ID`, canonical package address, real initial bindings, and changed-input reuse; retain packaging/launch-compatibility checks. |
| Crane superchain services | New D10 test from Step 5. |

- **Do:** use actual factory/manager/registry APIs, existing TestBases, interface `PkgInit` types, real nonzero facets, and exact assertions. For independent package reuse tests, change one valid facet binding using a second real facet deployed under an explicit D11 test key; the production helper must still return the first package with its original bindings. Do not change economic assertions to make the tests pass.
- **Do:** keep the package-reuse test on the existing DETF TestBase; it already installs the first correct package. Put the legacy-first facet-shadow regression in an additional `CraneTest`-derived test contract in the same file so inherited DETF setup cannot occupy the canonical `RebasingClaimTokenFacet` salt first. Predeploy the existing real `ERC20Facet` payload into that name salt, call the corrected helper, and assert exact address/runtime reuse. No SUT `vm.etch` or mock.
- **Do:** for the wrong-dependency test deploy a real `RebasingClaimTokenDFPkg` directly with its wrong-bound `PkgInit` and `abi.encode("UniswapV4Detf_FacetPackaging.wrongClaimFacet")._hash()`. Preserve the stage's existing stale-dependency revert and zero `uniV4DetfPkg`; do not call the now-idempotent production helper to obtain that variant.
- **Do:** library tests use existing production math artifacts. Use the constant-product hook math as the intended library and weighted-buffer hook math as a distinct payload for an occupied source-qualified salt. Predeploy via CREATE3, then invoke the real artifact loader; assert the patched address and unchanged occupied runtime. In the fresh case, execute the intended math's existing `toWad` check. Keep test cases isolated through normal Foundry test state reset. Do not rewrite artifact JSON or add fake loader/factory implementations.
- **Do:** preserve all D11 composition/pool-adapter keys named in R5, their distinct addresses/bindings, and composed-route assertions. When constructor address inputs change, update predictions only through existing APIs. Preserve FullSpread's existing all-component name-salt assertions; `_hash()` produces equal values.
- **Tests:** run V3 after Steps 3–6 compile together. Extend inventory coverage mapping to existing affected suites; V5's full hermetic gate covers those beyond the focused tests. Retain existing declaration/selector/registration assertions and use Crane Behaviors for standards checks.
- **Done when:** every corrected producer class has real-path evidence, occupied salts never claim replacement, and unchanged proxy formulas/preserved economic code are verified against the baseline.

### Step 7: Reconcile guidance and preserve historical evidence

- **Files:** `docs/testing/ARTIFACT_BUILDS.md`, `docs/agent/INDEXEDEX_AGENT_LAW.md`, `docs/factory-service-artifact-creation-bytecode.md`, `docs/factory-service-artifact-creation-bytecode.plan.md`, `docs/security/universal-detf-audit/release-review/MIGRATION.md`, `docs/security/universal-detf-audit/release-review/RELEASE_REVIEW.md`, `implementation-artifacts/detf-funded-staking/production-readiness/PUBLIC_DEPLOYMENT_RUNBOOK.md`, `implementation-artifacts/detf-funded-staking/production-readiness/before-final-acceptance-closure/PUBLIC_DEPLOYMENT_RUNBOOK.md`, and E.
- **Do:** replace current contrary salt guidance with D3, D12, and D14 while preserving artifact-loading/constructor-delivery requirements. Mark obsolete candidate salt patches superseded. Update the two runbooks' formula rows; retain hashes/addresses/rehearsal results and annotate that their records used the old formula. Explain occupied reuse and package-address-driven downstream prediction changes; make no migration or deployment claim.
- **Do:** preserve all original FullSpread evidence bytes, including its preservation manifest/build context. In E, list every changed preserved deployment-glue source, its prior/new hash, inventory ID, and reason. All other preserved source hashes must match the old manifest. Record updated FullSpread glue hashes separately; do not rewrite its old validation evidence after this effort changes salt style/linking.
- **Tests:** inspect the closed eight-file guidance list and compare all preserved evidence hashes with Step 1. Historical `source-before/` copies and other rehearsal/test snapshots remain untouched.
- **Done when:** active guidance agrees with the new salts and exceptions, and historical evidence remains distinguishable and byte-preserved where required.

### Step 8: Run final gates and close the evidence

- **Files:** E, this plan's completion record, and the `lib/crane` gitlink when packaging the completed work.
- **Do:** execute V4 and V5 serially after the final source changes. Re-run a prior gate only if a later change affects its result. Record command arguments, cwd/profile/compiler settings, exit codes, test/suite counts, source and working-tree fingerprints, expected salt vectors/addresses, and coverage per inventory ID. Record D7 exceptions explicitly; do not describe archived blocked sources as compiled.
- **Do:** compare final source changes with the captured baseline. Check no proxy formula, economic runtime, CREATE2/hook-mining path, or excluded test-key encoding changed. Reconcile the execution-input JSON with the final diff and producer inventory. Record successful default-profile root build, runtime-artifact refresh, hermetic tests, maintained script builds, and Crane build separately.
- **Tests:** V5's complete CI gate must pass; focused success is insufficient. A pre-existing maintained-source or default-gate failure cannot use D7's archive exception. Report such a failure with evidence and leave acceptance incomplete; do not weaken gates or repair unrelated product behavior without a scope decision.
- **Done when:** all 37 acceptance criteria below have exact evidence references, only bounded scope was changed, preserved-source exceptions are limited to deployment glue, and both repository revisions are deliverable. No live deployment, address-registry repointing, or broadcast has occurred.

## Acceptance criteria

The following criteria are copied from the reviewed PRD in requirement order. `R<number>.<ordinal>` maps each checkbox to the source requirement. Keep their semantics intact; the work-order details above select files and verification mechanics without weakening them.

- [x] **AC01 (R1.1)** Record the inventory in `docs/create3-release-salt-input-inventory.md`: source path, function, deployment kind, factory call, current salt expression, replacement expression, constructor/bytecode dependencies, corresponding prediction/stage/test callers, and disposition (exactly one of: D3 correction, D3 style correction, D3 compliant inventory-only, D8 already-name-only inventory-only, D11 explicit-key inventory-only, or out of scope), plus the D7 label `source-validated, compilation blocked` on archived entries that requirement 5 covers. IndexedEx producers whose current salt is already written as `abi.encode(name)._hash()` (or the equal `abi.encode(type(C).name)._hash()`), and Crane producers whose current salt is already that `_hash()` encoding, use D3 compliant inventory-only with unchanged replacement expressions. IndexedEx production FactoryServices, Init* services, and scripts using runtime Solidity `keccak256(abi.encode(name))` are D3 style corrections: rewrite to `abi.encode(name)._hash()` without changing the bytes32. Direct test/TestBase `keccak256(abi.encode(name))` encodings stay D11 inventory-only under D12; do not rewrite them solely to swap the hash helper. Constant initializers using `keccak256(abi.encode(name))` are D3 compliant inventory-only under D14; retain their declarations and values. Known compliant constants: `CREATE3_FACTORY_PACKAGE_SALT`, `CALL_TARGET_REGISTRY_PACKAGE_SALT`, and `BOUNTY_BOARD_PACKAGE_SALT` in `scripts/foundry/anvil_robinhood_main/Phase_02_Stage_02_DiamondPackageFactory.sol` and `scripts/foundry/anvil_robinhood_testnet/Phase_02_Stage_02_DiamondPackageFactory.sol`. The renamed FullSpread services, whose own PRD (D22 there) lands runtime `keccak256(abi.encode("<new contract name>"))`, remain style corrections to `_hash()`. Crane salts that contain only name/label inputs and no creation bytecode, `PkgInit`, or constructor data but are packed or version-labeled use D8 already-name-only inventory-only and keep their current expression. Both remain in scope for inventory without requiring source edits.

- [x] **AC02 (R1.2)** Search `contracts/`, `scripts/` (including archived scripts), `test/`, and `lib/crane/` FactoryServices, Init* services, tests, and scripts. Follow component deployment wrappers through `create3`, `create3WithArgs`, `deployFacet`, `deployPackageWithArgs`, registry `deployPkg`, and automatic library linking to the CREATE3 Factory. Include direct expressions without the name `releaseSalt` and dependencies hidden inside a namespace passed to another helper. Do not inventory unrelated Crane vendored protocol internals, CREATE2 formulas, storage-slot hashes, or proxy `deploy()`. Do not expand this inventory into a redesign of proxy deployment.

- [x] **AC03 (R1.3)** Every in-scope bytecode/constructor-dependent salt has a correction and validation entry. Exclude proxy deployment and its `PkgArgs`/`calcSalt` paths, actual CREATE2 deployment/address formulas, and hashes used only for runtime/constructor verification. A text-search count alone cannot establish completion.

- [x] **AC04 (R1.4)** The 2026-09-16 review checkout contains 113 `ArtifactCreationCode.releaseSalt` call sites in 25 IndexedEx Solidity files (108 calls in 20 files under `contracts/`, five calls in five files under `scripts/`). The earlier 139-call/27-file figure is historical. Recompute against the execution checkout after FullSpread; these counts are discovery snapshots, not a required minimum or fixed allowlist. Include independent, already-name-only, and nested producers too.

- [x] **AC05 (R2.1)** In `contracts/utils/foundry/ArtifactCreationCode.sol`, use `releaseSalt(bytes32 namespace_) internal pure returns (bytes32)` returning `namespace_` unchanged. Remove the bytecode/constructor parameters and the old three-argument overload; callers must stop supplying those values to the salt helper.

- [x] **AC06 (R2.2)** Preserve the three `*_PACKAGE_SALT` constant declarations and their uses in each Robinhood main/testnet `Phase_02_Stage_02_DiamondPackageFactory.sol` library. Their `keccak256(abi.encode(<contract identifier>))` initializers already satisfy D3 and D14. Inventory all six as compliant with unchanged replacement expressions; do not inline them or convert them to runtime helpers solely to use `_hash()`. For any newly written in-scope constant salt, `keccak256` is permitted but D3's ABI-encoded identity and D1's prohibited-input rules still apply; the existing D8/D11 exceptions remain unchanged.

- [x] **AC07 (R2.3)** Continue passing creation code and ABI-encoded constructor arguments to deployment functions in their existing order. Artifact loading, linking, missing/empty/unresolved-bytecode failures, and constructor initialization remain functional.

- [x] **AC08 (R2.4)** Constructor data cannot enter the helper indirectly. For example, replace the fee collector's `abi.encode("FeeCollectorDFPkg", pkgInitArgs)._hash()` namespace with `abi.encode("FeeCollectorDFPkg")._hash()` before calling the namespace-only helper.

- [x] **AC09 (R2.5)** Under confirmed decision D3, the final salt for every named facet, execution delegate, and DFPkg deployed by IndexedEx production FactoryServices, Init* services, deployment scripts, and script libraries has exactly the value of `abi.encode(name)._hash()`, where `name` is its Solidity contract identifier and `_hash` is `BetterEfficientHashLib._hash(bytes)` (`using BetterEfficientHashLib for bytes`). Do not use Solidity `keccak256` for runtime salt hashing; D14 permits the value-equal `keccak256(abi.encode(name))` in constant initializers. Standardize raw-name and packed-name hashes in those IndexedEx callers too, even when they already exclude code/constructor inputs, including `DetfFacetFactoryService` / `DetfPkgFactoryService` `keccak256("DETFFundedBondMetadataFacet")` and `keccak256("DETFSYFacet")` / `keccak256("DETFSYDFPkg")`. FullSpread uses its new contract identifiers with this same encoding; the earlier raw-name formula is superseded. Direct test/TestBase callers with explicit keys follow D11, including its retained raw/packed test labels. Crane already-name-only salts stay inventory-only under D8: do not re-encode Crane FactoryServices, InitDevService / InitBcService constants, or Crane scripts/tests whose salts contain only name/label inputs and no creation bytecode, `PkgInit`, or constructor data, even when those Crane salts are packed or version-labeled (`keccak256("bc-promo-UniV2Factory-v1")` and equivalents).

- [x] **AC10 (R2.6)** D3 component-name salts do not add release-label fields, caller-supplied package namespaces, or another hash layer. Production callers of the shared helper pass `abi.encode(name)._hash()` or its value-equal D14 constant; the helper returns it unchanged. D11 test namespaces remain subject to the prohibition on creation-code and constructor-blob hashing. Production component helpers drop obsolete salt inputs from their signatures. In particular, every IndexedEx hook `deployPackage(..., bytes32 salt)` (standard-exchange Orbital, Weighted, constant-product single, Dual, leftover single buffer, Balancer Quad, Curve Quad, and non-SE orbital/weighted/balancer/curve swap packages) loses the `salt` argument and computes `abi.encode(<DFPkg identifier>)._hash()` internally, whether it currently wraps `ArtifactCreationCode.releaseSalt` or forwards `salt` to `deployPkg`. Callers that currently pass `abi.encode(type(I*Pkg).name, "v1")._hash()`, `keccak256(abi.encode(type(I*Pkg).name, "v1"))`, `abi.encode(type(I*Pkg).name, FixtureEconomics.SALT_NS)._hash()`, `abi.encode(type(I*Pkg).name, "pons")._hash()`, or any other caller namespace through that helper stop supplying a salt and stay on the helper. Those TestBase helper calls are D3 production-helper callers, not D11. A test that needs a second, differently initialized package uses D11 by calling the factory or registry directly. This does not change proxy deployment interfaces or arguments.

- [x] **AC11 (R2.7)** Apply D3 to the other named non-proxy contracts in IndexedEx production scripts and FactoryServices too: routers, pool managers/factories, seeders, and deployment infrastructure use their Solidity contract identifier as `name`, not a chain label, fixture label, interface alias, or release alias. Hook stages and FactoryServices use the deployed DFPkg or facet identifier from the artifact id (for example `UniswapV4StandardExchangeOrbitalBufferHookDFPkg`), not `type(I*Pkg).name` and not `FixtureEconomics.SALT_NS`. `PoolSeedLib.ensureSeeder` uses `UniswapV4LiquiditySeeder` (`abi.encode("UniswapV4LiquiditySeeder")._hash()`), replacing `keccak256(abi.encode(FixtureEconomics.SALT_NS, "V4LiquiditySeeder"))`. IndexedEx scripts that deploy `ERC721Facet` or other named components with release aliases (`keccak256("FeeDetf_ERC721Facet")`, `keccak256("RhTestnet_ERC721Facet")`, `keccak256("RhMain_ERC721Facet")`, `keccak256("LocalTestingScenario3_ERC721Facet")`, `keccak256("LocalTestingScenario3WeightedPoolFactory")`, `keccak256("LocalTestingScenario3PoolManager")`, `keccak256("LocalTestingScenario3LiquiditySeeder")`, and `abi.encode("ERC20MintBurnOwnableFacet", FixtureEconomics.SALT_NS)._hash()` / the matching DFPkg in `Phase_07_Stage_01_CoreTestTokens`) become `abi.encode(<contract identifier>)._hash()`. The identifier is the contract name in the artifact id the same call loads. Explicit replacements for the remaining maintained alias producers: `scripts/foundry/local_testing/anvil_single/Script_03_DeployBaseProtocols.s.sol` `_salt("LocalTestingWETH9")` → `_salt("WETH9")`, `_salt("LocalTestingBetterPermit2")` → `_salt("BetterPermit2")`, `_salt("LocalTestingUniV2Factory")` → `_salt("UniV2Factory")`, `_salt("LocalTestingUniV2Router02")` → `_salt("UniV2Router02")`, `_salt("LocalTestingBalancerV3Authorizer")` → `_salt("BasicAuthorizerMock")` (that call loads `BasicAuthorizerMock.sol:BasicAuthorizerMock`), and its `abi.encode("SenderGuardFacet", "LocalTesting")._hash()` → `abi.encode("SenderGuardFacet")._hash()`; `scripts/foundry/supersim/base/Script_03B_DeployBalancerV3Core.s.sol` `_salt("BaseSepoliaBalancerV3Authorizer")` → `_salt("BasicAuthorizerMock")` (same `BasicAuthorizerMock.sol:BasicAuthorizerMock` artifact; its `_salt("BalancerV3VaultDFPkg")` / `_salt("BalancerV3RouterDFPkg")` calls stay D3); `scripts/foundry/supersim/base/Script_03C_DeployAerodromeCore.s.sol` `_salt("BaseSepoliaAerodromePoolImplementation")` → `_salt("Pool")` (`Pool.sol:Pool`), `_salt("BaseSepoliaAerodromePoolFactory")` → `_salt("PoolFactory")` (`PoolFactory.sol:PoolFactory`), `_salt("BaseSepoliaAerodromeFactoryRegistry")` → `_salt("FactoryRegistry")` (`FactoryRegistry.sol:FactoryRegistry`), `_salt("BaseSepoliaAerodromeRouter")` → `_salt("Router")` (`Router.sol:Router`); `Script_12_DeployScenario3Overlay.s.sol` `LocalTestingScenario3WeightedPoolFactory` → `WeightedPoolFactory`, `LocalTestingScenario3PoolManager` → `PoolManager`, `LocalTestingScenario3LiquiditySeeder` → `UniswapV4LiquiditySeeder`, `LocalTestingScenario3_ERC721Facet` → `ERC721Facet`; `scripts/foundry/local_testing/anvil_single/Script_06_DeployFoundationAssets.s.sol` `abi.encode("ERC20MintBurnOwnableFacet", "LocalTesting")._hash()`, `abi.encode("ERC20MintBurnOwnableOperableDFPkg", "LocalTesting")._hash()`, `abi.encode("ERC20MinterFacadeFacetDFPkg", "LocalTesting")._hash()`, and `abi.encode("ERC20PermitDFPkg", "LocalTestingRich")._hash()` drop the second field; `scripts/foundry/anvil_robinhood_testnet/Phase_04_Stage_02_Erc20MinterFacade.sol` `abi.encode("ERC20MinterFacadeFacetDFPkg", FixtureEconomics.SALT_NS)._hash()` → `abi.encode("ERC20MinterFacadeFacetDFPkg")._hash()`; `scripts/foundry/anvil_sepolia/Script_07_DeployTestTokens.s.sol` `abi.encode("ERC20PermitDFPkg", "DemoRichToken")._hash()` → `abi.encode("ERC20PermitDFPkg")._hash()`. No maintained script tree deploys the same named DFPkg twice with different `PkgInit`, so dropping these aliases does not merge two intended packages. The archived `scripts/archive/foundry/sepolia/Script_07_DeployTestTokens.s.sol` `abi.encode(type(ERC20PermitDFPkg).name, "DemoRichToken")._hash()` receives the same D3 replacement under D7 (source-validated, compilation blocked). The same D3 rule applies to IndexedEx research fixtures under `scripts/foundry/research/` that call the CREATE3 factory or registry directly with scenario labels: `keccak256("ResearchDetfSingleSe_ERC721Facet")` becomes `abi.encode("ERC721Facet")._hash()`; `keccak256("ResearchDetfSingleSe_RateProviderFacet")` and `keccak256("Research_StandardExchangeRateProviderFacet_WethUsdc")` become `abi.encode("StandardExchangeRateProviderFacet")._hash()`; `keccak256("ResearchDetfSingleSe_RateProviderDFPkg")` and `keccak256("Research_StandardExchangeRateProviderDFPkg_WethUsdc")` become `abi.encode("StandardExchangeRateProviderDFPkg")._hash()`; `abi.encodePacked("ResearchDetfSingleSe_WeightedPoolFactory")._hash()` becomes `abi.encode("WeightedPoolFactory")._hash()`. Those research callers are D3 scripts, not D11, even though they call the factory directly. Token-proxy salts passed to `deployToken` remain out of scope under D4. Automatic libraries retain requirement 3's source-qualified identity. Direct CREATE3 factory or registry calls in tests and TestBases follow D11 instead, including `keccak256("Uv4Detf_ERC721Facet")` in `TestBase_UniswapV4Detf.sol` and `TestBase_UniswapV4Detf_Decimals.sol`, and `keccak256("PonsUv4Detf_ERC721Facet")`. Record the identity string explicitly in each inventory entry; do not infer it from `vm.label`, an interface type name, or package metadata when those differ from the contract identifier.

- [x] **AC12 (R3.1)** Correct independent formulas in `contracts/protocols/dexes/aerodrome/v1/Aerodrome_Component_FactoryService.sol`, `contracts/protocols/staking/rocket-pool/RocketPoolRETH_Component_FactoryService.sol`, and `contracts/protocols/staking/rebasingVault/RebasingAwareERC4626_Component_FactoryService.sol` to `abi.encode(componentName)._hash()`. RebasingAware's local helper becomes `releaseSalt(string memory componentName)` returning `abi.encode(componentName)._hash()` and drops `RELEASE_ID`, code, and constructor arguments from salt derivation. Those files import `BetterEfficientHashLib` and `using BetterEfficientHashLib for bytes` if they do not already.

- [x] **AC13 (R3.2)** Correct `ArtifactCreationCode._linkSource`: library salt becomes `abi.encode(id_)._hash()`, using the full source-qualified artifact name as the library identity to distinguish same-named libraries from different sources. It excludes the extra `IndexedEx.ArtifactLibrary` field, linked/unlinked bytecode hashes, and compiler-selected library addresses. This uses the same single-string ABI-encoded `_hash()` as other component-name salts. `ArtifactCreationCode` imports `BetterEfficientHashLib` for this call. Do not use Solidity `keccak256` in `_linkSource`.

- [x] **AC14 (R3.3)** Correct CREATE3 script paths, including `scripts/foundry/supersim/Script_24_DeploySuperchainBridgeInfra.s.sol`, where package salts directly include `pkgInitArgs`; changing the shared helper cannot reach those expressions. Script 24's `_deployFacet` helper uses runtime `keccak256(abi.encode(name))` and is a D3 style correction to `abi.encode(name)._hash()`. Update the five shared-helper hook stages and the RebasingAware stage's local-helper calls.

- [x] **AC15 (R3.4)** Under D8, correct every Crane CREATE3 package salt that still includes `PkgInit` or constructor data. Known producers: `lib/crane/contracts/protocols/l2s/superchain/relayers/token/TokenTransferRelayerFactoryService.sol`, `.../registries/message/sender/ApprovedMessageSenderRegistryFactoryService.sol`, `.../registries/token/bridge/SuperChainBridgeTokenRegistryFactoryService.sol`, and `lib/crane/test/foundry/fork/protocols/l2s/superchain/TokenTransferRelayer_Superchain.t.sol` (`ERC20PermitDFPkg`). Replacement salt is `abi.encode(name)._hash()` with the deployed contract identifier. Constructor arguments remain the `deployPackageWithArgs` payload. Already-name-only Crane salts (`abi.encode(type(C).name)._hash()` / `keccak256(abi.encode(type(C).name))` in Access, Introspection, Gyro, ERC4626RateProvider, InitDevService, InitBcService, and equivalent) stay inventory-only. This effort includes those Crane source edits and the IndexedEx submodule pin; it is not a follow-up Crane PR.

- [x] **AC16 (R3.5)** Correct equivalent in-scope producers discovered by requirement 1, including TestBases and deployment fixtures. Do not retain constructor-derived component namespaces merely because they predate `ArtifactCreationCode` or live under `lib/crane/`. D11 explicit test identity fields remain permitted even when the same field is also passed to a constructor; encoding or hashing the constructor blob remains forbidden.

- [x] **AC17 (R3.6)** Keep constructor/runtime fingerprints used exclusively to validate a deployment or record evidence. They must not contribute to an in-scope CREATE3 Factory deployment salt or select an implicit replacement namespace. Preserve CREATE3's underlying address algorithm, including its fixed intermediate deployment-proxy code hash; this requirement targets the supplied component salt, not the factory primitive.

- [x] **AC18 (R4.1)** The implementation diff makes no changes to proxy deployment algorithms, `PkgArgs`, `calcSalt`, `processArgs`, proxy initialization, or proxy salt derivation. Proxy paths remain excluded even if they use CREATE3 internally.

- [x] **AC19 (R4.2)** Distinguish deployment of a DFPkg contract through the CREATE3 Factory (in scope) from deployment of a proxy using that package (out of scope). Package-constructor `PkgInit` data must no longer contribute to the package contract's salt, but must still reach its constructor. Proxy `PkgArgs` are not an input to this correction.

- [x] **AC20 (R4.3)** Do not modify actual CREATE2 address computation, initcode hashing required by CREATE2, or hook flag mining. Classify a deployment by its actual call path and deployed contract rather than by a nearby CREATE3 name.

- [x] **AC21 (R4.4)** Unchanged proxy deployment means unchanged code and formulas, not a guarantee of identical predicted addresses when their inputs change. `DiamondPackageCallBackFactory` incorporates the package address into its existing salt formula; a corrected package address can therefore change downstream proxy predictions with identical `PkgArgs`. Update affected prediction fixtures by supplying the corrected package address to the existing prediction API, without modifying the proxy formula or adding compatibility salts. Document this consequence in the validation evidence; do not generalize it to hook paths whose existing formulas exclude the package address.

- [x] **AC22 (R5.1)** Extend `test/foundry/spec/utils/foundry/ArtifactCreationCode.t.sol` for the helper and library-linking changes. With a fixed source-qualified library identity, different library creation code yields the same salt; deployment on a fresh factory still links and executes the intended library.

- [x] **AC23 (R5.2)** Exercise corrected facets and packages through real CREATE3/manager/registry paths. Assert exact expected salt/address identity, correct runtime or immutable bindings on a fresh deployment, and constructor arguments still delivered intact. Use existing production TestBases; do not mock the factory, registry, package, or vault.

- [x] **AC24 (R5.3)** With a fixed namespace and factory, changing creation code or constructor arguments must not change the computed salt/address. Existing occupied-salt reuse behavior remains: a second deployment returns the existing contract without replacing its code or rerunning its constructor. Tests must assert that existing bindings remain unchanged rather than pretending the second payload was installed.

- [x] **AC25 (R5.4)** Update `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_FacetPackaging.t.sol` and any equivalent tests that currently require constructor-sensitive addresses or automatic isolation from an occupied name salt. Rewrite `test_releaseSalt_legacyFacetDoesNotShadowCurrentFacet` and `test_releaseSalt_constructorChangeCreatesNewPackage` into D6 reuse assertions: the canonical name salt returns the existing contract and its bindings are unchanged. Production component helpers keep canonical name salts and gain no test namespace parameters. A test that needs a second, differently initialized deployment of a named component obtains it under D11 by calling `create3Factory.deployPackageWithArgs`, `create3WithArgs`, or registry `deployPkg` directly with an explicit test-key salt of the form `abi.encode("<TestContract>.<scenario>")._hash()`, never a salt that hashes creation code or the constructor blob. New D11 keys computed at runtime use `_hash()`; D14 permits `keccak256` in constant initializers. For occupied-salt regressions, deploy the first payload before invoking the corrected helper in that setup; do not let inherited setup populate the slot with the current implementation first. Pure namespace-helper and factory-primitive tests may use explicit test namespaces, but those do not establish component-name policy compliance.

- [x] **AC26 (R5.5)** Preserve fixtures that require differently initialized instances of the same named contract to coexist in one test. Under D11, `contracts/test/bases/TestBase_FundedComposedDETF.sol` `_poolAdapter` keeps its explicit pool-keyed salt `keccak256(abi.encode("funded-composed-adapter", pool_))` for the `composedStable` and `composedCommon` `BalancerV3SinglePoolStandardExchange` adapters, and `_deployInnerPools` keeps `keccak256("FundedComposedStableFactory")` for the `StablePoolFactory`. The equivalent per-pool adapter deployments in `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/TestBase_ComposedStableCommonDetf_Decimals.sol`, `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_IntegratedDeploy.t.sol`, `test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol`, and `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/decimals/adversarial/Adversarial_BalancerV3SinglePoolSE_Decimals.sol` keep theirs, as does the variant package salt `keccak256("V2.revertingAdvisoryOracle")` in `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v4/UniswapV4FullSpreadStandardExchangeVault_TwapPoke.t.sol` and the packed `IndexedexBalancerV3WeightedPoolFactory` label in `contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol` `_createPoolFactory`. These callers are inventory-only: record each with its explicit key and confirm by source inspection that no creation-code or constructor-blob hash enters the salt. Do not convert them to canonical name salts, add isolated factories, modify adapter runtime code, or split away the composition test. Existing assertions on distinct adapter addresses, exact `pool`, `bptToken`, and `router` bindings, and composed routes remain in force. Record equivalent explicit-key callers and their inspection result in the inventory.

- [x] **AC27 (R5.6)** Preserve `test_releaseStage_wrongDependencyImplementationRejected` and the other stage rejection assertions. Its current setup redeploys `RebasingClaimTokenDFPkg` with a different facet binding after the correct package already exists, which will reuse the correct package under D6. Construct the wrong-bound real `RebasingClaimTokenDFPkg` through a direct `create3Factory.deployPackageWithArgs` call with the wrong-bound `PkgInit` and the explicit D11 test-key salt `abi.encode("UniswapV4Detf_FacetPackaging.wrongClaimFacet")._hash()`, not through `DetfPkgFactoryService.deployRebasingClaimTokenDFPkg`, which under D3 and D6 returns the already deployed correct package. Then pass it to `Phase_06_Stage_07_UniswapV4DetfPkg`. Assert the existing stale-dependency revert and unchanged `uniV4DetfPkg` state. Keep `_requireCurrentDependency` runtime checks; changing salts must not turn this rejection test into a success assertion or remove it.

- [x] **AC28 (R5.7)** For automatic library linking, cover both unused and occupied source-qualified identity salts through `ArtifactCreationCode.creationCode(factory, artifactId)`. On an occupied identity, assert that the returned initcode links to the existing library address and that its runtime remains unchanged. Cover recursive links and assert that equal library identifiers repeat while different source-qualified identifiers remain distinct. Do not use a fresh-factory-only result to claim that changed library code replaces an occupied library.

- [x] **AC29 (R5.8)** Cover shared-helper callers, independent helpers, nested constructor namespaces, script salts, automatic library linking, and Crane package-salt producers. Assert corrected D3 component salts equal `abi.encode(name)._hash()` and differ from `bytes(name)._hash()` (raw-name) and from packed-name hashes for the tested nonempty names. Runtime expected vectors in tests use `_hash()`; constant vectors may use `keccak256` under D14. The validation document distinguishes these forms and records their equal bytes32 values. D8 and D11 inventory-only entries retain their documented expressions and are not subject to this encoding assertion. Different names remain distinct and unchanged names are repeatable. Update deployment predictions and stage checks to use exactly the same corrected formulas as deployment. Under D10, add `test/foundry/spec/protocols/l2s/superchain/SuperchainBridgeInfra_Create3Salt.t.sol` on `IndexedexTest`. It deploys the three packages through the corrected Crane FactoryServices on the TestBase CREATE3 factory, using each helper's existing argument list: `deployApprovedMessageSenderRegistryDFPkg(create3Factory, ownableFacet, operableFacet, approvedMessageSenderRegistryFacet)`; `deploySuperChainBridgeTokenRegistryDFPkg(create3Factory, ownableFacet, operableFacet, superChainBridgeTokenRegistryFacet)`; `deployTokenTransferRelayerDFPkg(create3Factory, ownableFacet, tokenTransferRelayerFacet, permit2)` (the relayer package has no `operableFacet`). Inputs come from existing helpers only: `ownableFacet` is `IndexedexTest.multiStepOwnableFacet`; `operableFacet` is `AccessFacetFactoryService.deployOperableFacet(create3Factory)` and is passed only to the two registry helpers; each package's own facet is that FactoryService's `deploy*Facet(create3Factory)` helper; `permit2` is the canonical address etched by `deployPermit2()` from `lib/crane/contracts/protocols/utils/permit2/test/utils/DeployPermit2.sol` and is passed only to the relayer helper. `DeployPermit2` is a `Script` contract with a public `deployPermit2()`, not a library: the test contract inherits it alongside `IndexedexTest`, the way `test/foundry/spec/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHook_Permit2.t.sol` inherits `DeployPermit2`, and calls `deployPermit2()` in `setUp`. The test asserts: each package address equals the CREATE3 prediction for `abi.encode(<contract identifier>)._hash()`; that salt equals the corrected Script 24 expression for the same identifier, recomputed inside the test as `abi.encode("<contract identifier>")._hash()` from the literal identifier string (the test does not import, inherit, or instantiate Script 24); the deployed package's public immutables equal the supplied `PkgInit` (`OWNABLE_FACET`, `OPERABLE_FACET`, and `APPROVED_MESSAGE_SENDER_REGISTRY_FACET` / `SUPER_CHAIN_BRIDGE_TOKEN_REGISTRY_FACET` on the two registries; `OWNABLE_FACET`, `TOKEN_TRANSFER_RELAYER_FACET`, and `PERMIT2` on the relayer); and a second call with a different `PkgInit` returns the existing package with unchanged bindings (D6). Script 24 is not a hermetic test and is not executed for this effort.

- [x] **AC30 (R5.9)** Build fresh artifacts before running affected hermetic suites using the repository's `scripts/forge-artifacts.py` workflow. Record source revision, exact commands, suite results, expected salt vectors, and test coverage by inventory entry in `docs/create3-release-salt-input-validation.md`. Before the implementation PR, require the default-profile build, runtime-artifact refresh, and hermetic test gates in `.github/workflows/foundry-ci.yml` and `.github/ASSISTANT_TESTS.md` to pass. Compile every affected maintained script with its runtime artifacts prepared, without broadcasting. Run any existing hermetic Crane tests that cover a corrected Crane producer and record those commands and results in the same validation document. No `via_ir`, package profiles, or fork RPC dependency for these regressions. Crane fork tests that currently encode `PkgInit` into a package salt are source-corrected under D8; they are not a required runtime gate. Script 24 is compiled with its runtime artifacts prepared and not executed; the D10 hermetic test is its runtime evidence.

- [x] **AC31 (R5.10)** Explicitly compile `lib/crane/test/foundry/fork/protocols/l2s/superchain/TokenTransferRelayer_Superchain.t.sol` without executing its setup or tests and without RPC access. Under D13, run `forge build` from the `lib/crane` checkout with Crane's default profile (its `foundry.toml` sets `test = 'test'`, which includes `test/foundry/fork/`); do not use `FOUNDRY_PROFILE=fork`, `forge test`, or an RPC URL. Record the build command, the Crane source revision, and the successful result in the validation document. The IndexedEx-root build does not establish this result: IndexedEx's test root is `test/foundry/spec` and it never compiles `lib/crane/test/`. D10 requires successful compilation, not merely a source-corrected salt expression.

- [x] **AC32 (R5.11)** Correct in-scope salt expressions in archived scripts even when pre-existing compilation failures prevent execution. For each such caller, record source-level validation of the corrected identity, salt expression, deployment payload, and prediction expressions in the inventory and validation document, together with the existing compile blocker and its source evidence. Label these entries as source-validated with compilation blocked; do not report them as compiled or runtime-tested. This exception applies only to already-broken callers under `scripts/archive/`. Maintained callers are in-scope files under `scripts/foundry/` (including `scripts/foundry/research/`) plus the IndexedEx and Crane FactoryServices, tests, and TestBases this effort edits. Those require compilation and affected hermetic tests; new failures caused by this correction must be fixed.

- [x] **AC33 (R6.1)** Update only these current-guidance files where they still teach bytecode-sensitive or constructor-sensitive component salts, and point those passages at this correction: `docs/testing/ARTIFACT_BUILDS.md` (library salts derived from source identifier and fully linked creation code); `docs/agent/INDEXEDEX_AGENT_LAW.md` FactoryService creation-bytecode paragraph (library salts bound to fully linked bytecode); `docs/factory-service-artifact-creation-bytecode.md` requirement 2 / that document's own D13 / non-goal "Do not change salts" (keep `pkgInitArgs` in salts); and `docs/factory-service-artifact-creation-bytecode.plan.md` (CREATE3 salts stay; do not change salts). Preserve their independent artifact-loading and constructor-delivery requirements. Do not search for further unspecified "deployment guidance". Historical copies under `docs/security/universal-detf-audit/release-review/source-before/` and implementation-artifact test snapshots are not current guidance; do not rewrite them except for the two runbook formula rows in D9. Current Crane salt guidance in `lib/crane/AGENTS.md` and `lib/crane/docs/deployment/factory-services.md` already teaches name-only salts; do not add constructor inputs there. Dated Crane plans stay historical.

- [x] **AC34 (R6.2)** In `implementation-artifacts/detf-funded-staking/production-readiness/PUBLIC_DEPLOYMENT_RUNBOOK.md` and `implementation-artifacts/detf-funded-staking/production-readiness/before-final-acceptance-closure/PUBLIC_DEPLOYMENT_RUNBOOK.md`, replace the "Product component salts" formula row with D3 (`abi.encode(name)._hash()` via `BetterEfficientHashLib` for named components; source-qualified identity for automatic libraries). Keep recorded hashes, addresses, and rehearsal results in those files as historical. Add a one-line note that those records were produced with the old bytecode/constructor-sensitive formula.

- [x] **AC35 (R6.3)** Mark the bytecode-sensitive candidate policy in `docs/security/universal-detf-audit/release-review/MIGRATION.md` and `RELEASE_REVIEW.md` as superseded by this effort. Retain historical patches, RPC evidence, and reported results as historical records, with a clear warning against reapplying their obsolete salt correction as current guidance.

- [x] **AC36 (R6.4)** Record that an occupied salt keeps its existing deployment. Source edits do not upgrade live contracts, and removing fingerprints does not guarantee an unused address. No stage may describe a reused address as proof that new bytecode or constructor bindings were installed.

- [x] **AC37 (R6.5)** This separate effort may change deployment glue in the preserved Uniswap V3/V4 trees to satisfy the owner's global instruction. Do not change their vault economic/runtime implementation source. Preserve the FullSpread effort's original `PRESERVED_SOURCE_SHA256.json` and validation files as dated evidence; record deployment-glue exceptions and new hashes in this effort's validation document instead of rewriting old evidence to conceal the difference.

## Verification

These commands run during implementation, not plan creation. Execute from the repository root except the explicit Crane cwd. Use one writer to each `out/`/`cache_forge/` tree. Keep the default profile, optimizer, compiler, and test/source paths unchanged. Do not enable `via_ir`, add package profiles, delete caches, or stop Forge/solc for lack of progress. Cold compiles can take hours. Copy green worktree artifacts back to the warm seed after validation.

### V1: Verify the FullSpread prerequisite before code edits

```bash
python3 - <<'PY'
from pathlib import Path
import hashlib, json, re
base = Path('contracts/vaults/standard/exchange/protocols/uniswap')
validation = (base / 'VALIDATION.md').read_text()
plan = (base / 'uniswap-se-v2-liquidity-leak-fixes.plan.md').read_text()
assert '**Status:** implemented and validated' in plan
manifest = json.loads((base / 'PRESERVED_SOURCE_SHA256.json').read_text())
assert len(manifest) == 96
for name, expected in manifest.items():
    assert hashlib.sha256(Path(name).read_bytes()).hexdigest() == expected, name
production = [base / 'StandardExchangeConstantProduct.sol']
production += list((base / 'v3').rglob('*.sol')) + list((base / 'v4').rglob('*.sol'))
tests = list(Path('test/foundry/spec/vaults/standard/exchange/protocols/uniswap').rglob('*.sol'))
for label, paths in [('Production', production), ('Test', tests)]:
    lines = ''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.as_posix()}\n'
                    for p in sorted(paths))
    actual = hashlib.sha256(lines.encode()).hexdigest()
    recorded = re.search(label + r'-source fingerprint: `([0-9a-f]{64})`', validation)
    assert recorded and actual == recorded.group(1), label
    print(label, actual)
assert (base / 'REGRESSION_RESULTS.txt').stat().st_size > 0
print('Prerequisite source fingerprints and 96 preserved hashes match.')
PY
```

Inspect the recorded successful command/exit and acceptance evidence, not only the file's presence. Hash and snapshot the FullSpread PRD, plan, six evidence JSON/markdown/text files named in Step 1, and preservation build context before changing salt code. The strict 96-hash check is an entry gate; final checks use Step 7's explicit glue exceptions and do not rewrite that manifest.

### V2: Discover producers and inspect the final salt policy

```bash
rg -n 'releaseSalt|deployCanonicalPackageWithArgs|deployPackageWithArgs|deployFacet|create3WithArgs|\.create3\(|\.deployPkg\(' contracts scripts test lib/crane/contracts lib/crane/test lib/crane/script -g '*.sol'
rg -n 'abi\.encodePacked|keccak256|SALT_NS|pkgInitArgs|RELEASE_ID' contracts/utils/foundry/ArtifactCreationCode.sol contracts/fee/collector/FeeCollectorFactoryService.sol contracts/hooks/uniswap/v4 scripts/foundry -g '*.sol'
```

Repeat the searches against the final sources and inspect every relevant result. Raw counts and blanket `keccak256` bans are not pass/fail criteria: D8, D11, D14, verification hashes, storage slots, proxies, and actual CREATE2 have explicit dispositions. Add any Crane script directories present in the execution checkout to the same search; R1 covers them regardless of their spelling.

### V3: Refresh artifacts and run focused real-path regressions

Complete Steps 3–6 first. The inventory's single JSON block is the execution input. Require all edited production paths and all seven named test roots before running this command; affected extra suites add roots without replacing those seven. Negative artifact-loader fixtures must not be auto-discovered as real artifacts.

```bash
python3 - <<'PY'
from pathlib import Path
import json, os, re, subprocess
text = Path('docs/create3-release-salt-input-inventory.md').read_text()
blocks = re.findall(r'```json\s*\n(.*?)\n```', text, re.S)
assert len(blocks) == 1
inputs = json.loads(blocks[0])
sources = inputs['edited_sources']
roots = inputs['focused_test_roots']
assert 'contracts/utils/foundry/ArtifactCreationCode.sol' in sources
required_roots = {
    'test/foundry/spec/utils/foundry/ArtifactCreationCode.t.sol',
    'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_FacetPackaging.t.sol',
    'test/foundry/spec/fee/collector/FeeCollectorProxy_Selectors.t.sol',
    'test/foundry/spec/protocol/dexes/aerodrome/v1/AerodromeStandardExchange_DeployWithPool.t.sol',
    'test/foundry/spec/protocol/staking/rocket-pool/RocketPoolRETHStandardExchange_Core.t.sol',
    'test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Packaging.t.sol',
    'test/foundry/spec/protocols/l2s/superchain/SuperchainBridgeInfra_Create3Salt.t.sol',
}
assert required_roots <= set(roots), sorted(required_roots - set(roots))
for path in sources + roots:
    assert Path(path).exists(), path
args = ['python3', 'scripts/forge-artifacts.py', 'test', *sources,
        '--all-artifacts', '--no-consumer-artifacts']
for root in roots:
    args += ['--test-root', root]
args += ['--', '-vv', '--no-match-path', '**/fork/**', '--no-match-contract', 'Fork']
env = os.environ.copy()
env['FOUNDRY_PROFILE'] = 'default'
for name in ('ALCHEMY_KEY', 'ETH_RPC_URL', 'BASE_RPC_URL', 'ROBINHOOD_RPC_URL',
             'FOUNDRY_ETH_RPC_URL', 'FOUNDRY_BASE_RPC_URL', 'FOUNDRY_ROBINHOOD_RPC_URL'):
    env.pop(name, None)
print(args, flush=True)
subprocess.run(args, env=env, check=True)
PY
```

Record every exact invocation/result in E. The helper builds before testing; the test-root list includes `ArtifactCreationCode.t.sol`, so `--no-consumer-artifacts` prevents intentional `MissingArtifact`/invalid-source tests from breaking artifact discovery. `--all-artifacts` refreshes real deployment-helper sources and their linked libraries.

### V4: Compile maintained scripts and Crane without execution or RPC

```bash
python3 - <<'PY'
from pathlib import Path
import json, os, re, subprocess
text = Path('docs/create3-release-salt-input-inventory.md').read_text()
inputs = json.loads(re.findall(r'```json\s*\n(.*?)\n```', text, re.S)[0])
env = os.environ.copy()
env['FOUNDRY_PROFILE'] = 'default'
for name in ('ALCHEMY_KEY', 'ETH_RPC_URL', 'BASE_RPC_URL', 'ROBINHOOD_RPC_URL',
             'FOUNDRY_ETH_RPC_URL', 'FOUNDRY_BASE_RPC_URL', 'FOUNDRY_ROBINHOOD_RPC_URL'):
    env.pop(name, None)
roots = sorted(set(inputs['maintained_script_roots']))
assert 'scripts/foundry/supersim/Script_24_DeploySuperchainBridgeInfra.s.sol' in roots
for path in roots:
    assert path.startswith('scripts/foundry/') and Path(path).is_file(), path
    commands = [
        ['python3', 'scripts/forge-artifacts.py', 'build', '--consumer', path],
        ['forge', 'build', path],
    ]
    for args in commands:
        print(args, flush=True)
        subprocess.run(args, env=env, check=True)
print('Crane default-profile build', flush=True)
subprocess.run(['forge', 'build'], cwd='lib/crane', env=env, check=True)
for path in inputs['crane_hermetic_test_roots']:
    assert path.startswith('lib/crane/test/') and '/fork/' not in path, path
    relative = str(Path(path).relative_to('lib/crane'))
    subprocess.run(['forge', 'test', '--match-path', relative, '-vv'],
                   cwd='lib/crane', env=env, check=True)
PY
```

This uses `forge build` on script sources, never `forge script`; no script setup/run is executed. For dynamic runtime artifact identifiers, add their concrete implementation sources to the corresponding artifact-build invocation and record them in the inventory. Under D13 the Crane default build includes repository path `lib/crane/test/foundry/fork/protocols/l2s/superchain/TokenTransferRelayer_Superchain.t.sol`; do not invoke that test or fork setup. A failing maintained compile blocks completion. Archived D7 sources receive source-level validation and recorded existing blockers outside this maintained-script loop.

### V5: Final repository gate and evidence closure

```bash
python3 - <<'PY'
import os, subprocess
env = os.environ.copy()
env['FOUNDRY_PROFILE'] = 'default'
for name in ('ALCHEMY_KEY', 'ETH_RPC_URL', 'BASE_RPC_URL', 'ROBINHOOD_RPC_URL',
             'FOUNDRY_ETH_RPC_URL', 'FOUNDRY_BASE_RPC_URL', 'FOUNDRY_ROBINHOOD_RPC_URL'):
    env.pop(name, None)
commands = [
    ['forge', 'build'],
    ['python3', 'scripts/forge-artifacts.py', 'build', '--all-artifacts'],
    ['forge', 'test', '-vv', '--no-match-path', '**/fork/**', '--no-match-contract', 'Fork'],
]
for args in commands:
    print(args, flush=True)
    subprocess.run(args, env=env, check=True)
PY
```

Then inspect the scoped diff against Step 1's working-tree baseline, not just HEAD. Rehash all original FullSpread evidence files and require byte equality. For each source in its original preservation manifest, require the old hash unless the exact path is a documented `preserved_glue_exceptions` entry; inspect every exception for deployment-only changes and record old/new hashes. Confirm FullSpread economic/test source changes are absent except required deployment expectations/fixtures, and document those separately from original evidence.

Match inventory IDs to final source expressions, explicit constant/runtime salt vectors, prediction results, named tests, compile commands, and D7 source evidence. Record final IndexedEx/Crane revisions plus uncommitted source fingerprints when applicable. Do not mark this plan complete while any required gate is failed or missing.

## Do not

- Do not change files outside the bounded file sets without a PRD update, or broaden an inventory entry into a runtime redesign.
- Do not reopen D1–D14, add namespace compatibility overloads, invent fallback/version salts, or convert compliant constant initializers to runtime code.
- Do not replace real deployment paths with mocks, bypass manager/registry routing, or remove stage rejection checks.
- Do not use the archive exception for maintained callers or claim compile-only evidence is runtime coverage.
- Do not overwrite FullSpread's historical evidence to make new hashes appear previously validated.
- Do not start implementation merely because this plan has been written. Execution requires the separate user instruction naming this plan.

## Execution record

Execution started 2026-09-16 and continued 2026-09-17. V1 passed against the actual working tree; [inventory](create3-release-salt-input-inventory.md) and [validation](create3-release-salt-input-validation.md) record the baseline and current evidence. The first focused V3 gate passed 107 tests across 12 suites after rerunning outside the macOS sandbox to avoid Forge system-proxy discovery panic. The Crane default build passed and its commit is pinned. The initial full repository gate built successfully and ran 32,199 tests with one obsolete occupied-namespace isolation assertion failing. After crash recovery, that Stata fixture was corrected under AC25/D6; the final focused gate passed 122 tests across 15 suites. All 173 maintained script roots compiled successfully. The final full repository rerun passed: 32,199 passed, 0 failed, 0 skipped across 2,774 suites, exit 0. All acceptance criteria are complete; the linked validation record contains the final fingerprints and command results.
