# Coordinator draft

## Draft identity

- Draft ID: draft-v4-same-pool-swap-evidence-20261026-01a171a0-r1
- Path: docs/research/v4-same-pool-swap-evidence-20261026-01a171a0/coordinator/draft.md
- Run ID: v4-same-pool-swap-evidence-20261026-01a171a0
- Status: pending advisory review. This file is not the final.
- Fingerprint: not embedded. The sha256 of these bytes, once frozen, is the review identity recorded in RUN.md and in the advisory assignment.
- Sources: coordinator receipts of the three substantive initials; coordinator re-execution in research/recheck.json; coordinator model research/model.py and research/results.json; source lines re-read this session as named below. Astra produced no original.

## Participation

- Council kind: full
- Requested members: astra, grok, minimax, kimi
- Substantive initial responses: grok, minimax, kimi
- Missing initial responses: astra. Provider content-policy failure on st_01a1773c. No substitution and no retry. Absence is not agreement.
- Result label: partial full council
- Coordinator mode: invoking-agent
- Coordinator is an independent vote: no

## Question

Can an actual entry swap and an actual proportional-slice exit swap make same-pool pricing safe against malicious ownership dilution or reserve extraction, when the only venue and reference is the underlying pool and its TWAP? If so, under which exact mint and execution rules? If not, exhibit a fully accounted profitable round trip or a precise limit. Do not require an independent feed. Do not treat execution itself as proof that the share cut is fair.

## Proposed text

Executed swaps do not, as a general fact, capture manipulated-price changes. They capture the price of the quantity that actually traded. A mint rule that then applies that execution price, or a live whole-book liquidation quote from the same pool, to inventory that did not trade is a different rule. That second step is where the checked witnesses extract value. No received response found a same-pool-only rule that is at once single-sided, same-transaction, fully credited for retained overage, and proved manipulation-free. That is a limit of the searched rules, not a claim that no such rule exists.

### What was rechecked

Coordinator re-execution is recorded in [research/recheck.json](../research/recheck.json). It is standalone arithmetic. It is not an EVM test, not a Wings reproduction, and not a rerun of the audit's Foundry PoCs.

- Grok's filed Domain L snippet matches the exact fraction `320226133435299/10170234955199` (about 31.4866 target). Opposing, shares, and debt end at zero in that snippet. The lender repays in kind and is assumed not to sell that repayment through this pool. The identity is rechecked. The existence of that lender for a sole-venue token is not.
- MiniMax's idle-inventory witness rechecks at `5162744.89786187` target for the 49% entry, opposing end `0`, with the no-manipulation control about `-143477.29` and the manipulation-without-deposit control about `-452033.47`. The 50%, 51%, and 1% entries on that same book recheck positive and closed: about `5053409.39`, `4943655.36`, and `10143708.38`. Post-swap denominator variants on the headline book stay positive. The vault in this model is idle inventory outside the pool. The loan is repaid by buying opposing through the same pool. It is not Grok's off-pool buffer, and it is not a core-plus-wings execution. MiniMax already marked default spacing 60 as likely to activate a wing on that path.
- Kimi's baseline live-quote mint plus entitlement exit rechecks closed at fee 0: attacker target delta about `+18055.89`, opposing delta about `0`, incumbent per-share quote about `0.208020` to `0.189964`. That is a toy of the current mint rule, not a rerun of APEX-012.
- Kimi's literal-rule default row rechecks as a convention loss, not a closed target profit: target delta about `+1127.47`, opposing delta about `-1955.08`, convention about `-827.61`. The row Kimi reported as `+9627.8` rechecks as target delta about `-9833.90`, opposing delta about `+19461.68`, convention about `+9627.78`. That convention marks residual opposing at the restored marginal price. It is not adopted as closed target profit. Closing that opposing through the sole pool would move the price. Kimi's own limits section already says convention value is an upper bound and is not realized target profit. The verdict line that calls this figure target profit is not adopted.
- Kimi's price-free proportional attack rechecks at about `+115.12` convention with about `+636.86` residual opposing at fee 0, and about `-470.48` convention at a 0.1% fee. The 0 ppm per-share claim for a pure proportional deposit was not separately re-executed; the invariant as written does not use a price.
- The coordinator single-interval model was re-executed. At a 0.3% fee, a 200 target deposit, and a 50% entry swap, executed-average actual-composition net target is negative at vault fractions 1% and 10% (`-0.593...` and `-0.369...`) and positive from 50% through 100% (`1.864...`, `3.903...`, `4.274...`, `4.313684168578358357`). Final opposing and both conservation errors are 0. This case has no prior dump and no later restore. It is an immediate deposit, entry swap, mint, slice withdrawal, and slice sale. Post-swap spot on the same 100% case is about `+13.806`. An ideal fixed price of 1 is about `-1.139`. Proportional refund is about `-0.450`. Those negatives are fee and impact drag in a no-manipulation round trip. They are not evidence that a price-1 reference survives a prior manipulation, because that model never moved the pool before the deposit.

