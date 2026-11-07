# Member feedback — minimax

## Identity

- Member: minimax
- Profile: research
- Phase: advisory review of the coordinator draft
- Requested role: council-member
- Requested model and reasoning: `minimax/MiniMax-M3`, admitted adaptive thinking, not a selectable depth
- Task ID: not exposed
- Write access on this pass: `docs/research/se-fullspread-remediation-plan-20261106/members/minimax/feedback.md` only
- Other runtime identity: not exposed. No other runtime identity is claimed.
- Sub-agents: none launched. No peer response or peer feedback was read.

## Draft under review

- Draft ID: draft-se-fullspread-remediation-plan-20261106-r1
- Draft path: `docs/research/se-fullspread-remediation-plan-20261106/coordinator/draft.md`
- SHA-256: `b2738a3b21c993f0e13153cdf7aefa4e27cd113f318f75c3d0adf54d3de74fba`, coordinator-supplied, recorded here as coordinator-supplied and not recomputed by this member
- My independent contribution of the same run is `members/minimax/response.md`; it is unchanged by this feedback

## Disposition

requested-changes

The draft's structure, its requirement-law coverage, its per-function production table, and its F1 to F11 traceability are correct and usable. The requested changes below are corrections of wording that would otherwise send an implementer to a wrong or an unannounced outcome. None of them reopens a product choice, and none of them asks for a new requirement.

## Concerns

| # | Draft section | Why two readers could diverge | Requested change (advice, not an edit) |
| --- | --- | --- | --- |
| 1 | 10, the row "Removed sizing helpers" in `QuotesAndRate.t.sol` | The row reads "No assertion requires `quadraticInput` or an iterative sizing loop". The current file does not match that text: `UniswapV4FullSpreadQuadraticLock_Test` holds `test_quadraticRootMatchesLockToken0`, `test_quadraticRootMatchesLockToken1`, `test_quadraticIsZeroOutsidePosition`, `test_quadraticIsZeroWhenActiveLiquidityIsZero`, and `test_quadraticCapIsSegmentBoundary`, which require `math.quadraticInput`, `math.boundaryInput`, and `scan.limitingSqrt` through `UniswapV4FullSpreadMathHarness` and `UniswapV4FullSpreadSwapProjectionHarness`, two harness contracts that live in the production tree. Section 10 states that a row which does not match is the defect, so one reader treats the row as a mandate to delete that contract and those two harnesses; another reads it as a prohibition on the production sizing path only and keeps the characterization. The first reader also performs a production-tree deletion that section 4 names nowhere and section 9 does not list as out of scope. | Say in section 10 whether `UniswapV4FullSpreadQuadraticLock_Test` and the two harnesses stay as a characterization of the removed method that is not a sizing acceptance row, or must be removed. If they stay, scope the row to the production sizing path and name them, so the row is not read as a deletion order. If they must be removed, add the corresponding production change to section 4 so the two sections agree. |
| 2 | 7, the sentence "The weighted two-leg `setUp` calls the parent `setUp`, then `_initializeWeighted(2)`" | The current row calls `TestBase_UniswapV4StandardExchangeWeightedBufferHook.setUp()` and then `_initializeWeighted(2)`. The row contract inherits `UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior`, whose `setUp` is a different function, and family plan section 12 requires that a row override `setUp` without calling the behavior `setUp` and instead call that family's TestBase `setUp` by the TestBase contract name. A reader who takes "the parent `setUp`" to mean `super.setUp()` writes a row that runs the inherited behavior setup the family plan forbids. | Name the call the row already makes, the weighted TestBase `setUp` by its contract name, and state that the behavior `setUp` is not called. |
| 3 | 6 and 4, the `Planner._exit` row and the sentence "`minAmountOut` binds that receipt" | Section 4 says the Planner's `amountOut` is the four-part receipt and section 6 says the minimum binds the receipt, without saying which amount the minimum is compared against and when. One reader enforces the minimum in `Execution.exchangeIn` after the swap against the amount actually paid to `recipient`, which is the current behavior; another enforces it before the swap against the Planner's planned four-part receipt. The two differ observably: the second can revert a call whose paid receipt meets the caller's minimum, and it makes the planned quote a gate, which the law forbids when it calls the receipt a stale preview. | State in section 6 that the minimum binds the receipt the recipient is actually paid after the swap, that the Planner's planned amount does not by itself satisfy the minimum, and that no planned-amount check may reject a call whose paid receipt meets it. Name `Execution.exchangeIn` as the place that enforces it. |
| 4 | 10, the acceptance table | The table has no row for the one-token exit preview. FS-OWN-30 in the family PRD states that a one-token exit preview quotes the same recipient receipt, so the quoted `amountOut` matches execution from the same state. Without a row, an implementer can satisfy every row while leaving the preview quoting a planned receipt that differs from the paid receipt once fees have accrued or a balance is booked, and the plan would not require the equality it depends on. | Add a row that the one-token exit preview quotes the same four-part receipt as the execution from the same state, and name the file that holds it. |
| 5 | 8, the measurement paragraph | The paragraph names the routes but not the files: "the money or maintenance file that owns the route", "in that row's file", and "in the quote file". Family plan section 13 assigns the standalone routes to `Money.t.sol`, the preview routes to `QuotesAndRate.t.sol`, and the composed measurement to `BufferHookIntegration.t.sol` and the row files named in section 12. One reader places each composed measurement only in its row file and treats `BufferHookIntegration.t.sol` as superseded; another keeps both, as the tree does today, because the family plan still assigns composed gas there. | Name the file for each measurement group: `Money.t.sol` for the seven standalone routes, `QuotesAndRate.t.sol` for the preview routes, `BufferHookIntegration.t.sol` and the nine section 12 row files for the composed measurements. |
| 6 | 10, the row "Invalid component" | The row names the six addresses but not the two forms the law requires. The requirement law says a missing or code-empty value reverts `InvalidComponent` before it is stored. The current `Package.t.sol` covers the code-empty form for the six addresses only. One reader adds the zero-address form for each address, another keeps the code-empty form only, because the row does not say which forms the assertion covers. | Name both forms in the row, the missing zero-address value and the code-empty value, and state that each reverts before a diamond exists. |

