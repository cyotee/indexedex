# Security Audit specialist — S-sharp-edges

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` (`1e0d7c48eff8a883837996ae700426ac5397924b`) |
| Status | **COMPLETE** |
| Inputs | PRD §2, §3.5, §7.3–7.4, §19; `docs/security/audit/00_SCOPE_PARTITION.md`; `01_METHODOLOGY_NOTES.md`; `docs/security/audit/repro/SEC-COMMON-001/`; `docs/testing/coverage-audit/WORK_PACKAGE_BACKLOG.md`; **no area reports** at hunt start — production allowlists used. Orchestrator persisted this file after the specialist worker could not write. |
| Skill | Trail of Bits `sharp-edges` / `sharp-edges-analyzer` (pit of success; insecure defaults; silent failures). Hunt: PAT-SHARP-FLAG, PAT-E6-REFUND, PAT-I-ABS, PkgArgs hostile `vaultShare`, silent `address(0)`, zero `minOut`, max-approve, Permit2 |

## 1. Cross-cut thesis

Pilot money APIs still make the **insecure path the easy path**. `exchangeIn` / `exchangeOut` / `bond` expose a public `bool pretransferred` that disables the pull; product law allows any caller to pass `true`, so reserve-delta is the only backstop. That backstop is now in `BasicVaultCommon._secureTokenTransfer` (PAT-I-ABS **OWNED_ELSEWHERE** / closed in helper at this SHA), but exact-out `_refundExcess` still refunds **user `maxAmountIn − used`**, not this-call unused inbound — a boolean plus a claimed-max refund is an **E6 drain of booked pair tokens**. SE LP-deposit routes **ignore** the flag and credit `ERC4626Service._secureReserveDeposit`’s `lastTotalAssets` gap. DFPkg / tests ship `minAmountOut=0` and `pretransferred=true`. MultiVault `PkgArgs` silently aliases `vaultShares[i]==0` to `vaults[i]` and never locks share to a registered SE. Threshold / expansion zeros fail **closed**. `deadline=0` fails closed. Pit of success is not met for flags, refunds, or PkgArgs.

## 2. Findings

### 2.1 [SEC-SHARP-001] Public `bool pretransferred` disables pull on every money route

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SHARP-001` |
| **Title** | Public boolean trust flag on `exchangeIn` / `exchangeOut` / `bond` |
| **Severity** | Medium |
| **Class** | **ACCEPTED_RISK** (flag existence per L-RSRV-CALLER) + Wave-4 ABI hardening recommended |
| **Confidence** | confirmed (static) |
| **Catalog IDs** | I |
| **Pattern IDs** | PAT-SHARP-FLAG |
| **EVM-audit domain** | general / erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | none |
| **Products** | All BasicVaultCommon inheritors (Aerodrome / Camelot / Uni V2 SE); MultiVaultWeightedDetf `exchangeIn` / `bond` |
| **Blast radius** | Shared ABI. Nested DETF `_nestedExchangeInPush` hardcodes `true`. |
| **Attacker** | CFG / INT |
| **Attack scenario** | 1) Integrator copies DFPkg/test call with `pretransferred=true`. 2) Omits atomic push, or aims to spend vault inventory. 3) After reserve-delta: I1 reverts when `U=0`; when `U>0` credits unbooked surplus. 4) Combined with SEC-SHARP-002, `true` + fat `maxAmountIn` refunds booked inventory. |
| **Preconditions** | Caller can set the bool (any EXT). |
| **Impact** | Not free booked mint by itself at this SHA; keeps the security-disabling switch on the hot path and enables E6/I1 misuse. |
| **Evidence** | Crane `IStandardExchangeIn`; `AerodromeStandardExchangeInTarget`; `MultiVaultWeightedDetfExchangeInTarget`; `MultiVaultWeightedDetfBondingTarget`. |
| **Runtime** | n/a (Medium) |
| **Recommended CODE** | Typed `FundingMode { Pull, Pretransfer }` (or split `exchangeInPretransfer`). Do not default to Pretransfer. |
| **Recommended TEST** | `test_SHARP_001_default_or_docs_path_is_pull`; first TestBase example uses `false` + allowance. |
| **Anti-theater** | Happy `true` + real transfer is not coverage. |
| **Suggested WP-ID** | `WP-SEC-SHARP-ABI-001` (Wave 4) |
| **Link TCA / prior** | I1 body **OWNED_ELSEWHERE** → `WP-I-COMMON-001` / `TCA-COMMON-001` |
| **Depends / parallel** | After E6 CODE; parallel with product TEST WPs |

