# Test Coverage Audit — T-manager-fee-registry

| Field | Value |
|-------|--------|
| Date | 2026-08-09 |
| Agent / run | Stage 1 area subagent · full · `T-manager-fee-registry` |
| Status | **COMPLETE** |
| Production paths | `contracts/manager/**`, `contracts/fee/**`, `contracts/oracles/**`, `contracts/registries/**` |
| Test paths | `test/foundry/spec/manager/**`, `test/foundry/spec/fee/**`, `test/foundry/spec/oracles/fee/**`, `test/foundry/spec/registries/vault/**`; deploy/auth wiring exercised via `contracts/test/IndexedexTest.sol` + product TestBases (reference only) |
| Skills / PRD version cited | `docs/testing/TEST_COVERAGE_AUDIT_PRD.md` (DRAFT, locks L-TCA-1…8, §2.2 layers, §2.3 Manager/fee oracle P0, §2.4 PAT-*, §3.8, §7.2, §8); product class P0: **Access, fee non-dilution, registry wiring, D, J**; `crane-testing` LR-7 / production-first; `indexedex-testing` registry path |
| Finding ID prefix | `TCA-MGR-NNN` |
| Runtime proofs | No Blocker CODE claimed. High CODE seigniorage J-omit is **static** (missing interface + `facetFuncs` + typo name); labeled `STATIC_ONLY` (not free-mint class). |

---

## 1. Executive summary

### Maturity scores by product (0–5)

| Product / surface | Maturity | Worst open severity |
|-------------------|----------|---------------------|
| **IndexedexManager DFPkg** (diamond + CREATE3 deploy) | **3** | High TEST (J/D declaration gap) |
| **VaultFeeOracle Manager + Query** (on manager proxy) | **4** | Medium TEST (liquid-reserve auth suite incomplete) |
| **VaultRegistry Deployment** | **3–4** | Medium TEST (hook deploy ACL thin here; package DFPkg path solid) |
| **VaultRegistry Vault/Package Manager + Query** | **3** | High CODE (seigniorage query surface) + Medium CODE (unregister stale pack) |
| **VaultRegistry Disable Manager/Query** | **3–4** | Medium TEST (exact selector on disable auth) |
| **FeeCollector DFPkg** (manager + single-token push) | **2** | High TEST (pullFee ACL / accounting / push surface) |
| **VaultFeeOracleQueryAware** facet/repo | **1** | Low (support facet; no area suite) |

### Blocker / High counts

| Severity | Count | Notes |
|----------|------:|-------|
| **Blocker** | **0** | No free mint / unbounded extract / silent missing money API on vault money paths owned here |
| **High** | **3** | Seigniorage registry query J-omit CODE; manager facet J/D TEST gap; FeeCollector pull/push access+surface TEST |
| **Medium** | **5** | Stale `feeTypeIdsOfVault` on unregister; register ACL exact selectors; liquid-reserve auth; FeeCollector theater; hook deploy ACL depth |
| **Low / Info** | **4** | Seigniorage package-query symmetry; stale Operable comments; permissionless sync design; deploy-path quality good |

### Top 5 recommended WPs

1. **`WP-J-MGR-001`** — CODE+TEST: fix seigniorage vault fee-type query (`seeigniorageTermsTypeId` → proper interface name), add to `IVaultRegistryVaultQuery` + `facetFuncs`, proxy J smoke.
2. **`WP-J-MGR-002`** — TEST: `Behavior_IFacet` / `TestBase_IFacet` for **all** manager diamond facets + FeeCollector SingleTokenPush; loupe + proxy callable matrix (J1–J3).
3. **`WP-N-FEE-001`** — TEST (+ optional CODE): FeeCollector `pullFee` onlyOwner exact selector + real ERC20 balances + post-pull reserve sync policy; `pushSingleTokenFee` proxy smoke.
4. **`WP-CODE-REG-001`** — CODE+TEST: `VaultRegistryVaultRepo._removeVault` **delete** `feeTypeIdsOfVault[vault]` (not re-assign); assert via harness or exposed view.
5. **`WP-N-MGR-001`** — TEST: exact-selector access matrix for `registerVault` / `unregisterVault` / `registerPackage` / `unregisterPackage` / liquid-reserve setters / hook factory + `deployHookVault*`.

### Headline

Manager + fee-oracle + vault-registry form a **strong admin/config substrate**: production-first `IndexedexTest` deploys FeeCollector and IndexedexManager via CREATE3 facets + DFPkg + diamond package factory; fee oracle has **excellent** bounds, cascade/fallback, events, and WAD non-dilution/proportionality suites; registry registration/query/disable and deploy ACL for SE packages are well covered. The open P0 gaps for this product class are **J/D surface completeness** (almost no manager facet declaration tests; seigniorage per-vault type ID query **not on diamond API** due to typo + omit) and **FeeCollector money-out hardening** (`pullFee` access and reserve accounting under-tested; push facet undeclared in tests). No catalog **I/K** money free-mint path lives primarily in this area (N/A for pretransfer on manager/oracle; fee collector is owner pull / push sync).

