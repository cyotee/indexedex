# Session handoff: V4 Wings vault design and same-pool swap evidence

Date recorded: 2026-10-26.
Source session: `01a171a0-0d64-7a6c-b2a0-834fc1e0e7f7`.
Purpose: brief a new session. This file is a record of discussion and research state. It is not an implementation decision, an audit closure, or a finished answer to the same-pool question.

Point a new session at this file first. Then open only the artifacts named below. Do not reconstruct the recommendation from chat memory.

## Paste this into the new session

```text
Read docs/research/SESSION_HANDOFF_v4-wings_20261026.md and follow it.
Do not implement. Do not change getRate away from a normalized one-whole-share
actual withdrawal-and-sale preview. Do not assume an independent price exists.
The first design council is published. The same-pool evidence council is
published at docs/research/v4-same-pool-swap-evidence-20261026-01a171a0/REPORT.md.
It is a partial full council. Do not edit its frozen draft. Do not implement it.
```

## What the user asked, in their words

First request, 2026-10-25:

> What does the council recommend for the entire vault design, everything. How to deposit, and withdrawal.

They also required the council not to be limited by existing requirements, and to recommend the ideal design even if that changes prior expectations.

Second request, 2026-10-26, after the first council said a qualified independent price was required:

> The problem is finding that independent pricing source. We only have our TWAP Oracle because we will be targeting tokens whose only liquidity is the uinderlying pool. As far as I see it, the only reliable price course is the underlying pool. So, I want the council to consider if swapping could really protect us against malicious price manipulation by capturing the change. I want the council to actually research the matter and provide evidence supporting their claim.

Third request, this handoff:

> Please record our discussions so far so I cna use it to inform a new session.

The same-pool council is now published. Read its REPORT.md and coordinator/resolution.md. The frozen draft was not edited after review. Astra has no original. The report is not implementation authority.

## Standing constraints for every later session

1. `getRate` stays a normalized quote for redeeming one whole share into target through the actual withdrawal-and-sale preview. It is not NAV, not a clamp, and not a full-book average. Amount-specific previews quote their own size. A view does not execute a trade. This correction is not implementation authorization. The stored agreement has been broken three times and is marked NEEDS-HUMAN: do not redefine `getRate` again.
2. Accounting recommendations may change prior PRDs and owner rulings, but every changed expectation must be named. Historical documents are evidence, not a veto.
3. For the follow-up question, do not assume an independent venue or feed. The premise is: the target token's only liquidity is the underlying pool, and the available reference is this project's TWAP of that pool.
4. Neither council authorizes production edits, tests, deployment, or a chosen implementation.
5. Do not treat "the price is manipulable" or "a swap really happened" as a proof. A claim needs a closed attacker ledger or a stated invariant and its domain.

## Discussion 1 — whole vault design

Status: **published research council, not implemented.**

Root: `docs/research/v4-wings-complete-design-20261025-01a171a0/`

Read:

- `REPORT.md` — coordinator final after one advisory pass. Final wording was not sent back for member approval.
- `coordinator/resolution.md` — all 29 advisory concerns, including rejected premises.
- `coordinator/draft.md` — immutable reviewed draft `draft-v4-wings-complete-design-20261025-01a171a0-r1`.
- `members/{astra,grok,minimax,kimi}/response.md` and the feedback artifacts.

Roster: Astra (`gpt-6-astra:high`), Grok (`grok-4.7:xhigh`), MiniMax (`MiniMax-M3`, adaptive), Kimi (`k3:high`). All four originals and one feedback pass settled. Astra and Grok requested changes. MiniMax and Kimi supported with reservations.

### Selected machine

One fungible 18-decimal ERC20 share of the whole portfolio.

Deposit:

1. Pull the caller's target, or both tokens on the dual-token route.
2. Target-only convenience swaps about half of the entrant's own target. That percentage is execution convenience, not the fairness formula.
3. Add matched liquidity to the existing full-range core.
4. Put token0 overage into an eligible upper wing and token1 overage into an eligible lower wing. If a wing cannot take it, retain credited idle or refund it. Do not overwrite a live range.
5. Mint from the reference value of the **final retained liquidity increments and idle**, not from gross input and not from a live liquidation quote.

```text
minted = existing supply * net contribution value / existing portfolio value
```

Old fees, including fees the old LPs earn during the entrant's swap, stay in the denominator. The entrant pays for a fraction of those fees by buying shares against a larger old-equity value. The entrant bears their own swap fee, impact, and reference-valued placement discount.

Withdrawal:

