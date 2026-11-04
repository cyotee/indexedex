# Research report

## Question

- Run ID: v4-swap-capture-evidence-20261026-01a177b3
- Question: Do actual swaps during deposit and during exit eliminate the reported share-pricing vulnerability when target-token liquidity may exist only in the underlying pool and that pool's TWAP is the available reference?
- Profile: research
- Council kind: full
- Result label: full

## Authorization and scope

- Authorization source: the current user asked for a council to redo the research and for actual evidence on whether those swaps eliminate the vulnerability.
- Authorizing task or role: invoking session, acting as coordinator, not as a vote.
- Admitted read scope: the session handoff, the prior evidence report as context only, production vault source read for the mint and exit path, and this run's member artifacts and coordinator ledgers.
- Inherited permissions: accepted. They are not extra authority and not a sandbox.
- Implementation authority: none. This report does not authorize edits, tests, installs, deployment, or Git.

## Participation

| Participant | Role | Requested model and reasoning | Actual model and reasoning | Task ID | Fresh or continued | Status | Identity source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| coordinator | invoking-agent coordinator, not a vote | invoking session | exposed labels: PI_MODEL=gpt-6.1-sol in one kernel; persona and restored label grok-4.7. Not two votes. | none | continued | completed | Native session 01a177b3-f4ed-7770-9633-b5735573eb05 |
| astra | council-member | chatgpt-subscription/gpt-6-astra:high | admitted that route; member says native actual model not exposed | st_01a177b9 | continued for advisory epoch 1 | original and feedback completed | Native task admission in RUN.md |
| grok | council-member | xai/grok-4.7:xhigh | admitted that route; member says actual model not exposed. Monitor label grok-4.7 | st_01a177ba | continued for advisory epoch 1 | original and feedback completed | Native task admission in RUN.md |
| minimax | council-member | minimax/MiniMax-M3, adaptive thinking | member reports MiniMax-M3, PI_REASONING_LEVEL=high. Adaptive payload not observed | st_01a177bb | continued for advisory epoch 1 | original and feedback completed | Native task admission plus member self-report |
| kimi | council-member | kimi-coding/k3:high, global route | admitted that route, reasoning high. Monitor label k3 | st_01a177bc | continued for advisory epoch 1 | original and feedback completed | Native task admission in RUN.md |

- Coordinator mode: invoking-agent
- Actual mode equals requested mode: yes
- Missing initial responses: none
- Missing feedback: none

## Conclusions

- No. Executing a swap during deposit and a swap during exit does not eliminate the vulnerability for the quote rule or the executed-price rule in the domains that were rechecked.
- Production does not currently swap the entrant's deposit. `UniswapV4UpperLowerWingsStandardExchangeVaultMoney._deposit` pulls target, harvests, reads `Quote.quote`, then calls `Accounting.issue` before `_changeTarget`. For existing supply that mint is `floor(supply * credit / quote)`. The pending deposit is not in the booked balances when the quote is taken. `_redeem` pays `floor(shares * quote / supply)` from the same whole-book quote. If the idle target sleeve is short, `_fund` can close positions and `_swapDeficit` can sell the whole local opposing balance, not only the redeemer's slice. `getRate` is that whole-book quote times `1e18` divided by supply, or synthetic `1e18` at zero supply. That is not a one-whole-share withdrawal-and-sale preview. This report does not redefine `getRate`.
- The swaps fail to close the hole for more than one reason. Marking inventory the swap did not trade is sufficient in some rows. It is not the cause of every row. Astra's zero-old-opposing witness has no old opposing inventory to extrapolate, and it still extracts target.
- A price-free per-component join removes the pool-price conversion and the demonstrated acceptance-time ownership distortion, under the conditions stated below. It is not a proof that every later trade is harmless, and it is not claimed to be the only rule that could be safe.
- The same-pool TWAP, as read, is a poke record that can credit an idle gap with the truncated live tick. It is not an independent price and it is not a frozen pre-trade reference.

The three mechanisms below are not the same defect. A row from one does not rerun another.

### Quote manipulation

Mint `floor(S * D / V)` and, if redemption pays the live quote, payout `floor(shares * V_live / supply)`. `V` is the live whole-book liquidation quote. The pool fee is inside that sale. No separate fee cutoff below 100 percent was shown to close these rows. Inventory cutoff: none. Unsold opposing adds nothing in the quote model used here.

