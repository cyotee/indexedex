# Work Package Backlog — Stage 1 Security Audit (MODE=full)

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` |
| Ranking | PRD §9 (severity × exploitability × blast × class) |
| Worktree prefix | `sec_fix_` (L-SEC-8) |
| Aggregate | [`AGGREGATE.md`](./AGGREGATE.md) |
| Archive (thin pilot) | [`archive/2026-08-13/WORK_PACKAGE_BACKLOG.md`](./archive/2026-08-13/WORK_PACKAGE_BACKLOG.md) |

Do **not** schedule `sec_fix_*` for OWNED_ELSEWHERE rows. Concurrency ≤ 3 live trees (L-SEC-12). One worktree per package after Wave 0 (L-SEC-13).

**Critical WPs:** none.

---

## Finding → WP index (every Critical/High `SEC-*`)

No Critical `SEC-*`. Every **High** `SEC-*` is listed individually (no ranges).

| FINDING_ID | Sev / Class | WP (this program) | Notes |
|------------|-------------|-------------------|--------|
| SEC-COMMON-002 | High CODE | `WP-SEC-E6-COMMON-001` | self-burn |
| SEC-COMMON-003 | High OE | — | Uni V3 pull → `WP-I-CLONE-001` |
| SEC-SHARP-002 | High CODE | `WP-SEC-E6-COMMON-001` | `_refundExcess` |
| SEC-SHARP-003 | High CODE | `WP-SEC-E6-COMMON-001` | self-burn |
| SEC-SHARP-004 | High CODE | `WP-SEC-I-SE-4626-001` | LP-deposit gap |
| SEC-SHARP-006 | High CODE | `WP-SEC-PKG-MV-001` | PkgArgs share |
| SEC-SHARP-010 | High OE | — | I-ABS helper closed |
| SEC-SHARP-011 | High OE | — | MultiVault pull closed |
| SEC-SE-AC-001 | High CODE | `WP-SEC-E6-SE-001` | SE Out call-sites |
| SEC-SE-CAM-001 | High CODE | `WP-SEC-CAM-OUT-001` | Camelot Out drop |
| SEC-SE-CAM-002 | High CODE | `WP-SEC-R4-SE-001` | Camelot Route4 |
| SEC-SE-U2-001 | High CODE | `WP-SEC-R4-SE-001` | Uni V2 Route4 |
| SEC-SE-AC-002 | High CODE | `WP-SEC-A0-SE-001` | zap-in A0 |
| SEC-SE-AC-003 | High OE | — | `WP-I-SE-AC-001` |
| SEC-SE-AC-004 | High OE | — | `WP-J-SE-AC-001` / `WP-ADV-SE-AC-001` |
| SEC-DETF-MV-007 | High TEST | `WP-SEC-DETF-MV-A0-001` | missing `test_A0_*` |
| SEC-CROPS-001 | High CODE | `WP-SEC-CROPS-001` | disable-on-exit |
| SEC-SPEC-001 | High OE | — | same as `SEC-CROPS-001` |
| SEC-SPEC-010 | High NEEDS_OWNER | `WP-SEC-TOKEN-001` | weird tokens |
| SEC-SPEC-020 | High CODE | `WP-SEC-E6-COMMON-001` | E6 epic pointer (no extra tree) |
| SEC-SPEC-030 | High TEST | `WP-SEC-I-LST-001` + `WP-SEC-J-LST-001` + `WP-SEC-I-ERC4626-001` + `WP-SEC-E6-SLIP-001` | J leftovers |
| SEC-SPEC-040 | High OE | — | Coordinator I5 `WP-I5-RTR-001` |
| SEC-DETF-SSE-010 | High TEST | `WP-SEC-DETF-SSE-A0-001` | A0 names |
| SEC-DETF-CS-013 | High CODE | `WP-SEC-DETF-CS-LOCK-001` | nonReentrant |
| SEC-DETF-CS-014 | High CODE | `WP-SEC-DETF-CS-TOKEN-001` | leftover minter |
| SEC-DETF-CS-015 | High TEST | `WP-SEC-DETF-CS-A0-001` | A0 |
| SEC-DETF-DL-003 | High CODE | `WP-SEC-DETF-DL-DELTA-001` | same-tx vs docs |
| SEC-DETF-DL-004 | High CODE | `WP-SEC-DETF-DL-A0-001` | A0 |
| SEC-DETF-DL-005 | High TEST | `WP-SEC-DETF-DL-I-HONESTY-001` | fork I/K L-SEC-5 |
| SEC-DETF-UV4-002 | High CODE | `WP-SEC-DETF-UV4-BURN-I1-001` | burn skip pull |
| SEC-DETF-UV4-003 | High TEST | `WP-SEC-DETF-UV4-I-SUITE-001` | I1–I3 |
| SEC-DETF-UV4-004 | High TEST | `WP-SEC-DETF-UV4-J-001` | J |
| SEC-DETF-UV4-005 | High TEST | `WP-SEC-DETF-UV4-A0-001` | A0 |
| SEC-DETF-UV4-006 | High CODE | `WP-SEC-DETF-UV4-NFT-001` | local NFT owner |
| SEC-DETF-UV4-007 | High CODE | `WP-SEC-DETF-UV4-NFT-001` | local claim pull |
| SEC-DETF-UV4-008 | High CODE | `WP-SEC-DETF-UV4-ORB-CLAIM-001` | depositClaim |
| SEC-DETF-COM-001 | High OE | — | `WP-I-CLAIM-001` closed |
| SEC-DETF-COM-004 | High TEST | `WP-SEC-DETF-COM-J-001` | J |
| SEC-SE-U3-001 | High OE | — | `WP-I-CLONE-001` pull |
| SEC-SE-U3-002 | High CODE | `WP-SEC-E6-U3-001` | entire-balance refund |
| SEC-SE-U3-003 | High CODE | `WP-SEC-I-U3-SHARE-001` | zap-out share |
| SEC-SE-U3-004 | High CODE | `WP-SEC-A0-U3-001` | A0 |
| SEC-SE-U3-006 | High OE | — | `WP-I-CLONE-001` |
| SEC-SE-U4-002 | High CODE | `WP-SEC-E6-U4-001` | zap-out E6 |
| SEC-SE-U4-003 | High CODE | `WP-SEC-IMP-U4-001` | importPosition |
| SEC-SE-U4-004 | High CODE | `WP-SEC-A0-U4-001` | A0 |
| SEC-SE-AAVE-001 | High CODE | `WP-SEC-I-AAVE-LOOP-001` | Loop skip-pull |
| SEC-SE-AAVE-002 | High CODE | `WP-SEC-I-AAVE-LOOP-001` | Loop self-share burn |
| SEC-SE-AAVE-003 | High OE | — | `WP-I-SE-UAB-001` |
| SEC-SE-AAVE-004 | High OE | — | `WP-SEC-E6-COMMON-001` blast (commons file) |
| SEC-SE-LST-001 | High TEST | `WP-SEC-I-LST-001` | I names |
| SEC-SE-LST-002 | High TEST | `WP-SEC-J-LST-001` | J |
| SEC-SE-4626-001 | High TEST | `WP-SEC-I-ERC4626-001` | I theater |
| SEC-SE-4626-002 | High TEST | `WP-SEC-I-ERC4626-001` | J |
| SEC-SE-SLIP-001 | High CODE | `WP-SEC-E6-SLIP-001` | entire-balance In |
| SEC-SE-SLIP-002 | High CODE | `WP-SEC-E6-SLIP-001` | max−used Out |
| SEC-SE-SLIP-003 | High TEST | `WP-SEC-E6-SLIP-001` | I/J fold |
| SEC-SE-BAL-001 | High CODE | `WP-SEC-I-BAL-SINGLE-001` | SinglePool receive |
| SEC-SE-BAL-002 | High OE | — | `WP-J-ROUTER-UAB-001` |
| SEC-HOOK-SE-001 | High OE | — | `WP-I-HOOK-SEBUF-001` / `WP-J-HOOK-001` |
| SEC-HOOK-SE-002 | High OE | — | `WP-I-HOOK-CP-001` / `WP-I-HOOK-DUAL-001` |
| SEC-HOOK-SW-001 | High OE | — | `WP-J-HOOK-001` |
| SEC-RTR-001 | High OE | — | `WP-I5-RTR-001` / `WP-J-RTR-001` / `WP-N-RTR-001` |
| SEC-MGR-001 | High OE | — | `WP-SEC-CROPS-001` (DETF files, not manager) |
| SEC-MGR-002 | High OE | — | `WP-J-MGR-001` closed |
| SEC-MGR-003 | High OE | — | `WP-J-MGR-002` closed |
| SEC-FEE-001 | High OE | — | `WP-N-FEE-001` closed |

---

## OWNED_ELSEWHERE (do not `sec_fix_*`)

| SEC / note | Coverage IDs | Touch-set |
|------------|--------------|-----------|
| Commons token I-ABS | `TCA-COMMON-001`, `WP-I-COMMON-001/002` | `BasicVaultCommon._secureTokenTransfer` |
| MultiVault I/J/K | `WP-I-DETF-MV-*`, `WP-J-DETF-MV-001`, `WP-K-DETF-MV-001` | MultiVault Common/Targets |
| SE AMM v2 I/J/ADV | `WP-I-SE-AC-001`, `WP-J-SE-AC-001`, `WP-ADV-SE-AC-001` | Aero/Cam/U2 tests |
| Aero deadline / Camelot H | `WP-E5-AERO-001`, `WP-H-CAM-001` | not Route4 CODE |
| Uni V3 **pull** | `WP-I-CLONE-001` | Uni V3 `_secureTokenTransfer` |
| Single SE I/J | `WP-I-DETF-SSE-*`, `WP-J-DETF-SSE-*` | Bal + CP |
| Legacy listing DETF | `WP-I-DETF-SSE-UV4-001` | **directory gone** |
| CS/MB I/J/ADV/G | `WP-I-DETF-CS-*`, `WP-I-DETF-MB-001`, `WP-J-DETF-CS-MB-001`, `WP-ADV-DETF-MB-001`, `WP-G-E-DETF-CS-001` | pull bodies closed |
| DualLiq receive | `WP-I-DETF-DL-001` | `_receive` closed |
| Uni V4 SE / Stata token I/J/ADV | `WP-I-CLONE-UAB-001`, `WP-I-SE-UAB-001`, `WP-J-SE-UAB-001`, `WP-ADV-SE-UAB-001` | not Loop In file |
| Claim token I | `WP-I-CLAIM-001` | RebasingClaimToken |
| Hooks I/J/ADV | `WP-I-HOOK-*`, `WP-J-HOOK-001`, `WP-ADV-HOOK-001` | SE buffer + swap J |
| Manager J / Fee N | `WP-J-MGR-001/002`, `WP-N-FEE-001` | closed at SHA |
| Router I5/J/N | `WP-I5-RTR-001`, `WP-J-RTR-001`, `WP-N-RTR-001` | Coordinator |
| Balancer SE router J | `WP-J-ROUTER-UAB-001` | not SinglePool helper |

---

## Parallelism graph

```text
SERIAL Wave 0:
  WP-SEC-E6-COMMON-001  (BasicVaultCommon.sol)  ──blocks──► Stata Out E6, AMM v2 self-burn callers