- Remove only `q/S` of every position and both idle balances. The last holder takes all real equity, not another floor.
- Strict target route sells only that holder's opposing slice and pays actual target received, subject to `minTargetOut`. No top-up from other holders.
- Explicit two-token in-kind redemption does not need an oracle, a buyer, or a quote walker.

Fees belong to all current shareholders. Collection is separate from placement. Every communal placement, including compounding into an unchanged wing, needs a fresh reference and a cumulative loss budget. No portfolio-funded swap rebalance in the first release.

`getRate` is the strict one-whole-share target-exit preview, normalized as whole target per whole share times `1e18`. If supply is below one whole share, that quote is unavailable. Do not publish synthetic `1e18`.

### Tradeoffs the first report left for the owner

- Full retained-imbalance credit needs a qualified independent reference. The report said not to launch that product with a same-pool fallback. **The user then rejected that prerequisite as unavailable.** Discussion 2 exists because of that.
- Shares are not raw target. Initial listing is an ordinary pool of the share token. A live `getRate` is not a safe price for unredeemed inventory.
- Strict target exit and `getRate` may fail. In-kind is the quote-independent exit. That narrows older "target exit always works" expectations, including the historical APEX-026 posture. It does not close APEX-026.
- New 18-decimal shares, no initial exact-output, no foreign-manager nested buffering, no cash sleeve, and no mandatory one-target-atom floor.
- Empty-state unowned surplus is cleaned to a fixed recipient before bootstrap. It is not a live senior claim and not a gift to the first minter.

### What the first council did not prove

It did not run tests. It did not prove that every same-pool or self-executed price is unsafe. Kimi's executed-price rule was rejected as a release basis because it was unproved, not because a profitable round trip had been exhibited. MiniMax's live-composition mark and `getRate` clamp were not selected. Grok's silent unpriced mode was not selected.

## Discussion 2 — can the swap itself capture manipulation?

Status: **research started, council report not published.** The user stopped it for this handoff.

Root: `docs/research/v4-same-pool-swap-evidence-20261026-01a171a0/`

Read `brief.md` for the required question. `RUN.md` was stale at interruption: it still said Grok, MiniMax, and Kimi were running. The actual state is below. There is no `REPORT.md`, draft, or advisory pass.

### Member status

| Member | Task | What happened |
| --- | --- | --- |
| Astra | `st_01a1773c` | Settled with a provider content-policy refusal. No original. Do not substitute another model for that failure if the same council rules still apply. |
| MiniMax | `st_01a1773e` | Completed. Full inline text preserved at `coordinator/received-originals/minimax.md`. Not independently re-executed by the coordinator. |
| Grok | `st_01a1773d`, child `01a1773c-665b-71a0-ac04-81b10126a77e` | Completed. `apply_patch` was unavailable. The native transcript delivery was truncated. No complete receipt file was saved. Headline only is recorded below. |
| Kimi | `st_01a1773f` | Completed inline. Delivery cuts off inside the reproducible model. No complete receipt file was saved. A 34,401-byte completion text exists at `/Users/cyotee/.omo/agent/projects/indexedex-5248cf3d3615/senpi-task/completion-results/st_01a1773f.txt`; treat it as possibly truncated. |

Recover missing full texts from the session logs before synthesizing. Do not invent the missing pages. Session artifacts live under:

`/Users/cyotee/.omo/agent/sessions/--Users-cyotee-Projects-indexedex--/2026-10-25T05-54-37-028Z_01a171a0-0d64-7a6c-b2a0-834fc1e0e7f7-artifacts/`

### What is already source-checked

Current Wings issuance does **not** execute the proposed protective swap. `Money` mints and redeems from a live whole-book liquidation quote. Audit APEX-012 is that machine. Reported PoC profits were not rerun in this session.

Current project TWAP is not a normal historical TWAP:

- `UniswapV4TruncatedTwapOracleLib.write` credits the whole idle gap with the live tick read at poke time, truncated to 9,116 ticks from the previous recorded tick.
- `observe` extrapolates the tail with the live tick.
- `update` is permissionless and resets `writeAge`.
- APEX-050 reports push, poke, restore: spot restored, `consult(1800)` mean tick 9116, adapter price about 2.488e36 versus fair 1e36, fee cost about 2,866.8 tokens. The profitable consumer in that PoC is a hypothetical lender written in the test, not the Wings vault. No consumer was verified as reading this oracle. The PoC was not rerun.
- A corrected anchor would credit the elapsed gap with the previous tick. That removes retroactive fill of the old window. It does not reconstruct prices between pokes, and the next interval can still be poisoned by the tick recorded at the poke. With no other venue, there is no outside arbitrageur who must restore the pool.

