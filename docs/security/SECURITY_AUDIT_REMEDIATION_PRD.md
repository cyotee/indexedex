# Product Requirements Document (PRD)

## Title

**IndexedEx Security Audit Remediation** — production CODE (class CODE/BOTH) and production-first Foundry tests (class TEST/THEATER) that close Stage 1 security-audit High findings this program owns, via parallel `sec_fix_*` worktrees

---

## 1. Header

| Field | Value |
|-------|--------|
| **Status** | **READY-FOR-IMPLEMENTATION** (Stage 2 PRD; authorizes Stage 3 only after an accepted execute plan) |
| **Kind** | Fix / remediation PRD |
| **Date** | 2026-08-13 |
| **Depends on Stage 1** | [`docs/security/audit/AGGREGATE.md`](./audit/AGGREGATE.md), [`WORK_PACKAGE_BACKLOG.md`](./audit/WORK_PACKAGE_BACKLOG.md), [`00_SCOPE_PARTITION.md`](./audit/00_SCOPE_PARTITION.md), [`PILOT_EXIT.md`](./audit/PILOT_EXIT.md), [`repro/`](./audit/repro/), area/specialist reports under [`docs/security/audit/`](./audit/) |
| **Stage 1 audit law** | [`docs/security/SECURITY_AUDIT_PRD.md`](./SECURITY_AUDIT_PRD.md) §§2, 8, 13–14, locks **L-SEC-1…14** |
| **Stage 2 planner prompt** | [`docs/security/PROMPT_SECURITY_AUDIT_REMEDIATION_PRD.md`](./PROMPT_SECURITY_AUDIT_REMEDIATION_PRD.md) |
| **Normative backlog** | **Critical WPs: none.** **36** High `WP-SEC-*` (this program). Every High `SEC-*` is indexed (this program / OWNED_ELSEWHERE / alias). No new `SEC-*` / `WP-SEC-*` IDs. |
| **Primary skills** | `crane-adversarial-testing` (+ `references/implementation-test-dod.md`), `indexedex-adversarial-testing`, `crane-testing`, `indexedex-testing`; deploy: `crane-deployment` / `crane-architecture` |
| **Worktree / branch prefix** | `sec_fix_` (**L-SEC-8**) — e.g. worktree `sec_fix_e6-common`, branch `sec_fix/e6-common`. **Never** `gap_cover_`. |
| **Fork RPC** | `foundry.toml` `*_alchemy` endpoints + `ALCHEMY_KEY` (**L-SEC-6**); profile `FOUNDRY_PROFILE=fork` |
| **Orchestrator concurrency** | **≤ 3** live `sec_fix_*` worktrees (**L-SEC-12**). Not raised. |
| **Package packing** | **One worktree per package** after Wave 0 (**L-SEC-13**). Two WPs that share a production file sit in the same slice. |
| **Execute plan** | Optional companion: [`docs/security/SECURITY_AUDIT_REMEDIATION_IMPLEMENTATION_PLAN.md`](./SECURITY_AUDIT_REMEDIATION_IMPLEMENTATION_PLAN.md) |
| **Collision with coverage-audit** | Gap-closure Stage 3 is **44/44 closed** (`docs/testing/coverage-audit/STAGE3_PROGRESS.md` @ `03d2f1c`). **No open `gap_cover_*` worktrees** at PRD authorship. Do **not** reopen closed I-ABS / pull bodies. OWNED_ELSEWHERE stays appendix-only. |
| **Supersession** | This program owns **new** High CODE/TEST not already a coverage `WP-I-*` / `WP-J-*` / `WP-N-*` primary touch-set (E6 refunds, remaining PAT-I-ABS clones, A0, CROPS disable-on-exit, CS lock/minter, DualLiq residual, UV4 extra burn/NFT, import, Route4, Camelot Out). Coverage-audit remains SoT for closed I/J/K pull/surface WPs (**L-SEC-4**). |

---

## 2. Intent & success definition

### 2.1 Why this program exists

Stage 1 (`SHA 1e0d7c48`) found **no Critical** live extract. Commons token PAT-I-ABS is **blocked** (`repro/SEC-COMMON-001/` — 9/9 I1–I3). Coverage-audit 2026-08-09 Blocker pulls on MultiVault / Single SE / CS / DualLiq receive / Uni V4 SE token / Stata / hook CP are **OWNED_ELSEWHERE** (mostly closed in production).

This program closes the **new High** surface Stage 1 actually owns:

1. **E6 refund / self-burn** — `max−used` and entire-`balanceOf` refunds skim booked inventory (`BasicVaultCommon`, AMM v2 Out, Slipstream, Uni V3, Uni V4 SE zap-out, SinglePool).
2. **Remaining PAT-I-ABS clones** — Aave CrossVersion Loop skip-pull; Uni V4 extra **burn** skip-`_pullToken`; SinglePool `_receiveExactIn`; Uni V3 zap-out self-share (pull body itself stays coverage `WP-I-CLONE-001`).
3. **A0 empty / first-mint** — SE zap-in, DualLiq 1:1 genesis, Uni V3/V4 SE, catalog `test_A0_*` on gold DETFs.
4. **Trust / surface** — disable-gated DETF pause on claim/exit (`SEC-CROPS-001`); CS leftover `detfToken` minter; CS missing `nonReentrant`; Uni V4 `importPosition`; MultiVault PkgArgs hostile `vaultShare`.
5. **TEST honesty** — DualLiq fork I/K theater; LST / ERC4626 I/J; claim/bond J; extra Uni V4 I/J/A0.

Success is **not** “tests green on a still-exploitable path.”

### 2.2 Goals

1. Close every **High** `WP-SEC-*` in §5 with production CODE (CODE/BOTH) and production-first Foundry tests (TEST/THEATER/DOCS-as-specified).
2. Keep Wave 0 commons **serial**; then spawn **conflict-free package slices** with **≤ 3** live `sec_fix_*` worktrees.
3. Require **proof-first** runtime for every Stage 1 High CODE labeled `RUNTIME_UNPROVEN` (pass = **exploit blocked**).
4. Hand Stage 3 a law document such that **this PRD + Stage 1 backlog + linked `SEC-*`** are enough — no monorepo re-audit.

### 2.3 Success definition

| Criterion | Meaning |
|-----------|---------|
| **High CODE closed** | Named extract / free mint / leftover admin / disable-on-exit is impossible on the touched path; acceptance tests fail on pre-fix code and pass post-fix |
| **I1–I3 (where WP touches I)** | Catalog-named free-mint proofs; I1 does **not** transfer tokens in-call; happy `pretransferred=true` with a real transfer is **not** I1 |
| **J1–J3 (where WP touches J)** | Target ⊆ `facetFuncs` ⊆ cuts ⊆ loupe ⊆ **proxy** callable (never facet impl address) |
| **A0 / E6 (where WP touches)** | First minter cannot drain pre-seeded inventory; surplus refund cannot pay booked `R` |
| **No greenwash** | Theater tests asserting free credit / `max−used` skim / ShareInflation-as-I are inverted or renamed; mock SUT never counts |
| **Waves respected** | Commons E6 helper lands before dependent AMM v2 Out call-sites; merge order preserves conflict-free slices |
| **Evidence** | `forge test` (and fork where required) pasted in PR/worklog; optional repro under `docs/security/audit/repro/<FINDING_ID>/` |

### 2.4 Non-goals

See §11. Stage 3 is **not** authorized by this authorship run.

---

## 3. Imported security bar (do not weaken)

Source of truth: Stage 1 PRD §2, `crane-adversarial-testing`, `implementation-test-dod.md`, `indexedex-adversarial-testing`. Close criteria this program actually touches:

### 3.1 Trust-flag catalog (I)

Normative pull / credit (L-CLAIM-3 / L-GAPS-9 — do not re-decide):