### 2.2 [SEC-SHARP-002] `_refundExcess` pays user `max − used`, not this-call unused inbound

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SHARP-002` |
| **Title** | Exact-out refund trusts caller `maxAmountIn` after crediting only `used` |
| **Severity** | **High** (would be Critical if runtime-proven; L-SEC-3 cap) |
| **Class** | **CODE** |
| **Confidence** | static-high / **RUNTIME_UNPROVEN** |
| **Catalog IDs** | E6, I |
| **Pattern IDs** | PAT-E6-REFUND, PAT-SHARP-FLAG |
| **EVM-audit domain** | erc20 / defi-amm |
| **CROPS pillar** | n/a |
| **Incident theme** | skim / leftover refund |
| **Products** | BasicVaultCommon helper; Aerodrome / Camelot / Uni V2 `exchangeOut` |
| **Blast radius** | Every `_refundExcess(..., maxAmountIn, used, true, msg.sender)` call site. |
| **Attacker** | **EXT** / CAP |
| **Attack scenario** | 1) Vault has booked `R` of pair token T and unbooked `U ≥ needed`. 2) Attacker calls `exchangeOut(..., maxAmountIn=U+X, ..., pretransferred=true)`. 3) `_secureTokenTransfer(T, needed, true)` succeeds (`needed ≤ U`). 4) Vault sends `needed` to the pool. 5) `_refundExcess` transfers `max−needed`. 6) If `max > U`, refund exceeds remaining unbooked and pulls from booked `R`. |
| **Preconditions** | Live SE with pair-token inventory; `U ≥ needed`; attacker chooses `maxAmountIn > U`. |
| **Impact** | Drain of booked pair-token inventory to `msg.sender`. |
| **Evidence** | `BasicVaultCommon.sol` `_refundExcess`: `refund = maxAmount_ - usedAmount_` with no `U` cap. Aerodrome Out swap credits quoted `amountIn` then refunds user `maxAmountIn`. |
| **Runtime** | **RUNTIME_UNPROVEN** (proof-first Wave 0) |
| **Recommended CODE** | Refund `min(max−used, unbooked_after_use)` **or** credit `max` then refund unused inbound. |
| **Recommended TEST** | `test_E6_exchangeOut_pretransfer_maxGtUnbooked_doesNotDrainBookedReserve` |
| **Anti-theater** | Must not transfer `max` in-call; must not assert refund == `max−used` against booked inventory. |
| **Suggested WP-ID** | `WP-SEC-E6-COMMON-001` |
| **Link TCA / prior** | Same **file** as closed `WP-I-COMMON-001` but **different defect** (E6). **Not** OWNED_ELSEWHERE for the E6 algorithm. Serialize on this file. |
| **Depends / parallel** | Wave **0** serial. Parallel with MultiVault PkgArgs WP. |

### 2.3 [SEC-SHARP-003] `_secureSelfBurn` refunds all leftover vault-share balance

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SHARP-003` |
| **Title** | Pretransfer share-burn refunds entire `balanceOf(this)` of vault shares |
| **Severity** | **High** |
| **Class** | **CODE** |
| **Confidence** | static-high / RUNTIME_UNPROVEN |
| **Catalog IDs** | E6, I |
| **Pattern IDs** | PAT-E6-REFUND |
| **EVM-audit domain** | erc20 / erc4626 |
| **CROPS pillar** | n/a |
| **Incident theme** | leftover / donation skim |
| **Products** | BasicVaultCommon; Aerodrome / Camelot / Uni V2 withdraw / zap-out |
| **Blast radius** | Any SE route that burns `address(this)` shares when `pretransferred=true`. |
| **Attacker** | EXT |
| **Attack scenario** | 1) Vault holds donated / stranded self-share balance. 2) Attacker burns exact `burnAmount` with `pretransferred=true`. 3) Helper burns `burnAmount` then `safeTransfer`s **entire remaining** share balance to `owner`. |
| **Preconditions** | Non-zero leftover self-shares; withdrawer uses `pretransferred=true`. |
| **Impact** | Theft of unbooked vault-share inventory. |
| **Evidence** | `BasicVaultCommon._secureSelfBurn` leftover sweep; Aerodrome In/Out call sites. |
| **Runtime** | RUNTIME_UNPROVEN |
| **Recommended CODE** | Refund only `thisCallInbound − burnAmount` (snapshot before burn). Do not sweep `balanceOf(this)`. |
| **Recommended TEST** | `test_E6_selfBurn_pretransfer_doesNotSweepDonatedShares` |
| **Anti-theater** | Attacker must not be the only share holder on the vault. |
| **Suggested WP-ID** | `WP-SEC-E6-COMMON-001` |
| **Link TCA / prior** | Same-file serialize with `WP-I-COMMON-001`; E6 not in that WP. |
| **Depends / parallel** | Cluster with SEC-SHARP-002 |