### Coordinator numerical evidence, already executed

This is coordinator research, not council consensus and not an EVM test.

Code: `research/model.py`
Results: `research/results.json`
SHA-256 when written: model `d5eeb576065b125d013a8343144e66755fd52d53186adb3e560a772b91e5f698`, results `834985f01e5f7ca89dca94b729c89465c58e58ed5edbb6c3d3ae0dfa9271c7e2`.

Model domain: token1 is target, token0 is opposing, both 18 decimals, one active core interval, vault starts as a full-range LP, 0.3% fee unless varied, integer formulas ported from TickMath, SqrtPriceMath, SwapMath, and LiquidityAmounts. Upper wing is funded above the post-entry price and does not activate on the later downward sale. No hooks, protocol fee, harvest reshape, or converted-wing maintenance. Native token ledgers closed at zero error in the executed cases.

Witness, rule `executed_average_actual_composition`, vault owns 100% of 100e18 active liquidity, attacker starts with 200 target and nothing else:

1. Swap 100 target in. Receive about 49.925 opposing. Fee 0.300 target, credited to old LP.
2. Mint about 66.600 shares from pre-add actual token composition marked at the fee-inclusive execution price `100 / 49.925`.
3. Matched core add about 50.075 liquidity. Upper wing add about 49.690 liquidity. All leftover idle is credited, not donated.
4. Burn the new shares immediately. Remove only their slice. Sell that opposing slice.
5. Attacker ends with 0 opposing, 0 shares, 0 LP, 0 debt, and **204.313684168578358357 target**.
6. Realized target gain: **4.313684168578358357**. Incumbent target claim falls from about 100 to about 95.686. Opposing claim stays about 100.

That is a closed target-token profit after real entry and exit swaps, with the vault's own liquidity filling both swaps and earning the fees. It contradicts "the swap captures the manipulation, so this mint rule is safe" for this rule and this state.

Same model, 0.3% fee, 200 target deposit, half swap, by vault share of active liquidity:

| Vault fraction | Attacker target gain |
| --- | ---: |
| 1% | -0.593 |
| 10% | -0.369 |
| 50% | +1.864 |
| 90% | +3.903 |
| 99% | +4.274 |
| 100% | +4.314 |

Same rule, vault is the whole active book, 0.3% fee:

| Deposit | 49% swap | 50% swap | 51% swap |
| --- | ---: | ---: | ---: |
| 2 | -0.006 | -0.006 | -0.006 |
| 20 | -0.037 | -0.022 | -0.006 |
| 200 | +3.972 | +4.314 | +4.654 |
| 2000 | +23.680 | +24.208 | +24.726 |

Of 24 fee/depth cases for that rule, 19 were positive and 5 were negative. The largest gain in that grid was about 4.706 target at zero fee and 100% vault ownership. The worst was about -1.980 target.

Controls in the same 200-target, 100% vault, 0.3% case:

- Ideal historical reference fixed at price 1, ranges valued at that reference: attacker **-1.139 target**. This is not a proof that every TWAP is safe. The reference was defined as the pre-manipulation price and was not updated by the attack.
- Proportional vector join with unmatched refund, then the attacker liquidates their own refund through the pool: **-0.450 target**. No positive case in its 24-case grid.
- Post-swap spot marking of actual composition was worse for incumbents: attacker **+13.806 target**.
- Marking the new ranges at the execution price, rather than live composition, still made **+5.534 target**.

So, in this model, executing the swaps does not protect the executed-price or spot-price mint. A price-free proportional join does not show the extraction. A reference that the attacker cannot move also does not show it. Dominance of the pool and deposit size matter: small deposits into a deep external book lost money after fees.

### Member claims, after coordinator recheck

Receipts are filed. Rechecked arithmetic is in `research/recheck.json`. Unrechecked rows stay member-reported.

MiniMax, rechecked: idle opposing-heavy book, loan repaid by buying opposing through the same pool. Literal rule profit `5162744.89786187` target at a 49% entry, opposing end 0. The 50%, 51%, and 1% entries on that book also rechecked closed and positive. Controls without the vault loop were negative. Default wing spacing was disclosed as likely to activate on that path. The 13,500-case count was not re-executed.

Grok, full original filed. The Domain L snippet rechecks at exactly `320226133435299/10170234955199` when a same-asset opposing loan is repaid in kind and the lender does not sell it here. Domain N excess of about `-2.4e-4` is member-reported and was not in the rechecked snippet.

