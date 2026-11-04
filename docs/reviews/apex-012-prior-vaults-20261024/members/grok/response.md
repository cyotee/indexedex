# Member response

## Identity

- Run ID: apex-012-prior-vaults-20261024
- Member label: grok
- Profile: research
- Phase: initial independent response
- Owned path: docs/reviews/apex-012-prior-vaults-20261024/members/grok/response.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

- Question: From the vault survey already completed, what can IndexedEx take, and what can it not take, for the liquidity-manipulation claim in APEX-2026-012?
- Required targets: `.omo/ulw-research/20261023-171500/SYNTHESIS.md`; `.omo/ulw-research/20261023-171500/sources-ledger.md`; `docs/reviews/apex-012-auditor-claim-20261024/REPORT.md`
- Optional context: the APEX-2026-012 section in `docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md`, only to check a sentence the claim report cites
- Admitted read scope: those files, plus a ledger URL when a suggestion depends on a sentence the synthesis does not quote. No new protocol search.

The four answers below are the question. The synthesis recommendation is evidence of what the survey found for a different question. It is not a decision already made. This response does not redesign Wings.

## Evidence

Public fetches used, all URLs already listed in the ledger or the raw form of a listed blob URL. No private source excerpt was sent. No new protocol was searched.

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| Claim to answer | `docs/reviews/apex-012-auditor-claim-20261024/REPORT.md`, "What the auditor claims" | source observation | Deposit and redeem set share price from `LiquidationQuote.quote()`. That quote reads live slot0, getLiquidity, and the tick bitmap, subtracts only the vault's own liquidity, and simulates selling the other token into the remaining depth. A permitted liquidity add raises that quote. Redeem then pays more from remaining holders. The spot-move sequence and the unsettled in-unlock path are separate broadenings. The report does not adopt the auditor's fix list. |
| Survey question | `SYNTHESIS.md`, Executive summary and Recommendation | source observation | The survey asked for swap-fee earning plus a view one-token rate that does not read same-pool spot. It found no inspected production Uniswap vault that does both. |
| Wings | `SYNTHESIS.md`, Quote functions table and Recommendation; ledger S2, S3 | source observation | `EconomicTarget.getRate` calls `Quote.quote`, which reads `getSlot0`. S3: `_prepare` reads `manager.getSlot0`; `_quote` simulates an opposing-token sale. The table says this is the bug and does not enter the recommendation. Local Wings files were not re-read. |
| Survey formula, not a vault | `SYNTHESIS.md`, Recommendation | source observation | Proposed formula: accounted target tokens * 1e18 / supply, for deposit, redeem, and getRate. It does not read slot0, a quoter, or a hypothetical sale. Fees enter only when target tokens move into the accounted balance. The other token stays out until a conversion outside getRate. Storage is an accounted counter, not `balanceOf` and not pool state. The same section says this is not an inspected production vault. |
| Spot exclusion is not this claim | `SYNTHESIS.md`, Exclusions from primary postmortems; ledger S22, S23 | source observation | Visor mint used `currentTick`. Gamma 23 Jan 2024 was a single-sided ratio exception plus a manipulated pool price. The survey calls both the spot-quote class and says a getRate that does not read same-pool spot does not emit that quote, and does not by itself fix a deposit that still prices off the pool. |
| Arrakis V2 pricing | Ledger S4, fetched text of `https://raw.githubusercontent.com/ArrakisFinance/v2-core/21e662bce6aa206534f4f909cb86a45854428911/contracts/libraries/Underlying.sol`; `SYNTHESIS.md`, Quote functions table | source observation | `underlying()` always reads `pool.slot0()`. A supplied sqrt price replaces only the price used for amounts. The tick used for fees stays the live tick. Amounts come from `LiquidityAmounts.getAmountsForLiquidity` on the position's own liquidity. Fees come from fee growth and `tokensOwed`, not from tick liquidity. Idle `balanceOf` is added. No swap simulation and no pool-liquidity read appear in that file. The synthesis says the result is two amounts and that V1/V2 are deprecated. |
| Arrakis status and oracles | `SYNTHESIS.md`, Exclusions and Alternative precedent; ledger S8, S24 | source observation | V1/V2 deprecated 15 Jun 2026. S8: the Arrakis oracle is a rebalance check, not a public share rate. |
| Charm pricing and withdraw | Ledger S14 blob URL; raw text fetched from `https://raw.githubusercontent.com/charmfinance/alpha-vaults-v2-contracts/0174095f918b5a883c3726cbe4556aaa58f12c82/contracts/AlphaProVault.sol` because the blob page did not return source. `SYNTHESIS.md`, Quote functions table | source observation | `_amountsForLiquidity` reads `pool.slot0()` and calls `getAmountsForLiquidity` on the vault position's liquidity. `withdraw` pays a share of idle balances plus `pool.burn` of that same position liquidity. It does not simulate a sale into remaining depth. `getTwap` / `maxTwapDeviation` gate `rebalance`, not `withdraw`. The synthesis records two-token pro-rata and a slot0 read, and excludes Charm from the recommendation. |
| Gamma V4 | `SYNTHESIS.md`, Executive summary and Quote functions table; ledger S13 | source observation | Withdraw math is recorded as a spot mark: share value uses `poolManager.getSlot0`. S13 has no URL. The WithdrawLogic file was not opened. The survey does not record a simulated sale or a `getLiquidity` read for Gamma. |
| Steer | `SYNTHESIS.md`, Quote functions table; ledger S15 | source observation | `getTotalAmounts` returns two tokens. The integrator applies an unspecified market price. The survey does not record a slot0 read, a depth read, or a sale. |
| ICHI | `SYNTHESIS.md`, Quote functions table; ledger S9, S10, S11 | source observation | Legacy deposit compares spot and TWAP. The surveyed page has no getRate. Current Solidity was not opened. The survey calls it a guard, not a rate. |
| Panoptic rate | Ledger S16, fetched text of `https://raw.githubusercontent.com/panoptic-labs/panoptic-v1-core/main/contracts/CollateralTracker.sol`, truncated at 50.0KB of 75.3KB; `SYNTHESIS.md`, Executive summary and Quote functions table | source observation | `totalAssets()` is `s_poolAssets + s_inAMM`. `convertToAssets` is shares * that sum / supply. Those functions do not read slot0 or pool liquidity. `previewDeposit` also charges `COMMISSION_FEE`. `takeCommissionAddData` writes `s_inAMM` from amounts the Panoptic pool passes in, not from a liquidity read. `exerciseCost`, in the same file, does read ticks. The tail of the file was not read. The survey says this is options collateral, shape only, not an LP vault. |
| Maker cache | `SYNTHESIS.md`, Alternative precedent, not the recommendation | source observation | GUniLPOracle at commit `0d25676e0956fc3a5359431c708106547c4fef26` derives price from two independent USD oracles, calls `getUnderlyingBalancesAtPrice`, and divides by supply. `peek`/`read` return the last `poke`. `poke` is limited by hop, default 1 hour. `seek()` still calls the vault. Arrakis `underlying()` still reads slot0 for the fee tick when a price is supplied. The survey says this supports a cached external mark, does not make a live AtPrice call safe, and is not the recommended pattern. No ledger row. The oracle source was not opened. |
| Other ledger rows | S17, S18, S19, S20, S21, S25; `SYNTHESIS.md`, Gaps | source observation | Revert `V3Oracle`: slot0 or `observe`, a price oracle. Bunni v2: exploited, postmortem body not read. Doppler and Ekubo: not share vaults. Balancer `ERC4626RateProvider`: getRate delegates to `convertToAssets`; not re-read by the lead. DefiEdge, Teahouse, Orange, Maverick, ICHI current Solidity, and an Arrakis Pro V4 share formula stay outside the recommendation set. Teahouse and Algebra docs do not publish a view getRate that ignores same-pool spot. |

