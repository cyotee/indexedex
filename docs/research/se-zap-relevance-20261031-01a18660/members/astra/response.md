# Astra: Zap relevance to the adopted full-spread vault

## Identity

- Assignment: independent Astra research member.
- Run: `se-zap-relevance-20261031-01a18660`.
- Requested model: `chatgpt-subscription/gpt-6-astra:high`.
- Actual Native model, account route, and reasoning setting: not exposed.
- Native parent/root identity: not exposed.
- Date: October 31, 2026.
- This response is an independent recommendation, not a council consensus, a PRD lock, or implementation authorization.

## Question and targets

1. Does Weir configure `maxZapBps` and `maxZapTickMove`, and what zap controls does it actually have?
2. Do those two caps perform useful work in the adopted single-position full-spread Standard Exchange vault, which retains single-token `exchangeIn`?
3. What does `previewZapCredit`'s per-currency split let a caller do beyond `previewExchangeIn`, and does that value survive refunding unused input?

The targets are the admitted Weir source and import requirements, the specified full-spread configuration and owner decisions, the previous zap ROI report, and the optional PairToken cap paragraphs. The locked drops of `previewWithdrawalMode` and `wrappedNative()` are not reconsidered.

## Evidence

All source observations below are from local files read in this assignment. Interpretations and recommendations are identified separately.

**E1 - Source observation: independent negative searches.** I searched the complete files `contracts/protocols/strategy/weir/WEIR_VAULT_SOURCE_IMPORT_PRD.md` and `contracts/protocols/strategy/weir/WeirVaults.sol` for `maxZapBps|maxZapTickMove`. Both searches returned zero matches. This independently verifies the brief's reported absence; absence of names alone is not the behavioral proof. The relevant function bodies were also read directly.

**E2 - Source observation: deposit controls and refunds.** In `contracts/protocols/strategy/weir/WeirVaults.sol:160-185`, `deposit` is paused/reentrancy/deadline guarded, accepts caller `minShares`, and refunds `p.amount0 - used0` and `p.amount1 - used1` to the payer. In `_deposit` at lines 248-285, `p.zap` selects balancing, liquidity is sized at the resulting pool price with a two-unit reduction of each candidate amount, and shares are calculated from liquidity. Net settlement combines swap and add-liquidity deltas; negative nets determine used input and positive nets are settled to the depositor. These are not a configurable reserve-fraction cap or entry tick-movement cap.

**E3 - Source observation: actual balancing and swap limits.** `WeirVaults.sol:387-426` contains `_balance` and `_swap`. `_balance` values the inputs at the current pool price, sells half the calculated imbalance using the specified nested-floor arithmetic, skips a zero-sized swap, and incorporates actual returned deltas. `_swap` requests exact input through negative `amountSpecified`; its price limit is `MIN_SQRT_PRICE + 1` or `MAX_SQRT_PRICE - 1`, by direction. Neither function checks a reserve-relative input fraction or compares ticks before and after the swap.

**E4 - Source observation: exit control is different.** `WeirVaults.sol:187-204,288-325` checks the deadline and `zapTo`, removes proportional liquidity and idle, optionally swaps a positive unwanted currency, settles both final nets, and checks `min0` and `min1`. It does not require complete conversion to one currency.

**E5 - Source observation: import requirements agree with the source.** `contracts/protocols/strategy/weir/WEIR_VAULT_SOURCE_IMPORT_PRD.md:156-157` lists `DepositParams` with `zap`, `minShares`, and `deadline`, and `WithdrawParams` with `zapTo`, `min0`, `min1`, and `deadline`. WI-13 through WI-20 at lines 184-204 preserve liquidity-based issuance, signed settlement, proportional withdrawals, the one-swap heuristic, global price limits, and actual-delta accounting. WI-20 explicitly preserves partial fills rather than adding a full-consumption requirement.

