# Remediation PRD

## Question

- Run ID: se-fullspread-plan-execution-20261104
- Question: Does the current repository tree execute every requirement in `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md` completely and accurately?
- Profile: review
- Council kind: full
- Result label: full

Answer: no. The re-read lines miss the plan on the one-token exit error, one-sided remainder accounting, infrastructure code checks, the fixture booked getter, the weighted two-leg setup, and the package and money tests named below. That is not a claim that every other requirement failed, and it is not runtime proof. Full participation is not complete conformance adjudication.

## Authorization and scope

- Authorization source: explicit council directive
- Authorizing task or role: the user asked this invoking session to review the work that executed the named plan and to ensure the full plan was executed accurately
- Required targets: the 48 paths listed in `docs/reviews/se-fullspread-plan-execution-20261104/brief.md`, plus that plan
- Optional context: the family PRD, the blockers file, the plan's research report and draft, and the seven behavior contracts. The PRD rows FS-A01 through FS-A04 and FS-A08 were re-read because the plan names those IDs without restating them
- Inherited permissions: accepted. They are not extra authority and not a sandbox
- Implementation authority: none. This PRD does not authorize edits, reviewed-project tests, installs, deployment, or Git

## Owner lock, 2026-11-06

This lock replaces the 2026-11-05 sizing sentences in this file. Those sentences are not the method. This lock does not authorize implementation.

Scope. A one-sided share mint, and a one-token `donate` or `compound`. Not a bundle deposit. Not a one-token exit.

Rule. Swap 49% of the processed input, then deposit. That fixed fraction is the adaptation of the Weir process. Do not iterate. Do not size an exact output. Do not solve a closed-form root. Do not walk ticks to find a better split. The swap output is consumed by the add. Rounding leaves any remainder in the input token. A user-deposit remainder is refunded. A donate or compound remainder is booked.

Boundary. If the price is not strictly inside the position, including exactly at either boundary, do not swap. The position wants only one token. If the caller provided that token, add it with no swap. A share mint refunds what the add does not take. A donate or compound books that dust and does not refund it. If the caller provided the other token, do not swap it. A share mint refunds it. A donate or compound books it. No new error.

Collapsed candidate. Zero active liquidity is not the boundary case. If the 49% swap cannot be formed, or the following add cannot consume its output, return the input and keep no swap. A share mint refunds that input and mints nothing. A donate or compound books that input and does not refund it. A first deposit that does not add more than 1,000 liquidity still reverts `MinLiquidityNotMet`. That is not a refund.

Exit receipt. The one-token exit minimum, and the returned `amountOut`, are the recipient receipt. That receipt is the swap proceeds, the withdrawn requested-token principal, that holder's requested-token fee portion, and that holder's requested booked claim. It is not the swap proceeds alone and it is not a stale preview. An incomplete exit raises `AmountOutNotMet` and does not burn.

Migration scope. This remediation does not walk the preview-consumer index and does not certify that migration. The family plan still requires it. This pass does not close it.

The other owner answers below remain. None of these locks authorizes implementation.