## Assumptions

- The claim's principal sequence adds pool depth and does not, by itself, move slot0. The claim report states that sequence separately from the spot-move sequence. This response did not re-simulate either sequence.
- "Would stop" below means the recorded formula has no input for remaining pool depth, so a depth change that does not also change an input that formula does read would not change its output. It does not mean a test was run. The survey contains no APEX-2026-012 reproduction.
- Uniswap `getAmountsForLiquidity` and a burn of a stated liquidity quantity depend on that liquidity and price, not on other positions' liquidity. That is inference from the calls observed in S4 and S14, not from a Forge run.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| `SYNTHESIS.md` | required | examined | Full file read. |
| `sources-ledger.md` | required | examined | Full table read. S4, S14, and S16 opened. Other rows used as ledger notes only. |
| Auditor-claim `REPORT.md` | required | examined | Full file read. |
| APEX-2026-012 section of the diff review | optional | not examined | The claim report states the liquidity sequence, the spot-move sequence, and the unsettled path in its own words. No cited sentence had to be checked to answer the survey question. |
| Gamma WithdrawLogic (S13) | ledger note, no URL | not examined | The survey records a slot0 spot mark and does not quote the formula. |
| Maker GUniLPOracle source | named in the synthesis, not a ledger URL | not examined | Used only the synthesis paragraph. |
| Local Wings quote files (S2, S3) | ledger paths | not examined | Used the ledger notes and the claim report. Not re-read. |

