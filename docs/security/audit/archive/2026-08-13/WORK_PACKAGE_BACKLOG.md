# Work Package Backlog — Stage 1 Security Audit (pilot)

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` |
| Ranking | PRD §9 (severity × exploitability × blast × class) |
| Worktree prefix | `sec_fix_` (L-SEC-8) |
| Aggregate | [`AGGREGATE.md`](./AGGREGATE.md) |
| Sources | `areas/A-commons-pull.md`, `A-detf-multi-vault.md`, `A-se-amm-v2.md`; `specialists/S-sharp-edges.md`, `S-crops-trust.md` |

This file is the **primary Stage 2 handoff**. Do **not** schedule `sec_fix_*` for OWNED_ELSEWHERE rows.

---

## Finding → WP index (Critical/High)

| FINDING_ID | Class | WP (this program) | Notes |
|------------|-------|-------------------|--------|
| SEC-COMMON-001 | OWNED_ELSEWHERE | — | `TCA-COMMON-001` / `WP-I-COMMON-001` — I1 **closed** + 9/9 PASS |
| SEC-COMMON-002 | CODE High | `WP-SEC-E6-COMMON-001` | `_secureSelfBurn` sweep |
| SEC-COMMON-003 | OWNED_ELSEWHERE | — | Uni V3 clones → `WP-I-CLONE-001` / `A-se-v3-v4-lending` |
| SEC-SHARP-002 | CODE High | `WP-SEC-E6-COMMON-001` | `_refundExcess` max−used |
| SEC-SHARP-003 | CODE High | `WP-SEC-E6-COMMON-001` | same self-burn |
| SEC-SHARP-004 | CODE High | `WP-SEC-I-SE-4626-001` | LP-deposit exact-gap |
| SEC-SHARP-006 | CODE High | `WP-SEC-PKG-MV-001` | PkgArgs hostile share |
| SEC-SHARP-009 | Medium | fold `WP-SEC-A0-SE-001` | Aero offset 0 |
| SEC-SHARP-010/011 | OWNED_ELSEWHERE | — | I-ABS helper / MV pull |
| SEC-SE-AC-001 | CODE High | `WP-SEC-E6-SE-001` | SE Out call-sites |
| SEC-SE-CAM-001 | CODE High | `WP-SEC-CAM-OUT-001` | Camelot Out drop |
| SEC-SE-CAM-002 | CODE High | `WP-SEC-R4-SE-001` | Camelot Route4 |
| SEC-SE-U2-001 | CODE High | `WP-SEC-R4-SE-001` | Uni V2 Route4 |
| SEC-SE-AC-002 | CODE High | `WP-SEC-A0-SE-001` | zap-in A0 |
| SEC-SE-AC-003/004 | OWNED_ELSEWHERE | — | Uni V2 I/J/ADV tests |
| SEC-DETF-MV-001…006 | OWNED_ELSEWHERE | — | I/J/K/N/L3 coverage WPs |
| SEC-DETF-MV-007 | TEST High | `WP-SEC-DETF-MV-A0-001` | missing `test_A0_*` |
| SEC-CROPS-001 | CODE High | `WP-SEC-CROPS-001` | disable-on-exit (mostly full-pass families) |
| SEC-CROPS-002 | Medium | fold CROPS-001 | Uni V2 disable Out |

No Critical findings.

---

## OWNED_ELSEWHERE (do not `sec_fix_*`)

| SEC / note | Coverage IDs | Touch-set |
|------------|--------------|-----------|
| Token PAT-I-ABS helper | `TCA-COMMON-001`, `WP-I-COMMON-001`, `WP-I-COMMON-002` | `BasicVaultCommon._secureTokenTransfer` |
| MultiVault pull / I / J / K | `TCA-DETF-MV-001…006`, `WP-I-DETF-MV-001/002`, `WP-J-DETF-MV-001`, `WP-K-DETF-MV-001` | MultiVault Common/Targets IJK |
| SE I/J/ADV tests (esp. Uni V2) | `WP-I-SE-AC-001`, `WP-J-SE-AC-001`, `WP-ADV-SE-AC-001` | SE adversarial / J |
| Aero deadline | `WP-E5-AERO-001` | Aero In/Out deadline |
| Camelot H tests | `WP-H-CAM-001` | H matrix (not Route4 convert CODE) |
| Uni V3 absolute pull | `WP-I-CLONE-001` | Uni V3 In/Out helpers |
| FeeCollector pullFee tests | `WP-N-FEE-001` | collector |
| Manager/oracle J | `WP-J-MGR-001/002` | manager facets |

---

## Ranked WPs (this program)

### 1. WP-SEC-E6-COMMON-001 — Cap commons refunds / self-burn to this-call surplus

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-E6-COMMON-001` |
| **Title** | Fix `_refundExcess` + `_secureSelfBurn` to this-call unused inbound only |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | BasicVaultCommon; Aero/Camelot/Uni V2 / Aave Stata share-burn and exact-out |
| **Finding IDs** | SEC-COMMON-002, SEC-SHARP-002, SEC-SHARP-003 |
| **Problem** | Token pull is reserve-delta; refund still pays `max−used` and self-burn sweeps **all** leftover vault shares. `pretransferred=true` + fat max / sitting shares skims booked pair tokens or donated `vaultShare`. |
| **Production files (touch set)** | `contracts/vaults/basic/BasicVaultCommon.sol` |
| **Test files (touch set)** | `test/foundry/spec/vaults/basic/**` (`test_E6_*`, `test_I1_secureSelfBurn_*`) |
| **Out of scope files** | SE Out Targets (call-site WP); Uni V3 clones; MultiVault DFPkg |
| **Depends on** | none. Confirm `gap_cover_i-common` idle. |
| **Parallelizable with** | `WP-SEC-CAM-OUT-001`, `WP-SEC-PKG-MV-001`, `WP-SEC-DETF-MV-A0-001` |
| **Conflicts with coverage-audit WP** | Same file as **closed** `WP-I-COMMON-001`. Serialize. Do not reopen I-ABS body. |
| **Suggested worktree** | `sec_fix_e6-common` / `sec_fix/e6-common` |
| **Implementation notes** | Snapshot `U` before consume; refund `min(max−used, U−used)` or credit max then refund. Self-burn: refund inbound−burn only. L-RSRV-ABSORB. Skills: crane-adversarial E6. Never `via_ir`. |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/vaults/basic/**' --match-test 'test_E6_|test_I1_|test_I2_|test_I3_' -vv` — new E6/I1 self-burn fail pre-fix / pass post-fix; existing token I1 stay green |
| **Anti-theater checks** | No in-call transfer of `max`; booked `R` must not fall due to refund; second user’s sitting shares stay |
| **Proof-first?** | **yes** |
| **Wave** | **0** |
| **Estimate** | M |

### 2. WP-SEC-CAM-OUT-001 — Camelot Out swap pays recipient

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-CAM-OUT-001` |
| **Title** | Camelot `exchangeOut` swap: pay recipient; do not overwrite `amountIn` |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Camelot V2 SE |
| **Finding IDs** | SEC-SE-CAM-001 |
| **Problem** | Out swap leaves `tokenOut` on the vault and uses `amountOut` as refund `used`. Honest users lose output; E6 math is unbounded. |
| **Production files (touch set)** | `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol` |
| **Test files (touch set)** | `test/foundry/spec/protocol/dexes/camelot/v2/CamelotV2StandardExchangeOut_Swap.t.sol` |
| **Out of scope files** | `BasicVaultCommon.sol`; Aero/Uni V2 Out |
| **Depends on** | none |
| **Parallelizable with** | `WP-SEC-E6-COMMON-001`, `WP-SEC-PKG-MV-001`, R4 on **In** files |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_cam-out` / `sec_fix/cam-out` |
| **Implementation notes** | Mirror Camelot In swap `safeTransfer(recipient, amountOut)`. Separate `usedIn` vs `out` locals. Gold TestBase. |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/protocol/dexes/camelot/v2/**' --match-test 'test_exchangeOut_swap'` — recipient `tokenOut` delta ≥ `amountOut` |
| **Anti-theater checks** | Proxy call; assert balances, not only return value |
| **Proof-first?** | yes |
| **Wave** | **1** |
| **Estimate** | S |

### 3. WP-SEC-E6-SE-001 — SE Out call-sites refund this-call surplus only

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-E6-SE-001` |
| **Title** | SE `exchangeOut`: refund only this-call prepaid surplus |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Aerodrome, Camelot, Uni V2 SE |
| **Finding IDs** | SEC-SE-AC-001 |
| **Problem** | Call-sites credit `used` then refund `maxAmountIn − used`, skimming booked pair inventory. |
| **Production files (touch set)** | `AerodromeStandardExchangeOutExecuteTarget.sol`; `CamelotV2StandardExchangeOutTarget.sol`; `UniswapV2StandardExchangeOutTarget.sol` — **not** `BasicVaultCommon.sol` unless helper API must change |
| **Test files (touch set)** | SE adversarial `test_E6_*` + per-protocol Out files |
| **Out of scope files** | Commons pull body; DETF; Uni V3/V4 SE |
| **Depends on** | Prefer Wave 0 commons helper freeze; **serial** after `WP-SEC-CAM-OUT-001` on Camelot Out file |
| **Parallelizable with** | Aero Out + Uni V2 Out after Camelot Out merge (or one agent all three) |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_e6-se` (or `sec_fix_e6-aero` + `sec_fix_e6-u2` per L-SEC-13) |
| **Implementation notes** | Prefer credit `maxAmountIn` then spend `used`. L-CLAIM-3: no exact-U lock. |
| **Acceptance** | `forge test --match-test 'test_E6_'` — inflated max + transfer(used) ⇒ no pair-token inventory loss |
| **Anti-theater checks** | Do not transfer EXTRA in I1-style case |
| **Proof-first?** | yes |
| **Wave** | **1** (after 0 / CAM-OUT) |
| **Estimate** | M |

### 4. WP-SEC-R4-SE-001 — Route4 convert against pre-deposit reserve

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-R4-SE-001` |
| **Title** | Route4 convert against pre-deposit reserve (Camelot + Uni V2) |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Camelot V2 SE, Uniswap V2 SE |
| **Finding IDs** | SEC-SE-CAM-002, SEC-SE-U2-001 |
| **Problem** | Post-deposit reserve in `convertToShares` under-mints later depositors. Camelot preview still pre-deposit (N2 theater). |
| **Production files (touch set)** | `CamelotV2StandardExchangeInTarget.sol`; `UniswapV2StandardExchangeInTarget.sol` |
| **Test files (touch set)** | `*StandardExchangeIn_VaultDeposit.t.sol` |
| **Out of scope files** | Aero In (already correct); Out Targets |
| **Depends on** | none |
| **Parallelizable with** | CAM-OUT, E6 Out, PKG-MV. **Serial** with `WP-SEC-A0-SE-001` on these In files. |
| **Conflicts with coverage-audit WP** | Soft: `WP-H-CAM-001` test asserts may need update — this tree may edit that test file |
| **Suggested worktree** | `sec_fix_r4-cam` + `sec_fix_r4-u2` (L-SEC-13) or one `sec_fix_r4-se` if sequential |
| **Implementation notes** | Copy Aero snapshot `vs.vaultLpReserve`. Remove Uni V2 preview `reserveAfter` hack. |
| **Acceptance** | VaultDeposit tests: `assertEq(exec, preview)`; large-D case no 2% slack |
| **Anti-theater checks** | D ≈ existing LP; no 2% bound |
| **Proof-first?** | no |
| **Wave** | **1** |
| **Estimate** | M |

### 5. WP-SEC-A0-SE-001 — Zap-in / empty mint cannot absorb donated LP

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-A0-SE-001` |
| **Title** | Block zap-in/empty mint from unbooked LP; Aero offset parity |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Aerodrome, Camelot, Uni V2 SE |
| **Finding IDs** | SEC-SE-AC-002, SEC-SHARP-009 |
| **Problem** | Zap-in deposit snapshots lastTotal then sets lastTotal to live LP (includes donation). First redeem drains D. Aero `decimalOffset=0`. |
| **Production files (touch set)** | Aero/Camelot/Uni V2 In Targets (zap-in deposit); `AerodromeStandardExchangeDFPkg.sol` offset |
| **Test files (touch set)** | SE adversarial `test_A0_*` |
| **Out of scope files** | Crane `ERC4626Service.sol` unless wrapper added in IndexedEx |
| **Depends on** | **Serial** with R4 on Camelot/Uni V2 In Targets |
| **Parallelizable with** | Aero-only offset hunk vs Camelot Out |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_a0-se` after R4, or fold into per-package R4 trees |
| **Implementation notes** | Require `pool.balanceOf == lastTotalAssets` before zap-in mint. Offset 9 on Aero DFPkg. |
| **Acceptance** | `forge test --match-test 'test_A0_'` — donator≠attacker; redeem profit ≤ 0 vs donation |
| **Anti-theater checks** | Must redeem; not only assert no immediate share mint |
| **Proof-first?** | yes |
| **Wave** | **1** |
| **Estimate** | M |

### 6. WP-SEC-I-SE-4626-001 — Honor pull flag on LP deposit

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-I-SE-4626-001` |
| **Title** | Route SE LP-deposit through reserve-delta (do not skip pull on exact lastTotal gap) |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Aerodrome, Camelot, Uni V2 SE |
| **Finding IDs** | SEC-SHARP-004 |
| **Problem** | LP→share mint ignores `pretransferred` and credits exact `lastTotalAssets` gap. |
| **Production files (touch set)** | `*StandardExchangeInTarget.sol` LP-deposit branches (same In files as R4/A0 — **pack per package**) |
| **Test files (touch set)** | `test_I1_lpDeposit_*` |
| **Out of scope files** | Commons helper |
| **Depends on** | Reserve-delta law already in BVC. Pack with A0/R4 per In Target. |
| **Parallelizable with** | Out WPs; MultiVault PkgArgs |
| **Conflicts with coverage-audit WP** | Soft overlap `WP-I-SE-AC-001` tests — add cases, do not fork a second I-suite tree |
| **Suggested worktree** | pack into `sec_fix_r4-cam` / `sec_fix_r4-u2` / `sec_fix_a0-se` (L-SEC-13) |
| **Implementation notes** | `_secureTokenTransfer` + sync. `false` always pulls. |
| **Acceptance** | `test_I1_lpDeposit_pretransferredFalse_existingLpGap_doesNotMint` |
| **Anti-theater checks** | I1 zero transfer; no mock SE |
| **Proof-first?** | yes |
| **Wave** | **1** (packed) |
| **Estimate** | M |

### 7. WP-SEC-PKG-MV-001 — Lock MultiVault PkgArgs vault / share

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-PKG-MV-001` |
| **Title** | Reject unregistered vaults and unlocked `vaultShare` in PkgArgs |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | MultiVaultWeightedDetfDFPkg |
| **Finding IDs** | SEC-SHARP-006 |
| **Problem** | `vaultShares[i]==0` aliases to `vaults[i]`; no registry or share-token check. Immutable hostile configuration. |
| **Production files (touch set)** | `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfDFPkg.sol` |
| **Test files (touch set)** | MultiVault deploy / `test_SHARP_006_*` |
| **Out of scope files** | MultiVault Common `_pullToken` (OWNED_ELSEWHERE) |
| **Depends on** | none |
| **Parallelizable with** | all commons/SE WPs |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_pkg-mv` / `sec_fix/pkg-mv` |
| **Implementation notes** | Registry membership; share == vault or vault-reported share. Revert bare `address(0)` unless proven. Registry deploy in tests. |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/**' --match-test 'test_SHARP_006'` |
| **Anti-theater checks** | Hostile ERC-20 as share must revert; no `new` DFPkg |
| **Proof-first?** | no |
| **Wave** | **1** |
| **Estimate** | S |

### 8. WP-SEC-DETF-MV-A0-001 — MultiVault A0 test on production proxy

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-MV-A0-001` |
| **Title** | Add catalog `test_A0_*` for residual inventory at empty / pre-live supply |
| **Severity** | High |
| **Class** | TEST |
| **Products** | MultiVaultWeightedDetf |
| **Finding IDs** | SEC-DETF-MV-007 |
| **Problem** | No `test_A0_*`. Production looks gated (`initializeReserve` pulls `false`; inert until first BPT bond) but residual inventory is unproven. |
| **Production files (touch set)** | none unless test finds CODE |
| **Test files (touch set)** | `test/.../multi-vault-weighted/adversarial/` |
| **Out of scope files** | A–H rewrite |
| **Depends on** | none |
| **Parallelizable with** | PKG-MV, F1, all SE WPs |
| **Conflicts with coverage-audit WP** | none (I/J/K owned elsewhere) |
| **Suggested worktree** | `sec_fix_detf-mv-a0` |
| **Implementation notes** | Gold `TestBase_MultiVaultWeightedDetf`; registry deploy; role names. |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/adversarial/**' --match-test 'test_A0_'` |
| **Anti-theater checks** | Production proxy; donate then first minter/bond cannot drain |
| **Proof-first?** | no |
| **Wave** | **1** |
| **Estimate** | S |

### 9. WP-SEC-CROPS-001 — Strip disable from DETF claim/exit (full-pass families)

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-CROPS-001` |
| **Title** | Registry disable must not brick DETF claim/exit (or Uni V2 Out) |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Disable-gated DETF families (Single SE, Uni V4 DETFs, DualLiquidity); Uni V2 SE Out |
| **Finding IDs** | SEC-CROPS-001, SEC-CROPS-002 |
| **Problem** | Manager owner `setVaultAddressDisabled` freezes `_requireActive` including claim/exit on families that call `_requireNotDisabled`. MultiVault is already clean. |
| **Production files (touch set)** | Those families’ `*Common.sol` / Bonding / ExchangeOut; `UniswapV2StandardExchange{In,Out}Target.sol` |
| **Test files (touch set)** | Family `_requireActive` / disable negatives — claim still works when disabled **or** owner documents ACCEPTED_RISK |
| **Out of scope files** | MultiVault Common |
| **Depends on** | Owner: kill-switch vs walkaway. May wait MODE=full area reports. |
| **Parallelizable with** | per-family after owner OK |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_crops-disable-exit` (split per family) |
| **Implementation notes** | L-SEC-11. Prefer: disable blocks **new** mint/bond only; `redeemClaim` / `closeBondMature` / `exchangeOut` remain live. |
| **Acceptance** | Disabled instance: claim/exit succeed; new bond reverts |
| **Anti-theater checks** | Call proxy after `setVaultAddressDisabled(true)` |
| **Proof-first?** | no |
| **Wave** | **full / later** |
| **Estimate** | M |

### 10. WP-SEC-SHARP-ABI-001 — Wave 4 ABI hygiene (clustered Medium)

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-SHARP-ABI-001` |
| **Title** | Typed funding mode, minOut floor, recipient/lock/Permit2 bound |
| **Severity** | Medium |
| **Class** | CODE |
| **Products** | IStandardExchange consumers; MultiVault bond |
| **Finding IDs** | SEC-SHARP-001, 005, 007, 008, 012 |
| **Problem** | Bool + zero minOut + silent 0 recipient + uint160 cast + silent lock clamp. |
| **Production files (touch set)** | Interfaces + Targets (ABI — coordinate) |
| **Test files (touch set)** | `test_SHARP_00{1,5,7,8,12}_*` |
| **Out of scope files** | E6 math |
| **Depends on** | Wave 0 E6 |
| **Parallelizable with** | none if ABI breaks |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_sharp-abi` |
| **Implementation notes** | Fail closed on swap `minOut==0`, `recipient==0`, `amount>uint160.max`, lock>max. |
| **Acceptance** | listed `test_SHARP_*` |
| **Anti-theater checks** | First example is the safe path |
| **Proof-first?** | no |
| **Wave** | **4** |
| **Estimate** | L |

---

## Parallelism graph

```text
Wave 0 (serial, one tree):
  [sec_fix_e6-common]     BasicVaultCommon.sol

Wave 1 (≤3 live; L-SEC-12):
  [sec_fix_cam-out]       Camelot Out Target          ||  [sec_fix_pkg-mv]   ||  [sec_fix_detf-mv-a0]
  [sec_fix_e6-aero]       Aero Out                    after Wave 0 helper freeze
  [sec_fix_e6-u2]         Uni V2 Out                  after Wave 0
  [sec_fix_r4-cam]        Camelot In                  then A0/4626 on SAME file
  [sec_fix_r4-u2]         Uni V2 In                   then A0/4626 on SAME file

Do not parallel:
  e6-common || any other editor of BasicVaultCommon.sol
  cam-out   || e6-se on Camelot Out Target
  r4-cam    || a0-se / 4626 on Camelot In Target
  r4-u2     || a0-se / 4626 on Uni V2 In Target
  sec_fix_* || gap_cover_* on the same primary file
```

**Orchestrator concurrency:** ≤ 3 `sec_fix_*` worktrees (L-SEC-12).
