# Wings clarifications — Kimi K3 cross-review

**Author:** Kimi K3. **Date:** 2026-10-05. Read Astra/Grok/MiniMax clarification originals in full (untrusted). All arithmetic re-verified by hand against `StandardExchangeConstantProduct.sol` and `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol`. My original preserved; corrections listed below. Custody-only `R` and vault-owned `D` definitions treated as settled.

## Arithmetic verification

- **Astra §3 counterexample — verified.** B0=B1=100, S=100, prices (2,1), deposit 125 token1: K'=150, m=50, K/share stays 1; incumbent mark value 300 → 283⅓; entrant claim 141⅔ for 125 contributed. Exact and correct: GM-preserving mint transfers market value whenever book ratio ≠ market price — **no manipulation required**.
- **Astra §4 fixed-mark neutrality — verified.** `m = S·v/V` gives incumbents `S/(S+m)·(V+v) = V` exactly. Correct, and it needs a trusted price: value neutrality is purchasable only with a valuation source.
- **Astra §5 same-token roundtrip — verified in exact arithmetic.** With `q = m/(S+m) = 1−sqrt(B0/(B0+a))`, payout `(B0+a)(2q−q²) = a` exactly. Neutral same-token roundtrip under fixed state, no fees, exact math, sufficient cover.
- **Grok's quantity-impossibility proof — verified and correct.** Any positive mint against positive B1 reduces incumbent token1-per-share; no rounding fixes it. Token-quantity preservation is off the table for positive scalar mints.
- **Grok's numeric table — verified** (sqrt(12000)=109.544, m floor 9; depositor claim ≈ 18.17 at spot 1 for 20 contributed; floor also raises incumbent K/S).

## Corrections

1. **To my own original (two retractions).**
   a. **"With F=0 the book tracks the pool, window pool-bounded" is wrong for concentrated D.** Only a full-range CP position follows `k = const`. Finite wings are piecewise one-sided; B's token ratio structurally diverges from market price as price moves (maximally when price leaves the envelope — PRD G3 `:101`). Astra's static counterexample proves divergence transfers *without* any pool manipulation. My "sleeve fraction × move × deposit" bound is only the sleeve's contribution, not a bound. For this product the divergence window is **structural and always open**; manipulation analysis must treat `ratio(B) ≠ market` as the normal state.
   b. **My roundtrip "two impacts" framing was wrong.** Astra's algebra shows the same-token roundtrip is exactly neutral in reals. My 10,000→8,030 example is dominated by **share-granularity flooring** (mint 4.987 floored to 4 — a 19.7% hit at 1%-of-book size), not by two conversion impacts. Consequence: small single-sided deposits are penalized primarily by integer share granularity, up to total loss (m=0); the dust domain is a first-order economic parameter, not a footnote.
2. **MiniMax's zap-vs-no-swap comparison is apples-to-oranges; the "41.84 subsidy" conflates quantity with value.** Path A assumes a ~zero-impact external swap (50 token0 → 50 token1) against a book the same size as the vault's. A real CP swap of 50 into a 100/100 book yields **33.33** token1. Recompute Path A honestly: contribution (50, 33.33), book (150, 133.33), `m = min(33, 25) = 25`, depositor claim ≈ 56.7 value for 100 paid — **worse** than Path B's ≈ 87.2. And the 41.84 figure measures only the token0-quantity change, ignoring the 29.08 token1 claim; at mark 1:1 the Path B transfer is ≈ 12.8, i.e. ordinary conversion impact. Both paths charge the joiner impact; they differ in *which market executes the conversion* (external AMM vs internal formula over B), not in whether a "subsidy" exists. MiniMax Q1 should be reframed accordingly — it is not a hidden fee and not uniquely a Path B property.
3. **Grok over-infers prohibition.** "An internal virtual swap … is outside this intent" goes beyond the evidence: the owner *asked whether* accounting can preserve value without a typical zap, and PRD B3 candidate 2 (`:148`) is exactly local/virtual pricing "without a balancing swap." Per instruction, do not infer the owner prohibited virtual pricing or no-swap exits (`_singleExit:98-111` is an in-repo no-pool-interaction exit mechanism). Likewise "geometric growth is a value transfer, not a third neutral option" proves too much: every admission rule, zap included, is a value transfer; the live question is which transfer rule, its size, and its manipulation bounds.
4. **Wing orientation — Grok's "placement bug" claim is rejected; PRD G1 is correct.** Verified at `LiquidityAmounts.sol:67-76`: price **at/below range bottom** → `getLiquidityForAmount0` (position above price holds **token0**); price **at/above range top** → `getLiquidityForAmount1` (position below price holds **token1**). With spot inside the center, the lower wing (entirely below spot) holds **token1** and the upper wing (entirely above spot) holds **token0** — exactly G1's table (`PRD:78-82`), and consistent with the historical record (`FULL_RANGE_DEPLOYED_BOOK_PRD.md:73-74`). Grok inverted the conditional's subject.

