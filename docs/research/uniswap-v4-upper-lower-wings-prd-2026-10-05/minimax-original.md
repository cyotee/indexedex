# PRD: UniswapV4UpperLowerWingsStandardExchangeVault — first-pass (MiniMax M3)

- **Date:** 2026-10-05
- **Author:** MiniMax M3 (independent first pass; no peer originals or cross-reviews read this round)
- **Status:** research-only PRD draft. **No implementation plan is included in this document.** A separate plan is out of scope until this PRD is approved or amended.
- **Authorization boundary:** Markdown only. No code, tests, shell, config, deploy, instruction edits, delegation, or other writes executed or planned by this document.
- **Preserved by mandate:** `UniswapV4FullSpreadHooklessStandardExchangeVault` and `UniswapV4FullSpreadPonsFamilyHook` (`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/**`, n=47 files, observed 2026-10-05) and the existing FullSpread implementation plan `docs/plans/UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md` (F0–F6, R1–R11). This PRD does **not** propose modifying any FullSpread source or test artifact.

## 0. Terminology (normative)

| Term | Meaning |
|---|---|
| **Center range** | The existing single full-range V4 position currently used by FullSpread (was the only position in restored `92cdf89a^`). |
| **Upper wing** | A new V4 position holding **only token1** while `currentTick ≤ tickLower_w` (above current price). |
| **Lower wing** | A new V4 position holding **only token0** while `tickUpper_w ≤ currentTick` (below current price). |
| **Wing** | Either an upper or a lower wing. Two wings maximum by default. |
| **Position set** | The set of on-chain V4 positions the vault owns = `{center} ∪ {upper_wing?, lower_wing?}` |
| **Local liquidity sleeve** | The vault's own `F_0 + F_1` free ERC-20 custody, **augmented** by a separately-booked inner position the vault may deploy via a **locally unlocked** sub-account when the **outer** PoolManager is already unlocked. **The product has a nested-unlock problem the sleeve must avoid.** (Owner decision: see OD-4 below.) |
| **Wing salt** | Deterministic identifier for a wing, derivable from `(token, side, index)` plus a per-instance constant; no caller-supplied range bytes. |
| **Admission rule** | How a single-token deposit mints fungible shares against the combined book. Today: min-ratio two-leg formula. **This PRD does NOT assert a new admission rule**; OD-1 is unresolved. |
| **Custody vs economic backing** | *Custody* = who holds which ERC-20 at the leaf (vault, SE, V4 PM, hook). *Economic backing* = what a share is redeemable for at the prevailing rates. The two are separated. |

## 1. Goal

Define a **new** Uniswap V4 Standard Exchange vault product — `UniswapV4UpperLowerWingsStandardExchangeVault` — that:

1. Preserves the existing FullSpread scalar/dual/exact-output route matrix (R1–R11 of `UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md:170–193`) **at the proxy and accounting level** — same external surface, same errors, same preview parity obligations.
2. Adds **at most two new positions** in addition to the center: one upper (token1-only) and one lower (token0-only). Each is closed-form under `LiquidityAmounts.getLiquidityForAmount0/1` when out of range.
3. Preserves actual ERC-20 custody on the diamond; **does not** relabel, hide, or scale reserves; **does not** introduce a stale or scaled-reserve fallback.
4. Composes with **eligible SE vaults or bare tokens** per owner clarification — DETFs may bind this product directly, not only FullSpread. Composition rules are unchanged from DETF I/O routing law.
5. Exposes a **local liquidity sleeve** that supports the nested-PoolManager-unlock constraint (when the outer PM is already unlocked, the vault must not attempt a second `pm.unlock`; instead, internal accounting executes from free custody only).
6. Preserves forbidden-by-policy categories: no FoT, no rebasing underlyings, no `via_ir`, no `new` SUT, no mocks of SUT, no `MockStandardExchange` on the new path, no scaled stale reserve, no waived fee.

## 2. Product summary (what this PRD does and does not)

### 2.1 What this product is (proposed)

