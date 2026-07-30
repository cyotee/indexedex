# Implementation & Test Plan: Remove SingleVaultDetf (`composed/single`)

| Field | Value |
|-------|--------|
| **Status** | READY TO IMPLEMENT |
| **Date** | 2026-07-29 |
| **PRD** | [`SingleVaultDetf_REMOVAL_PRD.md`](./SingleVaultDetf_REMOVAL_PRD.md) (normative) |
| **This plan** | Execution detail for the carve-out; does not re-open PRD product law |
| **Superseding product** | `contracts/vaults/detf/standardExchange/single/` — **SingleStandardExchangeDETF** |

---

## 0. Locked decisions (PRD + clarification 2026-07-29)

| Topic | Decision |
|-------|----------|
| Fix vs remove | **Remove** entire family; do not rewrite SingleVaultDetf |
| Archive tree | **No** — delete from repo; no `_deprecated` / freeze-as-broken |
| Superchain bridge | **Delete** `DetfSuperchainBridgeRepo` with the family |
| Scenario 3 | **Retarget** to SingleStandardExchangeDETF + injected Uni V4 SE (not delete Scenario 3) |
| Scenario 3 fidelity | **Minimal** — compile + deploy path works; keep primary artifact keys; not full behavioral parity |
| Scenario 3 anvil dry-run | **Optional** — not required for acceptance |
| Seeder | **Rename and keep if still needed**; delete only if unused after retarget |
| PR doc scope (acceptance) | **Minimal:** contracts + tests + live scripts + AGENTS family table + `scripts/foundry/local_testing/README.md` Scenario 3 blurb |
| Launch / inventory / other docs | **Out of acceptance** — list as follow-up only |
| Plan + PRD location | **Stay under** `contracts/vaults/detf/composed/` after `single/` is deleted |
| PR / commits | **One PR**, **phased commits** matching §3 phases |

---

## 1. Goal / non-goals

### Goal

Carve out and delete invalid `SingleVaultDetf` (`detf/composed/single`), exclusive interface, Superchain bridge repo, exclusive tests, exclusive archive scripts; retarget Scenario 3 to production SingleStandardExchangeDETF; update AGENTS family table so agents stop listing `composed/single` as a live family.

### Non-goals (do not do in this PR)

- Fix SingleVaultDetf to accept arbitrary SE vaults.
- Archive package under `scripts/archive` or a deprecated path.
- Full rewrite of `docs/LAUNCH_PLAN.md`, `docs/ROBINHOOD_LAUNCH_PLAN.md`, `docs/ANVIL_LOCAL_TESTING_SCENARIOS_PRD.md`, `docs/CODEBASE_MAP.md`, pool inventory, consolidation plans, frontend research copy (optional follow-up; see §8).
- Redesign Superchain bridge for other DETFs.
- Change SingleStandardExchangeDETF product law.
- Required anvil dry-run of Scenario 3.
- Migrating historical mainnet CHIR / Protocol DETF deployments.

---

## 2. Success criteria (acceptance)

Mirror PRD §11; clarify with locked scope:

- [x] No directory `contracts/vaults/detf/composed/single/`.
- [x] No `contracts/interfaces/ISingleVaultDetf.sol`.
- [x] No `contracts/vaults/detf/DetfSuperchainBridgeRepo.sol`.
- [x] No `test/foundry/spec/vaults/detf/composed/single/`.
- [x] No live `scripts/foundry/**` (non-archive) imports of SingleVaultDetf / `ISingleVaultDetf` / `DetfSuperchainBridgeRepo`.
- [x] Seeder either renamed off `SingleVaultDetf*` or deleted if unused; no `SingleVaultDetfUniswapV4LiquiditySeeder` symbol remains if renamed.
- [x] Archive protocol-detf scripts that imported SingleVaultDetf are **deleted** (PRD §6.4 inventory).
- [x] `Script_12_DeployScenario3Overlay.s.sol` deploys **SingleStandardExchangeDETF** + injected Uni V4 SE + outer WETH/DETF pool; no Superchain bridge init; still writes `12_scenario_3.json` with stable keys where practical (`inventoryDetf`, `underlyingVault`, `balancerWethDetfPool`, etc.).
- [x] `scripts/foundry/local_testing/README.md` Scenario 3 description matches Single SE DETF (not composed/single).
- [x] `AGENTS.md` / `Agents.md` DETF families table no longer lists Composed single / `composed/single`.
- [x] This PRD + this plan remain under `contracts/vaults/detf/composed/`.
- [x] `forge build` succeeds.
- [x] Grep (below) clean under live trees.
- [x] Smoke tests for remaining DETF families pass (§6).

