# Test Coverage Audit — T-detf-single-vault-seigniorage

| Field | Value |
|-------|--------|
| Date | 2026-08-09 |
| Agent / run | Stage 1 area subagent · **full** · `T-detf-single-vault-seigniorage` |
| Status | **COMPLETE** |
| Production paths | **Named products absent.** Historical: ~~`contracts/vaults/detf/composed/single/`~~ (SingleVaultDetf), ~~`contracts/vaults/seigniorage/`~~ (SeigniorageDETF). Residual nearest surfaces: `contracts/vaults/detf/common/bondNft/**`, `contracts/vaults/detf/common/claimToken/**` (shared DETF helpers — not the removed dual-token product) |
| Test paths | **No** `SingleVaultDetf*` / `SeigniorageDETF*` suites under `test/**`. Residual: `test/foundry/spec/vaults/detf/common/{bondNft,claimToken}/**`; SAF partials under `test/foundry/spec/saf/**` |
| Skills / PRD version cited | `TEST_COVERAGE_AUDIT_PRD.md` §2, §2.4, §3.8, §7.2, §8, §19; `TEST_COVERAGE_AUDIT_EXECUTE_PLAN.md` F1; crane A–K ship-gate; prior seed `ADVERSARIAL_VAULT_COVERAGE_GAP_REPORT.md` §§4,7,9 + `FUZZ_INVARIANT_*` SingleVault/Seigniorage waves |
| Finding ID prefix | `TCA-DETF-SVS-NNN` |
| Runtime proofs | **N/A** for removed products (no SUT). Residual claim PAT-I residual already owned/scored by `T-basic-protocol-commons` (no duplicate Blocker runtime here) |

---

## 1. Executive summary

### Maturity (0–5)

| Product / surface | Maturity | Worst open severity | One-line |
|-------------------|----------|---------------------|----------|
| **SingleVaultDetf** (`composed/single`) | **N/A** | **None (product gone)** | **REMOVED** — supersession path is Single SE DETF (`standardExchange/single`); not a ship product |
| **SeigniorageDETF** (legacy dual-token) | **N/A** | **None (product gone)** | **REMOVED** (2026-07-31 class docs) — dual-token RBT/sRBT + underwrite NFT package deleted; **not** fee-oracle seigniorage incentive |
| **DETFNFTVault** (common bond NFT DFPkg) | **1–2** | **Medium THEATER** | Live shared residual; deploy path tests exist; pure-math unit suite is **labeled stub** — not production adversarial |
| **RebasingClaimToken** (common claim DFPkg) | **1–2** | **High CODE residual** (foreign-token pretransfer; cross-cite commons) | Live shared residual; self-path L-CLAIM-3 delta; foreign-token absolute credit residual; pure redemption suite is **stub** |

### Severity counts (this area)

| Severity | Count | IDs |
|----------|------:|-----|
| **Blocker** | **0** | — No free-mint / free-principal surface on a removed product; no Blocker CODE invented for non-SUT |
| **High** | **1** | `TCA-DETF-SVS-003` (claim foreign-token pretransfer residual — **cross-cite** `T-basic-protocol-commons`; not a new product bug class) |
| Medium | 2 | `TCA-DETF-SVS-002`, `TCA-DETF-SVS-004` |
| Low / Info | 3 | `TCA-DETF-SVS-001`, `TCA-DETF-SVS-005`, `TCA-DETF-SVS-006` |

### Top recommended WPs

**No product CODE/TEST WPs** for SingleVaultDetf / SeigniorageDETF (packages deleted — do not restore for coverage theater).

1. **Do not reintroduce** SingleVaultDetf or SeigniorageDETF packages for audit closure — successor money paths live under **`T-detf-single-se`** (and other live DETF areas).
2. **`WP-I-CLAIM-001`** (owned by `T-basic-protocol-commons`) — residual foreign-token delta on `RebasingClaimTokenTarget._secureTokenTransfer` — **reference only** here.
3. **`WP-TEST-DETF-SVS-001`** (optional Medium) — replace or demote pure stubs under `test/.../detf/common/{bondNft,claimToken}/` so aggregate does not count them as H/D coverage; prefer DETF-integrated D2/D6/H2 (already on MultiVault / peers).
4. **Docs hygiene** (Low) — archive/stale plans still list Wave 3 SingleVault/Seigniorage adversarial tasks as open; mark superseded.