Numbers not re-executed stay member-reported: Grok's Domain N excess of about `-2.4e-4`, Grok's other grid rows, Kimi's W4/W5 and TWAP-replica ticks, and Kimi's full grids beyond the rows above. APEX-012 and APEX-050 Foundry outputs were not rerun.

### Current issuance is a different and weaker rule

Source re-read this session, not adopted from a member's line number alone:

- `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol` `_deposit` at lines 120-140 pulls target, harvests, reads `Quote.quote`, and calls `Accounting.issue`. There is no entry swap.
- `_redeem` at lines 156-163 harvests, reads the same live quote, and pays `Accounting.entitlement`.
- `Accounting.issue` at lines 18-22 mints `supply * credit / value` after the zero-supply case.
- `UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.sol` `getRate` at lines 29-32 returns the whole-book liquidation quote times `1e18` divided by supply. Grok's short citation `EconomicTarget.sol:29-32` matches those lines. MiniMax's `:27-41` is the surrounding block; the return is line 32.

That is live whole-book quote issuance. Kimi's closed toy and the reported APEX-012 PoC, which was not rerun, are evidence against this rule. Changing only the exit to a slice sale does not close a mint that already happened. Kimi reported that split; the slice-exit variant of W2 was not re-executed.

### Literal executed-price mint

The literal rule is `m = S * D / (A_T + p_exec * A_O)` with `p_exec = targetSpent / opposingReceived` on the pre-swap book. The received basket credits to `D` at `p_exec` by algebra. That identity prices the swap. It does not price the unswapped book.

Checked closed counterexamples:

- Domain L, Grok: positive exact target profit if a same-asset opposing loan can be repaid in kind without that lender selling through this pool. A 49% entry does not close the opposing-heavy case in Grok's unrechecked grid. The coordinator does not adopt those unrechecked grid magnitudes.
- Idle opposing-heavy book, MiniMax: positive closed target profit with the repayment bought through the same pool, including at 49%, 50%, and 51% entries, and a larger profit at a 1% entry. This rejects the further claim that "the attacker must trade the manipulation inventory through this pool, so the two sides cancel" as a universal rescue. It does not establish the same profit inside active Wings ranges.
- Immediate self-fill, coordinator model: positive closed target profit for executed-average marking once the vault owns half or more of the active interval, with no separate attacker dump. The vault filling the swap changes composition. It does not bind the later slice-exit value to `p_exec`.

Grok did not find a closed issuance profit in the tested Domain N unwind on a balanced deep pool. That result is member-reported and unrechecked. It can stand beside MiniMax's closed idle-book profit because the books are not the same. Neither result restores a universal safety claim.

Fixed 49/50/51 sizing is not a safety threshold in the rechecked MiniMax book or in the coordinator 100%-ownership immediate round trip, where 49%, 50%, and 51% of a 200 target deposit are all positive. Smaller coordinator deposits of 2 and 20 target were slightly negative at those splits. Sign depends on size and ownership, not on landing inside a 2-point band.

### Proportional vector, and what it gives up

The rule that had a no-price invariant in the responses that tested it is scalar ownership of the position vector. After harvest, and before the caller's tokens are mixed in, accept only `lambda` times the current vector of core, each wing, each idle balance, and fee checkpoints. Refund the rest in kind. Mint `lambda * S`, rounding down. Exit pays that fraction of each component in kind, and if opposing is sold, sells only that exiter's slice and pays the actual proceeds.