| Rule | Behavior |
|------|----------|
| **Measure** | Observe **inbound balance delta** (or durable `U = B − R` where the package already books `R`). Absolute `balanceOf(this)` alone is **not** delivery. |
| **Credit** | If `claimed ≤ delta` (or `U`), credit **exactly `claimed`**. |
| **Short** | If `claimed > delta`, revert `TransferDeltaInsufficient(claimed, observed)` (`ISecurePullErrors`). Do not silently cap. Do not free-credit inventory. |
| **No exact-delta grief** | Do **not** require `delta == claimed`. Extra inbound (donation) must not lock honest depositors. |

| ID | Must prove |
|----|------------|
| **I1** | `pretransferred=true`, **no** caller transfer, vault/diamond already holds ≥ claimed → **delta = 0** → shared short-delivery revert (no free mint / free extract / free burn of inventory shares) |
| **I2** | Short delivery (`claimed > delta`) → **exact** `TransferDeltaInsufficient` |
| **I3** | Residual after a partial path cannot fund a second free credit |

**Anti-theater:** happy-path `pretransferred=true` **with a real transfer** is **not** I1–I3. I1 must not transfer tokens in-call.

### 3.2 Surface catalog (J)

| ID | Must prove |
|----|------------|
| **J1** | Target / product interface money selectors ⊆ Facet `facetFuncs()` (controls from Target, not incomplete Facet copy) |
| **J2** | Selectors in package `facetCuts`; loupe `facetAddress(sel) != 0` |
| **J3** | Smoke-call each money selector on the **deployed proxy**, never the facet implementation address |

### 3.3 E6 surplus-refund

If any path refunds residual tokens / `vaultShare` to the caller:

- Refund **this-call unused inbound only** (`min(max−used, unused U)` or snapshot unused).
- Seed booked inventory; fat `max` + transfer of only `used` must **not** skim `R`.
- `_secureSelfBurn` must not sweep leftover `address(this)` shares that were not delivered this call.

### 3.4 A0 empty-vault / first mint

First minter / first bond / zap-in / 1:1 genesis **cannot** absorb pre-seeded / donated inventory at `totalSupply==0` (or stale `lastTotalAssets`). Donate **before** live; redeem must not profit the first mover beyond documented fees.

### 3.5 F / CROPS leftover admin + disable

- DETF instances are **unowned / immutable after deploy** (L-SEC-11). Leftover `owner` / minter / `diamondCut` on a live DETF or satellite `detfToken` is High.
- Registry `setVaultAddressDisabled` must **not** freeze mature `closeBondMature` / `redeemClaim` / user exit on disable-gated families. Inbound-only gates (new mint / new bond) may remain if product keeps a deploy-time kill switch.
- Acceptance: call **after** `setVaultAddressDisabled(true)` on the production proxy.

### 3.6 L / M (where WP touches)

- **L2** (TOKEN-001): real FoT as the **configured** token, not a mock SUT.
- **M** (import / SinglePool approve): untrusted PM/owner must revert; no unbounded Permit2 approve of booked inventory.

### 3.7 Deploy bar (non-negotiable)

- Facets: CREATE3 / `*FactoryService` / `create3Factory` — **never** `new` production facets on user paths.
- Vault / DETF DFPkgs: **IndexedEx manager vault registry** (`indexedexManager.deploy*DFPkg` / registry path) — never bypass with bare `diamondPackageFactory.deploy` for registered vault packages.
- Gold TestBases: `CraneTest` → `IndexedexTest` → protocol TestBase. **No mocks of SUT.**
- **`via_ir` forbidden** (L-SEC-14). No package-specific IR profiles.

### 3.8 DETF role names only

Use only: `rateAsset`, `pairToken`, `underlyingVault` / `standardExchangeVault`, `vaultShare`, `detfToken` / `address(this)`, `reservePool` / `reserveBpt`, `rebasingClaimToken`. Never product brands (RICH/RICHIR, etc.).

### 3.9 Pass = exploit blocked (L-SEC-10)

Never treat fork `assertGt(attackerProfit, 0)` as coverage. Never greenwash free mint / unbounded extract as “expected” without `NEEDS_OWNER` + documented invariants.

---

## 4. Locked product law (do not re-decide)

| Lock / source | Statement |
|---------------|-----------|
| **L-SEC-1…14** | Reaffirmed in full. Especially: all money products ship-blocking (L-SEC-2); runtime proof for Critical CODE (L-SEC-3; Stage 1 has **no** Critical — High `RUNTIME_UNPROVEN` still proof-first); do not compete with coverage on the same primary files (L-SEC-4); fork P0 = hermetic severity (L-SEC-5); Alchemy `*_alchemy` (L-SEC-6); repro under `docs/security/audit/repro/` (L-SEC-7); `sec_fix_` prefix (L-SEC-8); catalog SoT A–K + A0/L/M/N/O + E6/F5 (L-SEC-9); pass = exploit blocked (L-SEC-10); DETF unowned after deploy (L-SEC-11); concurrency ≤ 3 (L-SEC-12); one worktree per package (L-SEC-13); no `via_ir` (L-SEC-14) |
| **L-CLAIM-3 / L-GAPS-9** | `pretransferred=true` credits only against **observed inbound delta** (or durable `U = B − R` where the package already books `R`). `claimed ≤ delta` → credit `claimed`; `claimed > delta` → `TransferDeltaInsufficient`. Do **not** require exact-delta equality. |
| **L-SEC-11 / agent law** | DETF instances immutable / unowned after deploy; inert until first bond / family bootstrap; sell→claim only after bond maturity (DETF-wide); mint/burn thresholds from `PkgArgs` → `DETFThresholdPolicy`; fees via fee oracle |
| **Seigniorage** | Open thresholds may allow bounded skew extract — **ACCEPTED_RISK** only with victim-balance + no-free-principal + residual-inventory invariants. Do not “fix” documented seigniorage. |
| **DualLiquidity delta (SEC-DETF-DL-003)** | **NEEDS_OWNER** pick: (A) durable `U` per L-CLAIM-3 **or** (B) keep same-tx and invert two-tx/Permit2 theater. **Default if owner silent: (B)** — keep same-tx (already I1-safe); invert `pushThenTrue` / Permit2-`true` / surplus-refund-to-caller; NatSpec. **Never restore** no-op `_receive` or `held − amountIn` refund. Do not silently convert to durable `U` (larger blast; closed `WP-I-DETF-DL-001`). |
| **Orbital `depositClaim` (SEC-DETF-UV4-008)** | Family PRD locks the API. **Default: implement** on orbital (copy weighted). Owner may amend the family PRD instead — then DOCS close, J must not claim a missing selector. |
| **Weird tokens (SEC-SPEC-010 / WP-SEC-TOKEN-001)** | **NEEDS_OWNER** policy first. Do not invent an allowlist or FoT economics. Wave 3. |
| **Gap-closure I/J/K** | Closed pull bodies stay closed. This program does **not** restyle `BasicVaultCommon._secureTokenTransfer`, MultiVault `_pullToken`, Uni V3 `_secureTokenTransfer`, shared `RebasingClaimToken` pull, hook CP/SE-buffer I, Coordinator I5/J/N. |

---

## 5. Normative WP inventory

**Source:** `docs/security/audit/WORK_PACKAGE_BACKLOG.md` only. **Critical WPs: none** — do not invent any. **No High WP is dropped.** `WP-SEC-TOKEN-001` stays (High NEEDS_OWNER, Wave 3). **No DEFER.**

Acceptance language may be refined below; IDs, severity, class, and touch-sets are Stage 1’s.

### 5.1 Finding → WP index (every High `SEC-*`)