### Ship-blocking statement

| Question | Answer |
|----------|--------|
| Is **SingleVaultDetf** ship-blocking? | **No** — package **not in tree**; no DFPkg/diamond to deploy or free-mint. |
| Is **SeigniorageDETF** (legacy dual-token) ship-blocking? | **No** — package **not in tree**; deploy scripts comment Stage 15 removed. |
| Residual bond NFT / claim helpers ship-blocking? | **Helpers remain money-adjacent** for **live** DETF families (bond sell → claim, redeem). **No Blocker unique to this area.** High residual = claim foreign-token PAT (commons-owned CODE). Pure unit stubs are **not** proof of D-class safety — real proof must stay on product DETF adversarial suites (`T-detf-multi-vault`, `T-detf-single-se`, `T-detf-composed-stable`, etc.). |
| Fee-oracle “seigniorage incentive %” | **Not this product.** Retained global mint-fee knob under manager/fee oracle (`T-manager-fee-registry`). Do not conflate with SeigniorageDETF. |

**Headline:** Prior 2026-07 adversarial/fuzz reports treated SingleVaultDetf + SeigniorageDETF as live P0 surfaces. **2026-08-09 inventory: both production trees and matching test trees are gone.** Area status **COMPLETE** with **N/A** product matrices. Residual bond NFT + claim commons are inventoried so orchestrator does not drop ship-relevant helper gaps; they are **not** rebranded as the deleted products.

---

## 2. Product inventory

### 2.1 Named products (historical — **absent**)

| Product | DFPkg / key Targets | TestBase | Test roots | Deploy path quality | Status 2026-08-09 |
|---------|---------------------|----------|------------|---------------------|-------------------|
| **SingleVaultDetf** | ~~`SingleVaultDetfDFPkg`~~ · ~~`composed/single/*`~~ | ~~`SingleVaultDetf_*` TestBase~~ | ~~`test/.../detf/composed/single/**`~~ · ~~adversarial/fuzz~~ | N/A | **REMOVED** — inventory cites `docs/DETF_POOL_INTEGRATION_INVENTORY.md` F5; research universe locked out 2026-07-29; gold successor = `SingleStandardExchangeDETF` |
| **SeigniorageDETF** | ~~`SeigniorageDETFDFPkg`~~ · ~~`SeigniorageNFTVault*`~~ · ~~`Seigniorage_Component_FactoryService`~~ | ~~`TestBase_SeigniorageDETF_Fork`~~ | ~~`test/.../seigniorage/**`~~ · ~~`spec/protocol/vaults/seigniorage/**`~~ | N/A | **REMOVED** — inventory F6; dual-token RBT/sRBT product; Stage 15 scripts removed |

**rg evidence (zero production/test hits):**

- `rg 'SingleVaultDetf|SeigniorageDETF|SeigniorageNFTVault' contracts --glob '*.sol'` → **no matches**
- `rg 'SingleVaultDetf|SeigniorageDETF|TestBase_Seigniorage' test --glob '*.sol'` → **no matches**
- `contracts/vaults/**` listing: **no** `composed/single/`, **no** `seigniorage/` package root

### 2.2 Residual nearest surfaces (still present — **not** inventing products)

Scope partition: *“SingleVault + Seigniorage DETF (if present) **or nearest bond/NFT seigniorage surfaces**”*.