**E6 - Source observation: full-spread configuration is not Weir configuration.** `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md:177-187` says `PkgArgs` is the PairToken set and lists `uint16 maxZapBps` and `int24 maxZapTickMove`. FS-OWN-09 at line 62 maps paired deposit/redeem to bundle routes and makes the mapped redemption proportional, without selling one leg. FS-OWN-10 at line 64 leaves `previewZapCredit`, `maxZapBps`, and `maxZapTickMove` open while locking the two unrelated selector drops.

**E7 - Source observation: the names' originating policy.** In `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md:533-553`, S1-OP-02 caps the declared single-token entry amount at `floor(inputReserve * maxZapBps / 10000)` using the specified pre-entry-swap reserve snapshot. It separately caps `abs(tickAfter - tickBefore)` around the entry swap while using the same extreme square-root-price limits. It then books uncredited residual. The cap paragraphs at lines 603-620 also use `maxZapBps` for a quarter-sized compound cap and expressly restrict `maxZapTickMove` to entry swaps. These are PairToken requirements, not evidence of Weir behavior or permission to adopt the compound coupling.

**E8 - Source observation: the earlier ROI answer was conditional.** `docs/research/se-zap-roi-20261031-01a18660/REPORT.md`, under Answer and the three function headings, reports unresolved recommendations. It describes `previewExchangeIn` as returning shares and a same-token refund, whereas `previewZapCredit` supplies the per-currency credit and uncredited split. It makes the latter's usefulness conditional on the accounting policy and planner reuse. Its getter recommendations assume stored caps; it does not establish that Weir stores them. This is prior research evidence, not fresh verification of the PairToken planner implementation.

## Assumptions

- The brief's adopted product remains one full-spread position with a single-token `exchangeIn`; dropping separate paired selectors does not remove that entry swap.
- Refund behavior is the scenario being evaluated, not a new claim that this family has locked every detail of Weir settlement or share issuance.
- A comparison to PairToken's size cap means its documented entry-amount test, not an invented cap on only the half-input swap. A future design must define the reserve basis, snapshot, rounding, and bootstrap applicability explicitly.
- A predicted per-currency allocation is state-dependent information. Publishing it neither enforces execution minima nor supplies an independent price reference.

## Coverage

| Target | Coverage |
| --- | --- |
| Weir import PRD | Required parameter rows and WI-13 through WI-20 examined; complete-file cap-name search independently performed. Not a whole-PRD audit. |
| Weir source | External/internal deposit and withdrawal, `_balance`, and `_swap` examined directly; complete-file cap-name search performed. No dependency audit or execution. |
| Full-spread PRD | Required `PkgArgs`, FS-OWN-09, and FS-OWN-10 examined. No PRD edits. |
| Prior zap ROI report | Read as admitted prior research; its conditional recommendations are not treated as locked requirements. |
| PairToken stage-one PRD | Optional entry-cap and compound-cap paragraphs examined only for policy origin and distinction. |
| Current council peers | Not read. |

## Conclusions

### 1. Does Weir configure the two caps?

**No. The examined Weir source does not configure or enforce either cap. The current full-spread PRD does list both as package inputs. Those are separate facts.** The latter comes from its PairToken configuration sentence, not from Weir. [E1-E7]

Weir's actual zap-related controls are the caller's deposit `zap` choice, withdrawal `zapTo` choice, transaction deadlines, deposit `minShares`, withdrawal `min0`/`min1`, its bounded one-swap balancing procedure, and the global square-root-price endpoints. Deposit also has pause/reentrancy guards, but those are operational controls rather than price-impact caps. Actual deltas determine accounting and unused declared deposit input is refunded; none of this is a configurable entry-size or local tick-movement test. [E2-E5]

The two package fields therefore need an explicit adaptation decision. They must not be justified as settings required by the Weir import. The existence of an internal policy and the usefulness of exposing its getter remain separate decisions. [Inference from E6-E8]

### 2. Are the caps relevant to this product?

**Yes, as additional entry policy; they are not redundant with Weir's swap limits, but neither is required merely to reproduce Weir. I recommend retaining their purpose for the adopted single-token entry route, subject to an explicit definition of the reserve basis and checkpoint.** This recommendation supplies no numeric value and locks no requirement. [Inference from E2-E3, E6-E7]

