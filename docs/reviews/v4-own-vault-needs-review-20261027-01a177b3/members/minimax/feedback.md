# Member feedback

## Identity

- Run ID: v4-own-vault-needs-review-20261027-01a177b3
- Member label: minimax
- Phase: advisory review
- Owned path: docs/reviews/v4-own-vault-needs-review-20261027-01a177b3/members/minimax/feedback.md
- Requested role: council-member
- Actual role, model, reasoning, task ID, and session ID: council-member, minimax/MiniMax-M3, not exposed, st_01a17d25, not exposed
- Fresh or continued: continued
- Initial response path: docs/reviews/v4-own-vault-needs-review-20261027-01a177b3/members/minimax/response.md
- Initial response preserved: yes

## Draft under review

- Draft ID: draft-v4-own-vault-needs-review-20261027-01a177b3-r1
- Path: docs/reviews/v4-own-vault-needs-review-20261027-01a177b3/coordinator/draft.md
- Fingerprint supplied by the coordinator: sha256 b0a2c24b31c1ce1cb88e51306c5074631627f141b4839aacc44c363a36b29447
- Fingerprint independently computed: not computed
- Draft bytes opened: yes — the draft at that path was opened and read in full in this pass, and its own identity lines match the assigned Draft ID and Path. The draft's internal "Fingerprint" line records a different, pre-insertion value and defers review identity to the frozen-file sha256 in RUN.md; that difference is expected and is not treated as a mismatch. No hash command was run and RUN.md was not opened.

## Disposition

- Disposition: support-with-reservations
- This file replaces a missing initial response: no

### Answers to the three questions put to this pass

**Does the failed either-token grade fairly record my partial grade?** Largely yes, with one gap. The draft records my position accurately in two places: Finding 1 ("Kimi and MiniMax call this partial because one side works when the tick already makes the other unused") and the Preserved disagreements table ("Kimi and MiniMax: partial, because one side works when the tick already leaves the other unused"), and it states plainly that the failed grade is the one adopted while the exception is preserved. That is a fair record of the disagreement, and adopting the stricter grade is the coordinator's call, not a misstatement of my view. The gap: my partial rested on two legs and the draft carries only one. The second leg — that the entry path never specifies the conversion from deposited token amounts to a liquidity delta, which Uniswap V4 requires because V4 sizes a position by liquidity delta and derives the token amounts from it (REPORT.md:53, 135) — is absent from the draft, and it is also absent from the draft's own fix direction, which asks for a swap "of the amount required to add liquidity" without saying how that amount is derived. My grade also deserves the narrower reading the draft partly loses: the entry function does accept either token (REPORT.md:135, "Either amount may be zero"), and what the specification refuses is success in the states where the deposited currency is not the range-active side. "The depositor cannot choose either token" compresses that into a refusal the entry surface does not contain.

**Is the fee treatment fair?** The grade is fair and the record is faithful: Finding 3 states both of my reasons (the separate two-currency side claim, and the liability definition summing every holder), states my counterexample's consequence (an implementer who substitutes `floor(S * feePerShare / Q)` can overstate liability, drive remainder negative, and make `claimFees` revert), and preserves the three-member "met" reading as a preserved disagreement. The evidence-gap entry that my counterexample was not executed is honest and I have no objection to it. One reservation is about the fix direction rather than the grade: "store the aggregate unsettled liability" names the very quantity my counterexample shows can exceed the true sum of per-account floors, so an implementer following that sentence literally rebuilds the insolvency the same finding diagnoses. It needs one clause.

**Is the quote treatment fair?** Substantially fair, and my substance is carried into the draft: Finding 4 records that the repository's V4 quoter and StateView do not compose a removal-plus-sale preview and that `getRate` must not write, and its fix direction ("simulate removal first and then the sale, without an unlock that persists state") matches my finding. My one reservation is a precision point: I graded the specification partial because section 7 requires a composed removal-plus-sale preview while stating that `getRate` "writes nothing" and naming no preview mechanism — that is a gap in the written specification, not only in the tooling. The draft characterizes it as "an implementation gap, not a missing equation" and keeps the grade at "met, with limits", which is a defensible reading of a requirements document's role, but the Coverage row and Finding 4 should say which part is met: the equation and the revert set are specified; the mechanism that produces the number is not named by the specification. The draft's own Evidence gaps note that the coordinator did not re-read my V4Quoter and StateView observation on this pass, so that substance currently rests on one member's report.