### 2.4 [SEC-SHARP-004] SE LP-deposit ignores `pretransferred`; credits `lastTotalAssets` exact gap

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SHARP-004` |
| **Title** | LP→share mint uses `ERC4626Service._secureReserveDeposit` and drops the trust flag |
| **Severity** | **High** |
| **Class** | **CODE** |
| **Confidence** | static-high |
| **Catalog IDs** | I1–I3, K1, A0 |
| **Pattern IDs** | PAT-I-ABS, PAT-SHARP-FLAG, PAT-K-DONATE |
| **EVM-audit domain** | erc4626 |
| **CROPS pillar** | n/a |
| **Incident theme** | donation / inflation credit |
| **Products** | Aerodrome / Camelot / Uni V2 LP-deposit branches |
| **Blast radius** | All three pilot SE packages. |
| **Attacker** | EXT / HOS |
| **Attack scenario** | 1) LP balance exceeds `lastTotalAssets` by `D`. 2) Attacker calls `exchangeIn(poolLp, D, vaultShare, …)` with flag true or false. 3) Helper: `actualIn = balance − lastTotalAssets`; if `actualIn == amount` **skips pull**. 4) Vault mints shares for `D` without inbound transfer. |
| **Preconditions** | `lastTotalAssets` lag exactly equal to claimed `amountIn`. |
| **Impact** | Free `vaultShare` mint against prior inventory. |
| **Evidence** | Crane `ERC4626Service._secureReserveDeposit` exact-gap; Aerodrome/Camelot/Uni V2 In LP-deposit branches never read `pretransferred`. |
| **Runtime** | RUNTIME_UNPROVEN |
| **Recommended CODE** | Route LP deposit through `BasicVaultCommon._secureTokenTransfer`. Honor the flag: `false` always pulls. |
| **Recommended TEST** | `test_I1_lpDeposit_pretransferredFalse_existingLpGap_doesNotMint` |
| **Anti-theater** | Do not transfer LP in I1; do not use mock SE. |
| **Suggested WP-ID** | `WP-SEC-I-SE-4626-001` |
| **Link TCA / prior** | **Not** `WP-I-COMMON-001`. SE I-tests `WP-I-SE-AC-001` are TEST-only. New CODE touch-set: `*StandardExchangeInTarget.sol` LP-deposit branches. |
| **Depends / parallel** | After reserve-delta law freeze. Parallel per SE package after shared helper decision. |

### 2.5 [SEC-SHARP-005] `minAmountOut=0` is accepted and is the copy-paste default

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SHARP-005` |
| **Title** | Zero `minOut` disables slippage on public swap/zap/mint |
| **Severity** | Medium |
| **Class** | **CODE** |
| **Confidence** | confirmed |
| **Catalog IDs** | B, N |
| **Pattern IDs** | PAT-SHARP-FLAG |
| **EVM-audit domain** | defi-amm |
| **CROPS pillar** | n/a |
| **Incident theme** | sandwich / zero-minOut |
| **Products** | Aerodrome / Camelot / Uni V2 `exchangeIn`; MultiVault `exchangeIn` / claim settle; DFPkg bootstrap |
| **Blast radius** | All public exact-in routes. |
| **Attacker** | CFG / INT; CAP/MEV on swaps |
| **Attack scenario** | Integrator or UI calls `exchangeIn(..., minAmountOut=0, ...)`. Searcher sandwiches the AMM hop. `MinAmountNotMet` never fires. |
| **Preconditions** | Public AMM route; victim uses 0. |
| **Impact** | User receives dust / zero on swap; not protocol insolvency. |
| **Evidence** | Aerodrome/Camelot DFPkg bootstrap `minOut=0`; check is `if (amountOut < minAmountOut)` with no floor. |
| **Runtime** | n/a |
| **Recommended CODE** | Require `minAmountOut > 0` on swap/zap routes. DFPkg must pass preview (or 1 wei). |
| **Recommended TEST** | `test_SHARP_005_swap_minOutZero_reverts` |
| **Anti-theater** | Do not only test `minOut=1` happy path. |
| **Suggested WP-ID** | `WP-SEC-SHARP-ABI-001` |
| **Link TCA / prior** | none |
| **Depends / parallel** | Wave 4 |

