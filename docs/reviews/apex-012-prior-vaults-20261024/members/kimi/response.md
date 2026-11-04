# Council member response — kimi

## Identity

- Run ID: apex-012-prior-vaults-20261024
- Member label: kimi
- Profile: research
- Phase: initial independent response
- Owned path: `docs/reviews/apex-012-prior-vaults-20261024/members/kimi/response.md`
- Requested role: council-member
- Requested model and reasoning: kimi-coding/k3:high
- Other identity fields: not exposed
- Peers read before submission: no

## Question and targets

Question: from the vault survey already completed (`.omo/ulw-research/20261023-171500/`), what can IndexedEx take, and what can it not take, for the liquidity-manipulation claim in APEX-2026-012? The claim, as bounded by the claim report: a permitted change in pool liquidity changes the live liquidation quote, so a deposit at the honest quote and a redeem at the inflated quote pays the attacker from the remaining holders. Spot price is not, by itself, the claim; the report is broader only in also stating a spot-move sequence and an unsettled in-unlock path.

Targets answered below: (1) inspected designs that price a withdrawal from live pool depth or live slot0 and therefore do not stop this claim; (2) inspected designs that would stop a permitted liquidity change from changing what a holder is paid; (3) what IndexedEx gives up for each design that might help; (4) what must not be taken from the survey because it answers the old spot-rate question, not this liquidity claim.

## Evidence

### Target 1 — designs that price a withdrawal from live depth or live slot0

Every inspected design that publishes a withdrawal or share value reads live pool state; none of them stops the claim as stated:

- **Wings** (synthesis, "Quote functions in the recommendation set"; ledger S2, S3): `getRate = Quote.quote().value / supply`; `LiquidationQuote._prepare` reads `manager.getSlot0`, `getLiquidity`, and the tick bitmap, subtracts only the vault's own liquidity, and simulates selling the other token into the remaining depth. This is the only inspected design whose quote reads other LPs' live depth directly, and it is the design the claim is about. The synthesis marks it "No. This is the bug."
- **Gamma V4** (synthesis, "Quote functions" table; ledger S13): `WithdrawLogic` computes share value from `poolManager.getSlot0` — a live spot mark at withdrawal time. Excluded as a spot mark.
- **Arrakis V2** (synthesis, "Quote functions" table; ledger S4): `Underlying.underlying()` reads `pool.slot0()` and returns two amounts via `getAmountsForLiquidity`. Also deprecated 15 Jun 2026 (ledger S24).
- **Charm** (synthesis, "Quote functions" table; ledger S14): `AlphaProVault.getTotalAmounts` / `_amountsForLiquidity` reads slot0; shares are pro-rata of two amounts.
- **Visor 2021** (synthesis, "Exclusions from primary postmortems"; ledger S22): receipt mint priced off `TickMath.getSqrtRatioAtTick(currentTick())` — the deposit side, but the same live-spot class. Excluded.
- **Revert V3Oracle** (ledger S17): with `twapSeconds == 0` it reads slot0 directly. The synthesis does not place it in the recommendation set; it is a lending oracle, not a vault share rate.
- **Steer** (synthesis, "Quote functions" table; ledger S15): `getTotalAmounts` returns two token amounts and tells the integrator to apply a market price — the price choice is pushed to the caller, so any caller-supplied live price re-imports the live read.

One mechanism distinction the survey supports: only Wings simulates a sale into remaining depth, so only Wings is moved by a *pure* permitted depth addition with no price move at all. The other live-slot0 readers are moved by the claim report's broader spot-move sequence, not by depth alone. They still do not stop the claim, because the claim is not depth-only.

### Target 2 — designs that would stop a permitted liquidity change from changing the payout

The survey supports two, one directly and one as precedent:

1. **Panoptic CollateralTracker** (synthesis, "Recommendation" and "Quote functions" table; ledger S16): `convertToAssets` reads stored `s_poolAssets + s_inAMM` — accounted balances, not balanceOf, not slot0, not pool depth. A permitted change in pool liquidity writes nothing to those counters, so it cannot change what a share converts to. The synthesis names this stored single-token accounting as "the pattern that can implement IRateProvider.getRate() without reading spot" and notes it is options collateral, not an LP vault — "The rate shape is what IndexedEx can call." This is the one inspected design whose accounting is fully insensitive to the claim's mechanism.
2. **Maker GUniLPOracle** (synthesis, "Alternative precedent, not the recommendation"): `peek()`/`read()` return the last `poke()`, and `poke()` is hop-limited (default 1 hour) and derives sqrtPriceX96 from two independent USD oracles rather than from the pool. Between pokes, a permitted liquidity change cannot change the cached value a rate provider reads. The synthesis is explicit about the boundary: it "supports a cached external mark. It does not make a live AtPrice call safe" — `seek()` still calls the vault, and Arrakis V2 `underlying()` still reads `pool.slot0()` for the fee tick even when a price is supplied.

A third candidate must be stated carefully. **Two-token pro-rata exit** (Charm, ledger S14; Arrakis V2, ledger S4) contains no simulated sale: the holder withdraws both tokens pro-rata to the vault's own liquidity, and `getAmountsForLiquidity` for the vault's own position depends on the vault's liquidity and the current tick, not on other LPs' depth. On the survey's recorded mechanics, a pure permitted depth addition therefore cannot change what a withdrawing holder is paid. I flag this as my inference from the recorded mechanics, not a synthesis conclusion: the synthesis excluded these designs on the old spot-rate question (slot0-dependent split) and on deprecation, and never evaluated them against the liquidity claim. The slot0-dependent split also means the claim report's broader spot-move sequence still moves value between the two paid tokens, so this addresses only the depth channel.

### Target 3 — what IndexedEx gives up for each design that might help

