# Member response

## Identity

- Run ID: se-zap-relevance-20261031-01a18660
- Member label: grok
- Profile: research
- Phase: initial independent response
- Owned path: docs/research/se-zap-relevance-20261031-01a18660/members/grok/response.md
- Requested role: council-member, Grok member
- Requested model and reasoning: `xai/grok-4.7:xhigh`
- Actual role, model, reasoning, task ID, and session ID: role not exposed; task ID not exposed; session ID not exposed. The process environment exposes provider `xai`, model `grok-4.7`, and reasoning `xhigh`. That is an environment observation, not a model self-description, and it was not given as an assignment-issued task identity.
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

- Question: Does the vault design being adopted configure `maxZapBps` and `maxZapTickMove`, are those caps relevant to that design, and is `previewZapCredit`'s per-currency split useful to a caller?
- Required targets: Weir import PRD WI-13 through WI-20 and the DepositParams and WithdrawParams rows; `WeirVaults.sol` deposit, withdraw, and zap functions; full-spread PRD `PkgArgs` list, FS-OWN-09, and FS-OWN-10; `docs/research/se-zap-roi-20261031-01a18660/REPORT.md`
- Optional context: PairToken stage-one PRD, zap-cap paragraphs only, as the origin of the two names and not as Weir law. The three questions also require the entry-cap steps, the compound coupling sentence, and the `previewZapCredit` signature next to those names. Those paragraphs were read. The rest of that PRD was not.
- Admitted read scope: the brief's required files, the optional zap-cap paragraphs, and the adjacent stage-one paragraphs named above. No peers. No function-review file. No project-code edits.

The three questions, as the brief states them:

1. Does Weir configure `maxZapBps` and `maxZapTickMove`? Name the Weir controls that do exist for a zap, if any. Separate Weir from the full-spread PRD.
2. Are those two caps relevant to the design being adopted? Say whether a size-bps cap and an entry tick-move cap do work in that product that Weir's own swap limits do not already do. Do not invent a number.
3. What can a caller do with `previewZapCredit`'s per-currency split that `previewExchangeIn` does not already let them do? Say whether that use survives if unused input is refunded, as Weir does, rather than booked. If the split is only useful under a booked-residual policy this family has not locked, say that.

## Evidence

Public query: not used.