### 2.6 [SEC-SHARP-006] MultiVault `PkgArgs` accepts hostile `vaultShare` / unregistered vault; `address(0)` aliases silently

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SHARP-006` |
| **Title** | PkgArgs does not lock `vaultShares[i]` to the SE share token |
| **Severity** | **High** |
| **Class** | **CODE** |
| **Confidence** | static-high |
| **Catalog IDs** | C, G, F, I |
| **Pattern IDs** | PAT-SHARP-FLAG |
| **EVM-audit domain** | access-control / erc20 |
| **CROPS pillar** | S |
| **Incident theme** | hostile vault token / misconfigured share |
| **Products** | MultiVaultWeightedDetfDFPkg |
| **Blast radius** | Instance is immutable/unowned after deploy. |
| **Attacker** | **CFG** / **HOS** / ADM |
| **Attack scenario** | 1) Deployer sets `vaults[i]` to any non-zero address (no registry `isVault` check). 2) `vaultShares[i]==address(0)` silently becomes `IERC20(vaults[i])`. 3) Or pass an explicit hostile ERC-20 as `vaultShares[i]`. 4) Nested `exchangeIn(..., true)` sends value to a hostile host. |
| **Preconditions** | Ability to call `deployVault(PkgArgs)` (manager owner / registry path). One-shot. |
| **Impact** | Permanent hostile-share DETF: reentrancy, stolen joins, bricked exit. |
| **Evidence** | `MultiVaultWeightedDetfDFPkg` PkgArgs NatSpec + `initAccount` (weights/zero vault/rate XOR — **not** share lock or registry membership). |
| **Runtime** | n/a for CFG |
| **Recommended CODE** | Require `vaultShares[i] == IERC20(vaults[i])` or vault-reported share; require registry knows `vaults[i]`. Revert on bare `address(0)` share unless proven. |
| **Recommended TEST** | `test_SHARP_006_pkgArgs_zeroShare_unregisteredVault_reverts`; `test_SHARP_006_pkgArgs_explicitHostileShare_reverts`. |
| **Anti-theater** | Must deploy via `indexedexManager.deploy*DFPkg` / registry, not `new`. |
| **Suggested WP-ID** | `WP-SEC-PKG-MV-001` |
| **Link TCA / prior** | none (DFPkg not in `WP-I-DETF-MV-001` touch-set) |
| **Depends / parallel** | Parallel with E6 (different files). Wave 1. |

### 2.7 [SEC-SHARP-007] Permit2 `uint160` cast + allowance-or-Permit2 fallback

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SHARP-007` |
| **Title** | Pull path truncates to `uint160` and prefers dusty ERC-20 allowance over Permit2 |
| **Severity** | Medium |
| **Class** | **CODE** |
| **Confidence** | static-medium |
| **Catalog IDs** | I4, I5, O |
| **Pattern IDs** | PAT-SHARP-FLAG |
| **EVM-audit domain** | signatures / erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | none |
| **Products** | `BasicVaultCommon._secureTokenTransfer` (`!pretransferred`); `ERC4626Service._secureReserveDeposit` |
| **Blast radius** | All pull routes on BasicVault inheritors. |
| **Attacker** | CFG / INT |
| **Attack scenario** | `amount > type(uint160).max`: `uint160(amount)` truncates; Permit2 moves the low 160 bits; function returns `B1−B0` ≪ claimed. Stale max-approve leftover uses ERC-20 path when caller intended Permit2. |
| **Preconditions** | Huge amount or leftover allowance ≥ claimed. |
| **Impact** | Under-delivery then FoT-safe return; route that assumes `actualIn == claimed` can skew. |
| **Evidence** | `BasicVaultCommon.sol` Permit2 `uint160` cast; allowance-first branch. |
| **Runtime** | n/a |
| **Recommended CODE** | Revert if `amount > type(uint160).max` before Permit2. Prefer explicit funding mode. |
| **Recommended TEST** | `test_I4_permit2_amountOverUint160_reverts` |
| **Anti-theater** | Must hit the `uint160` branch with `amount > 2^160-1`. |
| **Suggested WP-ID** | `WP-SEC-SHARP-ABI-001` |
| **Link TCA / prior** | none |
| **Depends / parallel** | Wave 2–4 |