**Not acceptance:** optional anvil dry-run; full §8 doc sweep; frontend research strip.

---

## 3. Execution phases (commit boundaries)

Prefer **one PR** with commits ordered as below (each commit should leave the tree buildable where practical; after Phase 1–2, Scenario 3 will not build until Phase 3 — acceptable if PR lands as a unit, but prefer Phase 3 immediately after Phase 2 in the same PR).

### Phase 0 — Preflight (read-only; no commit)

Re-confirm isolation on the implement branch tip:

```bash
# Other DETF families must not import composed/single
rg -n 'composed/single|SingleVaultDetf|ISingleVaultDetf|DetfSuperchainBridgeRepo' \
  contracts/vaults/detf/standardExchange \
  contracts/vaults/detf/composed/multi-vault-weighted \
  contracts/vaults/detf/composed/stable \
  contracts/vaults/seigniorage \
  contracts/manager \
  contracts/registries \
  --glob '*.sol'

# Bridge consumers
rg -n 'DetfSuperchainBridgeRepo' contracts test scripts --glob '*.sol'

# Seeder importers
rg -n 'SingleVaultDetfUniswapV4LiquiditySeeder' scripts contracts test --glob '*.sol'

# Full exclusive-symbol map (for delete checklist)
rg -n 'SingleVaultDetf|ISingleVaultDetf|DetfSuperchainBridgeRepo|composed/single' \
  contracts test scripts/foundry scripts/archive --glob '*.{sol,md,sh}'
```

**Expected:** zero production imports from other DETF families; bridge only SingleVault + its tests/scripts; seeder only Scenario 3 (+ seeder file itself).

If any unexpected hit appears outside PRD §6, **stop** and update this plan / PRD before deleting.

---

### Phase 1 — Delete family tests

**Commit:** `test(detf): remove SingleVaultDetf composed/single specs`

Delete entire tree:

```text
test/foundry/spec/vaults/detf/composed/single/
```

Complete file list (PRD Appendix B) — all 14 `*.t.sol` plus any co-located non-test files under that tree:

| Path under `test/foundry/spec/vaults/detf/composed/single/` |
|------------------------------------------------------------|
| `SingleVaultDetf_ProductionBase.t.sol` |
| `SingleVaultDetfDFPkg_Deploy.t.sol` |
| `SingleVaultDetfExchangeIn_MintWithWeth.t.sol` |
| `SingleVaultDetf_MintSellRedeem.t.sol` |
| `SingleVaultDetf_AuctionBondWithPosition.t.sol` |
| `SingleVaultDetf_BridgeTransport.t.sol` |
| `SingleVaultDetf_ThresholdMode.t.sol` |
| `SingleVaultDetfBondingFacet_IFacet_Test.t.sol` |
| `SingleVaultDetfExchangeInFacet_IFacet_Test.t.sol` |
| `SingleVaultDetfExchangeInQueryFacet_IFacet_Test.t.sol` |
| `SingleVaultDetfExchangeOutFacet_IFacet_Test.t.sol` |
| `SingleVaultDetfInfoFacet_IFacet_Test.t.sol` |
| `adversarial/Adversarial_SingleVaultDetf_P0.t.sol` |
| `fuzz/SingleVaultDetf_Fuzz.t.sol` |

