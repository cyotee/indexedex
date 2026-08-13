# Security Audit — A-se-morpho-erc4626

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` (`1e0d7c48eff8a883837996ae700426ac5397924b`) |
| Agent / run | Stage 1 product-area · MODE=full · `A-se-morpho-erc4626` (orchestrator) |
| Status | **COMPLETE** |
| Production paths | `contracts/vaults/standard/erc4626/**` |
| Test paths | `test/foundry/spec/vaults/standard/erc4626/**`; `contracts/test/bases/TestBase_ERC4626StandardExchange.sol`; `TestBase_ERC4626MorphoHermetic.sol` |
| Skills cited | SECURITY_AUDIT_PRD §2–8, §19; crane-adversarial-testing; indexedex-testing; ethskills-security |
| Residual-risk scores | ERC4626 Standard Exchange → **3**; Morpho (no DFPkg) → **3** (same SUT + hermetic TestBase) |

## 1. Executive summary

- **No dedicated Morpho DFPkg** exists. Morpho is a **TestBase consumer** of `ERC4626StandardExchange` (`TestBase_ERC4626MorphoHermetic.sol`). Owning SUT is the generic ERC-4626 SE package.
- `_securePull` is **durable reserve-delta** (`U = B − R`; `TransferDeltaInsufficient`) — gold peer cited by coverage-audit. PAT-I-ABS **not live**.
- **Critical 0. High 2 TEST:** no real I1–I3 (`test_I1_unwrapExactIn_previewEqualsExecution` is **N2 theater**); no J1–J3 suite found.
- **OWNED_ELSEWHERE:** none for this tree’s I/J. Commons E6 self-burn **not** used here (own `_securePull` + exact-out refund law D38).
- **Top WPs:** `WP-SEC-I-ERC4626-001`, `WP-SEC-J-ERC4626-001`.

## 2. Product inventory

| Product | DFPkg / Targets | TestBase | Deploy path | Residual risk |
|---------|-----------------|----------|-------------|--------------:|
| **ERC4626StandardExchange** | `ERC4626StandardExchangeDFPkg`; In/Out/Marker Facets+Targets; Common | `TestBase_ERC4626StandardExchange`; Morpho hermetic TestBase | CREATE3 + `indexedexManager` registry | **3** |
| **Morpho MetaMorpho / ERC4626 vault as protocolVault** | none (config of above) | `TestBase_ERC4626MorphoHermetic` | same DFPkg + Morpho vault address in PkgArgs | **3** |

## 3. Threat models

| Actor | Surface | Asset | Trust flags | Admin | Worst case |
|-------|---------|-------|-------------|-------|------------|
| EXT | `exchangeIn`/`Out` | underlying / `protocolVault` shares / SE `vaultShare` | `pretransferred` | fee oracle | free mint if U ignored — **blocked** |
| HOS | hostile ERC4626 as `protocolVault` | vault shares | PkgArgs | — | inflation / donation (A0/K) if vault is hostile |
| INT | Morpho curator / allocator | underlying | — | Morpho roles | freeze / bad market (CROPS Info on Morpho, not IX admin) |
| CFG | PkgArgs `protocolVault` | — | — | deployer | mis-set vault |

## 4. Catalog matrix (A–O, E6, F5)

| ID | Mark | Evidence |
|----|------|----------|
| A0 | G | no empty-supply residual catalog test found |
| B | P | ERC4626 convert; Morpho market rates off-package |
| C | P | `ReentrancyLockModifiers` on In/Out |
| D | N/A | |
| E / E6 | P | exact-out “consume only amountIn, refund surplus” (D38); `_refundExcess` on pull overshoot |
| F / F5 | N/A | no permissionless migrate |
| G | N/A | |
| H | P | route suite exists |
| I1–I3 | G | only misnamed `test_I1_unwrapExactIn_previewEqualsExecution` (preview≡exec) |
| J1–J3 | G | Facets exist; no `test_J` |
| K | P | `_syncAllExpectedHoldReserves` after routes |
| L | N/A / P | not an AMM; Morpho market L off-package |
| M | N/A | |
| N | P / theater | preview tests exist; I1 name collision |
| O | P | permit possible via ERC20 |

## 5. Domain notes

Walked: general, precision-math, erc20, erc4626, proxies, access-control, dos. Morpho architecture is **integration** (underlying vault), not a ported Morpho Blue singleton.

## 6. Findings

### 6.1 [SEC-SE-4626-001] I1 name is preview-equality theater

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-4626-001` |
| **Title** | Replace misnamed I1 with real pretransfer I1–I3 |
| **Severity** | **High** |
| **Class** | **TEST** / **THEATER** |
| **Confidence** | static-high |
| **Catalog IDs** | I1–I3, N2 |
| **Pattern IDs** | PAT-THEATER-PRE |
| **EVM-audit domain** | erc4626 |
| **CROPS pillar** | n/a |
| **Incident theme** | none |
| **Products** | ERC4626StandardExchange (incl. Morpho hermetic) |
| **Blast radius** | one package |
| **Attacker** | n/a |
| **Attack scenario** | Production pull is reserve-delta (`ERC4626StandardExchangeCommon.sol` ~164–194). Tests never assert I1 (no transfer + booked `R==B`). The function named `test_I1_unwrapExactIn_previewEqualsExecution` cannot fail if PAT-I-ABS is re-introduced. |
| **Preconditions** | n/a |
| **Impact** | false confidence; helper regression possible |
| **Evidence** | `test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol:264` |
| **Recommended TEST** | `test_I1_pretransferred_noTransfer_bookedReserve_reverts`; I2 short; I3 residual. Morpho hermetic should inherit one I1. |
| **Anti-theater** | I1 no transfer; do not rename preview tests as I1 |
| **Suggested WP-ID** | `WP-SEC-I-ERC4626-001` |
| **Link TCA / prior** | none |
| **Depends / parallel** | parallel J |

### 6.2 [SEC-SE-4626-002] Missing J1–J3

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-4626-002` |
| **Title** | ERC4626 SE J1–J3 proxy surface |
| **Severity** | **High** |
| **Class** | **TEST** |
| **Confidence** | static-medium |
| **Catalog IDs** | J1–J3 |
| **Pattern IDs** | PAT-THEATER-FACET |
| **EVM-audit domain** | proxies |
| **Products** | ERC4626StandardExchange |
| **Blast radius** | one DFPkg |
| **Attacker** | n/a |
| **Attack scenario** | omitted selector → money API missing on proxy |
| **Impact** | silent missing route |
| **Evidence** | no `test_J` under `test/**/erc4626` |
| **Recommended TEST** | J1–J3 on In+Out+Marker |
| **Anti-theater** | J3 proxy |
| **Suggested WP-ID** | `WP-SEC-J-ERC4626-001` |
| **Link TCA / prior** | none |
| **Depends / parallel** | fold with I WP (L-SEC-13) |

## 7. Theater / false confidence

| Test / control | Why it cannot catch the bug | Fix |
|----------------|-----------------------------|-----|
| `test_I1_unwrapExactIn_previewEqualsExecution` | N2, not I1 | rename; add real I1 |

## 8. Coverage-audit linkage

| TCA / WP | Same touch-set? | Action |
|----------|-----------------|--------|
| commons “ERC4626 good pattern” | helper cited as gold | no CODE WP |
| `WP-I-CLONE-001` | not this helper | none |

## 9. Work package stubs

### WP-SEC-I-ERC4626-001 (+ fold J)

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-I-ERC4626-001` |
| **Title** | Real I1–I3 + J1–J3 on ERC4626 SE (Morpho hermetic inherits) |
| **Severity** | High |
| **Class** | TEST |
| **Products** | ERC4626StandardExchange |
| **Finding IDs** | SEC-SE-4626-001, SEC-SE-4626-002 |
| **Problem** | Theater I1 name; no J. |
| **Production files (touch set)** | none |
| **Test files (touch set)** | `test/foundry/spec/vaults/standard/erc4626/**` |
| **Out of scope files** | Aave Stata; Morpho Blue port in Crane |
| **Depends on** | none |
| **Parallelizable with** | LST I/J, Loop CODE |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_erc4626-ij` / `sec_fix/erc4626-ij` |
| **Implementation notes** | Use Morpho hermetic as one I1 environment if warm. No `via_ir`. |
| **Acceptance** | `--match-path 'test/foundry/spec/vaults/standard/erc4626/**' --match-test 'test_I1_\|test_I2_\|test_I3_\|test_J'` |
| **Anti-theater checks** | I1 no transfer; J3 proxy; preview test not named I1 |
| **Proof-first?** | no |
| **Estimate** | S |

`WP-SEC-J-ERC4626-001` folds into the same tree.

## 10. Deferred / N/A / NEEDS_OWNER / ACCEPTED_RISK

| Item | Class |
|------|-------|
| Morpho curator / market risk | ACCEPTED_RISK / CROPS Info (external) |
| Hostile `protocolVault` in PkgArgs | CFG / sharp-edges — Medium |
| M/F5 | N/A |

## 11. Commands run

```text
read ERC4626StandardExchangeCommon.sol ~164-194
read ERC4626StandardExchange{In,Out}Target.sol headers
rg test_I1_|test_J test/foundry/spec/vaults/standard/erc4626
ls contracts/vaults/standard/erc4626
# Morpho: only TestBase_ERC4626MorphoHermetic.sol
```