| Attribute | Value |
|---|---|
| Primary artifact | CREATE3-deployed **vault diamond** with the same facet surface set as FullSpread, plus a `WingsFacet` (or equivalent) exposing wing deployment, removal, consolidation and observation; no change to the existing FullSpread surface. |
| Position set | 1 center (existing full-range behavior) + at most 1 upper wing + at most 1 lower wing. |
| Center | Unchanged from FullSpread (full-range, fixed salt, F0 dual-only first mint, F4 single-step exact-output domain, R1–R11 selector matrix). |
| Wings | Out-of-range, closed-form `getLiquidityForAmount0/1` liquidity; deterministic per-instance salts; deposit time places wing, consolidation merges into center. |
| Sleeve | Local ERC-20 custody `F_0 + F_1` with the existing 1 bp / 50 bp / 25 bp / 10 bp protection constants preserved (D20/D25 of FullSpread plan). No new protection. |
| LP | Fungible ERC-20 on the proxy, EIP-2612 via shared facets, identical to FullSpread. |
| Fees | Own LP fees from each position (center and each wing) flow to the sleeve as in the current per-position `feeGrowthInside` checkpoint. **No new fee or fee waiver** is introduced. |
| Management | Permissionless consolidation, bounded per call (1 wing per call, max). Wings remaining in backing after partial deployment; no new share mint. |
| Deploy | IndexedEx manager vault registry, facets via CREATE3 + FactoryService, no `via_ir`, no `new` SUT. |

### 2.2 What this product is **not** (preserved by law)

- Not a replacement for `UniswapV4FullSpreadHooklessStandardExchangeVault` or `UniswapV4FullSpreadPonsFamilyHook`. **Preserve both unchanged.**
- Not a multi-V4-position concentrated product; **exactly three** positions (center + 0–2 wings).
- Not a multi-asset (n>2) product.
- Not a new asset class — the product still binds the same two pool tokens as FullSpread.
- Not a Funded/Orbital PFP. The product is a single-instance vault per binding, like FullSpread.
- Not a new core range; the center is full-range per existing `92cdf89a^` baseline (and the prior `35f47b5195d16fdf90fd7c032a10f8d3b916fd90` is **historical evidence, not authority**).
- Not an autonomous oracle/NAS admission; new admission rule is **deferred** to OD-1.
- Not a Sushi / Pancake / Arrakis / Charm / Gamma port. Primary-source leads only; license/dependency disposition deferred.
- Not a hook product. **No V4 hook flags are required.** The vault is a hookless standard exchange.

### 2.3 Non-goals (v1)

1. Multi-orbit (>2 wings) positions.
2. Concentrated center range. The center is full-range or whatever FullSpread prescribes at the time of adoption; **does not** widen the center's range.
3. Owner-controlled rebalance. Management is permissionless only.
4. New fee channels, new fee constants, new sleeve target.
5. New admission rule beyond F0 (dual-only first mint) and the existing two-leg minting path.
6. Backdating or replaying any historical commit including `35f47b5…` (see §10).
7. Pons, Orbital hook, Aperture solver, and the existing Aperture refactor work (`docs/plans/UNISWAP_V4_HOOKLESS_APERTURE_OPTIMAL_SWAP_REFACTOR_PRD.md`) — these are out of scope.
8. Cross-pool family composition; the product is one vault, one pool, one center, two wings.
9. User-supplied range bytes; salts are deterministic per instance.
10. SY wrappers, position import NFT, imported-increase path; the existing FullSpread import preview is preserved.
11. New external oracle or TWAP outside the existing `UniswapV4MultiPoolTwapOracleTarget.sol` peer.
12. Any reduction in the existing 1 bp / 50 bp / 25 bp / 10 bp protection constants.

## 3. Locked decisions