**Do not touch:** `test/foundry/spec/vaults/detf/standardExchange/single/**`, multi-vault-weighted, composed/stable, seigniorage, DualLiquidity.

---

### Phase 2 — Delete production exclusives

**Commit:** `chore(detf): delete SingleVaultDetf package, interface, Superchain bridge repo`

Delete:

```text
contracts/vaults/detf/composed/single/          # entire directory
contracts/interfaces/ISingleVaultDetf.sol
contracts/vaults/detf/DetfSuperchainBridgeRepo.sol
```

**Must remain** (never delete because of this work):

| Keep | Why |
|------|-----|
| `contracts/vaults/detf/core/**` | Shared threshold / fee / bond math |
| `contracts/vaults/detf/reusable/**` | Shared DETF factories / NFT inventory |
| `contracts/vaults/detf/bondNft/**`, `claimToken/**`, `inventory/**` | Shared packages |
| `contracts/vaults/detf/DETFCommon.sol` | Used by other families |
| `contracts/vaults/detf/standardExchange/single/**` | Superseding product |
| `contracts/vaults/detf/composed/multi-vault-weighted/**`, `composed/stable/**` | Other families |
| `contracts/vaults/detf/composed/SingleVaultDetf_REMOVAL_PRD.md` | Carve-out record |
| `contracts/vaults/detf/composed/SingleVaultDetf_REMOVAL_IMPLEMENTATION_AND_TEST_PLAN.md` | This plan |
| Uni V4 SE package, WeightedPool8020 (elsewhere), seigniorage “SingleVault” names | Not this family |

After this phase, `composed/` contains: `multi-vault-weighted/`, `stable/`, removal PRD, this plan.

---

### Phase 3 — Retarget Scenario 3 + seeder

**Commit:** `chore(local-testing): retarget Scenario 3 to SingleStandardExchangeDETF`

#### 3.1 Primary file

Rewrite:

```text
scripts/foundry/local_testing/anvil_single/Script_12_DeployScenario3Overlay.s.sol
```

#### 3.2 Target architecture (minimal fidelity)

Intent of Scenario 3 today: local inventory DETF + outer Balancer WETH/DETF pool for UI/dev. After retarget:

```text
[foundation stages 01–06]
        │
        ▼
 Uni V4 PoolManager + seed WETH/pairToken pool (seeder)
        │
        ▼
 Uni V4 Standard Exchange vault instance  ──inject──►  SingleStandardExchangeDETF instance
        │                                                      │
        │                                                      ├── bond NFT / claim (as PkgInit requires)
        │                                                      └── reserve weighted pool (DETF DFPkg; WeightedPoolFactory)
        ▼
 Outer Balancer WETH / DETF pool (keep balConstProdPkg path if still valid)
        │
        ▼
 12_scenario_3.json + tokenlist fragments
```

**Rules (PRD §0):**

1. **DETF package:** deploy facets/DFPkg for **SingleStandardExchangeDETF** via `SingleStandardExchangeDETF_*_FactoryService` + manager registry (`deployPkg` / typed deploy). Same production pattern as `TestBase_SingleStandardExchangeDETF`.
2. **External SE leg:** deploy **Uniswap V4 Standard Exchange** vault **separately**, then set `PkgArgs.standardExchangeVault` (and share / rateTarget). Do **not** bake Uni V4 into DETF package init.
3. **Seeder:** rename off `SingleVaultDetf*`; keep under `scripts/foundry/shared/` if still used for Uni V4 SE leg liquidity.
4. **Bridge:** drop all Superchain / `DetfSuperchainBridgeRepo` / empty bridge config. Hermetic single-chain overlay only.
5. **Artifacts:** keep stage number / `12_scenario_3.json`. Prefer **stable keys**:
   - **Keep:** `inventoryDetf`, `underlyingVault`, `balancerWethDetfPool`, `poolManager`, `liquiditySeeder`, `protocolNftVault`, `rebasingClaimToken`, `reservePool`, `inventoryDetfPkg` (or rename pkg key only if necessary), `owner`, `deployer`, `chainId`, `networkProfile`.
   - **Drop or zero:** `weightedPool8020Factory` if 8020 factory is no longer deployed (Single SE DETF uses general **WeightedPoolFactory**). Prefer omit key or leave absent rather than fake address; update any reader only if something in live local_testing **requires** the key (grep before changing).