1. `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, and `universalRouter` are components. Check each for code. A missing or code-empty value reverts `InvalidComponent` with no partial diamond. The owner called these the Uniswap V3 infrastructure and said the vault will not work if they are absent. This closes the F5 split.
2. The weighted two-leg row overrides `setUp`. It calls the weighted test base, then `_initializeWeighted(2)`. Do not delete that override. The older prohibition is withdrawn. The three-leg file remains the `n == 3` override. This closes the F8 split.
3. The one-token exit minimum, and the returned `amountOut`, are the recipient receipt named above: swap proceeds, withdrawn requested-token principal, requested-token fee portion, and requested booked claim. It is not the swap proceeds alone and it is not a stale preview. This closes the F2 basis split. It does not change F1's error.
4. `getRate` and `exchangeRate` are not components of this vault. Do not add or keep an `exchangeRate` test. Do not add a test whose only point is that issuance does not read `exchangeRate`. Rate rows use `IStandardExchangeRateProvider`. FS-A16's `exchangeRate` half is not a remediation requirement. `getRate` stays uninstalled. FS-A01 through FS-A04 remain required.
5. Every supported economic money and maintenance route has a gas test. A sampled route is not coverage. The count of six is withdrawn. The standalone routes are `exchangeIn` one-sided share mint, `exchangeIn` one-token exit, `exchangeIn` pass-through, `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound`. `setOperator` and `setOperatorFor` are appointment calls, not routes in this set. Each section 12 row named by the plan is a supported composed route and has its own composed measurement. The ceilings stay 11,900,000 for a cold standalone body, 12,000,000 for a composed transaction, and 5,000,000 for a preview. The measurement shows whether that route can be included in a mainnet transaction under that ceiling. An oversized route is unresolved, not passed.

## Participation

| Participant | Role | Requested model and reasoning | Actual model and reasoning | Task ID | Fresh or continued | Status | Identity source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Coordinator | invoking session, not a vote | invoking model | xai/grok-4.7, xhigh | not exposed | continued | draft, resolution, and this PRD | process environment |
| astra | council-member | chatgpt-subscription/gpt-6-astra:high | chatgpt-subscription/gpt-6-astra:high, high | st_01a1a7ea | continued for feedback | initial settled; feedback requested-changes | task status |
| grok | council-member | xai/grok-4.7:xhigh | xai/grok-4.7:xhigh, xhigh | st_01a1a7eb | continued for feedback | initial settled; feedback support-with-reservations | task status |
| minimax | council-member | minimax/MiniMax-M3, admitted adaptive thinking | minimax/MiniMax-M3, reasoning not exposed | st_01a1a7ec | continued for feedback | initial settled; feedback support-with-reservations | task status |
| kimi | council-member | kimi-coding/k3.1-pro:high, global route | kimi-coding/k3.1-pro:high, high | st_01a1a7ed | continued for feedback | initial settled; feedback requested-changes | task status |

- Coordinator mode: invoking-agent
- Actual mode equals requested mode: yes
- Missing initial responses: none
- Missing feedback: none

MiniMax adaptive thinking was admitted in the live model override and was not exposed on the status snapshot. MiniMax examined the family interface, the index header and two index rows, the two production assignments the plan names, `ExchangeInAmount.sol`, the local `IStandardExchangeIn` alias, Crane `IStandardExchangeIn` lines 30-89, and `ComposedStableCommonDetfRepo.sol` line 20. ComposedStable bindings at lines 621 and 705 were search hits, not a contiguous read. MiniMax did not examine required targets 2-42 or 44-48. That is not agreement with the other three.

## Findings

### F1. An incomplete one-token exit raises the wrong error

- Location: `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol` lines 164-166; `UniswapV4FullSpreadStandardExchangeVaultExecution.sol` line 65. Re-read after feedback.
- Invariant or requirement: Plan section 9, and FS-A08 at PRD line 561. Swap all unwanted withdrawn principal plus the opposing fee and opposing booked claim, or revert `AmountOutNotMet` and do not burn.
- Impact: If the projected swap does not spend the unwanted amount, the planner sets `plan.failed` and returns. `exchangeIn` maps every `plan.failed` to `MinLiquidityNotMet` before `_run`. The burn is skipped because execution does not continue. The required error is not the one raised. Astra, Grok, and Kimi reported the error mapping. MiniMax did not examine these files.
- Fix direction: Map that exit shortfall to `AmountOutNotMet` and do not burn. Add that assertion to `Money.t.sol`. Advice only.
- Evidence class: source observation
- Dissent on this finding: none among received feedback. The payment claim is F2, not part of this finding.

### F2. A quoted exit pays the planned amount; a proceeds mismatch was not observed

- Location: `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol` line 171; `UniswapV4FullSpreadStandardExchangeVaultExecution.sol` lines 66 and 74-77. Re-read after feedback. Lines 68-73 are the mint and pass-through branches. Lines 74-77 are the else branch, which burns and pays `plan.amountOut`. Kimi's feedback said 74-77 were the mint branch. That does not match this re-read.
- Invariant or requirement: Plan section 9. A one-token exit uses the actual token output. The caller minimum is enforced on that output.
- Impact: When the quote spends the unwanted amount, line 171 sets `amountOut` to the wanted inventory plus `quote.received`. Line 66 compares the minimum with that planned amount before `_run`. Lines 74-77 then burn and pay that same planned amount. The cited lines do not read a post-swap manager delta. A shortfall between the quote and the pool is inference, not an observed result.
- Fix direction: The owner lock dated 2026-11-06 names the basis. The minimum and the returned `amountOut` are the recipient receipt: swap proceeds, withdrawn requested-token principal, requested-token fee portion, and requested booked claim. Do not treat a payout shortfall as already observed. Advice only.
- Evidence class: source observation of the planned amount and the payment. The economic mismatch is inference.
- Dissent on this finding: Kimi asked for a corrected exit citation. The citation above is the coordinator revision. Kimi did not reject the payment point itself.

### F3. A collapsed one-sided candidate can revert instead of leaving the input as remainder

- Location: `UniswapV4FullSpreadStandardExchangeVaultMath.sol` lines 78-82; `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol` lines 114 and 185-199. Re-read before the draft. The planner push of `sized.swapIn` was part of that re-read.
- Invariant or requirement: Plan section 2. The swap output is entirely the other token the add consumes. Rounding leaves any remainder in the original input token. The swap input is not the processed amount the add itself consumes.
- Impact: `sizeOneSided` records the quoted `swapIn` and sets `remainder` to `amount_ - swapIn_ - needIn_`. If liquidity has collapsed to zero, that subtraction uses the last rejected need and can revert. The planner pushes `sized.swapIn` when it is nonzero. A no-add candidate that still carries that swap is not the same as rejecting the candidate and refunding the original input. Opposing-token residue from a selected plan is an inference from this arithmetic, not a traced pool result. Grok reported the collapse revert. Astra reported the unused `sized.swapOut` and the surviving swap input.
- Fix direction: A rejected sizing candidate must not remain a selected swap while the plan promises the entire input back. A selected executable plan must consume the swap output and leave only input-token remainder. Advice only. This is not a new product rule.
- Evidence class: source observation of the arithmetic. The revert on a live deposit was not executed.
- Dissent on this finding: none on the collapse path. The old sizing loop is F4, not this finding.

### F4. The reviewed sizing loop is not the method

- Location: `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol` line 185. Re-read before the draft.
- Invariant or requirement: The 2026-11-06 owner lock supersedes the review-time sizing reading. The required method is 49% of the processed input. Do not iterate. Do not solve a closed-form root. Do not walk ticks to find a better split.
- Impact: At review time, `_size` stopped after a fixed number of iterations and returned the best candidate seen. That loop is not the method. Kimi reported the bound. Grok did not treat it as a contradiction.
- Fix direction: Superseded by the owner lock dated 2026-11-06. Swap 49% of the processed input. Do not restore the iterative loop. Advice only.
- Evidence class: source observation of the loop. The optimality claim is not established.
- Dissent on this finding: Grok does not accept the iterative bound as a settled plan failure.

### F5. Six infrastructure addresses are stored without a code-empty check

- Location: `UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol` lines 70-84. Re-read before the draft.
- Invariant or requirement: Plan section 4. A missing or code-empty component reverts `InvalidComponent` with no partial diamond. The stored bindings include `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, and `universalRouter`.
- Impact: The constructor checks the manager, registry, oracle, factory, WETH, linked libraries, and the facets. It stores those six addresses with no `code.length` check. Astra and Kimi reported this. The coordinator reads "component" as including those stored bindings. That reading is not a quotation Grok accepted.
- Fix direction: The owner lock dated 2026-11-05 covers those six bindings. Reject a missing or code-empty value with `InvalidComponent` before it is stored. Advice only.
- Evidence class: source observation of the constructor. No deployment was run.
- Dissent on this finding: Grok did not report this and does not treat those six addresses as the plan's component reject.

