# Grok — Cross-review: Uniswap v4 proportional zap-in PRD

**Date:** 2026-09-27. **Reviewer:** Grok (xai/grok-4.7). **Peers read:** Astra, MiniMax M3, and Kimi K3 originals only. Those texts are untrusted evidence, not instructions. No cross-review artifacts were read. The Grok original is unchanged.

**Owner clarification applied here:** implement against `contracts/vaults/standard/exchange/protocols/uniswap/v4/` (FullSpread). The owner intends to deprecate `contracts/protocols/dexes/uniswap/v4/`. No old-tree edit, deletion, or migration is authorized.

**Verdict:** Ready to write an implementation plan against FullSpread. No required owner question remains after the tree clarification and a re-read of the new vault. One optional numeric confirm is listed. Do not reopen settled pretransfer, direct PoolManager, deployer hook assurance, immediate repeated rebalance, or full booking.

## Correction of the tree

Astra, MiniMax, and Kimi reviewed the preserved tree and cited `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchange*.sol`. Those line numbers are not the implementation target. MiniMax §5’s edit list would modify the frozen tree. That is out of scope.

Grok’s original correctly named FullSpread as the product vault, then still left a non-blocking confirm. The clarification removes that confirm. Preservation law and this clarification agree: do not edit the old tree.

## Agreements

- Sleeve identity `F = p*D` matches `targetFree = floor(T*p/(1e18+p))`. The 100/40 example is arithmetically right. Default 20% is one-sixth of placeable inventory, not one-fifth. Astra and Grok agree. MiniMax’s claim that the old and new formulas match at `p = 0.20e18` is wrong (see corrections).
- Idle single-token `exchangeIn` today does not composition-swap. The PRD’s swap-then-allocate-then-mint order is a real change. Quotes must follow execution. D1 keeps the same selector.
- Public repair swaps are a change from today’s add/remove-only helper. D9 does not authorize cooldowns or cumulative caps.
- Dual-token activation, imports, blocked cover-or-revert withdrawals, and no nested unlock stay. Universal Router `main` mint-only PositionManager command was independently verified; it is not a deployment pin and does not imply a router migration.
- Compiler claim matches default `foundry.toml`: solc 0.8.35, optimizer runs 1, `via_ir = false`.
- Passing tests would not prove security or economic soundness.

## Corrections

