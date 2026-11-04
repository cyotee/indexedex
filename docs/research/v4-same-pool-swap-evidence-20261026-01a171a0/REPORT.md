# Research report

## Question

- Run ID: v4-same-pool-swap-evidence-20261026-01a171a0
- Question: Can an actual entry swap and an actual proportional-slice exit swap make same-pool pricing safe against malicious ownership dilution or reserve extraction, when the only venue and reference is the underlying pool and its TWAP? If so, under which exact mint and execution rules? If not, exhibit a fully accounted profitable round trip or a precise limit.
- Profile: research
- Council kind: full
- Result label: partial full council

## Authorization and scope

- Authorization source: explicit user request to research whether swapping captures manipulated-price changes when target tokens may have liquidity only in the underlying pool, and to provide evidence. Independent pricing was not to be assumed.
- Authorizing task or role: invoking session 01a171a0-0d64-7a6c-b2a0-834fc1e0e7f7
- Admitted read scope: Wings money, accounting, quote, inventory, geometry, and rate surfaces; the truncated TWAP library, target, and adapters; the named audit findings and the TWAP PoC source, read only; member receipts in this run; standalone models in this run.
- Inherited permissions: accepted. They are not extra authority and not a sandbox.
- Implementation authority: none. This report does not authorize edits, tests, installs, deployment, or Git.

## Participation

| Participant | Role | Requested model and reasoning | Actual model and reasoning | Task ID | Fresh or continued | Status | Identity source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| coordinator | invoking-agent, not a vote | invoking model | continued session; earlier record said gpt-6.1-sol was exposed; continuation restore notice named grok-4.7 | 01a171a0-0d64-7a6c-b2a0-834fc1e0e7f7 | continued | synthesis published | Native session and restore notice |
| astra | council-member | chatgpt-subscription/gpt-6-astra:high | chatgpt-subscription/gpt-6-astra; high resolved | st_01a1773c | fresh | missing | Native terminal provider-policy error |
| grok | council-member | xai/grok-4.7:xhigh | xai/grok-4.7; xhigh resolved | st_01a1773d | fresh initial; advisory continued at epoch 1 | initial and feedback received | Native task record |
| minimax | council-member | minimax/MiniMax-M3, adaptive | minimax/MiniMax-M3; effective thinking payload not captured | st_01a1773e | fresh initial; advisory continued at epoch 1 | initial and feedback received | Native task record |
| kimi | council-member | kimi-coding/k3:high | kimi-coding/k3; high resolved | st_01a1773f | fresh initial; advisory continued at epoch 1 | initial and feedback received | Native task record |

- Coordinator mode: invoking-agent
- Actual mode equals requested mode: yes
- Missing initial responses: astra
- Missing feedback: astra, not requested

## Conclusions

Executed swaps do not, as a general fact, make same-pool pricing safe. They price the quantity that actually traded. A mint that then applies that execution price, or a live whole-book liquidation quote from the same pool, to inventory that did not trade is a different rule. That second step is where the checked witnesses extract value.

No received response found a same-pool-only rule that is at once single-sided, same-transaction, fully credited for retained overage, and proved manipulation-free. That is a limit of the searched rules, not a proof that no such rule exists. Astra did not speak.

The closed witnesses, each in its own domain:

- Current live-quote issuance, Kimi's toy, rechecked: about `+18055.89` target, opposing about `0`, incumbent per-share quote about `0.208020` to `0.189964`, fee 0. This is not a rerun of APEX-012. The reported Foundry profit stays reported.
- Literal rule `m = S * D / (A_T + p_exec * A_O)`, Grok Domain L, rechecked: exact profit `320226133435299/10170234955199`. The attacker borrows opposing and repays the lender in kind. The lender is assumed not to sell that repayment through this pool. The identity is rechecked. The lender's existence for a sole-venue token is not.
- Same literal rule, MiniMax idle opposing-heavy book, rechecked: `5162744.89786187` target at a 49% entry, opposing end `0`, 0.3% fee. The loan is repaid by buying opposing through the same pool. The 50%, 51%, and 1% entries on that book also rechecked closed and positive. The vault is idle inventory, not active Wings liquidity. Default spacing was disclosed as likely to activate a wing. This rejects "the attacker must trade the manipulation inventory through this pool, so the sides cancel" as a universal rescue. It does not establish the same profit inside Wings ranges.
- Immediate deposit, entry swap, mint, and slice exit, coordinator single-interval model, rechecked, no prior dump: executed-average marking is negative at 1% and 10% vault ownership and positive from 50% through 100% at a 0.3% fee and a 200 target deposit. At 100% ownership the net is `4.313684168578358357` target, opposing `0`, ledger error `0`. The vault filling the swap does not bind the later slice exit to `p_exec`.

Attacker-owned same-pool LP and JIT inventory were compared and do not rescue the priced mint. APEX-012 reports a JIT extraction against the current live-quote rule: `70,634,405,953` raw token0 on a `1e12` book, control `-1`. That PoC was not rerun. Grok's standalone calibration of that current rule, pool `1,000/1,000`, temporary `10,000/10,000` liquidity, was about `+2.095` target with opposing and debt zero. That row was not re-executed and is not a Foundry reproduction. MiniMax's closed literal-rule witness ended with attacker JIT LP inventory zero, so that profit does not depend on the attacker also being an LP. Kimi did not model JIT inside the quote and reported that APEX-012 shows it worsens the baseline. Grok also reported a fee case where an unprofitable non-LP attacker still left an incumbent shortfall because fees went to the external LP, and said the combined case where the attacker owns that LP was not the headline. The coordinator model is the other ownership: the vault, not the attacker, owns the active interval. Attacker JIT is therefore a reported aggravation of the current quote rule and an unresolved production variant, not a missing condition for the literal-rule counterexamples that already closed without it.

Rows that are not closed target profit stay labeled that way. Kimi's `+9627.8` rechecks as target delta about `-9833.90` plus opposing residual about `+19461.68`. That is a restored-price convention, not target profit. Kimi's advisory accepted that correction.

A fixed 49/50/51 entry is not a safety threshold. On the rechecked MiniMax book all three are largely positive, and a 1% entry is larger. On the coordinator 100%-ownership immediate case, 49%, 50%, and 51% of a 200 target deposit are all positive. Tiny deposits in that model were slightly negative. Sign depends on book, size, and ownership.

The price-free alternatives that survived as stated are proportional claims on the inventory vector, with unmatched tokens refunded. They are not one rule. Grok's rule is a scalar of the per-range liquidity vector: core liquidity, each wing's liquidity, each idle balance, and fee checkpoints. Kimi and MiniMax used `min(d_T/A_T, d_O/A_O)` on token claims, and said liquidity units in disjoint ranges are not one commensurable aggregate. All three rejected a single square root of aggregate token balances as the invariant. Grok's Domain L exact-zero row for the proportional control was not rechecked. The coordinator proportional control was about `-0.450` target under a 0.3% fee, which is fee and impact drag, not an extraction. What these rules give up is full credit for retained overage and a clean single-sided deposit. A 49% swap of the deposit is not a scalar of the book. Leftovers marked at `p_exec` recreate the literal-rule numerator. Kimi reported that a vault-executed zap on the mint path breaks claim neutrality; that defect was not re-executed. This is not implementation authority.

Current TWAP, source-checked this session, credits the elapsed gap with the truncated live tick and stores that tick as the next anchor. `update(PoolKey)` is public and has no `isUnlocked` check in that function. APEX-050's reported poke was not rerun. Its lender is hypothetical test code, not the Wings vault. A corrected anchor stops the retroactive backfill. It does not reconstruct prices between pokes, and it does not create an external arbitrageur on a sole venue. It can be a delay or a cap. It is not an independent mint price. Kimi said a live-versus-TWAP band should fail open to proportional entry rather than halt deposits. Grok did not make that recommendation. MiniMax listed deviation bands in a gate stack and did not state the fail-open rule.