---

## 2. Product inventory

| Product | DFPkg / key Targets | TestBase | Test roots | Deploy path quality |
|---------|---------------------|----------|------------|---------------------|
| **IndexedexManager** | `IndexedexManagerDFPkg`, `IndexedexManagerFactoryService`; facets: fee query/manager, operable, registry deployment/manager/query/disable | `IndexedexTest` → real manager proxy | `test/foundry/spec/manager/IndexedexManager_InitAccount.t.sol` (+ all suites casting manager) | **Excellent** — CREATE3 facets, DFPkg via create3Factory, diamond via `diamondPackageFactory.deployIndexedexManager`; never `new` production facets |
| **VaultFeeOracle** | `VaultFeeOracle{Query,Manager}Facet`, `VaultFeeOracleRepo` (storage on manager diamond) | Same manager proxy | `test/foundry/spec/oracles/fee/*` (8 files) | **Excellent** — facets on manager diamond; queries hit proxy |
| **VaultRegistry** | Deployment / VaultManager / PackageManager / VaultQuery / PackageQuery / Disable* Facets+Targets+Repos | Manager proxy; deploy auth uses `TestBase_AerodromeStandardExchange` | `test/foundry/spec/registries/vault/*` (5 files) | **Excellent** for `deployPkg`/`deployVault` registry path; DFPkg helpers authorized as registered packages |
| **FeeCollector** | `FeeCollectorDFPkg`, Manager + SingleTokenPush Facets/Targets, FactoryService | `IndexedexTest.feeCollector` | `test/foundry/spec/fee/collector/*` (2 files) | **Excellent** deploy; **weak** product tests (mocks, thin selectors) |
| **VaultFeeOracleQueryAware** | `VaultFeeOralceQueryAwareFacet` (+ typo in type name), Repo | None dedicated | — | Support facet for packages that store oracle pointer; not on manager DFPkg cuts |

### 2.1 Trust-flag / money credit entrypoints (this area)

| Surface | Flag / credit | Notes |
|---------|---------------|-------|
| Manager / fee oracle | None | Config-only; fees consumed by vaults |
| Registry deploy | N/A | Deploy/register ACL |
| FeeCollector `syncReserve` / `pushSingleTokenFee` | Balance snapshot to MultiAsset repo | Permissionless write of observed balance |
| FeeCollector `pullFee` | Owner ERC20 transfer out | **No** `pretransferred`; PAT-I N/A; owner extract risk if ACL weak |

### 2.2 Facet inventory (manager diamond — `IndexedexManagerDFPkg`)

| Facet | Access model | `facetFuncs` count (approx) | Declaration test? |
|-------|--------------|----------------------------:|-------------------|
| DiamondCut | owner (Crane) | Crane | Crane |
| MultiStepOwnable | owner | Crane | Crane |
| Operable | owner for setOperator | Crane | Crane |
| VaultFeeOracleQuery | view | 25 | **No** |
| VaultFeeOracleManager | onlyOwner / onlyOwnerOrOperator | 16 | **No** |
| VaultRegistryDeployment | onlyOwnerOrOperator / `_onlyOwnerOrOperatorOrPkg` | 5 | **No** |
| VaultRegistryVaultManager | onlyOwner | 2 | **No** |
| VaultRegistryVaultPackageManager | onlyOwner | 2 | **No** |
| VaultRegistryVaultPackageQuery | view | 10 | **No** |
| VaultRegistryVaultQuery | view | 21 | **No** |
| VaultRegistryDisableQuery | view | 7 | **No** |
| VaultRegistryDisableManager | onlyOwner | 2 | **No** |

FeeCollector diamond: MultiStepOwnable + SingleTokenPush (1) + Manager (3). Only Manager has `*_IFacet` test.

### 2.3 Known production shape notes

1. **`VaultRegistryVaultQueryTarget.seeigniorageTermsTypeId`** (typo) exists on Target but is **not** on `IVaultRegistryVaultQuery` and **not** in `VaultRegistryVaultQueryFacet.facetFuncs` → not cut onto proxy (**PAT-J-OMIT** / incomplete API). Sibling fields (`vaultUsageFeeTypeId`, `vaultDexTermsTypeId`, `vaultBondTermsTypeId`, `vaultLendingTermsTypeId`) are wired.
2. **`_removeVault`** sets `feeTypeIdsOfVault[vault] = vaultConfig.vaultFeeTypeIds` instead of `delete` (documented by existing test as bug; individual fee fields are deleted).
3. **Append-only sets** on unregister package/vault (`contentsIds`, `vaultTokens`, fee-type ID sets, `pkgsOfType`) — documented intentional BEHAVIOR tests.
4. **Auth comments** in `VaultFeeOracleManagerFacet_Auth.t.sol` / `VaultRegistryDeployment_Auth.t.sol` claim OperableFacet missing — **stale**: DFPkg includes OPERABLE; operator tests succeed via `setOperator`.
5. **`facetCuts()`** installs OPERABLE before fee facets, while `facetAddresses()` lists fee before OPERABLE; comment says interfaces order must match addresses. Factory still deploys a working diamond (auth/query tests green). Treat as metadata hygiene unless ERC165 zip is proven broken (not claimed Blocker).

