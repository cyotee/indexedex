# Security Audit — A-slipstream-buffer

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` (`1e0d7c48eff8a883837996ae700426ac5397924b`) |
| Agent / run | Stage 1 product-area · MODE=full · `A-slipstream-buffer` (orchestrator) |
| Status | **COMPLETE** |
| Production paths | `contracts/protocols/dexes/aerodrome/slipstream/**`; `contracts/vaults/slipstream/**` |
| Test paths | `test/foundry/spec/protocols/dexes/aerodrome/slipstream/**`; `test/foundry/fork/base_main/slipstream/**` |
| Skills cited | SECURITY_AUDIT_PRD §2–8, §19; crane-adversarial-testing; indexedex-adversarial-testing; ethskills-security |
| Residual-risk scores | Slipstream SE → **2**; SlipstreamVaultRepo → **4** (storage only) |

## 1. Executive summary

- Pull helper is **same-tx inbound-delta** (`TransferDeltaInsufficient` if claimed > observedDelta). Classic two-tx PAT-I-ABS is **blocked**.
- **New High CODE this program owns:** `exchangeIn` `_refundRemainder` transfers **entire** `balanceOf(this)` of token0/token1 to `msg.sender` (**PAT-E6**). Same class as Uni V3 In (pilot blast). Out `_refundExcess` pays `maxAmount − used` when `pretransferred` (**PAT-E6**, same as Aero/Camelot Out — `WP-SEC-E6-SE-001` pattern).
- **Critical 0** (RUNTIME_UNPROVEN). **High 3** (2 CODE refund + 1 TEST I/J gap).
- **OWNED_ELSEWHERE:** none on these files (`WP-I-CLONE-001` lists Slipstream as same-tx peer, not E6 refund).
- **Top WPs:** `WP-SEC-E6-SLIP-001`.

## 2. Product inventory

| Product | DFPkg / Targets | TestBase | Deploy path | Residual risk |
|---------|-----------------|----------|-------------|--------------:|
| **SlipstreamStandardExchange** | `SlipstreamStandardExchangeDFPkg`; In/Out Facets+Targets; Common; FactoryService | slipstream TestBases | CREATE3 + manager registry | **2** |
| **SlipstreamVaultRepo** | storage lib `contracts/vaults/slipstream/SlipstreamVaultRepo.sol` | via SE | n/a | **4** |

## 3. Threat models

| Actor | Surface | Asset | Trust flags | Admin | Worst case |
|-------|---------|-------|-------------|-------|------------|
| EXT | `exchangeIn` | pair tokens → `vaultShare` + leftover tokens | `pretransferred` | — | drain **all** token0/token1 sitting on vault via `_refundRemainder` |
| EXT | `exchangeOut` | `vaultShare` → pair | `pretransferred` + fat `maxAmountIn` | — | skim booked pair via `max−used` refund |
| CAP | CL pool spot | pair | — | Slipstream pool | L3 / B |
| HOS | FoT pair | pair | — | — | L2 if allowed |

## 4. Catalog matrix (A–O, E6, F5)

| ID | Mark | Evidence |
|----|------|----------|
| A0 | G | zap/empty CL position residual not catalogued |
| B / L3 | P | CL ticks / spot |
| C | G | |
| D | N/A | |
| E6 | **VULN** | `_refundRemainder` entire balance; Out `max−used` |
| F5 | N/A | |
| H | P | |
| I1–I3 | P | same-tx delta pull; no named I suite |
| J | G | Facets exist; no J suite found |
| K | P | pull does not credit booked inventory |
| L1 | **VULN** | entire-balance refund = skim |
| M | N/A | |
| N | G | |
| O | N/A | |

## 5. Domain notes

Walked: general, precision-math, erc20, defi-amm (CL), proxies, flashloans (CAP), dos. Slipstream is product-like (DFPkg + fork tests) — in scope (not DEFER).

## 6. Findings

### 6.1 [SEC-SE-SLIP-001] In `_refundRemainder` pays entire token balance

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-SLIP-001` |
| **Title** | Cap Slipstream In refund to this-call unused inbound |
| **Severity** | **High** |
| **Class** | **CODE** |
| **Confidence** | static-high |
| **Catalog IDs** | E6, L1 |
| **Pattern IDs** | **PAT-E6-REFUND**, PAT-L-SKIM |
| **EVM-audit domain** | defi-amm |
| **CROPS pillar** | n/a |
| **Incident theme** | skim / surplus refund |
| **Products** | SlipstreamStandardExchange |
| **Blast radius** | this package (+ same anti-pattern as Uni V3 In) |
| **Attacker** | **EXT** |
| **Attack scenario** | 1. Vault holds token0/token1 (inventory / donation). 2. Attacker `exchangeIn` any small mint (or even dust). 3. After mint, `_refundRemainder(token0)` and `token1` transfer **full** `balanceOf` to attacker. 4. Booked CL / idle inventory leaves with attacker. |
| **Preconditions** | Non-zero token0/token1 balance on vault after mint path. |
| **Impact** | Drain pair tokens; possible insolvency vs LP position. |
| **Evidence** | `SlipstreamStandardExchangeInTarget.sol` ~228–229, ~256–260. |
| **Runtime** | RUNTIME_UNPROVEN |
| **Recommended CODE** | Snapshot balances before consume; refund only unused inbound (or `U` unbooked surplus), never raw `balanceOf`. |
| **Recommended TEST** | `test_E6_in_refund_doesNotSweepBookedInventory` — seed tokens, exchangeIn, assert seed remains. |
| **Anti-theater** | Seed **before** call; do not count leftover-from-this-call as booked. |
| **Suggested WP-ID** | `WP-SEC-E6-SLIP-001` |
| **Link TCA / prior** | none (Uni V3 similar but `WP-I-CLONE-001` is pull, not refund) |
| **Depends / parallel** | parallel Uni V3 E6 if that area opens a WP |

### 6.2 [SEC-SE-SLIP-002] Out `_refundExcess` pays max−used

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-SLIP-002` |
| **Title** | Cap Slipstream Out refund to this-call unused inbound |
| **Severity** | **High** |
| **Class** | **CODE** |
| **Confidence** | static-high |
| **Catalog IDs** | E6, I1 |
| **Pattern IDs** | PAT-E6-REFUND |
| **EVM-audit domain** | erc20 |
| **Products** | SlipstreamStandardExchange |
| **Blast radius** | Out Target |
| **Attacker** | **EXT** with `pretransferred=true` + fat max + transfer only `used` |
| **Attack scenario** | Same as `SEC-SE-AC-001` / `SEC-SHARP-002`: credit `used`, refund `max−used` from booked pair. |
| **Preconditions** | Booked pair tokens ≥ `max−used`. |
| **Impact** | Skim pair inventory. |
| **Evidence** | `SlipstreamStandardExchangeOutTarget.sol` ~238–247. |
| **Runtime** | RUNTIME_UNPROVEN |
| **Recommended CODE** | Refund `min(max−used, this-call unused U)`. |
| **Recommended TEST** | `test_E6_out_pretransferred_fatMax_doesNotSkimBook` |
| **Anti-theater** | Transfer only `used`; vault already holds inventory |
| **Suggested WP-ID** | `WP-SEC-E6-SLIP-001` |
| **Link TCA / prior** | pattern twin of `WP-SEC-E6-SE-001` (Aero/Camelot/UniV2) — **different files**, new WP |
| **Depends / parallel** | same WP as 001 |

### 6.3 [SEC-SE-SLIP-003] Missing I/J catalog tests

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-SLIP-003` |
| **Title** | Slipstream I1–I3 + J1–J3 |
| **Severity** | **High** |
| **Class** | **TEST** |
| **Confidence** | static-medium |
| **Catalog IDs** | I, J |
| **Pattern IDs** | PAT-THEATER-PRE, PAT-THEATER-FACET |
| **EVM-audit domain** | proxies |
| **Products** | SlipstreamStandardExchange |
| **Blast radius** | one package |
| **Attacker** | n/a |
| **Attack scenario** | n/a |
| **Impact** | no ship-gate proof |
| **Evidence** | no `test_I1_` / `test_J` found under slipstream spec (static rg) |
| **Recommended TEST** | I+J+E6 in one adversarial file |
| **Anti-theater** | I1 no transfer; J3 proxy |
| **Suggested WP-ID** | `WP-SEC-E6-SLIP-001` (fold TEST) |
| **Link TCA / prior** | none |
| **Depends / parallel** | after CODE |

## 7. Theater / false confidence

| Test / control | Why it cannot catch the bug | Fix |
|----------------|-----------------------------|-----|
| Happy mint that refunds leftover of **this** add | Does not seed prior inventory | E6 seed-before-call |
| Same-tx I1 on pull | Does not test refund skim | separate E6 |

## 8. Coverage-audit linkage

| TCA / WP | Same touch-set? | Action |
|----------|-----------------|--------|
| `WP-I-CLONE-001` | Slipstream pull listed as same-tx **peer** (not ABS) | no CODE on pull |
| `WP-SEC-E6-SE-001` | same pattern, **AMM v2 files** | new WP here |

## 9. Work package stubs

### WP-SEC-E6-SLIP-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-E6-SLIP-001` |
| **Title** | Cap Slipstream In/Out refunds; add I/J/E6 tests |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | SlipstreamStandardExchange |
| **Finding IDs** | SEC-SE-SLIP-001, SEC-SE-SLIP-002, SEC-SE-SLIP-003 |
| **Problem** | Entire-balance In refund + max−used Out refund skim booked CL pair tokens. |
| **Production files (touch set)** | `SlipstreamStandardExchangeInTarget.sol`; `SlipstreamStandardExchangeOutTarget.sol` |
| **Test files (touch set)** | `test/foundry/spec/protocols/dexes/aerodrome/slipstream/adversarial/` (new) |
| **Out of scope files** | Aero v1; Uni V3 (own area); `SlipstreamVaultRepo.sol` unless slot change |
| **Depends on** | none |
| **Parallelizable with** | `WP-SEC-E6-SE-001`, Uni V3 E6 |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_slip-e6` / `sec_fix/slip-e6` |
| **Implementation notes** | Snapshot unused inbound. Fork-first CL paths if hermetic incomplete (L-SEC-5). No `via_ir`. |
| **Acceptance** | `forge test --match-path 'test/**/slipstream/**' --match-test 'test_E6_\|test_I1_\|test_J' -vv` |
| **Anti-theater checks** | E6 seeds inventory; I1 no transfer |
| **Proof-first?** | **yes** |
| **Estimate** | M |

## 10. Deferred / N/A / NEEDS_OWNER / ACCEPTED_RISK

| Item | Class |
|------|-------|
| CL tick management / MEV | DEFER P2 |
| Repo-only file | no money entry |

## 11. Commands run

```text
rg pretransferred|_refund contracts/protocols/dexes/aerodrome/slipstream --glob '*.sol'
read SlipstreamStandardExchangeCommon.sol ~441-459
read SlipstreamStandardExchangeInTarget.sol ~228-260
read SlipstreamStandardExchangeOutTarget.sol ~238-247
```