| # | Decision | Value |
|---|---|---|
| **UD1** | Product name (file + Solidity type + DFPkg) | **`UniswapV4UpperLowerWingsStandardExchangeVault`** |
| **UD2** | Package path | `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/` |
| **UD3** | Family peer | `UniswapV4FullSpreadHooklessStandardExchangeVault` (route/selector/observation surface preserved) |
| **UD4** | Position set size | 1 center + ≤ 1 upper + ≤ 1 lower = 3 max |
| **UD5** | Wing salt | Deterministic, per `(instance, side, slot)`. Slot indices: upper = 0, lower = 1. |
| **UD6** | Wing tick spacing | Pool's `tickSpacing` (per-instance, set on init). Range always strictly **outside** the current tick at deposit time. |
| **UD7** | Wing gap policy | **Owner decision OD-2.** The PRD recommends: distance of 1 spacing between the wing's inner bound and the **adjacent** tick; the outer bound is the global usable extreme. The PRD **does not** commit to a numeric gap, width, or `k% of tick` policy. |
| **UD8** | First mint | **F0 dual-only** (reused; same dead-sink MINIMUM_LIQUIDITY math as `StandardExchangeConstantProduct.sol:30–35`). Single-token first mint **reverts** `InvalidRoute`. |
| **UD9** | Subsequent deposit (idle) | Existing F0/F1 paths for dual/multi; **single-token deposits are deferred to OD-1** (admission rule). The wings deployment is independent of admission. |
| **UD10** | Subsequent withdraw (idle) | Existing F2/F3/F6 paths preserved. Wing inventory backs the pro-rata share; wings are not separately redeemable. |
| **UD11** | Exact-output support | R2 / R6 / R8 of FullSpread plan preserved; no new supported domain. |
| **UD12** | Local liquidity sleeve | Local ERC-20 `F_0 + F_1` custody, computed live; **no separate inner-pool deployment** unless OD-4 is approved. |
| **UD13** | PoolManager already-unlocked | Existing `UniswapV4Exchange_PoolManagerInteractionBlocked` semantics preserved (reject all idle routes requiring an unlock). Blocked F1/F2 paths continue to settle from `F_0 + F_1`. **No nested unlock.** |
| **UD14** | Fees | Own LP fees from center and each wing flow to sleeve per position's `feeGrowthInside` checkpoint. **Per-position collection; no double-count.** |
| **UD15** | Management | Permissionless consolidation, 1 wing per call, deterministic salt order. No caller reward. |
| **UD16** | No public `diamondCut` after deploy; instances are immutable. |
| **UD17** | Forbidden | `new` SUT, `MockStandardExchange`, `via_ir`, scaled stale reserve, fee waiver, in-kind recovery route, NAV admission, oracle admission (without OD-1), share mint in management. |
| **UD18** | Sources to preserve (unchanged) | `UniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.sol` and its 28 sibling files in `fullSpread/hookless/`; `UniswapV4FullSpreadPonsFamilyHookDFPkg.sol` and its 18 sibling files in `fullSpread/ponsFamilyV2Hook/`; `StandardExchangeConstantProduct.sol`; `UniswapV4Exchange_PoolManagerInteractionBlocked`. |
| **UD19** | Toolchain | Solidity `0.8.35` (per `foundry.toml:29`, observed 2026-10-05). Hermetic default profile; fork profile reserved for fork DoD. No package-specific profiles. |
| **UD20** | Naming | Full product name on Solidity types/files/FactoryService. **No** short hook aliases. LP symbol prefix PRD-locked. (Symbol owner decision OD-3.) |

## 4. Architecture (proposed)

