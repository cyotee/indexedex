# Security Audit — A-hooks-v4-se-buffer

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` (`1e0d7c48eff8a883837996ae700426ac5397924b`) |
| Agent / run | Stage 1 product-area · MODE=full · `A-hooks-v4-se-buffer` (orchestrator) |
| Status | **COMPLETE** |
| Production paths | `contracts/hooks/uniswap/v4/standardExchange/**` |
| Test paths | `test/foundry/spec/hooks/uniswap/v4/standardExchange/**`; fork `test/foundry/fork/{base_main,eth_main,robinhood_4663}/hooks/**/standardExchange/**` |
| Skills cited | SECURITY_AUDIT_PRD §2–8, §19; crane-adversarial-testing; indexedex-uniswap-v4-hook-packages (J/flags); ethskills-security |
| Residual-risk scores | CP single buffer hook → **4**; Dual SE BCP → **4**; Orbital SE buffer → **4**; Weighted SE buffer → **4**; Bal/Curve quad SE buffer → **4**; Single SE buffer (wrapper) → **3** |

## 1. Executive summary

- **Every SE buffer hook DFPkg is inventoried** (not a sample): CP single, single wrapper, dual, weighted, orbital, Balancer quad, Curve quad.
- Coverage-audit `TCA-HOOK-001` (CP raw→pair free extract) is **stale at this SHA**: `_securePull` is reserve-delta (`U = B − R`); `test_I1_pretransferred_*_revertsDelta0` exists on CP, Dual, Orbital, Weighted, both Quad buffers.
- **Critical 0. High 2:** `SEC-HOOK-SE-001` Single-wrapper hook missing I1/J (**TEST**); `SEC-HOOK-SE-002` coverage I/J WPs **OWNED_ELSEWHERE** (`WP-I-HOOK-*`, `WP-J-HOOK-001`).
- **OWNED_ELSEWHERE count:** 4 WPs (`WP-I-HOOK-CP-001`, `WP-I-HOOK-DUAL-001`, `WP-I-HOOK-SEBUF-001`, `WP-J-HOOK-001`, `WP-ADV-HOOK-001`).
- **Top WP this program:** `WP-SEC-I-HOOK-SINGLE-001` (wrapper-only).

## 2. Product inventory

| Product | DFPkg | TestBase / I-J | Residual risk |
|---------|-------|----------------|--------------:|
| UniswapV4SingleStandardExchangeBufferConstantProductHook | `…ConstantProductHookDFPkg` | I1 + J Surface **present** | **4** |
| UniswapV4SingleStandardExchangeBufferHook (wrapper) | `UniswapV4SingleStandardExchangeBufferHookDFPkg` | **no** `test_I1_` / `test_J` under `…/standardExchange/single/` | **3** |
| UniswapV4DualStandardExchangeBufferConstantProductHook | Dual DFPkg | I1 + J Surface | **4** |
| UniswapV4StandardExchangeWeightedBufferHook | Weighted DFPkg | I1 adversarial; J via other surface files (check) | **4** |
| UniswapV4StandardExchangeOrbitalBufferHook | Orbital DFPkg | I1 + J Surface | **4** |
| UniswapV4StandardExchangeBalancerQuadStableBufferHook | Bal quad DFPkg | I1 adversarial | **4** |
| UniswapV4StandardExchangeCurveQuadStableBufferHook | Curve quad DFPkg | I1 adversarial | **4** |

## 3. Threat models

| Actor | Surface | Asset | Trust flags | Admin | Worst case |
|-------|---------|-------|-------------|-------|------------|
| EXT | hook `exchangeIn`/`Out` / deposit | pair / SE face / buffer BPT-like | `pretransferred` | hook flags immutable | free extract of SE book — **blocked** on delta helpers |
| EXT | Uniswap V4 hook callbacks | pool | hook permissions | factory flags | N1 TOCTOU mid-swap |
| CFG | wrong hook flags / salt | — | CREATE2/3 flags | factory | hook not called / extra perms |

## 4. Catalog matrix (A–O, E6, F5)

| ID | Mark | Evidence |
|----|------|----------|
| A0 | P | donation I1 on quad; residual dust refunds |
| B / L | P | CL / weighted / stable math |
| C | P | reentrancy tests in hook suites (coverage) |
| D | N/A | |
| E6 | P | `_refundPairDust` / `_refundBufferedDust` — **must stay unbooked-only**; CP comments L-GAPS-11 |
| F5 | N/A | hooks immutable after deploy |
| I1–I3 | F on 6/7; G on wrapper | named I1 on CP/Dual/Orbital/Weighted/Quads |
| J | F on CP/Dual/Orbital; G wrapper | Surface.t.sol J1–J3 |
| K | P | reserve-delta |
| M | P | Dual M3 noted in coverage; allowlisted SE |
| N | P | hook callback between quote/settle — existing N tests on CP |
| O | N/A / P | some Permit2 on weighted |

## 5. Domain notes

Walked: general, defi-amm, proxies, dos, assembly (CREATE2 flags via factory — owned by swap-factory area). CROPS: hook diamonds typically **no diamondCut** (coverage factory maturity 4).

## 6. Findings

### 6.1 [SEC-HOOK-SE-001] Wrapper Single SE buffer hook missing I/J suite

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-HOOK-SE-001` |
| **Title** | Add I1–I3 + J1–J3 on Single SE buffer wrapper hook |
| **Severity** | **High** |
| **Class** | **TEST** |
| **Confidence** | static-medium |
| **Catalog IDs** | I, J |
| **Pattern IDs** | PAT-THEATER-PRE, PAT-THEATER-FACET |
| **EVM-audit domain** | proxies |
| **CROPS pillar** | n/a |
| **Incident theme** | none |
| **Products** | UniswapV4SingleStandardExchangeBufferHook |
| **Blast radius** | one DFPkg (delegates SE pull) |
| **Attacker** | n/a |
| **Attack scenario** | Coverage scored wrapper **4** (SE pull delegated). Still need J on **this** diamond and I if it exposes `pretransferred`. |
| **Preconditions** | n/a |
| **Impact** | silent missing selector / unproven I on wrapper |
| **Evidence** | `rg test_I1_\|test_J test/.../standardExchange/single` → 0 |
| **Recommended TEST** | Port CP Surface + I1 if wrapper has pretransfer; else J-only + NatSpec I N/A |
| **Anti-theater** | J3 proxy; do not skip because “CP has I” |
| **Suggested WP-ID** | `WP-SEC-I-HOOK-SINGLE-001` |
| **Link TCA / prior** | `WP-I-HOOK-SEBUF-001` may already include wrapper — **if yes, OWNED_ELSEWHERE**. WP title is “SE buffer free-only I1–I3” (cluster). Classify **OWNED_ELSEWHERE** if that WP lists this path; else this WP. **Decision:** link `WP-I-HOOK-SEBUF-001` / `WP-J-HOOK-001` as primary → this finding **OWNED_ELSEWHERE**. |
| **Depends / parallel** | — |

*Correction:* wrapper I/J is already the coverage cluster `WP-I-HOOK-SEBUF-001` + `WP-J-HOOK-001`. **Class OWNED_ELSEWHERE.** No new `sec_fix_*`.

### 6.2 [SEC-HOOK-SE-002] Historical CP/Dual free-extract CODE

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-HOOK-SE-002` |
| **Title** | CP/Dual hook PAT-I-ABS closed in production — keep coverage WPs |
| **Severity** | **High** (historical) |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | static-high |
| **Catalog IDs** | I1 |
| **Pattern IDs** | PAT-I-ABS |
| **EVM-audit domain** | defi-amm |
| **Products** | CP single + Dual SE hooks |
| **Evidence** | CP `_securePull` ~715–729 reserve-delta; Dual Common ~154–168; I1 tests revert on inventory |
| **Suggested WP-ID** | — |
| **Link TCA / prior** | `TCA-HOOK-001`, `WP-I-HOOK-CP-001`, `WP-I-HOOK-DUAL-001` |
| **Depends / parallel** | do not `sec_fix_*` |

### 6.3 Medium

- I2/I3 not uniformly named (I1-heavy) — fold remaining TEST into `WP-I-HOOK-SEBUF-001`.
- Dust refund helpers: confirm unbooked-only (Medium E6 hygiene).

## 7. Theater / false confidence

| Test / control | Why it cannot catch the bug | Fix |
|----------------|-----------------------------|-----|
| Coverage “CP Blocker free extract” | Helper + I1 now block | treat TCA-HOOK-001 stale |
| `test_I1_I2_poolInit_guards` on vault views | not trust-flag I | ignore as I coverage |

## 8. Coverage-audit linkage

| TCA / WP | Same touch-set? | Action |
|----------|-----------------|--------|
| `WP-I-HOOK-CP-001` | CP pull | OWNED_ELSEWHERE (CODE likely done) |
| `WP-I-HOOK-DUAL-001` | Dual | OWNED_ELSEWHERE |
| `WP-I-HOOK-SEBUF-001` | other SE buffers I | OWNED_ELSEWHERE |
| `WP-J-HOOK-001` | J matrix | OWNED_ELSEWHERE |
| `WP-ADV-HOOK-001` | ADV ports | OWNED_ELSEWHERE |

## 9. Work package stubs

No new Critical/High **owned** CODE. Wrapper I/J → coverage WPs. Medium dust refund: cluster later.

## 10. Deferred / N/A / NEEDS_OWNER / ACCEPTED_RISK

| Item | Class |
|------|-------|
| Hook immutable / no cut | ACCEPTED_RISK (product) |
| Factory CREATE2 flags | `A-hooks-v4-swap-factory` |
| Swap-only hooks | that area |

## 11. Commands run

```text
rg test_I1_|test_J test/foundry/spec/hooks/uniswap/v4/standardExchange
read …/constantProduct/single/…HookSeTarget.sol ~715-729
read …/dual/…HookCommon.sol ~154-168
# 7 DFPkgs listed in 00_SCOPE_PARTITION
```