### 2.8 [SEC-SHARP-008] `recipient==address(0)` remaps on DETF, not on SE

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SHARP-008` |
| **Title** | Silent `address(0)` recipient → `msg.sender` on MultiVault only |
| **Severity** | Low |
| **Class** | **CODE** |
| **Confidence** | confirmed |
| **Catalog IDs** | none |
| **Pattern IDs** | none |
| **EVM-audit domain** | general |
| **CROPS pillar** | n/a |
| **Incident theme** | none |
| **Products** | MultiVault `exchangeIn` / `bond` / claim |
| **Blast radius** | DETF money routes; integrator ABI confusion. |
| **Attacker** | CFG |
| **Attack scenario** | Caller passes `recipient=0`; DETF remaps to `msg.sender` instead of reverting. |
| **Preconditions** | Zero recipient. |
| **Impact** | Tokens/NFT go to caller instead of burn address; not a steal. |
| **Evidence** | `MultiVaultWeightedDetfExchangeInTarget` / BondingTarget `recipient_ == address(0) → msg.sender`. |
| **Runtime** | n/a |
| **Recommended CODE** | Revert on `recipient==0` everywhere (fail closed). |
| **Recommended TEST** | `test_SHARP_008_recipientZero_reverts` |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | `WP-SEC-SHARP-ABI-001` |
| **Link TCA / prior** | none |
| **Depends / parallel** | Wave 4 |

### 2.9 [SEC-SHARP-009] Aerodrome `decimalOffset = 0` vs peer SE `9`

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SHARP-009` |
| **Title** | Aerodrome DFPkg initializes ERC-4626 with `decimalOffset=0` |
| **Severity** | Medium |
| **Class** | **CODE** |
| **Confidence** | confirmed |
| **Catalog IDs** | A0 |
| **Pattern IDs** | PAT-A0-EMPTY |
| **EVM-audit domain** | erc4626 |
| **CROPS pillar** | n/a |
| **Incident theme** | first-depositor inflation |
| **Products** | AerodromeStandardExchangeDFPkg only (Camelot/UniV2 use offset `9`) |
| **Blast radius** | Empty Aerodrome SE before first LP deposit. |
| **Attacker** | EXT / CAP |
| **Attack scenario** | Classic 4626 inflation: donate 1 wei LP, mint 1 share, donate large LP, next depositor rounds to 0 shares. |
| **Preconditions** | New vault, `totalSupply==0` or tiny supply. |
| **Impact** | First-depositor / donation theft of subsequent LP. |
| **Evidence** | `AerodromeStandardExchangeDFPkg` `decimalOffset` **0**. Camelot/UniV2 use **9**. |
| **Runtime** | n/a |
| **Recommended CODE** | Use the same offset as Camelot/UniV2 (9) or dead shares at init. |
| **Recommended TEST** | `test_A0_aerodrome_emptyVault_donation_doesNotStealNextDeposit` |
| **Anti-theater** | Must start from empty/live-zero supply on production diamond. |
| **Suggested WP-ID** | `WP-SEC-I-SE-4626-001` |
| **Link TCA / prior** | A0 not in `WP-I-SE-AC-001`. New. |
| **Depends / parallel** | Parallel with Camelot/UniV2 I suite |

