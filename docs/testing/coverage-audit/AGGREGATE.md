# Coverage Audit Aggregate — Stage 1 (Full Pass)

| Field | Value |
|-------|--------|
| Date | 2026-08-09 |
| Mode | **full** (pilot exit green; OBJECTIVE authorized full Stage 1) |
| PRD | `docs/testing/TEST_COVERAGE_AUDIT_PRD.md` (locks **L-TCA-1…8**) |
| Execute plan | `docs/testing/TEST_COVERAGE_AUDIT_EXECUTE_PLAN.md` |
| Scope | [`00_SCOPE_PARTITION.md`](./00_SCOPE_PARTITION.md) |
| Methodology | [`01_METHODOLOGY_NOTES.md`](./01_METHODOLOGY_NOTES.md) |
| Pilot exit | [`PILOT_EXIT.md`](./PILOT_EXIT.md) **GREEN** |
| Backlog | [`WORK_PACKAGE_BACKLOG.md`](./WORK_PACKAGE_BACKLOG.md) |
| Repro | `repro/TCA-COMMON-001/` (PAT-I-ABS helper free-credit **confirmed**); notes for MV/DL static |

---

## 1. Program metadata — area status

| Area | Status | Blocker | High | Path |
|------|--------|--------:|-----:|------|
| `T-basic-protocol-commons` | **COMPLETE** | 0* | 5 | `areas/T-basic-protocol-commons.md` |
| `T-detf-multi-vault` | **COMPLETE** | 2 | 3 | `areas/T-detf-multi-vault.md` |
| `T-se-aerodrome-camelot-univ2` | **COMPLETE** | 1 | 8 | `areas/T-se-aerodrome-camelot-univ2.md` |
| `T-detf-single-se` | **COMPLETE** | 4 | 5 | `areas/T-detf-single-se.md` |
| `T-detf-composed-stable` | **COMPLETE** | 4 | 7 | `areas/T-detf-composed-stable.md` |
| `T-detf-single-vault-seigniorage` | **COMPLETE** | 0 | 1 | `areas/T-detf-single-vault-seigniorage.md` (products **removed**) |
| `T-detf-dual-liquidity` | **COMPLETE** | 2 | 3 | `areas/T-detf-dual-liquidity.md` |
| `T-se-univ4-aave-balancer` | **COMPLETE** | 2 | 9 | `areas/T-se-univ4-aave-balancer.md` |
| `T-hooks-v4` | **COMPLETE** | 1 | 9 | `areas/T-hooks-v4.md` |
| `T-manager-fee-registry` | **COMPLETE** | 0 | 3 | `areas/T-manager-fee-registry.md` |
| `T-routers-permit2` | **COMPLETE** | 0 | 3 | `areas/T-routers-permit2.md` |

\*Commons area kept helper free-credit at High; **aggregate elevates Wave-0 commons CODE to Blocker epic** with runtime **confirmed** (`repro/TCA-COMMON-001`).

**Optional add-ons:** not required for DoD — `T-slipstream-buffer`, `T-research-contracts` skipped.

**FAILED areas:** none.

---

## 2. Executive summary + maturity heatmap

### 2.1 Headline

1. **PAT-I-ABS is the monorepo-wide ship blocker** — absolute / blind `pretransferred` credit in `BasicVaultCommon`, package-local `_pullToken` / `_receive` clones, Aave Stata free share mint, DualLiquidity receive, and hook CP free extract.
2. **Runtime proof (L-TCA-3):** hermetic BasicVaultCommon unit suite **confirms** free credit without caller transfer (`confirmed`). Product e2e free-mint/extract Blockers remain **RUNTIME_UNPROVEN** with static overwhelming CODE — Stage 2 must prove or demote per product.
3. **Gold MultiVault A–H remains F**; under full A–K bar maturity is **3**, not 5 (I/J/K incomplete).
4. **SingleVaultDetf / SeigniorageDETF removed** from tree — 2026-07 matrices **stale**; successor money path is Single SE DETF.
5. **Wave 0** must serialize commons CODE before product I suites; **Wave 1** parallelizes package-local PAT-I-ABS CODE + J/I tests.

