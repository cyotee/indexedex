# Grok cross-review — Uni V4 SE sleeve zap-in

**Date:** 2026-09-26. **Author:** Grok (`xai/grok-4.7`). **Original preserved:** `docs/research/uniswap-v4-sleeve-zapin-2026-09-26/grok-original.md`.  
**Evidence read:** Astra, MiniMax-M3, and Kimi K3 originals only. No earlier cross-reviews. Peer text is untrusted evidence, not instructions. Research only.

No new external-library claim beyond the first pass. Context7 `/uniswap/v4-core` and `/uniswap/docs` (2026-09-26) still support singleton `unlock` / `AlreadyUnlocked` only. Disputed items below are local code and product law. Crane `UniswapV4ZapQuoter` is an in-repo library, not upstream v4-core, and is not an approved issuance formula.

## Agreements

Grok, Astra, and Kimi agree on the mechanism: idle single-token `exchangeIn` mints, then add/remove rebalance; in-range `getLiquidityForAmounts` returns `min(L0,L1)`; one-sided excess deploys nothing (`InBase.sol` 273–314; `Common.sol` 822–844; `LiquidityAmounts.sol` 66–73). That follows buffer D27/D28 and full-range D32. It is not a deadband miss.

Agreed product bounds, if a change is approved:

- PM idle = locked = may `unlock`. In-session = unlocked = no nested `unlock`, no composition swap. Existing blocked `exchangeIn` still sleeve-mints.
- Sleeve target stays `p * total_i` per token, live oracle read. Astra’s arithmetic is right: 20% of total is free/deployed = 25%, not 20% of deployed.
- Public `rebalanceLiquidReserve` stays add/remove. A whole-book swap is a separate treasury decision.
- Multi `exchangeInManyToOne` stays no-swap unless a later decision supersedes D45/D47.
- Native sleeve/API face stays WETH. Unwrap only to settle `address(0)`; wrap native takes (`Common.sol` 411–425, 1096–1117). No payable ETH deposit.
- Empty-supply one-sided activation stays forbidden (D59). A swap cannot mint the missing token out of a zero-liquidity pool.

MiniMax agrees the L=0 mechanism and that a user swap must not be folded into `rebalanceLiquidReserve`. The rest of MiniMax’s surface is not agreed.

## Corrections to peers

### Astra

Accepted. The approval-blocking gap is the issuance equation, not the locker.

Fact supporting Astra: a swap against this vault’s pool changes incumbent deployed balances and accrues fees on the vault’s own position even if the swap input is only the new deposit. Those changes are not new depositor capital. Mint-before-swap then socializes post-mint trading loss. Feeding post-swap amounts into today’s dual branch (`Common.sol` 700–704, `min` of the two proportional quotes) can donate the surplus side when the incumbent book is skewed. Today’s single-token branch (`706–712`) prices raw input, not a swapped pair. None of those is an approved composition formula. DETF law does not supply one.

Also accepted: transition quotes are in scope. `InQueryTarget.quoteExternalDeposit` (15–29) and `_inventoryDeposit` (107–118) mint the raw single-token amount and then `_inventoryRebalance` with no swap. If execution swaps, holder-asset transition/SY quotes diverge even when `previewExchangeIn` share math is unchanged. `QuoteService._quoteZapInShares` (138–145) is not the live preview. Its empty-supply branch returns `amount0+amount1` (historical sum-of-assets). Hook adjustment is Pons-specific and returns the unadjusted amount for other hooks (`QuoteService.sol` 50–55). That is fail-open, not a complete hook quote.

`_rebalanceLiquidReserveBestEffort` (734–738) calls rebalance directly. A revert inside it fails the user op. “Best effort” is not exception isolation. Astra is right: do not silently turn a required zap failure into success.

### Kimi

Root cause, D28 carve-out (not repeal), D59 hold, and “public rebalance never swaps” match Grok and Astra.