### F6. The fixture adds a booked getter

- Location: `SeMatrix_FullSpreadV4Fixture.sol` lines 108-110. Re-read before the draft.
- Invariant or requirement: Plan section 12. Do not add a booked getter.
- Impact: `seBooked()` returns `token0.balanceOf(seVault)`. That is a booked-named getter, and it reports raw balance rather than the family booked ledger. Astra, Grok, and Kimi reported it.
- Fix direction: Remove the booked getter. Do not add a production booked view to satisfy a parent. Advice only.
- Evidence class: source observation
- Dissent on this finding: none among received feedback

### F7. The fixture declares capacity functions the plan says are not part of it

- Location: `SeMatrix_FullSpreadV4Fixture.sol` lines 105-107. Re-read before the draft. Both functions are empty overrides.
- Invariant or requirement: Plan section 12. `limitCapacity()` and `openCapacity()` are not part of this fixture. Do not add a sleeve capacity gate.
- Impact: The functions are present, so the first sentence is not met by the current text. Their bodies do not add a gate, so the second sentence is not shown to be broken. Whether the parent interface forces the override was not re-read for this final.
- Fix direction: Do not treat the empty bodies as satisfying "not part of this fixture." Do not delete them until the parent requirement is checked. Advice only.
- Evidence class: source observation of the declarations. The parent constraint is unverified.
- Dissent on this finding: Grok treats the empty overrides as not a defect. This finding does not order deletion.