PARALLEL Wave 1 (disjoint trees; ≤3 live):
  WP-SEC-CAM-OUT-001          Camelot Out only
  WP-SEC-E6-SE-001            Aero/Cam/U2 Out Targets (after or with Wave 0 if they only change call-sites)
  WP-SEC-R4-SE-001            Camelot + Uni V2 In Route4
  WP-SEC-A0-SE-001            Aero/Cam/U2 zap-in
  WP-SEC-I-SE-4626-001        LP-deposit helpers (not ERC4626 package)
  WP-SEC-PKG-MV-001           MultiVault PkgArgs
  WP-SEC-CROPS-001            disable-gated DETF commons `_requireNotDisabled`
  WP-SEC-I-AAVE-LOOP-001      aave/cross-version In/Out
  WP-SEC-E6-SLIP-001          slipstream In/Out
  WP-SEC-E6-U3-001 + SHARE + A0   uniswap/v3 (same tree — one worktree)
  WP-SEC-E6-U4-001 + IMP + A0     uniswap/v4 SE (one worktree)
  WP-SEC-I-BAL-SINGLE-001     SinglePool helper only
  WP-SEC-DETF-CS-LOCK + TOKEN + A0   composed-stable (one worktree)
  WP-SEC-DETF-DL-*            DualLiquidity (one worktree; fork)
  WP-SEC-DETF-UV4-BURN + I + J + A0 + NFT + ORB   (one worktree per L-SEC-13)
  WP-SEC-DETF-SSE-A0-001      Single SE tests
  WP-SEC-DETF-MV-A0-001       MultiVault A0 tests
  WP-SEC-DETF-COM-J-001       claim/bond J
  WP-SEC-I-LST-001 + J        one lst worktree
  WP-SEC-I-ERC4626-001        erc4626 tests