| Surface | Path | Role | Money path? | Owned primarily by |
|---------|------|------|-------------|--------------------|
| **DETFNFTVault** DFPkg / Facet / Target / Service | `contracts/vaults/detf/common/bondNft/**` | Bond NFT vault; lock/harvest/redeem math; used by live DETF bonding | Yes (via DETF bond/sell/claim flows) | Product DETF areas + shared deploy tests here |
| **RebasingClaimToken** DFPkg / Facet / Target | `contracts/vaults/detf/common/claimToken/**` | `rebasingClaimToken` after sell-to-claim; redeem / burnShares / `pretransferred` | Yes | Product DETF + **commons** for pull helper |
| DETF core libs (mint split, compound, thresholds) | `contracts/vaults/detf/common/core/**` | Shared law libs | Indirect | Live DETF areas (not unique to removed products) |
| VaultFeeOracle seigniorage incentive % | `contracts/interfaces/IVaultFeeOracleManager.sol` + fee oracle impl | Mint incentive fee for **true DETFs** | Fee path | **`T-manager-fee-registry`** |

### 2.3 Residual file inventory (bond NFT + claim)

| Path | Role |
|------|------|
| `DETFNFTVaultDFPkg.sol` / `DETFNFTVaultFacet.sol` / `DETFNFTVaultTarget.sol` / `DETFNFTVaultCommon.sol` / `DETFNFTVaultRepo.sol` / `DETFNFTVaultService.sol` | Bond NFT package |
| `RebasingClaimTokenDFPkg.sol` / `RebasingClaimTokenFacet.sol` / `RebasingClaimTokenTarget.sol` / `RebasingClaimTokenRepo.sol` | Claim token package |
| `test/.../bondNft/DETFNFTVaultDFPkg_Deploy.t.sol` | Production-ish registry deploy of NFT DFPkg |
| `test/.../bondNft/DETFNFTVault.t.sol` | **Stub** pure arithmetic (`@custom:adversarial-status stub-not-production-path`) |
| `test/.../claimToken/RebasingClaimTokenDFPkg_Deploy.t.sol` | DFPkg + `deployToken` smoke |
| `test/.../claimToken/RebasingClaimTokenRedemption.t.sol` | **Stub** pure arithmetic (legacy RICHIR comments) |
| `test/foundry/spec/saf/T01_FacetSelectors.t.sol` etc. | Partial proxy/selector smoke on bond/claim diamonds |

### 2.4 Trust-flag entrypoints (residual claim only)

| Entrypoint | Flag | Credit path |
|------------|------|-------------|
| `RebasingClaimTokenTarget.redeem` / multi-token redeem | `pretransferred` | `_secureTokenTransfer` |
| `burnShares` | `pretransferred` | branch skips transfer when true |
| DETFNFTVault | no general `pretransferred` mint flag of SingleVault/Seigniorage style | Bond authority via DETF diamond + inventory policies |

**PAT-I note (claim):** Self-token path uses `lastSelfBalance` delta (L-CLAIM-3). **Foreign token** path: `balanceNow >= amount` then **`return amount_`** without measuring a **delta** vs a stored last foreign balance — residual free-credit class when inventory already holds the foreign token (see §5 `TCA-DETF-SVS-003`).

### 2.5 Facet surface (J static skim — residual only)

- `DETFNFTVaultFacet.facetFuncs()` present.
- `RebasingClaimTokenFacet.facetFuncs()` present.
- Formal J1–J3 Target-diff + loupe + proxy smoke: **partial** via SAF T01 / deploy tests; **not** a full catalog J suite for these helpers as standalone products. Live DETF package J remains product-area owned.

---

## 3. Layer matrix

Legend: **F** full · **P** partial · **G** gap · **N/A** · **S** stub/theater

| Product | H | N | D | J | I | K | A–H | P | L1 | L2 | L3 | Maturity | Notes |
|---------|---|---|---|---|---|---|-----|---|----|----|----|----------|-------|
| SingleVaultDetf | **N/A** | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | **N/A** | Package removed |
| SeigniorageDETF | **N/A** | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | **N/A** | Package removed |
| DETFNFTVault (common) | **P** | **P** | **P** | **P** | **N/A**\* | **G**/N | **S**/G† | N/A | **G** | **G** | **G** | **1–2** | Deploy + SAF; unit suite **S**; D-class real proof on integrated DETFs |
| RebasingClaimToken (common) | **P** | **P** | **P** | **P** | **G**/P‡ | **G** | **S**/G† | **P** | **G** | **G** | **G** | **1–2** | Deploy + SAF; pure redemption **S**; I foreign residual |