The brief's statement that a coordinator search found no `maxZapBps` or `maxZapTickMove` string in the Weir import PRD is coordinator-supplied. It is not a finding of this response. The absence rows below are this member's own searches.

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| No `maxZapBps` or `maxZapTickMove` in the Weir import PRD | `contracts/protocols/strategy/weir/WEIR_VAULT_SOURCE_IMPORT_PRD.md`, exact-string search of the file | source observation | Zero matches for either string. A second search for `maxZap`, `ZapBps`, `ZapTick`, and `tickMove` also returned no matches. The only sqrt-price hit is WI-20. |
| No `maxZapBps` or `maxZapTickMove` in WeirVaults | `contracts/protocols/strategy/weir/WeirVaults.sol`, exact-string search | source observation | Zero matches for either string. The zap path takes no bps argument and no tick-move argument. |
| Deposit and withdraw parameter rows | Same PRD, data-model table | source observation | DepositParams is `key`, `amount0`, `amount1`, `zap:bool`, `minShares`, `recipient`, `deadline`, `hookData`. WithdrawParams is `key`, `shares`, `zapTo:uint8`, `min0`, `min1`, `recipient`, `deadline`, `hookData`. Neither row has a size cap or a tick-move cap. |
| WI-12 refund | Same PRD, WI-12 | source observation | Deposit refunds unused input to `msg.sender`. Manager credits during deposit go to the payer, not the share recipient. |
| WI-15 used input | Same PRD, WI-15 | source observation | Used input is the negative part of the signed net. Positive net is taken to the depositor. The outer refund is declared input minus used input, with checked subtraction. |
| WI-19 zap heuristic | Same PRD, WI-19, and the Deposit balancing section | source observation | Deposit balancing uses at most one swap. The sale input is the nested-floor half-imbalance at the pre-swap spot price. Withdrawal zap 1 sells positive currency1 for currency0; zap 2 sells positive currency0 for currency1; zap 0 does not swap. A zero amount does not swap. The text says this is not TWAP protection. |
| WI-20 swap limits | Same PRD, WI-20 | source observation | Swaps use negative `int256(amountIn)` and `MIN_SQRT_PRICE+1` or `MAX_SQRT_PRICE-1`. Returned deltas determine accounting. No consumption-equality check and no single-token completion guarantee. Both output currencies can remain positive after a withdrawal zap. |
| Deposit zap in source | `WeirVaults.sol` DepositParams `zap` comment; `deposit`; `_deposit`; `_balance`; `_swap` | source observation | `zap` means swap inside the pool so the deposit matches the price ratio. `deposit` pulls both declared amounts, then refunds `amount0 - used0` and `amount1 - used1` to `msg.sender`. Shares below `minShares`, or zero shares, revert `Slippage`. `_deposit` calls `_balance` only when `p.zap` is true. `_swap` sets `sqrtPriceLimitX96` to `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1`. |
| Withdraw zap in source | `WeirVaults.sol` WithdrawParams; `withdraw`; `_withdraw` | source observation | `zapTo` is 0, 1, or 2. `zapTo > 2` reverts `BadZap`. After settlement, `out0 < min0` or `out1 < min1` reverts `Slippage`. Zap 1 swaps the positive currency1 net; zap 2 swaps the positive currency0 net. There is no bps ceiling on that input. |
| Fee bps is not a zap cap | `WeirVaults.sol` `perfFeeBps`, `MAX_PERF_FEE_BPS` | source observation | `perfFeeBps` defaults to 500 and is capped at 1,000. It cuts harvested fees. It is not an entry-size cap and not a tick bound. |
| Adopted product is not a Weir copy | Full-spread PRD, goal and section 1.1 | source observation | The product is one registry-deployed diamond, one pool key, one full-range position, one ERC-20 share supply. The text says this is not WeirVaults and not "add ERC-20 to WeirVaults." It inherits PairToken stage-one economics by ID and specifies deltas. |
| Inherited zap checks are not removed | Full-spread PRD, authority section, named overrides and the inherit sentence | source observation | Named overrides do not delete a size cap or a tick-move cap. FS-X04 narrows S1-OP-02's partial-fill domain. The named S1-OP-05 override is the already-unlocked reject. The inherit sentence keeps S1-ARCH-01 through S1-ARCH-05, S1-OP-01 through S1-OP-05 except those named sentences, and S1-ACC-01 through S1-ACC-07. |
| Full-spread fields are the PairToken set | Full-spread PRD, FS-PKG-01 | source observation | `PkgArgs` is the PairToken set and lists `uint16 maxZapBps` and `int24 maxZapTickMove`. The same section says there is no silent zap default. That sentence does not say Weir has the fields. |
| Init validation | Full-spread PRD, FS-PKG-02 | source observation | Zap limits that are not a positive in-range fee bound and a nonnegative tick bound revert `InvalidZapLimits`. |
| Views left open | Full-spread PRD, FS-OWN-10 | source observation | The owner lock drops `previewWithdrawalMode` and `wrappedNative()`. It says `previewZapCredit`, `maxZapBps`, and `maxZapTickMove` stay open. |
| Single-token entry remains | Full-spread PRD, FS-X04, FS-OWN-08, FS-OWN-09, money and quote facet rows | source observation | `exchangeIn` and `previewExchangeIn` stay. They return `(amountOut, amountRefunded)`. FS-OWN-09 drops the paired deposit and redeem selectors and maps them to bundle routes. It keeps `donate` and `compound`. The quote facet list includes `previewZapCredit`. |
| Booked remainder in the written PRD | Full-spread PRD, FS-X04, disposition row "Entry remainder", FS-MONEY-01, FS-A07 | source observation | Addition remainder `J_i` stays booked to shared backing without extra shares, and previews disclose it. FS-X04 does not change S1-ACC-07 share credit. A full selected swap can still book `J_i` without a second-token payout. FS-MONEY-01 says a successful single-token call does not pay a second token. This text is a PRD delta and an inherit, not an FS-OWN owner lock. |
| Stage-one size and tick checks | PairToken stage-one PRD, S1-ARCH-03 items 4 and 5; S1-OP-02 steps 3 and 6; S1-OP-05 | source observation | `maxZapBps` must be positive and at most 10,000. `maxZapTickMove` must be nonnegative. Entry requires `0 < amountIn <= floor(inputReserve * maxZapBps / 10000)` against pre-entry-swap reserves, then `abs(tickAfter - tickBefore) <= maxZapTickMove` around that entry swap only. The same bps value also caps the compound leftover swap at the baseline active-pool reserve estimate times `maxZapBps / 10000 / 4`. The tick bound does not govern compound. No number is recommended here. The 10,000 figure is the stage-one validation domain, not a selected setting. |
| `previewZapCredit` signature | PairToken stage-one PRD, S1-API-05 | source observation | Returns `(shares, credit0, credit1, uncredited0, uncredited1)`. The text says it exposes final share credit and uncredited residual, uses the same planner, and is not an additional deposit route. |
| Prior ROI record | `docs/research/se-zap-roi-20261031-01a18660/REPORT.md` | source observation | That report leaves all three public functions unsettled. It says `previewExchangeIn` returns shares and a same-token refund and does not return the per-currency split. It says the four fields are residual accounting that report's Grok member treated as not locked. It is a prior coordinator revision, not Weir law, not an owner lock, and not this response's vote. |
| Caps do work Weir's limits do not | Comparison of the rows above | inference | A reserve-fraction size ceiling and an entry tick-delta ceiling are not implemented by Weir's global sqrt-price limit, half-imbalance swap, output minima, or refund. FS-X04's full-consumption revert is also not those two ceilings. |
| Split usefulness depends on booking | Comparison of the preview signature, FS-OWN-08, FS-X04, and WI-12/WI-15 | inference | The decision to refuse a gift to other shareholders exists only if the uncredited pair is booked. Weir returns unused input to the payer instead of booking it. |