`getRate` in source is the whole-book liquidation quote times `1e18` divided by supply. That is not the requested one-share withdrawal-and-sale preview. The requested meaning stays a normalized preview of withdrawing one whole share, selling that share's opposing slice, and reporting target proceeds plus the target slice. A preview of size `q` uses `q`'s own impact. A view does not trade. Issuance accounting stays separate. This report does not authorize implementing that distinction. A whole-book sale quote, divided per share, amortizes more impact than a one-share slice sale and is typically a lower target number. That direction is not a reason to treat the current return as the requested preview. Whether the lower number is conservative depends on the consumer: a lender seeing less collateral is not the same case as a shareholder being quoted less than a one-share exit. A same-pool quote is not independent collateral.

Consumers are a separate surface from vault issuance. MiniMax reported, and this coordinator did not re-read those files this session, that buffer-hook `ratedReserve` paths value a share balance with scalar `getRate` without redeeming, that DETF scaling multiplies by `getRate`, and that the Balancer standard-exchange rate provider uses a full-book exit preview rather than the vault's one-share rate. A consumer that redeems must quote the quantity it redeems. A consumer that does not redeem is not made safe by a vault mint rule. Issuance safety does not freeze either number.

## Evidence

| Item | Source | Class | Used for |
| --- | --- | --- | --- |
| No entry swap; live quote then issue | Money.sol `_deposit` lines 120-140, re-read this session | source observation | Current mint is not the proposed swap rule |
| Live quote then entitlement | Money.sol `_redeem` lines 156-163, re-read this session | source observation | Current exit pays a book quote |
| Issue formula | Accounting.sol lines 18-22, re-read this session | source observation | `supply * credit / value` |
| getRate is whole-book quote over supply | EconomicTarget.sol lines 29-32, re-read this session | source observation | Separates current code from the requested preview |
| TWAP credits the live truncated tick across the elapsed gap; update is public | TruncatedTwapOracleLib write path; MultiPoolTwapOracleTarget.sol lines 32-45 | source observation | Current oracle is not a historical anchor |
| Domain L exact fraction | coordinator/received-originals/grok.md; research/recheck.json | exact derivation, coordinator re-execution | Closed conditional profit. Lender existence unverified |
| Idle-book closed profit and 49/50/51/1% signs | coordinator/received-originals/minimax.md; research/recheck.json | reproducible standalone witness | Closed same-pool repayment profit outside Wings geometry |
| Baseline closed toy; literal-rule convention row; proportional attack rows | coordinator/received-originals/kimi.md; research/recheck.json | reproducible standalone witness | Current-rule toy profit; `+9627.8` is not closed target profit |
| Immediate self-fill nets by vault fraction | research/model.py; research/results.json; re-executed this session | reproducible standalone witness | Executed-average mint can profit with no prior dump when the vault owns the interval |
| APEX-012 and APEX-050 outputs | audit diff review, as read by members; not rerun | reported existing PoC output | JIT quote extraction and retroactive TWAP. Not a fresh Wings profit |
| Attacker JIT LP | Grok calibration, unrechecked; MiniMax witness ends at zero attacker JIT LP; Kimi omitted JIT | member-reported standalone witness and reported PoC | JIT aggravates the current quote rule. Literal-rule closed profits above do not require attacker LP |
| Advisory dispositions | coordinator/received-feedback/{grok,minimax,kimi}.md | member advisory | Two wording corrections accepted. No verdict reversal |

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| CLAUDE.md | required | partially examined | Grok grepped it and reported no pricing law. Not read end to end by the coordinator this session. No pricing law is invented. |
| Wings Money, Accounting, LiquidationQuote, Inventory, Geometry, ExecutionDelegate, rate surface | required | examined | Deposit, redeem, issue, and getRate re-read. Harvest placement was not line-read this session. |
| APEX-012, 024, 025, 026, 040, 050 | required | partially examined | Read by members in the diff review. PoCs not rerun. |
| TWAP library, target, adapters | required | examined | Write credit and permissionless update re-read. Adapter maxWriteAge follows from the write resetting lastTimestamp, as members reported. |
| TwapRetroactive.t.sol | required | partially examined | Read by members. Not executed. |
| Prior council report and TWAP PRD | optional | not examined as proof | The prior council did not prove self-executed pricing unsafe. It is not a source for this verdict. |
| Wings three-slot attack execution | required for a production claim | not examined | No model here is a core-plus-both-wings PoolManager sequence. |
| Attacker-owned same-pool LP and JIT | required comparison | partially examined | Reported APEX-012 JIT and Grok's unrechecked calibration. MiniMax closed witness has zero attacker JIT LP. No production JIT variant was run. |
| Downstream rate consumers | required comparison | partially examined | Separated from issuance. Named consumers are MiniMax source observations, not re-read this session. |

