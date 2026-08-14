# Stage 3 Remediation Progress — Security Audit

| Field | Value |
|-------|--------|
| **Status** | **36/36 High closed.** `WP-SEC-TOKEN-001` recorded as project law (FoT forbidden; no rebasing underlyings; non-18 decimals allowed / scale to 18; pause accepted; docs + `test_L2_FoT_forbidden`; no allowlist). **No BUILD_BLOCKED.** |
| **Started** | 2026-08-13 |
| **Base SHA** | `aa8ec347` |
| **Tip** | `bb16e109` |
| **Law** | `docs/security/SECURITY_AUDIT_REMEDIATION_IMPLEMENTATION_PLAN.md` |
| **Concurrency** | Wave 0 = 1 slot; thereafter ≤ 3 live `sec_fix_*` worktrees |
| **Max live observed** | 3 |
| **via_ir** | never |
| **ALCHEMY_KEY** | set (DualLiq + Slipstream ran fork/hermetic as required) |

## Live slots

| Slot | Slice | Status |
|------|-------|--------|
| 1–3 | — | free |

## Linear history on main (`sec_fix` stack, newest first)

| Commit | Slice | WPs |
|--------|-------|-----|
| `961e5369` | `token-policy` | `WP-SEC-TOKEN-001` |
| `d6260db0` | `detf-com-j` | `WP-SEC-DETF-COM-J-001` |
| `cbde922d` | `erc4626-ij` | `WP-SEC-I-ERC4626-001` |
| `55208c31` | `lst-ij` | `WP-SEC-I-LST-001`, `WP-SEC-J-LST-001` |
| `a18fdb51` | `detf-sse` | `WP-SEC-DETF-SSE-A0-001` + SSE/CP CROPS |
| `5d336f8d` | `detf-cs` | `WP-SEC-DETF-CS-LOCK-001`, `…-TOKEN-001`, `…-A0-001` |
| `b8cb7dd1` | `detf-mv` | `WP-SEC-PKG-MV-001`, `WP-SEC-DETF-MV-A0-001` |
| `e16cf5d6` | `detf-dl` | `WP-SEC-DETF-DL-A0-001`, `…-DELTA-001`, `…-I-HONESTY-001` + DualLiq CROPS |
| `49b3aa0a` | `detf-uv4-extra` | UV4-BURN/I/J/A0/NFT/ORB + UV4 CROPS |
| `705ea924` | `univ4-se` | `WP-SEC-E6-U4-001`, `WP-SEC-IMP-U4-001`, `WP-SEC-A0-U4-001` |
| `b32cb20c` | `univ2-se` | Uni V2 E6/R4/A0/I-4626 + Uni V2 CROPS |
| `c6b534dc` | `univ3-e6` | `WP-SEC-E6-U3-001`, `WP-SEC-I-U3-SHARE-001`, `WP-SEC-A0-U3-001` |
| `4999526d` | `aero-se` | Aero E6/A0/I-4626 |
| `e69f7f2d` | `slip-e6` | `WP-SEC-E6-SLIP-001` |
| `1f8c8e21` | `cam-se` | `WP-SEC-CAM-OUT-001` + Camelot E6/R4/A0/I-4626 |
| `7b2ef90a` | `bal-single-i` | `WP-SEC-I-BAL-SINGLE-001` |
| `ea48cc1e` | `aave-loop` | `WP-SEC-I-AAVE-LOOP-001` |
| `4936635c` | `e6-common` | `WP-SEC-E6-COMMON-001` |

Orchestrator record commits: `a7b0a6d2` (Wave 0 progress), `b5cba112` (W1-A record).

## WP status (36 High)