### 2.10 [SEC-SHARP-010] PAT-I-ABS on `BasicVaultCommon` pull (historical) — OWNED_ELSEWHERE

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SHARP-010` |
| **Title** | Absolute-balance pretransfer on `_secureTokenTransfer` (closed in helper) |
| **Severity** | Info at `1e0d7c48` (historical High) |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | not-reproducible on this SHA (`repro/SEC-COMMON-001/` + hermetic I1 **9/9 PASS**) |
| **Catalog IDs** | I1–I3 |
| **Pattern IDs** | PAT-I-ABS |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | none |
| **Products** | BasicVaultCommon + inheritors |
| **Blast radius** | n/a at this SHA for booked inventory (`U = B − R`) |
| **Attacker** | n/a |
| **Attack scenario** | Historical absolute credit; current helper reverts. |
| **Preconditions** | n/a |
| **Impact** | Was free credit of inventory; helper now reverts `TransferDeltaInsufficient`. |
| **Evidence** | Current `BasicVaultCommon.sol` L75–100; `docs/security/audit/repro/SEC-COMMON-001/` |
| **Runtime** | I1 green at `1e0d7c48` |
| **Recommended CODE** | none (do not reopen `sec_fix_*` on this body) |
| **Recommended TEST** | Remain with `WP-I-COMMON-002` / `WP-I-SE-AC-001` |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none — `WP-I-COMMON-001` / `WP-I-COMMON-002` |
| **Link TCA / prior** | `TCA-COMMON-001`, `WP-I-COMMON-001`, `WP-I-COMMON-002` |
| **Depends / parallel** | n/a |

### 2.11 [SEC-SHARP-011] MultiVault `_pullToken` clone — OWNED_ELSEWHERE

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SHARP-011` |
| **Title** | MultiVault local `_pullToken` (coverage I/J/K WPs) |
| **Severity** | High (coverage label Blocker; helper reserve-delta at this SHA) |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | static — body at this SHA uses reserve-delta + `TransferDeltaInsufficient` |
| **Catalog IDs** | I1–I3 |
| **Pattern IDs** | PAT-I-ABS |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | none |
| **Products** | MultiVaultWeightedDetf |
| **Blast radius** | MultiVault family |
| **Attacker** | n/a |
| **Attack scenario** | Historical clone PAT-I-ABS; current `_pullToken` matches commons. |
| **Preconditions** | n/a |
| **Impact** | Owned by coverage-audit I WPs. |
| **Evidence** | `MultiVaultWeightedDetfCommon.sol` L468–481 |
| **Runtime** | n/a |
| **Recommended CODE** | none from this specialist |
| **Recommended TEST** | `WP-I-DETF-MV-002` |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none — `WP-I-DETF-MV-001` / `002` |
| **Link TCA / prior** | `TCA-DETF-MV-001/002`, `WP-I-DETF-MV-001/002` |
| **Depends / parallel** | n/a |