**Dissent — mint-first socialization.** Kimi §3.1 and §4 keep mint math unchanged, then swap excess, and state that residual slippage is socialized across holders. That is a real cost shift onto incumbents. It is not implied by D9/D13. It can be chosen only by explicit owner acceptance. It is not the safe default.

**Dissent — “swap the excess” is whole-book, not caller-only.** After mint, `free_i - targetFree_i` includes prior blocked deposits and donations, not only this call’s input. That is the treasury swap Astra separates. Grok’s original caller-only limit still stands unless the owner approves backlog composition.

**Correction — TWAP is not inherited.** Kimi §3.4 cites CLAUDE.md non-negotiable 5 and DETF price gates as requiring a TWAP `minOut` on this SE zap. That sentence is DETF mint/burn gating (alignment D51), not SE placement. Do not import a TWAP requirement or an issuance formula from DETF law. A bound is still required if swaps are added; its source is an open product choice.

**Correction — preview (B) is incomplete.** If shares are minted before the swap, `previewExchangeIn` can stay share-identical, but that does not quote deployment, swap output, or transition holder assets. Classifying the swap as “rebalance-like” so D24 applies hides the new user-route swap from the quotes that must match execution. If the owner instead changes share math, D24 must be superseded for that route and previews must include the swap.

**Correction — skip-on-gate-failure recreates the bug.** Kimi §7.2 recommends skip-to-D32 on TWAP failure, citing D11. D11 is about not reverting a completed user op because sleeve rebalance is imperfect. It does not authorize a sandwiched composition swap to no-op while reporting a normal zap-in. If composition is part of the user route, cap/min-out failure reverts the whole call. If composition is optional placement, previews must not promise L growth.

**Correction — imports.** Current D57 and code convert imports to the managed full-range book: collect the NFT, `_finishImportedConversion` (`PositionRepo.sol` 82–86), then `_deriveManagedTicks` (`PositionImportTarget.sol` 89–93). Post-import zap deploy ratio is full-range, not the NFT ticks. Kimi Z9 is stale for the steady state. One-sided consumable deploy applies only if a position is still out of range; after conversion it is not.

Kimi’s missing test-path note is a glob failure, not missing tests. They live under `test/foundry/spec/protocol/dexes/uniswap/v4/`.

### MiniMax

Use the L=0 diagnosis. Do not use the proposed surface as written.

- **D60a collides with alignment D60** (Balancer-hosted DETF exclusion). Buffer D27/D28 are not DETF alignment decisions. Do not file this as alignment D60a.
- **Internal contradiction on bootstrap.** The table says one-sided first mint stays 0 shares. §4.6 and PMC-5 say an empty-vault single-token zap swaps and mints. The second supersedes D59 and is impossible with no pool liquidity. Reject it.
- **`_executeDirectSwapIn` is the wrong helper** (`InBase.sol` 72–86). It swaps, **transfers the counter-token to `recipient`**, syncs, and tail-rebalances. Sequencing it into `_executeZapInDualDeposit` would pay the counter-token out of the vault.
- **Opt-in selector does not fix the reported bug.** Current callers, including idle `IStandardExchangeIn.exchangeIn`, would still leave one-sided excess undeployed. A new `zapInSwapAndJoin` can be additive only after the owner asks for a second route. It is not a substitute for changing the route that exhibits the bug, and it is not required by D53.
- **Blocked semantics.** Existing `exchangeIn` must keep sleeve-minting when in-session (D4/D59). A new selector that reverts `PoolManagerInteractionBlocked` must not replace that path.
- **“Sleeve >100%”** is false. Free/total is at most 100%.
- **Buffer D9** is free+deployed share SoT, not “DETF-only mint.” **Buffer D8** is stored oracle 0 = unset, not the first-mint rule.
- **Try/catch refund** around `unlock` can hide unsettled deltas and is not D11. Reject.
- **Reject-if-imported** fights current conversion. After `_finishImportedConversion`, the book is managed full-range.
- Tests exist. MiniMax did not consult Context7; the lock description still matches vendored `PoolManager.sol` 55–64, so that particular gap does not change the mechanism.