Grok reported exact 0 target and 0 opposing in the Domain L setup. That row was not in the rechecked snippet. Kimi's executable proportional attack was rechecked and was not a closed target extraction; the fee-0 remainder was residual opposing. The coordinator proportional control was negative under a 0.3% fee, which is the depositor paying fees and impact, not an extraction from incumbents. Kimi reported that a vault-executed zap on the mint path breaks the exact claim-neutrality, because the vault's own liquidity is repriced mid-mint. That implementation defect was not re-executed. The design constraint is adopted as a member finding: the clean invariant, as stated, requires the vault not to swap on the mint path. The user zap, or a dual-asset deposit, sits outside the vault's share cut.

What this rule gives up is full credit for retained overage and a clean single-sided target deposit. A 49% swap of the deposit is a fraction of the deposit, not a scalar of the book. Leftovers marked at `p_exec` are the literal numerator problem again. Refund them, or the invariant is gone. An internal `sqrt(A_T * A_O)` share price is not a substitute for heterogeneous core and wing ranges. All three substantive responses said liquidity units in disjoint ranges are not one price-free aggregate. That agreement is not a proof, and Astra did not speak.

This is a research conclusion. It is not implementation authority.

### Same-pool TWAP

Source re-read this session: `UniswapV4TruncatedTwapOracleLib.write` sets `recordedTick = truncate(tick_, prevTick)` and credits `recordedTick * delta` across the elapsed gap, then stores that recorded tick as `prevTick`. `UniswapV4MultiPoolTwapOracleTarget.update(PoolKey)` at lines 32-45 is public, reads live `slot0`, and has no `isUnlocked` check in that function. A write resets `lastTimestamp`. Adapter `maxWriteAge` then sees a fresh write. This matches the mechanism APEX-050 reports. The PoC was not rerun. Its lender is hypothetical test code, not the Wings vault.

A corrected anchor, crediting the elapsed gap with the tick that held before the write and refusing a write while the manager is unlocked, stops the retroactive backfill. It does not reconstruct prices between pokes. The poked tick can still anchor the next interval until an honest write. On a sole venue there is no external arbitrageur in the evidence. Holding a skewed spot costs a round trip of fees and impact, capital lockup, and whatever organic flow exists. It does not cost a fee every block merely because a blog prices manipulation that way on a deep two-venue pair. A TWAP can be a delay, a deviation band, or a per-operation cap in front of a consumer. Using it to revalue the book reopens the literal-rule exposure once the anchor has moved. A band that halts deposits is also a denial-of-service lever. If a band is used, the responses that addressed it said it should fail open to the proportional rule, not freeze the vault. That is a recommendation, not a built control.

The coordinator model's negative result for a fixed price of 1 is not this corrected TWAP. That price was the initial price, and the case had no prior manipulation.

### getRate

Current code is the whole-book liquidation quote times `1e18` over supply. That is not a one-share sale. Kimi's section 6 calls the current return a one-whole-share withdrawal-and-sale preview. That conflation is not adopted. MiniMax separated the current source from the requested meaning. Grok did the same.

The requested meaning stays what it was: a normalized preview of withdrawing one whole share, selling that share's opposing slice, and reporting target proceeds plus the target slice, per share. A preview of size `q` uses `q`'s own curve impact. A view does not trade. This draft does not authorize implementing that distinction. Issuance accounting stays separate from that preview. A lender, a DETF scale, or a hook that treats either number as collateral is a different victim from the vault's shareholders. A same-pool quote is not independent collateral. That is a limit of the venue.

### What is not claimed

- No production Wings profit figure. No Foundry sequence was run.
- No claim that every parameter of the literal rule is profitable. Several rechecked rows are negative.
- No claim that Domain L's lender exists.
- No claim that MiniMax's idle-book profit survives default-spacing wings.
- No claim that Kimi's `+9627.8` is closed target profit.
- No claim that a corrected TWAP is an independent price.
- No implementation, test, or configuration authority.

## Preserved disagreements