### 2.2 Maturity heatmap (0–5)

| Product | Maturity | Worst open | Area |
|---------|----------|------------|------|
| BasicVaultCommon | **1** | Blocker epic (runtime free-credit) | commons |
| MultiVaultWeightedDetf | **3** | Blocker PAT-I-ABS pull/burn | multi-vault |
| SingleStandardExchangeDETF (Balancer) | **3** | Blocker PAT-I-ABS | single-se |
| Uni V4 CP Single SE DETF | **2** | Blocker PAT-I-ABS | single-se |
| Uni V4 legacy Single SE DETF | **1** | Blocker + scaffold | single-se |
| ComposedStableCommonDetf | **2** | Blocker blind pretransfer | composed-stable |
| MixedBufferMultiVaultStableDetf | **2** | Blocker pull/burn | composed-stable |
| DualLiquidityLinkedCrossVersion | **2** | Blocker `_receive` / `_receiveOut` | dual-liquidity |
| SingleVault / Seigniorage DETF | **N/A** | removed | single-vault-seigniorage |
| Aerodrome V1 SE | **3** | Blocker/High I | se-aero |
| Camelot V2 SE | **2** | I/J/H holes | se-aero |
| Uniswap V2 SE | **2** | no adversarial; I/J | se-aero |
| Uni V4 SE | **3** | Blocker PAT-I-ABS | se-uab |
| Aave Stata SE | **2** | Blocker free share mint | se-uab |
| Balancer SE Router / buffer | **4** | High J formal | se-uab |
| Hooks (factory) | **4** | — | hooks |
| Hooks Single SE Buffer | **4** | High residual I | hooks |
| Hooks Dual / SE CP | **2** | Blocker free extract | hooks |
| Manager / Registry / Fee oracle | **3–4** | High J-OMIT seigniorage query | manager |
| FeeCollector | **2–3** | High money-out tests | manager |
| Coordinator router + Permit2 | **3** | High I5 suite missing | routers |

### 2.3 Deduped Blocker inventory (CODE)

| Global theme | Representative findings | Products | Runtime |
|--------------|-------------------------|----------|---------|
| **BVC absolute pretransfer** | TCA-COMMON-001, TCA-SE-AC-001 | Aero/Camelot/UniV2/Aave Out burn | **confirmed** helper |
| **DETF `_pullToken` return amount_** | TCA-DETF-MV-001/002, SSE-001…004, CS-001/003/004 | MultiVault, Single SE, ComposedStable, MixedBuffer | RUNTIME_UNPROVEN |
| **DualLiquidity `_receive`** | TCA-DETF-DL-001/002 | DualLiquidity vault | RUNTIME_UNPROVEN |
| **Uni V4 SE local pull** | TCA-SE-UAB-001 | Uni V4 SE | RUNTIME_UNPROVEN |
| **Aave Stata free mint** | TCA-SE-UAB-002 | Aave Stata In | RUNTIME_UNPROVEN |
| **Hook CP free extract** | TCA-HOOK-001 | Single SE CP hook raw→pair | RUNTIME_UNPROVEN |

---

## 3. Global layer matrix (summary)

Legend: **F** full · **P** partial · **G** gap · **N/A** · **S** stub/theater

