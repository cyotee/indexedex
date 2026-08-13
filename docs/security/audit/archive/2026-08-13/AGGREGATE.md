# Security Audit — AGGREGATE (thin pilot)

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` (`1e0d7c48eff8a883837996ae700426ac5397924b`) |
| Mode | **pilot** (L-SEC-1) — not MODE=full; remaining areas / specialists / adversarial-modeler **not** in this file |
| PRD | `docs/security/SECURITY_AUDIT_PRD.md` locks **L-SEC-1…14** |
| Areas | `A-commons-pull` COMPLETE · `A-detf-multi-vault` COMPLETE · `A-se-amm-v2` COMPLETE |
| Specialists | `S-sharp-edges` COMPLETE · `S-crops-trust` COMPLETE |
| Backlog | [`WORK_PACKAGE_BACKLOG.md`](./WORK_PACKAGE_BACKLOG.md) |
| Runtime | [`repro/SEC-COMMON-001/`](./repro/SEC-COMMON-001/) — I1/I2/I3 **9/9 PASS** at this SHA |

---

## 1. Executive summary

Historical PAT-I-ABS on `BasicVaultCommon._secureTokenTransfer` (absolute `balanceOf >= claimed` → credit claimed) is **not a live Critical** at `1e0d7c48`. The helper is reserve-delta (`U = B − R`); hermetic I1 tests revert `TransferDeltaInsufficient` with no inbound transfer. MultiVault `_pullToken` matches. Aerodrome no longer overrides the helper. Coverage-audit `WP-I-COMMON-001` / `WP-I-DETF-MV-001` stay **OWNED_ELSEWHERE** — do not open `sec_fix_*` on those closed pull bodies.

**New High CODE this program owns** (not in gap-closure I/J/K):

| Cluster | Why it matters |
|---------|----------------|
| **E6 refund / self-burn** | `_refundExcess` pays `max−used`; `_secureSelfBurn` sweeps leftover `vaultShare`. `pretransferred=true` + fat max can skim booked pair tokens or donated shares. |
| **Camelot Out swap** | `tokenOut` stays on the vault; `amountIn` overwritten with `amountOut` before refund. Honest users lose output. |
| **SE Route4 convert** | Camelot + Uni V2 convert shares against **post-deposit** LP reserve (under-mint). |
| **SE A0 / LP-deposit** | Zap-in / `lastTotalAssets` exact-gap credit; Aerodrome `decimalOffset=0`. |
| **PkgArgs hostile share** | MultiVault `vaultShares[i]==0` aliases to `vaults[i]`; no registry lock. |
| **CROPS disable-on-exit** | Not MultiVault (clean). Disable-gated DETF families + Uni V2 Out can be frozen by manager owner — High but mostly **MODE=full** families. |

**Critical: 0.** Worst open severity: **High** (static; E6/Camelot Out **RUNTIME_UNPROVEN**).

---

## 2. Residual-risk heatmap (pilot products)

| Product | Residual risk (0–5) | Worst open | OWNED_ELSEWHERE? |
|---------|--------------------:|------------|------------------|
| BasicVaultCommon token pull | **4** | E6 leftovers on same file | I1 body yes (`WP-I-COMMON-001`) |
| BasicVaultCommon `_secureSelfBurn` | **2** | High CODE E6 | no |
| MultiVaultWeightedDetf | **3** | High TEST A0; Medium CODE preview/idle | I/J/K yes |
| Aerodrome V1 SE | **3** | E6 + A0 offset 0 | I/J/E5 yes |
| Camelot V2 SE | **2** | Out-swap drop + E6 + Route4 | I/J/H tests yes |
| Uniswap V2 SE | **2** | E6 + Route4; I/J tests still coverage-owned | I/J/ADV open in gap-closure |

---

## 3. Severity counts (pilot, deduped)

| Severity | Actionable (this program) | OWNED_ELSEWHERE / Info |
|----------|---------------------------|------------------------|
| Critical | **0** | 0 |
| High CODE | E6 commons, E6 SE call-sites, Camelot Out, Route4×2, A0/LP-deposit, PkgArgs, CROPS disable (cross-cut) | Historical I-ABS, Uni V3 clones (other area) |
| High TEST | MultiVault missing `test_A0_*`; Uni V2 I/J still gap-closure | — |
| Medium / Low | minOut=0, Permit2 uint160, recipient 0, lock clamp, fee 100% WAD | — |

---

## 4. Catalog snapshot (pilot)

| ID | Commons | MultiVault | Aero | Camelot | Uni V2 |
|----|---------|------------|------|---------|--------|
| A0 | ACCEPTED bootstrap / G on products | **G** (no `test_A0_*`) | **VULN** offset 0 + zap-in | **VULN** zap-in | **VULN** zap-in |
| I1–I3 | **F** hermetic 9/9 | **F** (owned tests) | **F** landed | **F** landed | **G** tests (`WP-I-SE-AC-001`) |
| J | n/a helper | **P** (owned; residual smoke) | **F** | **F** | **G** (`WP-J-SE-AC-001`) |
| K | ACCEPTED U-claim | **F** owned | P | P | P |
| E6 | **VULN** self-burn + `_refundExcess` | N/A / P | **VULN** Out | **VULN** Out | **VULN** Out |
| F / CROPS | n/a | **F** unowned/no cut | no disable | no disable | disable bricks Out |
| L/B | n/a | ACCEPTED open seigniorage | ACCEPTED spot + minOut | Route4 convert **VULN** | Route4 convert **VULN** |

---

## 5. CROPS (pilot)

MultiVault DETF diamond: **unowned, no `diamondCut`, no `isDisabled`**. Walkaway holds (bond / sell→claim / redeem / `exchangeOut` / `compoundProtocolRewards` permissionless). Manager remains an owned admin diamond (fees, disable, cut) — accepted for **manager**, not for DETF instances. Disable-gated families (Single SE, Uni V4 DETFs, DualLiquidity) re-import a pause onto claim/exit — High, mostly out of pilot product ownership.

---

## 6. Conflicts & decisions

| Conflict | Decision |
|----------|----------|
| `WP-SEC-E6-COMMON-001` vs closed `WP-I-COMMON-001` same file | **New defect** (E6, not I-ABS). One `sec_fix_*` tree on `BasicVaultCommon.sol`. Do not parallel `gap_cover_i-common`. |
| Sharp-edges E6 + commons self-burn | **One WP** `WP-SEC-E6-COMMON-001` covers `_refundExcess` **and** `_secureSelfBurn`. |
| SE Out call-sites vs commons helper | `WP-SEC-E6-SE-001` is call-site (pass credited-max). Serialize with commons if helper signature changes; else parallel after helper freeze. |
| Camelot Out Target: CAM-OUT vs E6 | **Serial**: `WP-SEC-CAM-OUT-001` first, then E6 on that file. |
| Camelot/Uni V2 In: R4 vs A0 | **Serial** on those In Targets (same files). |
| SEC-CROPS-001 families | Record in backlog; **do not** require MODE=full product-area reports this run. Stage 2 may DEFER to full-pass areas. |
| Uni V3 PAT-I-ABS | Blast only; **OWNED_ELSEWHERE** / `A-se-v3-v4-lending`. |

---

## 7. Diff vs coverage-audit

| Coverage claim | Status now |
|----------------|------------|
| PAT-I-ABS BasicVaultCommon | **Closed** CODE + I1 tests. Historical `repro/TCA-COMMON-001/` stale. |
| MultiVault `_pullToken` absolute return | **Closed** CODE + I tests. |
| Aero override still returns claimed | **Closed** — no override. |
| Aero deadline | **Closed**. |
| Camelot H / Route4 K1 tests | Tests exist; **new** convert-math CODE remains. |
| Uni V2 I/J/ADV | **Still gap** (TEST) — stay on `WP-I/J/ADV-SE-AC-*`. |
| E6 / Camelot Out drop / PkgArgs / disable-on-exit | **New** this program. |

---

## 8. Wave sketch (input to Stage 2 — not a plan)

| Wave | Contents |
|------|----------|
| **0 serial** | `WP-SEC-E6-COMMON-001` on `BasicVaultCommon.sol` (proof-first) |
| **1 parallel** | `WP-SEC-CAM-OUT-001`; `WP-SEC-PKG-MV-001`; `WP-SEC-DETF-MV-A0-001` (TEST) |
| **1 after 0 / CAM-OUT** | `WP-SEC-E6-SE-001` (split per package if L-SEC-13) |
| **1 serial on In Targets** | `WP-SEC-R4-SE-001` then `WP-SEC-A0-SE-001` / `WP-SEC-I-SE-4626-001` |
| **Later / full** | `WP-SEC-CROPS-001` (disable-gated families); `WP-SEC-SHARP-ABI-001`; MultiVault Medium N2/idle/sync |

---

## 9. Stage 2 readiness (pilot)

- [x] Pilot area + specialist reports exist and match §7.2 / §7.4 headings
- [x] Backlog has ≥5 real WPs with §8 fields
- [x] OWNED_ELSEWHERE table present
- [x] Parallelism graph present
- [x] Runtime attempt on PAT-I-ABS at current SHA
- [ ] MODE=full §12 (remaining areas, remaining specialists, adversarial-modeler) — **not this goal**

Next: accept this pilot, then a **new** `/goal` for MODE=full, or proceed to Stage 2 only for **pilot High WPs** if the owner chooses a thin remediation. Default law is pilot-then-full.
