# Security Audit — A-hooks-v4-swap-factory

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` (`1e0d7c48eff8a883837996ae700426ac5397924b`) |
| Agent / run | Stage 1 product-area · MODE=full · `A-hooks-v4-swap-factory` (orchestrator) |
| Status | **COMPLETE** |
| Production paths | `contracts/hooks/uniswap/v4/{factory,weighted,orbital,stable}/**` |
| Test paths | `test/foundry/spec/hooks/uniswap/v4/{weighted,orbital,stable}/**`; factory tests; fork hook trees |
| Skills cited | SECURITY_AUDIT_PRD §2–8, §19; indexedex-uniswap-v4-hook-packages; crane-adversarial-testing |
| Residual-risk scores | Hook factory → **4**; WeightedSwapHook → **3**; OrbitalSwapHook → **3**; Balancer QuadStableSwapHook → **3**; Curve QuadStableSwapHook → **3** |

## 1. Executive summary

- Swap hooks are **pricing/AMM hooks**, not SE `pretransferred` vaults. I1–I3 = **N/A** (no pull-credit). J + flags + residual + reentrancy remain P0.
- Factory: no `pretransferred` / `onlyOwner` money path; CREATE3 callback factory + `deployHookVault` via registry (coverage maturity 4).
- **Critical 0. High 1 TEST OWNED_ELSEWHERE:** `WP-J-HOOK-001` / `WP-ADV-HOOK-001` still own formal J + ADV for swap hooks (`rg test_J` under `…/hooks/…/weighted` and swap-only trees empty).
- **No new `sec_fix_*`.** Residual-risk 3 = missing J matrix, not live extract.

## 2. Product inventory

| Product | DFPkg | Residual risk |
|---------|-------|--------------:|
| UniswapV4HookDiamondPackageCallBackFactory | factory + FactoryService + AwareRepo | **4** |
| UniswapV4WeightedSwapHook | `UniswapV4WeightedSwapHookDFPkg` | **3** |
| UniswapV4OrbitalSwapHook | `UniswapV4OrbitalSwapHookDFPkg` | **3** |
| UniswapV4BalancerQuadStableSwapHook | Bal quad swap DFPkg | **3** |
| UniswapV4CurveQuadStableSwapHook | Curve quad swap DFPkg | **3** |

## 3. Threat models

| Actor | Surface | Asset | Trust flags | Admin | Worst case |
|-------|---------|-------|-------------|-------|------------|
| EXT | `beforeSwap`/`afterSwap` / modifyLiquidity | pool tokens | hook flags | none on instance | residual leak / reentrancy |
| CFG | wrong `requiredHookFlags` / salt | — | CREATE2 bits | factory | hook skipped or extra callback |
| ADM | factory owner (if any) | deploy | — | registry | cannot steal live hook inventory if unowned |

## 4. Catalog matrix (A–O, E6, F5)

| ID | Mark | Evidence |
|----|------|----------|
| A0 / I | N/A | no pretransfer credit |
| B / L | P | swap math |
| C | P | reentrancy tests (coverage) |
| E6 | P | residual / fee dust |
| F / F5 | P | instances typically uncuttable |
| J | G | no `test_J` under swap-only weighted tree; factory J informal |
| M | N/A | |
| N | P | hook between quote and settle |
| O | N/A | |

## 5. Domain notes

Walked: general, defi-amm, proxies, dos, assembly (flag mining). Factory has **no** PAT-I-ABS surface.

## 6. Findings

### 6.1 [SEC-HOOK-SW-001] Swap-hook J1–J3 still coverage-owned

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-HOOK-SW-001` |
| **Title** | Formal J on swap hooks + factory |
| **Severity** | **High** |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | static-medium |
| **Catalog IDs** | J1–J3 |
| **Pattern IDs** | PAT-J-OMIT, PAT-THEATER-FACET |
| **EVM-audit domain** | proxies |
| **Products** | four swap hooks + factory |
| **Blast radius** | hook diamonds |
| **Attacker** | n/a |
| **Attack scenario** | omitted `afterSwap` / liquidity selector |
| **Impact** | hook not invoked or extra function missing |
| **Evidence** | `rg test_J test/foundry/spec/hooks/uniswap/v4/weighted` → 0 |
| **Recommended TEST** | as `WP-J-HOOK-001` |
| **Anti-theater** | J3 on hook **proxy** after `deployHookVault` |
| **Suggested WP-ID** | — |
| **Link TCA / prior** | `WP-J-HOOK-001`, `WP-ADV-HOOK-001` |
| **Depends / parallel** | — |

## 7. Theater / false confidence

| Test / control | Why it cannot catch the bug | Fix |
|----------------|-----------------------------|-----|
| Flag/salt H tests | not J | WP-J-HOOK-001 |
| CL-ban tests named `test_I2_*` | not trust-flag I | ignore |

## 8. Coverage-audit linkage

| TCA / WP | Action |
|----------|--------|
| `WP-J-HOOK-001` | OWNED_ELSEWHERE |
| `WP-ADV-HOOK-001` | OWNED_ELSEWHERE |

## 9. Work package stubs

None this program (all High → coverage).

## 10. Deferred / N/A / NEEDS_OWNER / ACCEPTED_RISK

| Item | Class |
|------|-------|
| I1 on swap hooks | N/A |
| Flag-bit economics | ACCEPTED_RISK / CFG |

## 11. Commands run

```text
rg pretransferred|_securePull|diamondCut contracts/hooks/uniswap/v4/factory --glob '*.sol'
rg test_I1_|test_J test/foundry/spec/hooks/uniswap/v4/weighted
ls contracts/hooks/uniswap/v4/{factory,weighted,orbital,stable}
```
