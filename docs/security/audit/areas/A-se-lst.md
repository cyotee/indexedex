# Security Audit — A-se-lst

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` (`1e0d7c48eff8a883837996ae700426ac5397924b`) |
| Agent / run | Stage 1 product-area · MODE=full · `A-se-lst` (orchestrator) |
| Status | **COMPLETE** |
| Production paths | `contracts/protocols/staking/{lido,etherfi,rocket-pool}/**` |
| Test paths | `test/foundry/spec/protocol/staking/{lido,etherfi,rocket-pool}/**`; `test/foundry/fork/eth_main/vaults/staking/**`; co-located hermetic TestBases |
| Skills cited | SECURITY_AUDIT_PRD §2–8, §19; crane-adversarial-testing; indexedex-adversarial-testing; indexedex-testing; ethskills-security; defi-incident-patterns |
| Residual-risk scores | Lido wstETH SE → **3**; EtherFi weETH SE → **3**; Rocket rETH SE → **3** |

## 1. Executive summary

- Three LST Standard Exchange packages share the **same-tx inbound-delta** `_securePull` (not durable `U = B − R`). I1 two-tx (inventory sitting, no in-call push) **reverts** (`actualIn == 0`). That is I1-safe for the classic PAT-I-ABS class.
- **Critical 0. High 2 TEST** this program owns: missing catalog-named `test_I1/I2/I3` (only `test_A0_pretransferred_*` exists) and missing J1–J3 proxy suites. **No new CODE** on pull bodies.
- Rebase/share weirdness (stETH vs wstETH, weETH, rETH) is product-accepted if routes only wrap/unwrap official LST tokens — **ACCEPTED_RISK** with “no raw rebasing stETH as `rateAsset`” invariant (verify per package).
- **OWNED_ELSEWHERE:** none (coverage UAB / clone WPs do not list these trees).
- **Top WPs:** `WP-SEC-I-LST-001` (I1–I3 named suite on all three proxies); `WP-SEC-J-LST-001` (J1–J3).

## 2. Product inventory

| Product | DFPkg / Targets | TestBase | Deploy path | Residual risk |
|---------|-----------------|----------|-------------|--------------:|
| **LidoWstETHStandardExchange** | `LidoWstETHStandardExchangeDFPkg`; In/Out/Marker/Rebalance Facets | `TestBase_Lido*`; `Adversarial_LidoWstETH_P0.t.sol` | CREATE3 + manager registry | **3** |
| **EtherFiWeETHStandardExchange** | `EtherFiWeETHStandardExchangeDFPkg`; In/Out | `Adversarial_EtherFiWeETH_P0.t.sol` | same | **3** |
| **RocketPoolRETHStandardExchange** | `RocketPoolRETHStandardExchangeDFPkg`; In/Out | `Adversarial_RocketPoolRETH_P0.t.sol` | same | **3** |

## 3. Threat models

| Actor | Surface | Asset | Trust flags | Admin | Worst case |
|-------|---------|-------|-------------|-------|------------|
| EXT | `exchangeIn`/`Out` | ETH/wstETH/weETH/rETH ↔ `vaultShare` | `pretransferred` | fee oracle | free mint if pull were absolute — **blocked** (same-tx delta=0) |
| EXT two-tx | pretransfer then later call | same | `pretransferred=true` | — | reverts (no in-window delta) — **cannot** credit booked inventory |
| HOS | rebase token as configured asset | LST | — | protocol pause | accounting drift if raw stETH used (policy) |
| CAP | rate via LST protocol | — | — | Lido/EF/RP oracles | B/L3 bounded |

## 4. Catalog matrix (A–O, E6, F5)

| ID | Products | Mark | Evidence |
|----|----------|------|----------|
| A0 | all three | P | `test_A0_pretransferredTrue_noBalanceDelta_revertsAndNoMint` (Lido/EF); Rocket `test_A0_pretransferred_noDelta` |
| B / L3 | all | P | protocol rates; no SE spot AMM |
| C | all | G | no hostile-share suite |
| D | all | N/A | no bond |
| E / E6 | all | P | pull refunds overshoot by capping credit; no `max−used` entire-balance refund found on LST Out |
| F / F5 | Lido | P | Rebalance facet exists — permissionless structural? cite as P (not Loop-class) |
| G | all | N/A | |
| H | all | P | P0 adversarial files exist |
| I1–I3 | all | P | A0 covers empty-delta; **no** named I2/I3; I1 two-tx not separately named |
| J1–J3 | all | G | `facetFuncs` present on Lido In (preview, exchangeIn, exchangeInEth); **no** `test_J*` |
| K | all | P | same-tx delta does not credit prior donation |
| L2 | all | N/A | FoT not claimed; LST wrap tokens |
| M / O | all | N/A / P | no arbitrary call; Permit2 may be inited — not default money path |
| N | all | P | preview exists |

## 5. Domain notes

Walked: general, precision-math, erc20, erc4626-like wrap, defi-staking (rebase), proxies, access-control, dos. Token-weird specialist should re-hit raw stETH / weETH share math.

## 6. Findings

### 6.1 [SEC-SE-LST-001] No catalog I1–I3 suite (A0-only)

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-LST-001` |
| **Title** | Add I1–I3 named tests on Lido / EtherFi / Rocket proxies |
| **Severity** | **High** |
| **Class** | **TEST** |
| **Confidence** | static-high |
| **Catalog IDs** | I1–I3 |
| **Pattern IDs** | PAT-THEATER-PRE |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | none |
| **Products** | Lido / EtherFi / Rocket SE |
| **Blast radius** | three packages (same helper shape) |
| **Attacker** | EXT (proof gap, not live CODE) |
| **Attack scenario** | Reviewer cannot prove I2 short-delivery / I3 residual reuse from existing names. Production helper: `actualIn = balAfter−balBefore`; `pretransferred && actualIn < amountIn` → `InsufficientDeposit`. |
| **Preconditions** | n/a |
| **Impact** | Ship-gate I incomplete; regression risk if helper is later changed |
| **Evidence** | `rg test_I1_ test/foundry/spec/protocol/staking` → 0. A0 tests exist. Helper `LidoWstETHStandardExchangeCommon.sol` ~286–304 (peers copy). |
| **Runtime** | n/a (TEST) |
| **Recommended CODE** | none |
| **Recommended TEST** | `test_I1_*` inventory sitting + no transfer; `test_I2_*` short push; `test_I3_*` leftover reuse. Match-path each staking tree `--match-test 'test_I'`. |
| **Anti-theater** | I1 no transfer; proxy; no mock LST protocol for I |
| **Suggested WP-ID** | `WP-SEC-I-LST-001` |
| **Link TCA / prior** | none |
| **Depends / parallel** | parallel with `WP-SEC-J-LST-001` |

### 6.2 [SEC-SE-LST-002] Missing J1–J3 proxy surface

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-LST-002` |
| **Title** | Prove Target ⊆ facetFuncs ⊆ loupe ⊆ proxy for three LST SE |
| **Severity** | **High** |
| **Class** | **TEST** (CODE only if PAT-J-OMIT found during WP) |
| **Confidence** | static-medium |
| **Catalog IDs** | J1–J3 |
| **Pattern IDs** | PAT-THEATER-FACET |
| **EVM-audit domain** | proxies |
| **Products** | Lido / EtherFi / Rocket SE |
| **Blast radius** | three DFPkgs |
| **Attacker** | n/a |
| **Attack scenario** | Silent missing money selector on proxy (J). Lido In `facetFuncs` lists 3 selectors including `exchangeInEth` — must appear on Target + cuts + loupe. |
| **Preconditions** | n/a |
| **Impact** | user cannot call a documented route on the diamond |
| **Evidence** | `LidoWstETHStandardExchangeInFacet.sol` ~18–23; no `test_J` under staking specs |
| **Recommended TEST** | `test_J1_facetFuncs_coversTargetApi`; `test_J2_proxyLoupe`; `test_J3_proxyCallable` per package |
| **Anti-theater** | J3 calls **proxy** |
| **Suggested WP-ID** | `WP-SEC-J-LST-001` |
| **Link TCA / prior** | none |
| **Depends / parallel** | parallel with I-LST |

### 6.3 Medium / ACCEPTED_RISK

- Same-tx (not durable reserve) pull: two-tx I1 is safe; same-tx donation+call can credit (N1) — Medium / document.
- Raw rebasing stETH as configured `rateAsset`: NEEDS_OWNER if PkgArgs allow it.

## 7. Theater / false confidence

| Test / control | Why it cannot catch the bug | Fix |
|----------------|-----------------------------|-----|
| `test_I1_unwrapExactIn_*` on ERC4626 (not this area) | n/a | — |
| A0 only | Does not name I2/I3 / residual reuse | `WP-SEC-I-LST-001` |
| Happy pretransfer with real transfer | Theater for I | I1 zero transfer |

## 8. Coverage-audit linkage

| TCA / WP | Same touch-set? | Action |
|----------|-----------------|--------|
| `WP-I-CLONE-001` | LST listed as same-tx delta **peers** in commons blast, not as PAT-I-ABS | no competing CODE |
| none | I/J TEST | **new** this program |

## 9. Work package stubs

### WP-SEC-I-LST-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-I-LST-001` |
| **Title** | Named I1–I3 on Lido / EtherFi / Rocket SE proxies |
| **Severity** | High |
| **Class** | TEST |
| **Products** | three LST SE |
| **Finding IDs** | SEC-SE-LST-001 |
| **Problem** | Only A0 empty-delta tests; ship-gate I incomplete. |
| **Production files (touch set)** | none unless helper regression |
| **Test files (touch set)** | `test/foundry/spec/protocol/staking/{lido,etherfi,rocket-pool}/adversarial/` |
| **Out of scope files** | Aave Loop; Uni V3; `BasicVaultCommon.sol` |
| **Depends on** | none |
| **Parallelizable with** | `WP-SEC-J-LST-001`, all other product I tests |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_lst-i` / `sec_fix/lst-i` |
| **Implementation notes** | Copy Stata `test_I1_pretransferred_*` shape. Gold TestBases. No `via_ir`. |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/protocol/staking/**' --match-test 'test_I1_\|test_I2_\|test_I3_' -vv` |
| **Anti-theater checks** | I1 no transfer |
| **Proof-first?** | no |
| **Estimate** | M |

### WP-SEC-J-LST-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-J-LST-001` |
| **Title** | J1–J3 proxy surface for three LST SE |
| **Severity** | High |
| **Class** | TEST |
| **Products** | three LST SE |
| **Finding IDs** | SEC-SE-LST-002 |
| **Problem** | No loupe/proxy smoke. |
| **Production files** | only if PAT-J-OMIT |
| **Test files** | same adversarial trees |
| **Out of scope files** | DETF J WPs |
| **Depends on** | none |
| **Parallelizable with** | `WP-SEC-I-LST-001` (same worktree OK per L-SEC-13) |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_lst-i` (fold) or `sec_fix_lst-j` |
| **Implementation notes** | Target-derived controls; J3 proxy |
| **Acceptance** | `--match-test 'test_J'` on staking paths |
| **Anti-theater checks** | J3 not facet impl |
| **Proof-first?** | no |
| **Estimate** | S |

## 10. Deferred / N/A / NEEDS_OWNER / ACCEPTED_RISK

| Item | Class |
|------|-------|
| Same-tx delta (not durable U) | ACCEPTED_RISK — I1 two-tx blocked; document |
| Raw rebasing stETH as asset | NEEDS_OWNER if PkgArgs allow |
| M/O | N/A no router calldata / default permit money path |

## 11. Commands run

```text
rg _securePull contracts/protocols/staking --glob '*.sol'
rg test_I1_|test_J test/foundry/spec/protocol/staking
read LidoWstETHStandardExchangeCommon.sol ~286-304
# no forge
```
