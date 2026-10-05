# MiniMax M3 — cross-review of remediation proposals (≤650 words)

- **Inputs read:** `remediation/astra-original.md`, `remediation/grok-original.md`, `remediation/kimi-original.md` (untrusted attributed proposals; not authority). No peer cross-review artifacts read. Originals preserved at `remediation/{astra,grok,kimi,minimax}-original.md`.
- **Method:** peer findings treated as proposals; primary code re-checked at cited paths.
- **Cross-checks against code:**
  - `_requirePostUnderRadius` reads rated `_effectiveWad()` unconditionally (`Common.sol:483–488`); called at `:1245`. Not in my R3 try/catch set. Grok #5 names it. Kimi R6 names the L2/sync sites but misses this one.
  - `_faceForClaim` binary search at `ExitQuoteLib.sol:347–374` is called inside `_planDeposit` to derive `used[i]` from `desired` (rated-effective). Loop bound ≤ 8 probes + log₂ (lines 357–371). Bound holds after R1 if the *target* `desired` switches from rated to raw se-share count (the loop input changes, the bound does not).
  - `_claimIn` face-amount fallback at `ExitQuoteLib.sol:379–381` (`minted == 0 ? amount : amount` and `rated == 0 ? amount : rated`) is the unit-mismatch hazard. Removing both is safe: zero preview → revert is the correct outcome under raw-share mint.

## 1. Specific challenges

| Peer proposal | Issue | Verdict |
|---|---|---|
| Grok #5 "newReserve = oldReserve × newInventory / oldInventory" stale-scaled fallback | This **is** a scaled reserve fallback. User explicitly forbids unauthorized stale/scaled-reserve fallback. | **Reject.** No stale scaling. L2/sync must cache (no-op on rate failure) and not invent a scaled reserve. |
| My R3: try/catch around `_maybeMintProtocolFee` / `_snapshotKLastIfFeeOn` that skips fee mint on dead rate | Kimi R6 is right: this is a behavior change (silent fee skip for one block) and should be **owner-ruled**, not defaulted. | **Demote to OD-2** (deferred). Default keeps fail-closed on fee reads. |
| My R3 try/catch around `_recomputeL2` / `_syncVaultReserves` | Reads `_effectiveWad()` (rated) unconditionally. Per D60 sphere invariant, L_SQUARED must stay rated; on rate failure, cache-only is sound. | **Accept** as default scope (no fee change, no scaling). Extend to include `_requirePostUnderRadius` (`Common.sol:483–488`, called `:1245`) — same try/cache. |
| Astra R3 / Kimi R3: partial sphere-NAV uses rated `R`; raw inventory cannot simply reuse rated radius | Correct. Sphere-NAV (`Math.sol:380–391`, `Common.sol:1633–1657`) is fundamentally a rated-domain formula. Forcing raw inventory here would invent a new invariant. | **Defer to OD-3.** Default: keep partial path on rated R (no change beyond unit-conversion numerator/denominator); flag for owner ruling. |
| Astra R2 / Kimi R1 "ceil required inventory for m" | Current full-book `used*` is floor (`Math.fullBookUsedWad`). Floor favors existing LPs (under-mint). Changing to ceil would over-pull from user. | **Reject.** Stay floor on both mint and pull (consistent, conservative). |
| Grok "≤1 wei" bound on raw vs rated mint drift | Floor-mulDiv drift is not bounded at ≤ 1 wei for non-identity rate; example in earlier round showed `3×5e17/1e18=1`, `6×5e17/1e18=3` (ratio `1/3` vs raw `1/2`). | **Reject ≤1 wei claim.** Test must quantify drift across the 0/1/2/3-SE × rate `{0.5e18, 1e18, 1.5e18, 2e18}` matrix; report observed max, not assume. |
| "Unchanged zap result" if rates change | Zap split is sphere-rated; rate change MUST change `q.saleJ`/`q.saleK` (and therefore `q.offered`). The terminal mint uses raw post-swap share count, so the minted amount is rate-independent at a single post-state. | **Distinguish:** split pricing changes with rate (correct, swap invariant); terminal mint is rate-independent (correct, raw LP law). Tests must assert both per rate row. |
| Kimi "weighted balance diverges from se balance" loop bound | Inventory loop bounds (`_faceForClaim` ≤8, `_invertBufferForEffective` ≤64) are independent of rate policy. | **Accept Kimi:** bounds preserved by construction. |
| Grok #4 / Kimi R4 SE buffer/unwrap preservation | All three agree; matches D60 buffer rule. | **Accept.** |

