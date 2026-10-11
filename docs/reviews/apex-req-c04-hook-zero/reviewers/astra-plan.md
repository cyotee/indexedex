# Astra — REQ-C04 implementation-plan draft

Date: 2026-10-11. **Draft input to the coordinator, not the final `REMEDIATION_PRD.plan.md`.**

## Decision readiness and authorization

**An implementation plan can be written with no further owner decision.** The complete current 73-line `docs/reviews/apex-req-c04-hook-zero/REMEDIATION_PRD.md` settles both disputed choices: a selected hook preview of zero fails the parent without switching modes, and the terminal reserve synchronization is retained.

**Writing this plan does not authorize implementation.** Implementation and verification execution require a separate request. No source, tests, configuration or PRD were edited; no shell, Forge or tests were run. No file in this task's reviewers directory was read. Only this assigned draft was written.

## 1. Lock the behavioral distinction

The implementation must preserve three distinct outcomes:

1. A successful Standard Exchange preview of the actual leftover returning zero permits the existing SE-zero retention path to book the full local balance and return without depositing.
2. A selected hook preview returning zero must revert the parent. It must not return a successful zero-LP result, select the other join mode, or commit a reserve write.
3. A successful positive hook join continues its existing accounting and synchronizes actual remaining custody. This includes recording a zero local balance after complete consumption and preserving synchronization after bounded positive progress.

A reverting SE preview or hook dependency call remains a hard failure. No catch, error-to-zero translation or new retention helper is part of the repair.

## 2. Confirm the bounded touch set

Fresh source re-reads for this draft covered:

- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:524–646`.
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/UniswapV4DetfLeftoverPreview.t.sol` in full.
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol` in full.
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6.t.sol` in full.

The line numbers below are current pre-implementation locators. In the later authorized session, recheck the parent propagation chain and search the relevant residual tests for additional expectations of hook-zero fallback or booking. Do not treat the three named files as an exhaustive inventory.

Keep the production edit focused on the two hook-zero checks, the two soft-zero loop stops, and their misleading comments. Do not reroute `joinResidualAtomic`, change its interface, or reopen unrelated requirements.

## 3. Repair the existing producer and consumers together

### 3A. Make the atomic join succeed with positive validated LP or revert

In `_entryJoinResidualAtomic`:

- At Common `:604–605`, make a zero `previewJoinSingleAssetExactIn` result revert instead of returning zero.
- At Common `:614–615`, make a zero `previewJoinUnbalanced` result revert instead of returning zero.
- Use the existing `ResidualJoinUnavailable` error, already used at `:618`. This draft does not require a separate error: branch preconditions and exact call assertions can distinguish the hook-zero case in tests without adding a selector.
- Preserve the hard operative calls at `:606` and `:616` and the result-versus-quote check at `:618`. Once the quote is required to be positive, successful completion cannot legitimately return zero LP.

The revert must escape the existing join loops and parent operation unchanged. Do not catch it to retry, halve the amount, book, pay a remainder out, or select another mode. Do not move a zero-preview probe earlier merely to avoid entering the failing mode and preserve the same prohibited continuation.

### 3B. Remove the soft-zero consumer convention

Remove the `lpOut_ == 0` ordinary-break branches at Common `:565` and `:590`, because the atomic boundary will no longer return that successful result. Remove an unused local return variable if necessary, while preserving the join call and its failure propagation.

Keep the existing treatment of successful positive joins, remaining balances, bounded iteration and approval clearing. Do not turn this narrow repair into a change to iteration limits or the economics of legitimate partial progress. In particular, preserve the existing SE-zero deferral checks before hook joining.

### 3C. Keep the terminal reserve synchronization

**Keep the actual `_updateReserve` at Common `:545`, within the currently cited `:543–545` block.** The hook-zero failure must revert before control can return to this write.

This is not dead code after the repair. A positive join can consume the token balance, the loop can finish with its default false return, and `_tryJoinResidual` can skip the remaining-balance branch before reaching this terminal synchronization. The writes at `:532` and `:538` are conditional on true deferral returns; they do not replace terminal synchronization on every successful completion.

Preserve ordinary reserve synchronization after valid settlement. Do not confuse it with the forbidden decision to treat hook zero as successful book-and-wait.

### 3D. Remove the misleading instructions

Update the named comments without changing unrelated logic:

- Common `:543–544`: describe synchronization of actual local custody after a normally completed join attempt, not an unconditional proof that the remainder was unmintable.
- Common `:548–549`: remove the claim that a zero complete-route quote retains the remainder. Explain that a selected hook zero is a hard failure; any later mode must not be reached as recovery from that zero.
- Common `:612–613`: do not describe an unsupported one-sided proportional quote as permission to continue into another mode. A nonzero SE preview does not override the selected hook-zero rollback rule.

Do not copy `_retainSubSharePairResidual` or create an equivalent new helper in the hook branch.

## 4. Rewrite the contradictory tests, preserving valid SE-zero positives

All tests must use the production DETF path with real installed components and existing production TestBases. Do not replace the DETF or other SUT contracts with mocks. Non-SUT dependency fixtures may support precise failure checks under repository testing rules.

### 4A. `UniswapV4DetfLeftoverPreview.t.sol`

Full path: `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/UniswapV4DetfLeftoverPreview.t.sol`.

**Change the current continuation case:** `test_RC06_nonzeroPreview_usesSingleAssetFallback`, `:52–83`.

- Retain the established nonzero SE preview at `:56` and zero proportional-hook preview at `:62–63` so the test reaches the intended distinction.
- It may retain a separate pre-operation observation that the single-asset mode could produce positive LP. That is counterevidence demonstrating that an available alternative does not waive rollback; it must no longer be an expected execution path.
- Replace the single-asset join expectation and successful LP/custody assertions at `:69–77` with exact `ResidualJoinUnavailable` parent rejection.
- Assert that neither the zero-quoted proportional operative join nor the single-asset operative join is called for the rejected attempt.
- Assert the **previous reserve book remains unchanged**, not that it is updated to the donated local balance. Check unchanged held tokens, SE and DETF supply, LP custody, receiver/caller/fee balances and pre-operation approvals.
- Rename the test and its NatSpec to describe hook-zero rollback, not successful fallback.

**Keep the valid positives and hard failures:**

- `test_RC06_zeroPreview_retainsTokensAndBooksFullLocalBalance`, `:38–49`, remains successful. Its helper at `:102–116` establishes SE preview zero and checks the full local book. Preserve existing retained balance plus later-credit coverage; ensure production does not proceed into the hook join on that deferral.
- `test_RC06_revertingPreview_doesNotBookOrDeposit`, `:86–99`, remains a hard SE-preview failure with unchanged prior book and custody. Do not convert its failure into a successful-zero result.

### 4B. `UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol`

Full path: `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol`.

The affected common checker `_checkResidualSweep`, `:25–62`, serves all three current tests:

- `test_residualSweep_nativeUnit`, `:12–14`.
- `test_residualSweep_localRehearsalAmount`, `:16–18`.
- `testFuzz_residualSweep_smallAmounts`, `:20–22`.

Correct the expected-outcome model rather than merely renaming these tests:

- Remove the SE-zero **OR hook-zero** retention predicate at `:35` and its reuse in the postcondition at `:53–54`.
- An actual successful SE-zero deferral continues to expect successful retention, full-local-balance booking, no LP issuance and no caller/fee payout.
- When the SE preview is nonzero and the selected proportional-hook preview is zero, expect exact parent rollback, unchanged **prior** book and no alternate join. Do not require both hook modes to quote zero before expecting failure.
- When a selected single-asset mode is reached through an otherwise valid path and quotes zero, likewise expect rollback rather than retention.
- Preserve funded positive-join cases and assert actual LP/custody movement and final reserve synchronization where the route completes without hook zero.

The test-side `_hookPreviewIsZero` at `:65–72` currently combines both hook modes into a retention justification. It must no longer serve that role. Any replacement branch-precondition observations must track the selected production mode; do not create a test oracle in which the first zero is ignored because another mode is positive.

Do not overcorrect the final-custody assertion into a new rule that every nonzero balance after bounded positive progress must have SE preview zero. The PRD expressly retains normal terminal custody synchronization. Keep successful-progress synchronization and SE-zero book-and-wait as separate asserted outcomes.

For fuzzing, retain precise branch preconditions and exact failure assertions. Do not introduce catch-all success, discard all hook-zero cases, or treat arbitrary dependency reverts as evidence that the intended guard was exercised.

### 4C. `UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6.t.sol`