```text
┌────────────────────────────────────────────────────────────────────┐
│ Integrator (DETF, SY wrapper, bare token, hook buffer, router)      │
│   • vault registry: deployPkg + FactoryService (existing path)      │
│   • exchangeIn(token, amount, share, …) on proxy (existing ABI)    │
│   • exchangeOut(…) / exchangeInManyToOne / exchangeOutOneToMany      │
│   • preview*, position import, rebalanceLiquidReserve               │
│   • NEW: placeWing(side, saltIndex), consolidate(saltIndex),        │
│          wings(), wing(side), wingLiquidity(side)                   │
└───────────────────────────┬────────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────────┐
│ UniswapV4UpperLowerWingsStandardExchangeVault (diamond)             │
│  • FullSpread facets preserved (existing)                           │
│  • NEW WingsFacet (place / consolidate / observe)                   │
│  • Shared facets: ERC20+5267+2612, MultiAssetBasic+Standard         │
│  • same proxy = LP; same selectors, same errors                     │
│  • 1 center (existing full-range) + ≤1 upper + ≤1 lower             │
│  • local sleeve = F0 + F1 (live ERC-20 custody)                     │
└───────────────────────────┬────────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────────┐
│ Uniswap V4 PoolManager (single pool)                               │
│  • pool currency0 = token0, currency1 = token1 (binding order)      │
│  • positions: center + upper + lower (no hook)                      │
└────────────────────────────────────────────────────────────────────┘
```

## 5. Package layout (proposed, normative when accepted)

```text
contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/
  UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md   # this file
  interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol
  UniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.sol
  UniswapV4UpperLowerWingsStandardExchangeVault_FactoryService.sol
  UniswapV4UpperLowerWingsStandardExchangeVaultRepo.sol
  UniswapV4UpperLowerWingsStandardExchangeVaultCommon.sol
  UniswapV4UpperLowerWingsStandardExchangeVaultWingsFacet.sol
  facets/UniswapV4UpperLowerWingsStandardExchangeVaultWingsFacet.sol
  test/harness/UniswapV4UpperLowerWingsStandardExchangeVaultConsumingHook.sol
  test/harness/UniswapV4UpperLowerWingsStandardExchangeVaultProductionBindingProbe.sol
```

## 6. Public surface (proposed sketch)

### 6.1 Existing FullSpread surface (preserved verbatim)
Selectors, errors, events, previews, and lifecycle inherited from the existing FullSpread hookless surface.

### 6.2 New wings surface (sketch only — implementation plan owns the detail)

```text
placeWing(uint8 side, uint256 saltIndex) internal;  // permissionless keeper; only valid when book is healthy
consolidateWing(uint8 side) external;                // permissionless; bounded per call (1 wing)
wings() external view returns (WingInfo[2] memory);  // (side, tickLower, tickUpper, liquidity, feesOwed)
wing(uint8 side) external view returns (WingInfo memory);
wingLiquidity(uint8 side) external view returns (uint128);
```

Errors: `WingAlreadyPlaced`, `WingNotPlaced`, `WingInRange`, `WingInvalidSide`, `WingOutOfUsableRange`. No selector reuses a FullSpread selector or name.

Events: `WingPlaced(side, tickLower, tickUpper, liquidity)`, `WingConsolidated(side, removedLiquidity, addedToCenter, residual0, residual1)`. **No** `LiquidityAdded`/`LiquidityRemoved` events re-emitted by wing ops; those are FullSpread-surfaced.

## 7. DoD (deferred to implementation plan)

This PRD **does not** contain a DoD. DoD requires a measured acceptance matrix; per CLAUDE non-negotiables (item 8) and the Hookless refactor PRD §8 ("performance … before tuning, using matched compiler settings, fresh artifacts"), no gas or pass/fail claim is asserted by this PRD.

## 8. Explicit owner decisions (OD register)

The PRD **does not** invent any of the following by consensus. Each is an unresolved decision for the owner.