On a 200 target deposit, vault fraction 1, JIT liquidity 10 times pool liquidity, fee 0.3 percent, the quote-paid exit made net target profit 60.440726. The slice-sale exit of the same mint made net target profit 22.178387. Both figures are net profit, not gross payout. The slice sale removes the extra profit that comes from paying the inflated quote. It does not repair the mint. At full ownership and no JIT, the quote redeem returned the deposit and the slice sale still made net 22.199955 target, because that quote had valued unsold opposing at zero. Kimi's advisory recheck says a whole-book mint versus a per-slice exit can extract without that zero cutoff and without a prior push. That number, `+15068798773.084002` on a 1e11 deposit, was not re-executed here. The mechanism point is accepted. The number stays member-reported.

Grok's idle-book row, rechecked from `members/grok/model.py`, is `+1179070738173910` target with a no-JIT control of `-1`. Domain: sleeve-sufficient idle book, one range, quote after owned liquidity is removed. It is not a both-wings harvest and not a hook sequence. The same model, quote mint then slice exit with no prior push, closed at `+1103316364600005`.

### Executed-price allocation, including a case with no old opposing inventory

Gross execution price `p_g = q / u`. Retained credit `(D - q) + p_g * u = D`. Net price `p_n = (q - fee_T) / u` retains `D - fee_T`. The issuance denominator is the old book. The new credit is not in it. `A_T` and `A_O` mean booked idle, removable principal, and uncollected fees unless a row says idle-only. Old LP fees are counted once.

When old opposing inventory is zero, the denominator is the old target balance. The execution price does not enter it. The loss comes from issuing against a changed mixture and then unwinding a smaller slice through a nonlinear pool.

Rechecked compact ledger, zero fee, continuous constant-product, virtual reserves, no stated nonzero reserve offset. Initial attacker 100 target, vault 100 target and 0 opposing, external virtual reserves `(100, 100)`. Swap 50. After entry the vault is `(150, 100/3)` and the pool is `(150, 200/3)`. After the attacker's slice exit the attacker has 105 target, the vault is `(75, 50/3)`, and the pool is `(120, 250/3)`. After the incumbent closes, the incumbent has 95 target and the pool is back at `(100, 100)`. Both tokens close. Profit is 5 target. Locator: `coordinator/recheck-astra.md`.

Same sizes, fee 0.3 percent, gross credit. Attacker final wallet `10470058473/99880180`, about 104.826187. Net profit `482040473/99880180`, about 4.826187. The larger fraction is the final wallet, not the profit.

Coordinator interval ledger, vault owns the whole interval, deposit 200, swap half, fee 0.3 percent, then sell only the slice: profit `909146072454192229/210758608401740140`, about 4.313684, ending opposing 0. Zero fee, same sizes: `80/17`. Across 288 cases, 155 executed-price rows were positive and 0 proportional rows were positive. Locator: `research/EXECUTED.md`. This machine is not Astra's zero-opposing witness and not MiniMax's constant-product reduction.

MiniMax idle-opposing, vault not the LP, full swap, rechecked from their function: profit `182670959878875300000000000000000/90821980886249`, opposing 0, both tokens closed. This row needs no prior price push. It is not a rerun of the audited manipulation. Their reported incumbent split of about 2.379517 was not rechecked. Their `+25.472084e18` and `+30.508645e18` quote rows are transcript arithmetic. The shipped `model.py` does not print them.

The fee-aware sentence in the draft was too broad. For a vault-initiated swap that retains its output, spent target and execution-price times output can cancel, so the old-book mark can match the pre-swap book. That is not vault-as-LP self-fill. Rechecked self-fill residual: post inventory `(1049999999999999999, 552517026241844072)`, swap output `94965947516311854`, mark `1631805416248746237`, liquidation quote `1434680630207761058`, gap `197124786040985179`. The mark does not equal the quote.

Kimi's combined-book identity, `(A_T + D - alpha*D) + p_exec*(A_O + delta_O) = A_T + D + p_exec*A_O`, includes the retained deposit. It is the combined book. It is not the issuance denominator that excludes the new credit. Using it as that denominator would be a different rule. It was not re-derived here beyond that distinction.

