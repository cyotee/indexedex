# Member feedback

## Identity

- Run ID: v3-fullspread-v4-se-parity-20261117
- Member label: minimax
- Phase: advisory review
- Owned path: `docs/research/v3-fullspread-v4-se-parity-20261117/members/minimax/feedback.md`
- Requested role: council-member
- Actual role, model, reasoning, task ID, and session ID: role council-member, as assigned. Actual runtime model and reasoning: not exposed to me as a verifiable runtime fact. Task ID: not exposed. Session ID: not exposed.
- Fresh or continued: continued
- Initial response path: `docs/research/v3-fullspread-v4-se-parity-20261117/members/minimax/response.md`
- Initial response preserved: yes. The initial response file is unchanged; this pass wrote only `members/minimax/feedback.md` and did not overwrite `response.md`.

## Draft under review

- Draft ID: draft-v3-fullspread-v4-se-parity-20261117-r1
- Path: `docs/research/v3-fullspread-v4-se-parity-20261117/coordinator/draft.md`
- Fingerprint supplied by the coordinator: not computed
- Fingerprint independently computed: not computed. The assignment forbids computing one, so no fingerprint was produced and none is offered as proof of identity.
- Draft bytes opened: yes. The file opened at the stated path, and its own identity lines (`Draft ID: draft-v3-fullspread-v4-se-parity-20261117-r1`, `Path: docs/research/v3-fullspread-v4-se-parity-20261117/coordinator/draft.md`, `Fingerprint: not computed`) match the assigned identity.

## Disposition

- Disposition: support-with-reservations
- This file replaces a missing initial response: no

The draft's substance matches my initial response and I support it: the proposed text answers the council question with "the confirmation is not available" and Q2 not confirmed; it keeps Q1 as two conditional verdicts ("plan not accurate" under the wings comparator, "plan partially accurate" under the full-spread comparator) without a coordinator pick, which matches the preserved disagreement; it records the two gaps I reported (the appointment disable gate and the zero-output pass-through) and the third narrower difference (bundle preview failure mode); it correctly declines to adopt my one-liquidity-unit claim as an observed difference and keeps it in the evidence gaps as unverified; and it separates the observation that the current V3 tree follows the plan from the requested confirmation. The reservations below are locator and evidence-completeness defects in the draft's line-level citations, all inside the bullets that carry the full-spread reading. None of them changes a verdict; they are the kind of error that makes the draft's own "the coordinator re-read both sides" claim unverifiable at the cited lines.

