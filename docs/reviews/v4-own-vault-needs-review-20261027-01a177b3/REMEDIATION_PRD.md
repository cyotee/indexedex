# Remediation PRD

## Question

- Run ID: v4-own-vault-needs-review-20261027-01a177b3
- Question: Does the published vault specification, and any implementation it has, meet a fee-exposed reserve, a deposit of either token, a single-token withdrawal, and a one-share single-token quote? Report gaps and failures.
- Profile: review
- Council kind: full
- Result label: full

## Authorization and scope

- Authorization source: explicit council request in this thread
- Authorizing task or role: invoking session 01a177b3-f4ed-7770-9633-b5735573eb05
- Required targets: docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md
- Optional context: docs/research/v4-own-vault-spec-20261027-01a177b3/coordinator/resolution.md, not used as a second target
- Inherited permissions: accepted. They are not extra authority and not a sandbox.
- Implementation authority: none. This PRD does not authorize edits, reviewed-project tests, installs, deployment, or Git.

## Participation

| Participant | Role | Requested model and reasoning | Actual model and reasoning | Task ID | Fresh or continued | Status | Identity source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Coordinator | invoking-agent, not a vote | invoking session | not exposed | none | continued | synthesis written | PI_SESSION_ID |
| astra | council-member | chatgpt-subscription/gpt-6-astra:high | chatgpt-subscription/gpt-6-astra:high, reasoning high | st_01a17d23 | fresh, then continued for feedback | initial and feedback settled | task host |
| grok | council-member | xai/grok-4.7:xhigh | xai/grok-4.7:xhigh, reasoning xhigh | st_01a17d24 | fresh, then continued for feedback | initial and feedback settled | task host |
| minimax | council-member | minimax/MiniMax-M3 | minimax/MiniMax-M3 | st_01a17d25 | fresh, then continued for feedback | initial and feedback settled | task host |
| kimi | council-member | kimi-coding/k3:high | kimi-coding/k3:high, reasoning high | st_01a17d26 | fresh, then continued for feedback | initial and feedback settled | task host |

- Coordinator mode: invoking-agent
- Actual mode equals requested mode: yes
- Missing initial responses: none
- Missing feedback: none

## Findings

No. The specification does not meet the four needs as a set, and no implementation of it was found. Fee exposure, single-token withdrawal, and the one-share quote are specified. Either-token deposit fails. None of the four has been built. Wording that differs from the reviewed draft is a coordinator revision. Members did not review this text.

### Grades

| Need | Specification | Code |
| --- | --- | --- |
| Reserve exposed to trading fees | met | no identified implementation |
| Deposit of either token | failed | no identified implementation |
| Withdrawal into one token | met, with limits | no identified implementation |
| Quote of one share into one token | met for the equation and revert set | no identified implementation |

### Either-token deposit is refused while the tick uses both sides

- Location: `docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md` lines 133-137 and 253. Coordinator re-read. Line 133 says "No vault-initiated swap." Line 135 allows either amount to be zero only when the current tick leaves that side unused, and reverts when `uReceived` is zero. Line 253 says the vault does not swap on entry.
- Invariant or requirement: the vault can accept a deposit of either token.
- Impact: the entry surface does accept a zero amount on either side. A one-sided deposit still reverts whenever the deposited currency is not the side the range is using at the current tick, because that deposit adds no liquidity. While the tick is inside the range, neither token alone succeeds. Out of range, the unused token alone also reverts. The depositor cannot choose either token and have the deposit succeed. Kimi and MiniMax call this partial because of the tick exception. That exception does not meet the need.
- Fix direction: meeting the need requires a separate route that accepts either token, derives a liquidity delta from the deposited amount, adds liquidity, refunds the unused remainder, and still mints with `floor(uReceived * (S + 10^d) / (U_before + 1))`. The repository already has `getLiquidityForAmounts` at `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol` line 56. The coordinator confirmed the function is declared there and did not re-read its body. That route is the zap the specification explicitly rejected. Adding it is a product decision, not a silent repair of a gap the specification forgot. If it is added, the swap changes `uReceived` only. It must not enter the denominator, and it must not be described as closing the prior extraction result. This direction does not authorize the change.
- Evidence class: source observation of the specification lines. The function declaration is a source observation of its location only.
- Dissent on this finding: Kimi and MiniMax grade the need partial. Astra and Grok grade it failed. Failed is adopted.

### No implementation of this specification was identified

- Location: member repository searches, reported in all four initial responses. The coordinator did not repeat the search on this pass.
- Invariant or requirement: all four needs, as operations that can be used.
- Impact: no identified contract, facet, package, or test implements this vault. Wings and DETF surfaces are not this vault and were not reviewed as if they were. Specification grades are not code grades. This does not claim that no deployed product anywhere can deposit, withdraw, or quote.
- Fix direction: none. Implementation was not requested and is not authorized.
- Evidence class: coordinator-supplied from four member searches. Not re-run by the coordinator.
- Dissent on this finding: none among received responses.

### Fee exposure is specified; the liability total is not an on-chain rule