## Conclusions

No inspected production Uniswap vault in this survey was shown to pay a one-token amount that ignores a permitted liquidity change. The survey did not test any design against APEX-2026-012. What can be taken is a constraint and a rate shape, plus a clear list of results that answer the old spot question and must not be reused as if they answered this claim. The synthesis recommendation is not chosen.

### 1. Live pool depth, or live slot0, does not mean the same failure

The "therefore" in the question holds only for a withdrawal priced from remaining pool depth. It does not hold for every design that reads slot0.

**Prices a withdrawal from live pool depth. Does not stop the claim.**

- Wings. Synthesis Quote functions table and Recommendation; ledger S2 and S3; claim report, "What the auditor claims". `Quote.quote` reads slot0 and simulates an opposing-token sale. The claim report adds getLiquidity and the tick bitmap, and says only the vault's own liquidity is subtracted. Added depth is an input to the amount paid. This is the claim, not a pattern to take. No other inspected design is recorded as simulating that sale.

**Prices from live slot0. That fails the old spot question. It does not, on this record, establish the liquidity claim.**

- Arrakis V2. Synthesis Quote functions table; ledger S4. `underlying()` reads slot0 and returns two amounts from the position's own liquidity, plus fees and idle balances. It does not read remaining pool depth. A slot0 read is not a sale into added liquidity.
- Charm. Synthesis Quote functions table; ledger S14. `_amountsForLiquidity` reads slot0. `withdraw` burns the vault's own position liquidity and pays two tokens. It does not simulate a sale into remaining depth.
- Gamma V4. Synthesis Executive summary and Quote functions table; ledger S13. Recorded as a slot0 spot mark. The formula was not opened. The survey does not support calling Gamma a live-depth pricer, and it does not support saying the slot0 mark stops or fails this claim.
- Visor, 25 Nov 2021. Synthesis Exclusions; ledger S22. Receipt mint used `currentTick`. That is deposit pricing, not a withdrawal from pool depth.

**Does not belong in this bucket.**

- Panoptic `convertToAssets`. Synthesis Quote functions table; ledger S16. The rate reads stored `s_poolAssets + s_inAMM`. It does not read slot0 or pool liquidity.
- Steer. Synthesis Quote functions table; ledger S15. Two amounts plus a caller-supplied market price. The survey does not record a slot0 read or a depth read.
- ICHI. Synthesis Quote functions table; ledger S9. No withdrawal rate on the surveyed page.
- Maker `peek`/`read`. Synthesis, Alternative precedent. The cached view does not read the pool in the caller's transaction. The live path still reaches Arrakis `underlying()`, which reads slot0 for the fee tick. That residual read is not recorded as a sale into remaining depth.

### 2. Which recorded formulas would keep a permitted liquidity change from changing the amount paid

None of these was tested against the claim. "Would stop" is inference from the formula plus the claim's mechanism.

- Panoptic `CollateralTracker.convertToAssets` / `previewRedeem`. Synthesis Executive summary and Quote functions table; ledger S16. The amount is shares times stored assets over supply. An outsider adding Uniswap liquidity does not write `s_poolAssets` or `s_inAMM`. The observed rate functions would not pay more because depth changed. This is options collateral, not an LP vault. The survey says the shape is what can be called. `exerciseCost` in the same file does read ticks; that function is not the rate. The file tail was not read.
- Charm `withdraw`. Ledger S14. The paid amounts are a share of idle balances plus a burn of the vault's own liquidity. Remaining pool depth is not an input. Inference, not a test: a pure liquidity add would not change that payment. This is a two-token V3 withdraw. It does not stop the spot-move sequence, because slot0 is an input to the position amounts. It was not run against the V4 unlock path.
- Arrakis V2 `underlying` / `getUnderlyingBalances`. Ledger S4; synthesis Quote functions table. Same inference for the two amounts: they move with slot0, the position's liquidity, fee growth, and balances, not with other positions' depth. Deprecated. Not a one-token payment. The vault withdraw entrypoint was not opened; the surveyed library was.
- Maker `peek`/`read`. Synthesis, Alternative precedent. A same-transaction liquidity change does not change the cached view, because the view does not read the pool in that transaction. The survey explicitly says a live AtPrice call is not safe. A liquidity change left in place until the next poke is not a recorded test. Inference from S4 plus that paragraph: the underlying amounts the synthesis ties to this oracle are position amounts at a supplied price, not a simulated sale. That inference is not an oracle-source reading. There is no ledger row.