\* NFT vault not the classic DETF exchangeIn pretransfer surface.  
† Prior report already labeled protocol NFT/claim unit suites as stub risk.  
‡ Self-path delta partial; foreign absolute credit gap.

### Layer evidence (summary)

| Layer | Evidence |
|-------|----------|
| **H (named products)** | **None** — no deployable SUT |
| **H (residual)** | DFPkg deploy tests; SAF facet selector / retire / brand-strip helpers; integrated DETF bonding/claim (owned elsewhere) |
| **N** | Partial deploy auth / init; integrated DETF claim negatives (owned elsewhere) |
| **D** | Facet files exist; pure unit “tests” do **not** declare production control lists |
| **J** | facetFuncs present; no dedicated J1–J3 adversarial for helpers |
| **I** | Claim pretransfer exists; **no** `test_I1_` / `test_I2_` / `test_I3_` on claim proxy under residual tree |
| **K** | No dedicated donation→pretransfer suite on claim package |
| **A–H** | No `adversarial/` for removed products; residual unit files self-label stub |
| **P / L1–L3** | N/A for removed products; residual helpers have no property suites here |

---

## 4. Catalog matrix (A–K)

### 4.1 Named products — entire catalog **N/A**

| ID | SingleVaultDetf | SeigniorageDETF | Evidence |
|----|-----------------|-----------------|----------|
| A–K (all) | **N/A** | **N/A** | No production SUT; no test tree |

### 4.2 Residual bond NFT + claim helpers

| ID | DETFNFTVault | RebasingClaimToken | Evidence or G |
|----|--------------|--------------------|---------------|
| A1–A3 | **G**/N | **G** | No package-local donation adversarial |
| B | N/A | N/A | Pricing owned by parent DETF |
| C1–C3 | **G** | **G** | No reentrancy suite on helper packages |
| D2–D6 | **S**→**G** locally; **F/P** on MultiVault | **S**→**G** locally; **P/F** on integrated DETF | Stubs explicitly defer to MultiVault/Single SE/ComposedStable |
| E1/E5 | **G** | **G**/P | No local residual/zero/deadline catalog |
| F | **P** | **P** | Deploy/registry paths only |
| H2–H3 | **G** | **G** | Atomic fail owned by parent DETF bonding |
| **I1–I3** | N/A | **G** | No false-claim pretransfer suite on claim proxy |
| **J1–J3** | **P** | **P** | SAF T01 partial; not formal Target⊆facetFuncs⊆loupe⊆proxy |
| **K1** | N/A | **G** | Donation + pretransfer untested at claim package |

---

## 5. Findings

### 5.1 [TCA-DETF-SVS-001] Info · DEFER · product removal

- **Summary:** SingleVaultDetf and SeigniorageDETF production packages and matching Foundry suites are **not present**. Prior 2026-07 gap work (adversarial Wave 3A, fuzz 3C/3D) is **superseded by deletion**, not “still open P0 on those packages.”
- **Evidence:**
  - `docs/DETF_POOL_INTEGRATION_INVENTORY.md` F5/F6 REMOVED
  - Zero `.sol` hits for `SingleVaultDetf` / `SeigniorageDETF` under `contracts/` and `test/`
  - `contracts/vaults/detf/` tree has no `composed/single/`; no `contracts/vaults/seigniorage/`
  - Active deploy scripts: `// Stage 15 (SeigniorageDETF dual-token product) removed.`
- **Why bar fails:** N/A — product bar does not apply.
- **Recommended CODE:** None. **Do not restore packages** for coverage optics.
- **Recommended TEST:** None for deleted products. Route successor coverage to **`T-detf-single-se`** (and other live DETF areas).
- **Suggested WP id:** — (no WP)
- **Priority:** Info

### 5.2 [TCA-DETF-SVS-002] Medium · THEATER · residual bond NFT unit suite

