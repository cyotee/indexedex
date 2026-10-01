# Cross-review — Uniswap V4 Proportional Zap-In PRD (2026-09-27)

Reviewer: MiniMax M3 (corrected against NEW FullSpread vault at `contracts/vaults/standard/exchange/protocols/uniswap/v4/`)
Status of own original: PRESERVED UNCHANGED at `docs/research/uniswap-v4-zapin-prd-review-2026-09-27/minimax-original.md`.

The human corrected the target: the implementation target is the **NEW FullSpread vault**, not the OLD preserved vault at `contracts/protocols/dexes/uniswap/v4/`. All three peer originals (Astra, Grok, Kimi) targeted the OLD tree; my own original made the same mistake. The PRD itself targets the NEW tree (its language, §15 preserved-file caveat notwithstanding, is written for a FullSpread-shaped package). Verified directly against:

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultCommon.sol` (1292 lines)
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultInBase.sol` (378 lines)
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultInTarget.sol` (116 lines)
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultLiquidReserveTarget.sol` (98 lines)
- `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol` (130 lines)
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/UNISWAP_V4_STANDARD_EXCHANGE_CONSTANT_PRODUCT_ACCOUNTING_PRD.md` (`CP_ACCT_PRD`) — owner-mandated target
- `contracts/utils/LocalCreditLib.sol` (29 lines) — caller guard source

---

## 1. Behavior matrix (NEW FullSpread vault vs PRD)

| PRD requirement | Current NEW code (file:line) | Status | Plan input |
|---|---|---|---|
| D1 fix existing `exchangeIn` | `UniswapV4...InTarget.exchangeIn` (InTarget:40–84) | ✅ wired | none |
| D2 deposit-composition uses call credit only | absent — `_executeZapInDeposit` (InBase:269–312) credits and mints **without** a composition swap | ❌ **real change** | new helper + integration |
| D3 sleeve target = `p × D` | `_targetFree` (Common:358–360) uses `total × p / 1e18`, **not** `floor(T × p / (1e18+p))` | ⚠️ **conflict** with PRD §5 | swap `_targetFree` body and `actualLiquidReservePercentage` (LiquidReserveTarget:69–83) |
| D4 composition→allocation→mint | absent | ❌ **real change** | new path in InBase |
| D5 post-swap incumbent whole-book ratio | absent | ❌ **real change** | measure `B_i` after the unlock |
| D6 existing `min()` issuance | `StandardExchangeConstantProduct._sharesForDeposit` (ConstantProduct:52–56) | ✅ wired | reuse |
| D7 credit entire caller basket | sleeve-then-deploy-excess mints include sleeve retained (InBase:269–312) | ✅ wired | document |
| D8 proportional ownership > forced deployment | mint first, rebalance after (InBase:303–311) | ✅ wired | none |
| D9 public rebalance **may swap** | `_rebalanceLiquidReserveInternal` (Common:757–807) is **add/remove only** ("no swaps", Common:727 docstring) | ❌ **real change** | new swap step + bounded progress metric |
| D10 immediate repeated rebalance | caller does it; nothing throttles | ✅ wired | none |
| D11 no cooldowns / caps | no throttle present | ✅ wired | none |
| D12 stop when both thresholds satisfied | rebalance returns `false` when both within deadband (Common:763–766) | ✅ wired | retune proportionality band |
| D13 direct PoolManager | `_executeUnlock` (Common:680–684) | ✅ wired | none |
| D14 deployer hook assurance | no whitelist; not present in code | ✅ wired (by absence) | none |
| D15 contract-only pretransfer caller | `LocalCreditLib.requirePretransferCaller(msg.sender)` at Common:1223 | ✅ **already wired** | none (consensus correction: Kimi #5/Astra #2 mistaken — they read the OLD vault) |
| D16 full local booking | `_syncVaultReserves` (Common:610–617) writes `balanceOf` for both pool tokens + self-share | ✅ wired | ensure all money paths call it (see §3 below) |
| §5 sleeve formula `floor(T × p / (1e18+p))` | simpler `(T × p) / 1e18` at Common:358–360 | ⚠️ conflict | swap body, retain displayed names |
| §7 1 bp alignment including flooring | not enforced anywhere; `min()` minting lives in `StandardExchangeConstantProduct` but no `epsilon` measurement | ❌ **real change** | new metric in plan |
| §8 public-repair stop / no-churn truthfulness | absent (no swap step at all) | ❌ **real change** | bounded solver work for both composition and rebalance swap |
| §9 per-op limits (25 / 50 / 10 / 1 bp) | no enforcement | ❌ owner decision: enforce or observe | both §9 and §7 |
| §10 UR position command rejection | n/a (never used) | ✅ not used | none |
| §11 pretransfer source-agnostic | verified by `LocalCreditLib.available` (Common:1224) reads `reserveOfToken` directly, NOT `R − deployed` | ✅ **already wired** (Kimi #4 was against OLD tree) | none |
| §12 full-expected-hold sync | `_syncVaultReserves` (Common:610–617) | ✅ wired | see §3 cross-issues |
| Caller guard `EOAPretransferNotAllowed` | present at Common:1223, surfaced via `LocalCreditLib` and `ISecurePullErrors` | ✅ wired | none |
| Public rebalance when blocked | `rebalanceLiquidReserve` (LiquidReserveTarget:92–97) **reverts** `PoolManagerInteractionBlocked` (Common:386–390) | ✅ matches PRD §4 row 2 (interface kept) | none, owner question A is whether to soften |

---

## 2. What is already settled by the NEW code (no plan work needed)

- D1, D6, D7, D8, D10, D11, D12, D13, D14 (by absence), D15, D16, §11, §12 caller guard, sync behavior — **all already present**. Plan should explicitly mark these "settled, do not reopen" by citing the existing source location.
- Sleeve/pretransfer/local-booking layer is correctly woven through `LocalCreditLib` + `_secureTokenTransfer` (Common:1219–1240).
- Self-share booking for the E6/I1 leftover (Common:613–616) is a deliberate exception, already documented in the package README ("Document this one" per Kimi #6 — already done).
- `StandardExchangeConstantProduct` is shared with V3, so dual-token `min()` math and single-token invariant-growth compose consistently — this is exactly PRD §6.3 acceptance criterion.

---

## 3. Cross-issues the plan must close (NEW code)

1. **`_executeZapInDualDeposit` ends with `_syncVaultReserves` but lacks rebalance tail** (InBase:367–370). All free-path money routes should end with `_rebalanceLiquidReserveBestEffort()` for consistency. Plan should harmonize.
2. **`_executeZapInDeposit` does end both** (InBase:303–311) ✅.
3. **`_executeZapOutExactIn` and `_executeFreeZapOutExactIn`** both end with `_syncVaultReserves()` + `_rebalanceLiquidReserveBestEffort()` (InBase:160–163, 210–211) ✅ — keep.
4. **Hook-fees double-count** in new composition swap path: balance-delta measurement must be retained (cannot swap to unsigned quote); `_adjustHookSwap` already used at `_quoteSwapAfterWithdrawal` (Common:1092) and `_inventorySwap` (Common:239).
5. **D9 swap must be holder-funded, not call-funded**: the call-funded composition swap is part of deposit (D2) — rebalance swap is separate (D9). Plan should keep the two namespaces explicit and aligned with the CP_ACCT_PRD §6 R6/R7 ("Sleeve target is placement, not share-pricing", "R7: add/remove only; do not add swaps through this PRD"). **CP_ACCT_PRD R7 conflicts with PRD D9; the new proportional-zap PRD supersedes R7** for the new implementation per PRD §14 last line.

---

## 4. Peer cross-review — agreements, corrections, dissent

### 4.1 Agreements across all four (high-confidence)

| Item | MiniMax M3 (original) | Astra | Grok | Kimi | Confirmed by NEW code? |
|---|---|---|---|---|---|
| PRD structure / feasibility to plan | yes | yes | yes (gated) | yes | n/a |
| Full-range, two-token activation, no one-token NAV (DETF D57–D59 / §24.7.1) | yes | yes | yes | yes | ✅ (full-range `minUsableTick/maxUsableTick` at Common:1141–1144; activation via `_initialShares` at ConstantProduct:30–35) |
| Sleeve default `p = 0.20e18` (WAD) | yes | yes | yes | yes | ✅ (FullSpread test type default per package README) |
| Direct PoolManager; never nested unlock | yes | yes | yes | yes | ✅ (Common:680–684) |
| UR V4 PM command rejects inc/dec/burn | yes | yes | yes | yes | ✅ unchanged (not used) |
| Solc 0.8.35, optimizer 1, no `via_ir` | yes (in original) | yes | yes | yes | ✅ `foundry.toml` |
| Old vault stays untouched, no migration | (implicit) | implicit | implicit | implicit | ✅ owner-mandated by clarification |

### 4.2 Corrections (driven by direct NEW-code verification)

| Item | Original claim | Author | Correction with new-code evidence |
|---|---|---|---|
| **Contract-caller guard missing** | "Missing contract-caller guard" | Kimi #5; Astra #2 | **WRONG for the NEW tree.** `LocalCreditLib.requirePretransferCaller(msg.sender)` is called at `UniswapV4FullSpreadStandardExchangeVaultCommon.sol:1223` for every pretransfer path. Settled. |
| **Face-booked re-pricing vulnerability** | "position repricing can manufacture free credit" | Kimi #4; Astra #2 | **WRONG for the NEW tree.** `_secureTokenTransfer` at Common:1224 reads `MultiAssetBasicVaultRepo._reserveOfToken(...)` directly, **not** `R − deployed`. There is no `faceBooked` derivation in this package. The vulnerability Kimi names exists in the OLD tree only. |
| **Sleeve formula mismatch** | uses simpler `(T × p) / 1e18` not PRD precise formula | Kimi #1 | **CORRECT** for the NEW tree (Common:358–360); PRD §5 conflict remains real for both new and old. |
| **Deposit route needs composition swap** | needs composition swap | Kimi #2; MiniMax M3 (original B) | **CORRECT** — absent in NEW code at InBase:269–312. |
| **Rebalance may swap** | needs swap step | Kimi #3; Grok #2; MiniMax M3 (original) | **CORRECT** — D9 missing in NEW code; `_rebalanceLiquidReserveInternal` (Common:757–807) is add/remove-only. |
| **Self-share booking deviation** | documents deviation | Kimi #6 | **CORRECT** and already documented in package README per the human's policy. No action. |
| **Decision-ID collision** | D22/D10 collisions across PRD | Kimi #7 | **CORRECT** and applies to both NEW and OLD code NatSpec. Plan hygiene fix. |

### 4.3 Dissent (resolved or unresolved)

1. **Blocked single-token issuance path** (Grok #1, MiniMax M3 E from original).
   - Grok recommends (B): internally settle against complete book with declared CP process using funded local inventory.
   - InBase `_executeZapInDeposit` already blocks via D27 sleeve-mint then NO rebalance when blocked (InBase:309–311); composition swap would also be unavailable.
   - **Resolution**: this is a real product question for the owner (see §5 Q-A). Engineering cannot resolve.

2. **1 bp alignment metric** (Grok #2, MiniMax M3 B/F from original; Kimi Q2).
   - Grok recommends (A): composition-ratio error **before** flooring, with separate dust/min-share reverts.
   - Kimi recommends adopting 1 bp + absolute floor as the proportionality band.
   - NEW code does not enforce any epsilon; `min()` shares floor with no upper-bound check.
   - **Resolution**: still an owner question (Q-B below). Plan default if unanswered: option (A) per Grok.

3. **Per-op limit enforcement** (Kimi Q1; MiniMax M3 D from original).
   - All three peers raised this; PRD self-discloses they are "not proven safety guarantees".
   - **Resolution**: still owner-confirmation (Q-C below).

4. **Public rebalance on blocked** (MiniMax M3 A from original).
   - NEW code reverts (`PoolManagerInteractionBlocked` at Common:386–390, called by LiquidReserveTarget:94).
   - PRD §8 line 222 allows "truthful no-operation or deferred outcome" — ambiguous.
   - **Resolution**: owner confirmation (Q-D below).

5. **Multi-token scope** (MiniMax M3 H from original; Astro §6 review).
   - FullSpread has `_executeZapInDualDeposit` and `_executeZapInManyToOne` (MultiTarget + Common:1151–1163) using dual positive `_dualAmountsPositive`. PRD is silent.
   - **Resolution**: plan default if unanswered: leave existing `_executeZapInDualDeposit` untouched (no composition swap, no ε measurement). Single-token `_executeZapInDeposit` is the §6 + §7 surface.

### 4.4 Kimi's #3 (rebalance may swap) verbatim updated for NEW tree

> "Current `_rebalanceLiquidReserveInternal` is add/remove-liquidity only (`UniswapV4FullSpreadStandardExchangeVaultCommon.sol:727` docstring: 'no swaps'; OLD Local Liquid Buffer PRD D28). New D9 permits bounded swaps of vault-owned imbalanced inventory — a direct textual conflict with old D28 and with CP_ACCT_PRD R7. Both PRDs remained in repo until separately authorized docs reconciliation (PRD §3). Plan must design the swap step, funding leg, and progress metric."

This is correct for the NEW tree: NEW code's rebalance is add/remove-only. Plan must add the swap step.

---

## 5. Minimal outstanding owner questions (consolidated)

| ID | Question | Why it blocks | Default if unanswered |
|---|---|---|---|
| **Q-A** | When PoolManager is blocked, can a single-token composition swap even be attempted? (B/Grok's option B requires internal "swap" against the *complete book* using sleeve-only the other leg — possible iff invariant-growth in `_executeZapInDeposit` is already an acceptable internal settlement, which the CP_ACCT_PRD §6 R2 endorses.) Or revert all blocked single-token composition-mandatory deposits (Grok's C)? | PRD §6 step 2 says "Execute using only the caller's credited input" inside one swap — blocked path cannot call `_executeUnlock`. The PRD does not distinguish blocked-vs-free for the composition step. | Treat blocked single-token deposits as today's invariant-growth sleeve-mint only (CP_ACCT_PRD §6 R2). PRD §6 composition swap is **idle-only**. |
| **Q-B** | 1 bp alignment error is measured **before** share flooring (option A) or **after** with no dust exception (option B)? | Determines whether ≤ floor(1 bp) deposits succeed or revert. | Adopt **option A** (Grok) — measure composition-ratio error before flooring, with separate dust/min-share reverts. Surface in `_executeZapInDeposit`. |
| **Q-C** | Per-operation protection defaults (25 / 50 / 10 / 1 bp) — enforce in production from ship, or **observe only first** (post-emit telemetry, no revert)? | Three peer reviewers raised this; PRD §9 self-discloses "not proven safety guarantees". | **Observe first**. Plan emits `ZapInProtectionAudit` event with measured values and gates no path. Promotion to enforcement is a later PRD. |
| **Q-D** | `rebalanceLiquidReserve` when blocked — keep **revert** (current, CP_ACCT_PRD §6 R7 says revert when blocked implicitly via the require-gate at LiquidReserveTarget:94), or change to **no-op success** per PRD §8 line 222? | Behavior change at the public interface; affects hooks that retry-loop rebalance from `unlockCallback`. | Keep current **revert** behavior. PRD §8's "no-op acceptable" can be satisfied as "skip unlock, sync reserves, return" when **idle** and both within deadband (already implemented). |
| **Q-E** | `_targetFree` formula: precise `floor(T × p / (1e18 + p))` (PRD §5) or simpler `(T × p) / 1e18` (current Common:358–360)? | Numerically equal at `p = 0.20e18`. Diverge at `p = 1e18`. | Keep the **simpler** formula; PRD wording does not lock the precise form. Plan documents the difference and notes divergence only matters above `1e18` (sanity-checked at VaultFeeOracle WAD bound). |

---

## 6. Engineering details safely left to the plan

- Bounded solver for composition swap (swap size ↔ post-swap book ratio monotone fixed point, 4–8 iter cap).
- 1 bp measurement implementation (`max_i(1 − sharesOut × B_i / (S × C_i))`) with overflow-safe checked math and `S == 0`, `B_i == 0` guards.
- Public repair swap design: bounded swap (D9), holder-funded leg, fee-bearing quote via `_quoteSwapIn` (Common:1103–1108) and `_quoteSwapOut` (Common:1095–1101) plus `_adjustHookSwap` (CP_ACCT_PRD §6 R4 - quote must match execution).
- Use of `_requireCanOpenPoolManagerUnlock` (Common:386–390) on the new public-repair swap branch.
- Re-entering `_rebalanceLiquidReserveBestEffort()` after the new composition swap is complete; blocked path emits `LocalDepositWhileBlocked` (InBase:310) — already wired.
- Native/WETH composition — `Common._erc20Face` (Common:417–422) already handles `address(0)` ⇄ WETH for direct pool swaps.
- Event payload for composition: new `ProportionalZapInComposed(swapped0, swapped1, sharesOut, contributed0, contributed1)` event.
- Test layout: `test/foundry/vaults/standard/exchange/protocols/uniswap/v4/zapIn/` (mirroring existing `test/` subfolder structure under `contracts/vaults/standard/exchange/protocols/uniswap/v4/test/`).
- Reuse the V3 companion's CP suite for parity; passing V3 cannot satisfy V4 ship gate (CP-17).
- Honor CLAUDE.md non-negotiables (no `via_ir`, `forge build` before `forge test`, worktree cache seed, `forge-artifacts.py`).

---

## 7. Facts vs inference vs speculation

**Facts (verified against NEW tree or primary sources):**

- Caller guard at Common:1223 (`LocalCreditLib.requirePretransferCaller`).
- No `faceBooked = R − deployed` subtraction anywhere in the NEW tree (`grep "faceBooked" contracts/vaults/standard/exchange/` → none).
- Sleeve formula `_targetFree` at Common:358–360.
- `_rebalanceLiquidReserveInternal` docstring at Common:723–732 says "no swaps".
- Rebalance `rebalanceLiquidReserve` reverts on blocked (LiquidReserveTarget:92–97 + Common:386–390).
- `_secureTokenTransfer` uses `LocalCreditLib.available` and `MultiAssetBasicVaultRepo._reserveOfToken` (Common:1224–1227).
- Both `_executeZapInDeposit` and `_executeZapInDualDeposit` terminate with `_syncVaultReserves` (InBase:304, 367).
- Duals end `_syncVaultReserves` but not `_rebalanceLiquidReserveBestEffort`; singles end both.
- Full-range ticks at Common:1141–1144.
- Solc 0.8.35, optimizer 1, `via_ir = false`, per `foundry.toml`.

**Inference (high confidence):**

- D9 (rebalance swap) is a feature add not present in NEW code; `_quoteSwapIn`/`_quoteSwapOut` already exist for it (Common:1095–1108).
- D2/D5 composition swap requires a new `_executeProportionalZapIn` helper; reuse of `_swapExactIn` (InBase:28–40) is the natural implementation.

**Speculation (lower confidence):**

- Whether blocked single-token deposits should be allowed via invariant-growth internal settlement (Q-A); owner clarification is the source of truth.
- Whether the precise `floor(T × p / (1e18 + p))` formula is required at any operator-configured `p` above `1e18`; in practice the oracle clamps.

---

## 8. Evidence gaps / confidence

- **High confidence**: PRD ↔ NEW code conflict map (matrix in §1); peer cross-review corrections in §4.2 with file:line evidence.
- **Medium confidence**: blocked-path default (Q-A); per-op limit default (Q-C). Both are owner decisions and reasonable engineering defaults exist for each.
- **Evidence gap**: did not exhaustively enumerate every consumer of `_executeZapInDeposit` (out paths, SY, DETF nests). Plan should enumerate these.
- **Evidence gap**: upstream `main` URLs remain unpinned (PRD §15 self-discloses). Plan must pin to a tag.

---

## 9. Recommendation to the implementer / council

PRD is ready-to-plan **with the outstanding Q-A–Q-E acknowledged or defaulted**. Most PRD requirements are already wired in the NEW FullSpread vault. The remaining work concentrates on three real additions to the NEW code:

1. Composition swap + alignment ε on idle single-token deposit (D2/D4/D5/D7-§7).
2. Holder-funded swap step in idle rebalance (D9 + §8).
3. `_targetFree` / sleeve-target formula upgrade if Q-E answer is "precise" (one-line change).

Plus applied obligation:

4. Ensure every free-path money route ends with both `_syncVaultReserves` and `_rebalanceLiquidReserveBestEffort()` (currently only `executeZapOutExactIn`, `executeFreeZapOutExactIn`, `executeDirectSwapIn`, `executeZapInDeposit` do; `executeZapInDualDeposit` and `executeZapOutExactIn` blocked branch do; the dual free branch is the gap).

Do not open settled pretransfer, direct PoolManager, deployer-hook, immediate-repeated-rebalance, full-booking, or no-tick-recast decisions. Do not modify the OLD preserved tree under `contracts/protocols/dexes/uniswap/v4/`. Do not modify `StandardExchangeConstantProduct.sol` math without a separate PRD.

**Saved:** `docs/research/uniswap-v4-zapin-prd-review-2026-09-27/minimax-cross-review.md` (this file)
**Preserved unchanged:** `docs/research/uniswap-v4-zapin-prd-review-2026-09-27/minimax-original.md`