### 2.12 [SEC-SHARP-012] `lockDuration > max` silently clamped

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SHARP-012` |
| **Title** | Bond lock above max is shortened without revert |
| **Severity** | Low |
| **Class** | **CODE** |
| **Confidence** | confirmed |
| **Catalog IDs** | D |
| **Pattern IDs** | none |
| **EVM-audit domain** | general |
| **CROPS pillar** | n/a |
| **Incident theme** | none |
| **Products** | MultiVault `bond` |
| **Blast radius** | Bond lock UX |
| **Attacker** | CFG |
| **Attack scenario** | User requested 10y lock, receives `maxLockDuration`. Too-short reverts (fail closed). Too-long is silent. |
| **Preconditions** | `lockDuration > max`. |
| **Impact** | User gets shorter lock than requested; not a steal. |
| **Evidence** | `MultiVaultWeightedDetfCommon` lock clamp. |
| **Runtime** | n/a |
| **Recommended CODE** | Revert `LockDurationTooLong` (symmetric with `LockDurationTooShort`). |
| **Recommended TEST** | `test_SHARP_012_lockAboveMax_reverts` |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | `WP-SEC-SHARP-ABI-001` |
| **Link TCA / prior** | none |
| **Depends / parallel** | Wave 4 |

## 3. Products implicated (blast)

| Product | Findings | Notes |
|---------|----------|--------|
| **BasicVaultCommon** | 001, 002, 003, 007, 010 | E6 helpers are the Wave-0 epicenter. I1 body OWNED_ELSEWHERE (closed; I1 9/9 PASS). |
| **Aerodrome SE** | 001, 002, 003, 004, 005, 007, 009 | Unique `decimalOffset=0`. DFPkg bootstrap `minOut=0` + `true`. |
| **Camelot V2 SE** | 001, 002, 003, 004, 005, 007 | Offset 9. |
| **Uniswap V2 SE** | 001, 002, 003, 004, 005, 007 | Same LP-deposit helper as Camelot. |
| **MultiVaultWeightedDetf** | 001, 005, 006, 008, 011, 012 | PkgArgs hostile share is the DETF-specific High. `_pullToken` OWNED_ELSEWHERE. |

## 4. Recommended epic WPs

### WP-SEC-E6-COMMON-001 — Cap refunds to this-call unused inbound

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-E6-COMMON-001` |
| **Title** | Fix `_refundExcess` + `_secureSelfBurn` to this-call surplus only |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | BasicVaultCommon; Aero/Camelot/UniV2 Out/withdraw |
| **Finding IDs** | SEC-SHARP-002, SEC-SHARP-003 |
| **Problem** | Exact-out refunds `maxAmountIn−used` after crediting only `used`. Self-burn sweeps all leftover vault shares. |
| **Production files (touch set)** | `contracts/vaults/basic/BasicVaultCommon.sol` (primary); SE Out/In Targets only if call-site must pass credited-max |
| **Test files (touch set)** | `test/foundry/spec/vaults/basic/**`; SE Out adversarial |
| **Out of scope files** | MultiVault DFPkg; ERC4626 LP-deposit |
| **Depends on** | Confirm `gap_cover_i-common` merged/abandoned |
| **Parallelizable with** | `WP-SEC-PKG-MV-001`, `WP-SEC-I-SE-4626-001` |
| **Conflicts with coverage-audit WP** | **Same file** as closed `WP-I-COMMON-001`. Serialize one commons tree. |
| **Suggested worktree** | `sec_fix_e6-common` / `sec_fix/e6-common` |
| **Implementation notes** | L-RSRV-ABSORB; snapshot `U` before consume; refund `min(max−used, U−used)`. Self-burn: snapshot inbound, refund inbound−burn only. **Proof-first.** |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/vaults/basic/**' --match-test 'test_E6_' -vv` |
| **Anti-theater checks** | No in-call transfer of `max`; booked `R` must not decrease by refund |
| **Proof-first?** | **yes** |
| **Estimate** | M |

### WP-SEC-I-SE-4626-001 — Honor pull flag on LP deposit; Aerodrome offset

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-I-SE-4626-001` |
| **Title** | Route SE LP-deposit through reserve-delta; set Aerodrome `decimalOffset` |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Aerodrome, Camelot, Uni V2 SE |
| **Finding IDs** | SEC-SHARP-004, SEC-SHARP-009 |
| **Problem** | LP→share mint ignores `pretransferred` and credits exact `lastTotalAssets` gap. Aerodrome offset 0 enables A0 inflation. |
| **Production files (touch set)** | `AerodromeStandardExchangeInTarget.sol`; `CamelotV2StandardExchangeInTarget.sol`; `UniswapV2StandardExchangeInTarget.sol`; `AerodromeStandardExchangeDFPkg.sol` |
| **Test files (touch set)** | SE adversarial I1 + A0 |
| **Out of scope files** | Crane `ERC4626Service.sol` unless a thin wrapper is added in IndexedEx |
| **Depends on** | Reserve-delta law (already in BasicVaultCommon) |
| **Parallelizable with** | `WP-SEC-E6-COMMON-001` after helper freeze |
| **Conflicts with coverage-audit WP** | I-tests overlap `WP-I-SE-AC-001` — add cases there or serialize |
| **Suggested worktree** | `sec_fix_i-se-4626` |
| **Implementation notes** | `_secureTokenTransfer` + `_syncAllExpectedHoldReserves`. Registry deploy. |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/vaults/standard-exchange/adversarial/**' --match-test 'test_I1_lpDeposit|test_A0_aerodrome' -vv` |
| **Anti-theater checks** | I1 zero transfer; A0 empty vault |
| **Proof-first?** | yes for free-mint claim |
| **Estimate** | M |

### WP-SEC-PKG-MV-001 — Lock MultiVault PkgArgs vault / share

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-PKG-MV-001` |
| **Title** | Reject unregistered vaults and unlocked `vaultShare` in PkgArgs |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | MultiVaultWeightedDetfDFPkg |
| **Finding IDs** | SEC-SHARP-006 |
| **Problem** | Deploy-time `vaultShares[i]==0` aliases to `vaults[i]`; no registry or share-token check. |
| **Production files (touch set)** | `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfDFPkg.sol` |
| **Test files (touch set)** | MultiVault deploy / adversarial PkgArgs |
| **Out of scope files** | Threshold/expansion resolve |
| **Depends on** | none |
| **Parallelizable with** | all commons/SE WPs |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_pkg-mv` |
| **Implementation notes** | Registry membership; `vaultShare == vault` or vault-reported share. |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/**' --match-test 'test_SHARP_006' -vv` |
| **Anti-theater checks** | Registry deploy; hostile ERC-20 as share must revert |
| **Proof-first?** | no |
| **Estimate** | S |

### WP-SEC-SHARP-ABI-001 — Wave 4 ABI hygiene

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-SHARP-ABI-001` |
| **Title** | Misuse-resistant money ABI (mode, minOut, recipient, Permit2 bound, lock clamp) |
| **Severity** | Medium |
| **Class** | CODE |
| **Products** | IStandardExchange* consumers; MultiVault bond/exchange |
| **Finding IDs** | SEC-SHARP-001, 005, 007, 008, 012 |
| **Problem** | Flattened primitives + bool + zero minOut + silent 0 recipient + uint160 cast + silent lock clamp. |
| **Production files (touch set)** | Interfaces + Targets (ABI change — coordinate) |
| **Test files (touch set)** | ABI / negative suites |
| **Out of scope files** | E6 math (Wave 0) |
| **Depends on** | Wave 0 E6 landed so examples stay valid |
| **Parallelizable with** | none if ABI breaks |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_sharp-abi` |
| **Implementation notes** | Fail closed on `minOut==0` for AMM hops, `recipient==0`, `amount>uint160.max`, lock>max. |
| **Acceptance** | `test_SHARP_001_*`, `test_SHARP_005_*`, `test_SHARP_007_*`, `test_SHARP_008_*`, `test_SHARP_012_*` |
| **Anti-theater checks** | First documented example must be the safe path |
| **Proof-first?** | no |
| **Estimate** | L |

**Do not create** `sec_fix_*` for SEC-SHARP-010/011.

## 5. Explicit non-findings (checked, clean)

| Check | Result |
|-------|--------|
| **`deadline=0`** | Fail **closed** (`DeadlineExceeded`). |
| **DETF `amount==0`** | `_requireActive` reverts `ZeroAmount`. |
| **Threshold zeros** | Resolve to 1.05e18 / 0.95e18 Policy defaults. Pit of success. |
| **Expansion zeros** | Resolve to defaults (not uncapped). |
| **`lockDuration < min`** | Reverts `LockDurationTooShort`. |
| **Max `approve` on SE money path** | Exact `amountIn` / `lpAmount`, not `type(uint256).max`. |
| **Aerodrome `PkgArgs.reserveAsset`** | Requires factory `isPool` and `!stable()`. |
| **SE `deployVault` recipient 0 + deposit** | `RecipientRequiredForDeposit`. |
| **MultiVault `initializeReserve`** | Always `_pullToken(..., false)`. |
| **Unrated `rateAsset==0`** | Documented unrated leg. |

## 6. Commands / checklists walked

```bash
git rev-parse HEAD   # 1e0d7c48eff8a883837996ae700426ac5397924b
rg -n --glob '*.sol' 'pretransferred' contracts/vaults/basic contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted contracts/protocols/dexes/aerodrome/v1 contracts/protocols/dexes/camelot/v2 contracts/protocols/dexes/uniswap/v2
rg -n --glob '*.sol' '_refundExcess|_secureSelfBurn|_secureReserveDeposit|uint160\(' contracts/vaults/basic contracts/protocols/dexes/{aerodrome/v1,camelot/v2,uniswap/v2}
```

Specialist did **not** run forge. Orchestrator I1 re-check is under `repro/SEC-COMMON-001/`. Sharp-edges checklist: zero/empty, defaults, mode selector, type confusion, PkgArgs validation, three adversaries, coverage collision — walked (see specialist return).

## Full-pass addendum (2026-08-13)

New High footguns from MODE=full (do **not** rewrite pilot findings):

| ID | Surface | Action |
|----|---------|--------|
| Loop `pretransferred` skip-pull | `AaveCrossVersionLoopExchangeInTarget` | `WP-SEC-I-AAVE-LOOP-001` |
| Slipstream `_refundRemainder` entire balance | In Target | `WP-SEC-E6-SLIP-001` |
| SinglePool `_receiveExactIn` returns claimed | `BalancerV3SinglePoolStandardExchange` | `WP-SEC-I-BAL-SINGLE-001` |
| SinglePool max Permit2 approve | same file | fold BAL WP |
| Public `bool pretransferred` still on all new SE/DETF ABIs | protocol-wide | still `SEC-SHARP-001` ACCEPTED_RISK |

No change to pilot High CODE IDs.

| Metric | Value |
|--------|--------|
| Status | **COMPLETE** |
| Critical | **0** |
| High CODE | `SEC-SHARP-002`, `003`, `004`, `006` |
| OWNED_ELSEWHERE | `010`, `011` |
| Epic WP-IDs | `WP-SEC-E6-COMMON-001`, `WP-SEC-I-SE-4626-001`, `WP-SEC-PKG-MV-001`, `WP-SEC-SHARP-ABI-001` |