Do not parallel two agents on the same Facet/Common file.
Skip all OWNED_ELSEWHERE (gap_cover_* owns those files).
```

---

## Ranked WPs (this program) — full PRD §8

### 1. WP-SEC-E6-COMMON-001 — Cap commons refunds / self-burn

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-E6-COMMON-001` |
| **Title** | Fix `_refundExcess` + `_secureSelfBurn` to this-call unused inbound only |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | BasicVaultCommon; Aero/Camelot/Uni V2 / Aave Stata share-burn |
| **Finding IDs** | SEC-COMMON-002, SEC-SHARP-002, SEC-SHARP-003 |
| **Problem** | Refund pays `max−used`; self-burn sweeps leftover `vaultShare`. `pretransferred=true` + fat max skims booked inventory. |
| **Production files (touch set)** | `contracts/vaults/basic/BasicVaultCommon.sol` |
| **Test files (touch set)** | `test/foundry/spec/vaults/basic/**` (`test_E6_*`) |
| **Out of scope files** | SE Out Targets (call-site WP); Uni V3; MultiVault DFPkg |
| **Depends on** | none. Confirm `gap_cover_i-common` idle. |
| **Parallelizable with** | Camelot Out, PkgArgs, product I WPs |
| **Conflicts with coverage-audit WP** | Same file as **closed** `WP-I-COMMON-001`. Serialize. Do not reopen I-ABS body. |
| **Suggested worktree** | `sec_fix_e6-common` / `sec_fix/e6-common` |
| **Implementation notes** | Snapshot `U`; refund `min(max−used, unused U)`. Skills: crane-adversarial E6. Never `via_ir`. |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/vaults/basic/**' --match-test 'test_E6_\|test_I1_\|test_I2_\|test_I3_' -vv` |
| **Anti-theater checks** | seed inventory; I1 no transfer |
| **Proof-first?** | yes |
| **Estimate** | M |

### 2. WP-SEC-CAM-OUT-001 — Pay Camelot Out recipient

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-CAM-OUT-001` |
| **Title** | Transfer `tokenOut` to recipient; stop overwriting `amountIn` |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Camelot V2 SE |
| **Finding IDs** | SEC-SE-CAM-001 |
| **Problem** | Swap sends `tokenOut` to vault; never pays recipient; `amountIn` set to `amountOut` before refund. |
| **Production files (touch set)** | `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol` |
| **Test files (touch set)** | Camelot Out adversarial |
| **Out of scope files** | Aero/Uni V2 Out; commons |
| **Depends on** | none |
| **Parallelizable with** | Wave 0 after file-disjoint confirm |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_cam-out` / `sec_fix/cam-out` |
| **Implementation notes** | `safeTransfer(recipient, amountOut)` before refund. No `via_ir`. |
| **Acceptance** | `--match-path 'test/**/camelot/**' --match-test 'test_CAM_OUT_\|test_E6_'` |
| **Anti-theater checks** | assert recipient received `tokenOut` |
| **Proof-first?** | yes |
| **Estimate** | S |

### 3. WP-SEC-E6-SE-001 — SE Out call-site refund cap

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-E6-SE-001` |
| **Title** | Cap Aero/Camelot/Uni V2 Out refunds to this-call unused |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Aerodrome, Camelot, Uni V2 SE |
| **Finding IDs** | SEC-SE-AC-001 |
| **Problem** | Call-sites pass slippage cap as if it were overpay. |
| **Production files (touch set)** | `*StandardExchangeOutTarget.sol` under aero/v1, camelot/v2, uniswap/v2 |
| **Test files (touch set)** | SE adversarial `test_E6_*` |
| **Out of scope files** | `BasicVaultCommon.sol` (Wave 0); Slipstream/U3 |
| **Depends on** | prefer after `WP-SEC-E6-COMMON-001` if helper changes |
| **Parallelizable with** | CAM-OUT if different functions coordinated |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_e6-se` / `sec_fix/e6-se` |
| **Implementation notes** | Pass unused inbound, not `maxAmountIn`. |
| **Acceptance** | `--match-test 'test_E6_' --match-path 'test/**/{aerodrome/v1,camelot/v2,uniswap/v2}/**'` |
| **Anti-theater checks** | fat max + only `used` transferred |
| **Proof-first?** | yes |
| **Estimate** | M |

### 4. WP-SEC-R4-SE-001 — Route4 pre-deposit convert

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-R4-SE-001` |
| **Title** | Camelot + Uni V2 Route4 convert against pre-deposit reserve |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Camelot, Uni V2 SE |
| **Finding IDs** | SEC-SE-CAM-002, SEC-SE-U2-001 |
| **Problem** | Post-deposit `convertToShares` under-mints. |
| **Production files (touch set)** | Camelot + Uni V2 In Targets Route4 |
| **Test files (touch set)** | Route4 donation/convert tests |
| **Out of scope files** | Aerodrome Route4 (already snapshot) |
| **Depends on** | none |
| **Parallelizable with** | E6-SE if different files |
| **Conflicts with coverage-audit WP** | `WP-H-CAM-001` is H tests — do not collide Route4 CODE |
| **Suggested worktree** | `sec_fix_r4-se` / `sec_fix/r4-se` |
| **Implementation notes** | Copy Aero `vaultLpReserve` snapshot. |
| **Acceptance** | `--match-test 'test_R4_\|test_K1_'` camelot+univ2 |
| **Anti-theater checks** | preview ≡ execute pre-deposit |
| **Proof-first?** | yes |
| **Estimate** | M |

### 5. WP-SEC-I-AAVE-LOOP-001 — Loop delta pull

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-I-AAVE-LOOP-001` |
| **Title** | Credit/burn Loop only against observed inbound delta |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | AaveCrossVersionLoop |
| **Finding IDs** | SEC-SE-AAVE-001, SEC-SE-AAVE-002 |
| **Problem** | `pretransferred` skips `transferFrom` and still values `amountIn`; Out burns `address(this)` shares. |
| **Production files (touch set)** | `…/aave/cross-version/AaveCrossVersionLoopExchange{In,Out}Target.sol` |
| **Test files (touch set)** | new cross-version adversarial I |
| **Out of scope files** | `aave/v3.6/**`; Uni V4 SE |
| **Depends on** | none |
| **Parallelizable with** | all non-aave-loop WPs |
| **Conflicts with coverage-audit WP** | none on these two files. TEST overlap `WP-I-SE-UAB-001` — implement Loop I here. |
| **Suggested worktree** | `sec_fix_aave-loop-i` / `sec_fix/aave-loop-i` |
| **Implementation notes** | ERC4626/commons reserve-delta. Registry deploy. |
| **Acceptance** | `--match-path 'test/**/aave/cross-version/**' --match-test 'test_I1_\|test_I2_\|test_I3_'` |
| **Anti-theater checks** | I1 no transfer; proxy |
| **Proof-first?** | **yes** |
| **Estimate** | M |

### 6. WP-SEC-E6-SLIP-001 — Slipstream refunds

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-E6-SLIP-001` |
| **Title** | Cap Slipstream In/Out refunds; add I/J/E6 tests |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | SlipstreamStandardExchange |
| **Finding IDs** | SEC-SE-SLIP-001, SEC-SE-SLIP-002, SEC-SE-SLIP-003 |
| **Problem** | Entire-balance In refund + max−used Out skim CL pair tokens. |
| **Production files (touch set)** | `SlipstreamStandardExchangeInTarget.sol`, `…OutTarget.sol` |
| **Test files (touch set)** | `test/**/slipstream/adversarial/` |
| **Out of scope files** | Aero v1; Uni V3 |
| **Depends on** | none |
| **Parallelizable with** | U3 E6, E6-SE |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_slip-e6` / `sec_fix/slip-e6` |
| **Implementation notes** | Snapshot unused inbound. Fork if needed (L-SEC-5). |
| **Acceptance** | `--match-path 'test/**/slipstream/**' --match-test 'test_E6_\|test_I1_\|test_J'` |
| **Anti-theater checks** | seed inventory |
| **Proof-first?** | **yes** |
| **Estimate** | M |