The survey's own formula, in the Recommendation section, is not an inspected design. If deposit, redeem, and getRate all used accounted target over supply, and the counter were not written from a hypothetical sale, a permitted liquidity change would not change the amount paid. That is the survey's proposal. It is not a vault that was inspected, and it is not chosen.

These do not support a "would stop" suggestion:

- Wings. It is the payment path that moves.
- Gamma V4. Slot0 mark only. Formula not opened.
- Steer. The market price is unspecified. The caller could apply a depth-sensitive price. The survey does not show a price that ignores depth.
- ICHI. No withdrawal rate. A deposit guard cannot stop a withdrawal quote it does not price.
- Bunni v2. Ledger S18 and S25. Excluded. Postmortem not read. No pricing formula.
- A view-only copy of any of the above. Synthesis Exclusions: a getRate that does not read spot does not fix a deposit that still prices off the pool. The claim report says `Money._deposit` and `Money._redeem` set the share price from `LiquidationQuote.quote()`. A safe view, with that payment path left in place, does not stop the claim.

### 3. What each design that might help already costs

**Panoptic rate shape, and the same shape in the unchosen Recommendation formula.**

- Fee earning: the Recommendation says the Uniswap position still earns swap fees, and those fees enter the rate only when target tokens actually move into the accounted balance. Taking the inspected Panoptic contract does not bring that LP vault. The survey already recorded "shape only, not an LP vault."
- One-token exit: the rate is a one-token number for tokens already accounted. The other token stays out until a separate conversion credits target. What is given up is a one-token exit that includes a hypothetical sale of the other token inside the rate. The survey does not say a later real conversion is impossible. It says that conversion is outside getRate and does not use slot0.
- Continuously executable rate: the view stays callable. What is given up is a mark that continuously includes live pool value. The survey does not record a hop for this formula. It records delayed recognition of fees and of the other token.
- Something else the survey recorded: the counter is not `balanceOf` and not pool state. Deposit, redeem, and getRate use one formula. A conversion that credited a simulated quote without tokens arriving would not be the formula the survey wrote. Panoptic's `COMMISSION_FEE` on `previewDeposit`, its virtual-share offset, and its open-leg withdraw lock are in S16. They are not in the Recommendation. They are not required costs of the shape.

**Maker cached external mark.** Synthesis, Alternative precedent. Not chosen. Not a ledger row.

- Continuously executable rate: given up. `peek`/`read` are the last poke. Hop default is 1 hour.
- One-token exit: not a target-token vault redeem. The synthesis describes an external mark of Arrakis underlying balances, which are two amounts, divided by supply. IndexedEx would depend on two independent USD oracles.
- Fee earning: the survey does not record a loss or a preservation claim for this precedent.
- Something else recorded: a live AtPrice call is not safe; `seek()` still calls the vault; Arrakis still reads slot0 for the fee tick when a price is supplied.

**Arrakis V2 and Charm, only as two-token payments of the vault's own position.** They might keep a pure depth change from changing the two amounts. They are not a one-token product, and they are not in the recommendation set.

- One-token exit: given up. Both return two token amounts. Synthesis Executive summary and Quote functions table.
- Fee earning: not given up on the surveyed record. Fees are inside the underlying amounts.
- Continuously executable spot-free rate: not provided. Both read slot0. They do not stop the spot-move sequence the claim report also states.
- Something else recorded: Arrakis V1/V2 are deprecated as of 15 Jun 2026, ledger S24, so Arrakis is not a live pattern. Both opened sources include idle `balanceOf` in the amount, which the Recommendation says the rate must not read. Charm's TWAP gates rebalance, not the withdrawal.