- **Summary:** `DETFNFTVault.t.sol` is **pure arithmetic placeholders** and self-documents that it is **not** production-path coverage. Must not be scored as D/H adversarial for bond NFT authority.
- **Evidence:**
  - `test/foundry/spec/vaults/detf/common/bondNft/DETFNFTVault.t.sol` header: `STUB / SPEC-ONLY`, `@custom:adversarial-status stub-not-production-path`
  - Methods are `public pure` / trivial `assertEq` without registry DFPkg deploy of a vault diamond
  - Contrast: `DETFNFTVaultDFPkg_Deploy.t.sol` does exercise CREATE3 facet + `indexedexManager.deployDETFNFTVaultDFPkg`
- **Why bar fails:** Catalog D2/D6/H2 claim “coverage” via pure math is **theater**.
- **Recommended CODE:** None required for theater alone.
- **Recommended TEST:** Either (a) deprecate/skip-label stubs so CI dashboards ignore them, or (b) replace with production proxy suite: deploy NFT vault via registry, bond via live DETF TestBase, prove onlyOwner / double-redeem / protocol NFT privileges with exact selectors. Prefer relying on MultiVault `Adversarial_BondClaim` if (b) is duplicate.
- **Suggested WP id:** `WP-TEST-DETF-SVS-001`
- **Priority:** Medium (hygiene; not free mint)

### 5.3 [TCA-DETF-SVS-003] High · CODE · residual claim foreign-token pretransfer (PAT-I class)

- **Summary:** `RebasingClaimTokenTarget._secureTokenTransfer` for **foreign** tokens under `pretransferred=true` requires absolute `balanceOf >= amount` and **returns claimed amount** without a measured inbound **delta** vs a last foreign balance. Self-claim path is delta-aware (L-CLAIM-3). Same class already escalated under `T-basic-protocol-commons` — **do not double-count as separate Blocker epicenter**.
- **Evidence:**
  - `contracts/vaults/detf/common/claimToken/RebasingClaimTokenTarget.sol` ≈ L538–550 foreign branch: `balanceNow_ < amount_` revert else `actualIn_ = amount_; return`
  - Self branch L553–559 uses `lastSelfBalance` delta
  - Repo NatSpec L-CLAIM-3 documents delta requirement; foreign path incomplete
  - Cross-cite: pilot `T-basic-protocol-commons` finding on RebasingClaimToken residual; WP-I-CLAIM-001
- **Why bar fails:** I1–I3 / PAT-I-ABS: pre-existing foreign inventory can satisfy absolute balance check → free credit on redeem routes that accept non-self tokens.
- **Recommended CODE:** Measure foreign delta (balNow − balBefore snapshot / lastForeignBalance) before crediting; reject false claims.
- **Recommended TEST:** `test_I1_claim_foreign_pretransferred_falseClaim_reverts` on production claim diamond (registry deploy); pass when false claim with pre-seeded inventory reverts and no shares burned/minted incorrectly.
- **Suggested WP id:** `WP-I-CLAIM-001` (**owner: commons**; this finding is pointer only)
- **Priority:** High · **RUNTIME_UNPROVEN** in this area (static clear; runtime owned by commons O3 / product claim suites)

### 5.4 [TCA-DETF-SVS-004] Medium · THEATER · residual claim pure redemption suite

- **Summary:** `RebasingClaimTokenRedemption.t.sol` is pure math stub (legacy brand comments); does not deploy claim via DFPkg or exercise redeem/pretransfer.
- **Evidence:** File header stub labels; `public pure` rate/balance arithmetic only; deploy coverage lives in `RebasingClaimTokenDFPkg_Deploy.t.sol` + SAF.
- **Why bar fails:** Counts as theater if treated as claim security suite.
- **Recommended TEST:** Same options as 5.2; integrate with I1–I3 after CODE fix.
- **Suggested WP id:** `WP-TEST-DETF-SVS-001` (same hygiene package)
- **Priority:** Medium

### 5.5 [TCA-DETF-SVS-005] Low · DEFER · stale task/docs inventory

