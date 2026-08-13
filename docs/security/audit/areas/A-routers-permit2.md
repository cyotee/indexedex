# Security Audit — A-routers-permit2

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` (`1e0d7c48eff8a883837996ae700426ac5397924b`) |
| Agent / run | Stage 1 product-area · MODE=full · `A-routers-permit2` (orchestrator) |
| Status | **COMPLETE** |
| Production paths | `contracts/routers/**` (Coordinator `balancerV3-uniswapV4/**`). Balancer SE router owned by `A-se-balancer-v3`. |
| Test paths | `test/foundry/spec/routers/**`; `test/foundry/fork/**/routers/**` |
| Skills cited | SECURITY_AUDIT_PRD §2–8, §19; ethskills-audit signatures; catalog O/I5 |
| Residual-risk scores | BalancerV3UniswapV4CoordinatorRouter → **3** |

## 1. Executive summary

- Permit2 pull is **delta-measured** (`balAfter − balBefore`; short → `InvalidAmount`). Token mismatch vs witness reverts `InvalidPermitWitness`.
- **I5 suite exists** (`test_I5_signatureReplay_*`, wrong spender, amount/steps tamper). **J1–J3 exist** on Surface tests.
- Coverage Highs (`WP-I5-RTR-001`, `WP-N-RTR-001`, `WP-J-RTR-001`) are **largely landed as TEST**. Residual: M1–M3 on `step.data` / adapter dispatch (user calldata to allowlisted routers).
- **Critical 0. High 1 OWNED_ELSEWHERE** leftover TEST hygiene (`WP-N-RTR-001`). **High 1 new Medium-clustered M:** open `step.data` to child routers — not a new Critical if allowlist holds.
- **No new `sec_fix_*` CODE.** Medium `SEC-RTR-001` M3 allowlist+measure.

## 2. Product inventory

| Product | DFPkg / Targets | TestBase | Residual risk |
|---------|-----------------|----------|--------------:|
| **BalancerV3UniswapV4CoordinatorRouter** | `BalancerV3UniswapV4CoordinatorRouterDFPkg`; ExactIn / admin / query / witness facets; adapters (Stock / Batch / SE / UR) | `TestBase_BalancerV3UniswapV4CoordinatorRouter` | **3** |
| Universal Router vendor smoke | `test/foundry/spec/routers/universal_router_port/**` | not SUT | n/a |

## 3. Threat models

| Actor | Surface | Asset | Trust flags | Admin | Worst case |
|-------|---------|-------|-------------|-------|------------|
| INT | `swapExactInWithPermit` | tokenIn | Permit2 witness | — | replay / wrong spender / witness tamper — **tested I5** |
| EXT | `swapExactInEth` | ETH | `msg.value` | — | underpay ETH — `InsufficientEth`; overpay refunded |
| INT | `step.data` + `step.router` | hop tokens | allowlist `_routerKind` | owner allowlist | M1 if kind=allow + hostile data |
| ADM | rescue / allowlist | stuck tokens | onlyOwner | owner | freeze hops / rescue |

## 4. Catalog matrix (A–O, E6, F5)

| ID | Mark | Evidence |
|----|------|----------|
| A0 / K | N/A | coordinator is not a vault |
| I5 / O | F | Permit2Security.t.sol I5 set; delta pull |
| J | F | Surface.t.sol J1–J3 |
| M1–M3 | P | allowlisted adapters; `step.data` forwarded |
| N | P | hop minOut; coverage WP-N-RTR-001 theater leftovers |
| E6 | P | ETH refund `msg.value − amountIn` only |
| L | P | hop out measured by balance delta |
| F | P | owned router (not DETF) |

## 5. Domain notes

Walked: general, erc20, signatures, access-control, dos. Catalog O/I5 primary.

## 6. Findings

### 6.1 [SEC-RTR-001] Coverage I5/J/N still own residual TEST

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-RTR-001` |
| **Title** | Do not open sec_fix for Coordinator I5/J — coverage WPs |
| **Severity** | **High** |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | static-high |
| **Catalog IDs** | I5, O, J, N |
| **Pattern IDs** | PAT-O-SIG, PAT-THEATER-FACET |
| **EVM-audit domain** | signatures |
| **Products** | Coordinator router |
| **Blast radius** | one diamond |
| **Attacker** | n/a |
| **Attack scenario** | n/a — tests exist; leftover exact-selector theater is `WP-N-RTR-001` |
| **Impact** | none new |
| **Evidence** | `BalancerV3UniswapV4CoordinatorRouter_Permit2Security.t.sol` I5; Surface J; ExactInTarget `_pullPermit` ~72–80 |
| **Recommended TEST** | finish `WP-N-RTR-001` only |
| **Anti-theater** | I5 must not count happy permit as replay proof |
| **Suggested WP-ID** | — |
| **Link TCA / prior** | `WP-I5-RTR-001`, `WP-J-RTR-001`, `WP-N-RTR-001` |
| **Depends / parallel** | — |

### 6.2 Medium [SEC-RTR-002] M3 `step.data` to allowlisted child

User calldata to Stock/Batch/SE/UR adapters. Allowlist is the control. **Medium TEST/CODE:** confirm unknown router reverts; measure `amountOut` only (already `_runStep` balance delta). Cluster; no High.

## 7. Theater / false confidence

| Test / control | Why it cannot catch the bug | Fix |
|----------------|-----------------------------|-----|
| Happy permit swap | not I5 | existing replay tests |
| Bare expectRevert leftovers | coverage N | `WP-N-RTR-001` |

## 8. Coverage-audit linkage

| TCA / WP | Action |
|----------|--------|
| `WP-I5-RTR-001` | OWNED_ELSEWHERE (suite present) |
| `WP-J-RTR-001` | OWNED_ELSEWHERE (suite present) |
| `WP-N-RTR-001` | OWNED_ELSEWHERE leftover TEST |
| `WP-J-ROUTER-UAB-001` | Balancer **SE** router — other area |

## 9. Work package stubs

None owned High CODE.

## 10. Deferred / N/A / NEEDS_OWNER / ACCEPTED_RISK

| Item | Class |
|------|-------|
| Owned coordinator (not unowned DETF) | ACCEPTED_RISK |
| Universal Router vendor smoke | Info / not SUT |

## 11. Commands run

```text
rg permitWitness|pretransferred contracts/routers --glob '*.sol'
rg test_I1_|test_J|test_I5_ test/foundry/spec/routers
read BalancerV3UniswapV4CoordinatorRouterExactInTarget.sol ~37-120
```
