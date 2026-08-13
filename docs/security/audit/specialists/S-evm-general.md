# Security Audit specialist — S-evm-general

| Field | Value |
|-------|--------|
| Date / SHA / status | 2026-08-13 · `1e0d7c48` · **COMPLETE** |
| Inputs | Area reports (pilot + orchestrator F2 + A-detf-single-se); precision / dos / general lists |
| Skill | ethskills-audit general + precision-math + dos |

## 1. Cross-cut thesis (≤10 lines)

General/precision/dos did **not** surface a new unbounded extract beyond area I/E6 Highs. Rounding on ERC4626 convert / DETF synthetic is Policy-bounded. DoS: Loop `rebalance` interval 1h; Coordinator hop revert is fail-closed (good). Unbounded loops: hook n-asset weighted (n small). `via_ir` never recommended. **No new Critical/High CODE.**

## 2. Findings

### 2.1 [SEC-SPEC-060] Precision / dust residuals are Medium

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SPEC-060` |
| **Title** | Cluster rounding/dust as Medium |
| **Severity** | **Medium** |
| **Class** | **TEST** |
| **Confidence** | static-medium |
| **Catalog IDs** | E, H |
| **Pattern IDs** | none |
| **EVM-audit domain** | precision-math |
| **CROPS pillar** | n/a |
| **Incident theme** | none |
| **Products** | ERC4626 SE; DETF mint split; hook dust refunds |
| **Blast radius** | dust ≤ 1 wei / MAX_DUST |
| **Attacker** | EXT grief |
| **Attack scenario** | Rounding favors protocol or next depositor — not free mint |
| **Preconditions** | tiny amounts |
| **Impact** | grief / dust, not insolvency |
| **Evidence** | ERC4626 Out NatSpec D38 dust → feeTo |
| **Recommended TEST** | existing residual helpers on MultiVault; port if missing |
| **Anti-theater** | do not assert attackerProfit |
| **Suggested WP-ID** | cluster Wave 3 |
| **Link TCA / prior** | none |
| **Depends / parallel** | — |

## 3. Products implicated (blast)

All; no unique High.

## 4. Recommended epic WPs (Wave 0 style)

None. Do not `via_ir` to “fix stack.”

## 5. Explicit non-findings (checked, clean)

- No `unchecked` user-amount mint found in hunted In targets.
- Deadline=0 fails closed (sharp-edges).
- Coordinator ETH refund is `msg.value − amountIn` (not full balance).

## 6. Commands / checklists walked

```text
general / precision-math / dos headings (overflow, rounding, unbounded loop, gas grief)
rg via_ir docs/security/audit  # must not propose
# no forge
```