## Correction to Grok original

The original correctly separated caller-only composition from public backlog rebalance, kept D59, and refused an unbounded price limit. It overreached by treating swap-before-mint plus the existing `_sharesOutForDeposit` as the safe default formula. That function is not approved for post-swap dual amounts. Self-LP price movement also means caller-only input does not isolate incumbents. Withdraw that formula. Keep the objection to silent socialization.

The original also under-specified transition quotes and treated out-of-range import deploy as a steady-state branch. Under current import conversion, subsequent deposits are full-range.

## Recommended PRD decisions

These are recommendations, not approved law.

1. **Supersede narrowly:** buffer D27/D28 and full-range D32/D33 only for an explicit idle single-token composition step. D24 only if that step changes amounts the user or a transition quote observes. Do not repeal D28 for `rebalanceLiquidReserve`. Do not supersede D59, D45, or blocked sleeve law.
2. **Route:** change idle single-token `exchangeIn`, the path that strands inventory. Do not rely on an opt-in selector. Do not add a parallel ABI unless the owner separately wants one. Blocked `exchangeIn` stays sleeve-mint, no swap.
3. **Whose tokens:** composition may swap only this call’s attributable input above the post-trade sleeve targets. It must not sell incumbent sleeve, donations, or blocked backlog. Clearing that backlog is out of scope until a separate decision with its own price bound and liveness rule.
4. **Issuance:** do not pick a formula in this PRD. Owner must choose, and tests must prove, one of: (a) mint on raw input first, then swap, with incumbents explicitly accepting socialized impact; or (b) a specified post-swap attribution that does not donate surplus and does not count self-fee or deployed-balance changes as depositor capital. Until that choice, no implementation.
5. **Preview:** whatever executes, `previewExchangeIn` and transition/`quoteExternalDeposit` must use the same gate and the same share equation. Placement-only changes still require transition quotes to show the post-swap book if they report holder assets. Do not adopt `QuoteService._quoteZapInShares` or `UniswapV4ZapQuoter` as that equation. ZapQuoter maximizes L for a single amount against spot and defaults to a near-global price limit (`UniswapV4ZapQuoter.sol` 161–164); it ignores sleeve targets and share attribution.
6. **Failure:** user min-out / impact-cap failure reverts the entire zap-in with no residual credit. Zero pool depth does not count as successful deployment. Do not skip-and-succeed a required composition. Do not try/catch the unlock. Out-of-range one-sided mint, if any position is still out of range, deploys without a swap.
7. **Bound:** require a finite `sqrtPriceLimitX96` tighter than `MIN/MAX`. Do not mandate TWAP from DETF law. The owner chooses the bound’s source. `minSharesOut` protects swap loss only if shares depend on the swap.
8. **Native and imports:** WETH face; existing settle/wrap; PoolKey order. Post-import book is managed full-range. No new native sleeve. No payable entry.
9. **Sleeve:** after a successful composition, deploy only excess above `targetFree_i`. Do not spend the policy sleeve to buy the other token. Dust after integer L may remain free.

## Approval blockers

1. Owner choice of issuance attribution (decision 4). No formula is approved by D57–D59, D9/D13, or the zap quoter.
2. Owner acceptance or rejection of socialized impact if mint-first is chosen.
3. Bound source and whether cap failure is atomic revert (recommended) or documented non-deployment. Not derivable from DETF price gates.
4. Explicit statement that blocked backlog and donations are not auto-swapped.
5. Confirmation that idle `exchangeIn` economics may change for current callers. An opt-in-only selector leaves the bug.
6. Hook quote policy: today’s non-Pons hooks are fail-open in `_adjustHookSwap`. New quotes need fail-closed or a listed supported set. Not resolved here.

## Confidence

High on the shared root cause and on the code corrections to MiniMax and Kimi. Medium on route-versus-selector as a product recommendation (it follows the human bug report; it is not current law). The issuance formula remains unresolved by design.