6. **8020 factory:** drop Scenario 3 exclusive `WeightedPool8020Factory` deploy if it only served SingleVaultDetf. Wire Single SE DETF `PkgInit.weightedPoolFactory` to a general WeightedPoolFactory available from foundation artifacts or deploy one CREATE3 in Script_12 if not already in manifests.
7. **Docs:** edit `scripts/foundry/local_testing/README.md` Scenario 3 blurb only (required).

#### 3.3 Concrete rewrite checklist for Script_12

| Current (delete / replace) | Replacement |
|----------------------------|-------------|
| Imports `ISingleVaultDetf`, `SingleVaultDetf_*_FactoryService`, `ISingleVaultDetfDFPkg`, `DetfSuperchainBridgeRepo` | Imports from `standardExchange/single/*` (`ISingleStandardExchangeDETDFPkg`, `SingleStandardExchangeDETF_*_FactoryService`, `SingleStandardExchangeDETF_Component_FactoryService` / Pkg helpers as needed) |
| Facet deploys `deploySingleVaultDetf*Facet` | Facet deploys for Single SE DETF (mirror TestBase: exchange-in facet + shared multi-asset vault facets + bond NFT / claim facets as required by PkgInit) |
| `deploySingleVaultDetfDFPkg` + `buildPkgInit` with `underlyingVaultPkg` + bridge | `deploySingleStandardExchangeDETDFPkg` / `deployPkg(pkgInit)` with **WeightedPoolFactory**, rate provider pkg, bond NFT pkg, **no** underlying vault pkg on DETF init |
| `_deploySingleVaultDetf` builds Uni V4 `PoolKey` into DETF PkgArgs | (1) deploy Uni V4 SE vault via `underlyingVaultPkg.deployVault(poolKey, widthMultiplier)`; (2) `PkgArgs.standardExchangeVault = that vault`; `rateTarget` = WETH (or vault’s rate asset); name/symbol can remain CHIR local fixture if UI expects it |
| `ISingleVaultDetf(inventoryDetf).underlyingVault()` | `ISingleStandardExchangeDETFInfo(inventoryDetf).standardExchangeVault()` (or equivalent info getter) for `underlyingVault` artifact |
| `_emptyBridgeConfig` / Superchain imports | **Delete** |
| `_deployWeightedPool8020FactoryIfNeeded` | **Delete** if unused; ensure WeightedPoolFactory for DETF reserve exists |
| Seeder type name | Renamed seeder (see 3.4) |
| Fragment labels “Single Vault DETF CHIR” | Prefer “Single Standard Exchange DETF” or keep CHIR symbol for local fixture stability — either OK; prefer clarity in `name` field |
| Log strings “Single Vault DETF” | Update to Single SE DETF |

**Gold reference for deploy order:**  
`contracts/vaults/detf/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol`  
(`_deploySingleStandardExchangeDetfPkg`, `_deployDetfInstance`).

**Gold reference for Uni V4 SE pkg deploy:** existing Script_12 `_deployPkgs` Uni V4 block + `UniswapV4_Component_FactoryService` (keep that path; stop attaching it as DETF package immutable).

#### 3.4 Seeder rename

