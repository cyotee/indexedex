# Grok feedback

## Identity

Grok, independent council member. Profile: research. Run `se-fullspread-prd-weir-align-20261031-01a18660`.

This is an advisory review of the frozen draft. It does not authorize implementation. It does not edit the draft, the PRD, the review file, or `response.md`. It does not vote on a preserved split.

## Draft under review

- Draft ID: `se-fullspread-prd-weir-align-20261031-01a18660-r1`
- Path: `docs/research/se-fullspread-prd-weir-align-20261031-01a18660/coordinator/draft.md`
- Raw-file check: `shasum -a 256` returned `c7afa4cd5c82ff0338ebe3cc09ab5aa216280fa17a2c584127b349e73cd10527`
- Expected SHA-256: `c7afa4cd5c82ff0338ebe3cc09ab5aa216280fa17a2c584127b349e73cd10527`
- Result: match. The file was readable. This review is of that file.

Original compared: `docs/research/se-fullspread-prd-weir-align-20261031-01a18660/members/grok/response.md`. Peer files were not read.

## Disposition

The draft does not state the Grok original accurately in full.

The direction matches. Remove PairToken economics inheritance. Close `previewZapCredit`, `maxZapBps`, and `maxZapTickMove` as absent. Do not invent a replacement cap or tick guard. Keep FS-OWN-01 through FS-OWN-10. Keep `donate` as a locked exception and say it is not Weir. State `compound` as Weir harvest-and-reinvest, not a PairToken ratio swap. Do not adopt the treasury cut, and do not adopt the no-fee rule.

The sections below misstate the original or leave a sentence the original required removed. A verbatim copy of every replacement block was not required. These are substance corrections.

## Corrections

### Goal

The draft replaces the first bullet under "What this family is not." The original said to keep that bullet. It is the manager-copy limit, not a PairToken-economics sentence. The proposed text, "not a mechanical wrapper around its internal share ledger," is not the original. Do not attribute that replacement to Grok.

The draft replaces only the two paragraphs that begin "This is not WeirVaults" and "It is a sibling of PairToken." That leaves "Public shares are proportional claims on that basket." The original replaced that sentence because it conflicts with the quoted `_deposit` issuance branch. Leaving it does not state the original.

"A PairToken economic or package choice stays only where one of those locks already keeps it" is broader than the original. The original kept the package facet shape already written in FS-FACET-01 as shape, not as economics authority. That shape is not an FS-OWN lock. Do not use this Goal sentence to delete it.

"Adapts the cited money operations" is a narrower paraphrase than "this vault adapts WeirVaults." That paraphrase is acceptable only with the two corrections above. It is not a separate formula.

### FS-X04

The unused-input sentence states the original: `deposit` returns unused declared input to the payer. `J_i` is not booked. Issuance is not S1-ACC-07. The one-token exit is not this row, and that route pays the selected token or reverts.

The settlement sentence does not. The original did not say `_deposit` settles the swap from the deltas actually returned. `_swap` returns the `BalanceDelta`. `_balance` sets its nets from `s.amount0()` and `s.amount1()`. `_deposit` then settles those nets. A positive credit goes to the depositor, who is the payer. Do not collapse the swap rule into `_deposit`.

### FS-OWN-09 and FS-OWN-10

This section states the original on the points it covers. `donate` stays, Weir has no `donate`, and the direct-transfer sentence is not Weir issuance. `compound()` stays the locked selector. Harvest-and-reinvest is not the ratio swap or the quarter-cap. The treasury cut is not added. The no-fee rule is not adopted. The three zap names are absent. No replacement view, cap, tick bound, or hidden constant is added. Weir's `compound(PoolKey, bytes)` is not added.

Correction: "Keep both locks" must retain the existing lock text the original preserved. That is the mapped bundle routes, the proportional redeem that does not sell one leg to pay the other, paired events, undecided raw ETH, and the FS-OWN-10 sentence that this lock does not publish an internal compound-or-collect branch. Adding the clarifications is not a rewrite of those sentences.