Gamma, Steer, and ICHI are not in this list. The survey does not support them as designs that would stop the payment change, so it does not support a give-up analysis for them either.

### 4. What must not be taken, because it answers the old spot question

- The Recommendation as a decision already made. It is evidence for the spot-rate question. Synthesis Recommendation.
- "No inspected production Uniswap vault both earns fees and ignores same-pool spot." Synthesis Executive summary. That negative result is not a result about liquidity-depth resistance.
- The Visor and Gamma postmortem exclusions. Synthesis Exclusions; ledger S22 and S23. They are the spot-quote class. The sentence that a getRate which does not read same-pool spot does not emit that quote answers mint-from-current-price. The next sentence says it does not fix a deposit that still prices off the pool. Ignoring slot0 is not, by that paragraph, a fix for a sale into remaining depth.
- Wings labeled "the bug" only because it reads slot0. The Executive summary groups Wings with Gamma and Visor as reading pool spot. S3 also records the simulated opposing-token sale. Stop-reading-slot0 is not the whole of what the survey recorded about Wings, and the spot grouping is not a finding that Gamma or Visor contain that sale.
- A slot0-free rate that still hypothetically sells the other token into live depth. The survey did not inspect that hybrid. The claim's mechanism is that sale. The Recommendation sentence that does address it is the refusal of a quoter or a hypothetical sale, not the refusal of slot0 alone.
- ICHI's TWAP-versus-spot deposit comparison. Ledger S9. Guard, not a rate, and not a withdrawal.
- Charm's rebalance TWAP. Ledger S14 source. A rebalance guard. The synthesis did not put it in the recommendation. It does not price the withdrawal.
- Revert `V3Oracle`, slot0 versus `observe`. Ledger S17. A price oracle. Not a withdrawal amount. Not discussed in the synthesis body.
- Arrakis oracle as a rebalance check. Ledger S8. Not a public share rate.
- Steer pushing the market price to the caller. Ledger S15. That answers who picks the spot price. It does not record a depth-insensitive withdrawal.
- Bunni's exclusion. Ledger S18 and S25. Exploited, postmortem not read. Not a liquidity-claim finding.
- Doppler and Ekubo. Ledger S19 and S20. Not share vaults.
- Balancer `ERC4626RateProvider`. Ledger S21. Not re-read. Not a Uniswap vault. The delegate shape is already ledger S1. It does not answer pool depth.
- Maker as if it were the recommendation. It is an alternative precedent for not reading the pool in the caller's transaction. The survey did not study it as an APEX-2026-012 fix.
- Panoptic virtual shares, the deposit commission, the open-leg withdraw lock, and `exerciseCost`. Ledger S16. Not the surveyed rate shape. Virtual shares are an inflation offset. `exerciseCost` reads ticks. None of them answers a simulated sale into remaining depth.
- The gaps. Synthesis Gaps. DefiEdge, Teahouse, Orange, Maverick, ICHI current Solidity, and an Arrakis Pro V4 share formula stay outside. The Teahouse and Algebra negative is "no view getRate that ignores same-pool spot." That is the old question.
- The auditor's fix list in the claim report: unlock revert, TWAP-bounded reference, depth cap, loss check, exit fee, round-trip test. The claim report does not adopt them. They are not survey findings. This response does not adopt them.

## Limits

- No Forge run, no attack reproduction, and no execution of deposit or redeem on any surveyed vault.
- "Would stop" is formula inference. The survey's question was spot, not this liquidity claim.
- Gamma WithdrawLogic was not opened. Maker's oracle source was not opened. Local Wings files were not re-read.
- Arrakis and Charm sources are Uniswap V3. The claim is a V4 quote, including an unsettled in-unlock path. The comparison is of recorded formulas, not a claim that V3 bytecode stops the V4 sequence.
- The Panoptic fetch is `main`, as listed, not a pinned commit, and it was truncated at 50.0KB of 75.3KB. Arrakis and Charm were pinned commits. A live `main` file can change. This is not an immutable snapshot.
- Optional diff-review section not examined.
- Public queries: the three raw URLs named in the Evidence table. Private excerpts were not sent. No new protocol search.
- Peers were not read. Agreement is not available. This is not council consensus.
- Runtime or extraction proof: none. Text fetches and local markdown reads only.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