| Action | Detail |
|--------|--------|
| If still needed after retarget | Rename `scripts/foundry/shared/SingleVaultDetfUniswapV4LiquiditySeeder.sol` → e.g. `UniswapV4LiquiditySeeder.sol` (or `LocalTestingUniswapV4LiquiditySeeder.sol`) |
| Contract name | Match file; no `SingleVaultDetf` substring |
| Update | Script_12 import + type + CREATE3 salt string if it embeds old name (optional salt stability) |
| If unused | Delete seeder file and all references |

Grep after rename:

```bash
rg -n 'SingleVaultDetfUniswapV4LiquiditySeeder|SingleVaultDetf' scripts/foundry --glob '*.sol'
```

#### 3.5 README

Edit `scripts/foundry/local_testing/README.md`:

- Scenario 3 describes **SingleStandardExchangeDETF** + Uni V4 SE leg + outer WETH/DETF pool.
- Remove references to Superchain bridge Script_22/23 in the live scenario path if still listed as current (those scripts live under archive and will be deleted in Phase 4).
- Keep `scenario3` stage / `12_scenario_3.json` naming.

---

### Phase 4 — Delete exclusive archive scripts

**Commit:** `chore(archive): delete SingleVaultDetf-dependent protocol-detf scripts`

Delete (confirm with `rg` at implement time; paths from PRD §6.4 + current tree):

```text
scripts/archive/foundry/protocol-detf/anvil_sepolia/Script_16_DeployProtocolDETF.s.sol
scripts/archive/foundry/protocol-detf/anvil_base_main/Script_16_DeployProtocolDETF.s.sol
scripts/archive/foundry/protocol-detf/public_sepolia/ethereum/Script_16_DeployProtocolDETF.s.sol
scripts/archive/foundry/protocol-detf/public_sepolia/base/Script_16_DeployProtocolDETF.s.sol
scripts/archive/foundry/protocol-detf/local_testing/supersim/Script_22_ConfigureSingleVaultDetfBridge.s.sol
scripts/archive/foundry/protocol-detf/local_testing/supersim/Script_23_ValidateSingleVaultDetfBridge.s.sol
```

Also delete any other archive `.sol` that still imports SingleVaultDetf after a final:

```bash
rg -n 'SingleVaultDetf|ISingleVaultDetf|DetfSuperchainBridgeRepo|composed/single' scripts/archive --glob '*.sol'
```

If a directory is empty after deletes, remove empty dirs only (no need to preserve empty shells).

**Note:** Live `scripts/foundry/**/Script_ExportTokenlists.s.sol` may still read historical key `inventoryDetf` from `16_protocol_detf.json` — that is **not** a SingleVaultDetf Solidity import. Leave unless it fails compile. Out of scope to rewire tokenlist export for deleted archive Script_16.

---

### Phase 5 — AGENTS family table

**Commit:** `docs(agents): drop composed/single from DETF families table`

Edit `AGENTS.md` / `Agents.md` (same content as applicable on this FS):

1. Remove the row:

   | Composed single | `detf/composed/single/` | … |

2. Ensure single-leg product points only at **Single Standard Exchange** / `detf/standardExchange/single/`.

3. Do **not** expand into a full docs sweep. `Claude.md` only if it duplicates the family table (it currently defers to AGENTS).

---

### Phase 6 — Verify

**Commit (optional empty / or fold into last code commit):** verification is run, not necessarily a commit.

#### 6.1 Required commands

```bash
# Build
forge build

# Zero hits in live code trees (PRD may still mention symbols — exclude this plan/PRD if grepping composed/)
rg -n 'SingleVaultDetf|ISingleVaultDetf|DetfSuperchainBridgeRepo|composed/single' \
  contracts test scripts/foundry \
  --glob '!**/SingleVaultDetf_REMOVAL_*.md' \
  --glob '!**/archive/**'

# Remaining DETF family smoke
forge test --match-path 'test/foundry/spec/vaults/detf/standardExchange/single/**' -vv
forge test --match-path 'test/foundry/spec/vaults/detf/composed/multi-vault-weighted/**' -vv
forge test --match-path 'test/foundry/spec/vaults/detf/composed/stable/**' -vv
```