| FINDING_ID | Sev / Class | Disposition | WP / coverage ID |
|------------|-------------|-------------|------------------|
| SEC-COMMON-002 | High CODE | this program | `WP-SEC-E6-COMMON-001` |
| SEC-COMMON-003 | High OE | appendix | `WP-I-CLONE-001` |
| SEC-SHARP-002 | High CODE | this program | `WP-SEC-E6-COMMON-001` |
| SEC-SHARP-003 | High CODE | this program | `WP-SEC-E6-COMMON-001` |
| SEC-SHARP-004 | High CODE | this program | `WP-SEC-I-SE-4626-001` |
| SEC-SHARP-006 | High CODE | this program | `WP-SEC-PKG-MV-001` |
| SEC-SHARP-010 | High OE | appendix | I-ABS helper closed (`WP-I-COMMON-001`) |
| SEC-SHARP-011 | High OE | appendix | MultiVault pull closed |
| SEC-SE-AC-001 | High CODE | this program | `WP-SEC-E6-SE-001` |
| SEC-SE-CAM-001 | High CODE | this program | `WP-SEC-CAM-OUT-001` |
| SEC-SE-CAM-002 | High CODE | this program | `WP-SEC-R4-SE-001` |
| SEC-SE-U2-001 | High CODE | this program | `WP-SEC-R4-SE-001` |
| SEC-SE-AC-002 | High CODE | this program | `WP-SEC-A0-SE-001` |
| SEC-SE-AC-003 | High OE | appendix | `WP-I-SE-AC-001` |
| SEC-SE-AC-004 | High OE | appendix | `WP-J-SE-AC-001` / `WP-ADV-SE-AC-001` |
| SEC-DETF-MV-007 | High TEST | this program | `WP-SEC-DETF-MV-A0-001` |
| SEC-CROPS-001 | High CODE | this program | `WP-SEC-CROPS-001` |
| SEC-SPEC-001 | High OE (alias) | this program via alias | same as `SEC-CROPS-001` → `WP-SEC-CROPS-001` |
| SEC-SPEC-010 | High NEEDS_OWNER | this program | `WP-SEC-TOKEN-001` |
| SEC-SPEC-020 | High CODE | this program | `WP-SEC-E6-COMMON-001` (epic pointer) |
| SEC-SPEC-030 | High TEST | this program | `WP-SEC-I-LST-001` + `WP-SEC-J-LST-001` + `WP-SEC-I-ERC4626-001` + `WP-SEC-E6-SLIP-001` |
| SEC-SPEC-040 | High OE | appendix | `WP-I5-RTR-001` |
| SEC-DETF-SSE-010 | High TEST | this program | `WP-SEC-DETF-SSE-A0-001` |
| SEC-DETF-CS-013 | High CODE | this program | `WP-SEC-DETF-CS-LOCK-001` |
| SEC-DETF-CS-014 | High CODE | this program | `WP-SEC-DETF-CS-TOKEN-001` |
| SEC-DETF-CS-015 | High TEST | this program | `WP-SEC-DETF-CS-A0-001` |
| SEC-DETF-DL-003 | High CODE | this program | `WP-SEC-DETF-DL-DELTA-001` |
| SEC-DETF-DL-004 | High CODE | this program | `WP-SEC-DETF-DL-A0-001` |
| SEC-DETF-DL-005 | High TEST | this program | `WP-SEC-DETF-DL-I-HONESTY-001` |
| SEC-DETF-UV4-002 | High CODE | this program | `WP-SEC-DETF-UV4-BURN-I1-001` |
| SEC-DETF-UV4-003 | High TEST | this program | `WP-SEC-DETF-UV4-I-SUITE-001` |
| SEC-DETF-UV4-004 | High TEST | this program | `WP-SEC-DETF-UV4-J-001` |
| SEC-DETF-UV4-005 | High TEST | this program | `WP-SEC-DETF-UV4-A0-001` |
| SEC-DETF-UV4-006 | High CODE | this program | `WP-SEC-DETF-UV4-NFT-001` |
| SEC-DETF-UV4-007 | High CODE | this program | `WP-SEC-DETF-UV4-NFT-001` |
| SEC-DETF-UV4-008 | High CODE | this program | `WP-SEC-DETF-UV4-ORB-CLAIM-001` |
| SEC-DETF-COM-001 | High OE | appendix | `WP-I-CLAIM-001` |
| SEC-DETF-COM-004 | High TEST | this program | `WP-SEC-DETF-COM-J-001` |
| SEC-SE-U3-001 | High OE | appendix | `WP-I-CLONE-001` |
| SEC-SE-U3-002 | High CODE | this program | `WP-SEC-E6-U3-001` |
| SEC-SE-U3-003 | High CODE | this program | `WP-SEC-I-U3-SHARE-001` |
| SEC-SE-U3-004 | High CODE | this program | `WP-SEC-A0-U3-001` |
| SEC-SE-U3-006 | High OE | appendix | `WP-I-CLONE-001` |
| SEC-SE-U4-002 | High CODE | this program | `WP-SEC-E6-U4-001` |
| SEC-SE-U4-003 | High CODE | this program | `WP-SEC-IMP-U4-001` |
| SEC-SE-U4-004 | High CODE | this program | `WP-SEC-A0-U4-001` |
| SEC-SE-AAVE-001 | High CODE | this program | `WP-SEC-I-AAVE-LOOP-001` |
| SEC-SE-AAVE-002 | High CODE | this program | `WP-SEC-I-AAVE-LOOP-001` |
| SEC-SE-AAVE-003 | High OE | appendix | `WP-I-SE-UAB-001` |
| SEC-SE-AAVE-004 | High OE | appendix | blast of `WP-SEC-E6-COMMON-001` (commons file) |
| SEC-SE-LST-001 | High TEST | this program | `WP-SEC-I-LST-001` |
| SEC-SE-LST-002 | High TEST | this program | `WP-SEC-J-LST-001` |
| SEC-SE-4626-001 | High TEST | this program | `WP-SEC-I-ERC4626-001` |
| SEC-SE-4626-002 | High TEST | this program | `WP-SEC-I-ERC4626-001` |
| SEC-SE-SLIP-001 | High CODE | this program | `WP-SEC-E6-SLIP-001` |
| SEC-SE-SLIP-002 | High CODE | this program | `WP-SEC-E6-SLIP-001` |
| SEC-SE-SLIP-003 | High TEST | this program | `WP-SEC-E6-SLIP-001` |
| SEC-SE-BAL-001 | High CODE | this program | `WP-SEC-I-BAL-SINGLE-001` |
| SEC-SE-BAL-002 | High OE | appendix | `WP-J-ROUTER-UAB-001` |
| SEC-HOOK-SE-001 | High OE | appendix | `WP-I-HOOK-SEBUF-001` / `WP-J-HOOK-001` |
| SEC-HOOK-SE-002 | High OE | appendix | `WP-I-HOOK-CP-001` / `WP-I-HOOK-DUAL-001` |
| SEC-HOOK-SW-001 | High OE | appendix | `WP-J-HOOK-001` |
| SEC-RTR-001 | High OE | appendix | `WP-I5-RTR-001` / `WP-J-RTR-001` / `WP-N-RTR-001` |
| SEC-MGR-001 | High OE (alias) | this program via alias | `WP-SEC-CROPS-001` (DETF files, not manager) |
| SEC-MGR-002 | High OE | appendix | `WP-J-MGR-001` |
| SEC-MGR-003 | High OE | appendix | `WP-J-MGR-002` |
| SEC-FEE-001 | High OE | appendix | `WP-N-FEE-001` |

### 5.2 This-program High WPs (36) — compact Stage 1 fields

Cross-package WPs (`WP-SEC-E6-SE-001`, `WP-SEC-R4-SE-001`, `WP-SEC-A0-SE-001`, `WP-SEC-I-SE-4626-001`, `WP-SEC-CROPS-001`) are **split across package slices** in §7 (L-SEC-13). The WP-ID is not renamed.