- **OD-1. Single-token admission rule when `B_other == 0`.** Options: (a) NAV with explicit admission charge; (b) blocked-state linear (F1) only; (c) **defer to a future PRD** (do not enable single-token issuance in v1); (d) require dual-only first mint and disallow single-token entries even on a one-sided book. The PRD recommends **(d)**: v1 disallows single-token entries, matching the existing F0 dual-only discipline. This is the smallest-change path and is most consistent with the FullSpread `reserveOfToken` / `deployedReserve` discipline.
- **OD-2. Wing gap/width policy.** Numeric values not proposed.
- **OD-3. LP symbol prefix.** Per skill rule, full Solidity type names; LP symbol PRD-locked. No prefix proposed here.
- **OD-4. Local liquidity sleeve design.** Two readings exist: (i) the existing `F_0 + F_1` is already the sleeve and needs no new position; (ii) the sleeve is a **separate inner V4 position** the vault owns and deploys when the outer PM is unlocked, which requires a second `pm.unlock` — **forbidden by the no-nested-unlock law** unless an owner ruling approves a new internal-account model. The PRD recommends **(i)**: no new inner position; reuse existing sleeve; document the no-nested-unlock constraint. If (ii) is chosen, this PRD is incomplete and a follow-up is required.
- **OD-5. Consolidation safety under keeper failure.** Options: (a) permissionless, current read; (b) bounded-incentive; (c) cooldown. The PRD recommends **(a)**.
- **OD-6. Historical `35f47b5195d16fdf90fd7c032a10f8d3b916fd90` evidence.** Treated as unverified by the user. The PRD does **not** adopt or reject the three-wing claim; the user notes that restored `92cdf89a^` is center-only full-range. The PRD recommends that no historical commit is restored, no historical branch is rebased, and the new code is written from a clean greenfield with no copy-paste from any prior commit.
- **OD-7. DETFs composing eligible SE vaults or bare tokens (owner clarification).** The PRD accepts the clarification; composition rules are unchanged from DETF I/O routing PRD §16. **No** new binding is added for this round; the new vault is a new package the DETF surface may bind like any other.
- **OD-8. Gas/throughput claim for the new path.** No claim. The user's prior **~1.28M** whole-test gas figure is **not adopted** because (a) the 35f47b5 commit is not authoritative, (b) the restored 92cdf89a^ is center-only and measures center-only, not wings. Acceptance requires a measured run on the new bytecode under the same test conditions.
- **OD-9. Weighted 1..8 buffered-leg composition.** The PRD names the **consumer matrix** (below) but does not assert compatibility. Each Weighted leg pattern (1..8 buffered) requires its own measured run.
- **OD-10. Subcall harness gas vs whole-test transaction gas.** The PRD distinguishes the two (see §11). No claim is made for either. Whole-transaction gas must be measured on the deployed bytecode under the actual chain cap (`foundry.toml:38` `gas_limit = 30000000000` is a Foundry ceiling, **not a chain measurement**).

## 9. Required consumer / adversarial matrix (named, not asserted)

| Surface | Required coverage |
|---|---|
| **FullSpread family regression** | Hookless + PonsFamily unchanged; full R1–R11 matrix must pass on the unchanged code. |
| **DETF binding** | One Orbit-grade + one Pons-grade + one V4-only DETF can bind this new vault via DETF I/O routing law. |
| **Weighted 1..8 buffered legs** | Each `(n=1..8, k buffered, 0..n-k raw)` cell must round-trip on the new bytecode; **no adoption claim**, only named as required matrix. |
| **Center-only** | 1 center, 0 wings — must round-trip identical to the existing FullSpread behavior. |
| **Center + 1 lower** | Token0 deposit → lower wing; consolidation into center when price crosses. |
| **Center + 1 upper** | Symmetric. |
| **Center + 2 wings** | Both wings placed. |
| **Sleeve — already-unlocked** | Outer PM unlocked; vault must not call `pm.unlock` again. Reject nested unlock. |
| **Sleeve — partial cover** | Sleeve exhausted; revert atomically; no part-payment. |
| **Adversarial catalog** | A0/L/M/N/O (`indexedex-adversarial-testing`), plus: dust spam (1 wei wings, if permitted), reentrancy via wing, donation dilution, salt collision, keeper sandwich, fee-double-count across positions, exact-tick boundary, off-by-one on `tickSpacing` rounding. |
| **Chain-appropriate transaction gas** | Measured on every supported chain (Ethereum, Base, RH 4663). Subcall harness gas reported separately from whole-tx gas. **No claim is asserted by this PRD.** |

## 10. Distinguishing historical behavior from new design