## Assumptions

- The design being adopted is the single-position full-spread Standard Exchange vault in the admitted full-spread PRD. It is not a WeirVaults deployment and not a silent copy of Weir's refund rule.
- "Owner-locked" means an FS-OWN decision, or a later owner lock the admitted files record. A PRD delta can state a rule without being an owner lock. FS-OWN-10 is the owner lock that leaves the three names open.
- The stage-one zap paragraphs are the origin of the two names and of the preview signature. They are not Weir requirements.
- No missing required target is being treated as examined. Unread bodies are listed under Limits.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| Weir import PRD, WI-13 through WI-20 | Required | examined | WI-13 through WI-20 were read, plus WI-12 and WI-15 because refund and used-input attribution are part of the zap answer. |
| Weir import PRD, DepositParams and WithdrawParams rows | Required | examined | Both rows were read. Neither contains the two caps. |
| `WeirVaults.sol` deposit, withdraw, and zap functions | Required | examined | `deposit`, `withdraw`, `_deposit`, `_withdraw`, `_balance`, and `_swap` were read. `previewRedeem`'s body was not read; WI-25 says that view does not zap. |
| Full-spread PRD, `PkgArgs` list | Required | examined | FS-PKG-01 was read. FS-PKG-02's zap-limit validation was read because it is the same fields' init check. |
| Full-spread PRD, FS-OWN-09 and FS-OWN-10 | Required | examined | Both owner-lock paragraphs were read. The inherit sentence and FS-X04 were also read so the relevance answer would not treat `PkgArgs` as the only full-spread mention. |
| `docs/research/se-zap-roi-20261031-01a18660/REPORT.md` | Required | examined | The whole 48-line report was read. It was not used as Weir evidence. |
| PairToken stage-one zap-cap paragraphs | Optional | examined | S1-ARCH-03 items 4 and 5, S1-OP-02 steps 3 and 6, the S1-OP-05 cap sentences, and the adjacent `previewZapCredit` signature were read. S1-ACC-07's formula body was not read. The heading was located at that file's line 454 only to record the gap. |
| Peer responses | Not admitted | not examined | The brief forbids reading peers on this pass. |
| Function-review file and project code outside the admitted paths | Not admitted | not examined | Not opened. `WeirBase.sol` was not opened. The refund and price limit used here are in `WeirVaults.sol` and in WI-12, WI-15, and WI-20. |