### F8. The weighted two-leg row overrides setUp

- Location: `UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` lines 22 and 44-47. Re-read before the draft.
- Invariant or requirement: Plan section 12. This file does not override `setUp`. The three-leg file is the one that overrides `setUp`.
- Impact: The two-leg contract overrides `setUp`. The comment says an owner instruction supersedes the plan. That comment is not the plan and was not an admitted amendment. Astra, Grok, and Kimi reported this.
- Fix direction: Superseded by the owner lock dated 2026-11-05. Keep the two-leg `setUp` override. Do not delete it to satisfy the older sentence. Advice only. The review record of the override remains.
- Evidence class: source observation
- Dissent on this finding: none among received feedback

### F9. Package.t.sol does not carry FS-A01 through FS-A04

- Location: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Package.t.sol`, re-read in full after feedback. The file is 69 lines. It contains only `test_bootstrapBundleDepositMintsShares`, `test_permitDomainUsesPackageName`, `test_getRateAndAssetAreAbsent`, and `test_directTransferDoesNotMintShares`. The draft's lines 29-78 citation was wrong for this file.
- Invariant or requirement: Plan section 13 assigns FS-A01 through FS-A04, FS-A16, the package cut, and the permit domain to this file. PRD lines 554-557 require the selector cut, a `bindingHash` change, invalid-component and bad-initialization reverts, and a slot distinct from PairToken and Wings. FS-A16 is that issuance does not read `exchangeRate` and that `getRate` is absent.
- Impact: The permit-domain test and the absent `getRate`/`asset` test cover part of the assigned file. They do not show the cut, a `bindingHash` change, an `InvalidComponent` revert, or the slot inequality. FS-A16 is only partly present through the `getRate` absence check. It is not rejected and it is not fully covered.
- Fix direction: Add the missing FS-A01 through FS-A04 assertions. The owner lock dated 2026-11-05 drops the `exchangeRate` half of FS-A16. Do not add that test. Advice only.
- Evidence class: source observation of the whole current file and the PRD rows. Tests were not run.
- Dissent on this finding: none on the missing rows. The locator correction is a coordinator revision.

### F10. Money.t.sol does not name the exit error

- Location: text search of `Money.t.sol` for `AmountOutNotMet`, plus the function list read before the draft. The functions are `test_passThroughSwapsWithoutMinting`, `test_oneSidedPreviewMatchesExecution`, `test_bundleOutPaysBothFaces`, `test_donateEmitsMarkerAndEmptyCompoundEmitsNothing`, `test_sameTokenRevertsInvalidRoute`, `test_deadlinePrecedesDisable`, `test_disabledVaultBlocksDepositAndAllowsExit`, `test_enabledExchangeOutIsAbsent`, and `test_bundleOutMinimumUsesCallerIndex`.
- Invariant or requirement: Plan section 13 assigns the money-route assertions, including the section 9 exit failure, to this file.
- Impact: No function in that file names `AmountOutNotMet`. F1 therefore has no assertion in the file the plan names. This is not a reading of every assertion body.
- Fix direction: Add the F1 regression to this file. Advice only.
- Evidence class: text search and function-name observation. Not a test run.
- Dissent on this finding: none among received feedback

### F11. Standalone money gas and composed gas are not in the assigned files

- Location: text search of `Money.t.sol`, `BufferHookIntegration.t.sol`, and `QuotesAndRate.t.sol` for `gasleft`, `11_900_000`, `11900000`, `12_000_000`, and `5_000_000`.
- Invariant or requirement: Plan sections 2 and 13. A standalone public money or maintenance call passes only if its cold body is at most 11,900,000. A composed hook route passes only if the whole transaction is at most 12,000,000. Previews fit 5,000,000. An oversized route is unresolved, not passed.
- Impact: `QuotesAndRate.t.sol` has `test_previewGasFitsCeiling`. The same search found no gas ceiling in `Money.t.sol` or `BufferHookIntegration.t.sol`. The preview test body was not read line by line, so this PRD does not say the preview measurement follows the cold-call rule.
- Fix direction: The owner lock dated 2026-11-05, as amended when the gas list was named, requires a gas test for each named standalone route and each named composed row. Do not warm a measurement with a preview. Advice only.
- Evidence class: text search. Not a gas measurement.
- Dissent on this finding: none among received feedback

## Unresolved, not adopted and not rejected

These were reported by a member and were not re-read far enough to adopt or reject. Naming them is not a finding that they are defects.

- Astra finding 2: the exit projection does not fully remove the position from the projected pool state. Not re-read for this final.
- Astra finding 3: zero added liquidity bypasses the first-deposit floor check. An earlier read of `Planner._shares` showed an early return when `liquidityAdded` is zero, before the `MIN_SHARES` check. The caller path was not traced to a revert or a success. Unresolved.
- Grok's section 12 identity-bind tests that pass after a recorded rejection, and the single-row partial-consumption assertions. Not re-read. Not withdrawn by Grok.
- Astra finding 24, restated: current evidence may mark a recorded rejection or an unverified address-side case as a compatible passing row. This is a classification concern, not a claim that the coordinator re-read a relabel. Targets 44-48 were not re-read. Not adopted and not rejected.
- Other Astra findings 6-21 and Kimi findings 5, 6, and 8-14, except where F9, F10, or F11 already covers the same point. Not re-read as whole test bodies.
- Share-burn allowance. `Execution.sol` lines 261-263 check the caller's balance only. The plan sentence "balance or allowance" can also be read as excluding parked shares. Not a finding.
- Native credit receipt. `unlockCallback` is not payable. The debt path does call `settle{value:}`. The diamond `receive` path was not opened. Not a finding.
- Repo-wide migration. The re-read sites in the curve claim library at lines 64, 119, 323, and 333, and in `ComposedStableCommonDetfCommon.sol` at lines 183-184, use `(uint256 name,) =`. That binds the first returned word and discards the refund word. It is not an old one-word assignment. It is also not the explicit two-name form `(uint256 amountOut, uint256 amountRefunded)`. The plan sentence that those two files will not compile against the widened return is not borne out by those lines. That is a mismatch between the plan's description and the current text, not proof the sites fail to compile, and not proof section 12 is complete. The other index paths were not walked.
- Index line anchors. Index line 47 lists the curve claim library at line 121. A `previewExchangeIn` was read at line 119. Shifted anchors are a navigation limit of the historical inventory. The plan does not require regenerating that index. Section 12 completion cannot be certified from those anchors or from the unwalked 618-file list.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| Plan | required specification | examined | Read in full before launch. Fingerprint 02060190a9237e07641a62d388e6204c8fce6d09a91af343cc743ed6985e1e57, coordinator-supplied, not recomputed by members |
| Targets 1-42 | required | partially examined | Astra, Grok, and Kimi reported them examined. The coordinator re-read only the lines cited in F1-F8 and the package test file. MiniMax did not examine targets 2-42 |
| Target 43 INDEX.md | required | partially examined | Grok reported the index file examined. Astra, Kimi, and MiniMax read parts of it. No member walked all 618 named files. The coordinator re-read lines 47 and 127 as anchors only |
| Targets 44-48 | required | partially examined | At least one of Astra, Grok, and Kimi reported a partial read. The coordinator did not re-read them. MiniMax did not open them |
| PRD FS-A01-A04 and FS-A08 | optional | examined | Re-read at PRD lines 554-561 for the named test rows |
| Blockers file, research report, research draft, seven behavior contracts | optional | not examined by the coordinator | Member use varied. No requirement was invented from an unread optional file |

## Disagreement and missing responses

- Disagreement: Grok dissents on F4, F5, and F7 as stated in those findings. MiniMax's literal two-name migration reading and index-regeneration demand are not adopted. The exit payment citation Kimi challenged was re-read and kept.
- Dissent carried into this PRD: yes, in F4, F5, F7, and the unresolved list
- Missing responses treated as approval: no
- Feedback used as a missing initial response: no

## Advisory review

- Draft ID: draft-se-fullspread-plan-execution-20261104-r1
- Draft path: docs/reviews/se-fullspread-plan-execution-20261104/coordinator/draft.md
- Resolution path: docs/reviews/se-fullspread-plan-execution-20261104/coordinator/resolution.md
- Feedback dispositions: astra requested-changes; grok support-with-reservations; minimax support-with-reservations; kimi requested-changes
- Concern outcomes: accepted except MiniMax's request to treat stale index anchors as a plan defect, and Kimi's claim that execution lines 74-77 are the mint branch. Both are recorded in the resolution.
- Post-review wording changes: the split exit findings, the package locator, the conditional fee-growth note, the named unresolved items, the migration consequence, and the capacity-function wording
- Those changes are member-approved: no

## Recommendations

- Change the incomplete exit shortfall to `AmountOutNotMet` and assert it. Do not describe a quote-versus-pool shortfall as already observed.
- Make a collapsed one-sided candidate return the input as remainder without keeping a selected swap.
- Check the six infrastructure addresses for code and revert `InvalidComponent` when one is missing or empty. The owner lock closes that split. The current constructor still does not check them.
- Remove `seBooked()`. Do not treat empty capacity overrides as if the plan omitted them.
- Keep the weighted two-leg `setUp` override. The owner lock withdraws the older prohibition.
- Add the missing FS-A01 through FS-A04 assertions. Do not add an `exchangeRate` test. Add a gas measurement for each standalone route named in owner lock item 5, and for each composed row the plan names.
- Do not certify the preview-consumer migration, and do not walk that index in this pass. The family plan still requires it. This remediation does not close it. The re-read sites bind the first return word. The index line numbers are not a live checklist.
- Size a one-sided mint, and a one-token `donate` or `compound`, at 49% of the processed input. Do not iterate. Do not solve a closed-form root. Do not walk ticks to find a better split. If the price is not strictly inside the position, do not swap.

## Limitations

- Static reading only. No forge test, compile, gas measurement, install, deployment, or Git action was run for this review.
- Member examination of a file is not a coordinator re-read of that file.
- This PRD does not claim permission confinement.
- Original responses, feedback, and the reviewed draft bytes are preserved.
- MiniMax adaptive thinking was configured and was not exposed on the call status line.

## Publication

- Publication state: published
- Final path or chat-only statement: docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md
- Cooperative update: none at the original publication. A 2026-11-06 owner lock in this file replaces the earlier sizing sentences. It does not authorize implementation.
- Unrelated edits preserved: yes
- Model work repeated for publication: no
- Git actions: none
- Artifacts retained until explicit deletion: yes
