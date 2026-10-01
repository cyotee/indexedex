# Grok — Uniswap v4 proportional zap-in PRD review

**Date:** 2026-09-27. **Reviewer:** Grok (xai/grok-4.7). **Document reviewed:** `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` (updated 2026-09-27). **Verdict:** Not ready to write an implementation plan until two owner questions are answered. Settled D1–D16 items below are not reopened.

## Assumptions

- This PRD wins on D1–D16 where it conflicts with older Uniswap V4 SE clauses. It does not reopen pretransfer, direct PoolManager, deployer hook assurance, immediate repeated rebalance, or full booking.
- “Fix the existing `exchangeIn` route” means that selector on the current product vault, not a license to edit the preserved tree cited in §15.
- No historical council artifacts were read.

## Facts

- Release authority is `CLAUDE.md` and `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md` D57–D59 / §24.7.1 (lines 97–99, 1153–1161): full-range positions, V2-style proportional ownership, both-token activation, later single-token deposits, sleeve operation during locks, and no new one-token NAV.
- The current product vault is FullSpread. Preservation law forbids editing `contracts/protocols/dexes/uniswap/v4/` (`UNISWAP_V4_STANDARD_EXCHANGE_CONSTANT_PRODUCT_ACCOUNTING_PRD.md` §7, R7, CP-01; package README). FullSpread `exchangeIn` still sleeve-mints, then best-effort add/remove rebalance, with no composition swap (`UniswapV4FullSpreadStandardExchangeVaultInBase.sol` 265–311).
- Dual positive deposits use `min(mulDiv)`; a one-sided deposit uses invariant growth (`StandardExchangeConstantProduct.sol` 37–64). Idle single-token deposits therefore do not match this PRD’s post-composition `min()` formula.
- Code sleeve target is `total * p / 1e18` (`UniswapV4FullSpreadStandardExchangeVaultCommon.sol` 358–360, 744–749). Deadband is `max(absolute floor, 5% of targetFree)`; floor is `1` if decimals ≤ 6, else `10^(decimals-6)` (362–381). Oracle `p` is WAD, stored 0 falls through, and `p > 1e18` reverts (`VaultFeeOracleQueryFacet.sol` 322–330; `VaultFeeOracleRepo.sol` 67–70). The FullSpread test type default is `0.2e18`.
- FullSpread sync writes `balanceOf` (`Common.sol` 610–616). Preserved sync writes economic totals, including deployed amounts and uncollected fees (`UniswapV4StandardExchangeCommon.sol` 605–623). Pretransfer law is `U = B − R`, contract callers only, exact-in refunds nothing (`BasicVaultCommon.sol` 80–105; pretransfer PRD §4).
- Local PoolManager is idle-locked; `unlock` reverts `AlreadyUnlocked` if already unlocked (`lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol` 46–56). Upstream Universal Router `main` `_checkV4PositionManagerCall` reverts `OnlyMintAllowed` for increase, increase-from-deltas, decrease, and burn (fetched 2026-09-27, `contracts/modules/V3ToV4Migrator.sol`). Direct PositionManager implements those actions. Default `foundry.toml`: solc 0.8.35, optimizer runs 1, `via_ir = false`.
- `F = p*D` is the same policy as `targetFree = floor(T*p/(1e18+p))` when `T = D+F`. The 100 deployed / 40 free example at 20% ends at `116 2/3` deployed and `23 1/3` free. That arithmetic is correct.

## Inference