| WP-ID | Title | Sev | Class | Products | Proof-first? |
|-------|-------|-----|-------|----------|--------------|
| `WP-SEC-E6-COMMON-001` | Cap `_refundExcess` + `_secureSelfBurn` to this-call unused inbound | High | BOTH | BasicVaultCommon | **yes** |
| `WP-SEC-CAM-OUT-001` | Transfer `tokenOut` to recipient; stop overwriting `amountIn` | High | BOTH | Camelot V2 SE | **yes** |
| `WP-SEC-E6-SE-001` | Cap Aero/Camelot/Uni V2 Out refunds to this-call unused | High | BOTH | Aero, Camelot, Uni V2 SE | **yes** |
| `WP-SEC-R4-SE-001` | Camelot + Uni V2 Route4 convert against pre-deposit reserve | High | BOTH | Camelot, Uni V2 SE | **yes** |
| `WP-SEC-I-AAVE-LOOP-001` | Credit/burn Loop only against observed inbound delta | High | BOTH | AaveCrossVersionLoop | **yes** |
| `WP-SEC-E6-SLIP-001` | Cap Slipstream In/Out refunds; add I/J/E6 | High | BOTH | Slipstream SE | **yes** |
| `WP-SEC-E6-U3-001` | Uni V3 entire-balance refund cap | High | BOTH | Uni V3 SE | **yes** |
| `WP-SEC-I-U3-SHARE-001` | Uni V3 zap-out: do not burn self-held `vaultShare` without inbound delta | High | BOTH | Uni V3 SE | **yes** |
| `WP-SEC-A0-U3-001` | Uni V3 first mint cannot drain pre-seeded inventory | High | BOTH | Uni V3 SE | **yes** |
| `WP-SEC-E6-U4-001` | Uni V4 SE zap-out leftover `vaultShare` cap | High | BOTH | Uni V4 SE vault | **yes** |
| `WP-SEC-IMP-U4-001` | Auth-gate Uni V4 SE `importPosition` PM/owner | High | BOTH | Uni V4 SE vault | **yes** |
| `WP-SEC-A0-U4-001` | Uni V4 SE first mint / virtual offset | High | BOTH | Uni V4 SE vault | **yes** |
| `WP-SEC-I-BAL-SINGLE-001` | Delta-safe SinglePool receive + cap refund/allowance | High | BOTH | BalancerV3SinglePool SE | **yes** |
| `WP-SEC-DETF-UV4-BURN-I1-001` | Extra Uni V4 DETF burn must `_pullToken` | High | BOTH | Weighted / Orbital / Curve-quad | **yes** |
| `WP-SEC-DETF-UV4-I-SUITE-001` | Named I1–I3 on extra Uni V4 DETF proxies | High | TEST | same | no |
| `WP-SEC-DETF-UV4-J-001` | J1–J3 proxy surface extra Uni V4 DETFs | High | TEST | same | no |
| `WP-SEC-DETF-UV4-A0-001` | First-bond A0 on extra Uni V4 DETFs | High | TEST | same | no |
| `WP-SEC-DETF-UV4-NFT-001` | Strip leftover owner + delta-gate unused Uni V4 local NFT/claim | High | BOTH | UniV4DetfBondNft, UniV4DetfRebasingClaim | **yes** |
| `WP-SEC-DETF-UV4-ORB-CLAIM-001` | Implement PRD-locked orbital `depositClaim` or document removal | High | BOTH / DOCS | Orbital DETF | no |
| `WP-SEC-DETF-CS-LOCK-001` | ComposedStable `nonReentrant` on mint/bond | High | BOTH | ComposedStableCommonDetf | **yes** |
| `WP-SEC-DETF-CS-TOKEN-001` | Unown / revoke minter on CS satellite `detfToken` | High | BOTH | RebasingDETFToken (CS) | **yes** |
| `WP-SEC-DETF-CS-A0-001` | CS / MixedBuffer `test_A0_*` | High | TEST | CS + MixedBuffer | no |
| `WP-SEC-DETF-DL-A0-001` | DualLiquidity A0 — 1:1 genesis cannot capture idle `reserveBpt` | High | BOTH | DualLiquidity | **yes** |
| `WP-SEC-DETF-DL-DELTA-001` | Align DualLiquidity receive with docs or invert tests | High | BOTH / DOCS | DualLiquidity | **yes** |
| `WP-SEC-DETF-DL-I-HONESTY-001` | Replace DualLiquidity I/K theater with fork I1–I3 + K1 | High | TEST | DualLiquidity | no |
| `WP-SEC-CROPS-001` | Remove `_requireNotDisabled` from DETF claim/exit (and Uni V2 Out) | High | BOTH | disable-gated DETF + Uni V2 SE | no |
| `WP-SEC-DETF-MV-A0-001` | MultiVault catalog `test_A0_*` | High | TEST | MultiVaultWeightedDetf | no |
| `WP-SEC-DETF-SSE-A0-001` | Balancer + Uni V4 CP Single SE `test_A0_*` | High | TEST | Single SE DETFs | no |
| `WP-SEC-DETF-COM-J-001` | J1–J3 on shared RebasingClaimToken + DETFNFTVault | High | TEST | claim / bond diamonds | no |
| `WP-SEC-I-LST-001` | Named I1–I3 on Lido / EtherFi / Rocket SE | High | TEST | three LST SE | no |
| `WP-SEC-J-LST-001` | J1–J3 proxy surface for three LST SE | High | TEST | three LST SE | no |
| `WP-SEC-I-ERC4626-001` | Real I1–I3 + J1–J3 on ERC4626 SE | High | TEST | ERC4626StandardExchange | no |
| `WP-SEC-A0-SE-001` | Aero/Camelot/Uni V2 zap-in / empty-supply residual LP | High | BOTH | AMM v2 SE | **yes** |
| `WP-SEC-I-SE-4626-001` | SE LP-deposit must not credit `lastTotalAssets` exact gap | High | BOTH | AMM v2 SE In | **yes** |
| `WP-SEC-PKG-MV-001` | Lock MultiVault PkgArgs `vaultShares[i]` to registered SE | High | BOTH | MultiVaultWeightedDetf | no |
| `WP-SEC-TOKEN-001` | Document or reject FoT / rebase / 6-dec / pause underlyings | High | DOCS / TEST (CODE if allowlist) | SE/DETF PkgArgs IERC20 | no |

Full §8 fields (problem, out-of-scope, implementation notes) remain in the Stage 1 backlog — implementers **must** open that file plus the linked `SEC-*` write-up. This PRD does not restate every Stage 1 paragraph.

---

## 6. OWNED_ELSEWHERE appendix

**Out of this program’s Stage 3.** No competing `sec_fix_*` on these **primary** files. Handled by gap-closure (`docs/testing/TEST_COVERAGE_GAP_CLOSURE_PRD.md` + `STAGE3_PROGRESS.md` 44/44) or already closed at `1e0d7c48`.