Optional if time:

```bash
forge test
```

Optional if local env up (not required for acceptance):

```bash
# foundation then scenario3 per scripts/foundry/local_testing/README.md
```

#### 6.2 Manual review checklist

- [ ] No accidental delete of `detf/core`, `reusable`, claim, bond, Single SE package.
- [ ] No accidental delete of seigniorage / `StandardExchangeSingleVaultSeigniorageDETF*` (name trap).
- [ ] Script_12 has no Superchain imports.
- [ ] Script_12 injects Uni V4 SE address into Single SE DETF PkgArgs.
- [ ] Artifact keys `inventoryDetf` + `balancerWethDetfPool` still exported.

---

## 4. KEEP vs REMOVE quick map

### REMOVE (exclusive)

| Asset | Phase |
|-------|-------|
| `contracts/vaults/detf/composed/single/**` | 2 |
| `contracts/interfaces/ISingleVaultDetf.sol` | 2 |
| `contracts/vaults/detf/DetfSuperchainBridgeRepo.sol` | 2 |
| `test/foundry/spec/vaults/detf/composed/single/**` | 1 |
| Archive Script_16 + bridge Script_22/23 (protocol-detf) | 4 |
| `SingleVaultDetf*` naming on seeder (rename or delete) | 3 |

### RETARGET (not delete)

| Asset | Phase |
|-------|-------|
| `Script_12_DeployScenario3Overlay.s.sol` | 3 |
| `scripts/foundry/local_testing/README.md` (Scenario 3) | 3 |
| Seeder file (rename if kept) | 3 |

### KEEP (shared / superseding)

See PRD §5. Especially: `core/`, `reusable/`, `bondNft/`, `claimToken/`, `DETFCommon.sol`, `standardExchange/single/**`, multi-vault / stable families, Uni V4 SE package, balancer 8020 math used by seigniorage.

### STAY IN REPO (records)

| Asset |
|-------|
| `contracts/vaults/detf/composed/SingleVaultDetf_REMOVAL_PRD.md` |
| `contracts/vaults/detf/composed/SingleVaultDetf_REMOVAL_IMPLEMENTATION_AND_TEST_PLAN.md` |

---

## 5. Scenario 3 implementer notes (pitfalls)

1. **Opacity:** Script_12 may deploy Uni V4 SE and pass the **address** into DETF args. DETF production code stays SE-opaque; only the script knows Uni V4.
2. **PkgInit vs PkgArgs:** Single SE DETF puts factory/facets/router/rateProvider/bondNft on **PkgInit**; vault address + rateTarget + weights + thresholds on **PkgArgs**. Do not reintroduce `underlyingVaultPkg` on DETF init.
3. **Claim token:** Current Script_12 deploys rebasing claim pkg and wires it into SingleVault PkgInit. Single SE DETF TestBase deploys bond NFT pkg; confirm whether claim pkg is required by Single SE DFPkg `postDeploy` — follow **Single SE DFPkg / TestBase**, not old SingleVault wiring, if they differ.
4. **Weights:** defaults 80/20 via 0,0 on PkgArgs is fine (product defaults).
5. **ThresholdMode:** `Policy` default is fine for local overlay.
6. **Name trap:** do not touch `StandardExchangeSingleVaultSeigniorageDETF*` under balancer vaults.
7. **Resume path:** `_loadExistingScenario` currently types packages as SingleVault; update types and optional 8020 factory reload when rewriting.

---

## 6. Test strategy

This is a **deletion + script retarget** PR. No new unit tests for the deleted family.