**Does any finding invent code?** No. Every code-level claim in the draft is a negative claim about what does not exist: that no contract, facet, package, or test implements this specification (Finding 2), and that the repository's existing V4 quoter and StateView cannot compose the preview the quote needs (Finding 4). I verified both in this session: `redeemTarget` and `feePerShare` appear only in this specification run's own documents, no tracked, modified, or untracked Solidity file implements the flow, every V4 contract under contracts/ is a swap hook, a TWAP oracle, or a Standard Exchange/DETF surface, and the V4 lens exposes swap quotes and read-only state with no removal simulation. The remaining text is specification quotation and advice. The draft does not claim any contract, function, or behavior that does not exist, and it correctly names Wings and the DETF surfaces as not this vault rather than reviewing them as one.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| C1 | Finding 3, fix direction: "store the aggregate unsettled liability, or define remainder from escrow minus a stored claim total that settle updates" | The first option names the aggregate that the finding itself shows can overstate liability. `floor(S * feePerShare / Q)` exceeds the sum of the per-account floors, so storing it as the liability can drive `remainder_i` negative and make `claimFees` revert — the exact failure the finding describes. The grade (partial) is right; the prescription risks reproducing the defect. | Keep the grade and the diagnosis, and make the prescription enumeration-free and safe: maintain the crystallized total exactly, treat the difference between the index entitlement and the per-account floors as permanent dust that is never distributed, and enforce solvency per claim rather than through a global equality. State explicitly that the global equality in the specification's invariant 15 is not computable and must be replaced by a per-claim solvency rule. |
| C2 | Finding 1, Impact: "The depositor cannot choose either token" | The entry surface does accept either token (REPORT.md:135, "Either amount may be zero"); what the specification refuses is success when the deposited currency is not the range-active side at the current tick, where `uReceived` is zero and the call reverts. Stated as a refusal, a reader will look for a rejection in the entry function that does not exist. | Restate as: the entry accepts either amount, and a one-sided deposit reverts whenever the deposited currency is not the range-active side, because the position takes the other currency in that state and the deposit yields no liquidity. |
| C3 | Finding 1, fix direction ("swaps only the amount required to add liquidity") and the omitted second leg of my grade | The prescription needs a step the draft never requires and the specification never names: the conversion from deposited token amounts to a liquidity delta, which Uniswap V4 requires because V4 sizes a position by liquidity delta and derives amounts from it (REPORT.md:53, 135). The repository already ships the inversion at lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol, `getLiquidityForAmounts` (line 56). This was the second leg of my partial grade and it is not recorded. | Add the conversion step to the finding: derive the liquidity delta from the deposited amounts, call `modifyLiquidity`, settle, and refund the unused remainder to the depositor, naming the inversion. Carry the specification's own caveat (REPORT.md:141) that a deposit swap plus the exit sale must not be described as closing the swap-capture result, so the fix direction does not read as a design already settled in tension with "It does not authorize a zap". |
| C4 | Coverage table, quote row ("met, with limits"), and Finding 4 | The grade is defensible for the equation and the revert set, but my partial was also a statement about the specification: section 7 requires a composed removal-plus-sale preview, requires `getRate` to write nothing, and names no mechanism, so the need is not implementable as written. The draft currently folds this under "an implementation gap, not a missing equation". | Either mark the quote row as met for the equation with the specification gap noted in the row, or state in Finding 4 that the specification does not name a preview mechanism and that the met grade covers the equation and the revert set only. No grade change is demanded. |

## What was not adopted from others

- Peer responses read: no — the peer positions named in the draft (Astra, Grok, Kimi) were read as the draft's own text and were neither verified against peer files nor adopted as my position.
- Peer feedback read: not read
- Unread members treated as support: no

## Limits

- Advisory only. The coordinator decides acceptance, rejection, or deferral.
- This file grants no implementation authority.
- Inherited parent permissions are not evidence of confinement.
