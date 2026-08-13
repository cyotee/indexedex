# Security Audit — A-se-aave

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` (`1e0d7c48eff8a883837996ae700426ac5397924b`) |
| Agent / run | Stage 1 product-area · MODE=full · `A-se-aave` (orchestrator after spawn-cap) |
| Status | **COMPLETE** |
| Production paths | `contracts/protocols/lending/aave/v3.6/**`; `contracts/protocols/lending/aave/cross-version/**` |
| Test paths | `test/foundry/spec/protocol/lending/aave/**`; `test/foundry/fork/{base_main,eth_main}/aave/**`; `TestBase_Aave*` |
| Skills cited | SECURITY_AUDIT_PRD §2, §2.4, §3.8, §5–8, §19; crane-adversarial-testing; indexedex-adversarial-testing; indexedex-testing; ethskills-security; defi-incident-patterns; coverage `T-se-univ4-aave-balancer.md` |
| Residual-risk scores | Aave V3.6 Stata SE → **3**; Aave CrossVersion Loop → **1** |

## 1. Executive summary

- **Residual-risk scores:** Stata SE **3** (token pull now inherits reserve-delta `BasicVaultCommon`; I1/J exist). CrossVersion Loop **1** (live PAT-I-ABS on `exchangeIn`; share-burn from `address(this)` on Out; no I/J suite).
- **Critical / High:** **Critical 0** (Loop free-mint is High + `RUNTIME_UNPROVEN` per L-SEC-3). **High 4** — `SEC-SE-AAVE-001` (Loop In skip-pull, **CODE** this program owns), `SEC-SE-AAVE-002` (Loop Out self-share burn, **CODE**), `SEC-SE-AAVE-003` (Loop I1–I3/J **TEST**, overlap `WP-I-SE-UAB-001` → **OWNED_ELSEWHERE**), `SEC-SE-AAVE-004` (Stata Out `_secureSelfBurn` E6, **OWNED_ELSEWHERE** → `WP-SEC-E6-COMMON-001` / `SEC-COMMON-002`).
- **Stata PAT-I-ABS from 2026-08-09 coverage-audit is stale.** `AaveV3StataStandardExchangeInTarget.exchangeIn` now calls `_secureTokenTransfer` (durable `U = B − R`). Historical `TCA-SE-UAB-002` / `WP-I-CLONE-UAB-001` stay **OWNED_ELSEWHERE**.
- **Top WPs this program owns:** `WP-SEC-I-AAVE-LOOP-001` (delta-gate Loop In+Out). Do not open `sec_fix_*` on Stata In pull body.
- **OWNED_ELSEWHERE count:** **4** (`WP-I-CLONE-UAB-001` Stata In; `WP-I-SE-UAB-001` I tests; `WP-J-SE-UAB-001` Stata J — already present as `Adversarial_AaveV3StataSE_SecurePull.t.sol` J1–J3; `WP-SEC-E6-COMMON-001` self-burn).

## 2. Product inventory

| Product | DFPkg / Targets | TestBase | Deploy path | Residual risk |
|---------|-----------------|----------|-------------|--------------:|
| **AaveV3StataStandardExchange** | `AaveV3StataStandardExchangeDFPkg`; In/Out Target+Facet; Marker; Common inherits `BasicVaultCommon` (**no** `_secureTokenTransfer` override) | `TestBase_Aave*` / hermetic Stata; adversarial `Adversarial_AaveV3StataSE_SecurePull.t.sol` | CREATE3 + `indexedexManager.deploy*DFPkg` | **3** |
| **AaveCrossVersionLoop** | `AaveCrossVersionLoopDFPkg`; In/Out/Rebalance/Marker Facets+Targets; executor/service | hermetic/spec under `test/**/aave/cross-version/**` (no `test_I*` found) | CREATE3 + registry DFPkg | **1** |

## 3. Threat models

### 3.1 Aave V3.6 Stata SE

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| EXT / CAP | `exchangeIn` | `rateAsset` / Stata / aToken → `vaultShare` | `pretransferred` | fee oracle | free mint if pull were absolute — **blocked** at helper |
| EXT | `exchangeOut` | `vaultShare` → Stata/base/aToken | `pretransferred` + `_secureSelfBurn` | fee | skim leftover self-shares (commons E6) |
| HOS | Stata / aToken as configured | rebase / pause | n/a | Aave pool | FoT N/A (Aave tokens); pause freeze |
| ADM | none on instance | — | — | manager disable if wired | freeze if `_requireNotDisabled` |

### 3.2 Aave CrossVersion Loop

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| EXT | `exchangeIn` | tokenA → loop shares | `pretransferred` **skips transferFrom** then credits `amountIn` | Aave V3/V4 oracles | **free mint** against vault inventory / loop NAV |
| EXT | `exchangeOut` | shares → tokenA | `pretransferred` burns `address(this)` shares | — | burn donated/inventory shares; no inbound-delta |
| EXT | `rebalance` / `forceRepay` | loop legs | none (permissionless) | placeholder HF/spread constants | F5 structural settle / NAV skew |
| CAP | flash + In | tokenA | same | spot oracles | inflate NAV then extract |

## 4. Catalog matrix (A–O, E6, F5)

| ID | Product | F/P/G/N/A/VULN | Evidence |
|----|---------|----------------|----------|
| A / A0 | Stata | P | `test_A0_pretransferred_noDelta_reverts`; empty-supply residual not fully catalogued |
| A / A0 | Loop | G / **VULN** path | no A0 test; In credits claimed with no delta |
| B | both | P | Aave rates; Loop uses live V3/V4 rates (`_currentNetCarry`) |
| C | both | G | no hostile-share suite found |
| D | both | N/A | no bond NFT |
| E / E6 | Stata | **VULN** (commons) | Out `_secureSelfBurn` — `SEC-COMMON-002` |
| E / E6 | Loop | G | Out no refund helper; burn-from-this |
| F / F5 | Loop | P / **VULN** (bounded) | permissionless `rebalance`/`forceRepay`; interval 1h; placeholder constants |
| G | both | N/A | not nested DETF |
| H | Stata | P | route H in coverage; Loop all-or-revert Out |
| I1–I3 | Stata | F (unit) | `test_I1_pretransferred_stataInventoryNoInCallTransfer_revertsDelta0` |
| I1–I3 | Loop | **VULN** | In: `if (!pretransferred) transferFrom` then always `valueUsd(..., amountIn)` |
| J1–J3 | Stata | F | `test_J1/J2/J3_*` in SecurePull adversarial |
| J1–J3 | Loop | P | In/Out/Rebalance have `facetFuncs`; **no** proxy J suite; Rebalance `facetInterfaces` empty |
| K | Stata | P | reserve sync after routes |
| K | Loop | **VULN** | claimed amount, not observed inbound |
| L1–L3 | Loop | P | lending books vs balances; oracle spot |
| M | both | N/A | no user `target+calldata` |
| N | Stata | P | preview vs exec notes in coverage |
| N | Loop | G | In uses claimed `amountIn` after optional skip |
| O | both | P | Permit2 init on Loop DFPkg; not hunted as money default |

## 5. Domain notes

Walked: general, precision-math (share mint vs NAV), erc20, erc4626 (Stata wrap), defi-lending (loop HF / carry), proxies (facetFuncs present), access-control (permissionless rebalance), oracles (Aave oracles on Loop), flashloans (Loop CAP), dos (rebalance interval). CROPS: Loop instance is a vault (not DETF unowned law); leftover manager disable not re-scored here (`S-crops-trust`).

## 6. Findings

### 6.1 [SEC-SE-AAVE-001] CrossVersion Loop `exchangeIn` credits claimed with no inbound delta

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-AAVE-001` |
| **Title** | Delta-gate Loop `exchangeIn` — stop skip-transfer free mint |
| **Severity** | **High** (`RUNTIME_UNPROVEN`; would be Critical if forge proved free shares) |
| **Class** | **CODE** |
| **Confidence** | static-high |
| **Catalog IDs** | I1–I3, K1, A0 |
| **Pattern IDs** | **PAT-I-ABS**, PAT-K-DONATE, PAT-A0-EMPTY |
| **EVM-audit domain** | erc4626 / defi-lending |
| **CROPS pillar** | n/a |
| **Incident theme** | first-deposit inflation / donation credit |
| **Products** | AaveCrossVersionLoop |
| **Blast radius** | single package; every Loop instance |
| **Attacker** | **EXT** (vault already holds tokenA) or **CAP** |
| **Attack scenario** | 1. Vault holds tokenA (seed, donation, leftover). 2. Attacker calls `exchangeIn(tokenA, amountIn, vaultShare, 0, attacker, true, deadline)` with **no** `transferFrom`. 3. Branch skips pull. 4. `depositValue = valueUsd(..., amountIn)` uses **claimed**. 5. `depositLoopAFirst` spends **vault inventory**. 6. Attacker is minted shares. |
| **Preconditions** | Live Loop with tokenA inventory ≥ `amountIn` (or A0 empty + donation). |
| **Impact** | Free `vaultShare` minted against existing loop inventory / NAV. |
| **Evidence** | `AaveCrossVersionLoopExchangeInTarget.sol` ~56–74: `if (!pretransferred) { tokenIn.transferFrom(...) }` then `valueUsd(m, tokenIn, amountIn)` + mint. |
| **Runtime** | not run (L-SEC-3 → High + RUNTIME_UNPROVEN). No `repro/` yet. |
| **Recommended CODE** | Measure `U` / same-tx delta; credit `min(claimed, observed)`; short → typed revert (`TransferDeltaInsufficient`). Do not `depositLoop` on unpaid `amountIn`. |
| **Recommended TEST** | `test_I1_loop_pretransferred_noTransfer_existingInventory_reverts`; setup: seed tokenA on proxy; `pretransferred=true`; no transfer; expect revert; shares/NAV unchanged. `forge test --match-path 'test/**/aave/cross-version/**' --match-test 'test_I'`. |
| **Anti-theater** | I1 must not transfer tokens; must call **proxy**; no `mockCall` on Loop. |
| **Suggested WP-ID** | `WP-SEC-I-AAVE-LOOP-001` |
| **Link TCA / prior** | `TCA-SE-UAB` CrossVersion clone notes; **not** in `WP-I-CLONE-UAB-001` file list (that WP is v3.6 + Uni V4). TEST overlap `WP-I-SE-UAB-001`. |
| **Depends / parallel** | Parallel with Stata-owned WPs; serial with any Loop Out CODE in same files. |

### 6.2 [SEC-SE-AAVE-002] Loop `exchangeOut` burns `address(this)` shares without inbound delta

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-AAVE-002` |
| **Title** | Do not burn vault-held shares on Loop Out `pretransferred` without credit |
| **Severity** | **High** |
| **Class** | **CODE** |
| **Confidence** | static-high |
| **Catalog IDs** | I1, E6 |
| **Pattern IDs** | PAT-I-ABS, PAT-E6-REFUND |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | none |
| **Products** | AaveCrossVersionLoop |
| **Blast radius** | same package as 001 |
| **Attacker** | **EXT** if vault holds its own shares (donation / fee / leftover) |
| **Attack scenario** | 1. Vault holds its `vaultShare`. 2. Attacker `exchangeOut(..., pretransferred=true)`. 3. `_burn(address(this), amountIn)` consumes inventory shares. 4. `withdrawA` + `transfer` pays attacker tokenA. |
| **Preconditions** | Self-held share balance ≥ `amountIn`. |
| **Impact** | Extract loop tokenA against donated/inventory shares. |
| **Evidence** | `AaveCrossVersionLoopExchangeOutTarget.sol` ~75–78. |
| **Runtime** | RUNTIME_UNPROVEN |
| **Recommended CODE** | Pull/burn only caller shares, or require inbound share delta before burning `address(this)`. |
| **Recommended TEST** | `test_I1_loop_out_pretransferred_noShareTransfer_reverts`. |
| **Anti-theater** | Do not transfer shares in-call. |
| **Suggested WP-ID** | `WP-SEC-I-AAVE-LOOP-001` (same tree) |
| **Link TCA / prior** | none CODE WP |
| **Depends / parallel** | same WP as 001 |

### 6.3 [SEC-SE-AAVE-003] Loop missing I1–I3 / J proxy suite

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-AAVE-003` |
| **Title** | Add Loop I1–I3 + J1–J3 on production proxy |
| **Severity** | **High** |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | static-high |
| **Catalog IDs** | I, J |
| **Pattern IDs** | PAT-THEATER-PRE, PAT-THEATER-FACET |
| **EVM-audit domain** | proxies |
| **Products** | AaveCrossVersionLoop |
| **Blast radius** | tests only |
| **Attacker** | n/a (TEST) |
| **Attack scenario** | n/a |
| **Preconditions** | n/a |
| **Impact** | no proof Loop In/Out/Rebalance selectors are on proxy; no I negatives |
| **Evidence** | `rg test_I1_ test/foundry/spec/protocol/lending/aave/cross-version` → 0 hits |
| **Recommended TEST** | as `WP-I-SE-UAB-001` / `WP-J-SE-UAB-001` (extend to Loop files) |
| **Anti-theater** | J3 on proxy |
| **Suggested WP-ID** | — |
| **Link TCA / prior** | `WP-I-SE-UAB-001`, `WP-J-SE-UAB-001` |
| **Depends / parallel** | after CODE 001 |

### 6.4 [SEC-SE-AAVE-004] Stata Out `_secureSelfBurn` leftover sweep

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-AAVE-004` |
| **Title** | Stata Out inherits commons self-burn E6 |
| **Severity** | **High** |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | static-high |
| **Catalog IDs** | E6, I1 |
| **Pattern IDs** | PAT-E6-REFUND |
| **EVM-audit domain** | erc20 |
| **Products** | AaveV3StataStandardExchange |
| **Blast radius** | commons + all self-burn callers |
| **Evidence** | `AaveV3StataStandardExchangeOutTarget.sol` ~104–105 |
| **Suggested WP-ID** | — |
| **Link TCA / prior** | `SEC-COMMON-002` / `WP-SEC-E6-COMMON-001` |
| **Depends / parallel** | Wave 0 commons |

### 6.5 Medium cluster

- **SEC-SE-AAVE-005** Medium CODE/NEEDS_OWNER: Loop `rebalance`/`forceRepay` permissionless with **placeholder** `MIN_SPREAD=0`, `HF_SAFETY_FLOOR=1.05e18` (F5). Product plan says fee-oracle later.
- **SEC-SE-AAVE-006** Medium TEST: Stata remaining ADV catalog (C/H) — `WP-ADV-SE-UAB-001`.
- **SEC-SE-AAVE-007** Info: Stata In PAT-I-ABS **closed** in production at this SHA.

## 7. Theater / false confidence

| Test / control | Why it cannot catch the bug | Fix |
|----------------|-----------------------------|-----|
| Coverage-audit “Stata skips pull” | Code now uses `_secureTokenTransfer` | Treat TCA-SE-UAB-002 as historical |
| Happy `pretransferred=true` with real transfer | Not I1 | Keep existing I1 on Stata; add Loop I1 with **zero** transfer |
| Loop H deposit/out e2e | Never sets `pretransferred=true` without funding | I1/I2 |

## 8. Coverage-audit linkage

| TCA / WP | Same touch-set? | Action |
|----------|-----------------|--------|
| `WP-I-CLONE-UAB-001` / `TCA-SE-UAB-002` | Stata In pull **was** this set; body now delta | **OWNED_ELSEWHERE** (closed CODE); do not `sec_fix_*` Stata In |
| `WP-I-SE-UAB-001` | Loop + Stata I tests | **OWNED_ELSEWHERE** TEST |
| `WP-J-SE-UAB-001` | Stata J landed in SecurePull adversarial; Loop J still open in that WP | **OWNED_ELSEWHERE** |
| `WP-ADV-SE-UAB-001` | Stata ADV | **OWNED_ELSEWHERE** |
| none | Loop In/Out production files | **new** `WP-SEC-I-AAVE-LOOP-001` |

## 9. Work package stubs

### WP-SEC-I-AAVE-LOOP-001 — Delta-safe CrossVersion Loop In/Out

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-I-AAVE-LOOP-001` |
| **Title** | Credit/burn Loop only against observed inbound delta |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | AaveCrossVersionLoop |
| **Finding IDs** | SEC-SE-AAVE-001, SEC-SE-AAVE-002 |
| **Problem** | `pretransferred=true` skips `transferFrom` and still values `amountIn`; Out burns `address(this)` shares. Free mint / inventory extract. |
| **Production files (touch set)** | `contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeInTarget.sol`; `…/AaveCrossVersionLoopExchangeOutTarget.sol` (optional shared helper) |
| **Test files (touch set)** | new `test/foundry/spec/protocol/lending/aave/cross-version/adversarial/*I*.t.sol` |
| **Out of scope files** | `aave/v3.6/**`; Uni V4 SE; `BasicVaultCommon.sol` |
| **Depends on** | none |
| **Parallelizable with** | `WP-SEC-E6-COMMON-001`, LST WPs, hook WPs |
| **Conflicts with coverage-audit WP** | none on these two files. TEST overlap `WP-I-SE-UAB-001` — implement I tests in that WP **or** here, not both. Prefer this tree for CODE+I on Loop only. |
| **Suggested worktree** | `sec_fix_aave-loop-i` / `sec_fix/aave-loop-i` |
| **Implementation notes** | Match ERC4626 / commons reserve-delta. Registry deploy. No `via_ir`. |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/protocol/lending/aave/cross-version/**' --match-test 'test_I1_\|test_I2_\|test_I3_' -vv` — I1 no transfer, existing inventory, revert, no mint |
| **Anti-theater checks** | I1 no transfer; proxy; no mock Loop |
| **Proof-first?** | **yes** (finding was RUNTIME_UNPROVEN) |
| **Estimate** | M |

## 10. Deferred / N/A / NEEDS_OWNER / ACCEPTED_RISK

| Item | Class |
|------|-------|
| Permissionless rebalance as product law | ACCEPTED_RISK **if** bounded + oracle-sourced thresholds; today placeholders → NEEDS_OWNER (`SEC-SE-AAVE-005`) |
| FoT on Aave a/Stata | N/A (standard Aave tokens) |
| Bond/claim D* | N/A |
| Stata In PAT-I-ABS | closed; OWNED_ELSEWHERE historical |

## 11. Commands run

```text
rg pretransferred|_securePull|_secureTokenTransfer contracts/protocols/lending/aave --glob '*.sol'
rg test_I1_|test_J test/foundry/spec/protocol/lending/aave
read AaveCrossVersionLoopExchange{In,Out}Target.sol
read AaveV3StataStandardExchange{In,Out}Target.sol
read AaveCrossVersionLoopRebalanceTarget.sol
# no forge this area (static High)
```
