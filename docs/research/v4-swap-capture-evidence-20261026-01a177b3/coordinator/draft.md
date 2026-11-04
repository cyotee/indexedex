# Coordinator draft

## Draft identity

- Draft ID: draft-v4-swap-capture-evidence-20261026-01a177b3-r1
- Path: docs/research/v4-swap-capture-evidence-20261026-01a177b3/coordinator/draft.md
- Run ID: v4-swap-capture-evidence-20261026-01a177b3
- Status: pending advisory review. This file is not the final.
- Fingerprint: not stored in this file. RUN.md records the sha256 of these bytes before advisory review.
- Sources: the four initial responses, their standalone models where present, coordinator re-execution notes, and the source lines named below. The coordinator is not a fifth vote.

## Participation

- Council kind: full
- Requested members: astra, grok, minimax, kimi
- Substantive initial responses: astra, grok, minimax, kimi
- Missing initial responses: none
- Result label: full
- Coordinator mode: invoking-agent
- Coordinator is an independent vote: no

## Question

When the target token's only liquidity is the underlying pool, and the only reference is this project's TWAP of that pool, do actual swaps during deposit and during exit eliminate APEX-2026-012? State the mint equation, fee cutoff, inventory cutoff, and execution rule for every answer. Do not assume an independent price. Do not treat a price move alone as proof.

## Proposed text

No. An actual swap during deposit, during exit, or during both does not eliminate APEX-2026-012 while the share cut still prices inventory that the swap did not trade.

Production does not do the proposed deposit swap. `Money._deposit` pulls target, harvests, reads `Quote.quote`, and mints `Accounting.issue(supply, value, assets)`. For existing supply that is `floor(supply * credit / value)`. The pending deposit is not in the booked balances when that quote is taken. `Money._redeem` pays `floor(shares * value / supply)` from the same whole-book quote. If the idle target sleeve is short, `_fund` can close positions and `_swapDeficit` can sell the whole local opposing balance, not only the redeemer's slice. `getRate` is that whole-book quote times `1e18` divided by supply, or synthetic `1e18` at zero supply. That is not a one-whole-share withdrawal-and-sale preview. This draft does not redefine `getRate` and does not authorize implementing that distinction.

The audit finding is that temporary depth, or an in-session price move, changes that quote. Mint `m = S * D / V0`, then a quote payout `m * V1 / (S + m)`, gives `profit = D * (V1 - V0 - D) / (V0 + D)` when the payout is paid in target. The reported Foundry profits were not rerun. They are not the evidence below.

A swap prices the quantity that traded. It does not price the vault inventory that did not trade. Extending the execution price, the live whole-book quote, or this pool's TWAP to that untraded inventory is a different rule. That second step is where the rechecked rows extract target.

### Rules, stated separately

1. Production. No entrant swap. Mint and payout use the live whole-book quote after removing this vault's liquidity. Unsold opposing adds nothing. Fee is the pool fee inside the quote sale. Inventory is booked idle, removable principal, and uncollected fees. Pending caller credit is excluded.

2. Real swaps added, quote retained. An entry swap of some fraction of the deposit, and a slice sale on exit, do not change the mint or payout equation. They change the pool the quote reads, and they move tokens. The amounts minted and paid remain functions of the live quote.

3. Executed-price mint. `m = S * D / (A_T + p_exec * A_O)`, with `p_exec` equal to target spent divided by opposing received. The fee-aware post-swap form that credits old LP fees and values retained tokens collapses to marking the pre-swap book at `p_exec` when the vault is the counterparty and all swap output is retained. Exit removes only the holder's fraction and sells only that slice's opposing. A 49%, 50%, or 51% swap is a parameter, not a safety threshold.

4. Price-free proportional position-vector mint. The accepted fraction is the minimum component ratio. Unmatched tokens are refunded in kind. Components are idle target, idle opposing, and each range's liquidity, not one scalar of liquidity units across disjoint ranges. Exit removes that same fraction. A sale of the exiter's own slice is a separate step from the mint.