---

## 3. Layer matrix

Legend: **F** full · **P** partial · **G** gap · **N/A** · **S** stub/theater · maturity 0–5.

| Product | H | N | D | J | I | K | A–H | P | L1 | L2 | L3 | Maturity | Notes |
|---------|---|---|---|---|---|---|-----|---|----|----|----|----------|-------|
| IndexedexManager DFPkg | F | P | G | P | N/A | N/A | N/A | N/A | G | G | G | **3** | InitAccount + ubiquitous proxy use; no package declaration suite |
| VaultFeeOracle | F | F | G | P | N/A | N/A | N/A | N/A | P | G | G | **4** | Strong bounds/cascade/events/auth; fuzz proportionality; missing IFacet |
| VaultRegistry Deploy | F | F | G | P | N/A | N/A | N/A | N/A | G | G | G | **3–4** | owner/attacker/pkg path + disable gate; hook paths thin in this area |
| VaultRegistry Indexing | F | P | G | **G/P** | N/A | N/A | N/A | N/A | G | G | G | **3** | Rich register/query tests; seigniorage view hole; package ACL N partial |
| VaultRegistry Disable | F | P | G | P | N/A | N/A | N/A | N/A | G | G | G | **3–4** | Functional OR logic solid; bare `expectRevert` on onlyOwner |
| FeeCollector | P | G | P | P | N/A | P* | G | N/A | G | G | G | **2** | Manager IFacet + smoke; no ACL/accounting depth; push untested |
| FeeOracleQueryAware | G | G | G | G | N/A | N/A | N/A | N/A | G | G | G | **1** | Not on manager package |

\*K for FeeCollector = reserve snapshot vs balance after pull/push — accounting integrity, not vault donation.

**Manager/fee oracle class P0 (PRD §2.3):** Access **P→F** (oracle strong; fee pull weak; register exact-selector partial) · Non-dilution **F** (oracle WAD) · Registry wiring **F** (deploy path) · D **G** · J **P/G**.

---

## 4. Catalog matrix (A–K)

Manager/fee/registry are **not** DETF/SE money vaults. Most classic catalog IDs are **N/A**; score access/config abuse and surface.

| ID | IndexedexManager | VaultFeeOracle | VaultRegistry | FeeCollector | Evidence (test name or G) |
|----|------------------|----------------|---------------|--------------|---------------------------|
| **A1–A3** Donation | N/A | N/A | N/A | G | No fee-collector donation/accounting abuse suite |
| **B*** Pricing | N/A | N/A | N/A | N/A | Config only |
| **C*** Reentrancy | N/A | N/A | G | G | No reentrancy on pullFee/sync (external token call) |
| **D*** Authority | N/A | N/A | N/A | N/A | Not NFT authority |
| **E1/E5** | N/A | N/A | N/A | G | No zero/FoT pullFee cases |
| **F*** Immutability | N/A | N/A | N/A | N/A | Admin diamond by design |
| **G*** Nested | N/A | N/A | N/A | N/A | |
| **H2–H3** | N/A | N/A | N/A | G | |
| **I1–I5** | N/A | N/A | N/A | N/A | No `pretransferred` on these surfaces |
| **J1** Target ⊆ facetFuncs | G | P | **G** (seigniorage) | P (manager yes; push untested) | Seigniorage Target fn omitted; FeeCollector manager matches interface |
| **J2** facetCuts / loupe | G | G | G | G | No loupe suite on manager/fee diamonds |
| **J3** proxy callable | P | F | P | P | Happy proxy use; no exhaustive selector matrix |
| **K1** | N/A | N/A | N/A | G | pullFee may desync MultiAsset reserve |

**Access / non-dilution (class-specific, not A–K letter):**

| Property | Score | Evidence |
|----------|-------|----------|
| Fee setter ACL (owner/operator) | **F** | `VaultFeeOracleManagerFacet_Auth.t.sol` (+ seigniorage partial) |
| `setFeeTo` onlyOwner (not operator) | **F** | `test_setFeeTo_revertsForOperator` |
| Liquid reserve setter ACL | **G** | Only functional FO suite; no attacker matrix |
| Register/unregister vault/pkg ACL | **P** | always `vm.prank(owner)` in registration; no stranger + exact selector |
| Deploy vault ACL | **F** | `VaultRegistryDeployment_Auth.t.sol` |
| Disable ACL | **P** | bare `expectRevert` |
| Fee WAD bounds ≤ 1e18 | **F** | Bounds + Dilution |
| Cascade vault→type→global | **F** | BondTermsFallback, Units, LiquidReserve FO-1..6 |
| Fee math proportionality / non-dilution doc | **F** | Dilution + `testFuzz_feeExtraction_isProportional` |
| FeeCollector pullFee ACL | **G** | only happy owner amount=0 mock |

---

## 5. Findings