- Location: REPORT.md lines 44 and 90-129, including `claimFees` at line 125 and `liability_i` in the terms table.
- Invariant or requirement: a reserve exposed to trading fees.
- Impact: the position earns trading fees, and holders can claim them in kind. That meets the stated need at specification level. Fees are not inside the share and are not in `getRate`. That separation is disclosed. It is not a failure of this need. Astra, Kimi, and Grok grade the need met. The liability definition sums every holder's claim. The specification does not say how that sum is maintained without visiting every holder. An implementer might substitute `floor(S * feePerShare / Q)`. The specification does not require that substitution. MiniMax's static example says that substitution can exceed the sum of per-account floors. The coordinator did not execute that example. It is not a proved insolvency, and it is not a reason to fail the fee-exposure need.
- Fix direction: a later specification, if authorized, must define how collected tokens, crystallized claims, unsettled claims, and remainder stay consistent at each operation without a holder loop and without treating `floor(S * feePerShare / Q)` as the liability. Storing that aggregate is not the fix. `getRate` already excludes fee escrow. Do not add that sentence again as if it were missing.
- Evidence class: source observation of the specification. The substitution hazard is an inference from MiniMax, not an executed test.
- Dissent on this finding: MiniMax graded the need partial. That grade is not adopted. The accounting gap is carried separately.

### Withdrawal into one token is specified and not built

- Location: REPORT.md section 5, lines 153-155, and the exit sequence.
- Invariant or requirement: a withdrawal into a single token.
- Impact: the specification removes the share's liquidity slice, sells only that slice's opposing principal, and pays the configured target. A short sale reverts the whole call. The last burn can leave residual liquidity. Fee escrow is not part of this payment. Those limits do not erase the specified withdrawal. No implementation of it was identified.
- Fix direction: none beyond the absent implementation. Do not sweep residual liquidity by changing the exit equation unless a later specification says so.
- Evidence class: source observation of the specification.
- Dissent on this finding: none on the specification grade. MiniMax recorded the residual and the price exposure as qualifications, not as a failed grade.

### The one-share quote is specified as an equation, and no preview mechanism is named

- Location: REPORT.md section 7, line 179, and the preview order that follows.
- Invariant or requirement: quote redeeming one vault share into a single token.
- Impact: `getRate` is the normalized preview of redeeming one whole share: removal first, then an exact-in sale of that slice's opposing principal, then `floor(q * 10^18 / 10^dT)`. It writes nothing. It reverts when the sale cannot be quoted, the fill would be incomplete, or the hook can change the amounts. It excludes fee escrow. That is the quote of the share redemption, not of the holder's separate fee claim. The specification does not name a preview mechanism that can do the removal-plus-sale composition without writing state. MiniMax reports that the repository's V4 quoter and StateView do not supply that composition. The coordinator did not re-read those files on this pass. The met grade covers the equation and the revert set. It does not mean a quote can be called today.
- Fix direction: when implementation is authorized, the preview must simulate removal and then the sale without persisting state. Do not treat `getRate` as total holder value.
- Evidence class: source observation of section 7. The tooling gap is a member report, not a coordinator re-read.
- Dissent on this finding: MiniMax grades the need partial because no mechanism is named. The equation grade stays met. The missing mechanism is recorded.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md | required | examined | All four members read it. Coordinator re-read the deposit and quote sentences. |
| Implementation of this specification | required for a code confirmation | absent | Four member searches found none. Coordinator did not repeat the search. |
| Wings and DETF contracts | not a target | not examined as this vault | Named only to exclude them |
| Excluded third-party source | excluded | not examined | Required |

## Disagreement and missing responses

- Disagreement: Kimi and MiniMax grade either-token deposit partial. MiniMax grades fee exposure and the quote partial. Those grades are recorded and not adopted.
- Dissent carried into this PRD: yes, on the deposit grade, the fee grade, and the quote grade.
- Missing responses treated as approval: no
- Feedback used as a missing initial response: no

## Advisory review

- Draft ID: draft-v4-own-vault-needs-review-20261027-01a177b3-r1
- Draft path: coordinator/draft.md
- Resolution path: coordinator/resolution.md
- Feedback dispositions: astra requested-changes; grok requested-changes; minimax support-with-reservations; kimi support-with-reservations
- Post-review wording changes: fee grade returned to met; accounting gap separated from that need; deposit impact restated; zap labeled a product decision; quote grade scoped to the equation
- Those changes are member-approved: no

## Recommendations

- Do not tell a depositor this vault accepts either token. The specification refuses that while the tick uses both sides.
- Do not implement the zap from this review. It is a product decision, and it does not close the extraction result.
- Do not treat `getRate` as the holder's fee value. Fees are a separate in-kind claim.

## Limitations

- The coordinator did not repeat the implementation search and did not re-read V4Quoter or StateView.
- MiniMax's liability counterexample was not executed.
- No project test was run.
- This PRD does not edit the specification.

## Publication

- Publication state: published
- Final path or chat-only statement: docs/reviews/v4-own-vault-needs-review-20261027-01a177b3/REMEDIATION_PRD.md
- Cooperative update: none
- Unrelated edits preserved: not applicable
- Model work repeated for publication: no
- Git actions: none
- Artifacts retained until explicit deletion: yes
