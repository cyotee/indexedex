# Identity

- Run ID: apex-012-prior-vaults-20261024
- Member label: minimax
- Profile: research
- Phase: initial independent response
- Owned path: `docs/reviews/apex-012-prior-vaults-20261024/members/minimax/response.md`
- Requested role: council-member
- Requested model: minimax/MiniMax-M3
- Peers read before submission: no

Scope actually exercised: read of the council brief, the admitted survey (`SYNTHESIS.md`, `sources-ledger.md`), the auditor-claim report, and the one optional-context section (`APEX-2026-012` in `docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md`) used only to check sentences the claim report cites. No Forge, no tests, no git, no installs, no wallets, no sub-agents, no new protocol search, no public query carrying source excerpts. No file other than this one was written.

# Question and targets

Council question: from the vault survey already completed, what can IndexedEx take, and what can it not take, for the liquidity-manipulation claim in APEX-2026-012.

The four sub-questions I answer, each requiring a protocol name plus a synthesis section or ledger id:

1. Which inspected designs price a withdrawal from live pool depth or live `slot0`, and therefore do not stop this claim?
2. Which inspected designs, if any, would stop a permitted liquidity change from changing the amount a holder is paid?
3. For each design that might help, what does IndexedEx give up: fee earning, a one-token exit, a continuously executable rate, or something else the survey already recorded?
4. What must not be taken from the survey, because it answers the old spot-rate question and does not answer this liquidity claim?

Target to answer, restated from the claim report (`docs/reviews/apex-012-auditor-claim-20261024/REPORT.md`, "What the auditor claims"): a permitted change in pool liquidity changes the live liquidation quote, so a deposit at the honest quote and a redeem at the inflated quote pays the attacker from the remaining holders. The report is broader only in also stating a spot-move sequence and an unsettled in-unlock path.

Constraint I held: the survey's recommendation is evidence of what was found, not a decision; I am not proposing a Wings change; I do not name any protocol the survey did not inspect.

# Evidence

## E1. The claim as recorded (for reading the survey against it)

From the claim report and the optional-context section:

- Wings (UpperLowerWings, Uniswap V4): `Money._deposit` and `Money._redeem` set the share price from `LiquidationQuote.quote()`. That quote reads live `slot0`, `getLiquidity` and the tick bitmap, subtracts only the vault's own liquidity (`_removeOwned`), then simulates selling the vault's opposing inventory into the remaining depth and adds those proceeds to the value. Shares are `issue = S*credit/V`; redemption entitlement is `shares*V/S`.
- Sequence: deposit at honest `V0`, add a large full-range position, redeem at inflated `V1`, remove the position. Auditor's formula: `profit = D*(V1 - V0 - D)/(V0 + D)`; stated results 70,634,405,953 raw token0 (7.1% of a 1e12 vault) for the in-unlock variant and 74,704,386,253 (7.5% of TVL) for the settled variant. `HolderValueLoss` compares two quotes taken in the same inflated state and cannot see the inflation.
- Important for this council: the *liquidity* channel is the claim. The spot-move sequence (swap out, deposit, swap back, redeem, paying 0.3% fees) is stated separately by the auditor and is not the liquidity channel. The in-unlock variant is blocked by a scripted 0% sleeve (`InsufficientLocalTarget`); the settled variant is not blocked by it.
- The survey's own ledger already touches this mechanism at the level of the quote: ledger `S3` records `UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.sol` as "`_prepare` reads manager.getSlot0; `_quote` simulates opposing-token sale", and `S2` records `EconomicTarget.getRate` as "getRate = Quote.quote().value / supply".

## E2. Survey map: what each inspected design reads when money is paid out

Source for every row: `SYNTHESIS.md` "Quote functions in the recommendation set", "Exclusions from primary postmortems", "Alternative precedent, not the recommendation", "Executive summary", "Gaps", cross-referenced to ledger ids in `sources-ledger.md` (access date 2026-10-23 for every row).