## Adjudicated distinctions (for the PRD's acceptance properties)

- **Fixed-mark value neutrality** (`m = S·v/V`) — achievable, needs an approved valuation source; manipulable/stale price ⇒ overmint. Distinct from **token-quantity preservation** (impossible, proven) and from **invariant-per-share preservation** (achievable formula-free of any oracle, transfers market value when `ratio(B) ≠ market`).
- **Sufficient local cover vs ownership valuation.** Redemption *ownership* is valued on B; *capacity* is F-only, always. A quote on B is not a promise of local cash. Idle vs blocked must not silently swap which one a route returns.
- **Virtual pricing vs actual AMM execution.** The no-swap rule performs the conversion *implicitly* over B (fee-free today, `:8`); the zap performs it *explicitly* against real pool liquidity (pays real fees/impact). Cost ordering depends on relative depths and fee treatment — it is not decided by the no-typical-zap clarification.
- **Concentrated D need not track market.** It does not; see correction 1a. Any single-sided rule faces states where internal and market prices are maximally apart, including one-sided books (domain rejection, not pricing).

## Agreements

Min-ratio zero is a domain boundary, not a defect; rounding must favor incumbents with no generic wei-allowance; full-drain single-token exit is guarded (`:102`); empty same-side and zero-leg states need named rejection; R/F/D/E/B semantics and `F = p·D` with `targetFree = floor(T·p/(1e18+p))` are settled.

## Few clear human questions

1. **Value metric for scalar admission.** Should "preserve value" mean (a) invariant-per-share preservation with virtual-conversion impact economics (no swap; existing helper as mechanism candidate), or (b) mark-to-market neutrality at an approved valuation source (requires full oracle policy)? Token-quantity preservation is proven impossible for positive mints and is off the table. Neither (a) nor (b) is claimed safe.
2. **Does no-typical-zap bind exits too?** May idle single-token exits execute a real underlying swap while blocked exits use a separately specified local conversion — or must both directions share one no-swap rule? State proportional-exit availability alongside the answer.
3. **Fee and dust policy on the virtual conversion.** Fee-free (status quo) or trading-fee-equivalent so routes stay aligned? And: named rejection for zero-mint dust (share-granularity flooring is the dominant small-deposit cost), with a product minimum single-token deposit if any.
4. **Divergence-transfer bound.** Since B's ratio structurally diverges from market for concentrated books, what bounds single-sided mint/exit transfers: accepted as AMM-style economics, per-deposit caps, or a reference-price gate (units/window/band/failure behavior to be specified)?

Secondary operational questions worth forwarding from MiniMax without endorsement: rebalance-swap exception vs D28 for stalled one-sided wings; payout-capacity floor vs target; protection-constant recalibration; per-chain gas-cap selection; 10/90 as restoration vs starting point.

## Honest scope

All math hand-derived, not executed; no simulation, tests, or fork data; no formula here is claimed safe; consensus is not evidence. My original stands except retractions 1a/1b above.