### 7. WP-SEC-E6-U3-001 + WP-SEC-I-U3-SHARE-001 + WP-SEC-A0-U3-001 (one tree)

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-E6-U3-001` (fold SHARE + A0) |
| **Title** | Uni V3 E6 refund, zap-out share I1, empty-vault A0 |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Uniswap V3 SE |
| **Finding IDs** | SEC-SE-U3-002, SEC-SE-U3-003, SEC-SE-U3-004 |
| **Problem** | Entire-balance refund; zap-out burns self-shares; first mint A0. Pull I-ABS stays coverage. |
| **Production files (touch set)** | `contracts/protocols/dexes/uniswap/v3/**` except do **not** restyle `_secureTokenTransfer` (OE `WP-I-CLONE-001`) unless coordinating with gap_cover |
| **Test files (touch set)** | Uni V3 adversarial E6/I/A0 |
| **Out of scope files** | `_secureTokenTransfer` body if `gap_cover_i-clones` is live |
| **Depends on** | none (or serialize with `WP-I-CLONE-001` if touching same files) |
| **Parallelizable with** | Slip E6, Loop |
| **Conflicts with coverage-audit WP** | **`WP-I-CLONE-001` owns pull.** Refund/share/A0 are new. |
| **Suggested worktree** | `sec_fix_univ3-e6` / `sec_fix/univ3-e6` |
| **Implementation notes** | If same files as clone WP, Stage 2 must pick one owner. |
| **Acceptance** | `--match-path 'test/**/uniswap/v3/**' --match-test 'test_E6_\|test_I1_\|test_A0_'` |
| **Anti-theater checks** | seed tokens; no transfer on I1 |
| **Proof-first?** | yes |
| **Estimate** | L |

### 8. WP-SEC-E6-U4-001 + IMP + A0 (one tree)

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-E6-U4-001` (fold `WP-SEC-IMP-U4-001`, `WP-SEC-A0-U4-001`) |
| **Title** | Uni V4 SE zap-out E6, untrusted importPosition, first-mint A0 |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Uniswap V4 SE vault |
| **Finding IDs** | SEC-SE-U4-002, SEC-SE-U4-003, SEC-SE-U4-004 |
| **Problem** | Leftover share refund; import accepts hostile PM/owner; no virtual offset. |
| **Production files (touch set)** | `contracts/protocols/dexes/uniswap/v4/**` (SE vault only) |
| **Test files (touch set)** | Uni V4 SE adversarial |
| **Out of scope files** | DETF/hooks; token `_secureTokenTransfer` (OE) |
| **Depends on** | none |
| **Parallelizable with** | U3, Slip, Loop |
| **Conflicts with coverage-audit WP** | `WP-I-CLONE-UAB-001` token pull — do not reopen |
| **Suggested worktree** | `sec_fix_univ4-se` / `sec_fix/univ4-se` |
| **Implementation notes** | Auth-gate import; cap zap-out refund. |
| **Acceptance** | `--match-path 'test/**/uniswap/v4/**' --match-test 'test_E6_\|test_IMP_\|test_A0_'` (SE vault paths only) |
| **Anti-theater checks** | import must revert untrusted owner |
| **Proof-first?** | yes |
| **Estimate** | L |

### 9. WP-SEC-I-BAL-SINGLE-001 — SinglePool receive

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
| **Test files (touch set)** | new balancer pools spec I/E6 |
| **Out of scope files** | buffer pool families; Coordinator |
| **Depends on** | none |
| **Parallelizable with** | Loop, Slip |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_bal-single-i` / `sec_fix/bal-single-i` |
| **Implementation notes** | Copy ERC4626 `_securePull`. |
| **Acceptance** | `--match-test 'test_I1_\|test_E6_\|test_M_' --match-path 'test/**/balancer/v3/pools/**'` |
| **Anti-theater checks** | I1 no transfer |
| **Proof-first?** | **yes** |
| **Estimate** | M |

### 10. WP-SEC-DETF-UV4-BURN-I1-001 (+ fold I/J/A0/NFT/ORB — one family tree)

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-UV4-BURN-I1-001` |
| **Title** | Uni V4 extra DETF burn delta-pull + I/J/A0 + local NFT + orbital claim |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Weighted / Orbital / Curve-quad DETF + local NFT/claim pkgs |
| **Finding IDs** | SEC-DETF-UV4-002…008 |
| **Problem** | Burn skips `_pullToken`; unused local NFT/claim have leftover owner + absolute pull; orbital missing `depositClaim`. |
| **Production files (touch set)** | `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/{weighted,orbital,stable/quad/curve}/**`; `…/uniswap/v4/common/{nft,rebasing}/**` |
| **Test files (touch set)** | matching `test/**/uniswap/v4/standardExchange/{weighted,orbital,stable/quad}/**` |
| **Out of scope files** | CP single (`A-detf-single-se`); shared `detf/common` claim (`WP-I-CLAIM-001`) |
| **Depends on** | none |
| **Parallelizable with** | CS, DualLiq, SSE A0 tests |
| **Conflicts with coverage-audit WP** | mint `_pullToken` is OE `WP-I-CLONE-001` — do not rewrite mint helper |
| **Suggested worktree** | `sec_fix_detf-uv4-extra` / `sec_fix/detf-uv4-extra` |
| **Implementation notes** | Burn must `_pullToken`. L-SEC-13 one tree. |
| **Acceptance** | `--match-path 'test/**/uniswap/v4/standardExchange/{weighted,orbital,stable/quad}/**' --match-test 'test_I\|test_J\|test_A0_\|test_depositClaim'` |
| **Anti-theater checks** | I1 no transfer on burn; J3 proxy |
| **Proof-first?** | yes (burn) |
| **Estimate** | L |

### 11. WP-SEC-DETF-CS-LOCK-001 + TOKEN + A0 (one tree)

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-CS-LOCK-001` |
| **Title** | ComposedStable `nonReentrant` + strip leftover token minter + A0 tests |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | ComposedStableCommonDetf, RebasingDETFToken |
| **Finding IDs** | SEC-DETF-CS-013, SEC-DETF-CS-014, SEC-DETF-CS-015 |
| **Problem** | Money paths missing lock; satellite token still owned/mintable; no `test_A0_*`. |
| **Production files (touch set)** | `…/stable/common/**` money Targets + token DFPkg init |
| **Test files (touch set)** | CS adversarial C + A0 |
| **Out of scope files** | MixedBuffer pull (OE); shared claim token |
| **Depends on** | none |
| **Parallelizable with** | UV4 extra, DualLiq |
| **Conflicts with coverage-audit WP** | pull bodies OE — do not reopen |
| **Suggested worktree** | `sec_fix_detf-cs` / `sec_fix/detf-cs` |
| **Implementation notes** | `ReentrancyLockModifiers` like ERC4626 In. Unown token after deploy. |
| **Acceptance** | `--match-path 'test/**/stable/**' --match-test 'test_C\|test_A0_\|test_F_'` |
| **Anti-theater checks** | hostile share reenter; owner()==0 after deploy |
| **Proof-first?** | yes |
| **Estimate** | M |

### 12. WP-SEC-DETF-DL-A0-001 + DELTA + I-HONESTY (one tree)

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-DL-A0-001` |
| **Title** | DualLiquidity A0 + same-tx/docs delta + honest fork I/K |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | DualLiquidityLinkedCrossVersion |
| **Finding IDs** | SEC-DETF-DL-003, SEC-DETF-DL-004, SEC-DETF-DL-005 |
| **Problem** | Residual inventory first mint; helper vs documented two-tx/Permit2; fork I/K theater. |
| **Production files (touch set)** | `…/crossVersion/v2/**` receive helpers |
| **Test files (touch set)** | `test/foundry/fork/**/crossVersion/v2/adversarial/` |
| **Out of scope files** | Single SE DualLiquidity matrix consumers |
| **Depends on** | none |
| **Parallelizable with** | CS, UV4 extra |
| **Conflicts with coverage-audit WP** | `WP-I-DETF-DL-001` receive **closed** — only change if product chooses two-tx durable U |
| **Suggested worktree** | `sec_fix_detf-dl` / `sec_fix/detf-dl` |
| **Implementation notes** | Fork-first (`FOUNDRY_PROFILE=fork`, `*_alchemy`). L-SEC-5. |
| **Acceptance** | fork `--match-path 'test/foundry/fork/**/crossVersion/v2/**' --match-test 'test_I\|test_A0_\|test_K1_'` |
| **Anti-theater checks** | I1 no transfer; do not count ShareInflation as I |
| **Proof-first?** | yes |
| **Estimate** | L |

### 13. WP-SEC-CROPS-001 — Strip disable from DETF exit

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-CROPS-001` |
| **Title** | Remove `_requireNotDisabled` from DETF bond/claim/exit or document exception |
| **Severity** | High |
| **Class** | BOTH / DOCS if NEEDS_OWNER keeps pause |
| **Products** | disable-gated DETF families |
| **Finding IDs** | SEC-CROPS-001, SEC-SPEC-001 |
| **Problem** | Manager owner freezes mature exit. Contradicts unowned/no-pause law. |
| **Production files (touch set)** | family `*Common.sol` / BondingTargets with `_requireNotDisabled` |
| **Test files (touch set)** | `test_CROPS_disabled_still_allows_mature_exit` |
| **Out of scope files** | Manager disable API itself (platform); MultiVault (clean) |
| **Depends on** | product-owner if exception |
| **Parallelizable with** | UV4 extra tree if same files — **merge** into that tree |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_crops-disable` or fold `sec_fix_detf-uv4-extra` |
| **Implementation notes** | Law: no admin pause on DETF diamond. |
| **Acceptance** | disabled flag + redeemClaim/closeBondMature succeed |
| **Anti-theater checks** | call **after** `setVaultAddressDisabled(true)` |
| **Proof-first?** | no |
| **Estimate** | M |

### 14. WP-SEC-I-U3-SHARE-001 — Uni V3 zap-out share I1

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-I-U3-SHARE-001` |
| **Title** | Do not burn Uni V3 self-held shares on zap-out without inbound delta |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Uniswap V3 SE |
| **Finding IDs** | SEC-SE-U3-003 |
| **Problem** | Zap-out `pretransferred` burns `address(this)` shares with no inbound-delta check. |
| **Production files (touch set)** | `contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeOutTarget.sol` (zap-out) |
| **Test files (touch set)** | Uni V3 adversarial `test_I1_zapOut_*` |
| **Out of scope files** | `_secureTokenTransfer` (`WP-I-CLONE-001`) |
| **Depends on** | none; same worktree as `WP-SEC-E6-U3-001` (L-SEC-13) |
| **Parallelizable with** | Slip, Loop, U4 SE |
| **Conflicts with coverage-audit WP** | none on zap-out; pull stays `WP-I-CLONE-001` |
| **Suggested worktree** | `sec_fix_univ3-e6` / `sec_fix/univ3-e6` |
| **Implementation notes** | Burn only caller shares or require inbound share delta. |
| **Acceptance** | `--match-path 'test/**/uniswap/v3/**' --match-test 'test_I1_'` |
| **Anti-theater checks** | I1 no share transfer; proxy |
| **Proof-first?** | yes |
| **Estimate** | M |

