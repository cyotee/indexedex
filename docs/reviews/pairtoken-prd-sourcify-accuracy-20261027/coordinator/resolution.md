# Coordinator resolution

## Draft

- Draft ID: draft-pairtoken-prd-sourcify-accuracy-20261027-r1
- Path: docs/reviews/pairtoken-prd-sourcify-accuracy-20261027/coordinator/draft.md
- Raw SHA-256 at advisory send: 8ff51c4b6f4dc7c2f853645858ec3ff3dca777017b98ae35cfe2e033eb215fb4
- Draft bytes changed after review: no

This resolution does not rewrite the pinned draft. Wording changes belong only in the final. They are coordinator revisions, not member-approved text.

## Advisory dispositions

| Member | Disposition | Concerns |
| --- | --- | --- |
| Astra | support-with-reservations | A1 on L6 gas justification; A2 on L7 static-call justification |
| Grok | support | none |
| MiniMax | support-with-reservations | M1 use corrected PRD locators; M2 label the liquidity-call re-read; M3 no change to other members' items |
| Kimi | support | none |

Absence was not treated as approval. No further round was requested or started.

## Concern outcomes

### A1 - adopted

The final removes the claim that the words "value call" already exclude a fixed gas stipend. An empty-calldata value call can carry an explicit gas limit. The failure wrapper does not establish how much gas is forwarded.

A search of the pinned PRD found no sentence containing gas, stipend, or remaining-gas forwarding. PT-BAL-05 line 410 and PT-BAL-06 line 416 say empty-calldata value call and name the failure modes only. No existing normative sentence was identified that already requires unrestricted gas forwarding.

The final still recommends stating that the source payout uses CALL with the gas() argument and the source refund uses Solidity's value call, which forwards the call's remaining gas. It does not promise that the current PRD already requires literally all remaining gas. It describes the source behavior as subject to the gas argument of that CALL. The low classification is qualified: this is an underspecification of call gas, not a demonstrated wrong formula, and it is not established as already cured by another sentence.

### A2 - adopted

The final removes the claim that a dependency's view declaration excuses a non-static caller. Choosing STATICCALL is caller behavior. "The PRD does not require the implementer to drop view" is not the same as a requirement to preserve static execution.

A search of the pinned PRD found view on PairToken's own getters and on the factory interface in PT-DEPENDS-01. It did not find staticcall, and PT-DEPENDS-03 names extsload(bytes32)->bytes32 without view. PT-BAL-01 does not say the balance read is static.

The final still recommends marking those consumed reads as view static calls. The low classification is qualified: no compared view-compliant dependency was shown to return a different value, and no existing PRD sentence was shown to require the static context already. The omission remains a call-context clarification, not a demonstrated accounting mismatch.

### M1 - adopted

Downstream citations use PRD line 145 for the equal-bounds sentence and line 569 for PT-AC-55. Line 549 remains PT-AC-35. The original lines 142 and 549 are not used as corrected locations and are not rewritten in the member file.

### M2 - adopted

LiquidityAmounts.sol lines 25 and 34 are labeled a coordinator re-read of the mulDiv expressions. MiniMax's original citation remains lines 22 and 32. The final does not present 25 and 34 as the member's citation.

### M3 - no change

L1, L4, L5, L6, and L7 stay. MiniMax did not verify them in the advisory pass. The coordinator had re-read the cited lines before pinning the draft. That earlier check is not converted into advisory confirmation.

### Grok and Kimi - no requested change

Support is recorded. It is not approval of the post-review final. Grok's refusal to adopt L1-L4 as independently verified in the advisory pass, and the refusal to adopt the unchecked division-by-zero sentence as Grok's observation, stay visible. That non-adoption is not dissent and is not a reason to drop the items.

## Verdict after resolution

Yes, with only non-material clarifications.

No material defect was demonstrated. L6 and L7 are retained as clarifications whose "already required elsewhere" justification is not adopted. The final says so. It does not elevate them to a required wrong result, and it does not hide the underspecification.