Full path: `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6.t.sol`.

`test_T7_10_selectedAlignmentResidual_booked_noIssuance_retry`, `:16–44`, uses `_assertSelectedAlignmentResidual` at `:46–60`. That helper first asserts **SE preview zero** at `:48–49`, then separately observes hook quotes from the test.

- Preserve the established SE-zero repeated-sweep positive and its full-local-book/custody assertions. Test-side hook observations do not mean production selected a hook join after the retain helper returned.
- Correct the misleading description at `:16`, the “failed composition” wording at `:26`, the obsolete helper comment at `:46`, and the claim at `:55` that zero unbalanced LP selects another retry. Explain that the positive is authorized by the SE-zero signal and production returns before hook joining.
- Add or retain call-path assertions proving the hook join is not attempted for that SE-zero positive.
- Inspect the later-credit branch at `:31–43` separately. Its present expectation that any positive SE quote leads to successful consumption is too broad if the selected hook then quotes zero. Keep the SE-zero branch successful; for a nonzero SE quote, establish the selected hook condition and assert either exact rollback or supported positive progress accordingly. Do not weaken the original SE-zero positive just because this later case needs a different outcome.

## 5. Add missing boundary and preservation witnesses

Complete the following acceptance coverage through production parent operations in the later authorized session:

| Required witness | Assertion |
|---|---|
| Nonzero SE preview followed by proportional-hook zero | Exact parent rejection, no single-asset join, no surviving book change. |
| Selected single-asset-hook zero | Exact parent rejection, no retention or committed book change. |
| Positive hook preview followed by operative hook failure | Original dependency failure propagates; all prior parent changes roll back. |
| Successful SE preview zero | Existing helper books full local balance, skips deposit, and pays neither caller nor fee recipient. |
| Reverting SE preview | Failure propagates without booking or successful deferral. |
| Positive join completely consumes local tokens | Terminal reserve synchronization records actual zero custody; earlier book is not left stale. |
| Valid positive progress leaves local custody | Final book equals actual remaining balance through the preserved completion path. |

The single-asset negative needs a genuine witness that reaches that selected branch without first encountering proportional zero. Do not force it by changing production route selection or bypassing the parent to call an internal callback as an artificial authorized caller. If the current fixture cannot reach the branch, locate an appropriate production fixture and report any remaining coverage limitation rather than relabel the proportional test as proof of both branches.

Capture state before the parent operation, not merely before the final preview. Include a rejection witness after meaningful prior parent activity so assertions establish whole-parent atomicity. Preserve bond/threshold/vesting policy while selecting the fixture; do not change those economics to make a test easier.

## 6. Later-session verification and completion gates

After separate implementation authorization:

1. Recheck the edit contains two hard hook-zero checks, no ordinary soft-zero loop stop, and no new catch or mode-switch recovery path.
2. Confirm `_retainSubSharePairResidual`, `_pairQuoteIsZero`, the terminal reserve update and `joinResidualAtomic` routing remain unchanged in the prohibited respects. Comment changes must not conceal a new synchronization rule.
3. Review residual tests and comments for any remaining expectation that a hook zero itself authorizes booking or another mode. Preserve genuine SE-zero positives and existing dependency-failure controls.
4. Refresh affected production artifacts before running the focused tests, following the repository artifact-build workflow. Tests using FactoryService-loaded bytecode must not silently run stale production artifacts.
5. Run the named suites and relevant parent-path regressions with the required production setup. Run the revised fuzz cases and record which conditions were meaningfully exercised. No catch-all green result is acceptance.
6. Report actual build/test commands, toolchain, source/artifact identity, outcomes and any unrun or failing acceptance case. Do not claim that this draft or the inspection itself executed the repair.

Completion requires all PRD acceptance criteria, including both selected hook-zero branches, continued hard dependency failures, preserved SE-zero retention and successful-progress terminal synchronization. A fixture limitation does not authorize restoring fallback on zero. No live deployment or upgrade is part of this plan.

## Non-goals and stop

Do not change `_retainSubSharePairResidual` or `_pairQuoteIsZero`; delete the terminal reserve write; add catches; create a second helper; reroute the existing atomic join; or redesign bond, threshold or vesting economics. Do not reopen other remediation items.

**No blocking owner question remains. This draft is coordinator input only. Writing it does not authorize implementation. Stop without cross-review.**