Correction: the `_compound`-before-entry and `_compound`-before-withdrawal ordering is inside the vault's own locked-path action. It does not change FS-A22. Public `compound` on the borrowed path still reverts `ManagerAlreadyUnlocked`. The draft does not say that.

### Authority

"PairToken stage one is not an economics authority" states the original. So does the rejection of "every other clause of that inherited requirement stays," and the refusal to inherit issuance, zap credit, addition remainder, and package zap fields. Hook bindings and owner locks stay except where a sentence asserts a removed rule. That matches.

Correction: do not say `WeirVaults.sol` is the source of the withdrawal rule without the exit limit. The original did not adopt Weir withdrawal as the family exit. `_withdraw` with `zapTo == 0` is consistent with the locked proportional redeem. `zapTo` 1 and 2 are not the accepted one-token exit. That exit remains the route constraint: the selected token or revert. It is not `IncompleteConversion`.

Correction: rejecting the "every other clause stays" sentence does not delete the inherit sentence that begins `Inherit S1-D01 through S1-D05`. The original said to delete that sentence and not replace it with a shorter inherit list. The draft does not say that. Applying only this section leaves S1-OP-02, S1-OP-05, S1-EXIT-01, and the S1-A blanket in force.

Correction: delete the named-override bullet that turns S1-A13 and S1-A15 into `IncompleteConversion` rejections and says their other accounting checks stay. Those other checks are the removed credit rule. The draft does not say to delete that bullet.

The draft has no §2.1 text. Applying the draft as written leaves two sentences the original replaced:

- The Entry remainder row, "Inherited `J_i` booking plus FS-X04 full selected-swap consumption."
- The Supply below `1e18` row, which still reads as a live `InsufficientRateSupply` requirement. The original marked that row withdrawn by FS-OWN-03. That is not a new rate policy.

### FS-MONEY-01

These bullets state the original: unused declared input goes back to `msg.sender`; a positive credit goes to the depositor; the recipient need not be the payer; there is no consumption-equality check; idle is not in the non-genesis denominator; `MIN_SHARES` is `1_000`; the cut is not adopted; `unlockCallback` compounds before deposit and before withdrawal; Weir's `deposit`, `withdraw`, `zap`, and `zapTo` selectors are not installed; no return field is added; unused input and a positive credit are not booked without shares.

The issuance bullets do not state the cited formula. The original quoted `_deposit`. The draft substitutes a shorter formula and drops source terms. That is a formula the source does not state in that form. Replace those two issuance bullets with the quoted branch, including all of the following:

- Liquidity is `getLiquidityForAmounts` of the post-balance amounts after the source's 2-wei input: `frame.a0 > 2 ? frame.a0 - 2 : 0`, and the same for `frame.a1`.
- If `totalShares` is 0 and `frame.liq <= MIN_SHARES`, the source reverts `ZeroShares`. It does not fall through.
- Recipient shares are `frame.liq - MIN_SHARES`. That `MIN_SHARES` amount is not credited to the recipient.
- The branch sets `totalShares` to `MIN_SHARES`, and `_deposit` then adds `frame.shares` to `totalShares`. Do not omit that add.
- Otherwise shares are `(uint256(frame.liq) * v.totalShares) / v.liquidity`. Idle is not read. Do not add an idle denominator, `floor(sqrt(a0 * a1))`, `G_i`, or `qCredit`.

"Reinvests the remainder plus idle" does not state the original once the cut is not adopted. "Remainder" can mean either the source's post-cut amount or a no-cut amount. The original refused both an adopted cut and a written zero-cut rule. State harvest-and-reinvest. `_compound` does not call `_balance` or `_swap` and does not write `totalShares`. The cut is not a requirement. Do not write a rule that the cut is zero.

The draft's "replace the inherited-surface section with these rules" drops two paragraphs the original kept: native ETH, including native-currency pools and actual ETH payout, and the 12,000,000 / 5,000,000 gas ceilings. Those sentences stay.