## What the draft states accurately

- All eleven requirement-law bullets are carried. Five appear verbatim in section 3; the other six are compressed, and every clause dropped in the compression is present elsewhere in the draft: "Do not delete that override" in section 7, the measurement coverage in section 8, "The family plan still requires it. This plan does not close it." in section 9, "Keep the empty `limitCapacity` and `openCapacity` overrides if the parent declares them" in section 7, and the unresolved list in section 9. No removed sizing method is restated as an option.
- The first-deposit composition is stated correctly and in both places it matters. Section 4 puts the first-deposit floor in `Planner._shares` and in `Execution.exchangeIn`, and section 5 keeps the collapsed-candidate refund for a share mint whose supply is already nonzero while sending a first deposit that adds at most 1,000 liquidity to `MinLiquidityNotMet` instead of the refund path. That matches the law bullet and family plan section 7.
- The production table names the right functions for the right behavior: `Planner._size` for the single 49% quote and the boundary case, `Planner.planMaintenance` for the one-token maintenance balance, `Planner._exit` for the whole unwanted claim, `Execution.exchangeIn` for the `AmountOutNotMet` mapping and the floor failure, and the package constructor for the six infrastructure addresses. The note that `planBundleIn` does not call `_size` and that `_exit` does not call `_size` is correct.
- Section 9 keeps the preview-index walk and the unresolved list out of scope and states that naming those items is not a finding that they are defects.
- Section 12 keeps the blocker report with the coordinator's decision: stop and report when a named function cannot meet its section 4 row without a new product choice.

## Limits

- This is advisory feedback on the coordinator draft. It does not authorize implementation, tests, installs, deployment, or Git, and it does not replace the draft.
- No forge test, compile, gas measurement, install, deployment, or Git action was run for this feedback.
- The draft's SHA-256 is recorded as coordinator-supplied and was not recomputed.
- The code-file reads behind concerns 1, 2, 5, and 6 are context reads for checking a named row against the current tree. They are not a review of those files and not a re-adjudication of the remediation PRD's findings.
- The draft was not edited, and no file outside the owned feedback path was written.
- Member reading is not a coordinator re-read, and no statement here is runtime proof.