Fee and inventory cutoffs for this rule are roots of a named book's profit function. MiniMax's `alpha* = 0.579815732950` and `f* = 20802.214799` pips are that instance, not a general boundary. A fixed 49/50/51 percent split is not a threshold.

### Vault self-fill

When the vault owns the liquidity that fills the exit sale, the attacker is trading against the vault. The coordinator interval ledger is positive in that configuration, including the half-swap row above. MiniMax's single-range reduction is negative when their function sets the vault as LP, at the shares they reported: 0, 0.25, 0.50, and 0.75. A coordinator call of that function at share 1 is not their report. At that point external depth is zero. The signs are preserved. Neither machine rebuts the other.

Grok's `self_fill_note` has 2 wei of pool-versus-claim dust. Token totals were conserved. It is not used as an exact witness.

### Price-free per-component join

Accepted fraction is per component: idle target, idle opposing, and each range's liquidity, matched to what the entrant contributed. Unmatched tokens are refunded in kind. This is not one scalar minimum over liquidity units that do not share a unit.

At acceptance, before the sale, with post-conversion fee-attributed book `B`, accepted claim `C = lambda * B`, and minted shares `m = lambda * S`, the identity `S / (S + m) * (B + C) = B` holds when nothing else mutates the book, matching is range by range, and rounding is the stated direction. Removing fraction `h` leaves `(1 - h) * B` before the sale.

The sale can change what remains. If the vault's liquidity fills it, remaining token composition and fees move. The invariant is not a post-sale guarantee that every holder's token principal is unchanged. Kimi's stronger claim, that the rule eliminates the extraction channel inside a stated domain including a slice-bounded exit, is carried as dissent. It is not the conclusion of this report.

The 288-case proportional control had no positive target profit. That grid is not a universal safety proof. The supporting statement is the acceptance identity, inside its domain.

### Same-pool TWAP

Two different mints have to be named. Gross credit: `m = S * D / (A_T + p_bar * A_O)`. Retained credit: `m = S * ((D - q) + p_bar * u) / (A_T + p_bar * A_O)`. A frozen reference can preserve the scalar `A_T + p_bar * A_O` for retained credit. That is not preservation of the ownership vector, and it is not preservation of executable target proceeds.

When old opposing inventory is zero, the gross-credit witness does not depend on `p_bar`. Freezing the reference does not close that row.

The implementation read in `coordinator/twap-source.md` is not that frozen reference. `update` is public. After the first observation, `write` applies the truncated live tick across the whole idle gap. A later read can fill an unwritten tail with the current truncated tick. The cap used in the member print is 9116 ticks. Kimi's program printed `1.0001^9116` as `2.488187224469637`. That is the program print, not the exact power. An 80-digit evaluation is `2.488187224469886...`. Both are above 2.25, so the rate-limit comparison does not depend on the tail. This oracle does not supply an independent price. Nothing in the source forces an outside trade to restore the pool.

## Evidence

| Item | Source | Class | Used for |
| --- | --- | --- | --- |
| Production mint and redeem path | `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol`, `_deposit`, `_redeem`, `_fund`, `_swapDeficit`, read this session | source observation | No entrant swap. Quote before booking. Whole-book payout. Whole opposing sale when the sleeve is short. |
| Issue and entitlement | `UniswapV4UpperLowerWingsStandardExchangeVaultAccounting.sol`, `issue` and `entitlement`, read this session | source observation | `floor(supply * credit / value)` and `floor(shares * value / supply)` |
| getRate | `UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.sol`, `getRate`, read this session | source observation | Whole-book quote times `1e18` over supply, or `1e18` at zero supply. Not changed. |
| Interval ledger | `research/EXECUTED.md`, from `research/ledger.py`, sha256 `558fe479e1d6cdfa673c33484533416b7ce77ca4abfe83cae9f35faad326c7ae` | coordinator-supplied | Executed-price and quote-versus-slice rows. 155 of 288 and 0 of 288. |
| Astra compact ledger | `coordinator/recheck-astra.md` | coordinator-supplied | Zero-opposing witness and the fee-row wallet versus profit |
| Grok model recheck | `members/grok/model.py`, `fee_aware_residual()` re-executed this session; JIT and slice rows in `coordinator/recheck-grok.md` | coordinator-supplied | Self-fill gap and the idle-book domain |
| MiniMax function recheck | `coordinator/recheck-minimax.md` | coordinator-supplied | Idle-opposing profit and the LP-share sign split. Not the transcript quote rows. |
| Kimi print recheck | `coordinator/recheck-kimi.md` and the current `members/kimi/response.md` line for the 5e11 row | coordinator-supplied | Model print versus the corrected response text |
| TWAP source | `coordinator/twap-source.md` | source observation | Public update, truncated gap credit, not a frozen reference |
| Member originals and feedback | `members/<label>/response.md` and `feedback.md` | source observation of those artifacts | Positions, dissent, and numbers explicitly labeled member-reported |
| Audit Foundry output | named in the handoff, not rerun | unverified | Not used as profit evidence |

