# Security Audit — AGGREGATE (MODE=full)

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` (`1e0d7c48eff8a883837996ae700426ac5397924b`) |
| Mode | **full** (L-SEC-1 pilot exit in `PILOT_EXIT.md`; thin pilot archived) |
| PRD | `docs/security/SECURITY_AUDIT_PRD.md` locks **L-SEC-1…14** |
| Execute plan | Tasks O5–O7 |
| Partition | [`00_SCOPE_PARTITION.md`](./00_SCOPE_PARTITION.md) |
| Backlog | [`WORK_PACKAGE_BACKLOG.md`](./WORK_PACKAGE_BACKLOG.md) |
| Archive | [`archive/2026-08-13/`](./archive/2026-08-13/) (thin pilot AGGREGATE + backlog) |
| Runtime | [`repro/SEC-COMMON-001/`](./repro/SEC-COMMON-001/) I1/I2/I3 **9/9 PASS** at this SHA (HEAD unchanged) |
| via_ir | never recommended |

---

## 1. Program metadata

### 1.1 Area status

| Area | Status | Worst open | Path |
|------|--------|------------|------|
| `A-commons-pull` | COMPLETE (pilot reuse) | High E6 self-burn | `areas/A-commons-pull.md` |
| `A-detf-multi-vault` | COMPLETE (pilot reuse) | High TEST A0 | `areas/A-detf-multi-vault.md` |
| `A-se-amm-v2` | COMPLETE (pilot reuse) | High Camelot Out / E6 / Route4 | `areas/A-se-amm-v2.md` |
| `A-detf-single-se` | COMPLETE | High TEST A0 | `areas/A-detf-single-se.md` |
| `A-detf-composed-stable` | COMPLETE | High CODE lock + leftover minter | `areas/A-detf-composed-stable.md` |
| `A-detf-dual-liquidity` | COMPLETE | High CODE A0 + same-tx/docs; fork P0 High (L-SEC-5) | `areas/A-detf-dual-liquidity.md` |
| `A-detf-univ4-extra` | COMPLETE | High CODE burn I1 + NFT/claim | `areas/A-detf-univ4-extra.md` |
| `A-detf-commons` | COMPLETE | High TEST J | `areas/A-detf-commons.md` |
| `A-se-univ3` | COMPLETE | High E6 + share I1 + A0; pull OWNED_ELSEWHERE | `areas/A-se-univ3.md` |
| `A-se-univ4` | COMPLETE | High E6 zap-out + import + A0 | `areas/A-se-univ4.md` |
| `A-se-aave` | COMPLETE | High Loop skip-pull | `areas/A-se-aave.md` |
| `A-se-morpho-erc4626` | COMPLETE | High TEST I/J theater | `areas/A-se-morpho-erc4626.md` |
| `A-se-lst` | COMPLETE | High TEST I/J | `areas/A-se-lst.md` |
| `A-se-balancer-v3` | COMPLETE | High SinglePool receive | `areas/A-se-balancer-v3.md` |
| `A-hooks-v4-se-buffer` | COMPLETE | High OWNED_ELSEWHERE (I closed) | `areas/A-hooks-v4-se-buffer.md` |
| `A-hooks-v4-swap-factory` | COMPLETE | High J OWNED_ELSEWHERE | `areas/A-hooks-v4-swap-factory.md` |
| `A-manager-fee-registry` | COMPLETE | High disable → CROPS WP | `areas/A-manager-fee-registry.md` |
| `A-routers-permit2` | COMPLETE | High I5/J OWNED_ELSEWHERE | `areas/A-routers-permit2.md` |
| `A-slipstream-buffer` | COMPLETE | High E6 refunds | `areas/A-slipstream-buffer.md` |
| `A-research-contracts` | N/A (no `.sol`) | — | partition F2b |

**FAILED:** none. **PARTIAL with unnamed money products:** none.

### 1.2 Specialist status

| Spec | Status |
|------|--------|
| `S-sharp-edges` | COMPLETE + full-pass addendum |
| `S-crops-trust` | COMPLETE + full-pass addendum |
| `S-spec-detf` | COMPLETE |
| `S-token-weird` | COMPLETE |
| `S-amm-oracle-flash` | COMPLETE |
| `S-diamond-proxy` | COMPLETE |
| `S-signatures` | COMPLETE |
| `S-incidents` | COMPLETE |
| `S-evm-general` | COMPLETE |
| F4 modelers | `S-adv-modeler-pilot-high-code.md`, `SEC-SE-AAVE-001`, `SEC-SE-SLIP-001`, `SEC-SE-BAL-001`, `full-pass-high-code.md` |

Locks cited: **L-SEC-1…14**. Catalog SoT: A–K + A0/L/M/N/O + E6/F5.

---

## 2. Executive summary + residual-risk heatmap

**Critical: 0.** Worst open: **High** (static; new extracts RUNTIME_UNPROVEN per L-SEC-3).

Commons token PAT-I-ABS is **not live** (reserve-delta + 9/9 I1–I3). Coverage-audit 2026-08-09 Blockers on MultiVault / Single SE / CS / DualLiq / Uni V4 SE / Stata / hook CP pulls are **mostly closed in production**; those touch-sets stay **OWNED_ELSEWHERE**.

**This program owns new High CODE** in three epics:

1. **E6 refund / self-burn** — `max−used` and entire-`balanceOf` refunds (commons, AMM v2 Out, Slipstream, Uni V3, Uni V4 SE zap-out, SinglePool).
2. **Remaining PAT-I-ABS clones** — Aave CrossVersion Loop skip-pull; Uni V3 pull (**coverage** `WP-I-CLONE-001`); Uni V4 extra **burn** skip-pull; SinglePool `_receiveExactIn`.
3. **Trust / surface** — disable-gated DETF pause (`SEC-CROPS-001`); CS leftover token minter; Uni V4 `importPosition`; CS missing `nonReentrant`; DualLiquidity A0 + same-tx/docs.

### Residual-risk heatmap (0–5)

| Product | Score | Worst open | OWNED_ELSEWHERE? |
|---------|------:|------------|------------------|
| BasicVaultCommon token pull | **4** | — | I1 yes |
| BasicVaultCommon self-burn | **2** | High E6 | no |
| MultiVaultWeightedDetf | **3** | TEST A0 | I/J/K yes |
| Single SE DETF (Bal + Uni V4 CP) | **3** | TEST A0 | I/J yes |
| ComposedStable + MixedBuffer | **3** | High CODE lock/minter | I pull yes |
| DualLiquidity | **2** | High A0 + fork I honesty | receive yes |
| Uni V4 weighted/orbital/quad DETF | **2** | High burn I1 | mint pull yes |
| DETF claim/bond commons | **3** | TEST J | I-CLAIM yes |
| Aerodrome V1 SE | **3** | E6 | I/J/E5 yes |
| Camelot V2 SE | **2** | Out drop + Route4 | I tests yes |
| Uni V2 SE | **2** | E6 + Route4 | I/J/ADV yes |
| Uni V3 SE | **1** | live I-ABS + E6 | pull yes (`WP-I-CLONE-001`) |
| Uni V4 SE vault | **2** | E6 / import / A0 | token I yes |
| Aave Stata SE | **3** | E6 self-burn | In I yes |
| Aave CrossVersion Loop | **1** | skip-pull CODE | I TEST yes |
| ERC4626 / Morpho SE | **3** | TEST I theater | no |
| Lido / EtherFi / Rocket SE | **3** | TEST I/J | no |
| Slipstream SE | **2** | E6 | pull peer only |
| Balancer buffer pools | **4** | — | ADV yes |
| Balancer SinglePool SE helper | **1** | PAT-I-ABS | no |
| SE buffer hooks | **4** | — | I/J yes |
| Swap hooks + factory | **3** | J | `WP-J-HOOK-001` |
| Manager / fee / registry | **3** | disable (CROPS) | J/N fee yes |
| Coordinator + Permit2 | **3** | leftover N | I5/J yes |

---

## 3. Global catalog matrix

Legend: F found/covered · P partial · G gap · N/A · VULN (this program CODE) · OE closed/owned coverage.

| Product | A/A0 | B | C | D | E6 | F/F5 | I | J | K | L | M | N | O |
|---------|------|---|---|---|----|------|---|---|---|---|---|---|---|
| Commons pull | P | N/A | N/A | N/A | **VULN** | N/A | OE | N/A | P | N/A | N/A | N/A | P |
| MultiVault | P | P | F | F | P | F | OE | OE | OE | P | N/A | P | N/A |
| Single SE DETF (Bal + CP) | G A0 | P | P | F | P | F | OE | OE | P | P | N/A | P | N/A |
| CS / MixedBuffer | G A0 | P | **VULN** lock | P | P | P | OE | OE | P | P | N/A | P | N/A |
| DualLiquidity | **VULN** | P | G | N/A | P | P | P | P | G | P | N/A | P | P |
| Uni V4 extra DETF | G | P | G | P | P | P | **VULN** burn | G | P | P | N/A | P | N/A |
| DETF claim/bond commons | P | N/A | P | P | P | P | OE | G | P | N/A | N/A | P | N/A |
| Aerodrome V1 SE | P | P | P | N/A | **VULN** | P | OE | P | P | P | N/A | P | N/A |
| Camelot V2 SE | P | P | P | N/A | **VULN** | P | OE | P | P | **VULN** R4 | N/A | P | N/A |
| Uni V2 SE | P | P | P | N/A | **VULN** | P | OE | G | P | **VULN** R4 | N/A | P | N/A |
| Uni V3 SE | **VULN** | P | G | N/A | **VULN** | P | OE pull | G | G | **VULN** | N/A | G | N/A |
| Uni V4 SE vault | **VULN** | P | P | N/A | **VULN** | P | OE | OE | P | P | **VULN** import | P | N/A |
| Aave Stata SE | P | P | G | N/A | OE | P | F | F | P | P | N/A | P | N/A |
| Aave CrossVersion Loop | **VULN** | P | G | N/A | G | P F5 | **VULN** | G | **VULN** | P | N/A | G | P |
| ERC4626 / Morpho SE | G | P | P | N/A | P | N/A | G | G | P | N/A | N/A | theater | P |
| Lido / EtherFi / Rocket SE | P | P | G | N/A | P | P | P | G | P | N/A | N/A | P | N/A |
| Slipstream SE | G | P | G | N/A | **VULN** | N/A | P | G | P | **VULN** | N/A | G | N/A |
| Balancer buffer pools | P | F | P | N/A | P | P | N/A | P | P | F | N/A | P | N/A |
| Balancer SinglePool helper | G | P | G | N/A | **VULN** | P | **VULN** | G | G | P | **VULN** | G | P |
| Balancer SE router | N/A | P | P | N/A | P | P | N/A | OE | N/A | P | P | P | P |
| SE buffer hooks | P | P | P | N/A | P | F | OE | OE | P | P | P | P | P |
| Swap hooks + factory | N/A | P | P | N/A | P | F | N/A | OE | N/A | P | N/A | P | N/A |
| Coordinator + Permit2 | N/A | N/A | P | N/A | P | P | F I5 | F | N/A | P | P | P | F |
| Manager / fee / registry | N/A | N/A | N/A | P | N/A | P | N/A | OE | N/A | N/A | N/A | OE | N/A |

---

## 4. Global domain matrix

| Product class | general | precision | erc20 | erc4626 | defi-amm | proxies | access | oracles | flash | dos | signatures | staking/lending |
|---------------|---------|-----------|-------|---------|----------|---------|--------|---------|-------|-----|------------|-----------------|
| DETF families | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | — | — |
| SE AMM / CL | Y | Y | Y | Y | Y | Y | Y | — | Y | Y | — | — |
| LST / Aave / ERC4626 | Y | Y | Y | Y | — | Y | Y | Y | Y | Y | — | Y |
| Hooks | Y | Y | Y | — | Y | Y | Y | — | — | Y | — | — |
| Router | Y | Y | Y | — | Y | Y | Y | — | — | Y | Y | — |
| Manager/fee/reg | Y | — | Y | — | — | Y | Y | — | — | Y | — | — |

Always-on domains walked on every money product: general, precision-math, erc20, proxies, access-control, dos.

---

## 5. CROPS record

| Pillar | Record |
|--------|--------|
| **C** | MultiVault / Single SE: no instance pause. Disable-gated Uni V4 extra + DualLiquidity + some SE: manager owner `setVaultAddressDisabled` freezes exit (**SEC-CROPS-001** High). |
| **O** | Source in-tree; no extra identity. |
| **P** | BUSL/BSL-1.1 — Info (`SEC-CROPS-005`). |
| **S** | DETF instances unowned/uncuttable (MultiVault, Single SE confirmed). Manager keeps `diamondCut` (intended). CS leftover **token** minter is High CODE. Walkaway works on MultiVault; fails if disable-gated family is disabled. Frontend/RPC = Info. |

---

## 6. Pattern incidence

| PAT | Epicenter | Incidence |
|-----|-----------|-----------|
| PAT-I-ABS | Loop In; Uni V3 pull; SinglePool receive; UV4 extra burn | live CODE (others OE/closed) |
| PAT-E6-REFUND | commons self-burn; SE Out max−used; Slip/U3 entire balance | **highest new epic** |
| PAT-A0-EMPTY | SE zap-in; DualLiq; UV4; Uni V3/V4 SE | High CODE/TEST |
| PAT-CROPS-ADMIN | disable-gated DETF | High |
| PAT-J-OMIT / THEATER-FACET | LST, ERC4626, Loop, Slip, swap hooks | TEST / OE |
| PAT-THEATER-PRE | ERC4626 misnamed I1; DualLiq ShareInflation as I | TEST |
| PAT-M-CALL / SHARP | SinglePool max approve; `importPosition`; public `pretransferred` | High/Medium |
| PAT-O-SIG | Coordinator | F / OE |
| PAT-SPEC-DRIFT | disable vs no-pause law; orbital `depositClaim` | High |
| PAT-L-SKIM | E6 twins | High |
| PAT-SLOT | family repo strings distinct | clean (spot) |

---

## 7. Deduped Critical/High

**Critical:** none.

### High CODE this program owns (deduped)

| Cluster | Findings | WP |
|---------|----------|----|
| Commons E6 | SEC-COMMON-002, SEC-SHARP-002/003 | `WP-SEC-E6-COMMON-001` |
| SE Out E6 | SEC-SE-AC-001 | `WP-SEC-E6-SE-001` |
| Camelot Out drop | SEC-SE-CAM-001 | `WP-SEC-CAM-OUT-001` |
| Route4 convert | SEC-SE-CAM-002, SEC-SE-U2-001 | `WP-SEC-R4-SE-001` |
| SE A0 / LP-deposit | SEC-SE-AC-002, SEC-SHARP-004 | `WP-SEC-A0-SE-001`, `WP-SEC-I-SE-4626-001` |
| PkgArgs hostile share | SEC-SHARP-006 | `WP-SEC-PKG-MV-001` |
| Disable-on-exit | SEC-CROPS-001, SEC-SPEC-001, SEC-MGR-001 | `WP-SEC-CROPS-001` |
| CS reentrancy | SEC-DETF-CS-013 | `WP-SEC-DETF-CS-LOCK-001` |
| CS leftover minter | SEC-DETF-CS-014 | `WP-SEC-DETF-CS-TOKEN-001` |
| DualLiq delta/A0 | SEC-DETF-DL-003/004 | `WP-SEC-DETF-DL-DELTA-001`, `WP-SEC-DETF-DL-A0-001` |
| UV4 extra burn I1 | SEC-DETF-UV4-002 | `WP-SEC-DETF-UV4-BURN-I1-001` |
| UV4 local NFT/claim | SEC-DETF-UV4-006/007 | `WP-SEC-DETF-UV4-NFT-001` |
| Orbital depositClaim | SEC-DETF-UV4-008 | `WP-SEC-DETF-UV4-ORB-CLAIM-001` |
| Aave Loop I | SEC-SE-AAVE-001/002 | `WP-SEC-I-AAVE-LOOP-001` |
| Slipstream E6 | SEC-SE-SLIP-001/002 | `WP-SEC-E6-SLIP-001` |
| Uni V3 E6 / share / A0 | SEC-SE-U3-002/003/004 | `WP-SEC-E6-U3-001`, `WP-SEC-I-U3-SHARE-001`, `WP-SEC-A0-U3-001` |
| Uni V4 SE E6 / import / A0 | SEC-SE-U4-002/003/004 | `WP-SEC-E6-U4-001`, `WP-SEC-IMP-U4-001`, `WP-SEC-A0-U4-001` |
| SinglePool receive | SEC-SE-BAL-001 | `WP-SEC-I-BAL-SINGLE-001` |

### High TEST this program owns

SEC-DETF-MV-007, SEC-DETF-SSE-010, SEC-DETF-CS-015, SEC-DETF-DL-005, SEC-DETF-UV4-003, SEC-DETF-UV4-004, SEC-DETF-UV4-005, SEC-DETF-COM-004, SEC-SE-LST-001, SEC-SE-LST-002, SEC-SE-4626-001, SEC-SE-4626-002, SEC-SE-SLIP-003, SEC-SPEC-030.

Modeler notes: `specialists/S-adv-modeler-*.md` (pilot High CODE, Loop, Slip, SinglePool, full-pass remainder).

---

## 8. Conflicts & decisions

| Conflict | Decision |
|----------|----------|
| Coverage 2026-08-09 “PAT-I-ABS live on commons / MV / SSE / CS / Dual / U4 SE / Stata / hook CP” vs current source | **Re-verify wins.** Those pulls are reserve-delta or same-tx-delta + I tests. Class **OWNED_ELSEWHERE** / Info historical. Do not `sec_fix_*` those files. |
| `WP-I-CLONE-001` vs Uni V3 still absolute pull | **Coverage keeps CODE.** STAGE3 “closed” is stale. No competing `sec_fix_*`. This program owns **E6/share/A0** only. |
| Execute-plan one `A-se-v3-v4-lending` vs split | **Split wins** (partition). |
| DualLiq same-tx vs two-tx docs | High CODE/NEEDS_OWNER (`WP-SEC-DETF-DL-DELTA-001`). Fork P0 stays **High** (L-SEC-5). |
| CS leftover token owner vs “unowned DETF” | Satellite token minter is High CODE (not diamondCut). |
| `via_ir` for stack | **Forbidden** (L-SEC-14). |
| Critical vs unproven Loop/E6 | **High + RUNTIME_UNPROVEN** (L-SEC-3). |

---

## 9. Diff vs coverage-audit (`docs/testing/coverage-audit/AGGREGATE.md`)

| Bucket | Items |
|--------|-------|
| **Still vuln** | Uni V3 absolute pull (`WP-I-CLONE-001`); disable-on-exit (new security framing of manager disable); E6 refunds **not** in coverage I/J/K |
| **Test-only** | LST/ERC4626/Loop/Slip J+I named suites; DualLiq I honesty; UV4 extra I/J/A0; CS/SSE A0 names |
| **Closed** (vs 2026-08-09 Blocker CODE) | Commons helper; MultiVault `_pullToken`; Single SE / CS / MB / Dual receive; Uni V4 SE / Stata / hook CP pulls; Coordinator I5/J suites present |
| **New** (this program) | All E6 WPs; Loop skip-pull; SinglePool receive; UV4 burn skip; Camelot Out drop; Route4 convert; importPosition; CS lock + leftover minter; Dual A0 |
| **Stale** | Coverage “Stata skips pull”; “hook CP free extract”; “Uni V4 SE absolute clone”; DualLiq no-op steal; legacy Uni V4 listing DETF (directory gone); SingleVault/Seigniorage DETF removed |

---

## 10. Remediation wave sketch (input to Stage 2)

| Wave | Contents | Parallelism |
|------|----------|-------------|
| **0** | `WP-SEC-E6-COMMON-001` (serial; shared `BasicVaultCommon`) | serial |
| **1** | Per-package High CODE: Loop I, Slip E6, U3 E6/share/A0, U4 SE E6/import/A0, SinglePool I, UV4 burn, CS lock+minter, Dual A0/delta, Camelot Out, Route4, PkgArgs, CROPS disable | parallel on **disjoint** files; ≤3 `sec_fix_*` (L-SEC-12) |
| **2** | L/M/N leftover, hook residual Medium, Coordinator N hygiene (OE) | after Wave 1 |
| **3** | Spec/CROPS docs, token weird policy, Medium cluster | |
| **4** | Sharp ABI `pretransferred` typed enum | |

**Skip `sec_fix_*`:** every OWNED_ELSEWHERE row (`WP-I-*`, `WP-J-*`, `WP-N-FEE-001`, hook I WPs).

---

## 11. Link to backlog

[`WORK_PACKAGE_BACKLOG.md`](./WORK_PACKAGE_BACKLOG.md) — finding→WP index, full §8 for owned Critical/High, OWNED_ELSEWHERE table, parallelism graph.

---

## 12. Stage 2 readiness (PRD §12)

- [x] `00_SCOPE_PARTITION.md` exists and was used for spawning / assignment.
- [x] Every planned product area COMPLETE (research N/A empty).
- [x] Every planned F3 specialist COMPLETE (none skipped).
- [x] Area reports have §7.2 sections 1–11.
- [x] Critical/High findings have §7.3 fields in area/specialist files (attack + attacker on High).
- [x] This AGGREGATE includes §7.5 items 1–12.
- [x] Backlog has §8 + index + OWNED_ELSEWHERE + parallelism.
- [x] PAT-I-ABS on commons: explicit finding + runtime (`repro/SEC-COMMON-001/`, not live Critical).
- [x] Monorepo statements on **A0**, **E6/F5**, **J**, **CROPS leftover admin**.
- [x] L-SEC-2: every money product named in an area inventory.
- [x] Adversarial-modeler notes for leftover High CODE (no Critical).
- [x] No Stage 2/3 implementation; writes only `docs/security/audit/**`.

**Stop.** Stage 2 planner: [`docs/security/PROMPT_SECURITY_AUDIT_REMEDIATION_PRD.md`](../PROMPT_SECURITY_AUDIT_REMEDIATION_PRD.md). Do **not** write `SECURITY_AUDIT_REMEDIATION_PRD.md` in this run.