| Protocol / design | What the survey recorded | Where | Reads live pool state on payout? |
| --- | --- | --- | --- |
| Wings (Uniswap V4 UpperLowerWings) | `EconomicTarget.getRate` -> `Quote.quote` reads `getSlot0`; liquidation quote reads `manager.getSlot0` and simulates the opposing-token sale. Row verdict: "No. This is the bug." | SYNTHESIS "Quote functions in the recommendation set"; ledger `S2`, `S3` | Yes — `slot0` plus live depth. This is the design under claim. |
| Arrakis V2 | `Underlying.underlying` reads `pool.slot0()`; both amounts via `getAmountsForLiquidity`. Row verdict: "No. Deprecated 15 Jun 2026." | ledger `S4`; `S24` for deprecation | Yes — live spot and live liquidity. |
| Charm (`AlphaProVault`) | `_amountsForLiquidity` reads `slot0`; shares are pro-rata of two token amounts. Row verdict: "No. Two-token pro-rata." | ledger `S14` | Yes — live `slot0`, and liquidity through the amount math. |
| Gamma V4 | `WithdrawLogic` share value uses `poolManager.getSlot0`. Row verdict: "No. Spot mark." | ledger `S13` (GammaStrategies/GammaV2 `WithdrawLogic.sol`) | Yes — spot mark on withdrawal. |
| Steer | `getTotalAmounts` returns two tokens; the integrator applies a market price. Row verdict: "No. Pushes the price choice to the caller." | ledger `S15` | No isolating price is supplied; the payout depends on a price IndexedEx would have to choose. |
| ICHI legacy | Deposit compares spot and TWAP with a 1% initial threshold; no `getRate` in the page. Row verdict: "No. Guard, not a rate." | ledger `S9` | Supplies no withdrawal rate at all; a deposit-side price guard. |
| Visor / Gamma (V3 postmortems) | Visor: receipt mint quantity "determined via consultation of Uniswap v3 pool's current price" (`TickMath.getSqrtRatioAtTick(currentTick())`). Gamma: ratio checker "erroneously allowed for deposits in any ratio so long as the contents within the vault were single-sided", with the attacker manipulating the pool price. | SYNTHESIS "Exclusions from primary postmortems"; ledger `S22`, `S23` | Spot-quote class; also documents a deposit-ratio hazard. |
| Bunni v2 | Repository README says exploited and issues not fixed; postmortem body not independently read. | SYNTHESIS "Gaps"; ledger `S18`, `S25` | Not established by the survey. |
| Panoptic (`CollateralTracker`) | `convertToAssets` uses stored `s_poolAssets + s_inAMM`. Row verdict: "Shape only. Not an LP vault." | ledger `S16`; SYNTHESIS "Executive summary" | No — stored accounting, no pool read. But it is options collateral, not an LP vault. |
| Maker `GUniLPOracle` | Derives `sqrtPriceX96` from two independent USD oracles, calls `getUnderlyingBalancesAtPrice`, divides by supply. `peek()`/`read()` return the last `poke()`; `poke()` is limited by hop (default 1 hour). `seek()` itself still calls the vault, and Arrakis V2 `underlying()` still reads `pool.slot0()` for the fee tick even when a price is supplied. | SYNTHESIS "Alternative precedent, not the recommendation" | No live read at read time — a cached mark — but the cached value is derived from live pool state at poke time, and a live `AtPrice` path stays exposed. |
| Balancer `ERC4626RateProvider` | `getRate` delegates to `convertToAssets`; lane `web-balancer-rates`, not re-read by lead. | ledger `S21` | Not established: it delegates to a provider the survey did not open. |
| Revert `V3Oracle` | `twapSeconds == 0` uses `slot0`, else `pool.observe`. | ledger `S17` | Configuration-dependent; a `slot0` branch is live spot. A rate source, not a vault. |

## E3. Survey's own recorded mechanisms that bear on the liquidity question

- "Storage the rate reads: an accounted target-token counter, not `balanceOf` and not pool state. The other token stays out of the rate until a separate conversion credits target. That conversion is outside `getRate` and does not use `slot0`." (SYNTHESIS "Recommendation")
- "A `getRate` that does not read same-pool spot does not emit that quote. It does not by itself fix a deposit function that still prices off the pool." (SYNTHESIS "Exclusions from primary postmortems")
- "This precedent supports a cached external mark. It does not make a live `AtPrice` call safe, and it is not the recommended pattern." (SYNTHESIS "Alternative precedent, not the recommendation")
- "Excluded: Wings spot liquidation, Gamma/Visor spot share mint, Bunni v2, and deprecated Arrakis V1/V2." (SYNTHESIS "Recommendation")
- "Fee source: the Uniswap position still earns swap fees while price is inside the range. Those fees enter the rate only when target tokens actually move into the accounted balance: a settled swap, a harvest, a deposit, or a redemption. The rate does not read `slot0`, a quoter, or a hypothetical sale of the other token." (SYNTHESIS "Recommendation")