| Layer | Action |
|-------|--------|
| Family unit/integration tests | **Delete** with package (Phase 1) |
| Regression | Smoke remaining DETF family paths (Phase 6) |
| Scenario 3 | Static correctness of Script_12; optional anvil dry-run |
| Adversarial / fuzz for SingleVault | **Delete** with family — do not port to Single SE unless a separate task already tracks gaps |

**Production-first reminder:** Scenario 3 retarget must use real CREATE3 + registry deploy paths for Single SE DETF and Uni V4 SE; no `new` DFPkg/facets; no mocks of SUT.

---

## 7. Risk register (execution)

| Risk | Mitigation |
|------|------------|
| Hidden import | Phase 0 + Phase 6 greps; `forge build` |
| Over-delete shared libs | Phase 2 keep table; never delete `core/` / `reusable` / Single SE |
| Seigniorage name confusion | Explicit keep of balancer seigniorage paths |
| Script_12 rewrite incomplete | Checklist §3.3; compile Script_12 via `forge build` |
| Artifact key break for UI/tokenlist | Prefer stable `inventoryDetf` / `balancerWethDetfPool` |
| CI match-path still points at deleted tests | Grep CI/docs for `composed/single` under live configs; fix only if CI fails |
| Half-migrated bridge leftovers | Delete Superchain imports from Script_12; delete archive bridge scripts |

---

## 8. Out-of-scope follow-ups (do not block PR)

List only — not acceptance criteria:

| Item | Notes |
|------|-------|
| `docs/CODEBASE_MAP.md` | Still lists `composed/single/` |
| `docs/DETF_POOL_INTEGRATION_INVENTORY.md` | F5 / SingleVault rows |
| `docs/LAUNCH_PLAN.md`, `docs/ROBINHOOD_LAUNCH_PLAN.md` | Fee-sink still says SingleVaultDetf → retarget product narrative to SingleStandardExchangeDETF in a **product** follow-up |
| `docs/ANVIL_LOCAL_TESTING_SCENARIOS_PRD.md` | Scenario 3 / bridge steps stale |
| `docs/DEPLOYMENT_INVENTORY_DETAILED.md`, consolidation plans, `PLAN_fix_dfpkg…` | Historical references |
| `frontend/app/content/research/articles/detf-types.ts` | Deprecated path wording can be stripped once code is gone |
| Threshold-mode history docs F5 | Annotate “package later removed” if desired; product law unchanged |
| Required anvil Scenario 3 dry-run | Optional quality bar |
| Move PRD/plan to `docs/` | Explicitly **not** this PR (stay under `composed/`) |

---

## 9. Suggested PR title and commit series

**PR title:** `chore(detf): remove invalid SingleVaultDetf (composed/single)`

**Commits (phased):**

1. `test(detf): remove SingleVaultDetf composed/single specs`
2. `chore(detf): delete SingleVaultDetf package, interface, Superchain bridge repo`
3. `chore(local-testing): retarget Scenario 3 to SingleStandardExchangeDETF`
4. `chore(archive): delete SingleVaultDetf-dependent protocol-detf scripts`
5. `docs(agents): drop composed/single from DETF families table`

Squash message (if needed later) may use PRD §14 text.

---

## 10. Implementer order of operations (checklist)

```text
[x] Phase 0 greps clean (or plan amended)
[x] Phase 1 delete test tree
[x] Phase 2 delete production exclusives (not shared)
[x] Phase 3 rewrite Script_12 + rename seeder + README
[x] Phase 4 delete archive scripts
[x] Phase 5 AGENTS table
[x] Phase 6 forge build + greps + family smoke
[ ] PR opened with phased commits
[x] Stop (no §8 doc sweep unless blocked)
```

---

## 11. Definition of done

PRD acceptance criteria (§2 of this plan) all checked; no open Phase 0 surprises; implementer has not expanded into launch-plan product rewrite or optional anvil requirement.

---

*End of implementation plan. Normative product decisions remain in `SingleVaultDetf_REMOVAL_PRD.md`.*