### 5.1 [TCA-MGR-001] High · CODE · PAT-J-OMIT · STATIC_ONLY

- **Summary:** Per-vault **seigniorage fee type ID** cannot be queried through the manager diamond the way usage/dex/bond/lending can. Target implements a **typo-named** external `seeigniorageTermsTypeId` that is **not** declared on `IVaultRegistryVaultQuery` and **not** listed in `VaultRegistryVaultQueryFacet.facetFuncs()`, so DFPkg never cuts it onto the proxy. Fee oracle still resolves seigniorage **internally** via `VaultRegistryVaultRepo._seigniorageIncentiveIdOfVault` in query facet — money policy may work, but the **documented registry query symmetry is broken** and any integrator calling a correct name gets no function on proxy.
- **Evidence:**
  - Target: [`contracts/registries/vault/VaultRegistryVaultQueryTarget.sol`](../../../../contracts/registries/vault/VaultRegistryVaultQueryTarget.sol) L224–226 (`seeigniorageTermsTypeId`)
  - Interface: [`contracts/interfaces/IVaultRegistryVaultQuery.sol`](../../../../contracts/interfaces/IVaultRegistryVaultQuery.sol) — has usage/dex/bond/lending only (L194–200); **no** seigniorage getter
  - Facet: [`contracts/registries/vault/VaultRegistryVaultQueryFacet.sol`](../../../../contracts/registries/vault/VaultRegistryVaultQueryFacet.sol) L22–45 — 21 selectors; ends at `vaultLendingTermsTypeId`; no seigniorage
  - Contrast: individual field **is** stored/cleared in register/unregister (`VaultRegistryVaultRepo` seigniorageIdOfVault)
- **Why bar fails:** J bar = Target API ⊆ facetFuncs ⊆ facetCuts ⊆ loupe ⊆ proxy. Target has a seigniorage view; facetFuncs omit it; interface incomplete → PAT-J-OMIT.
- **Severity note:** **High** not Blocker — not a silent missing **user money** entrypoint; admin/index surface + type-id observability. Static evidence is complete; no runtime free-value transition.
- **Recommended CODE change:**
  1. Add `vaultSeigniorageTermsTypeId(address)` (or product-agreed name) to `IVaultRegistryVaultQuery`.
  2. Rename Target function; remove typo name (or keep deprecated alias only if already externally used — none on proxy today).
  3. Append selector to `VaultRegistryVaultQueryFacet.facetFuncs()`.
  4. Optional: add `vaultSeigniorageFeeTypeIds()` on package query for symmetry with usage/dex/bond/lending (see TCA-MGR-009).
- **Recommended TEST:**
  - Name: `test_J1_vaultSeigniorageTermsTypeId_onProxy_afterRegister`
  - Setup: owner `registerVault` with packed fee type IDs including seigniorage; query on `indexedexManager` proxy.
  - Pass: returns expected bytes4; after unregister returns 0; stranger cannot write.
  - Match-path: `test/foundry/spec/registries/vault/**`
  - Also: `VaultRegistryVaultQueryFacet_IFacet` control list includes new selector.
- **Suggested WP:** `WP-J-MGR-001`
- **Priority:** Wave 1

### 5.2 [TCA-MGR-002] High · TEST · PAT-J / D gap (manager + fee facets)

- **Summary:** Only `FeeCollectorManagerFacet_IFacet.t.sol` implements Crane `TestBase_IFacet` in this area. **Zero** `*_IFacet` tests for VaultFeeOracle*, VaultRegistry*, FeeCollectorSingleTokenPush, or IndexedexManager DFPkg metadata. No loupe enumeration vs control list; no formal J2–J3 matrix on manager diamond. Functional proxy tests prove many selectors exist, but declaration theater bar (Target-derived controls + package cuts) is unmet monorepo-wide for this substrate.
- **Evidence:**
  - `rg TestBase_IFacet test/foundry/spec/{manager,fee,oracles,registries}` → only FeeCollectorManager
  - Manager facets all implement `facetFuncs` manually from interfaces (good source) but untested vs Target public surface
  - Seigniorage omit (001) would have been caught by Target-vs-facetFuncs diff
- **Why bar fails:** Product class P0 requires **D** and **J**; declaration without proxy smoke is PAT-THEATER-FACET risk for future cuts.
- **Recommended CODE:** none unless 001/omit found during audit script.
- **Recommended TEST:**
  - Per-facet `*_IFacet_Test` with `controlFacetFuncs` from **interface** (or Target public API list).
  - Manager package: deploy via `IndexedexTest`; for each expected selector `address(indexedexManager).code` staticcall succeeds (J3).
  - Optional: scripted Target external vs facetFuncs diff in CI notes.
  - Match-path: `test/foundry/spec/manager/**`, `oracles/fee/**`, `registries/vault/**`, `fee/collector/**`
- **Suggested WP:** `WP-J-MGR-002`
- **Priority:** Wave 1 (parallel with 001)

### 5.3 [TCA-MGR-003] High · TEST · FeeCollector access / surface / accounting