| Claim | Verdict |
|---|---|
| Prior commit `35f47b5195d16fdf90fd7c032a10f8d3b916fd90` is a three-wing implementation. | **Unverified.** No source has been read from that commit in this pass; it is named only by conversation evidence. Restored `92cdf89a^` is center-only full-range (per user). The PRD **does not** restore the alleged three-wing design and **does not** copy from any historical commit. |
| Prior whole-test gas ~1.28M. | **Unverified and unadopted.** A 1.28M figure is meaningless without knowing which code was measured, on which chain, with which fixture, and with which consumption. PRD §9 names the matrix; §8 OD-8 defers the figure. |
| Restored `92cdf89a^` center-only full-range is the production baseline. | **Adopted** as the de facto starting point — but only the **observable fact** that FullSpread is center-only; not a claim that this commit is blessed. |
| Existing FullSpread R1–R11 selector matrix is law. | **Adopted** from `UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md:170–193`. |
| Existing protection constants (1 bp, 50 bp, 25 bp, 10 bp) are law. | **Adopted.** |
| Forbidden list (FoT, rebasing, scaled reserve, fee waiver, NAV, oracle, share-mint-on-consolidate) is law. | **Adopted** from this PRD §2.2, §3 UD17, and `indexedex-adversarial-testing` catalog. |
| 31M/32M gas ceiling. | **Adopted** as a Foundry ceiling only; chain measurement is named required, not asserted. |
| Solidity 0.8.35, optimizer 1, no `via_ir`. | **Adopted** from `foundry.toml:29–36`. |

## 11. Chain-appropriate gas vs subcall harness gas

- **Whole-transaction gas** = `forge test --gas-report` on a hermetic matrix, then on fork (Ethereum + Base + RH 4663). The PRD does not propose a target.
- **Subcall harness gas** = `forge test` with explicit gas snapshots on individual facets/delegate calls, e.g. `vm.startSnapshotGas("wings.place")` / `vm.stopSnapshotGas()`. Reported separately.
- **Chain ceiling** = `foundry.toml:38` `gas_limit = 30000000000` is a Foundry-side ceiling, not a chain-side measurement. The PRD names it as the Foundry ceiling and **does not** assert it is sufficient.
- The PRD requires both numbers, separated, on the deployed bytecode, in a measured run. **No pre-claim.**

## 12. Acceptance criteria for this PRD document (not for the product)

- A1. PRD does not modify any FullSpread source or test artifact.
- A2. PRD identifies the center, upper wing, lower wing, and the local liquidity sleeve explicitly.
- A3. PRD enumerates owner decisions OD-1 through OD-10 with no consensus default invented.
- A4. PRD preserves FullSpread's R1–R11 selector matrix, protection constants, sleeve discipline, and 31M/32M gas ceiling (as Foundry ceiling).
- A5. PRD does not assert gas, pass/fail, or compatibility.
- A6. PRD names the consumer and adversarial matrix without claiming the cells.
- A7. PRD distinguishes "restoring historical behavior" from "selecting a new design" and does not perform the former.
- A8. PRD does not contain an implementation plan, file map, or test plan.

## 13. Open evidence gaps (named)

- No source from commit `35f47b5…` has been read. Three-wing evidence is **unverified**.
- The 1.28M gas figure is unverified and unadopted.
- The current `UniswapV4UpperLowerWingsStandardExchangeVault` does not exist in the source tree (verified by directory listing at `contracts/vaults/standard/exchange/protocols/uniswap/v4/`, observed 2026-10-05: only `fullSpread/` subdirectory). The product is greenfield.
- No Context7 / web sources for V4 wings precedent were fetched in this independent pass; the user permitted but did not require them. Future plan and peer rounds may fetch them.
- Cross-peer review of this PRD will happen in a later round; this document is the independent first pass only.

---

*End of PRD first pass. Saved to `docs/research/uniswap-v4-upper-lower-wings-prd-2026-10-05/minimax-original.md`. No code, tests, shell, config, deploy, or instruction edits performed. Originals preserved. The owner-decision register OD-1..OD-10 is the blocking list; the implementation plan is out of scope for this document.*