| Product class | H | N | D | J | I | K | A–H | P | L1 | L2 | L3 |
|---------------|---|---|---|---|---|---|-----|---|----|----|-----|
| MultiVault DETF | F | P | P | G/S | G | P | F (P0) | F | F | P | F |
| Single SE DETF (Bal) | F | P | P | G | G | G | P→F core | F | F | P | F |
| ComposedStable | P | P | P | G/S | G | G | P | P | G | G | G |
| MixedBuffer DETF | P | P | P | G | G | G | G | P | G | G | G |
| DualLiquidity | P | P | P | G | G | P† | P | P | P | P | G |
| SE Aero | F | P | P | G | G | P | P | F | F | G | P |
| SE Camelot / UniV2 | P | P | P | G | G | P/G | P/G | P | P/G | G | G |
| SE Uni V4 | F | P | P | P | G | P | G | F | P | G | P |
| SE Aave Stata | P | P | P | G | G | P | G | P | P | G | G |
| Balancer router/buffer | F | F | P | P | P‡ | P | P | F | P | P | F§ |
| Hooks (mature SE buf) | F | P | P | G | P | P | P | P | P | G | G |
| Manager/fee/registry | F | P | P | G | N/A | N/A | N/A | P | P | G | G |
| Coordinator router | F | P | G | G | P (I5 partial) | P | N/A | F | G | G | G |

† ShareInflation = A3-class BPT donation, not I/K.  
‡ Balancer prepay I5-class strong.  
§ BufferPool Foundry invariant gold.

---

## 4. Global catalog A–K incidence

| Catalog | Best coverage | Systemic gap |
|---------|---------------|--------------|
| **A** donation | MultiVault F; SE A1 partial; Dual ShareInflation | Many SE/DETF still G for full A1–A3 |
| **B** price/threshold | MultiVault F | Single SE / Composed partial |
| **C** reentrancy | MultiVault F; several SE partial | Composed G historically closed partial |
| **D** claim/bond | MultiVault F | Non-MV DETFs thin |
| **E** residual/guards | MultiVault + SE partial | Exact selectors often bare |
| **F** access | MultiVault F; SE diamondCut partial | Manager ACL exact selectors incomplete |
| **G** nested | MultiVault F; MixedBuffer F; Composed **G** | Composed outer G open |
| **H** grief/atomic | MultiVault F; SE H3 partial | — |
| **I** trust-flag | **Almost monorepo G** (staking SE ports + ERC4626 free-mint tests are positive outliers) | **P0 ship-gate fail** |
| **J** surface | Sparse declaration; few proxy J3 | **PAT-J-OMIT / theater epic** |
| **K** reserve sync | Partial (Route4, ERC4626) | Coupled to I on absolute pretransfer |

---

## 5. PAT incidence + epicenters

| Pattern | Incidence | Epicenter |
|---------|-----------|-----------|
| **PAT-I-ABS** | **Critical / monorepo** | `BasicVaultCommon`; DETF `_pullToken`; Dual `_receive`; Uni V4 SE; Aave Stata In; hook CP |
| **PAT-THEATER-PRE** | Widespread | Happy `*_pretransferred_true` + unit tests asserting free credit |
| **PAT-J-OMIT** | Medium–High | Fee seigniorage query typo; sparse facetFuncs coverage matrices |
| **PAT-J-CTRL / PAT-THEATER-FACET** | Medium | Facet `new` declaration without proxy |
| **PAT-K-DONATE** | Medium | Absolute inventory + pretransfer; residual after I fix |
| **PAT-MOCK** | Low–Medium | Aave mock units; MockStandardExchange must not count |
| **PAT-PREV** | Low–Medium | Spot-check product areas |

### PAT-I-ABS monorepo statement

**Not a clean bill.** Free absolute / blind pretransfer credit is **confirmed** on shared helper (runtime) and present as CODE pattern across DETF, SE, DualLiquidity, hooks.  
**Epic WPs:** `WP-I-COMMON-001` → `WP-I-CLONE-001` / package CODE → product `test_I1_*`.

### PAT-J-OMIT monorepo statement

**Not a clean bill.** Epic list:

1. MultiVault / DETF formal J1–J3 missing (declaration theater)
2. SE Aero/Camelot/UniV2/UniV4/Aave J matrices incomplete
3. Hooks area-wide J (factory loupe only partial)
4. Manager/registry almost no `*_IFacet` / proxy J (FeeCollector only partial)
5. Coordinator router no declaration J suite
6. **CODE:** manager fee seigniorage query typo `seeigniorageTermsTypeId` not on diamond (`TCA-MGR-001`)