### 15. WP-SEC-A0-U3-001 — Uni V3 empty-vault A0

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-A0-U3-001` |
| **Title** | First Uni V3 mint cannot drain pre-seeded inventory |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Uniswap V3 SE |
| **Finding IDs** | SEC-SE-U3-004 |
| **Problem** | Empty-supply / stale-book first mint can absorb donated pair tokens. |
| **Production files (touch set)** | Uni V3 In Target first-mint / offset |
| **Test files (touch set)** | `test_A0_*` Uni V3 |
| **Out of scope files** | `_secureTokenTransfer` body |
| **Depends on** | same tree as E6-U3 |
| **Parallelizable with** | other package A0 WPs |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_univ3-e6` |
| **Implementation notes** | Dead shares / init gate; do not credit donation. |
| **Acceptance** | `--match-test 'test_A0_' --match-path 'test/**/uniswap/v3/**'` |
| **Anti-theater checks** | donate before first mint; proxy |
| **Proof-first?** | yes |
| **Estimate** | M |

### 16. WP-SEC-IMP-U4-001 — Uni V4 importPosition

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-IMP-U4-001` |
| **Title** | Auth-gate Uni V4 SE `importPosition` PM/owner |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Uniswap V4 SE vault |
| **Finding IDs** | SEC-SE-U4-003 |
| **Problem** | Untrusted position-manager / owner args can import hostile inventory. |
| **Production files (touch set)** | Uni V4 SE import Target |
| **Test files (touch set)** | `test_IMP_*` |
| **Out of scope files** | token `_secureTokenTransfer` |
| **Depends on** | same tree as `WP-SEC-E6-U4-001` |
| **Parallelizable with** | U3, Slip, Loop |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_univ4-se` |
| **Implementation notes** | Allowlist PM; require msg.sender owns NFT. |
| **Acceptance** | `--match-test 'test_IMP_'` Uni V4 SE path |
| **Anti-theater checks** | untrusted owner must revert |
| **Proof-first?** | yes |
| **Estimate** | M |

### 17. WP-SEC-A0-U4-001 — Uni V4 SE first-mint A0

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-A0-U4-001` |
| **Title** | Uni V4 SE first mint / virtual offset |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Uniswap V4 SE vault |
| **Finding IDs** | SEC-SE-U4-004 |
| **Problem** | No virtual offset; first minter can absorb residual LP. |
| **Production files (touch set)** | Uni V4 SE Common / In mint |
| **Test files (touch set)** | `test_A0_*` |
| **Out of scope files** | DETF/hooks |
| **Depends on** | same tree as E6-U4 |
| **Parallelizable with** | other A0 WPs |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_univ4-se` |
| **Implementation notes** | Dead shares or go-live gate. |
| **Acceptance** | `--match-test 'test_A0_'` Uni V4 SE |
| **Anti-theater checks** | seed inventory before first mint |
| **Proof-first?** | yes |
| **Estimate** | M |