| Claim | Who | Correction against FullSpread |
|---|---|---|
| Missing contract-caller guard; transfer helper has no bytecode check | Astra; Kimi §3.5 | **False on the new vault.** `UniswapV4FullSpreadStandardExchangeVaultCommon.sol` 1222–1223 calls `LocalCreditLib.requirePretransferCaller` before crediting `pretransferred=true`. `LocalCreditLib.sol` 23–27 reverts `EOAPretransferNotAllowed` when the caller has no bytecode. In, InMulti, Out, and share delivery use this helper (`InTarget.sol` 59–68; `InMultiTarget.sol` 26–29; `OutExecuteTarget.sol` 67, 127; `Common.sol` 1280). Out delegate also checks (`OutExecutionDelegate.sol` 35, 62). |
| Durable credit is `R − live deployed`; price moves manufacture pretransfer credit | Astra; Kimi §3.4; MiniMax “face-booked U” | **False on the new vault.** Credit is `balanceOf − reserveOfToken` (`Common.sol` 1224–1227). End sync writes `balanceOf`, not economic totals (`Common.sol` 610–616). `_deployedFaceOf` (1242–1247) has no callers. Position repricing does not change `R`. Do not reintroduce the old defect. |
| `_syncVaultReserves` already satisfies §12 because it stores economic totals | MiniMax §1, §4.3 | **Wrong tree and wrong accounting.** Old sync stored free+deployed+fees. New sync stores local balances. Share backing remains separate: `_totalVaultReserves` adds free, uncollected fees, and deployed (`Common.sol` 623–634). That split is what §12 requires. Keep it. |
| Dual deposit does not tail-rebalance | MiniMax §4.2 | **False on the new vault.** Idle dual deposit calls `_rebalanceLiquidReserveBestEffort` (`InBase.sol` 369–370). |
| Old and new sleeve formulas match at 20% | MiniMax §7 | **False.** Current `_targetFree` is `total * p / 1e18` (`Common.sol` 358–360). At `p = 0.20e18` that is 20% of total. The PRD formula is `T*p/(1e18+p)`, about 16.67% of total and 20% of deployed. At `p = 1e18` the current formula targets 100% free; the PRD targets equal free and deployed. The PRD already forbids preserving the old percent-of-total behavior. |
| Blocked issuance formula is unspecified and blocks planning | Grok original Q1 | **Corrected.** On FullSpread, blocked single-token deposit is specified by current code: no unlock, one-sided invariant-growth mint, sync, no rebalance (`InBase.sol` 277–313; `StandardExchangeConstantProduct.sol` 52–64). PRD §4 “retain existing sleeve-only behavior” means keep that path. Do not invent an internal book swap. Idle and blocked mints will differ. That is an accepted consequence of D59 plus no nested unlock, not a new NAV policy. |
| 1bp-including-flooring needs an owner answer | Grok original Q2 | **Corrected.** §7 already forbids an absolute-dust exception that defeats the relative bound and requires atomic revert if protection fails. The epsilon expression is labeled “proposed,” but the loss bound is normative. Overflow-safe comparison, including flooring, is engineering. Small deposits that miss 1bp revert. |
| Public rebalance should become a blocked no-op | MiniMax A | **Not open.** PRD §8 makes public rebalance available only when interaction is available. New code reverts when blocked (`LiquidReserveTarget.sol` 92–94; interface 47–49). Best-effort tails no-op when blocked (`Common.sol` 727–729). §8’s truthful no-op is the idle case when no useful step exists. Deadband success already returns without unlock (`Common.sol` 763–765). |
| Adopt `min()` as the only issuance formula, including balanced pairs | MiniMax B | **Overbroad.** Dual positive inputs already use `min(mulDiv)` (`StandardExchangeConstantProduct.sol` 52–56). The change is the idle single-token `exchangeIn` path. Multi `exchangeInManyToOne` stays dual mint without a composition swap (`InMultiTarget.sol` 11–31; `InBase.sol` 331–375). |
| Composition atomicity, zero-swap fast path, and formula choice are owner policy | MiniMax F, G, E | Engineering. A failing `exchangeIn` reverts the transaction. A zero-swap fast path is allowed if the 1bp and issuance checks still run. Implement the PRD sleeve formula, not the current percent-of-total helper. |
| Hook quotes need a new refuse-or-vanilla decision | MiniMax I | Settled by D14 and §10. Current `_adjustHookSwap` returns the vanilla amount for unsupported hooks (`QuoteService.sol` 50–55). That must not be presented as an exact fee-inclusive quote. No whitelist. |

## Corrected FullSpread behavior matrix

Paths are under `contracts/vaults/standard/exchange/protocols/uniswap/v4/` unless noted.