- **Summary:** FeeCollector is the protocol fee sink. `pullFee` is `onlyOwner` in production but tests only show owner calling `pullFee(..., 0, ...)` with **mocked** `transfer`. No stranger-revert with exact `NotOwner` selector; no real token balance decrease; no post-pull `MultiAssetBasicVaultRepo` reserve consistency. `pushSingleTokenFee` is on DFPkg cuts but **has no proxy test** and no IFacet test. `syncReserve` permissionless happy path only (may be intentional).
- **Evidence:**
  - Production: [`FeeCollectorManagerTarget.sol`](../../../../contracts/fee/collector/FeeCollectorManagerTarget.sol) L51–54 `pullFee` onlyOwner; L27–42 sync unrestricted; [`FeeCollectorSingleTokenPushTarget.sol`](../../../../contracts/fee/collector/FeeCollectorSingleTokenPushTarget.sol) L32–35 unrestricted
  - Tests: `FeeCollectorProxy_Selectors.t.sol` mock balance/transfer; no attacker case; no push test
  - DFPkg includes SingleTokenPush facet (`FeeCollectorDFPkg.sol` facetCuts_[2])
- **Why bar fails:** Access is a P0 for fee collector money-out; weak proof is theater-adjacent (smoke without ACL).
- **Recommended CODE (optional, NEEDS_OWNER if intentional):** After `pullFee`, update reserve to `balanceOf` (or subtract amount) so MultiAsset accounting stays truthful — if anything reads reserves for solvency.
- **Recommended TEST:**
  - `test_pullFee_revertsForNonOwner` — exact `IMultiStepOwnable.NotOwner`
  - `test_pullFee_transfersRealERC20_andUpdatesReserve` — mint real token to collector; sync; pull; assert recipient balance + reserve
  - `test_pushSingleTokenFee_callableViaProxy` — vault/sim sends tokens; push; reserve == balance
  - Match-path: `test/foundry/spec/fee/collector/**`
- **Suggested WP:** `WP-N-FEE-001`
- **Priority:** Wave 1

### 5.4 [TCA-MGR-004] Medium · CODE · Registry unregister stale packed feeTypeIds

- **Summary:** `_removeVault` re-assigns packed `feeTypeIdsOfVault[vault]` from config instead of deleting, while clearing individual fee id fields. Existing test **names the bug** but cannot assert packed mapping externally (no public getter) — half-theater documentation.
- **Evidence:**
  - [`VaultRegistryVaultRepo.sol`](../../../../contracts/registries/vault/VaultRegistryVaultRepo.sol) L177 assignment vs L179–183 deletes
  - `test_unregisterVault_feeTypeIdsOfVault_bugStaleAssignment` documents without failable assert on packed field
- **Why bar fails:** Storage correctness / re-registration hygiene; low external exploit if only individual fields are read — still CODE debt.
- **Recommended CODE:** `delete layoutStruct.feeTypeIdsOfVault[vault];`
- **Recommended TEST:** expose via test harness or temporary query if product adds getter; re-register after unregister must not inherit ghost packed ids.
- **Suggested WP:** `WP-CODE-REG-001`
- **Priority:** Wave 2

### 5.5 [TCA-MGR-005] Medium · TEST · Register/unregister ACL exact selectors

- **Summary:** Vault and package manager mutators are `onlyOwner` but registration suites only exercise owner paths. No `test_*_revertsForNonOwner` with typed `NotOwner` for `registerVault` / `unregisterVault` / `registerPackage` / `unregisterPackage`. Disable manager has stranger reverts with bare `expectRevert()`.
- **Evidence:** `VaultRegistry_Registration.t.sol`, `VaultRegistryPackage_Registration.t.sol` (owner pranks only); `VaultRegistry_Disable.t.sol` L112–122 bare expectRevert
- **Why bar fails:** Negative bar requires **exact selectors**.
- **Recommended TEST:** matrix 4 mutators × stranger; match Auth style of fee oracle; use `abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, stranger)`.
- **Suggested WP:** `WP-N-MGR-001`
- **Priority:** Wave 2

### 5.6 [TCA-MGR-006] Medium · TEST · Liquid reserve manager ACL incomplete

- **Summary:** `setDefaultLiquidReservePercentage`, `…OfTypeId`, `setLiquidReservePercentageOfVault` are `onlyOwnerOrOperator` in production; FO suite covers cascade/bounds/events for owner only. Auth suite does not include liquid-reserve attackers (covers usage/bond/dex + seigniorage reverts partially).
- **Evidence:** Manager facet L168–196; `VaultFeeOracle_LiquidReservePercentage.t.sol` FO-1..6; `VaultFeeOracleManagerFacet_Auth.t.sol` ends without liquid-reserve cases
- **Recommended TEST:** add three attacker revert + owner/operator success tests mirroring usage fee pattern.
- **Suggested WP:** `WP-N-MGR-001` (cluster) or `WP-N-FEE-ORACLE-001`
- **Priority:** Wave 2

### 5.7 [TCA-MGR-007] Medium · THEATER · FeeCollector proxy selector suite