| SEC / note | Coverage / other ID | Primary touch-set (do not `sec_fix_*`) |
|------------|---------------------|----------------------------------------|
| Commons token I-ABS (`SEC-SHARP-010`) | `TCA-COMMON-001`, `WP-I-COMMON-001/002` | `BasicVaultCommon._secureTokenTransfer` **body** (E6 helper functions in the same file are **this** program — Wave 0 must not reopen I-ABS) |
| MultiVault I/J/K (`SEC-SHARP-011`) | `WP-I-DETF-MV-*`, `WP-J-DETF-MV-001`, `WP-K-DETF-MV-001` | MultiVault Common/Targets `_pullToken` / I/J/K suites |
| SE AMM v2 I/J/ADV (`SEC-SE-AC-003/004`) | `WP-I-SE-AC-001`, `WP-J-SE-AC-001`, `WP-ADV-SE-AC-001` | Aero/Cam/U2 **I/J/ADV tests** (not E6/Route4/A0/Out-drop CODE) |
| Aero deadline / Camelot H | `WP-E5-AERO-001`, `WP-H-CAM-001` | deadline CODE (closed); Camelot H **tests** (do not collide Route4 **CODE**) |
| Uni V3 **pull** (`SEC-COMMON-003`, `SEC-SE-U3-001/006`) | `WP-I-CLONE-001` | Uni V3 `_secureTokenTransfer` **body** |
| Single SE I/J | `WP-I-DETF-SSE-*`, `WP-J-DETF-SSE-*` | Bal + CP `_pullToken` / I/J |
| Legacy listing DETF | `WP-I-DETF-SSE-UV4-001` | **directory gone** |
| CS/MB I/J/ADV/G | `WP-I-DETF-CS-*`, `WP-I-DETF-MB-001`, `WP-J-DETF-CS-MB-001`, `WP-ADV-DETF-MB-001`, `WP-G-E-DETF-CS-001` | CS/MB **pull bodies** (lock + leftover minter are **this** program) |
| DualLiq receive steal | `WP-I-DETF-DL-001` | `_receive` / `_receiveOut` **steal** (closed). Residual same-tx-vs-docs + A0 + I honesty are **this** program — do not restore no-op |
| DualLiq J | `WP-J-DETF-DL-001` | DualLiq J suite (closed) |
| Uni V4 SE / Stata token I/J/ADV | `WP-I-CLONE-UAB-001`, `WP-I-SE-UAB-001`, `WP-J-SE-UAB-001`, `WP-ADV-SE-UAB-001` | Uni V4 SE **token** `_secureTokenTransfer`; Aave **Stata** In. **Not** Loop In/Out files |
| Loop I TEST names (`SEC-SE-AAVE-003`) | `WP-I-SE-UAB-001` | Stata/U4 I names. **Loop I CODE+tests** are `WP-SEC-I-AAVE-LOOP-001` (this program) |
| Stata Out self-burn (`SEC-SE-AAVE-004`) | blast of `WP-SEC-E6-COMMON-001` | do not open a second tree on `BasicVaultCommon.sol` |
| Claim token I (`SEC-DETF-COM-001`) | `WP-I-CLAIM-001` | shared `detf/common` RebasingClaimToken **pull** |
| Hooks I/J/ADV | `WP-I-HOOK-*`, `WP-J-HOOK-001`, `WP-ADV-HOOK-001` | SE buffer + swap J |
| Manager J / Fee N | `WP-J-MGR-001/002`, `WP-N-FEE-001` | closed at SHA |
| Router I5/J/N (`SEC-SPEC-040`, `SEC-RTR-001`) | `WP-I5-RTR-001`, `WP-J-RTR-001`, `WP-N-RTR-001` | Coordinator |
| Balancer SE router J (`SEC-SE-BAL-002`) | `WP-J-ROUTER-UAB-001` | not SinglePool helper |

**Finding aliases (not a second tree):** `SEC-SPEC-001` and `SEC-MGR-001` → `WP-SEC-CROPS-001` (this program; DETF/SE files, not manager disable API).

---

## 7. Waves + DAG + slice table

### 7.1 Wave law

| Wave | Contents | Parallelism |
|------|----------|-------------|
| **0** | Shared commons E6 CODE (`WP-SEC-E6-COMMON-001` on `BasicVaultCommon.sol`) | **Serial. Exactly 1 live `sec_fix_*`.** Confirm `gap_cover_i-common` idle (it is: 44/44 closed). Do **not** reopen `_secureTokenTransfer`. |
| **1** | Per-package High CODE+TEST (I/E6/A0/J/CROPS fold) | Conflict-free slices; **≤ 3** live; after Wave 0 merge |
| **2** | (none new) Stage 1 Wave 2 leftovers (hook residual Medium, Coordinator N) are **OWNED_ELSEWHERE** or Medium — not this High program |
| **3** | `WP-SEC-TOKEN-001` after owner policy; Medium clusters are **out of High scope** unless later added | After Wave 1; 1 live tree |
| **4** | Sharp ABI `pretransferred` typed enum (Stage 1 sketch; **not** a High `WP-SEC-*`) | Out of this High program |

### 7.2 Packing rules (normative for Stage 3)

1. **Same Common / Facet / error file** → same slice (or strict serial). Never two live agents on `BasicVaultCommon.sol`.
2. **L-SEC-13:** one worktree per **package directory** after Wave 0. Cross-package Stage 1 WPs are **executed as package portions** (same WP-ID, different slice).
3. **`WP-SEC-CROPS-001`** is **folded** into each affected package slice (not a fourth concurrent tree on those Commons). Checklist item in SSE / UV4 extra / DualLiq / Uni V2 slices.
4. **OWNED_ELSEWHERE** → skip (no spawn row).
5. If two WPs share a file, they **must** sit in the same slice (already applied below).

### 7.3 Slice table (Stage 3 spawn source)