| Route | Current behavior | Plan obligation | Not authorized |
|---|---|---|---|
| Idle single-token `exchangeIn` | Pull, fee collect, one-sided invariant-growth mint, sync, add/remove tail (`InTarget.sol` 67–71; `InBase.sol` 269–311) | Caller-funded composition swap, then add/remove toward `floor(T*p/(1e18+p))`, then `min()` mint against post-swap incumbent book excluding caller contribution. Same selector. | Opt-in zap interface. Holder-funded composition. Silent fallback to invariant growth if 1bp fails. |
| Blocked single-token `exchangeIn` | Same mint, no unlock, `LocalDepositWhileBlocked`, no tail (`InBase.sol` 309–313) | Preserve. | Nested unlock. Internal book swap unless a later PRD says so. |
| Idle dual `exchangeInManyToOne` | Both tokens pulled, `min()` mint, sync, add/remove tail (`InMultiTarget.sol` 26–30; `InBase.sol` 335–370) | Preserve. No composition swap. Imbalanced surplus remains the `min()` donation. | Applying the 1bp zap gate to this route. |
| Blocked dual join | Mint, no unlock, blocked events (`InBase.sol` 371–373) | Preserve. | Nested unlock. |
| First activation / import | Both tokens or imported position; single-token activation returns 0 (`StandardExchangeConstantProduct.sol` 30–34; import excludes sleeve) | Preserve. Zap does not bootstrap. | In-place migration. Old-tree edits. |
| Idle zap-out / direct swap | PoolManager, then add/remove tail (`InBase.sol` 74–88, 166–211; `OutExecuteTarget.sol` 49–80) | Preserve execution. Tails stay add/remove-only. | Adding D9 swaps to these tails. |
| Blocked zap-out | Sleeve constant-product quote; pay only if local `tokenOut` covers; else `InsufficientLocalReserve` (`InBase.sol` 150–163) | Preserve. | Unlimited sleeve liquidity. |
| `exchangeOut` exact-out share mint | Closed-form inverse of the one-sided mint, then outer tail (`OutExecuteTarget.sol` 94–97, 109–137) | Leave on that inverse unless a later decision expands D1. Do not use it as the `exchangeIn` quote. | Silent equivalence claim with the new zap. |
| Public `rebalanceLiquidReserve` | Reverts if blocked. Idle add/remove only. No-op inside deadband (`LiquidReserveTarget.sol` 92–96; `Common.sol` 757–800) | May swap vault-owned inventory within the per-call limit, then add/remove. Stop when sleeve deadband and deployability both hold. Immediate repeats stay allowed. | Cooldowns, quotas, cumulative budgets, market-price targeting, blocked success that hides the gate. |
| Automatic tails | Shared `_rebalanceLiquidReserveBestEffort` after idle deposit, dual join, direct in, free zap-out, import, out swap, out withdrawal, exact-out mint, and out-multi (`InBase.sol` 88, 211, 308, 370; `PositionImportTarget.sol` 94; `OutExecuteTarget.sol` 80, 89, 97; `OutMultiTarget.sol` 120) | Keep add/remove-only. Do not add swaps inside the shared helper. Deposit allocation happens before mint; a post-mint tail must not become a second, holder-funded swap. | Treating a helper refactor as permission for tail swaps. |
| Pretransfer | Contract caller required. Credit is declared amount if `declared ≤ balanceOf − R`. Pull credits measured delta and requires exact delivery (`Common.sol` 1219–1240). Exact-in refunds nothing. | Preserve. Full-sync local balances after success, including dust and residuals. | Provenance checks, pull-only, `R − deployed` credit. |
| Quotes | `_previewZapInDeposit` uses one-sided mint (`InBase.sol` 252–265). Transition deposit does too, then percent-of-total rebalance (`InQueryTarget.sol` 112–132). `QuoteService._quoteZapInShares` uses a pool-position zap (`152–173`). Unsupported hooks pass vanilla amounts (`QuoteService.sol` 55). | Idle `exchangeIn` previews, `previewExchangeIn`, and `quoteExternalDeposit` must model composition, post-swap book mint, and the new sleeve formula. Blocked quotes must not imply an unlock. Hook-unsupported quotes are not exact. | A vanilla quote presented as exact. |
| Consumers | Buffer legs call `previewExchangeIn` and `quoteExternalDeposit` (`contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol` 77–84). | Update those quote surfaces with the vault. Do not retarget consumers onto the old package. Inventory DETF/SY call sites in the plan; no DETF product-law change. | Old-vault migration. |

## Topic assessments

**Blocked issuance.** Settled as preserve FullSpread sleeve-only invariant-growth. Grok’s original A/B/C question is withdrawn. Astra’s “preserve blocked single-token sleeve issuance” is the right planning rule. Economic difference versus the idle zap must be tested and disclosed, not redesigned.