- §15’s preserved-file list would send a plan at the frozen tree. Higher law already selects FullSpread, or a new CREATE3 identity if those facet bytecodes are frozen. That is a PRD defect, not permission to edit preserved sources.
- “Blocked deposits retain the existing sleeve-only behavior” specifies placement, not issuance. Today’s issuance is invariant growth. Applying §6.3 `min()` to a one-sided credit mints 0 and breaks D59. Constant-product Q2’s internal book settlement is not specified here.
- The 1bp tolerance is accepted; the epsilon that includes share flooring is labeled “proposed” (§7). Including flooring rejects many small deposits, because integer `min()` loss often exceeds 1bp. That collides with preserved single-token deposits unless those reverts are accepted.
- D7’s “credit the entire contribution” holds only when ratios match within tolerance. `min()` donates the excess side. That is consistent only if a failed alignment reverts.
- `UniswapV4ZapQuoter` quotes a pool-position zap (`UniswapV4FullSpreadStandardExchangeVaultQuoteService.sol` 152–173). D5 requires the post-swap incumbent whole-book ratio. Those differ when sleeve or fees skew the book.
- Buffer PRD D17/D27/D28 and constant-product R7 conflict with this formula, deposit order, and public-rebalance swaps. This PRD wins on D1–D16. The plan must say so. Docs reconciliation is a separate task.

## Speculation

- Repeated 25bp public swaps can move price with no cumulative cap. The owner accepted that (D10–D12, §8–§9). Not reopened. A per-call progress rule can still forbid useless churn.

## Owner questions (blockers)

1. **Locked single-token issuance.** When PoolManager is already unlocked, which mint is required? (A) Keep today’s invariant-growth sleeve mint, explicitly not equivalent to the idle zap. (B) Internally settle against the complete book with the declared constant-product process, using only funded local inventory, then the same `min()` mint; revert if the other leg cannot be funded. (C) Revert locked single-token deposits. Recommend (B): it satisfies D58/D59 and §24.7.1 without nested unlock or a new NAV. (A) needs an explicit D58 exception.
2. **What the 1bp bound measures.** (A) Composition-ratio error before share flooring, with separate dust and minimum-share reverts. (B) The proposed epsilon, including flooring, and no dust exception, so sub-threshold deposits revert. Recommend (A) unless the owner wants (B).

Non-blocking confirm: target FullSpread or a successor package, not in-place edits to `contracts/protocols/dexes/uniswap/v4/`. Proceed on that assumption if unanswered.

## Leave to planning

- Immutable working limits of 25/50/10 bp, plus the chosen 1bp rule. No new vault admin. Do not overload `liquidReservePercentage`.
- Fixed-point solver for the post-swap book ratio, bounded steps, overflow-safe compares, and a zero-reserve revert.
- Public-repair stop rule: sleeve deadband and internal book-vs-pool deployability, judged per call. No cooldown, quota, or cumulative budget.
- Deposit path: caller-funded composition swap, then add/remove toward `floor(T*p/(1e18+p))`, then mint. Do not also run a swapping tail-rebalance. Non-deposit tail-rebalance stays add/remove-only.
- Quotes must match that route. Blocked quotes must not imply an unlock. Hook quotes are not exact.
- Keep FullSpread `R = balanceOf`. Do not copy preserved economic-total sync. Count `E` in ownership, not in `T`. Collect fees once.
- Multi routes get no new composition swap. Imbalanced dual input keeps the `min()` donation.
- Do not change shared V3 math or migrate instances. Use an execution delegate if size requires it. Production-first tests; no SUT mocks.

## Settled — do not reopen

Pretransfer provenance and the contract-caller guard; direct PoolManager; deployer hook assurance; immediate repeated rebalance; full local booking; dual-token activation; no Universal Router migration; no in-place migration.

## Gaps and confidence

Code and local compiler/lock facts: high. Universal Router mint-only check: high for upstream `main` on 2026-09-27, not a deployment pin. Context7 described unlock sessions but did not quote `AlreadyUnlocked`; local `PoolManager.sol` did. Council artifacts were not read. Tests were not run. Whether FullSpread CREATE3 bytecode is already frozen on a target chain was not proven. Agreement or later passing tests would not prove security or economic soundness.

**Saved:** `docs/research/uniswap-v4-zapin-prd-review-2026-09-27/grok-original.md`
