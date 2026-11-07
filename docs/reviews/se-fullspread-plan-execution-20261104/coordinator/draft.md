# Coordinator draft

## Draft identity

- Draft ID: draft-se-fullspread-plan-execution-20261104-r1
- Path: docs/reviews/se-fullspread-plan-execution-20261104/coordinator/draft.md
- Run ID: se-fullspread-plan-execution-20261104
- Status: pending advisory review. This file is not the final.
- Fingerprint: not computed in this file. The coordinator records the raw-file hash in RUN.md after this text is frozen. Members record that supplied hash as given and do not recompute it.
- Sources: the four initial response files, the plan, and the source lines named below. The coordinator re-read those lines. A member claim whose lines were not re-read is not adopted.

## Participation

- Council kind: full
- Requested members: astra, grok, minimax, kimi
- Substantive initial responses: all four. Astra, Grok, and Kimi examined the production and test targets. MiniMax examined the interface, the index header and two index rows, and the two production assignments the plan names. MiniMax did not examine required targets 2-42 or 44-48.
- Missing initial responses: none
- Result label: full
- Coordinator mode: invoking-agent
- Coordinator is an independent vote: no

MiniMax's narrow coverage is not absence and is not agreement with the other three. A target MiniMax marked not examined is not a vote that the target matches the plan.

## Question

Does the current repository tree execute every requirement in the supplied implementation and test plan completely and accurately?

No. The re-read lines contradict the plan on the exit error, one-sided sizing, infrastructure code checks, the fixture booked getter, the weighted two-leg setup, and several acceptance rows the plan assigns to named test files. That is not a claim that every other requirement failed, and it is not runtime proof.

## Proposed text

### D1. Section 9 — an incomplete one-token exit uses the wrong error and pays the planned amount

- Location: `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol` lines 161-164 and 169; `UniswapV4FullSpreadStandardExchangeVaultExecution.sol` lines 65-66 and 74-77. Re-read by the coordinator.
- Invariant or requirement: Plan section 9. Swap all unwanted withdrawn principal plus the opposing fee and opposing booked claim, or revert `AmountOutNotMet` and do not burn. A one-token exit uses the actual token output. The caller's minimum is enforced on that output.
- Impact: If the projected swap does not spend the entire unwanted amount, the planner sets `plan.failed` and returns. `exchangeIn` maps every `plan.failed` to `MinLiquidityNotMet` before `_run`, so the burn is skipped by the revert, but the required error is not raised. When the quote does spend the unwanted amount, the minimum is compared with `plan.amountOut` before execution, and the exit then burns and pays that planned amount. The swap delta is not read. Astra, Grok, and Kimi reported the error mapping. Grok also reported the planned-amount payment. MiniMax did not examine these files.
- Fix direction: Map an incomplete exit conversion to `AmountOutNotMet`, do not burn, and compare the caller minimum with the token amount execution actually pays. Add that assertion to `Money.t.sol`. Advice only.
- Evidence class: source observation of the control flow. No test was run.

### D2. Sections 2, 9, and 10 — one-sided sizing does not establish the plan's result

- Location: `UniswapV4FullSpreadStandardExchangeVaultMath.sol` lines 56-83; `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol` lines 105-115 and 175-202. Re-read by the coordinator.
- Invariant or requirement: Plan section 2. The result is the greatest liquidity the following add can take. The swap output is entirely the other token that liquidity consumes. The unswapped processed input is what that add consumes. Rounding leaves any remainder in the original input token. The swap input is not the processed-token amount the add itself consumes. There is no step cap and no about-half approximation.
- Impact: Three observed mechanisms, not one repeated vote. The search stops after 96 iterations and returns the best candidate seen, so it does not establish greatest liquidity for every accepted input. `sizeOneSided` records the quoted `swapIn` even when the add consumes less of the quoted output, and the planner pushes that `swapIn`, so opposing-token residue can remain. If candidate liquidity collapses to zero, `remainder` subtracts the last rejected need and can revert instead of leaving the original input as remainder. The search is not a 48% approximation. Astra reported the residue and the unused `sized.swapOut`. Grok reported the collapse revert. Kimi reported the 96-step bound. MiniMax did not examine these files.
- Fix direction: Select a swap and add that consume the swap output, leave only input-token remainder, and terminate on an indivisible feasible optimum rather than a fixed 96-step horizon. A zero-liquidity candidate must return the original input as remainder. Advice only.
- Evidence class: source observation of the arithmetic and the loop bound. Optimality over the full input domain was not executed.

