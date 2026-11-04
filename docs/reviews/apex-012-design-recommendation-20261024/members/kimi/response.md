# Member response

## Identity

- Run ID: apex-012-design-recommendation-20261024
- Member label: kimi
- Profile: research
- Phase: initial independent response
- Owned path: docs/reviews/apex-012-design-recommendation-20261024/members/kimi/response.md
- Requested role: council-member
- Requested model and reasoning: kimi-coding/k3:high
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

Question: recommend one vault design whose reserve is exposed to trading and earns swap fees, whose holder can be priced and paid in one target token, where deposit, redeem, and the rate use one rule, and name what the design refuses to do.

Targets addressed:

1. Reserve earns swap fees from real trading volume.
2. A view returns one `uint256`, 18 decimals, in target-token terms, suitable for a rate provider.
3. One rule governs deposit, redeem, and the rate. No live same-pool liquidation quote, no slot0, no rate/zap split, no single-sided-target-only reserve, no sale executed or previewed by `getRate`.
4. Any conversion is justified from the goals, not asserted.
5. One mechanism for V3 and V4 unless a protocol difference forces a split.

## Evidence

Admitted sources only: the brief, `docs/reviews/apex-012-deposit-process-20261024/REMEDIATION_PRD.md`, `docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md`, `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol`, `.omo/ulw-research/20261023-171500/SYNTHESIS.md`.

- The defect being reconsidered is live in `Money.sol`: `_deposit` prices the mint from `Quote.quote(Common.quoteRequest()).value`; `_redeem` sizes the entitlement from the same quote, funds it through `_fund`/`_swapDeficit`, and guards remainder value with a pre/post quote comparison (`HolderValueLoss`). `_swapDeficit` sells the vault's other-token inventory at `MIN`/`MAX` price limits sized to a quoted deficit. This is the rejected whole-book quote on the money path.
- The remediation council established as agreed fact: the existing deposit does not sell target; harvest never swaps; `_swapDeficit` sells other token for target and only a redeem reaches it. The gift problem (a target-only mint handing the new holder a slice of pre-existing other token) and the open-new-range problem were raised; three owner options were recorded and no member selected one.
- The old PRD's accounting core is sound and survives reconsideration: settled-target counter, `getRate = settledTarget * 1e18 / supply`, counter moves only when target actually moves in a vault operation, exit pays only the burned slice's actual proceeds, remaining holders take the other side of the exit sale by design. What the old PRD left weak, and the remediation council exposed, is the entry side of a two-sided book: it asserted an entry swap the current code does not have, without deriving why the goals force it.
- The synthesis confirms the external landscape: no inspected production Uniswap vault exposes a view one-token rate that ignores same-pool spot; Visor (2021) and Gamma (2024) are the spot-quote exploit class; the only spot-free rate shape found is stored single-token accounting (Panoptic `convertToAssets` reading stored counters), which is the shape this recommendation uses.
- Arithmetic behind the entry rule below: with supply `S`, settled target `T`, vault-owned other token `O`, a deposit retaining `R` target after converting part of the deposit mints `s = R * S / T`; the new holder's claim on pre-existing `O` is `s * O / (S + s)`; funding that claim requires the entry conversion to deliver `B >= s * O / S` other token. This identity uses only actuals measured after a real execution. No quote, no slot0, no simulated sale is needed to check it.

## Assumptions

- "One rule" means one accounting identity — settled target per share — governs what a mint costs, what a burn debits, and what the rate reads. It does not mean a redemption numerically equals `shares * rate`; the exit pays actual settled proceeds and the counter records them. A previewed exit number different from the rate would be the rejected split; an executed exit whose actuals update the same counter is the rule itself.
- "One target token" is the vault's single numéraire: the only token accepted at entry, the only token paid at exit, the unit of the rate.
- A real conversion inside the acting holder's own entry or exit call is permitted by the brief when the recommendation names why the goals require it; this response names that reason in the Deposit section.
- The rate provider needs a cheap view: one stored counter divided by supply, 1e18-scaled.
- Rebalance, deployed-vault containment, harvest internals beyond the credit rule, and APEX-2026-024/025/026/040 closures are out of scope for this recommendation.

## Coverage

| Brief constraint | Where answered |
| --- | --- |
| Reserve exposed to trading, earns swap fees | The Position: pro-rata slices of the existing core and wing ranges stay deployed; fees accrue to the position |
| Priced and paid in one target token | The Rate and The Exit: counter-denominated rate, target-only payout |
| Deposit, redeem, rate use one rule | The One Rule statement; deposit mints, redeem debits, and the rate reads the same settled-target counter |
| No live same-pool liquidation quote as share price | Refused behavior 1; rate is a ledger ratio |
| No rate/zap-out split | The Exit pays actuals of the holder's own slice and writes them to the same counter; there is one number, not two |
| Single-sided target range is not a fee reserve | The Position keeps the existing two-sided-capable ranges; single-sidedness is a market state, not the design |
| No claim that the current deposit sells target | The Deposit is a new process; the recommendation names why the goals require its conversion |
| `getRate` executes/previews no sale | The Rate reads storage only; the absent value is named |
| Name the value absent from the rate until a real conversion settles | The Rate: all unsettled vault-held other-token value is absent |
| Same mechanism V3 and V4 unless a difference forces a split | Protocol split: one mechanism, one named settlement-timing caveat, no split |

## Conclusions

**The one rule.** A share is a claim on a settled-target ledger: shares are created only against target that actually settles into the vault's accounted balance, shares are destroyed only against target that actually settles out, and the rate is that same accounted target divided by supply. Deposit, redeem, harvest credit, and `getRate` are four reads or writes of one counter. Nothing else — no spot price, no quote, no donation, no outsider's swap — mints a share or moves the rate.