5. Same-pool TWAP as a mint reference or a gate. As written, `update(PoolKey)` is public, reads live slot0, and `write` credits the elapsed gap with `truncate(liveTick, prevTick)`, capped at 9,116 ticks. `observe` and `consult` can fill an unwritten tail with that same truncated live tick. An idealized historical TWAP that does not backfill is a different object. Neither is an outside price.

### Rechecked closed rows

These are coordinator re-executions, not a second vote. Each domain limit stays attached to the number.

Production-shaped quote, no deposit swap. Grok `rule1_jit`, fee 3000: attacker target delta `+1179070738173910`, opposing delta 0, shares 0, debt 0, incumbent idle target delta the exact negative. The no-JIT control is `-1`. Kimi's model printed a settled-JIT profit of `15242727659.270647`, equal to `D(V1-V0-D)/(V0+D)`, with incumbent loss equal to that profit. Those two programs use different book sizes. Both closed a quote-payout profit. Neither is a rerun of the audit PoC.

Swaps added, quote retained. Grok's 1-wei, 1%, 49%, 50%, and 51% entry swaps before the same JIT quote payout all stayed positive. Kimi's model printed `+10879800366.892393` for a 50% entry swap, quote mint, and slice sale under settled JIT, against a no-JIT control of `-5089304282.61814`. The coordinator interval ledger, vault swap of half a 200 target deposit before the quote, then a slice exit, closed at `+16.466617` target when the vault owned the interval and `+4.782512` at half ownership. Fee 0.3%. Ending opposing was 0.

Slice exit does remove the extra profit that comes from paying the JIT-inflated whole-book quote. In the coordinator ledger, full ownership and 10x temporary depth, the quote payout was about `60.44` target and the slice sale was about `22.18`. With no temporary depth, the quote payout returned the deposit and the slice sale still made `22.199955` target, because the quote had valued unsold opposing at zero and minted too many shares. Grok's quote-mint then slice-exit row, with no prior push, closed at `+1103316364600005`. An exit swap is not a repair of a quote mint.

Executed-price mint, both swaps. Coordinator interval ledger, vault owns the only active liquidity, deposit 200, half swapped, fee 0.3%: profit `909146072454192229/210758608401740140` = `4.313684168578358362` target, opposing 0. Zero fee: exactly `80/17`. Of 288 fee, size, split, and ownership cases, 155 were positive. Astra's idle-target witness, old opposing zero, deposit 100, swap 50, zero fee: attacker finishes at 105, incumbent close 95, pool restored. The 0.3% gross-credit row rechecks at `10470058473/99880180`. MiniMax's idle-opposing function, swap of the whole 100e18 deposit, fee 0.3%: exact profit `182670959878875300000000000000000/90821980886249`. Kimi's model printed `+6462528490.257205` for a 51% swap on an 80%-opposing book, and `+8638361543.096815` for the fee-aware post-swap form at a 30% swap. The same model printed `+3128158354.8193827` for a 5e11 deposit at 51%. The response prose rounded that last row to `3,128,200,000`. Use the print.

Proportional claim. Coordinator control, same 288-case grid: 0 positive. The 200-deposit half-swap loss equalled the no-vault swap-and-reverse loss, `-8973027/19940090`. Grok's rechecked proportional round trip closed at attacker target delta 0. Kimi's printed rule-4 attack rows were negative. Astra stated a componentwise ownership invariant at the acceptance cutoff. That invariant does not use a pool price. It refuses full credit for an unmatched token. It is not a claim that later AMM trading cannot move value.

TWAP. Source check: the implemented write and read paths credit idle time with the truncated live tick. Grok's rechecked as-written backfill row closed at `+1970597147462162`. The idealized in-transaction reference on that ledger closed at `-573794679209779`. The same push after the window closed at the backfill profit. A frozen pre-trade reference can remove an executed-price gain. This oracle is not that frozen reference. `1.0001^9116` printed as `2.488187224469637`. That cap is a per-write rate limit, not an outside price.

### What this does not say

It does not say every same-pool accounting rule is unsafe. It does not say a proportional mint is the chosen product. It does not authorize production edits, tests, deployment, or a change to `getRate`. It does not rerun the audit PoC and does not claim a Wings three-slot lifecycle. Standalone arithmetic is not Forge execution.