### D3. Section 4 — six infrastructure bindings are stored without a code-empty check

- Location: `UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol` lines 70-84. Re-read by the coordinator.
- Invariant or requirement: Plan section 4. A missing or code-empty component reverts `InvalidComponent` with no partial diamond. The infrastructure bindings include `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, and `universalRouter`.
- Impact: The constructor checks the manager, registry, oracle, factory, WETH, linked libraries, and, through `_append`, the facets. It stores the six infrastructure addresses with no `code.length` check. Astra and Kimi reported this. Grok did not. MiniMax did not examine this file. The coordinator did not re-read the fixture addresses those members said are bare, so that fixture claim is not adopted here.
- Fix direction: Apply the same code-empty rejection to those six bindings before they are stored, and add the FS-A03 negative the plan assigns to `Package.t.sol`. Advice only.
- Evidence class: source observation of the constructor. No deployment was run.

### D4. Section 12 — the fixture adds a booked getter

- Location: `SeMatrix_FullSpreadV4Fixture.sol` lines 108-110. Re-read by the coordinator.
- Invariant or requirement: Plan section 12. Do not add a booked getter.
- Impact: `seBooked()` returns `token0.balanceOf(seVault)`. That is a booked-named getter, and it reports raw balance rather than the family booked ledger. Astra, Grok, and Kimi reported it. MiniMax did not examine the fixture.
- Fix direction: Remove the booked getter. Do not add a production booked view to satisfy the parent. Advice only.
- Evidence class: source observation.

### D5. Section 12 — the weighted two-leg row overrides setUp

- Location: `UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` lines 22 and 44-47. Re-read by the coordinator.
- Invariant or requirement: Plan section 12. This file does not override `setUp`. The three-leg file is the one that overrides `setUp`.
- Impact: The two-leg contract overrides `setUp` and calls the weighted test base, then `_initializeWeighted(2)`. The comment says an owner instruction supersedes the plan. That comment is not the plan and was not an admitted amendment. Astra, Grok, and Kimi reported this. MiniMax did not examine the file.
- Fix direction: Use the inherited behavior setup for the two-leg row, or amend the plan in a later admitted edit. Do not treat the comment as that amendment. Advice only.
- Evidence class: source observation.

### D6. Section 13 — Package.t.sol does not carry the assigned acceptance rows

- Location: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Package.t.sol` lines 29-78, re-read by the coordinator. Plan section 13 assigns FS-A01 through FS-A04, FS-A16, the package cut, and the permit domain to this file. The PRD rows at lines 554-557 were re-read as optional context because the plan names those IDs without restating them.
- Invariant or requirement: FS-A01 requires the selector cut and the absent selectors. FS-A02 requires `bindingHash` to change when a binding changes. FS-A03 requires invalid-component and bad-initialization reverts with no usable vault. FS-A04 requires the family slot to differ from the PairToken and Wings slots.
- Impact: The file has four tests: a bootstrap bundle deposit, a permit-domain name and version check, absent `getRate` and `asset`, and a direct transfer that does not mint. Those cover part of the absent-selector and permit sentences. They do not show the cut, a `bindingHash` change, an `InvalidComponent` revert, or the slot inequality. A text search of this file found no `InvalidComponent`. Astra and Kimi reported a thin package suite. The coordinator adopts only the gap against the four re-read PRD rows, not every package claim those members made.
- Fix direction: Add the missing FS-A01 through FS-A04 assertions to this file. Advice only.
- Evidence class: source observation of the test names and the PRD rows. The tests were not run.

