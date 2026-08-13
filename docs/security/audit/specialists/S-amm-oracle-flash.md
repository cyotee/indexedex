# Security Audit specialist — S-amm-oracle-flash

| Field | Value |
|-------|--------|
| Date / SHA / status | 2026-08-13 · `1e0d7c48` · **COMPLETE** |
| Inputs | `A-se-amm-v2`, `A-slipstream-buffer`, `A-se-aave`, `A-hooks-v4-*`, `A-detf-single-se`, DualLiquidity still in-flight (fork-first L-SEC-5) |
| Skill | ethskills-audit defi-amm / oracles / flashloans; catalog B / L / N |

## 1. Cross-cut thesis (≤10 lines)

Spot-priced mint/burn (Aerodrome/Camelot/Uni V2/V3/V4 SE, Slipstream CL, hook AMMs) is **B/L3** by design; DETF Policy mode deadbands are the bound. **New extract class is E6 skim of AMM inventory** (Slipstream entire-balance refund; AMM v2 Out `max−used`; Uni V3 entire-balance — area-owned). Loop uses Aave oracles + permissionless rebalance (flash-capable CAP). DualLiquidity is fork-first — missing fork P0 stays High per L-SEC-5 (area). No new oracle-manipulation Critical beyond those E6/I Highs.

## 2. Findings

### 2.1 [SEC-SPEC-020] E6/L1 surplus refund is the live AMM extract class

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SPEC-020` |
| **Title** | Treat E6 refunds as L1 skim (epic) |
| **Severity** | **High** |
| **Class** | **CODE** (already filed per-area) |
| **Confidence** | static-high |
| **Catalog IDs** | E6, L1 |
| **Pattern IDs** | PAT-E6-REFUND, PAT-L-SKIM |
| **EVM-audit domain** | defi-amm |
| **CROPS pillar** | n/a |
| **Incident theme** | skim / surplus refund |
| **Products** | Slipstream; Aero/Camelot/Uni V2 Out; Uni V3 In; SinglePool Balancer helper |
| **Blast radius** | all `balance − floor` / `max−used` refunds |
| **Attacker** | EXT |
| **Attack scenario** | See area findings SEC-SE-SLIP-001/002, SEC-SE-AC-001, SEC-SE-BAL-001, Uni V3 refund. |
| **Preconditions** | Booked inventory + fat max or leftover-balance refund |
| **Impact** | Drain pair / CL tokens |
| **Evidence** | area reports |
| **Recommended CODE** | this-call unused only |
| **Recommended TEST** | `test_E6_*` seed inventory |
| **Anti-theater** | seed before call |
| **Suggested WP-ID** | existing `WP-SEC-E6-*` |
| **Link TCA / prior** | none competing |
| **Depends / parallel** | Wave 0 commons then per-package |

### 2.2 Medium [SEC-SPEC-021]

Flash-loan CAP on Loop rebalance / SE spot: document as B ACCEPTED_RISK under Policy deadband; Open mode seigniorage already ACCEPTED_RISK in law.

## 3. Products implicated (blast)

All AMM SE, Slipstream, hooks, DualLiquidity, Aave Loop.

## 4. Recommended epic WPs (Wave 0 style)

Stay on `WP-SEC-E6-COMMON-001`, `WP-SEC-E6-SE-001`, `WP-SEC-E6-SLIP-001`, `WP-SEC-I-BAL-SINGLE-001`. No third E6 helper.

## 5. Explicit non-findings (checked, clean)

- Coordinator hop output measured by **balance delta** (not quoted amount).
- Hook CP/Dual pulls reserve-delta (stale TCA-HOOK-001).
- DETF synthetic uses reserve principal, not lone spot (law).

## 6. Commands / checklists walked

```text
defi-amm / oracles / flashloans headings: spot, skim, FoT, TWAP, flash donate
read Slipstream refunds; Camelot Out (pilot); Loop rebalance
# DualLiquidity fork P0 deferred to area report
```