- **Size cap:** A reserve-relative test rejects an entry that is too large relative to the chosen liquidity/reserve basis before allowing its swap. Weir's half-imbalance heuristic scales with caller inventory, not with that reserve basis. Its extreme price endpoints do not enforce a maximum entry fraction. Refunding leftover input does not undo the swap already performed; the restriction can therefore still matter with refunds.
- **Tick-movement cap:** A before/after entry-swap tick test rejects too much local price movement even when the swap remains far inside the global endpoints. Weir does not impose that local bound. Full-spread liquidity avoids a narrow position range; it does not make a swap price-neutral. A refund policy likewise does not eliminate this distinction.

The controls overlap in intent but test different quantities: one bounds relative entry size and the other observes movement around the actual swap. `minShares` tests the caller's final share outcome; it does not itself impose either protocol-wide bound. Conversely, these caps do not replace `minShares`, prove a fair starting price, or prevent all manipulation. An already-distorted starting price can satisfy a local movement bound. These are limited admission controls, not an oracle or a security proof. [Inference from E2-E3, E7]

Do not carry over the PairToken compound quarter-cap merely because the field name is retained. Nor should the entry tick bound be applied to every price change during compounding or other operation. Under FS-OWN-09, mapped redemption does not swap one leg, so a zap-entry argument cannot justify an exit cap there. [E6-E7; recommendation]

### 3. What does the per-currency preview add, and is that useful with refunds?

**It adds a composition/accounting breakdown, not another share-output guarantee. Its strongest actionable use depends on booked uncredited residual, which this family has not locked. Under a refund policy, I would not retain `previewZapCredit` solely for that rationale.** [E8; inference from E2, E7]

If residual is **booked**, a caller can inspect which amounts in each currency are credited toward the entry and which are retained without purchasing additional shares. That can support a UI disclosure, a route-comparison policy, or a decision to use paired input instead. The shares-plus-same-token-refund preview does not expose that per-currency accounting. A common valuation basis is still needed to compare the economic significance of different tokens; the raw split is not itself a loss estimate. [E7-E8; inference]

If unused input is **refunded**, the claim that the caller needs these fields to discover value left in the vault without shares no longer follows for that refunded inventory. For a caller deciding how much input to spend, how many shares to receive, and how much input comes back, `previewExchangeIn` already provides the principal decision outputs described by the prior report. A credit pair can still support composition display, attribution, or reconciliation, but those are narrower uses, not proof that the five-output public interface earns its maintenance cost. [E2, E8; inference]

There is one concrete settlement distinction worth preserving: Weir can settle a positive net in the other currency directly to the depositor, in addition to refunding unused declared input. A router that must forward all resulting assets could benefit from a preview of those per-currency receipts. However, a field meaning "uncredited but booked" is not automatically a field meaning "returned to the caller." The admitted sources do not establish that `previewZapCredit` predicts those receipts under the adopted settlement policy. Any such justification must define recipient, currency, and returned-versus-retained semantics rather than relabel the old fields. Execution must still handle actual receipts, not assume the preview is final. [E2, E5, E8; inference]

**Recommendation:** keep `previewExchangeIn` as the primary single-token entry quote. Do not justify `previewZapCredit` by an unadopted booked-residual policy. Retain that extra public preview only if a concrete composition consumer or multi-currency receipt consumer is identified and the fields accurately represent the adopted execution. Reusing one planner is a prerequisite for controlling cost, not by itself evidence of caller value. This narrows the previous report's conditional keep argument rather than treating its unresolved split as a decision. [E8; recommendation]

## Limits

This is static research against live local files, not an atomic repository snapshot or runtime proof. I did not run tests, builds, installs, Git commands, deployments, wallet actions, or sub-agents. I did not read current council peers or edit the PRD, function-review file, or project code. Only this assigned response is written.

No cap magnitude, reserve adapter, bootstrap rule, residual policy, additional selector, or compound coupling is locked here. The response neither implements the recommendations nor authorizes implementation.