| Slice / worktree | WPs included | Production touch-set | Test touch-set | Depends on | Wave |
|------------------|--------------|----------------------|----------------|------------|------|
| `sec_fix_e6-common` (branch `sec_fix/e6-common`) | `WP-SEC-E6-COMMON-001` (SEC-COMMON-002, SEC-SHARP-002/003, SEC-SPEC-020) | `contracts/vaults/basic/BasicVaultCommon.sol` only (`_refundExcess`, `_secureSelfBurn`; optional NatSpec on `ISecurePullErrors.sol`). **Not** `_secureTokenTransfer` | `test/foundry/spec/vaults/basic/**` (`test_E6_*`, keep `test_I1_\|test_I2_\|test_I3_` green) | none (`gap_cover_i-common` idle) | **0** |
| `sec_fix_aero-se` (`sec_fix/aero-se`) | Aero portion of `WP-SEC-E6-SE-001`, `WP-SEC-A0-SE-001`, `WP-SEC-I-SE-4626-001` | `contracts/protocols/dexes/aerodrome/v1/**` Out Execute Target + In Target (zap-in / LP-deposit) + DFPkg `decimalOffset` only | `test/**/aerodrome/v1/**` `test_E6_*`, `test_A0_*`, `test_I1_lpDeposit_*` | Wave 0 merged | **1** |
| `sec_fix_cam-se` (`sec_fix/cam-se`) | `WP-SEC-CAM-OUT-001` + Camelot portion of `WP-SEC-E6-SE-001`, `WP-SEC-R4-SE-001`, `WP-SEC-A0-SE-001`, `WP-SEC-I-SE-4626-001` | `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol`; `…InTarget.sol` (Route4 + zap-in + LP-deposit) | `test/**/camelot/v2/**` `test_CAM_OUT_*`, `test_E6_*`, `test_R4_*`, `test_A0_*`, `test_I1_lpDeposit_*` | Wave 0 merged | **1** |
| `sec_fix_univ2-se` (`sec_fix/univ2-se`) | Uni V2 portion of `WP-SEC-E6-SE-001`, `WP-SEC-R4-SE-001`, `WP-SEC-A0-SE-001`, `WP-SEC-I-SE-4626-001` + Uni V2 portion of `WP-SEC-CROPS-001` | `contracts/protocols/dexes/uniswap/v2/**` In/Out Targets + Common disable on **Out** / `vaultShare` exit (not manager API) | `test/**/uniswap/v2/**` `test_E6_*`, `test_R4_*`, `test_A0_*`, `test_I1_lpDeposit_*`, `test_CROPS_*` | Wave 0 merged | **1** |
| `sec_fix_aave-loop` (`sec_fix/aave-loop`) | `WP-SEC-I-AAVE-LOOP-001` | `contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeInTarget.sol`; `…OutTarget.sol`. **Not** `aave/v3.6/**` | `test/**/aave/cross-version/**` `test_I1_*`, `test_I2_*`, `test_I3_*` | Wave 0 (API freeze only; no file share) | **1** |
| `sec_fix_slip-e6` (`sec_fix/slip-e6`) | `WP-SEC-E6-SLIP-001` | `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeInTarget.sol`; `…/SlipstreamStandardExchangeOutTarget.sol` | `test/**/slipstream/**` `test_E6_*`, `test_I1_*`, `test_J*` | Wave 0 (no file share) | **1** |
| `sec_fix_univ3-e6` (`sec_fix/univ3-e6`) | `WP-SEC-E6-U3-001`, `WP-SEC-I-U3-SHARE-001`, `WP-SEC-A0-U3-001` | `contracts/protocols/dexes/uniswap/v3/**` In / Out / PositionImport. **Do not** restyle `_secureTokenTransfer` (`WP-I-CLONE-001`) | `test/**/uniswap/v3/**` `test_E6_*`, `test_I1_*`, `test_A0_*` | Wave 0 (no file share) | **1** |
| `sec_fix_univ4-se` (`sec_fix/univ4-se`) | `WP-SEC-E6-U4-001`, `WP-SEC-IMP-U4-001`, `WP-SEC-A0-U4-001` | `contracts/protocols/dexes/uniswap/v4/**` SE vault only (Out delegate/execute, InBase, Common, PositionImport, DFPkg bind). **Not** DETF/hooks; **not** token `_secureTokenTransfer` | `test/**/uniswap/v4/**` SE vault paths `test_E6_*`, `test_IMP_*`, `test_A0_*` | Wave 0 (no file share) | **1** |
| `sec_fix_bal-single-i` (`sec_fix/bal-single-i`) | `WP-SEC-I-BAL-SINGLE-001` | `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol` | `test/**/balancer/v3/pools/**` `test_I1_*`, `test_E6_*`, `test_M_*` | Wave 0 (no file share) | **1** |
| `sec_fix_detf-uv4-extra` (`sec_fix/detf-uv4-extra`) | `WP-SEC-DETF-UV4-BURN-I1-001`, `WP-SEC-DETF-UV4-I-SUITE-001`, `WP-SEC-DETF-UV4-J-001`, `WP-SEC-DETF-UV4-A0-001`, `WP-SEC-DETF-UV4-NFT-001`, `WP-SEC-DETF-UV4-ORB-CLAIM-001` + UV4-extra portion of `WP-SEC-CROPS-001` | `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/{weighted,orbital,stable/quad/curve}/**`; `…/uniswap/v4/common/{nft,rebasing}/**`. **Not** CP-single; **not** shared `detf/common` claim; **not** mint `_pullToken` helper body | `test/**/uniswap/v4/standardExchange/{weighted,orbital,stable/quad}/**` `test_I*`, `test_J*`, `test_A0_*`, `test_depositClaim*`, `test_F1_*`, `test_CROPS_*` | Wave 0 (no file share) | **1** |
| `sec_fix_detf-cs` (`sec_fix/detf-cs`) | `WP-SEC-DETF-CS-LOCK-001`, `WP-SEC-DETF-CS-TOKEN-001`, `WP-SEC-DETF-CS-A0-001` | `…/balancer/v3/stable/common/ComposedStableCommonDetfExchangeIn.sol`; `…BondingFacet.sol`; `RebasingDETFToken` DFPkg / token Targets post-deploy unown. **Not** MixedBuffer pull; **not** shared claim token | `test/**/stable/**` + MixedBuffer A0 only: `test_C*`, `test_A0_*`, `test_F_*` | Wave 0 (no file share) | **1** |
| `sec_fix_detf-dl` (`sec_fix/detf-dl`) | `WP-SEC-DETF-DL-A0-001`, `WP-SEC-DETF-DL-DELTA-001`, `WP-SEC-DETF-DL-I-HONESTY-001` + DualLiq portion of `WP-SEC-CROPS-001` | `contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/**` MathLib / Common / In-Out (A0 + disable + **docs/test invert**; do not restore no-op receive) | `test/foundry/fork/**/crossVersion/v2/**` `test_I*`, `test_A0_*`, `test_K1_*`, `test_CROPS_*` | Wave 0; owner-silent default §4 DualLiq (B) | **1** |
| `sec_fix_detf-mv` (`sec_fix/detf-mv`) | `WP-SEC-PKG-MV-001`, `WP-SEC-DETF-MV-A0-001` | `…/multi-vault-weighted/**` `MultiVaultWeightedDetfDFPkg.sol` `processArgs` only. **Not** I/J/K Common/Targets | `test/**/multi-vault-weighted/**` `test_PKG_*`, `test_C1_*`, `test_A0_*` (adversarial) | Wave 0 (no file share) | **1** |
| `sec_fix_detf-sse` (`sec_fix/detf-sse`) | `WP-SEC-DETF-SSE-A0-001` + Single SE / Uni V4 CP portion of `WP-SEC-CROPS-001` | Disable-gated `*Common.sol` / Bonding / Out only (`SingleStandardExchangeDETF*`, `UniswapV4SingleStandardExchangeDETF*`). **Not** `_pullToken` | SSE + CP adversarial `test_A0_*`, `test_CROPS_*` | Wave 0 (no file share) | **1** |
| `sec_fix_detf-com-j` (`sec_fix/detf-com-j`) | `WP-SEC-DETF-COM-J-001` | none unless PAT-J-OMIT. **Not** `WP-I-CLAIM-001` pull | claim + NFT vault `test_J*` after CREATE3/registry deploy | Wave 0 (no file share) | **1** |
| `sec_fix_lst-ij` (`sec_fix/lst-ij`) | `WP-SEC-I-LST-001`, `WP-SEC-J-LST-001` | none unless helper regression / PAT-J-OMIT | `test/foundry/spec/protocol/staking/{lido,etherfi,rocket-pool}/**` `test_I1_*`, `test_I2_*`, `test_I3_*`, `test_J*` | Wave 0 (no file share) | **1** |
| `sec_fix_erc4626-ij` (`sec_fix/erc4626-ij`) | `WP-SEC-I-ERC4626-001` | none | `test/foundry/spec/vaults/standard/erc4626/**` `test_I1_*`, `test_I2_*`, `test_I3_*`, `test_J*` (rename theater I1) | Wave 0 (no file share) | **1** |
| `sec_fix_token-policy` (`sec_fix/token-policy`) | `WP-SEC-TOKEN-001` | optional DFPkg `processArgs` allowlist **only after** owner policy | one `test_L2_*` per family that claims FoT (real FoT token) | Wave 1 complete + **NEEDS_OWNER** policy | **3** |

**Spawn count:** 18 slices (1 Wave 0 + 16 Wave 1 + 1 Wave 3). **No slice** lists an OWNED_ELSEWHERE primary file as its production touch-set.

### 7.4 Recommended live batches (≤ 3)

Wave 0 must finish and merge before any Wave 1 slice that edits an AMM v2 Out Target (Aero / Camelot / Uni V2). Other Wave 1 slices do not share `BasicVaultCommon.sol` but **wait for Wave 0** so helper semantics are frozen (L-SEC Wave 0 serial).

| Batch | Live slices (≤ 3) | Why this set |
|-------|-------------------|--------------|
| **W0** | `sec_fix_e6-common` | Serial commons |
| **W1-A** | `sec_fix_cam-se`, `sec_fix_aave-loop`, `sec_fix_bal-single-i` | Highest new extracts; disjoint packages |
| **W1-B** | `sec_fix_aero-se`, `sec_fix_slip-e6`, `sec_fix_univ3-e6` | Remaining E6/A0 SE |
| **W1-C** | `sec_fix_univ2-se`, `sec_fix_univ4-se`, `sec_fix_detf-cs` | Uni V2 E6/R4/CROPS; Uni V4 SE; CS lock/minter |
| **W1-D** | `sec_fix_detf-uv4-extra`, `sec_fix_detf-dl`, `sec_fix_detf-mv` | DETF families (fork slot for DualLiq) |
| **W1-E** | `sec_fix_detf-sse`, `sec_fix_lst-ij`, `sec_fix_erc4626-ij` | TEST-heavy + SSE CROPS |
| **W1-F** | `sec_fix_detf-com-j` | Last Wave 1 (1 live) |
| **W3** | `sec_fix_token-policy` | After owner policy |

**Depends on / Parallelizable with (DAG):**

```text
WP-SEC-E6-COMMON-001  ──serial──►  Aero/Cam/U2 E6 call-sites (aero-se, cam-se, univ2-se)

All Wave 1 slices ──parallel after W0──  if different package dirs (table above).

Inside a slice: CODE before TEST that would fail pre-fix (burn I1 before UV4 I-suite; DualLiq owner-default before honesty invert).

WP-SEC-TOKEN-001  ──after──  Wave 1 + owner policy.
```