Kimi, full delivered text filed. W4/W5 and the TWAP replica are described, not coded. Baseline live-quote mint rechecks closed at about `+18055.89` target, opposing about 0. The `+9627.8` literal-rule row rechecks as convention value of residual opposing, not closed target profit: target delta about `-9833.90`, opposing delta about `+19461.68`.

### Answer that can be given now, and its limit

Executed deposit and withdrawal swaps do **not** by themselves make same-pool share issuance safe.

They do price and settle the tokens that actually trade. They do not price the vault inventory that does not trade. If old opposing inventory is marked with the execution price of a smaller swap, the attacker can move that price, mint against the discounted book, and sell their slice back. The swap captures the attacker’s own traded quantity. It does not capture the revaluation of the unsold book.

That statement is supported by the coordinator witness above for one exact mint rule. It is not a proof about every possible same-pool accounting rule, every pool fee, every vault share of liquidity, or the production Wings contract. Production reachability is unverified.

The current TWAP, as implemented, cannot be the manipulation-resistant reference for this problem. APEX-050 is a source-and-reported-PoC result about the oracle, not a Wings profit result.

The no-price alternative that survived the executed controls is proportional entry: add the same fraction of every existing position and idle balance, refund the unmatched tokens, and let the user or router do any zap outside the mint equation. That gives up full credit for arbitrary retained imbalance. It is the alternative to study if the product cannot accept an independent feed and cannot accept the demonstrated mint-price extraction.

A same-pool TWAP can still be studied as a cost and a gate: corrected anchoring, no live-tail fill, covered history, deviation bounds, size caps, and time delay. Those can make an attack expensive. They are not an independent price, and no calibrated parameter set was shown to make the executed-price mint safe.

## Product facts the next session must not confuse

- Supported V4 vault family: `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`. Legacy V4 Standard Exchange and both V4 FullSpread families are deleted. Do not restore them.
- Project TWAP: `contracts/oracles/uniswap/v4/twap/`. It is an external poke oracle, not a V4 hook. V4 PoolManager has no built-in observations.
- Current `getRate` divides a whole-book liquidation quote by supply and returns synthetic `1e18` at zero supply. The requested semantics are different and were not implemented.
- `StandardExchangeRateProviderFacet` uses a full-supply preview. Pointing it at a new one-share `getRate` is a new integration, not an automatic fix.
- Buffer hooks can value held shares with a scalar rate without redeeming them. Actual-size redemption of one leg does not validate every other rated reserve.
- No production file was edited in either research run. No project Forge test or build was run. Standalone Python is not production validation.

## If the new session continues the research

1. Do not implement.
2. Preserve `getRate` semantics.
3. Do not recover the originals again. They are at `coordinator/received-originals/{grok,minimax,kimi}.md`. Astra has no original.
4. Do not edit `coordinator/draft.md`. Its ID is `draft-v4-same-pool-swap-evidence-20261026-01a171a0-r1`. sha256 `54172c64b0cefb36c78d9c677062f14e833f42acfc0d365064a28ca4e480898f`.
5. Advisory settled. Grok supported with reservations. MiniMax and Kimi supported. Receipts are under `coordinator/received-feedback/`.
6. `coordinator/resolution.md` and `REPORT.md` are published. Post-review wording is a coordinator revision, not member-approved text.
7. A production-first Foundry witness is a separate authorized task. Do not run it just to finish the research note.

## If the new session is asked to choose a design

The choice is now explicit:

| Choice | What the user gets | What the evidence says |
| --- | --- | --- |
| Independent-reference NAV mint | Full credit for retained imbalance in one share | First council's preference. User says no such feed exists for the target pairs. Do not invent one from this pool. |
| Executed-swap price mint | Target-only deposit and full imbalance credit | Coordinator witness shows a closed target profit when the vault is a large share of the only pool. Not safe as specified. |
| Current live liquidation quote | Already implemented | APEX-012. Not the proposed swap design, and not safe on the reported evidence. |
| Current TWAP as the mint reference | Uses the only oracle the user has | APEX-050: one poke can fill an idle window. Even a corrected TWAP is still this pool's history, not an outside price. |
| Proportional join and refund | No price in the mint | Survived the executed controls. User does not get automatic full credit for unmatched tokens. |
| Do not launch single-asset imbalance credit | Avoids the unpriced exchange | Honest if neither a feed nor proportional refund is acceptable. |

No option was selected by the user after seeing this evidence. Do not pick one silently and start coding.