- **Summary:** `FeeCollectorProxy_Selectors` proves selectors route when tokens are `vm.mockCall`ed and pull amount is 0. Cannot fail if `pullFee` dropped onlyOwner, reserve tracking wrong, or push facet omitted from cuts.
- **Evidence:** `FeeCollectorProxy_Selectors.t.sol` L18–66
- **Why bar fails:** PAT-THEATER class relative to security claims of “selectors route correctly” without ACL/balance asserts.
- **Recommended TEST:** replace mocks with real ERC20 for money-out; keep interfaceId check; add push.
- **Suggested WP:** `WP-N-FEE-001`
- **Priority:** Wave 1–2

### 5.8 [TCA-MGR-008] Medium · TEST · Hook deploy registry path thin in this area

- **Summary:** `deployHookVault`, `deployHookVaultAutoMine`, `setHookDiamondPackageFactory` are on Deployment facet/target with ACL. This area’s auth suite covers SE `deployVault`/`deployPkg` only. Hook factory wiring and unauthorized hook deploy are primarily owned by hooks area — **score partial here** so aggregate does not double-count, but manager ownership of the entrypoints requires at least one ACL negative on manager proxy.
- **Evidence:** `VaultRegistryDeploymentTarget.sol` L79–120; `VaultRegistryDeployment_Auth.t.sol` SE-only
- **Recommended TEST:** `test_setHookDiamondPackageFactory_revertsForNonOwnerOrOperator`; `test_deployHookVault_unauthorized_reverts` (can use zero factory or fixture from hooks TestBase).
- **Suggested WP:** `WP-N-MGR-001` (or coordinate with `T-hooks-v4`)
- **Priority:** Wave 2

### 5.9 [TCA-MGR-009] Low · CODE/TEST · Package query seigniorage type ID set

- **Summary:** Package query exposes usage/dex/bond/lending fee type ID sets but not seigniorage; fee oracle exposes `seigniorageVaultTypeIds()` via package repo. Asymmetry is low severity if oracle is the intended API.
- **Evidence:** `VaultRegistryVaultPackageQueryTarget.sol` L23–37 vs `VaultFeeOracleQueryFacet.seigniorageVaultTypeIds`
- **Recommended:** document intentional dual API or add package-query mirror + test.
- **Suggested WP:** optional with `WP-J-MGR-001`
- **Priority:** Wave 3 / opportunistic

### 5.10 [TCA-MGR-010] Low · TEST · Stale OperableFacet comments

- **Summary:** Comments claim IndexedexManager lacks OperableFacet; production DFPkg includes it and tests set operators successfully.
- **Evidence:** Auth test headers vs `IndexedexManagerDFPkg.facetCuts` OPERABLE; `test_setDefaultUsageFee_succeedsForOperator`
- **Recommended:** fix comments only (docs hygiene) when touching files — not a security WP.
- **Priority:** opportunistic

### 5.11 [TCA-MGR-011] Info · DEFER · Permissionless fee sync/push

- **Summary:** Anyone can call `syncReserve` / `pushSingleTokenFee` to snapshot balances. Grief is gas-only unless reserve is trusted without balance recheck. Document as intentional push-hook model unless product law requires vault-only caller.
- **Class:** DEFER / NEEDS_OWNER if product wants restrict-to-registered-vaults.

### 5.12 [TCA-MGR-012] Medium · CODE · pullFee does not resync reserve (optional)

- **Summary:** `pullFee` transfers tokens without updating MultiAsset reserve; subsequent views of reserve can overstate inventory until someone syncs. If no consumer trusts reserve for enforcement, severity drops to Low.
- **Evidence:** `FeeCollectorManagerTarget.pullFee` vs `syncReserve` update path
- **Recommended CODE:** post-transfer `_updateReserve(token, balanceOf)`; test in `WP-N-FEE-001`
- **Class:** CODE if reserve is security-relevant; else TEST docs only · **NEEDS_OWNER** for product intent
- **Priority:** Wave 2 with fee WP

### 5.13 Positive baselines (Info — no WP)

- **Deploy path:** `IndexedexTest` + `IndexedexManagerFactoryService` / `FeeCollectorFactoryService` match Claude.md non-negotiables (CREATE3 facets; manager DFPkg via factory).
- **Fee non-dilution / bounds:** WAD cap, 0 sentinel fallback, vault isolation fuzz, bond terms validation, liquid reserve FO suite — **strong for product class**.
- **Registry deploy ACL + disable gate:** unauthorized deploy reverts; disabled package blocks deploy; DFPkg-as-caller pattern documented and tested.
- **Production-first:** area suites use real `indexedexManager` / `feeCollector` proxies (FeeCollector token mocks only on external ERC20, not mock manager SUT).

---

## 6. Theater list