No private source was sent to a search or fetch service for these rows.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| Whether a deposit swap plus an exit swap eliminates the quote-rule extraction | required | examined | Closed rows in `research/EXECUTED.md` and the Grok recheck. Production source shows the current path has no deposit swap. |
| Whether those swaps eliminate the executed-price extraction | required | examined | Astra compact ledger, interval ledger, MiniMax idle-opposing recheck. |
| Same-pool TWAP as the only reference | required | examined | Source read. Not executed as a Wings profit trace. |
| Price-free proportional alternative | required by the comparison, not as a requested implementation | examined | Acceptance identity and the 288-case control. Post-sale immunity not adopted. |
| Production Wings lifecycle, both wings, harvest, hooks, and the audit PoC | required for a production exploit claim | not examined | No Forge run. The closed rows are not that trace. |
| `getRate` as a one-share withdrawal preview | optional distinction, forbidden as an implementation | examined as a source observation | Current `getRate` is the whole-book quote over supply. Not changed. |
| Prior council report | optional context | partially examined | Used to frame the question. Its frozen draft was not edited and its numbers are not this run's evidence unless re-executed here. |

## Disagreement and missing responses

- Disagreement: executed-price sign when the vault is the LP; whether the proportional rule eliminates the extraction channel or only the acceptance-time conversion; where the executed-price boundary sits; whether a slice sale leaves other holders' token principal unchanged.
- Dissent carried into this report: MiniMax's negative LP-share rows; Kimi's stronger rule-4 claim and `alpha = omega` boundary; Astra's rejection of a post-sale token-principal invariant. The coordinator does not average these.
- Missing responses treated as approval: no
- Feedback used as a missing initial response: no

## Advisory review

- Draft ID: draft-v4-swap-capture-evidence-20261026-01a177b3-r1
- Draft path: coordinator/draft.md
- Resolution path: coordinator/resolution.md
- Feedback dispositions: astra requested-changes; grok requested-changes; minimax support-with-reservations; kimi support-with-reservations
- Post-review wording changes: the split payout equations, mechanism labels, unit corrections, fee-aware limit, TWAP equations, and the carried dissent
- Those changes are member-approved: no

## Recommendations

- Do not treat a deposit swap plus an exit swap as a fix on the evidence in this run.
- Do not treat the price-free join as implementation authority, or as proof against later trading losses.
- A later question, if one is authorized, is a production trace of the Wings lifecycle. This report does not run it and does not specify a patch.
- Keep repayment route and initial opposing-capital availability as separate questions. A row that repays in kind can still assume a lender or a preexisting opposing wallet.

## Limitations

- No row here is a Forge trace, a PoolManager execution, a both-wings harvest, or a rerun of the audit PoC.
- The compact Astra ledger uses virtual reserves and does not state a nonzero constant reserve offset. A pool whose actual reserves differ by such an offset is a different case.
- Member-reported numbers that this session did not re-execute are labeled that way. They are not coordinator evidence.
- The invoking session was compacted before this final was written. The same owner session continued. Member artifacts were re-read. The draft bytes were not edited.
- Live source can move. Line-level claims are from the tree opened for this session.
- Agreement among the four members that the direct answer is no is not, by itself, the proof. The proof is the closed ledgers and the source read.

## Publication

- Publication state: published
- Final path or chat-only statement: docs/research/v4-swap-capture-evidence-20261026-01a177b3/REPORT.md
- Cooperative update: this run's coordinator files only. The prior evidence run and the other redo run were not edited.
- Unrelated edits preserved: yes
- Model work repeated for publication: no
- Git actions: none
- Artifacts retained until explicit deletion: yes