## 2. Approved recommendation (default scope)

| ID | Change | File | Lines |
|---|---|---|---|
| R1 | Full-book share/used math on raw share count | `O/Common.sol` | `_fullBookSharesUsed` 1066–1090; `_partialSharesUsed`/`_partialUsed`/`_partialMinShares` 1093–1184 |
| R2 | Zap terminal mint on raw post-swap share count; zap split stays rated | `O/ExitQuoteLib.sol` | `_planDeposit` 272–295; `_claimIn` 376–382 (drop both face-fallback branches); `_faceForClaim` 347–374 (input switches from rated-effective to raw-share-delta) |
| R3 | Partial-join numerator/denominator both raw (share count); **rating R and `_capFaceUnderRadius` stay rated** | `O/Common.sol` | 1116–1184; 1633–1657 |
| R4 | SE buffer/unwrap execution unchanged | all | 514–617, 581–598, 620–625 |
| R5 | `_proRataOut`/`_burnAndPay` byte-identity preserved | `O/Common.sol` | 1287–1368 |
| R6 | Try/catch + cache-only on rate failure for L2/sync/radius. **No fee skip, no scaled reserve.** | `O/Common.sol` | `_recomputeL2` 472–480; `_syncVaultReserves` 459–469; `_requirePostUnderRadius` 483–488 |

## 3. Deferred owner decisions (NOT in default scope)

- **OD-1.** In-kind recovery route / failure-tolerant exit bookkeeping (fail-closed is default).
- **OD-2.** Skip protocol-fee mint on dead rate (Kimi R6 / my R3 disagreement; default = fail-closed, no fee change).
- **OD-3.** Partial sphere-NAV pricing rule (rated R vs raw-R sphere); default = hold partial economic change pending decision (Astra R3).
- **OD-4.** Scaled stale-reserve fallback (Grok #5); default = reject.
- **OD-5.** Rated bootstrap / fee redesign; default = preserved (D63).
- **OD-6.** First-mint radius, `kLast` rated measure, Weighted inventory, Hookless analytic, `foundry.toml:38` ceiling; preserved.

## 4. Test criteria (must be measured, not asserted)

- Rate-independence differential: rates `{0.5e18, 1e18, 1.5e18, 2e18}` × decimals rows; mint delta vs raw-share ratio must be reported (no ≤1 wei claim).
- Conservation: floor pulls ≤ used shares; existing-LP non-dilution beyond the SE buffering quote.
- Preview fidelity: `previewDepositSingle`/`previewAddLiquidity`/`previewDepositFlexible` bit-exact vs execution at same `R`/oracle/SE state.
- Exit byte-identity vs pre-change `_proRataOut` outputs.
- Liveness pin: dead/short/zero provider — fee-on/fee-off matrix; fee-on must still revert (default), L2/sync/radius must cache (no revert), `_requirePostUnderRadius` must not brick.
- Swap quote byte-identity for the rated path; zap split must change with rate.
- Matrix 0/1/2/3 SE × RP on/off × fee on/off × kLast 0/>0.
- Pre-existing unrelated failures (Hookless analytic compile errors; FullSpread TestBase; `ReleaseRegression.t.sol`) **must not** be relabeled passing or attributed to this change.

## 5. Anti-patterns (carry forward)

No new ABI/storage/selectors; no `via_ir`; no `new` SUT; no mocked provider; do not touch Weighted/Hookless/`foundry.toml`/family PRDs; do not zero L_SQUARED/kLast on failure; no "old planner fits gas" claim without measurement.

---

*Saved to `remediation/minimax-cross-review.md`. Originals preserved. No code/tests/config/shell executed.*