The direct answer to the swap question is narrower. Executing the deposit swap and the exit swap does not eliminate the finding for the quote rule or for the executed-price rule in the rechecked domains. It eliminates the quote-to-share conversion only in the price-free vector rule, and that rule is not "the swap captured the manipulation."

## Preserved disagreements

| Topic | Positions | Not resolved in this draft |
| --- | --- | --- |
| Executed-price sign when the vault is the LP | MiniMax's function is negative at vault liquidity shares 1/4, 1/2, 3/4, and 1, and positive on an idle-opposing book when the whole deposit is swapped. The coordinator interval ledger is positive when the vault owns the active interval and fills both swaps. Grok's `self_fill_note` is positive but has 2 wei of pool dust on each token, so it is not an exact zero-conservation row. | These are different machines. No row is discarded because another row has the opposite sign. |
| Whether a 50% swap is safe | MiniMax's idle book is negative at a half swap (`-0.358973`) and positive when the whole deposit is swapped. Kimi's first-order boundary is `alpha < omega`, so 51% fails on an 80%-opposing book. The coordinator 49/50/51 rows at full ownership and a 200 deposit are all positive. | A fixed 49/50/51 split is not a threshold. |
| Whether the proportional exit sale preserves the invariant | Kimi says a sale of only the exiter's slice does not change other holders' per-component claims. Grok's terminal summary said the conserving vector case does not sell. The coordinator sale control lost the round-trip fee and did not extract. | Ownership conservation at acceptance is not the same claim as immunity to later trading. |
| Whether rule 4 eliminates the finding | Kimi says yes, inside the stated componentwise domain. Astra's invariant is ownership allocation, not a ban on adverse trading. | The draft adopts the narrower claim: the vector rule removes the pool-price conversion. It does not adopt "eliminates every loss." |

## Evidence gaps

- The audit PoC was not rerun. Reported Foundry profits stay reported.
- No model here is a core-plus-both-wings PoolManager sequence. Harvest, hooks, and dynamic fees are unmodeled.
- Grok's self-fill row has 2 wei of dust. It is not used as an exact witness.
- MiniMax's response table profits of `+25.472084e18` and `+30.508645e18` were not the numbers `main()` printed for its depth-100 control. Those table rows were not re-executed.
- Kimi's task had written the response before Native settlement. The recheck used the file that was present. A later edit after this draft's hash would be a gap, not a silent update of this draft.
- Flash-loan availability for a sole-venue opposing token is not established. Rows that repay opposing in kind through this pool do not need that assumption. Rows that repay a lender outside this pool do.
- Live source can move. Locator checks are of the tree read this session.

## Coverage adopted from responses

| Target | Status | Adopted from | Conflict or gap |
| --- | --- | --- | --- |
| Money._deposit and Accounting.issue | examined by coordinator | lines 120-133 and 18-22, re-read this session | Members cite the same mint. No conflict. |
| Money._redeem and _swapDeficit | examined by members; coordinator read _redeem and _fund | Astra, Kimi, Grok | The whole-balance sale is the production exit, not the proposed slice. |
| LiquidationQuote | examined by members | Astra table, Kimi trace | Coordinator did not re-read every quote line this session. |
| APEX-2026-012 | examined as text | audit lines 268 onward, read this session | PoC not rerun. |
| TWAP write and observe | examined by coordinator | `UniswapV4TruncatedTwapOracleLib.sol` write at the recorded-tick credit; observe transform | Members agree on the backfill. APEX-050 was not rerun. |
| Executed-price and proportional ledgers | re-executed | coordinator ledger, Astra equations, MiniMax model, Grok run(), Kimi main() | Sign disagreement on vault-as-LP is preserved, not averaged. |
| Wings PRD | not used as proof | Grok did not read it; others may have | Optional. Not a veto and not a source for this verdict. |

## Limits

- Static, extracted, supplied-runtime, and unverified claims stay distinguished. The closed rows are standalone arithmetic. They are not Forge traces.
- This draft does not claim permission confinement.
- Original response files were read and are preserved.
- No project code, configuration, or Git action is authorized by this draft.