# Conclusions

## Q1. Inspected designs that price a withdrawal from live pool depth or live `slot0` (do not stop this claim)

- **Wings (Uniswap V4 UpperLowerWings)** — SYNTHESIS "Quote functions in the recommendation set" row "Wings" (ledger `S2`, `S3`). It is the design under claim: `slot0`, `getLiquidity`, tick bitmap, own liquidity removed, opposing-token sale simulated into the remaining depth.
- **Arrakis V2** — ledger `S4`. `underlying()` reads `pool.slot0()` and derives both amounts from live liquidity. Also deprecated 15 Jun 2026 (`S24`), so it is not a live pattern either.
- **Charm `AlphaProVault`** — ledger `S14`. `_amountsForLiquidity` reads `slot0`; the two-token pro-rata share means the paid amount moves with live pool state.
- **Gamma V4** — ledger `S13`. Withdrawal share value uses `poolManager.getSlot0`: a spot mark, i.e. the same class as Wings.
- **Steer** — ledger `S15`. It supplies no isolating price at all: `getTotalAmounts` returns two token amounts and the integrator supplies the price. On its own it does not stop the claim; the isolation would have to come from a price source IndexedEx supplies, which the survey did not inspect for Steer.
- **Visor and Gamma V3 (postmortem class)** — SYNTHESIS "Exclusions from primary postmortems", ledger `S22`, `S23`. Both mint from live pool price (`currentTick()`; manipulated pool price). They are the documented instance of the class and the survey excluded them on that basis; the Gamma ratio-checker exception (`S23`) is additionally a deposit-side hazard that is not the same thing as this claim.
- **Revert `V3Oracle`** — ledger `S17`, as a rate source: the `twapSeconds == 0` branch reads `slot0`. Not a vault design, but it is an inspected component whose configuration decides whether a rate is live-spot.

Not in this class, and the survey is explicit about why: **ICHI legacy** (ledger `S9`) has no withdrawal rate to be live at all — it is a deposit-side spot-vs-TWAP guard — and **Panoptic** (`S16`) reads stored accounting.

## Q2. Inspected designs that would stop a permitted liquidity change from changing what a holder is paid

Two mechanisms are supported by the survey, and neither is an inspected Uniswap vault:

1. **Stored single-token accounting** — SYNTHESIS "Recommendation" (table row "Recommended pattern": `getRate` reads accounted target / supply); shape precedent **Panoptic** `CollateralTracker.convertToAssets`, ledger `S16`. The recorded mechanism is "an accounted target-token counter, not `balanceOf` and not pool state", so a change in pool depth cannot move the rate. Two conditions the survey itself attaches: it must cover the deposit credit and the redeem payout, not only `getRate` ("It does not by itself fix a deposit function that still prices off the pool"), and there is no drop-in production Uniswap vault to copy, because Panoptic "is options collateral, not an LP vault" (SYNTHESIS "Executive summary").
2. **Cached external mark** — **Maker `GUniLPOracle`**, SYNTHESIS "Alternative precedent, not the recommendation". `peek()`/`read()` return the last `poke()` and `poke()` is limited by hop (default 1 hour), so a liquidity change inside the attacker's own transaction cannot re-price the holder through that path. Limits the survey records: the cached value is derived from live pool liquidity and price at poke time, so a later poke reflects the added depth; `seek()` itself still calls the vault; Arrakis V2 `underlying()` "still reads `pool.slot0()` for the fee tick even when a price is supplied"; and the synthesis's own verdict is that it "does not make a live `AtPrice` call safe, and it is not the recommended pattern".

Everything else inspected fails this test: Charm (`S14`), Arrakis V2 (`S4`), Gamma V4 (`S13`), Visor/Gamma (`S22`, `S23`) price from live state; Steer (`S15`) and ICHI legacy (`S9`) supply no isolating price; Bunni v2 (`S18`, `S25`) is unsupported by the survey; Balancer `ERC4626RateProvider` (`S21`) delegates to a provider the survey did not read.