---

## 6. Deduped Blocker / High findings (link areas)

### Blockers (deduped themes → WPs)

| Theme | Area findings | Primary WP |
|-------|---------------|------------|
| Commons absolute pretransfer | TCA-COMMON-001 | **WP-I-COMMON-001** |
| MultiVault pull/burn | TCA-DETF-MV-001/002 | **WP-I-DETF-MV-001** |
| Single SE DETF pull/burn (3 packages) | TCA-DETF-SSE-001…004 | **WP-I-DETF-SSE-001**, CP, UV4 |
| ComposedStable / MixedBuffer / Rebasing | TCA-DETF-CS-001…004 | **WP-I-DETF-CS-001**, **WP-I-DETF-MB-001** |
| DualLiquidity receive | TCA-DETF-DL-001/002 | **WP-I-DETF-DL-001** |
| SE BasicVaultCommon consumers | TCA-SE-AC-001 | **WP-I-COMMON-001** + **WP-I-SE-AC-001** |
| Uni V4 SE + Aave free mint | TCA-SE-UAB-001/002 | **WP-I-CLONE-UAB-001** |
| Hook CP free extract | TCA-HOOK-001 | **WP-I-HOOK-CP-001** |

### High clusters (non-exhaustive)

| Theme | WPs |
|-------|-----|
| I1–I3 missing everywhere money pretransfer exists | product `WP-I-*-002` tests after CODE |
| J1–J3 declaration + proxy | `WP-J-DETF-MV-001`, `WP-J-SE-AC-001`, `WP-J-HOOK-001`, `WP-J-MGR-002`, `WP-J-RTR-001` |
| Theater pretransfer | kill with I suite (commons + products) |
| SE adversarial thin / Uni V2 missing | `WP-ADV-SE-AC-001` |
| Permit2 replay / wrong spender | `WP-I5-RTR-001` |
| FeeCollector money-out | `WP-N-FEE-001` |
| Claim foreign-token residual | `WP-I-CLAIM-001` |

Full detail: area reports §5 + [`WORK_PACKAGE_BACKLOG.md`](./WORK_PACKAGE_BACKLOG.md).

---

## 7. Conflicts & decisions

| Conflict | Decision |
|----------|----------|
| Commons High vs product Blocker for same PAT-I-ABS | **Wave-0 commons CODE is Blocker epic** (runtime confirmed free credit). Product e2e free mint/extract stays Blocker CODE with RUNTIME_UNPROVEN until Stage 2/3 proves. |
| MultiVault “P0 complete” (2026-07) vs A–K bar | **Stale** — A–H still F; I/J/K incomplete → maturity 3 |
| SingleVault/Seigniorage in 2026-07 reports | **Removed** — no ship-blocking WP for deleted SUT; successor = Single SE DETF |
| Struct-audit vs this program | **L-TCA-4:** this backlog owns I/J/K CODE+TEST WPs; link prior IDs |
| Free residual “intentional” on some hooks | **NEEDS_OWNER** only if product law documents beneficiary; free **extract of SE book** remains Blocker |
| O4 “ask user before full” | **Overridden** by OBJECTIVE (pre-authorized full after pilot exit) — recorded in `PILOT_EXIT.md` |

---

## 8. Diff vs 2026-07 adversarial + fuzz reports