### 18. WP-SEC-DETF-UV4-I-SUITE-001 — Uni V4 extra I1–I3

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-UV4-I-SUITE-001` |
| **Title** | Named I1–I3 on weighted/orbital/quad DETF proxies |
| **Severity** | High |
| **Class** | TEST |
| **Products** | Uni V4 weighted / orbital / curve-quad DETF |
| **Finding IDs** | SEC-DETF-UV4-003 |
| **Problem** | No catalog I suite on extra families. |
| **Production files (touch set)** | none unless I1 fails |
| **Test files (touch set)** | family `adversarial/` I files |
| **Out of scope files** | mint `_pullToken` body (OE) |
| **Depends on** | `WP-SEC-DETF-UV4-BURN-I1-001` CODE first for burn I1 |
| **Parallelizable with** | J/A0 in same tree |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_detf-uv4-extra` |
| **Implementation notes** | Copy Single SE I1 pattern; burn path after CODE. |
| **Acceptance** | `--match-test 'test_I1_\|test_I2_\|test_I3_'` extra Uni V4 DETF paths |
| **Anti-theater checks** | I1 no transfer; proxy |
| **Proof-first?** | no |
| **Estimate** | M |

### 19. WP-SEC-DETF-UV4-J-001 — Uni V4 extra J1–J3

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-UV4-J-001` |
| **Title** | J1–J3 proxy surface for extra Uni V4 DETFs |
| **Severity** | High |
| **Class** | TEST |
| **Products** | Weighted / Orbital / Curve-quad DETF |
| **Finding IDs** | SEC-DETF-UV4-004 |
| **Problem** | No loupe/proxy J suite. |
| **Production files (touch set)** | only if PAT-J-OMIT |
| **Test files (touch set)** | `test_J*` on those families |
| **Out of scope files** | CP single J (OE) |
| **Depends on** | none |
| **Parallelizable with** | I/A0 same tree |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_detf-uv4-extra` |
| **Implementation notes** | Target-derived controls; J3 proxy |
| **Acceptance** | `--match-test 'test_J'` extra Uni V4 DETF |
| **Anti-theater checks** | J3 not facet impl |
| **Proof-first?** | no |
| **Estimate** | S |

### 20. WP-SEC-DETF-UV4-A0-001 — Uni V4 extra A0

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-UV4-A0-001` |
| **Title** | First-bond A0 on extra Uni V4 DETFs |
| **Severity** | High |
| **Class** | TEST |
| **Products** | Weighted / Orbital / Curve-quad DETF |
| **Finding IDs** | SEC-DETF-UV4-005 |
| **Problem** | No `test_A0_*` first-mover residual. |
| **Production files (touch set)** | none unless test fails |
| **Test files (touch set)** | `test_A0_*` |
| **Out of scope files** | Single SE A0 WP |
| **Depends on** | none |
| **Parallelizable with** | I/J same tree |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_detf-uv4-extra` |
| **Implementation notes** | Donate before first bond; proxy |
| **Acceptance** | `--match-test 'test_A0_'` extra families |
| **Anti-theater checks** | donate before live |
| **Proof-first?** | no |
| **Estimate** | M |