So the survey's direct contribution to Q2 is mostly negative: **no inspected production Uniswap vault design, on the survey's own reading, stops a permitted liquidity change from changing a payout.** What the survey offers is a shape (`S16` / SYNTHESIS "Recommendation"), a cached-mark precedent (SYNTHESIS "Alternative precedent"), and the recorded fact that every fee-earning vault it inspected prices payouts from live pool state.

## Q3. What IndexedEx gives up per candidate

**For stored single-token accounting (SYNTHESIS "Recommendation"; shape precedent Panoptic `S16`):**

- Fee earning is **not** given up: "the Uniswap position still earns swap fees while price is inside the range".
- Continuous fee recognition in the rate **is** given up: fees "enter the rate only when target tokens actually move into the accounted balance: a settled swap, a harvest, a deposit, or a redemption". The rate is flat between conversions, so the vault's headline rate stops drifting upward on its own.
- A continuously executable single-token rate for the whole position **is** given up: "The other token stays out of the rate until a separate conversion credits target. That conversion is outside `getRate` and does not use `slot0`." The second leg becomes a real transaction, so the rate is a stored accounting number rather than an instant, realisable single-token quote of the position.
- Wings' live liquidation quote goes away: SYNTHESIS "Recommendation" lists "Wings spot liquidation" among the exclusions, and the table row for Wings reads "No. This is the bug." (recorded by the survey; I am not proposing a Wings change here).
- An instant mark of actual holdings goes away: the rate reads an accounted counter, explicitly "not `balanceOf`".
- There is no drop-in to copy: Panoptic is options collateral, not an LP vault (SYNTHESIS "Executive summary"), so the shape would have to be built.

**For the cached external mark (Maker `GUniLPOracle`, SYNTHESIS "Alternative precedent"):**

- A continuously executable rate **is** given up: `peek()`/`read()` return the last `poke()` and `poke()` is limited by hop (default 1 hour), so the value can be stale for up to about an hour and a redemption cannot demand a fresh value on demand.
- A live quote path must be absent or provably unused: the synthesis records that the precedent "does not make a live `AtPrice` call safe", and that `seek()` still calls the vault.
- New external dependencies: two independent USD oracles plus a poke/keeper, and a same-pool `slot0` read that survives in the position layer (Arrakis V2 `underlying()` for the fee tick).
- The survey's own verdict applies: "it is not the recommended pattern" — an alternative precedent, evidence, not a chosen design.

**Trade-offs the survey already recorded for the designs it rejected** (for completeness; these are not suggestions, since none of them helps):

- Charm (`S14`): two-token pro-rata shares — taking it gives up the one-token rate IndexedEx already has.
- Arrakis Pro (`S5`, `S6`, `S7`): "issuer-owned vaults, not public depositor shares", ERC-4626 rate used to rebalance and "not a public share rate", private vaults on V2 core — taking it gives up public share ownership.
- Steer (`S15`): "Pushes the price choice to the caller" — taking it moves the price choice, and its manipulation risk, onto IndexedEx; the survey inspected no external price source for Steer.
- ICHI current (`S10`, `S11`): one-token deposit and "claims no privileged rebalance", but the inventory rebalance "may sell preferred token when over-inventory" — taking an inventory manager gives up the no-privileged-rebalance property. Note the survey's own gap: "ICHI current Solidity was not opened", so only the marketing-level facts are known.
- Gamma V4 (`S13`) and Arrakis V2 (`S4`): taking them keeps live-pool pricing, which is the claim itself.

## Q4. What must not be taken from the survey