## Disagreement and missing responses

- Disagreement: Grok did not find a closed literal-rule profit when the tested balanced deep position had to buy the manipulation inventory back through the pool. That row was not rechecked. MiniMax found a large closed profit on an idle opposing-heavy book with repayment bought through the pool. Those books are not the same. Kimi's highlighted literal-rule profit on an LP book is convention-valued residual opposing. The proportional cutoff also differs: Grok's per-range liquidity scalar is not the Kimi/MiniMax token-claim min-ratio.
- Dissent carried into this report: both Domain N and the idle-book witness; both proportional cutoffs; Astra's silence.
- Missing responses treated as approval: no
- Feedback used as a missing initial response: no

Received feedback did not reverse the verdict. Grok supported with two wording reservations, both accepted in this report and not edited into the frozen draft. MiniMax and Kimi supported. That is not unanimity, and it is not a correctness proof. Astra is missing.

## Advisory review

- Draft ID: draft-v4-same-pool-swap-evidence-20261026-01a171a0-r1
- Draft path: coordinator/draft.md
- Resolution path: coordinator/resolution.md
- Feedback dispositions: grok support-with-reservations; minimax support; kimi support; astra not received
- Post-review wording changes: loan-flow sentence; proportional-rule attribution; fail-open band named as Kimi only; getRate impact-direction note; attacker-LP/JIT comparison and consumer separation added for required coverage
- Those changes are member-approved: no

## Recommendations

- Do not treat an executed entry or exit swap as proof that the share cut is fair.
- Do not use the literal executed-price denominator, a live whole-book quote, or the current TWAP as a manipulation-resistant mint price for a sole-venue token.
- If a later, separately authorized design needs a no-price mint, study the two proportional cutoffs named above and refund unmatched tokens. Do not mark leftovers at `p_exec`.
- Keep `getRate` as the requested one-share withdrawal-and-sale preview, separate from issuance. Do not implement that distinction on the authority of this report.
- A production-first Foundry witness is a different task. This report does not run it and does not authorize it.

## Limitations

- Astra's original is missing. The result is a partial full council.
- Grok's Domain N excess, fee grid, sandwich, and one-share quote move were not re-executed. Kimi's W4/W5 and TWAP replica were described, not coded.
- No Foundry sequence was run. Standalone arithmetic is not a Wings test and not a reproduction of the audit PoCs.
- Flash-loan availability for a sole-venue opposing token is unverified.
- Live source can move. Line checks are of the tree opened this session, not an atomic snapshot.
- The coordinator continuation model name differs from the earlier exposed coordinator name. That is recorded. It is not a second vote.

## Publication

- Publication state: published
- Final path or chat-only statement: docs/research/v4-same-pool-swap-evidence-20261026-01a171a0/REPORT.md
- Cooperative update: not applicable. No existing PRD was overwritten.
- Unrelated edits preserved: yes. No production or config file was edited.
- Model work repeated for publication: no
- Git actions: none
- Artifacts retained until explicit deletion: yes
