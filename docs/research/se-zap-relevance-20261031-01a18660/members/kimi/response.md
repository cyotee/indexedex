# Kimi response: Weir zap relevance

## Identity

- Run: `se-zap-relevance-20261031-01a18660`
- Member: Kimi
- Requested Native selection: `kimi-coding/k3.1-pro:high`, global route
- Actual Native identity: not exposed

## Question and targets

1. Does the Weir design being imported configure `maxZapBps` and `maxZapTickMove`, and what zap controls does it actually have?
2. Are those caps useful in the adopted single-position, full-spread Standard Exchange vault with single-token `exchangeIn`, beyond Weir's existing swap controls?
3. What does `previewZapCredit`'s per-currency split reveal that `previewExchangeIn` does not, and does that value remain when unused input is refunded rather than booked?

The targets are the admitted Weir import requirements and source functions, the full-spread package arguments and ownership decisions, the prior zap-ROI report, and the PairToken zap-cap paragraphs solely as the origin of the two cap names.

## Evidence

- I searched `WEIR_VAULT_SOURCE_IMPORT_PRD.md` for both cap names; neither occurs. Its `DepositParams` row contains `amount0`, `amount1`, `zap`, `minShares`, `recipient`, `deadline`, and `hookData`, not either cap. `WithdrawParams` similarly contains `zapTo`, `min0`, and `min1`, not either cap.
- I independently read `WeirVaults.sol`'s `deposit`, `_deposit`, `_balance`, `_swap`, `withdraw`, and `_withdraw` implementations. A deposit's `zap` flag invokes `_balance`, which derives at most one exact-input balancing swap from the declared amounts and current pool price. `_swap` sets `amountSpecified` to negative `amountIn` and uses only `MIN_SQRT_PRICE + 1` or `MAX_SQRT_PRICE - 1` as the directional price limit. There is no reserve-relative size check or entry tick-delta check.
- Deposit has a `minShares` check and deadline. Withdrawal has `zapTo` values 0/1/2, two output minima, and a deadline. These are caller output/mode controls, not configured zap-size or tick-move limits.
- The outer `deposit` sends `amount0 - used0` and `amount1 - used1` back to `msg.sender`; positive manager credits also go to the depositor. Thus Weir refunds unused input instead of booking it as a residual claim. WI-12, WI-15, and WI-20 agree with that source behavior and permit partial fills without guaranteeing full consumption.
- The full-spread PRD's `FS-PKG-01` separately lists `uint16 maxZapBps` and `int24 maxZapTickMove` in `PkgArgs` because it defines `PkgArgs` as the PairToken set. That is a full-spread package choice, not evidence of Weir configuration.
- The admitted PairToken paragraphs define `maxZapBps` as a pre-entry-reserve-relative input bound and `maxZapTickMove` as a bound on `abs(tickAfter - tickBefore)` around the entry swap. They also give the size cap a separate compound use; that coupling is not needed to answer the entry-cap question and is not Weir behavior.
- The prior zap-ROI report distinguishes `previewZapCredit`'s per-currency credited/uncredited outputs from `previewExchangeIn`'s shares and same-token refund. It does not establish a locked booked-residual policy.

## Assumptions

- The adopted entry path retains a same-pool balancing swap for single-token `exchangeIn` and follows Weir's policy of refunding unused input.
- For question 2, `maxZapBps` means an entry-size cap measured against the specified pre-entry input reserve, and `maxZapTickMove` applies only to the entry swap. No numeric setting, compound coupling, or manipulation-resistance guarantee is assumed.
- For question 3, the preview semantics are those described in the admitted ROI report. A future refund-aware preview could instead report expected per-currency execution/use, but that would be an explicit semantic choice rather than a booked-residual quote.
- No booked-residual policy is assumed for this product family.

## Coverage

| Question | Evidence applied | Coverage |
| --- | --- | --- |
| Weir configuration and controls | Import PRD parameter rows and WI-12 through WI-20; admitted Weir source functions | Direct source verification and a separate cap-name search |
| Cap relevance | PairToken cap semantics contrasted with Weir's exact-input/global-price-limit swaps and the full-spread single-token entry | Entry size and entry tick movement only; no invented values |
| Preview usefulness | Prior ROI report contrasted with Weir's actual refund behavior | Both execution-breakdown and booked-residual interpretations considered |

I did not read peer responses and did not reopen the locked `previewWithdrawalMode` or `wrappedNative()` decisions.

## Conclusions

### 1. Weir does not configure these two caps

No. Neither `maxZapBps` nor `maxZapTickMove` is present in the Weir import PRD or the admitted Weir zap implementation. The full-spread `PkgArgs` occurrence must not be attributed to Weir.

Weir instead provides a deposit `zap` toggle with an internally sized, at-most-one balancing swap; `minShares` and `deadline`; withdrawal `zapTo` direction selection with `min0`, `min1`, and `deadline`; exact-input swap requests; and the two global Uniswap price limits. Partial fills are settled from actual returned deltas. None of those is a reserve-relative size cap or a post-swap tick-movement cap.

### 2. Both caps are relevant as additional product-layer entry controls

Yes, if the adopted product wants explicit bounds on its single-token entry swap. They do work that Weir's controls do not:

- A size-bps cap limits the entry swap relative to the pre-entry pool reserve, bounding how large a same-pool price-moving trade one entry may attempt.
- An entry tick-move cap limits the realized tick change around that swap. Weir's global `MIN_SQRT_PRICE + 1`/`MAX_SQRT_PRICE - 1` limits permit partial fills near pool-wide extremes; they do not provide a local entry movement bound.
- `minShares` protects the caller's share output, but it is not interchangeable with either a swap-size bound or a tick-move bound.

These are new full-spread policy controls, not requirements for Weir source fidelity. Their reserve basis, timing, rounding, and revert semantics must be explicit, and the tick cap must not be presented as a general slippage or manipulation-proofing guarantee. I would retain them only with those product semantics; I would not import PairToken's compound quarter-cap coupling or invent a configured number.

### 3. The split has a narrower refund-aware use, not a booked-residual use

The unique information is the expected per-currency funding/credit and uncredited split. `previewExchangeIn` can tell a caller expected shares and a same-token refund, but it cannot show how a one-sided entry was funded across currency0 and currency1. An execution-oriented split can therefore support a UI breakdown, integration reconciliation, and diagnosis of which currency consumed or received value before submission.

Weir-style refunds remove the distinct value of tracking an uncredited per-currency residual as an asset or future claim: unused input comes back to the payer instead of remaining booked. Consequently, `previewZapCredit` must not be justified as a residual-accounting tool under the adopted refund policy. Its per-currency breakdown survives only as informational execution/use data with explicitly refund-aware semantics. If the proposed fields merely expose booked credited/uncredited residuals, that use does not survive and the family has not locked the policy that would make it meaningful. Whether the narrower informational breakdown warrants a separate public preview remains an interface-value decision; it is not already supplied by `previewExchangeIn`.

## Limits

This was a read-only consultation of the admitted materials. I did not implement anything, run tests, edit the PRD or review file, or inspect peers. This response recommends no numeric cap values, does not lock a preview or residual policy, and grants no implementation authority.