1. **The survey's headline result is a spot-rate result, not a liquidity result.** "No inspected production Uniswap vault both earns swap fees and exposes a view one-token rate that ignores the same pool's spot price" (SYNTHESIS "Executive summary") says nothing about a payout path that reads depth. The synthesis says it outright: "A `getRate` that does not read same-pool spot does not emit that quote. It does not by itself fix a deposit function that still prices off the pool." (SYNTHESIS "Exclusions from primary postmortems"). Since the claim path is `Money._deposit`/`Money._redeem` reading `LiquidationQuote.quote()`, a `getRate`-only change leaves deposit and redeem still reading `slot0` and depth. Taking the headline as an answer to APEX-2026-012 would be wrong.
2. **The survey's exclusion criterion was spot-only, so its recommendation set carries no clearance for the depth channel.** Every exclusion (Wings, Arrakis V2, Gamma/Visor, Bunni v2) was excluded for reading same-pool spot (SYNTHESIS "Recommendation" exclusion line; `S4`, `S13`, `S14`, `S18`, `S22`, `S23`, `S24`). A design can pass the survey's spot test and still read live depth; the survey never asked whether a liquidity change moves the payout, so it produced no evidence on it. Its silence is not evidence of safety.
3. **ICHI legacy (`S9`) cannot be carried over.** It is a deposit-side spot-vs-TWAP guard with a 1% initial threshold, it exposes no `getRate`, and a depth-only change moves neither spot nor TWAP, so it cannot detect or stop this claim.
4. **Maker `GUniLPOracle` cannot be carried over as a live-price design.** "It does not make a live `AtPrice` call safe, and it is not the recommended pattern" (SYNTHESIS "Alternative precedent"). It may be taken only as evidence that a cached external mark is a thing peers do.
5. **The Arrakis external-oracle line is not a redemption-pricing precedent.** The oracle there "is a rebalance check, Chainlink, RedStone, or Uni V3 TWAP" (`S8`), and the Arrakis Pro ERC-4626 rate is "used to rebalance, not a public share rate" (`S5`). Neither is an inspected precedent for paying a holder.
6. **The fee premise and the "no hypothetical sale" premise answer the old question only.** "The rate does not read `slot0`, a quoter, or a hypothetical sale of the other token" (SYNTHESIS "Recommendation") is a statement about `getRate`. The simulated sale into remaining depth is precisely the mechanism the claim report puts in `LiquidationQuote._sell` (ledger `S3`), and the survey says nothing about that path.
7. **Nothing in the survey supports the auditor's fix list.** The TWAP-bounded `V_ref` with mint-at-max/redeem-at-min, the depth cap on `_sell`, `HolderValueLoss` against `V_ref`, the exit fee and the SEC-08 round-trip test come from the auditor (REPORT.md, "The auditor's fix, not adopted here"; optional-context section "Fix"). The report states it "does not adopt any of those", and the survey offers no independent evidence for them.
8. **Items the survey cannot speak for at all** — no suggestion may rest on them: Bunni v2 (SYNTHESIS "Gaps"; `S18`, `S25`: postmortem body not independently read); Arrakis Pro V4 share formula (`S6`: not published); ICHI current internals (`S10`, `S11`: Solidity not opened); DefiEdge, Teahouse, Orange and Maverick (`SYNTHESIS "Gaps": hosts did not resolve on the first pass; Teahouse and Algebra docs found later, "Neither publishes a view `getRate` that ignores same-pool spot"); the unexecuted third-party reproduction of an August 2026 Arrakis V1 mint/burn (`SYNTHESIS "Gaps"); Balancer `ERC4626RateProvider` (`S21`: lane read not re-verified by lead).

# Limits

- I read only the admitted files plus the single optional-context section. I did not open the Wings contracts, the PoolManager, the Ganarly or Balancer implementations, or any protocol source beyond what the synthesis and ledger already record; the claim mechanics in E1 are cited from the claim report and that section, not re-derived from code.
- I did not run Forge, tests, git, or installs, and I hold no fix authority. Nothing here proposes a Wings change; the Wing-specific statements are the survey's recorded verdicts ("Wings spot liquidation" excluded; "No. This is the bug.").
- The survey itself is dated 2026-10-23 and pins some sources to specific commits (`S4` Arrakis V2, `S14` Charm) and others to `main` (`S16` Panoptic); I read the survey's summaries of those sources, not the sources themselves. A design's mechanism as summarised by the survey is what I rely on.
- The survey reached "complete for the three loop criteria" but explicitly parks unresolved hosts outside the recommendation set (SYNTHESIS "Gaps"). Every "not established" in E2/Q1/Q2 is a statement that the survey did not establish it, not a statement that the design is unsafe.
- Two points this survey cannot settle, and I flag them rather than assume: (a) whether a stored-accounting rate can fund a one-token redemption without any pool read — the survey specifies the rate's storage, not redemption funding; (b) whether the cached-mark precedent survives the *settled* variant, where deposit and redeem are separate transactions — the cached value derives from live pool liquidity and price at poke time, so a later poke reflects the added depth, and the survey does not record who may call `poke()`.
- The survey recommendation is evidence of what was found, not a decision, and this response treats it that way throughout. Q2's "stored single-token accounting" and "cached external mark" are the only two things the survey supports as candidate mechanisms, both with the conditions recorded above; I am not claiming either has been chosen.
