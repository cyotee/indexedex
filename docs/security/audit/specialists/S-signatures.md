# Security Audit specialist — S-signatures

| Field | Value |
|-------|--------|
| Date / SHA / status | 2026-08-13 · `1e0d7c48` · **COMPLETE** |
| Inputs | `A-routers-permit2`; commons Permit2 tests; ERC20 permit on DETF diamonds |
| Skill | ethskills-audit signatures + catalog O / I5 |

## 1. Cross-cut thesis (≤10 lines)

The only **first-class Permit2 money path** is the Coordinator `swapExactInWithPermit` → `permitWitnessTransferFrom` with **token match**, **delta received**, and a **witness hash of route params**. I5 suite exists (replay, wrong spender, amount/steps tamper). Coverage `WP-I5-RTR-001` / `WP-J-RTR-001` **OWNED_ELSEWHERE**. Vault Permit2 on BasicVaultCommon is commons-owned. No ecrecover-address(0) custom signer found on coordinator. **No new High CODE.**

## 2. Findings

### 2.1 [SEC-SPEC-040] Coordinator I5/O already tested

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SPEC-040` |
| **Title** | No new Permit2 CODE WP |
| **Severity** | **High** (historical TEST) |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | static-high |
| **Catalog IDs** | O1–O3, I5 |
| **Pattern IDs** | PAT-O-SIG |
| **EVM-audit domain** | signatures |
| **CROPS pillar** | n/a |
| **Incident theme** | broken permit |
| **Products** | Coordinator router |
| **Blast radius** | one diamond |
| **Attacker** | INT |
| **Attack scenario** | Replay / wrong spender — **reverts in existing tests** |
| **Preconditions** | n/a |
| **Impact** | none new |
| **Evidence** | `BalancerV3UniswapV4CoordinatorRouter_Permit2Security.t.sol`; ExactInTarget `_pullPermit` |
| **Recommended TEST** | leftover exact-selector → `WP-N-RTR-001` |
| **Anti-theater** | do not count happy path as I5 |
| **Suggested WP-ID** | — |
| **Link TCA / prior** | `WP-I5-RTR-001`, `WP-N-RTR-001` |
| **Depends / parallel** | — |

## 3. Products implicated (blast)

Coordinator; BasicVaultCommon Permit2 (commons); ERC20 `permit` on DETF (standard OZ-style — not re-hunted).

## 4. Recommended epic WPs (Wave 0 style)

None.

## 5. Explicit non-findings (checked, clean)

- Permit token ≠ `params.tokenIn` → `InvalidPermitWitness`.
- Short Permit2 delivery → `InvalidAmount`.
- ETH path does not use Permit2; `msg.value` checked.
- No custom `ecrecover` on coordinator ExactIn target.

## 6. Commands / checklists walked

```text
rg permitWitness|ecrecover contracts/routers --glob '*.sol'
rg test_I5_ test/foundry/spec/routers
signatures checklist: replay, domain, zero address, spender
```