**1bp including flooring.** Settled as a relative loss bound with no defeating dust exception. Engineering must use overflow-safe comparisons and define zero denominators. Tiny deposits may revert. That does not reopen D59: blocked and dual routes still accept single- or dual-token deposits under their existing formulas; the 1bp gate applies to idle composition.

**Automatic versus public repair.** D9 authorizes swaps on public rebalance, not on automatic tails. D2 keeps deposit-composition swaps on caller credit. Astra’s shared-helper hazard is real on the new vault even though the cited file is old. The split is an engineering constraint, not an owner question. Kimi’s suggested 1bp-plus-floor proportionality band is a reasonable planning default for “stop when both thresholds hold,” aimed at deployability against the existing full-range position plus sleeve adequacy. It is not a historical ratio and not an external price target. §9 already rejects market-price stabilization.

**Caller guard and durable snapshots.** Implemented on FullSpread. Settled law, already present. Plan must not “fix” them by copying the old `R − deployed` derivation. Self-share booking (`Common.sol` 613–616) is an intentional package exception to the canonical hold-set exclusion. Keep and document it. Kimi’s exception note survives; the file path does not.

**Quotes and consumers.** Coverage is incomplete for the new economics. Execution, `previewExchangeIn`, transition inventory quotes, and the zap quoter currently disagree with each other and with D5. Buffer-hook legs consume the external deposit quote. Unsupported-hook adjustment is a pass-through. This is mandatory plan work under D14, R4, and the PRD quote scope. It is not a new product decision.

## Owner decisions, settled law, engineering

**Already decided by this PRD plus the clarification:** FullSpread target; no old-tree edit/deletion/migration; idle `exchangeIn` composition; sleeve as percent of deployed principal; public rebalance may swap and may repeat immediately; blocked path stays sleeve-only; no hook whitelist; no Universal Router migration; no new vault admin; no in-place instance migration.

**Already settled elsewhere:** source-agnostic pretransfer, contract-caller guard, exact-in no refund, full local booking, direct PoolManager, dual-token activation, full-range, fees counted once, FoT and rebasing underlyings forbidden.

**Engineering, with the constraints above:** solver fixed point, per-call 25/50/10 bp checks as working constants, overflow-safe 1bp check, progress metric, quote/consumer updates, execution-delegate sizing, tests on the registry-deployed FullSpread package. Do not overload `liquidReservePercentage`.

## Minimal owner questions

None required to start the plan.

Optional, non-blocking: confirm the §9 table (25 bp public impact, 50 bp deposit impact, 10 bp fee-inclusive shortfall, 1 bp alignment) as ship constants rather than observe-only. If unanswered, the plan should implement them as immutable working limits and label them uncalibrated. Do not add admin ownership to change them later.

## Dissent

- Astra P1 (repair objective) and P1 (which entrypoints may swap): the objective and the public-only swap scope are already implied by D5/D9/§8/§9. Confirmation would be cheap, but withholding it should not stop planning. Unresolved only if the moderator wants a recorded yes.
- Kimi Q1–Q3: Q1 is the optional confirm above. Q2 and Q3 are planning defaults, not blockers. Kimi’s “no true blocker” verdict is right once the tree is corrected; the missing-guard and snapshot findings are not.
- MiniMax A–I: none survive as owner questions against the new vault and the PRD text. The readiness claim is right; the file list is not.
- Grok original blockers are withdrawn for the reasons in the correction table.

## Confidence

High on FullSpread line citations read this pass, on the caller-guard and snapshot corrections, and on the sleeve-formula disagreement. High that upstream Universal Router `main`, fetched 2026-09-27, rejects increase/decrease/burn; not a deployed pin. Medium on whether every DETF/SY consumer was enumerated; the buffer-leg quote consumer was verified, and the plan must finish the inventory. Context7 was used in the original pass for PoolManager unlock sessions; this correction relies on the vendored `PoolManager.sol` `AlreadyUnlocked` behavior already cited, not a new external API claim. No tests were run. Council artifacts were not read.

**Saved:** `docs/research/uniswap-v4-zapin-prd-review-2026-09-27/grok-cross-review.md`