- **Summary:** Tasks and historical plans still list SeigniorageDETF Deploy.t.sol / SingleVault adversarial as open work (`tasks/INDEX.md` IDXEX-107, `DEPLOYMENT_TRIAGE_REPORT`, archive deploy inventories, older PLAN_fix_dfpkg paths).
- **Evidence:** Doc/task greps (not production SUT).
- **Recommended:** Mark tasks **cancelled / superseded** by package removal; do not spawn Stage 3 WPs from those IDs for deleted products.
- **Suggested WP id:** docs-only (optional)
- **Priority:** Low

### 5.6 [TCA-DETF-SVS-006] Info · N/A · fee-oracle seigniorage ≠ SeigniorageDETF

- **Summary:** `seigniorageIncentivePercentage*` on fee oracle and mint-split “seigniorage” economics remain in tree for **true DETF** families. They are **not** the removed dual-token SeigniorageDETF product and must not reopen this area’s product matrix.
- **Evidence:** `IVaultFeeOracleManager` events/setters; MultiVault/Single SE ThresholdMode T13 fee split tests.
- **Ownership:** `T-manager-fee-registry` + live DETF product areas.
- **Priority:** Info

---

## 6. Theater list

| Test / control | Why theater | Fix |
|----------------|-------------|-----|
| `test/foundry/spec/vaults/detf/common/bondNft/DETFNFTVault.t.sol` | Pure math; no DFPkg proxy; self-labeled stub | Deprecate or replace with production proxy / rely on DETF adversarial |
| `test/foundry/spec/vaults/detf/common/claimToken/RebasingClaimTokenRedemption.t.sol` | Pure math; no redeem/pretransfer SUT | Same |
| Any historical claim that SingleVault/Seigniorage “P0 adversarial complete” (2026-07 plans) | Packages deleted; green suites no longer exist as coverage | Supersede in aggregate; successor = live DETF areas |

---

## 7. Prior-report diff

| Claim (doc) | Status now (2026-08-09) |
|-------------|-------------------------|
| Adversarial gap report §4 SingleVaultDetf `composed/single/` medium–high gaps | **STALE product** — path **removed**; gaps **moot** (no SUT). Naming-debt cleanup N/A |
| Adversarial gap report §7 Seigniorage DETF + NFT vault P0 backlog | **STALE product** — package **removed** |
| Adversarial matrix columns SingleVaultDetf / Seigniorage | **N/A columns** — do not score F/P/G on deleted products |
| Adversarial §9 Protocol DETFNFTVault + RebasingClaimToken stubs | **STILL TRUE** — stubs remain under `test/.../detf/common/**` (path reorg from `protocol/`) |
| Adversarial plan Wave 3A SingleVaultDetf P0 green checkbox | **Historical** at best; suite not in tree — treat as **superseded**, not live gold |
| Fuzz gap/impl SingleVault L1 + Seigniorage amount fuzz | **Superseded** by package removal; comments in fuzz plan already note Seigniorage tests removed |
| DEPLOYMENT inventory Stage 15 Seigniorage / SingleVault protocolDetf | **Stale docs** vs scripts that mark Stage 15 removed |
| “Use Single SE instead of SingleVault” (pool inventory / research) | **CONFIRMED** — successor ownership is **`T-detf-single-se`** |

---

## 8. Work package stubs

### WP-TEST-DETF-SVS-001 — Residual bond NFT / claim unit theater hygiene

| Field | Value |
|-------|--------|
| WP-ID | `WP-TEST-DETF-SVS-001` |
| Class | TEST / THEATER |
| Severity | Medium |
| Depends on | None |
| Paths | `test/foundry/spec/vaults/detf/common/bondNft/**`, `.../claimToken/**` |
| Scope | Label/skip pure stubs **or** replace with production DFPkg proxy authority tests **without** reintroducing SingleVault/Seigniorage products |
| Acceptance | Stubs not counted as D/H coverage in aggregate; optional proxy tests green under hermetic `forge test --match-path 'test/foundry/spec/vaults/detf/common/**'` |
| Suggested worktree | `gap_cover_detf_svs_helper_tests` (only if residual hygiene is prioritized) |