## Conclusions

Agreement is not available. Peers were not read. This is not council consensus, not an implementation, and not a PRD lock. No cap number is recommended. The stage-one bound of 10,000 is a validation domain quoted from that PRD, not a selected setting.

### 1. Weir does not configure `maxZapBps` or `maxZapTickMove`

Weir does not configure either value. This member's search of the Weir import PRD and of `WeirVaults.sol` found neither string. DepositParams carries a `zap` bool. WithdrawParams carries `zapTo` as 0, 1, or 2. There is no stored size fraction and no stored tick-move bound.

The Weir controls that do exist for a zap are:

- Deposit: the caller flag `zap`. If set, at most one in-pool swap sells the nested-floor half of the spot-value imbalance. The swap's price limit is `MIN_SQRT_PRICE+1` or `MAX_SQRT_PRICE-1`, not a tick delta. Partial fills are accepted. Unused declared input is refunded to `msg.sender` on each currency. A positive settlement net is taken to the depositor. The caller floor is `minShares`, reverting `Slippage`.
- Withdraw: `zapTo`, reverting `BadZap` above 2. Zap 1 or 2 sells the positive net of the unwanted currency, with the same global price limit and no consumption guarantee. The caller floors are `min0` and `min1`, applied to the positive amounts actually returned.
- Not a zap control: `perfFeeBps` and `MAX_PERF_FEE_BPS`. Those cut harvested fees. They do not cap entry size or tick movement.

Separate the full-spread PRD. Its `PkgArgs` list includes both fields because that section says `PkgArgs` is the PairToken set, and FS-PKG-02 rejects invalid zap limits. That is PairToken package shape. It is not evidence that Weir has the fields. FS-OWN-10 leaves the three view names open. An open getter is not a Weir configuration, and a listed `PkgArgs` field is not a Weir configuration.

### 2. The two caps are relevant to the adopted product, and Weir's swap limits do not already do their work

Yes. A size-bps cap and an entry tick-move cap each do work in the adopted full-spread product that Weir's own swap limits do not already do.

The adopted product still has single-token `exchangeIn`. The full-spread inherit sentence keeps S1-OP-02 except FS-X04's narrowing of partial fill, and keeps S1-OP-05 except the already-unlocked reject. Neither named override removes the reserve-fraction size test or the entry tick-move test. FS-X04 requires the selected positive half-swap to consume its specified input or revert `IncompleteConversion`. That is a completion check. It is not a size ceiling and not a tick-delta ceiling.

The size cap, in the inherited stage-one text, rejects an entry larger than `floor(inputReserve * maxZapBps / 10000)` of the snapshotted input reserve, and it also caps the compound leftover swap at one quarter of that fraction of the baseline active-pool reserve estimate. Weir has neither ceiling. Weir's deposit zap will attempt the half-imbalance swap up to the global price limit and refund what was not used. Weir's withdrawal zap sells the whole positive unwanted net, with no bps ceiling. Weir's compound does not swap at all. A caller `minShares` or `min0`/`min1` floor is an output minimum chosen by that caller. It does not stop a large fully fillable swap whose output still clears a low minimum. `IncompleteConversion` stops a selected swap that cannot consume its input. It does not stop a large swap the pool can fill.

The tick cap, in that same inherited text, rejects an entry swap whose tick movement exceeds `maxZapTickMove`. It governs the entry swap only, not compound, and not every square-root-price change. Weir's limit is the protocol price extreme, so the swap may run to that boundary. Output minima do not measure tick delta. A swap can move the tick past a configured bound and still mint enough shares to pass `minShares`. FS-X04 does not measure tick delta either.