### 21. WP-SEC-DETF-UV4-NFT-001 — Unused Uni V4 local NFT/claim

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-UV4-NFT-001` |
| **Title** | Strip leftover owner and delta-gate unused Uni V4 local NFT/claim pkgs |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | UniV4DetfBondNft, UniV4DetfRebasingClaim |
| **Finding IDs** | SEC-DETF-UV4-006, SEC-DETF-UV4-007 |
| **Problem** | Unused local packages (families wire shared commons) still have leftover owner + absolute pull. |
| **Production files (touch set)** | `contracts/vaults/detf/protocols/dexes/uniswap/v4/common/{nft,rebasing}/**` |
| **Test files (touch set)** | package I + F leftover-admin |
| **Out of scope files** | shared `detf/common/claimToken` (`WP-I-CLAIM-001`) |
| **Depends on** | none |
| **Parallelizable with** | burn I1 same extra tree |
| **Conflicts with coverage-audit WP** | `WP-I-CLAIM-001` is the **shared** claim token, not these files |
| **Suggested worktree** | `sec_fix_detf-uv4-extra` |
| **Implementation notes** | Unown after deploy; reserve-delta pull. Or delete unused pkgs (NEEDS_OWNER). |
| **Acceptance** | `--match-test 'test_I1_\|test_F1_'` on local nft/rebasing tests |
| **Anti-theater checks** | owner()==0; I1 no transfer |
| **Proof-first?** | yes |
| **Estimate** | M |

### 22. WP-SEC-DETF-UV4-ORB-CLAIM-001 — Orbital depositClaim

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-UV4-ORB-CLAIM-001` |
| **Title** | Implement PRD-locked orbital `depositClaim` or document removal |
| **Severity** | High |
| **Class** | BOTH / DOCS |
| **Products** | UniswapV4StandardExchangeOrbitalDETF |
| **Finding IDs** | SEC-DETF-UV4-008 |
| **Problem** | Family PRD locks `depositClaim`; API missing. |
| **Production files (touch set)** | orbital Bonding/Info Targets + Facet `facetFuncs` |
| **Test files (touch set)** | `test_depositClaim_*` |
| **Out of scope files** | other families |
| **Depends on** | NEEDS_OWNER if PRD should drop the API |
| **Parallelizable with** | same extra tree |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_detf-uv4-extra` |
| **Implementation notes** | Quote family PRD; do not invent economics. |
| **Acceptance** | `test_depositClaim_*` on orbital proxy or PRD amendment recorded |
| **Anti-theater checks** | J includes selector if CODE ships |
| **Proof-first?** | no |
| **Estimate** | M |

### 23. WP-SEC-DETF-CS-TOKEN-001 — CS leftover minter

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-CS-TOKEN-001` |
| **Title** | Unown / revoke minter on ComposedStable satellite `detfToken` |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | RebasingDETFToken (CS companion) |
| **Finding IDs** | SEC-DETF-CS-014 |
| **Problem** | Leftover owner/minter can mint extra `detfToken` after “unowned” deploy. |
| **Production files (touch set)** | `…/stable/common/RebasingDETFTokenDFPkg.sol` + token Targets |
| **Test files (touch set)** | `test_F_*` leftover minter |
| **Out of scope files** | CS pull helper (OE); MixedBuffer |
| **Depends on** | same tree as `WP-SEC-DETF-CS-LOCK-001` |
| **Parallelizable with** | UV4 extra, DualLiq |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_detf-cs` |
| **Implementation notes** | Post-deploy unown; only diamond mints. |
| **Acceptance** | `--match-test 'test_F_' --match-path 'test/**/stable/**'` |
| **Anti-theater checks** | stranger mint reverts; owner()==0 |
| **Proof-first?** | yes |
| **Estimate** | M |

### 24. WP-SEC-DETF-CS-A0-001 — CS A0 tests

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-CS-A0-001` |
| **Title** | ComposedStable / MixedBuffer `test_A0_*` |
| **Severity** | High |
| **Class** | TEST |
| **Products** | ComposedStableCommonDetf; MixedBuffer |
| **Finding IDs** | SEC-DETF-CS-015 |
| **Problem** | No catalog A0 empty-inventory proof. |
| **Production files (touch set)** | none unless test fails |
| **Test files (touch set)** | CS + MB adversarial A0 |
| **Out of scope files** | pull CODE (OE) |
| **Depends on** | none |
| **Parallelizable with** | lock/token same tree |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_detf-cs` |
| **Implementation notes** | Copy MultiVault A0 once it exists. |
| **Acceptance** | `--match-test 'test_A0_' --match-path 'test/**/{stable,mixedBuffer}/**'` |
| **Anti-theater checks** | donate before live; proxy |
| **Proof-first?** | no |
| **Estimate** | S |

### 25. WP-SEC-DETF-DL-DELTA-001 — DualLiquidity same-tx vs docs

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-DL-DELTA-001` |
| **Title** | Align DualLiquidity receive with documented two-tx/Permit2 or invert tests |
| **Severity** | High |
| **Class** | BOTH / DOCS |
| **Products** | DualLiquidityLinkedCrossVersion |
| **Finding IDs** | SEC-DETF-DL-003 |
| **Problem** | Helper is same-tx delta; docs/Permit2 imply two-tx pretransfer. |
| **Production files (touch set)** | `…/crossVersion/v2/` `_receive` / `_receiveOut` |
| **Test files (touch set)** | fork I1 two-tx |
| **Out of scope files** | closed no-op steal (`WP-I-DETF-DL-001`) |
| **Depends on** | product-owner if keeping same-tx |
| **Parallelizable with** | A0/honesty same tree |
| **Conflicts with coverage-audit WP** | do not reopen closed receive CODE unless choosing durable U |
| **Suggested worktree** | `sec_fix_detf-dl` |
| **Implementation notes** | Fork-first. L-SEC-5. |
| **Acceptance** | fork `--match-test 'test_I1_'` DualLiq |
| **Anti-theater checks** | I1 no transfer; not ShareInflation |
| **Proof-first?** | yes |
| **Estimate** | M |

### 26. WP-SEC-DETF-DL-I-HONESTY-001 — DualLiquidity fork I/K honesty

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-DL-I-HONESTY-001` |
| **Title** | Replace DualLiquidity I/K theater with fork I1–I3 + K1 |
| **Severity** | High |
| **Class** | TEST |
| **Products** | DualLiquidityLinkedCrossVersion |
| **Finding IDs** | SEC-DETF-DL-005 |
| **Problem** | ShareInflation is A3-class; happy Permit2 pretransfer is not I. Fork P0 = High (L-SEC-5). |
| **Production files (touch set)** | none |
| **Test files (touch set)** | `test/foundry/fork/**/crossVersion/v2/adversarial/` |
| **Out of scope files** | hermetic MathLib-only |
| **Depends on** | `WP-SEC-DETF-DL-DELTA-001` if CODE changes |
| **Parallelizable with** | A0 same tree |
| **Conflicts with coverage-audit WP** | `WP-I-DETF-DL-002` — **OWNED_ELSEWHERE if still scheduled**; else this WP |
| **Suggested worktree** | `sec_fix_detf-dl` |
| **Implementation notes** | Alchemy `*_alchemy`; do not kill forge. |
| **Acceptance** | `FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/**/crossVersion/v2/**' --match-test 'test_I\|test_K1_'` |
| **Anti-theater checks** | I1 no transfer; ShareInflation not counted as I |
| **Proof-first?** | no |
| **Estimate** | M |

### 27. WP-SEC-DETF-MV-A0-001 — MultiVault A0 tests

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-MV-A0-001` |
| **Title** | Add MultiVault catalog `test_A0_*` |
| **Severity** | High |
| **Class** | TEST |
| **Products** | MultiVaultWeightedDetf |
| **Finding IDs** | SEC-DETF-MV-007 |
| **Problem** | Gold suite lacks named A0 empty-inventory proof. |
| **Production files (touch set)** | none unless test fails |
| **Test files (touch set)** | `test/.../multi-vault-weighted/adversarial/` |
| **Out of scope files** | I/J/K CODE (OE) |
| **Depends on** | none |
| **Parallelizable with** | all disjoint trees |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_detf-mv-a0` |
| **Implementation notes** | Gold TestBase; donate before live. |
| **Acceptance** | `--match-path 'test/**/multi-vault-weighted/adversarial/**' --match-test 'test_A0_'` |
| **Anti-theater checks** | donate before first bond; proxy |
| **Proof-first?** | no |
| **Estimate** | S |

### 28. WP-SEC-DETF-SSE-A0-001 — Single SE A0 tests

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-SSE-A0-001` |
| **Title** | Add Balancer + Uni V4 CP Single SE `test_A0_*` |
| **Severity** | High |
| **Class** | TEST |
| **Products** | SingleStandardExchangeDETF; UniswapV4SingleStandardExchangeDETF |
| **Finding IDs** | SEC-DETF-SSE-010 |
| **Problem** | No catalog A0; production appears gated. |
| **Production files (touch set)** | none unless test fails |
| **Test files (touch set)** | SSE + CP adversarial |
| **Out of scope files** | `_pullToken` (OE) |
| **Depends on** | none |
| **Parallelizable with** | MV A0 |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_detf-sse-a0` |
| **Implementation notes** | Copy MultiVault A0 once written. |
| **Acceptance** | `--match-test 'test_A0_'` SSE + CP paths |
| **Anti-theater checks** | donate before live; proxy |
| **Proof-first?** | no |
| **Estimate** | S |

### 29. WP-SEC-DETF-COM-J-001 — Claim/bond J

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-COM-J-001` |
| **Title** | J1–J3 on shared RebasingClaimToken + DETFNFTVault |
| **Severity** | High |
| **Class** | TEST |
| **Products** | RebasingClaimToken; DETFNFTVault |
| **Finding IDs** | SEC-DETF-COM-004 |
| **Problem** | J not systematically proven on claim/bond diamonds. |
| **Production files (touch set)** | only if PAT-J-OMIT |
| **Test files (touch set)** | claim + NFT vault surface tests |
| **Out of scope files** | `WP-I-CLAIM-001` pull body |
| **Depends on** | none |
| **Parallelizable with** | all disjoint |
| **Conflicts with coverage-audit WP** | not `WP-I-CLAIM-001` |
| **Suggested worktree** | `sec_fix_detf-com-j` |
| **Implementation notes** | J3 on proxy after CREATE3/registry deploy. |
| **Acceptance** | `--match-test 'test_J'` claim/bond trees |
| **Anti-theater checks** | J3 proxy |
| **Proof-first?** | no |
| **Estimate** | S |

### 30. WP-SEC-I-LST-001 — LST I1–I3

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
| **Out of scope files** | Aave Loop; Uni V3; commons |
| **Depends on** | none |
| **Parallelizable with** | `WP-SEC-J-LST-001` (same tree) |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_lst-ij` / `sec_fix/lst-ij` |
| **Implementation notes** | Copy Stata I1 shape. |
| **Acceptance** | `--match-path 'test/foundry/spec/protocol/staking/**' --match-test 'test_I1_\|test_I2_\|test_I3_'` |
| **Anti-theater checks** | I1 no transfer |
| **Proof-first?** | no |
| **Estimate** | M |

### 31. WP-SEC-J-LST-001 — LST J1–J3

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-J-LST-001` |
| **Title** | J1–J3 proxy surface for three LST SE |
| **Severity** | High |
| **Class** | TEST |
| **Products** | Lido / EtherFi / Rocket SE |
| **Finding IDs** | SEC-SE-LST-002 |
| **Problem** | No loupe/proxy smoke. |
| **Production files (touch set)** | only if PAT-J-OMIT |
| **Test files (touch set)** | same staking adversarial trees |
| **Out of scope files** | DETF J WPs |
| **Depends on** | none |
| **Parallelizable with** | fold `sec_fix_lst-ij` |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_lst-ij` |
| **Implementation notes** | Target-derived controls; J3 proxy |
| **Acceptance** | `--match-test 'test_J'` staking paths |
| **Anti-theater checks** | J3 not facet impl |
| **Proof-first?** | no |
| **Estimate** | S |

### 32. WP-SEC-I-ERC4626-001 — ERC4626 I/J

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-I-ERC4626-001` |
| **Title** | Real I1–I3 + J1–J3 on ERC4626 SE (Morpho hermetic inherits) |
| **Severity** | High |
| **Class** | TEST |
| **Products** | ERC4626StandardExchange |
| **Finding IDs** | SEC-SE-4626-001, SEC-SE-4626-002 |
| **Problem** | Misnamed I1 is preview-equality; no J. |
| **Production files (touch set)** | none |
| **Test files (touch set)** | `test/foundry/spec/vaults/standard/erc4626/**` |
| **Out of scope files** | Aave Stata; Morpho Blue port |
| **Depends on** | none |
| **Parallelizable with** | LST I/J, Loop CODE |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_erc4626-ij` / `sec_fix/erc4626-ij` |
| **Implementation notes** | Rename theater I1; add real I1. |
| **Acceptance** | `--match-path 'test/foundry/spec/vaults/standard/erc4626/**' --match-test 'test_I1_\|test_I2_\|test_I3_\|test_J'` |
| **Anti-theater checks** | I1 no transfer; preview test not named I1 |
| **Proof-first?** | no |
| **Estimate** | S |

### 33. WP-SEC-A0-SE-001 — AMM v2 zap A0

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-A0-SE-001` |
| **Title** | Aero/Camelot/Uni V2 zap-in / empty-supply residual LP |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Aerodrome, Camelot, Uni V2 SE |
| **Finding IDs** | SEC-SE-AC-002 |
| **Problem** | Zap-in loads `lastTotalAssets` then syncs live LP including donation; Aero offset 0. |
| **Production files (touch set)** | Aero/Cam/U2 In Targets zap-in |
| **Test files (touch set)** | SE adversarial `test_A0_*` |
| **Out of scope files** | commons helper |
| **Depends on** | none |
| **Parallelizable with** | E6-SE if different functions |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_a0-se` / `sec_fix/a0-se` |
| **Implementation notes** | Snapshot pre-deposit; Aero offset parity. |
| **Acceptance** | `--match-test 'test_A0_' --match-path 'test/**/{aerodrome/v1,camelot/v2,uniswap/v2}/**'` |
| **Anti-theater checks** | donate LP before mint |
| **Proof-first?** | yes |
| **Estimate** | M |

### 34. WP-SEC-I-SE-4626-001 — LP-deposit exact-gap

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-I-SE-4626-001` |
| **Title** | SE LP-deposit must not credit `lastTotalAssets` exact gap |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | AMM v2 SE LP-deposit routes |
| **Finding IDs** | SEC-SHARP-004 |
| **Problem** | LP-deposit ignores `pretransferred` and credits exact-gap. |
| **Production files (touch set)** | Aero/Cam/U2 In LP-deposit helpers |
| **Test files (touch set)** | `test_I1_lpDeposit_*` |
| **Out of scope files** | `ERC4626StandardExchange` package |
| **Depends on** | none; fold `sec_fix_a0-se` |
| **Parallelizable with** | A0-SE same tree |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_a0-se` |
| **Implementation notes** | Credit pull delta / U only. |
| **Acceptance** | `--match-test 'test_I1_lpDeposit'` |
| **Anti-theater checks** | I1 no transfer |
| **Proof-first?** | yes |
| **Estimate** | M |

### 35. WP-SEC-PKG-MV-001 — MultiVault PkgArgs vaultShare

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-PKG-MV-001` |
| **Title** | Lock MultiVault PkgArgs `vaultShares[i]` to registered SE |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | MultiVaultWeightedDetf |
| **Finding IDs** | SEC-SHARP-006 |
| **Problem** | `vaultShares[i]==0` aliases to `vaults[i]`; no registry lock; hostile share. |
| **Production files (touch set)** | `MultiVaultWeightedDetfDFPkg.sol` processArgs |
| **Test files (touch set)** | PkgArgs hostile-share tests |
| **Out of scope files** | MultiVault I/J/K (OE) |
| **Depends on** | none |
| **Parallelizable with** | MV A0 tests |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_pkg-mv` / `sec_fix/pkg-mv` |
| **Implementation notes** | Require registered vaultShare; no silent alias. |
| **Acceptance** | `--match-test 'test_PKG_\|test_C1_'` MultiVault |
| **Anti-theater checks** | zero share must revert or explicit unrated policy |
| **Proof-first?** | no |
| **Estimate** | M |

### 36. WP-SEC-TOKEN-001 — Weird-token policy

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-TOKEN-001` |
| **Title** | Document or reject FoT / rebase / 6-dec / pause underlyings |
| **Severity** | High |
| **Class** | DOCS / TEST (CODE if allowlist ships) |
| **Products** | All SE/DETF that take arbitrary IERC20 in PkgArgs |
| **Finding IDs** | SEC-SPEC-010 |
| **Problem** | No PkgArgs lock for weird tokens. |
| **Production files (touch set)** | optional allowlist in DFPkg processArgs |
| **Test files (touch set)** | one `test_L2_*` per family that claims FoT |
| **Out of scope files** | official LST/Stata faces |
| **Depends on** | NEEDS_OWNER policy first |
| **Parallelizable with** | Wave 3 |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_token-policy` / `sec_fix/token-policy` |
| **Implementation notes** | Do not invent economics. |
| **Acceptance** | written policy + `test_L2_FoT_credits_actualIn` or `test_L2_FoT_forbidden` |
| **Anti-theater checks** | real FoT as configured token, not mock SUT |
| **Proof-first?** | no |
| **Estimate** | M |

---

## Stage 2 stop

Hand off to [`docs/security/PROMPT_SECURITY_AUDIT_REMEDIATION_PRD.md`](../PROMPT_SECURITY_AUDIT_REMEDIATION_PRD.md). Do not open `sec_fix_*` or write the remediation PRD here.