- **Stored single-token accounting (Panoptic shape, the synthesis recommendation; S16):**
  - Fee recognition becomes discrete, not continuous. The Uniswap position still earns swap fees in-range, but "those fees enter the rate only when target tokens actually move into the accounted balance: a settled swap, a harvest, a deposit, or a redemption" (synthesis, "Recommendation"). Between such events the rate understates the position.
  - The non-target token's value leaves the rate until a separate conversion credits target, and "that conversion is outside getRate and does not use slot0" (synthesis, "Recommendation"). IndexedEx gives up a rate that reflects full position value at every block.
  - The one-token rate itself is kept (`accounted target tokens * 1e18 / supply`), and fee earning is kept, so on the survey's record neither of those two is surrendered — what is surrendered is immediacy of recognition and any payout that exceeds the accounted target balance at redeem time.
  - Source-shape caveat: Panoptic is options collateral, not an LP vault (synthesis, "Quote functions" table), so the shape transfers but the surrounding product machinery does not.
- **Maker cached external mark (synthesis, "Alternative precedent"):**
  - A continuously executable, always-fresh rate. The value a caller reads is stale by up to the hop (default 1 hour); the rate is only as current as the last `poke()`.
  - Oracle independence. The mark derives from two independent USD oracles, adding an external liveness and correctness dependency the live-quote design does not have.
  - It does not make the live path safe: the synthesis records that `seek()` and Arrakis V2 `underlying()` still read the pool, so the cache must be the only thing the rate reads.
- **Two-token pro-rata exit (my inference from S4/S14 mechanics, not a synthesis recommendation):**
  - The one-token exit. The holder is paid in both pool tokens and must sell one leg themselves; IndexedEx gives up the single-target-token withdrawal that Wings currently quotes.
  - For Arrakis V2 specifically, a maintained codebase: deprecated 15 Jun 2026 (S24), "Not a live pattern."

### Target 4 — what must not be taken from the survey

- **"A rate that ignores same-pool spot" as a sufficient fix.** The old survey asked for a one-token rate that does not read same-pool spot; this claim is about deposit *and* redeem priced from the live liquidation quote. The synthesis says it directly: a getRate that does not read spot "does not emit that quote. It does not by itself fix a deposit function that still prices off the pool" ("Exclusions from primary postmortems"). Taking only the getRate change would leave `Money._deposit` / `Money._redeem` reading `LiquidationQuote` exactly as the claim describes.
- **The Visor 2021 and Gamma 2024 postmortem exclusions as evidence about this claim.** Both are "the spot-quote class" (synthesis, "Exclusions"; S22, S23). They demonstrate the danger of spot-priced mints and ratio checks; they say nothing about a permitted depth change, so they cannot be cited for or against the liquidity channel.
- **The Maker/Arrakis `AtPrice` machinery as a live-call fix.** The synthesis records that supplying a price does not stop the underlying slot0 reads ("Alternative precedent"). Only the cached `peek`/`read` half of that precedent is usable.
- **ICHI's TWAP-vs-spot check** (ledger S9): it is a deposit guard, "Guard, not a rate" (synthesis, "Quote functions" table). It answers "should this deposit be rejected," not "what is a holder paid," and says nothing about withdrawal pricing under a permitted liquidity change.
- **The synthesis recommendation as a decision already made.** It is evidence of what the survey found; the brief reserves the choice.

## Conclusions

1. Everything the survey inspected that prices a withdrawal reads live pool state, and none of those designs stops the claim. Wings (S2/S3) is the only one that reads other LPs' live depth via the simulated sale; Gamma V4 (S13), Arrakis V2 (S4), Charm (S14), Visor (S22), Revert in zero-TWAP mode (S17), and Steer-by-delegation (S15) read live slot0 or a caller-supplied live price and remain exposed to the claim report's broader spot-move sequence.
2. Exactly one inspected design is fully insensitive to a permitted liquidity change: Panoptic's stored-accounting shape (S16), which the synthesis already recommends. Maker's hop-limited cached mark ("Alternative precedent") is insensitive between pokes and is the survey's only external-mark precedent. Two-token pro-rata exit (S4/S14) plausibly kills the pure depth channel by removing the simulated sale, but that is my inference from recorded mechanics, not a survey conclusion, and it does nothing for the spot-move sequence.
3. The costs are already recorded: stored accounting costs continuous fee/value recognition and confines the payout to accounted target; the cached mark costs rate freshness and adds a dual-oracle dependency; two-token pro-rata costs the one-token exit and, for Arrakis V2, a maintained codebase. Fee earning and the one-token rate survive the recommended pattern.
4. Do not import the old question's answer as this claim's fix: a spot-free getRate alone leaves the deposit/redeem quote untouched, and the postmortem exclusions, the ICHI guard, and the live `AtPrice` path all answer questions other than this one.

## Limits

- Read scope: brief, synthesis, sources ledger, and claim report only. No peer files, no URLs re-opened, no new protocols, no Forge or code execution. The optional DiffReview cross-check was not needed; no suggestion here depends on a sentence the synthesis does not quote.
- The two-token pro-rata observation in Target 2/3 is an inference from mechanics the ledger recorded (S4, S14), explicitly not a synthesis finding; the synthesis evaluated those designs only against the old spot-rate question.
- Whether any of these patterns actually stops the settled-depth or unsettled-in-unlock variants inside the Wings diamond is an implementation question the survey does not answer; this response does not redesign Wings and does not adopt the synthesis recommendation as chosen.
- The survey's own gaps stand: DefiEdge, Orange, Maverick unresolved; Teahouse and Algebra publish no spot-free view rate; ICHI current Solidity unopened; Arrakis Pro V4 share formula unpublished ("Gaps"). Nothing from those hosts supports any suggestion here.