So the caps are relevant to this product. They are not made redundant by adopting Weir's flag, one half-swap, global price limit, and refund. The `PkgArgs` sentence is consistent with the inherit list. It is not the relevance proof. Relevance of the check is also not a verdict that the public getters must be installed. FS-OWN-10 leaves `maxZapBps()` and `maxZapTickMove()` open. The prior ROI report left those getters unsettled. This answer does not settle that getter vote.

### 3. The per-currency split is not already in `previewExchangeIn`, and its decision use does not survive a Weir refund

`previewZapCredit` returns `shares`, `credit0`, `credit1`, `uncredited0`, and `uncredited1`. The stage-one text calls that final share credit and uncredited residual. It is not a second deposit route. `previewExchangeIn` returns `amountOut` and `amountRefunded`: shares and one same-token refund. It does not return the four-field split. A caller cannot reconstruct two credited amounts and two uncredited amounts from one share figure and one same-token refund, because the entry swap moves value between the currencies.

What the caller can do with the split, under the written full-spread rule, is see before the transaction how much of each currency is credited toward shares and how much of each currency is `J_i` booked to shared backing without extra shares. That is a reason to refuse the deposit when the booked remainder is too large, or when it lands on a currency the caller does not want to add to the shared book. `amountRefunded` is not that pair. FS-X04 books `J_i` and says previews disclose it. FS-A07 says a full selected swap can book `J_i` without a second-token payout. FS-MONEY-01 says the successful single-token call does not pay a second token. The quote facet lists `previewZapCredit` separately from `previewExchangeIn`. The inference is that the written disclosure home for the pair is `previewZapCredit`, because `previewExchangeIn`'s return type cannot carry it. No sentence was read that says the words "only `previewZapCredit` discloses `J_i`."

That decision use does not survive if unused input is refunded, as Weir does, rather than booked. Weir's outer refund is declared input minus used input, paid to `msg.sender` on each currency. A positive settlement net is taken to the depositor, not booked as shared residual for other shareholders. If the uncredited amounts come back to the caller, they are not a gift the caller needs the split in order to refuse. `previewExchangeIn` already returns the share count and one same-token refund. The four-field credit-versus-uncredited split, as specified, is then residual accounting for a policy the call is not using.

A narrower payout gap can remain under Weir's actual settlement: a positive net in the other currency is taken to the depositor, and `amountRefunded` is only one same-token amount. That is not usefulness of the booked split. The adopted success path currently refuses that second-token payout. If the family refunds unused input instead of booking it, the caller does not need `credit0`, `credit1`, `uncredited0`, and `uncredited1` to see the gift, because the gift is not booked.

The booked-residual rule is written. FS-X04, the entry-remainder disposition, FS-MONEY-01, and the inherit of S1-ACC-07 state it. It is not an FS-OWN owner lock. FS-OWN-10 leaves `previewZapCredit` open. The prior ROI report records the residual policy as not locked. The split is only decision-useful under that booked-residual policy, and this family has not owner-locked it. This response does not lock it, and it does not lock a refund policy either.

## Limits

- Runtime or extraction proof: none. These are static reads of the live files in this run. No test, build, fork, or transaction was run. No execution confirmed the checked-subtraction path.
- Not examined: `WeirBase.sol`; the S1-ACC-07 formula body; the rest of the PairToken stage-one PRD; peer responses; the function-review file; hook packages; any file outside the admitted list. A differently named cap in an unread file was not searched. Within the admitted Weir zap functions, no such argument is taken.
- `previewRedeem` in `WeirVaults.sol` was not read line by line. WI-25 says it does not zap. That sentence was read from the import PRD.
- Live files can change. This response is not an atomic snapshot of the repository.
- The prior ROI report was read as required context. Its vote counts are not evidence about Weir and are not adopted as this member's vote.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path. It does not lock the PRD.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