### D7. Section 13 — the one-token exit error is not asserted in Money.t.sol

- Location: `Money.t.sol` function list and a text search for `AmountOutNotMet`, performed by the coordinator. The functions present are `test_passThroughSwapsWithoutMinting`, `test_oneSidedPreviewMatchesExecution`, `test_bundleOutPaysBothFaces`, `test_donateEmitsMarkerAndEmptyCompoundEmitsNothing`, `test_sameTokenRevertsInvalidRoute`, `test_deadlinePrecedesDisable`, `test_disabledVaultBlocksDepositAndAllowsExit`, `test_enabledExchangeOutIsAbsent`, and `test_bundleOutMinimumUsesCallerIndex`.
- Invariant or requirement: Plan section 13 assigns the money-route assertions, including the section 9 exit failure, to `Money.t.sol`. FS-A08, re-read at PRD line 561, requires `AmountOutNotMet` and no burn.
- Impact: No function in that file names `AmountOutNotMet`. The exit failure in D1 therefore has no assertion in the file the plan names. This search is not a reading of every assertion body.
- Fix direction: Add the D1 regression to `Money.t.sol`. Advice only.
- Evidence class: source observation of names and a text search. Not a test run.

### D8. Section 13 — standalone money gas and composed gas are not in the assigned files

- Location: text search of `Money.t.sol`, `BufferHookIntegration.t.sol`, and `QuotesAndRate.t.sol` for `gasleft`, `11_900_000`, `11900000`, `12_000_000`, and `5_000_000`.
- Invariant or requirement: Plan sections 2 and 13. Standalone public money and maintenance calls pass only if the cold call body is at most 11,900,000. A composed hook route passes only if the whole transaction is at most 12,000,000. Previews fit 5,000,000. An oversized route is unresolved, not passed.
- Impact: `QuotesAndRate.t.sol` has `test_previewGasFitsCeiling`. The same search found no gas ceiling in `Money.t.sol` or `BufferHookIntegration.t.sol`. Standalone money gas and composed gas are therefore not present in the files the plan assigns. The preview test was not read line by line, so this draft does not say that preview measurement follows the cold-call rule.
- Fix direction: Add the standalone and composed measurements the plan describes, without warming them with a preview. Advice only.
- Evidence class: text search of the assigned files. Not a gas measurement.

### D9. Section 4 — unpaid fee growth uses checked subtraction

- Location: `UniswapV4FullSpreadStandardExchangeVaultProjection.sol` lines 46-47. Re-read by the coordinator.
- Invariant or requirement: Plan section 4. `reserves()` and `reserveOfToken` are position principal plus unpaid fees owed to the position. They do not add local balances.
- Impact: Unpaid fees are `inside - last` under Solidity 0.8 checked subtraction. Booked balances are not added. Only Grok reported this. Fee-growth values wrap. After wrap, this read reverts instead of returning fees owed. That wrap result is inference from the subtraction, not a runtime observation.
- Fix direction: Use wrapping subtraction for the fee-growth delta. Keep booked balances out of the read. Advice only.
- Evidence class: source observation of the operator. Wrap impact is inference.

## Preserved disagreements