| Test / control | Why theater | Fix |
|----------------|-------------|-----|
| `FeeCollectorProxy_Selectors.test_pullFee_callableViaProxy` | amount 0 + mock transfer; no ACL negative | Real ERC20 + non-owner exact revert |
| `test_unregisterVault_feeTypeIdsOfVault_bugStaleAssignment` | Documents CODE bug without failable assert on packed storage | Fix CODE + assert packed clear |
| Missing manager `*_IFacet` suite | Future facet omissions can ship (already did for seigniorage) | WP-J-MGR-002 Target-derived controls |
| Auth file headers “OperableFacet not included” | Misleading operational truth | Comment fix |
| Registration “security” without stranger tests | Indexing correctness ≠ access proof | WP-N-MGR-001 |

---

## 7. Prior-report diff

| Claim (doc) | Status now |
|-------------|------------|
| Manager/fee oracle in adversarial vault gap reports (2026-07) — mostly out of A–H vault matrix | **Still gap** for formal J/D on manager facets; **not** I1-class |
| Fuzz gap: fee monotonic on vaults | Vault-owned; this area has **oracle math L1** (`testFuzz_feeExtraction_isProportional`) — **Closed** for oracle math; vault product fee paths separate |
| Struct-audit / registry unregister hygiene | **Still gap** CODE on packed `feeTypeIdsOfVault` (TCA-MGR-004); individual fields clear — **partial** |
| Negative report pretransfer focus | **N/A** this area (no pretransfer on manager/fee collector pull) |
| IDXEX-027 deploy auth | **Closed** for SE deploy path; hook deploy ACL residual (TCA-MGR-008) |
| IDXEX-036 fee dilution US | **Closed** via Dilution + Bounds suites |
| IDXEX-038 registry query/register | **Mostly closed** functional; ACL exact selectors residual |

---

## 8. Work package stubs

### WP-J-MGR-001

| Field | Value |
|-------|--------|
| **Title** | Wire seigniorage vault fee-type query on registry surface |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | VaultRegistryVaultQuery (+ interface/facet) |
| **Finding IDs** | TCA-MGR-001, TCA-MGR-009 (optional) |
| **Problem** | Typo Target function never cut; interface incomplete; integrators cannot read seigniorage type id on proxy. |
| **Production files** | `contracts/interfaces/IVaultRegistryVaultQuery.sol`, `VaultRegistryVaultQueryTarget.sol`, `VaultRegistryVaultQueryFacet.sol` (+ optional package query) |
| **Test files** | `test/foundry/spec/registries/vault/VaultRegistry_Registration.t.sol` or new `VaultRegistryVaultQuery_Seigniorage.t.sol`; new `*_IFacet` |
| **Out of scope** | Fee oracle cascade math; DETF seigniorage mint logic |
| **Depends on** | none |
| **Parallelizable with** | WP-J-MGR-002, WP-N-FEE-001 |
| **Suggested worktree** | `gap_cover_j-mgr-seigniorage` / branch `gap_cover/j-mgr-seigniorage` |
| **Implementation notes** | Match naming of siblings (`vault*TermsTypeId`); Crane J DoD: proxy call after DFPkg deploy via IndexedexTest |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/registries/vault/**' --match-test 'Seigniorage|vaultSeigniorage'` green; selector on facetFuncs; staticcall on `indexedexManager` succeeds |
| **Anti-theater** | Must call **proxy**, not facet implementation address; register→query→unregister→0 |
| **Estimate** | S |

### WP-J-MGR-002

| Field | Value |
|-------|--------|
| **Title** | Manager + FeeCollector facet declaration + proxy J matrix |
| **Severity** | High |
| **Class** | TEST |
| **Products** | All manager DFPkg facets; FeeCollector SingleTokenPush + DFPkg metadata |
| **Finding IDs** | TCA-MGR-002 |
| **Problem** | No systematic D/J proof; allows PAT-J-OMIT to recur. |
| **Production files** | none (unless omits found) |
| **Test files** | `test/foundry/spec/{manager,oracles/fee,registries/vault,fee/collector}/*_IFacet*.t.sol` |
| **Out of scope** | Vault product In/Out facets |
| **Depends on** | none (merge WP-J-MGR-001 selectors if concurrent) |
| **Parallelizable with** | WP-N-FEE-001, WP-N-MGR-001 |
| **Suggested worktree** | `gap_cover_j-mgr-facets` |
| **Implementation notes** | Copy `FeeCollectorManagerFacet_IFacet` + `TestBase_IFacet`; controls from interface |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/**/*IFacet*' --match-contract 'VaultFeeOracle|VaultRegistry|FeeCollector|IndexedexManager'` green; optional loupe length assert on manager |
| **Anti-theater** | Controls not copied from incomplete Facet only — interface/Target derived; J3 on proxy |
| **Estimate** | M |

### WP-N-FEE-001

