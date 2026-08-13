# Security Audit specialist — S-incidents

| Field | Value |
|-------|--------|
| Date / SHA / status | 2026-08-13 · `1e0d7c48` · **COMPLETE** |
| Inputs | All written area reports + pilot; `defi-incident-patterns` theme table |
| Skill | defi-incident-patterns (**map only**; no HackLabs remappings / compile) |

## 1. Cross-cut thesis (≤10 lines)

Every major HackLabs theme maps onto an **already-opened** `SEC-*` or coverage `TCA-*` / `WP-I-*`. No theme lacked a finding. Incident corpus is **reference only**. Pass remains “exploit blocked,” not attacker-profit.

## 2. Findings

No new hunt findings. Map table is the deliverable.

| Theme | Catalog | SEC / TCA already |
|-------|---------|-------------------|
| Empty vault / first deposit | A0 | `SEC-SE-AC-002`, `SEC-DETF-MV-007`, `SEC-DETF-SSE-010`, LST A0 tests |
| Donation / inflation | A, K | MultiVault OWNED_ELSEWHERE K; Loop I `SEC-SE-AAVE-001` |
| Spot / oracle | B, L3 | Policy deadband ACCEPTED_RISK; Loop oracles |
| Pair skim / FoT | L1, L2 | `SEC-SPEC-010` NEEDS_OWNER; E6 skims |
| Surplus refund `balance−floor` | E6, L1, F5 | `SEC-COMMON-002`, `SEC-SHARP-002`, `SEC-SE-AC-001`, `SEC-SE-SLIP-001/002`, `SEC-SE-BAL-001` |
| Reentrancy | C | MultiVault gold; hook reentrancy tests |
| Arbitrary call + allowance | M1–M3 | Coordinator allowlist; SinglePool max approve |
| Quote–settle TOCTOU | N1–N2 | hooks N; DualLiquidity area |
| Broken permit | O, I5 | Coordinator I5 OWNED_ELSEWHERE |
| Trust-flag free mint | I1–I3 | Commons closed; Loop/SinglePool/Uni V3 live or coverage |
| Missing diamond selectors | J | per-area J WPs |
| Admin pause | CROPS | `SEC-CROPS-001` |

### 2.1 [SEC-SPEC-050] Map complete — no orphan theme

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SPEC-050` |
| **Title** | Incident map has no unmapped theme |
| **Severity** | **Info** |
| **Class** | **ACCEPTED_RISK** / clean |
| **Confidence** | static-high |
| **Catalog IDs** | none |
| **Pattern IDs** | none |
| **EVM-audit domain** | general |
| **Products** | protocol-wide |
| **Blast radius** | n/a |
| **Evidence** | table above |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | all |
| **Depends / parallel** | n/a |

## 3. Products implicated (blast)

All money products (map only).

## 4. Recommended epic WPs (Wave 0 style)

None new. Implement existing E6 / I / CROPS WPs.

## 5. Explicit non-findings (checked, clean)

- Did **not** compile `lib/DeFiHackLabs`.
- Did **not** add remappings.

## 6. Commands / checklists walked

```text
read .grok/skills/defi-incident-patterns/SKILL.md theme table
cross-walk area SEC-* IDs
# no HackLabs execution
```