| Topic | Positions | Not resolved in this draft |
| --- | --- | --- |
| Fixture `limitCapacity` and `openCapacity` | Astra and Kimi treat the empty overrides as forbidden fixture surface. Grok treats them as not a sleeve gate, and treats only `seBooked` as the defect. | The plan says those functions are not part of this fixture and also says not to add a sleeve capacity gate. The empty functions exist. This draft adopts only the booked getter. |
| Share-burn allowance | Grok reads plan section 7, "balance or allowance," as requiring an allowance path. The coordinator re-read `Execution.sol` lines 261-263: the check is the caller's balance only. Astra and Kimi did not report this. | The sentence can also be read as excluding parked shares, not as requiring both credit paths. Not adopted as a defect. |
| Native credit receipt | Grok reports `unlockCallback` is not payable and infers that a native credit cannot be wrapped unless an unexamined proxy `receive` accepts it. The coordinator re-read the callback at line 12 and `_settle` at lines 84-103. The debt path does call `settle{value:}`. | The diamond proxy was not opened. The debt-path value send is present. The credit-receipt claim stays unverified. |
| Named migration sites | MiniMax reports twenty sites still bind one named value and that the plan's "will not compile" premise does not match the text. The coordinator re-read claim-lib lines 64, 119, 323, and 333, and `ComposedStableCommonDetfCommon.sol` lines 183-184. Those sites use `(uint256 name,) =`, which keeps the first word and discards the refund word. | This draft does not adopt those re-read sites as unmigrated one-word bindings. It also does not adopt a repo-wide migration verdict. The plan sentence that those two files will not compile does not describe the re-read sites. |
| Index line anchors | MiniMax reports index lines 47 and 127 no longer match current occurrence lines. Index line 47 lists the curve claim lib at line 121. The coordinator read a `previewExchangeIn` at claim-lib line 119. | Stale anchors are a checklist defect for line-by-line use. They are not, by themselves, proof that a named file was not migrated. |

## Evidence gaps

- No forge test, compile, or gas measurement was run. Static reading is not runtime proof.
- MiniMax did not examine required targets 2-42 or 44-48. That is a coverage gap, not agreement.
- The coordinator did not re-read every test body behind Astra's findings 6-21 or Kimi's findings 5-6 and 8-14. Those reports stay in the originals. They are not adopted and they are not rejected.
- Repo-wide migration of the 618 index files was not examined. Astra opened 19 index paths. The other members did not establish the rest.
- Evidence destinations 44-48 were not re-read by the coordinator. Member claims that historical V4 rows were relabeled are not adopted here.
- The diamond proxy `receive` path was not opened.
- The plan fingerprint pinned at admission remains `02060190a9237e07641a62d388e6204c8fce6d09a91af343cc743ed6985e1e57`. Members were told not to recompute it. This draft does not recompute it.

## Coverage adopted from responses

| Target | Status | Adopted from | Conflict or gap |
| --- | --- | --- | --- |
| Specification | examined by Astra, Grok, and Kimi; partially examined by MiniMax | member reports | MiniMax used section 12 and the interface, not the whole plan |
| Targets 1-42 | examined by Astra, Grok, and Kimi | member reports, plus coordinator re-reads named in D1-D6 and D9 | MiniMax: target 1 examined, 2-42 not examined |
| Target 43 INDEX.md | partially examined | Astra, Grok, Kimi, MiniMax | No member walked all 618 rows. Coordinator re-read lines 47 and 127 only as anchors |
| Targets 44-48 evidence files | partially examined by at least one of Astra, Grok, and Kimi | member reports | Coordinator did not re-read them. MiniMax did not open them |
| Optional PRD FS-A01-A04 and FS-A08 | examined by the coordinator for D6 and D7 | coordinator re-read of PRD lines 554-561 | Not a full PRD review |

A member's "examined" status is that member's claim. It is not a coordinator re-read of the whole file unless this draft says the lines were re-read.

## Limits

- Static analysis only. No project test, install, deployment, or Git action was run for this draft.
- This draft does not claim permission confinement.
- Original response files were read and are preserved. This draft does not edit them.
- No project code, configuration, or Git action is authorized by this draft.
- Coordinator changes after advisory review belong in the resolution and the final. They are not member-approved text.
- Findings D1 through D9 are advice. They do not authorize implementation.