| Claim (2026-07) | Status now (2026-08-09) |
|-----------------|-------------------------|
| MultiVault adversarial P0/P1 complete | **Still F for A–H**; **Still gap for I/J/K** under current bar |
| Single SE DETF highest ROI adversarial port | **Partially closed** — `adversarial/` exists; **Still Blocker** PAT-I-ABS + I/J |
| ComposedStable adversarial thin | **Still gap** on G nested outer; I CODE open; P0 suite partial |
| DualLiquidity fork security slices | **Still P**; I/J Blocker CODE new under A–K; L-TCA-5 fork gaps High |
| SE Aero+Camelot shared adversarial | **Still P** (A1/E5/F1/H3); Uni V2 **Still G** adversarial |
| SingleVault / Seigniorage P0 | **Stale — products removed** |
| DETF L1/L3 critical gap | **Closed for MultiVault + Single SE Bal** (fuzz/invariant exist); **Still G** for ComposedStable / MixedBuffer |
| BufferPool only Foundry invariant | **Still gold**; Aerodrome has thin handler too |
| No I/J/K columns | **New** — primary value of this audit |

---

## 9. Recommended implementation waves (sketch → Stage 2)

| Wave | Contents | Serial constraints |
|------|----------|--------------------|
| **0** | `WP-I-COMMON-001` CODE + `WP-I-COMMON-002` tests; begin `WP-I-CLONE-001` API freeze | **Serial** on BasicVaultCommon |
| **1** | Package PAT-I-ABS CODE (MV, SSE, CS, MB, DL, UAB, HOOK) + product I1–I3 + J1–J3 parallel by package | Not same Facet file concurrent |
| **2** | Remaining A–H ports, SE adversarial expand, K1, theater kill, Permit2 I5, FeeCollector N | After Wave 0 |
| **3** | L1/L3 property layer on products still G | After I CODE |
| **4** | P2, stub retirement, optional BasicVault surface | — |

**Do not** open `gap_cover_*` worktrees in Stage 1.

---

## 10. Link to backlog + Stage 1 DoD (PRD §12)

Primary handoff: [`WORK_PACKAGE_BACKLOG.md`](./WORK_PACKAGE_BACKLOG.md)

| PRD §12 item | Status |
|--------------|--------|
| `00_SCOPE_PARTITION.md` used for spawning | **Yes** |
| Every planned area COMPLETE/PARTIAL/FAILED | **Yes** — all 11 COMPLETE (3 pilot + 8 full) |
| Area reports §7.2 sections 1–10 | **Yes** (QA greps) |
| AGGREGATE global matrices, PAT, prior diff, waves | **Yes** (this file) |
| WORK_PACKAGE_BACKLOG ranked + §8 fields for Blocker/High | **Yes** — 44 formal WPs; **finding→WP index** maps all **69** Blocker/High TCA IDs (see backlog § index) |
| PAT-I-ABS finding + runtime attempt | **Yes** — confirmed `repro/TCA-COMMON-001` |
| PAT-J-OMIT monorepo statement | **Yes** §5 |
| Ship-blocking money products in inventory | **Yes** (removed products marked N/A with evidence) |
| No Stage 3 / no committed product-test fixes | **Yes** — writes only under `docs/testing/coverage-audit/**` |

### Stage 2 handoff prompt

```text
Read docs/testing/TEST_COVERAGE_AUDIT_PRD.md §13 and docs/testing/coverage-audit/AGGREGATE.md
+ WORK_PACKAGE_BACKLOG.md. Write docs/testing/TEST_COVERAGE_GAP_CLOSURE_IMPLEMENTATION_PLAN.md:
waves, gap_cover_* worktrees/branches, serial Wave 0 commons, parallel product WPs,
subagent prompts, forge acceptance, merge order. Do not implement code yet.
```

---

## 11. Ship-blocking product inventory (L-TCA-2)

All of the following appear in area inventories (pilot + full):

- DETF: MultiVault, Single SE (Bal + Uni V4), ComposedStable, MixedBuffer, DualLiquidity  
- SE: Aerodrome, Camelot, Uni V2, Uni V4, Aave Stata, Balancer routers/buffers  
- Hooks: Uni V4 hook packages (factory + SE buffers + Dual + pure AMM families)  
- Manager / fee oracle / vault registry / FeeCollector  
- Fund routers: BalancerV3–UniswapV4 Coordinator + Permit2  

**Removed (not ship-blocking):** SingleVaultDetf, SeigniorageDETF product packages.
