# Security Audit — A-se-balancer-v3

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` (`1e0d7c48eff8a883837996ae700426ac5397924b`) |
| Agent / run | Stage 1 product-area · MODE=full · `A-se-balancer-v3` (orchestrator) |
| Status | **COMPLETE** |
| Production paths | `contracts/protocols/dexes/balancer/v3/pools/**`; `…/rateProviders/**`; `…/routers/**` (SE router DFPkg, not Coordinator) |
| Test paths | `test/foundry/spec/protocols/dexes/balancer/v3/pools/**`; `test/foundry/spec/protocol/dexes/balancer/v3/routers/**` |
| Skills cited | SECURITY_AUDIT_PRD §2–8, §19; crane-adversarial-testing; crane-balancer |
| Residual-risk scores | Buffer / multi-vault pools → **4**; rate providers → **3**; BalancerV3 SE Router → **4**; **BalancerV3SinglePoolStandardExchange** → **1** |

## 1. Executive summary

- Buffer pool packages (mixed/common stable+weighted, mixed-leg, multi-pair, constProd) are **pool math + hooks**, not `pretransferred` vaults. Coverage scored **4** with adversarial/invariants — **reuse**, no re-hunt of pool math.
- **New High CODE this program owns:** `BalancerV3SinglePoolStandardExchange._receiveExactIn` / `_receiveMaxIn` **return claimed** after optional skip-transfer (**PAT-I-ABS**). Also `_refundUnused` pays `deposited−used` where `deposited` is the **claimed max** (E6). Plus max `forceApprove` to router + Permit2 (**PAT-SHARP-FLAG** / M).
- SE router + rate providers: J leftover **OWNED_ELSEWHERE** (`WP-J-ROUTER-UAB-001`).
- **Critical 0** (RUNTIME_UNPROVEN). **High 2** (SinglePool receive CODE + TEST I).

## 2. Product inventory

| Product | Path | Residual risk |
|---------|------|--------------:|
| MixedBufferMultiVaultStablePool | `pools/stable/mixedBufferMultiVault/**` | **4** |
| CommonBufferMultiVaultStablePool | `pools/stable/commonBufferMultiVault/**` | **4** |
| CommonBufferMultiVaultWeightedPool | `pools/weighted/commonBufferMultiVault/**` | **4** |
| MixedLegWeightedBufferPool | `pools/weighted/mixedLegBuffer/**` | **4** |
| MultiPairStandardExchangeBufferPool | `pools/weighted/multiPairBuffer/**` | **4** |
| ConstProd SE buffer pool facets | `pools/constProd/**` | **4** |
| BalancerV3SinglePoolStandardExchange | `pools/BalancerV3SinglePoolStandardExchange.sol` | **1** |
| StandardExchangeRateProvider (+ wrapped) | `rateProviders/standardExchange/**` | **3** |
| BalancerV3StandardExchangeRouter | `routers/**` DFPkg | **4** |

## 3. Threat models

### SinglePool SE helper

| Actor | Surface | Asset | Trust flags | Worst case |
|-------|---------|-------|-------------|------------|
| EXT | `_receiveExactIn` via public In | pool tokens | `pretransferred` | free credit claimed; join spends vault inventory |
| EXT | `_refundUnused` | pair | fat max | skim |
| INT | `_approvePermit2ToRouter` | allowance | max uint | M3 sweep if router hostile |

### Buffer pools

| Actor | Surface | Asset | Worst case |
|-------|---------|-------|------------|
| EXT | add/remove liquidity / hook | BPT / tokens | residual / invariant break (suite exists) |

## 4. Catalog matrix (A–O, E6, F5)

| ID | SinglePool SE | Buffer pools | Router |
|----|---------------|--------------|--------|
| I1–I3 | **VULN** | N/A | N/A (I5 on coordinator) |
| E6 | **VULN** | P | P |
| J | G | P | P (`WP-J-ROUTER-UAB-001`) |
| M | **VULN** max approve | N/A | P |
| A0/K | G | P | N/A |
| L/B | P | F (coverage) | P |

## 5. Domain notes

Walked: general, defi-amm, erc20, proxies, access-control. Buffer pool gold left to coverage-audit maturity 4.

## 6. Findings

### 6.1 [SEC-SE-BAL-001] SinglePool SE receive returns claimed with no delta

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-BAL-001` |
| **Title** | Delta-gate `BalancerV3SinglePoolStandardExchange` receive |
| **Severity** | **High** |
| **Class** | **CODE** |
| **Confidence** | static-high |
| **Catalog IDs** | I1–I3, E6, M3 |
| **Pattern IDs** | **PAT-I-ABS**, PAT-E6-REFUND, PAT-SHARP-FLAG, PAT-M-CALL |
| **EVM-audit domain** | erc20 / defi-amm |
| **CROPS pillar** | n/a |
| **Incident theme** | donation / allowance |
| **Products** | BalancerV3SinglePoolStandardExchange |
| **Blast radius** | this helper + any pool that uses it as SE adapter |
| **Attacker** | **EXT** |
| **Attack scenario** | 1. Contract holds tokenIn. 2. `pretransferred=true`, `amountIn` ≤ balance. 3. `_receiveExactIn` skips transfer, **returns amountIn**. 4. Join/swap spends inventory. 5. `_refundUnused` may also pay `max−used` of **claimed** deposit. |
| **Preconditions** | Inventory ≥ claimed. |
| **Impact** | Free join / skim. |
| **Evidence** | `BalancerV3SinglePoolStandardExchange.sol` ~172–189, ~192–197 (max approve). |
| **Runtime** | RUNTIME_UNPROVEN |
| **Recommended CODE** | Measure delta / `U`; typed short revert; refund this-call unused only; cap Permit2 allowance to `amountIn`. |
| **Recommended TEST** | `test_I1_singlePool_pretransferred_noTransfer_reverts`; `test_E6_refund_not_claimed_max`; `test_M_allowance_not_max`. |
| **Anti-theater** | I1 no transfer; real pool proxy if packaged |
| **Suggested WP-ID** | `WP-SEC-I-BAL-SINGLE-001` |
| **Link TCA / prior** | not in `WP-I-CLONE-UAB-001` file list |
| **Depends / parallel** | parallel Loop I, Slip E6 |

### 6.2 [SEC-SE-BAL-002] SE router formal J — coverage

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-BAL-002` |
| **Title** | Balancer SE Router J remains coverage-owned |
| **Severity** | **High** |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | static-medium |
| **Catalog IDs** | J |
| **Pattern IDs** | PAT-THEATER-FACET |
| **EVM-audit domain** | proxies |
| **Products** | BalancerV3StandardExchangeRouter |
| **Evidence** | `WP-J-ROUTER-UAB-001` |
| **Suggested WP-ID** | — |
| **Link TCA / prior** | `WP-J-ROUTER-UAB-001` |
| **Depends / parallel** | — |

## 7. Theater / false confidence

| Test / control | Why it cannot catch the bug | Fix |
|----------------|-----------------------------|-----|
| Buffer pool ADV | does not hit SinglePool helper | dedicated I1 |
| Coverage “router 4” | different contract | — |

## 8. Coverage-audit linkage

| TCA / WP | Action |
|----------|--------|
| buffer ADV / L3 | reuse; no new WP |
| `WP-J-ROUTER-UAB-001` | OWNED_ELSEWHERE |
| none | SinglePool helper → new WP |

## 9. Work package stubs

### WP-SEC-I-BAL-SINGLE-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-I-BAL-SINGLE-001` |
| **Title** | Delta-safe SinglePool SE receive + cap refund/allowance |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | BalancerV3SinglePoolStandardExchange |
| **Finding IDs** | SEC-SE-BAL-001 |
| **Problem** | Skip-transfer returns claimed; refund uses claimed max; max Permit2 approve. |
| **Production files (touch set)** | `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol` |
| **Test files (touch set)** | new spec under `test/foundry/spec/protocols/dexes/balancer/v3/pools/` |
| **Out of scope files** | buffer pool families; Coordinator |
| **Depends on** | none |
| **Parallelizable with** | Loop I, Slip E6 |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_bal-single-i` / `sec_fix/bal-single-i` |
| **Implementation notes** | Copy ERC4626 `_securePull`. No `via_ir`. |
| **Acceptance** | `--match-test 'test_I1_\|test_E6_\|test_M_' --match-path 'test/**/balancer/v3/pools/**'` |
| **Anti-theater checks** | I1 no transfer |
| **Proof-first?** | **yes** |
| **Estimate** | M |

## 10. Deferred / N/A / NEEDS_OWNER / ACCEPTED_RISK

| Item | Class |
|------|-------|
| Buffer pool invariant depth | DEFER (coverage 4) |
| Rate provider thin smoke | Medium TEST — cluster |

## 11. Commands run

```text
rg pretransferred|_secure contracts/protocols/dexes/balancer/v3/pools --glob '*.sol'
read BalancerV3SinglePoolStandardExchange.sol ~172-197
# buffer DFPkg-like StandardVaultPkg files inventoried
```