| Topic | Positions | Not resolved in this draft |
| --- | --- | --- |
| Closed literal-rule profit when the manipulation inventory must be bought back through this pool | Grok: not found on the tested balanced deep Domain N unwind, excess about `-2.4e-4`, unrechecked. MiniMax: closed profit about `5.16e6` target on an idle opposing-heavy book, rechecked, vault not in the pool. Kimi: highlighted literal-rule "profit" on an LP book is convention-valued residual opposing, rechecked as not closed. | The books and execution assumptions differ. No one result cancels the others. The universal safety claim is still rejected by the closed witnesses that do exist. |
| Whether a 49/50/51 entry is "good enough" | Kimi: often much smaller than the baseline, still profitable in some O-heavy rows, and those rows are not all closed target. Grok: below the book's opposing value weight the small-move zero-fee Domain L sign is positive; 49% is on that side of a balanced book in the limit and was slightly negative on one finite balanced row, unrechecked. MiniMax: 49/50/51 all largely positive on the idle headline book, rechecked. Coordinator immediate model: positive at large size and high vault ownership, negative for tiny deposits. | Not resolved into a safe band. Fixed sizing is not adopted as a proof. |
| getRate's current meaning | Kimi describes the current return as the requested one-share preview. Source at lines 29-32 is the whole-book quote over supply. Grok and MiniMax separate the two. | Current source observation is adopted. The requested preview meaning is retained as a constraint and is not a code change. |
| Ideal or corrected same-pool reference as a mint price | Coordinator no-manipulation immediate round trip loses at a fixed price of 1. All three substantive responses say a same-pool TWAP, even correctly anchored, can be held until it reports the skewed spot, and then the literal revaluation returns. | The negative price-1 row is not evidence that a TWAP mint is safe. |

## Evidence gaps

- Astra's initial response is missing. No later feedback can replace it.
- Grok Domain N, Grok's fee grid, Kimi W4/W5, and Kimi's TWAP replica were not re-executed. The filed Kimi model stops before those drivers.
- No member ran a Foundry sequence against PoolManager, wings, harvest placement, or the audit PoCs. This draft does not.
- Flash-loan availability for a sole-venue opposing token is unverified.
- Default-spacing wing activation on MiniMax's tick path is a disclosed reachability gap, not a measured Wings profit or loss.
- Public Uniswap oracle pages were fetched by some members and not re-fetched by the coordinator this session. They are not used as proof that a thin sole-venue token has external arbitrage cost.
- Live source can move. The line checks above are of the tree opened this session, not an atomic snapshot.

## Coverage adopted from responses

| Target | Status | Adopted from | Conflict or gap |
| --- | --- | --- | --- |
| Money deposit and redeem | examined | source re-read, lines 120-140 and 156-163 | No entry swap. Quote then issue or entitlement. Member line ranges that cover this block are accepted. |
| Accounting.issue | examined | source re-read, lines 18-22 | `supply * credit / value` after harvest. |
| getRate | examined | source re-read, lines 29-32 | Whole-book quote over supply. Kimi's identification of this with the one-share preview is not adopted. |
| TWAP write and update | examined | source re-read | Elapsed gap credited with the truncated live tick; `prevTick` becomes that tick; `update` is public and has no `isUnlocked` check in the function. |
| APEX-012 and APEX-050 | partially examined | member readings of the diff review; not rerun | Reported PoC outputs stay reported. The hypothetical lender is not Wings. |
| Literal executed-price rule | examined as a model | Grok snippet, MiniMax model, Kimi default and one O-heavy row, coordinator immediate model | Closed profits exist in some domains. Not universal. Not a Wings PoC. |
| Proportional vector refund | examined as a model | three responses plus coordinator control | No-price invariant as stated. Exact zero was member-reported in Grok's Domain L and not rechecked. Coordinator control is fee-negative, not an extraction. |
| Wings core and both wings in one executed attack | not examined as an execution | all three models omit or only approximate it | Coordinator model has one active interval plus an inactive upper wing. It is not a three-slot attack. |
| CLAUDE.md pricing law | partially examined | Grok reported no pricing law in the matches; file not read end to end by the coordinator this session | No pricing law is invented. |

## Limits

- Static, extracted, supplied-runtime, and unverified claims stay distinguished. Rechecked arithmetic is labeled. Unrechecked member numbers are labeled. Audit PoCs were not rerun.
- This draft does not claim permission confinement.
- Original response receipts were read and are preserved under coordinator/received-originals/. Members did not write members/<label>/response.md because project-scoped apply_patch was absent. The receipts are the originals, not rewrites.
- No project code, configuration, or Git action is authorized by this draft.
- The coordinator's model is evidence about the rules it executes. It is not a fourth vote.