| WP-ID | Slice(s) | Status | Merge SHA |
|-------|----------|--------|-----------|
| `WP-SEC-E6-COMMON-001` | `e6-common` | **CLOSED** | `4936635c` |
| `WP-SEC-CAM-OUT-001` | `cam-se` | **CLOSED** | `1f8c8e21` |
| `WP-SEC-E6-SE-001` | `cam-se` + `aero-se` + `univ2-se` | **CLOSED** (all 3) | `1f8c8e21` / `4999526d` / `b32cb20c` |
| `WP-SEC-R4-SE-001` | `cam-se` + `univ2-se` | **CLOSED** (all 2) | `1f8c8e21` / `b32cb20c` |
| `WP-SEC-A0-SE-001` | `cam-se` + `aero-se` + `univ2-se` | **CLOSED** (all 3) | `1f8c8e21` / `4999526d` / `b32cb20c` |
| `WP-SEC-I-SE-4626-001` | `cam-se` + `aero-se` + `univ2-se` | **CLOSED** (all 3) | `1f8c8e21` / `4999526d` / `b32cb20c` |
| `WP-SEC-I-AAVE-LOOP-001` | `aave-loop` | **CLOSED** | `ea48cc1e` |
| `WP-SEC-E6-SLIP-001` | `slip-e6` | **CLOSED** | `e69f7f2d` |
| `WP-SEC-E6-U3-001` | `univ3-e6` | **CLOSED** | `c6b534dc` |
| `WP-SEC-I-U3-SHARE-001` | `univ3-e6` | **CLOSED** | `c6b534dc` |
| `WP-SEC-A0-U3-001` | `univ3-e6` | **CLOSED** | `c6b534dc` |
| `WP-SEC-E6-U4-001` | `univ4-se` | **CLOSED** | `705ea924` |
| `WP-SEC-IMP-U4-001` | `univ4-se` | **CLOSED** | `705ea924` |
| `WP-SEC-A0-U4-001` | `univ4-se` | **CLOSED** | `705ea924` |
| `WP-SEC-I-BAL-SINGLE-001` | `bal-single-i` | **CLOSED** | `7b2ef90a` |
| `WP-SEC-DETF-UV4-BURN-I1-001` | `detf-uv4-extra` | **CLOSED** | `49b3aa0a` |
| `WP-SEC-DETF-UV4-I-SUITE-001` | `detf-uv4-extra` | **CLOSED** | `49b3aa0a` |
| `WP-SEC-DETF-UV4-J-001` | `detf-uv4-extra` | **CLOSED** | `49b3aa0a` |
| `WP-SEC-DETF-UV4-A0-001` | `detf-uv4-extra` | **CLOSED** | `49b3aa0a` |
| `WP-SEC-DETF-UV4-NFT-001` | `detf-uv4-extra` | **CLOSED** | `49b3aa0a` |
| `WP-SEC-DETF-UV4-ORB-CLAIM-001` | `detf-uv4-extra` | **CLOSED** | `49b3aa0a` |
| `WP-SEC-DETF-CS-LOCK-001` | `detf-cs` | **CLOSED** | `5d336f8d` |
| `WP-SEC-DETF-CS-TOKEN-001` | `detf-cs` | **CLOSED** | `5d336f8d` |
| `WP-SEC-DETF-CS-A0-001` | `detf-cs` | **CLOSED** | `5d336f8d` |
| `WP-SEC-DETF-DL-A0-001` | `detf-dl` | **CLOSED** | `e16cf5d6` |
| `WP-SEC-DETF-DL-DELTA-001` | `detf-dl` | **CLOSED** | `e16cf5d6` |
| `WP-SEC-DETF-DL-I-HONESTY-001` | `detf-dl` | **CLOSED** | `e16cf5d6` |
| `WP-SEC-CROPS-001` | `univ2-se` + `detf-uv4-extra` + `detf-dl` + `detf-sse` | **CLOSED** (all 4) | `b32cb20c` / `49b3aa0a` / `e16cf5d6` / `a18fdb51` |
| `WP-SEC-PKG-MV-001` | `detf-mv` | **CLOSED** | `b8cb7dd1` |
| `WP-SEC-DETF-MV-A0-001` | `detf-mv` | **CLOSED** | `b8cb7dd1` |
| `WP-SEC-DETF-SSE-A0-001` | `detf-sse` | **CLOSED** | `a18fdb51` |
| `WP-SEC-DETF-COM-J-001` | `detf-com-j` | **CLOSED** | `d6260db0` |
| `WP-SEC-I-LST-001` | `lst-ij` | **CLOSED** | `55208c31` |
| `WP-SEC-J-LST-001` | `lst-ij` | **CLOSED** | `55208c31` |
| `WP-SEC-I-ERC4626-001` | `erc4626-ij` | **CLOSED** | `cbde922d` |
| `WP-SEC-TOKEN-001` | `token-policy` | **CLOSED** (docs + `test_L2_FoT_forbidden`; no allowlist) | `961e5369` |

## Worklog

- Wave 0 `e6-common` FFd **before** `cam-se` / `aero-se` / `univ2-se`.
- Live concurrency never exceeded 3. Branches used `sec_fix/` only (no `gap_cover_`).
- Each worktree seeded `cache_forge/` + `out/` from primary; harvested after each green FF.
- DualLiquidity receive remains same-tx inbound-delta (not no-op, not `held − amountIn`).
- Uni V3 `_secureTokenTransfer` body not restyled (OWNED_ELSEWHERE).
- `BasicVaultCommon._secureTokenTransfer` not restyled.
- Token-policy LOCKED 2026-08-13 (owner): FoT forbidden; rebasing underlyings forbidden; non-18 decimals allowed (scale to 18); pause/blacklist accepted; no `processArgs` allowlist. SoT: `docs/agent/INDEXEDEX_AGENT_LAW.md` § Token policy.
- `token-policy` matcher on `main`: `forge test --match-test 'test_L2_FoT_forbidden' -vv` → 2/2 (ERC4626 SE + Camelot V2 SE).

### Matcher notes

On-`main` rematch at `bb16e109` (each slice twice; logs `{SCRATCH}/sec_fix_<slice>.log`):

- **PASS 2×:** `e6-common`, `cam-se`, `aave-loop`, `bal-single-i`, `aero-se`, `slip-e6`, `univ3-e6`, `univ2-se`, `univ4-se`, `detf-uv4-extra`, `detf-dl` (fork + Alchemy), `detf-mv`, `detf-sse`, `lst-ij`, `erc4626-ij`, `detf-com-j`, `token-policy`.
- **`detf-cs` exact §4 `test/**/stable/**` matcher FAIL** (over-match): ProtocolCompound `test_C1`–`C8` `MaxImbalanceRatioExceeded`; MixedBuffer `test_C3_swap_unpaired0_to_buffer` `AllVaultsExhausted`. Those are **outside** CS lock/minter/A0 CODE (§9).
- **`mixedBuffer/**` + `test_A0_` PASS 2×** after deleting `test_A0_mb_emptyUserSupply_donatedInventory_notDrainedByFirstMint` (join solver out of CS CODE). Remaining A0: donate+bootstrap. Log: `{SCRATCH}/sec_fix_detf-cs-mixedbuffer-a0.log`.
- **`detf-cs` WP-named rematch PASS 2×** (11/11 + donatedBuffer A0): `{SCRATCH}/sec_fix_detf-cs-wp-named.log`. Summary: `{SCRATCH}/matcher_summary.txt`.

### Seed / harvest

Warm primary `cache_forge/` + `out/` harvested after every green slice. Crane was a worktree symlink only (never committed).