### WP-I-CLAIM-001 — (pointer; owner commons)

| Field | Value |
|-------|--------|
| WP-ID | `WP-I-CLAIM-001` |
| Class | CODE + TEST |
| Severity | High |
| Owner area | **`T-basic-protocol-commons`** (not re-owned here) |
| Finding | `TCA-DETF-SVS-003` / commons claim residual |
| Note | Stage 2 planner should **dedupe** to single claim WP |

**No WP** for SingleVaultDetf or SeigniorageDETF product reimplementation, adversarial port, or fuzz port.

---

## 9. Deferred / N/A / NEEDS_OWNER

| Item | Disposition |
|------|-------------|
| SingleVaultDetf full H/N/D/J/I/K/A–H/P/L1–L3 | **N/A** — product removed |
| SeigniorageDETF full catalog | **N/A** — product removed |
| Restore Stage 15 deploy scripts | **DEFER / refuse** unless product owner reopens dual-token product PRD |
| Fee-oracle seigniorage incentive suite | **Out of area** → `T-manager-fee-registry` |
| Integrated DETF bond/claim A–K depth | **Out of area** → multi-vault / single-se / composed-stable / dual-liquidity reports |
| Residual helper L1–L3 property suites | **DEFER** — low ROI if DETF-integrated L3 covers sell/claim flows |
| NEEDS_OWNER | None for deleted product economics |

---

## 10. Commands run / evidence paths searched

```text
# Production / test product names
rg -n --glob '*.sol' 'SingleVaultDetf|SeigniorageDETF|SeigniorageNFTVault|TestBase_Seigniorage' contracts test
# → 0 matches in contracts/ and test/ for those identifiers

# Broader seigniorage / single-vault strings (docs + residual fee/oracle)
rg -n -i 'SingleVault|SeigniorageDETF|composed/single|vaults/seigniorage' --glob '*.{sol,md}' .

# Tree
list contracts/vaults/          # no seigniorage/, no detf/composed/
list contracts/vaults/detf/     # common/ + protocols/ only
list test/foundry/spec/vaults/detf/common/  # bondNft, claimToken, core only

# Residual pretransfer
rg -n 'pretransferred|facetFuncs|_secureTokenTransfer' contracts/vaults/detf/common --glob '*.sol'

# Deploy script removal notes
rg -n 'Stage 15|SeigniorageDETF dual-token' scripts --glob '*.sol'

# Prior reports
read docs/DETF_POOL_INTEGRATION_INVENTORY.md (F5/F6)
read docs/testing/ADVERSARIAL_VAULT_COVERAGE_GAP_REPORT.md (§4,7,9)
read docs/testing/FUZZ_INVARIANT_COVERAGE_IMPLEMENTATION_PLAN.md (3C/3D removed notes)
read docs/testing/coverage-audit/00_SCOPE_PARTITION.md (this area row)
```

**Not run:** `forge test` on SingleVault/Seigniorage match-paths (no files). No Blocker runtime proof required (no Blocker CODE on a live SUT in this area).

---

## Return block (orchestrator)

| Field | Value |
|-------|--------|
| **Status** | **COMPLETE** |
| **Area** | `T-detf-single-vault-seigniorage` |
| **OUT_FILE** | `docs/testing/coverage-audit/areas/T-detf-single-vault-seigniorage.md` |
| **Blocker** | **0** |
| **High** | **1** (`TCA-DETF-SVS-003` claim foreign pretransfer — **cross-cite commons**; RUNTIME_UNPROVEN here) |
| **Products** | SingleVaultDetf **REMOVED** · SeigniorageDETF **REMOVED** · residual DETFNFTVault + RebasingClaimToken inventoried |
| **Ship-blocking** | **None for named products.** Residual helpers matter only via live DETF + commons WPs. |
| **WPs** | Optional `WP-TEST-DETF-SVS-001`; pointer `WP-I-CLAIM-001` |