---

## 8. Parallel execution law (Stage 3 orchestrator)

### 8.1 Spawn shape

1. Create **at most three** git worktrees at a time, named `sec_fix_<slice>` from current `main`.
2. Branch: `sec_fix/<slice>` (or `sec_fix_<slice>`). Prefix **`sec_fix_`** required (L-SEC-8).
3. Spawn one implementer per worktree. **Never** a fourth concurrent implementer.
4. Wait for completion → verify §9 forge acceptance → **rebase worktree onto `main`** → **fast-forward `main`** (linear history; same practice as gap-closure) → remove worktree → start next queued slice(s).
5. Never let two live worktrees share a primary production or primary test touch-set file.
6. **Do not** open `gap_cover_*` trees. If a surprise live `gap_cover_*` appears on a listed file, **skip or serialize** that `sec_fix_*` slice — do not compete.

### 8.2 Worktree compile seed (Claude.md — non-negotiable)

Before the **first** `forge` in a **new** worktree, seed from a warm checkout (`REPO`) into the worktree (`WT`):

```bash
rsync -a "${REPO}/cache_forge/" "${WT}/cache_forge/"
rsync -a "${REPO}/out/" "${WT}/out/"
rm -rf "${WT}/lib/crane" && ln -s "${REPO}/lib/crane" "${WT}/lib/crane"
```

After a **green** forge, copy `cache_forge/` + `out/` **back** to the warm seed. **Never** delete `out/` or `cache_forge/` mid-program. **Never `via_ir`.**

**Forge patience:** monorepo compile 20–40+ minutes with little output is **normal**. Wait for process exit. Timeouts: **hours** (2–4h) for first compile, not 10–20 minutes. Never kill `forge` / `solc`.

### 8.3 Subagent prompt skeleton (copy per slice)

```text
You implement Stage 3 security remediation for slice <SLICE> only.

LAW: docs/security/SECURITY_AUDIT_REMEDIATION_PRD.md §§3–4, 8–9
     docs/security/audit/WORK_PACKAGE_BACKLOG.md (your WP-IDs)
     linked SEC-* in docs/security/audit/areas/** and specialists/**
     Claude.md + docs/agent/INDEXEDEX_AGENT_LAW.md (DETF/deploy)
SKILLS: crane-testing, crane-adversarial-testing + implementation-test-dod.md,
        indexedex-testing, indexedex-adversarial-testing

WPs: <list from slice table>
Worktree: sec_fix_<slice>   Branch: sec_fix/<slice>
Production touch-set: <exact paths>
Test touch-set: <exact paths>
Out of scope: every other package; all OWNED_ELSEWHERE primary files

Hard rules:
- No via_ir. DETF role names only. CREATE3 facets; vault/DETF DFPkg via manager registry.
- No mock SUT. Pass = exploit blocked.
- I1: pretransferred=true, NO in-call transfer, inventory already held → revert. Happy pretransfer+real transfer is NOT I1.
- J3: call the proxy after registry/factory deploy, never facet impl.
- Proof-first if the WP flag is yes: red test or throwaway repro BEFORE claiming CODE closed.
- Do not reopen _secureTokenTransfer / MultiVault _pullToken / Uni V3 pull / shared claim pull.
- DualLiquidity: never restore no-op _receive or held−amountIn refund.
- Seed cache_forge/ + out/ before first forge. Never kill forge/solc.

Acceptance: run the exact forge matchers in PRD §9 for this slice. Paste the log in the worklog.
When done: do not merge; leave the branch for the orchestrator to rebase+FF.
```

### 8.4 BUILD_BLOCKED / red forge

| Symptom | Action |
|---------|--------|
| Compile error in **this** slice’s files | Fix in-slice. Do not enable `via_ir`. |
| Compile error **outside** touch-set | Stop. Report. Do not “fix the monorepo.” |
| DualLiquidity / Slipstream fork: missing `ALCHEMY_KEY` | `BUILD_BLOCKED` (L-SEC-6 / L-SEC-5). WP stays open. Hermetic helper-only is **not** DualLiq close. |
| Red test that proves the exploit still works | CODE not closed. Do not invert the assert to greenwash. |
| Red test that is pre-existing outside touch-set | Note; do not expand scope. |
| `gap_cover_*` suddenly live on the same file | Park this slice. Do not dual-edit. |

### 8.5 Merge order

Linear `main`: rebase slice → FF `main` → next batch. Wave 0 **must** land before W1-A Aero/Cam/Uni V2 slices. Inside a multi-WP slice, merge **once** (one worktree, all WPs).

---

## 9. Per-slice / per-WP acceptance

Global anti-theater (every slice):

- I1 ≠ happy `pretransferred=true` with a real transfer.
- J acceptance calls the **proxy**.
- Pass = **exploit blocked**.
- Exact revert selectors — no bare `expectRevert()`.
- Catalog names: `test_I1_`, `test_I2_`, `test_I3_`, `test_J`, `test_A0_`, `test_E6_`, `test_R4_`, `test_IMP_`, `test_CAM_OUT_`, `test_PKG_`, `test_C`, `test_F_`, `test_CROPS_`, `test_L2_`, `test_depositClaim`, `test_K1_` as applicable.

### 9.1 Wave 0

| Slice | Forge | Required names | Proof-first | Anti-theater |
|-------|-------|----------------|-------------|--------------|
| `sec_fix_e6-common` | `forge test --match-path 'test/foundry/spec/vaults/basic/**' --match-test 'test_E6_\|test_I1_\|test_I2_\|test_I3_' -vv` | `test_E6_*` on refund + self-burn; I1–I3 stay green | **yes** — seed booked inventory; fat max + transfer-only-`used` must not skim `R`; self-burn I1 no share transfer | I1 no transfer; do not reopen token I-ABS |

### 9.2 Wave 1 slices