Draft content I checked and found correct as written: the plan's own question and authority (plan lines 4-5, 8); the PRD naming the V4 full-spread vault as the behavior source and excluding pair-token and wings (PRD lines 11-13, 31); the plan's fence references to `unlockCallback` and `getRate` (plan lines 32, 33, 36); the floor and first-add rows (plan lines 43, 65); the pass-through row (plan line 95); the appointment choice (plan lines 24, 92); the gas citation (plan line 193); the wings `getRate` and `exchangeOut` rows (`upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.sol:27-31`, `...OutTarget.sol:8-24`); the wings sleeve (`upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultAccounting.sol:41-48`) and the "no permanent sink" sentence and `issue` body at lines 9 and 18-22; the V4 full-spread appointment rows (`v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMoneyTarget.sol:122-131`); the V4 `_pass` rows (`v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:120-130`); the V4 bundle-preview rows (`v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultQuoteTarget.sol:24-36,42-48`); the V4 floor call (`v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultExecution.sol:239`); the V3 floor write (`v3/UniswapV3FullSpreadStandardExchangeVaultRepo.sol:43-48`); the V3 appointment rows (`v3/UniswapV3FullSpreadStandardExchangeVaultMaintenanceTarget.sol:63-73`); and the V3 bundle-query import of the V4 interface (`v3/UniswapV3FullSpreadStandardExchangeVaultBundleQueryTarget.sol:6`).

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| M1 | Proposed text, the "Zero-output pass-through" bullet: "Current V3 sets `failed` when `amountOut` is zero (`v3/UniswapV3FullSpreadStandardExchangeVaultPlanner.sol` lines 281-284)" | The cited range does not contain the asserted behavior. Lines 281-284 are the `_pass` function header, the `kind` assignment, the `zeroForOne` assignment and the `readPosition()` call. The zero-output test is at line 286 and the `plan_.failed = true` assignment is at line 287, both outside the cited range. A reader who checks 281-284 finds no failure flag, so the draft's first half of its decisive bullet is not verifiable at the lines it cites. | Correct the citation to `v3/UniswapV3FullSpreadStandardExchangeVaultPlanner.sol:286-288` (the zero-output branch and the flag), or cite the whole `_pass` function at lines 281-301 as my initial response did. |
| M2 | Proposed text, the same bullet: "then reverts `ExchangeInNotAvailable` (`v3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol` lines 37-38 and 45)" | The cited lines do not contain that revert. Line 37 is `if (plan_.failed) {`, line 38 is the withdrawal branch that reverts `AmountOutNotMet`, and line 45 is `if (plan_.kind == Planner.Kind.OneSidedMint) {`, which reverts nothing. The `ExchangeInNotAvailable` reverts are at line 39 (failed pass-through) and line 50 (the zero-output guard on the pass-through success path). The draft also compresses two distinct reverts into one, which hides that the zero-output pass-through fails on two separate branches. | Correct the citation to `v3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol:39` and `:50`, or cite lines 37-50, and state that both the failed-plan branch and the success-path zero-output guard reject the route. |
| M3 | Proposed text, the same bullet: "A zero-output pass-through that V4 can settle as a refund cannot be executed on the current V3 path" | The V4 side of this comparison is evidenced only from the planner (`Planner.sol` lines 120-130), which shows that V4 records the quote output and the unspent-input refund but does not show that the refund is actually paid or that the route does not revert. The behavioral claim the draft relies on is an execution claim. | Add the V4 execution citation for the refund and the minimum: `v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultExecution.sol:69-71` (the `minAmountOut` revert only when the minimum is greater than zero) and `:78-80` (the pass-through branch pays the output to the recipient and refunds the unspent input to `msg.sender`). |
| M4 | Proposed text, the third-difference paragraph: "Current V3 bundle previews revert (`v3/UniswapV3FullSpreadStandardExchangeVaultBundleQueryTarget.sol` lines 11-12 and 27-33)" | The cited ranges mostly miss the reverts. Line 11 is the closing signature line of the first preview and line 12 its opening brace; the first preview's reverts are at lines 12-13 (`AmountsLengthMismatch`, `ExchangeBundleInForSingleOutNotAvailable`). In the second range, lines 27-33 contain the token reads, the route check and the `ExchangeBundleOutNotAvailable` revert at line 30, but they miss that preview's other two reverts at lines 24-25 (`TokenAmountsLengthMismatch`, `DuplicateOutput`). As written the citation understates where the reverts are. | Correct the citation to `v3/UniswapV3FullSpreadStandardExchangeVaultBundleQueryTarget.sol:12-13` and `:24-25,30`, or cite the two preview functions at lines 9-19 and 21-40. |

## What was not adopted from others

- Peer responses read: no
- Peer feedback read: no
- Unread members treated as support: no

I did not read `members/astra`, `members/grok`, or `members/kimi` on this pass, and I did not read them on the initial pass. The draft's attributions to astra, grok, and kimi (their comparator, their Q1 verdicts, grok's separate observation) are therefore taken as the coordinator's report, not as my verification; unread members are not support. The only peer-derived element I adopt in the concerns above is the draft's own text, which I checked against the sources I read myself.

## Limits

- Advisory only. The coordinator decides acceptance, rejection, or deferral.
- This file grants no implementation authority.
- Inherited parent permissions are not evidence of confinement.
- Static reading only. No Forge build, test, gas measurement, install, deployment, Git operation, or project-code edit was performed or attempted in this pass.
- The concerns above are citation and evidence-completeness defects in the draft. I do not dispute any verdict, wording of the answer to the council question, or preserved disagreement in the draft, and correcting the four items would not change the draft's conclusions.
- The draft's claim that the current V3 sources follow the plan, and its coordinator locator checks over `Repo` 43-48, `MaintenanceTarget` 63-73, `MoneyTarget` 122-131, `Planner` 120-130, `Execution` 239 and `QuoteTarget` 24-48, are outside what I re-verified in this pass; I did not re-read the whole V3 tree for it. My own initial response remains the record of what I examined.
- I did not examine whether the current `v4/fullSpread` tree is the family the owner ruled deleted. The draft does not resolve it either, and I do not treat that open governance question as a defect in the draft.