| Field | Value |
|-------|--------|
| **Title** | FeeCollector pullFee ACL + real balances + push surface |
| **Severity** | High |
| **Class** | TEST (optional CODE reserve resync) |
| **Products** | FeeCollector diamond |
| **Finding IDs** | TCA-MGR-003, TCA-MGR-007, TCA-MGR-012 |
| **Problem** | Money-out path under-proven; theater mocks. |
| **Production files** | optional `FeeCollectorManagerTarget.sol` reserve update |
| **Test files** | `test/foundry/spec/fee/collector/**` |
| **Out of scope** | How vaults compute fees |
| **Depends on** | none |
| **Parallelizable with** | WP-J-MGR-* |
| **Suggested worktree** | `gap_cover_n-fee-collector` |
| **Implementation notes** | Use real ERC20 from Crane test tokens; IndexedexTest feeCollector |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/fee/collector/**'` includes non-owner exact selector + real transfer asserts + pushSingleTokenFee |
| **Anti-theater** | No `vm.mockCall` on token.transfer for primary ACL/balance cases |
| **Estimate** | S–M |

### WP-CODE-REG-001

| Field | Value |
|-------|--------|
| **Title** | Delete packed feeTypeIdsOfVault on unregister |
| **Severity** | Medium |
| **Class** | BOTH |
| **Products** | VaultRegistryVaultRepo |
| **Finding IDs** | TCA-MGR-004 |
| **Problem** | Stale packed mapping after unregister. |
| **Production files** | `contracts/registries/vault/VaultRegistryVaultRepo.sol` |
| **Test files** | Registration suite + harness if needed |
| **Out of scope** | Append-only contentsIds/vaultTokens policy |
| **Depends on** | none |
| **Parallelizable with** | fee WPs |
| **Suggested worktree** | `gap_cover_reg-unregister-pack` |
| **Acceptance** | Existing bug test becomes assertable green; re-register isolation |
| **Anti-theater** | Must assert storage-visible effect, not comment-only |
| **Estimate** | S |

### WP-N-MGR-001

| Field | Value |
|-------|--------|
| **Title** | Access exact-selector matrix (register/disable/liquid reserve/hook factory) |
| **Severity** | Medium |
| **Class** | TEST |
| **Products** | Registry managers + fee liquid reserve + deployment hook admin |
| **Finding IDs** | TCA-MGR-005, TCA-MGR-006, TCA-MGR-008 |
| **Problem** | Incomplete negatives / bare expectRevert. |
| **Production files** | none |
| **Test files** | registries + oracles auth extensions |
| **Out of scope** | Product disable enforcement inside SE/DETF (product areas) |
| **Depends on** | none |
| **Parallelizable with** | all other area WPs |
| **Suggested worktree** | `gap_cover_n-mgr-auth` |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/{registries,oracles/fee}/**' --match-test 'revertsForNon|onlyOwner|NotOwner|NotOperator'` expanded coverage listed in PR |
| **Anti-theater** | Typed selectors; state-unchanged asserts where relevant |
| **Estimate** | S–M |

---

## 9. Deferred / N/A / NEEDS_OWNER

| Item | Class | Reason |
|------|-------|--------|
| Catalog I1–I3 on manager/oracle | N/A | No pretransfer credit |
| FeeCollector permissionless sync/push | DEFER / NEEDS_OWNER | Design may be intentional push-hook |
| pullFee reserve resync | NEEDS_OWNER | Only if reserve is security-relevant |
| Append-only registry sets | DEFER | Documented intentional anti-spam / history |
| L2/L3 invariants on fee parameters | DEFER Wave 3 | Low exploit vs vault L3 priority |
| VaultFeeOracleQueryAware deep suite | DEFER | Support facet; score when package cuts it |
| Full fork-only manager deploy on mainnet | DEFER | Hermetic IndexedexTest sufficient for this class; product forks use manager as fixture |

---

## 10. Commands run

```bash
# Inventory
ls contracts/manager contracts/fee/collector contracts/oracles/fee contracts/registries/vault
ls test/foundry/spec/manager test/foundry/spec/fee/collector test/foundry/spec/oracles/fee test/foundry/spec/registries/vault

# Surface / access / tests
rg -n 'function facetFuncs|onlyOwner|onlyOwnerOrOperator' contracts/{manager,fee,oracles,registries} --glob '*.sol'
rg -n 'TestBase_IFacet|controlFacetFuncs|function test_' test/foundry/spec/{manager,fee,oracles,registries} --glob '*.sol'
rg -n 'seeigniorage|seigniorageTerms|feeTypeIdsOfVault|pullFee|pushSingleToken' contracts test --glob '*.sol' --glob '!lib/**'

# Cross-area deploy path (reference)
rg -n 'deployIndexedexManager|deployFeeCollector|deployVault' contracts/test/IndexedexTest.sol
```

No `forge test` runtime proof executed this subagent (no Blocker CODE free-value claim requiring §3.8).

---

## Return summary (orchestrator)

| Field | Value |
|-------|--------|
| **Status** | **COMPLETE** |
| **Blocker** | **0** |
| **High** | **3** (TCA-MGR-001 CODE J-omit seigniorage; TCA-MGR-002 TEST D/J matrix; TCA-MGR-003 TEST FeeCollector ACL/surface) |
| **Top WPs** | `WP-J-MGR-001`, `WP-J-MGR-002`, `WP-N-FEE-001`, `WP-CODE-REG-001`, `WP-N-MGR-001` |
| **OUT_FILE** | `docs/testing/coverage-audit/areas/T-manager-fee-registry.md` |