| Slice | Forge | Required names | Proof-first | Anti-theater |
|-------|-------|----------------|-------------|--------------|
| `sec_fix_aero-se` | `--match-path 'test/**/aerodrome/v1/**' --match-test 'test_E6_\|test_A0_\|test_I1_lpDeposit'` | `test_E6_*`, `test_A0_*`, `test_I1_lpDeposit_*` | **yes** | fat max + only `used` transferred; donate LP before first mint; I1 lpDeposit no transfer |
| `sec_fix_cam-se` | `--match-path 'test/**/camelot/**' --match-test 'test_CAM_OUT_\|test_E6_\|test_R4_\|test_A0_\|test_I1_lpDeposit'` | `test_CAM_OUT_*` (recipient received `tokenOut`), `test_E6_*`, `test_R4_*` / `test_K1_*`, `test_A0_*` | **yes** | assert recipient `tokenOut`; preview ≡ execute **pre-deposit**; donate before mint |
| `sec_fix_univ2-se` | `--match-path 'test/**/uniswap/v2/**' --match-test 'test_E6_\|test_R4_\|test_A0_\|test_I1_lpDeposit\|test_CROPS_'` | same + `test_CROPS_*` disable does not block `exchangeOut` | **yes** (E6/R4/A0) | disable via manager **after** `setVaultAddressDisabled(true)`; I1 no transfer |
| `sec_fix_aave-loop` | `--match-path 'test/**/aave/cross-version/**' --match-test 'test_I1_\|test_I2_\|test_I3_'` | `test_I1_*` In and Out | **yes** | I1 no transfer; call **proxy**; seed inventory |
| `sec_fix_slip-e6` | `--match-path 'test/**/slipstream/**' --match-test 'test_E6_\|test_I1_\|test_J'` | `test_E6_*`, `test_I1_*`, `test_J*` | **yes** | seed inventory; J3 proxy; fork if that is the gold path (`FOUNDRY_PROFILE=fork`, `*_alchemy`) |
| `sec_fix_univ3-e6` | `--match-path 'test/**/uniswap/v3/**' --match-test 'test_E6_\|test_I1_\|test_A0_'` | `test_E6_*`, `test_I1_zapOut_*`, `test_A0_*` | **yes** | I1 no share transfer; donate before first mint; **do not** edit pull helper |
| `sec_fix_univ4-se` | `--match-path 'test/**/uniswap/v4/**' --match-test 'test_E6_\|test_IMP_\|test_A0_'` (SE vault paths only) | `test_E6_*`, `test_IMP_*`, `test_A0_*` | **yes** | untrusted import owner **must revert**; seed inventory before first mint |
| `sec_fix_bal-single-i` | `--match-path 'test/**/balancer/v3/pools/**' --match-test 'test_I1_\|test_E6_\|test_M_'` | `test_I1_*`, `test_E6_*`, `test_M_*` | **yes** | I1 no transfer; proxy |
| `sec_fix_detf-uv4-extra` | `--match-path 'test/**/uniswap/v4/standardExchange/{weighted,orbital,stable/quad}/**' --match-test 'test_I\|test_J\|test_A0_\|test_depositClaim\|test_F1_\|test_CROPS_'` | `test_I1_*` **burn** + mint/bond; `test_J*` on **proxy**; `test_A0_*`; `test_depositClaim_*` (orbital or recorded PRD amend); `test_F1_*` local NFT/claim `owner()==0`; `test_CROPS_*` mature exit after disable | **yes** (burn + NFT) | I1 no transfer on burn; J3 not facet impl; donate before first bond |
| `sec_fix_detf-cs` | `--match-path 'test/**/stable/**' --match-test 'test_C\|test_A0_\|test_F_'` and MixedBuffer `test_A0_` | `test_C*` hostile-share reenter; `test_A0_*`; `test_F_*` stranger mint reverts, `owner()==0` | **yes** (lock + minter) | hostile `vaultShare` reenter; leftover admin on **token**, not diamondCut theater |
| `sec_fix_detf-dl` | `FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/**/crossVersion/v2/**' --match-test 'test_I\|test_A0_\|test_K1_\|test_CROPS_' --fork-url base_mainnet_alchemy -vv` | `test_I1_*` no transfer; `test_A0_*`; `test_K1_*`; invert `pushThenTrue_succeeds` if default (B) | **yes** (A0 + delta default) | I1 no transfer; **ShareInflation is not I**; missing Alchemy → `BUILD_BLOCKED` |
| `sec_fix_detf-mv` | `--match-path 'test/**/multi-vault-weighted/**' --match-test 'test_PKG_\|test_C1_\|test_A0_'` | `test_PKG_*` / `test_C1_*` hostile/zero `vaultShare`; `test_A0_*` adversarial | no (PkgArgs); A0 TEST | zero share must revert or explicit unrated policy; donate before first bond; **proxy**; do not touch I/J/K CODE |
| `sec_fix_detf-sse` | `--match-test 'test_A0_\|test_CROPS_'` on SSE + CP paths | `test_A0_*`; `test_CROPS_*` mature exit after disable | no (A0 TEST); CROPS no | donate before live; **proxy**; disable **after** `setVaultAddressDisabled(true)` |
| `sec_fix_detf-com-j` | `--match-test 'test_J'` on claim/bond trees | `test_J1_*` / `test_J2_*` / `test_J3_*` | no | J3 **proxy** after CREATE3/registry; do not edit pull body |
| `sec_fix_lst-ij` | `--match-path 'test/foundry/spec/protocol/staking/**' --match-test 'test_I1_\|test_I2_\|test_I3_\|test_J'` | `test_I1_*`…`I3_*`, `test_J*` | no | I1 no transfer; J3 not facet impl |
| `sec_fix_erc4626-ij` | `--match-path 'test/foundry/spec/vaults/standard/erc4626/**' --match-test 'test_I1_\|test_I2_\|test_I3_\|test_J'` | real `test_I1_*`; `test_J*` | no | I1 no transfer; **preview-equality test must not be named I1** |

### 9.3 Wave 3

| Slice | Forge / artifact | Required names | Proof-first | Anti-theater |
|-------|------------------|----------------|-------------|--------------|
| `sec_fix_token-policy` | written policy **plus** `forge test --match-test 'test_L2_FoT_credits_actualIn\|test_L2_FoT_forbidden'` on families that claim FoT | `test_L2_*` | no | real FoT as **configured** token, not mock SUT; official LST/Stata faces out of scope |

---

## 10. Program definition of done

Stage 3 of **this** program is done when:

- [ ] All **36** High `WP-SEC-*` in §5.2 are merged **or** `BUILD_BLOCKED` (fork RPC only) **or** owner-gated `WP-SEC-TOKEN-001` with a recorded policy + tests
- [ ] Every touched path’s §9 forge matcher is green on `main` (evidence in PR/worklog)
- [ ] No unbounded extract / free mint is greenwashed
- [ ] I1 suites do not use happy pretransfer+real transfer as the I1 case
- [ ] J suites call the **proxy**
- [ ] Deferred catalog IDs (Medium/Low, N/A) appear in suite NatSpec — not silently dropped Highs
- [ ] No `via_ir`; DETF role names only; registry/CREATE3 deploy bar held
- [ ] OWNED_ELSEWHERE primary files were not “fixed again”
- [ ] Worktrees/branches used `sec_fix_` only; live concurrency never exceeded 3

**This PRD is done when the self-check in §12 is checked — not when remediations are green.**

---

## 11. Non-goals

- Re-auditing the monorepo or rewriting `docs/security/audit/**`.
- Competing I/J/K / hook / router / manager WPs already in gap-closure (appendix).
- Frontend, indexer, non-Foundry e2e.
- Formal verification, Echidna/Medusa, **`via_ir`**.
- Changing DETF economics / fee schedules / threshold exclusivity without `NEEDS_OWNER`.
- Inventing Critical findings (Stage 1: **Critical = 0**).
- Opening `sec_fix_*` or `gap_cover_*` worktrees in the Stage 2 authorship run.
- Production `*.sol` or permanent `test/**` in the Stage 2 authorship run.
- Deep rewrites of vendored `lib/**`.
- Wave 4 sharp ABI enum (not a High `WP-SEC-*`).

---

## 12. Prompt self-check

- [x] Every Stage 1 Critical/High `SEC-*` is either a `WP-SEC-*` in this PRD, OWNED_ELSEWHERE, or an explicit alias into one of those (no High dropped; **no DEFER**; Critical WPs = none)
- [x] No `sec_fix_*` slice overlaps a primary file of an **open** `gap_cover_*` WP (gap-closure 44/44 closed; Wave 0 still must not reopen I-ABS)
- [x] Wave 0 is serial; later slices are conflict-free (one package per tree; shared files co-sited)
- [x] Each slice has acceptance forge commands and anti-theater checks
- [x] DETF role names only; no `via_ir`; registry/CREATE3 deploy bar
- [x] No production or test code was edited in this Stage 2 run (this file only, plus optional execute plan)
- [x] A Stage 3 orchestrator can spawn slices from the §7.3 table without re-reading the whole monorepo

---

## 13. Counts for the owner

| Metric | Value |
|--------|------:|
| Critical `WP-SEC-*` | **0** (Stage 1; not invented) |
| High `WP-SEC-*` this program | **36** (0 DEFER) |
| High `SEC-*` this program (incl. aliases into those WPs) | **48** rows in §5.1 with a this-program WP |
| High `SEC-*` OWNED_ELSEWHERE / coverage-only | **19** coverage-owned Highs in §6 (plus **2** aliases into `WP-SEC-CROPS-001`) |
| `sec_fix_*` slices | **18** (1 Wave 0 + 16 Wave 1 + 1 Wave 3) |
| Max live trees | **3** |
| Wave 0 | `sec_fix_e6-common` only |
| First Wave 1 parallel set | `sec_fix_cam-se` · `sec_fix_aave-loop` · `sec_fix_bal-single-i` |

**Stop.** Do not start Stage 3 in the run that authored this PRD.