**The position.** The reserve is the vault's liquidity in the existing ranges (core and both wings) plus booked idle balances. It is exposed to trading by construction and earns the pool's swap fees while price crosses its ranges. A deposit adds liquidity pro-rata across positions that already exist; it never opens a new range; target that cannot be placed proportionally stays idle and remains part of the accounted book. Booked accounting, not `balanceOf`: a direct transfer is not inventory and moves nothing.

**The deposit.** Target only. If the position holds no vault-owned other token, shares mint as `assets * S / T` (or `assets` when supply is zero) against the pre-deposit counter, and placement proceeds pro-rata. If the position holds other token, the one rule forbids a free slice of it: the mint price is `T / S` but the share's content includes pre-existing other token, so a swap-free mint would price the deposit below its content and break the rule. This — and only this — is why the goals require an entry conversion: it is the only way a target-only deposit can buy a homogeneous share of a two-sided book without quoting that book. The depositor declares how much of the deposit to convert; the vault executes that exact-input sale in the depositor's own transaction at the pool's real price, then mints `s = retainedTarget * S / T` and reverts unless the conversion's actual delivered other token `B` satisfies `B * S >= s * O` against pre-deposit `O`. The sizing is the caller's parameter, the check is post-execution actuals; neither uses `Quote.quote`, a simulated sale, or slot0. If the caller declines to convert on a two-sided book, the deposit reverts — that is the fallback (owner option 2), and it is worse, because it refuses entry exactly when the reserve is earning fees.

**The exit.** Redeeming `s` of `S` shares burns exactly `s / S` of every position, receives the slice's actual target and other token at the current tick, sells only that slice's other token through the same pool at the real execution price — the remaining position filling part of it is intended, the same trade any swapper imposes — and pays the exiting holder the target actually received, bounded below by the holder's own minimum-out; failure reverts with nothing burned. The paid amount is debited from the settled counter. A terminal exit closes the whole book; a partial exit never sells more than the exiting slice. There is no entitlement computed from a quote, no `MIN`/`MAX` deficit sale, no pre/post quoted-value guard.

**The rate.** `getRate = settledTarget * 1e18 / supply`, and `1e18` when supply is zero: one view, one `uint256`, 18 decimals, no pool reads. The counter is written at the end of deposit, redeem, and a harvest credit of target actually collected. Absent from the rate until a real conversion settles: the entire target value of vault-held other token. The rate therefore understates a two-sided book by exactly its unsettled other-token inventory, and checkpoints the target side only at vault operations. That lag is the protection — a same-transaction swap, temporary liquidity, a donation, or an in-transaction price move cannot mint shares or move the rate.

**The refused behavior.** The design refuses to: (1) read any live same-pool state on the money path — no quote, no slot0, no simulated sale; the rate is a ledger, not a price; (2) pay a redemption the book did not settle — no whole-book liquidation payout, no quoted entitlement, no quoted-value remainder guard; (3) gift — no mint that hands a new holder pre-existing other token, and no new range opened for an empty slot; (4) convert outside the acting holder's own call — no harvest or keeper sale of the position's other token; (5) carry a second price — no oracle, no cached external mark, no rate/zap split; (6) guarantee a remaining holder's target balance across someone else's exit.

**The cost.** Depositing into a two-sided book costs a real swap's fee and impact, and the depositor bears sizing risk: a bad conversion parameter reverts. The rate is not a NAV — it lags, it is conservative only by omission of the other-token side, and exit proceeds will differ from `shares * rate` in both directions. Remaining holders absorb the other side of every exit: their counter falls and their other-token inventory rises by the fill. Entry and exit swaps are real orders with caller min-out as the only MEV defense. One named edge: if the counter reaches zero with positive supply, the rate is zero and deposits revert until a fee harvest or exit settlement restores a positive counter — the design prefers a halted deposit to a fabricated denominator.

**Protocol split.** None. The mechanism — counter, pro-rata placement, slice exit, checkpoint writes — is identical for a V3 pool and a V4 pool. The one named protocol difference is settlement timing, not a split: V4 token movements inside an unlocked PoolManager are transient until the lock settles, so the counter write must land after settlement (where the current code already re-verifies booked balances), while V3 settles synchronously inside the call.

**Rejected alternatives, one sentence each.**

- Quote-priced Wings as deployed: a live whole-book liquidation quote counts temporary liquidity and in-transaction moves, which is the defect under reconsideration.
- Two-token pro-rata redemption (Charm/Arrakis shape): it prices honestly but fails the goal of paying out in one target token.
- Oracle or cached external mark (Maker GUniLP precedent): it buys a spot-free rate with an external trust dependency that the settled ledger does not need.
- Single-sided target range as the reserve: it earns nothing while price is outside the range and then holds the other token, so it is not a fee-earning reserve.
- Swap-free mint on a two-sided book (remediation owner option 1): pricing a deposit at `T / S` while the share contains more than `T / S` breaks the one rule at entry.
- Revert-when-two-sided deposits (remediation owner option 2): it preserves the rule but refuses entry precisely when the reserve is two-sided and earning fees; kept only as the fallback if the entry conversion is rejected.

## Limits

Static reading of the admitted sources only. No forge run, no implementation, no peer files read. The entry-conversion interface (caller-declared exact-input amount plus post-execution identity check) is a design sketch, not a spec; exact revert ordering, deadline handling, and wing-by-wing placement math are engineering work for a later PRD. The zero-counter deposit halt is named, not engineered. V3 Upper Lower Wings does not exist in this repository, so the V3 side of the recommendation is validated only by the mechanism's protocol-dependence on primitives both pools share: mint/burn of liquidity and real swaps. Deployed-vault exposure remains the containment problem the old PRD already declared out of scope.