The draft does not state the entry-swap limit from the original. When an accepted entry swaps, the amount is the amount `_balance` computes, settled from the returned delta. Do not replace that computation with `floor(received / 2)`, a `maxZapBps` test, or a tick bound. `_swap`'s protocol-boundary price limit is the source's call. It is not a new guard. A two-token bundle entry is not given a new swap by this section. There is no collection-only fallback. Do not inherit S1-EXIT-01.

"The ERC-20 representation of the unredeemable `MIN_SHARES` floor is not chosen" matches the original's refusal to pick a holder address, add a second share ledger, or rescale `1_000`. It does not match if it is read as permission to omit the quoted branch. The branch is the adaptation. The representation gap is the absent holder address, not the absent formula.

### Tests and acceptance

"A predicted partial selected entry swap is no longer a revert-before-funds case" states the original. "Do not add a test for a cap or tick guard" states the original. Unused input returned, and no booked `J_i`, state the original.

"Replace rows and bullets that require `IncompleteConversion`, booked `J_i`, `previewZapCredit`, `maxZapBps`, `maxZapTickMove`, or S1-ACC-07" does not reach the rows the original replaced that do not use those names:

- FS-TEST-02's sentence that S1-A01 through S1-A70 apply. The original said those stage-one rows are not inherited obligations. The FS-A rows, as amended, are the acceptance surface.
- FS-A06, which still requires S1-ACC-02 and S1-ACC-03.
- FS-A11, which still requires S1-EXIT-01.
- FS-A25 and FS-A33, which still require S1-ACC-06 fee attribution and a collection-only fallback.
- FS-A05's "No dead-share mint. No performance fee." The original replaced that with the quoted genesis branch, and with no fee assertion and no no-fee assertion.

"The one-token exit row stays" understates the original. Keep the assertion that it pays only the selected token or reverts, and that shares are not burned on revert. Add that this is not `IncompleteConversion` and not Weir `zapTo`.

The draft has no FS-FACET-01, FS-PKG-02, or §6 text. Applying only the written sections leaves these sentences:

- `quoteFacet` still lists `previewZapCredit`.
- `queryFacet` does not say `maxZapBps()` and `maxZapTickMove()` are absent.
- FS-PKG-02 still rejects zap limits with `InvalidZapLimits`.
- FS-PKG-02 still rejects a pool key "outside the inherited domain." That phrase is the path back to the stage-one zap domain. Keep the initialized and nonzero-hook checks.
- FS-PKG-02 still says there is no permanent dead-share mint and no vault-level performance fee.
- The issuance table still names S1-ACC-02, S1-ACC-07, and `previewZapCredit`.
- The `previewExchangeIn` cell still imports maintenance and full unwanted-leg consumption. The exit constraint stays. It is not named `IncompleteConversion`, and it is not S1-EXIT-01.

FS-A01 still needs the three absent selectors named, or the manifest row does not state the close.

## Preserved disagreements

No vote.

### Genesis floor as a new lock

The draft states the original accurately on the position: Grok stated the `_deposit` branch as the adaptation, not as a request for a separate owner lock. "Does not restore the old dead-share ban" also matches.

"The draft states the cited formula" does not match until the FS-MONEY-01 correction above is applied. The paraphrase is not the quote. This is not a vote for or against MiniMax's separate lock, and not a vote on Astra's representation point. The original already refused a holder address, a second ledger, and a rescaled constant.

### Second-currency credit on a one-token route

The draft states the original's substance in FS-MONEY-01: unused input and a positive credit go to the payer, no return field is added, and the credit is not booked without shares. The table cell, "unused input is returned and remainder is not booked," omits the positive-credit half. The body has it.

"Does not define a new encoding" matches the original. The original did not define `amountRefunded` beyond returned to the payer and not booked as `J_i`. This review does not vote on whether that credit must fit one existing refund figure.

## Limits

This feedback does not replace the draft and does not authorize implementation. It does not edit the PRD. It does not resolve either preserved split.

The hash check used `shasum -a 256` on the raw draft file. The read tool was not used as the hash input. No peer file was read. Forge, Git, installs, and deployments were not run.
