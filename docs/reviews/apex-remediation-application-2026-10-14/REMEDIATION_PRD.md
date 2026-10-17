# Remediation PRD — APEX remediation application

- **Status:** DRAFT
- **Round state:** COMPLETED after a labeled Kimi K3 replacement. The earlier stop in this file is historical. The replacement does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`.
- **Date:** 2026-10-14
- **Review target:** Current IndexedEx working tree. Question: whether the remediations defined under `docs/reviews` have been correctly applied.
- **Inputs used:**
  - Human-supplied directory: `docs/reviews/`.
  - Controlling later text, where it withdraws an earlier draft: `docs/reviews/apex-rc01-explicit-holder/REMEDIATION_PRD.md` and `REMEDIATION_PRD.plan.md`; `docs/reviews/apex-req-c03-exact-output-settlement-witness/`; `docs/reviews/apex-req-c04-hook-zero/`; `docs/reviews/apex-req-c05-uniswap-readme/`; `docs/reviews/apex-req-c06-pretransfer-caller-first/`; `docs/reviews/apex-stage2-council-2026-10-07/FIX_PRD.md` and `FIX_PRD.plan.md`.
  - Prior claims, not proof: `docs/reviews/apex-stage2-remediation-confirmation-2026-10-11/REMEDIATION_PRD.md`; `docs/reviews/apex-stage2-council-2026-10-07/REMEDIATION_PRD.md`; `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md`; `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md`.
  - Audit PDF `docs/audits/APEX-IndexedEx-Audit-2026-09-17.pdf` exists and was cited by the September PRDs. It was not named by the human for this round and was not re-audited.
  - Dated notes under `docs/reviews` that are not `REMEDIATION_PRD.md` or `FIX_PRD.md` were not treated as current requirements.
- **Astra participation:** Substantive first pass and substantive cross-review. Session `ses_ec412bcc2ffejKLo7nuoEAqbV0`. The first-pass call timed out after the original was written. Not censored. No resubmission. Cap not used. Cross-review completed on the first continuation.
- **Other reviewers:** Grok `ses_ec4128917ffeeVds3Y2p7xrVjp`. MiniMax M3 `ses_ec41255ceffeVhrySLQe8hwwMC`. Both first-pass calls timed out. Originals were collected by resuming those same sessions. That is continuation, not a replacement. Both cross-reviews completed.
- **Kimi K3:** Labeled replacement, not continuity. New session `ses_ec3d04e91ffeJa0is24e2jZv06`. It does not recall failed session `ses_ec41220c2ffeqs5Eha7fPsd54B`. The replacement first pass timed out and was collected by resuming that new session. The cross-review continued on the new session.
- **Execution evidence:** No Forge, build, or test was run. Source presence is not a passing run. Consensus is not proof.

Writing this PRD does not authorize code, test, configuration, or deployment changes.

## Required outcome

Remediations that the current tree already matches are not reopened. The incomplete applications below are brought into conformance with the controlling later text, or the owner records a scoped amendment before those paths are treated as accepted. A green run was not produced in this round and is not claimed.

## Preserved originals

First passes and cross-reviews are preserved and were not rewritten:

- `docs/reviews/apex-remediation-application-2026-10-14/reviewers/astra-original.md`
- `docs/reviews/apex-remediation-application-2026-10-14/reviewers/astra-cross.md`
- `docs/reviews/apex-remediation-application-2026-10-14/reviewers/grok-original.md`
- `docs/reviews/apex-remediation-application-2026-10-14/reviewers/grok-cross.md`
- `docs/reviews/apex-remediation-application-2026-10-14/reviewers/minimax-original.md`
- `docs/reviews/apex-remediation-application-2026-10-14/reviewers/minimax-cross.md`
- `docs/reviews/apex-remediation-application-2026-10-14/reviewers/kimi-original.md`
- `docs/reviews/apex-remediation-application-2026-10-14/reviewers/kimi-cross.md`

The Kimi files are replacement artifacts. They are not continuity of the failed session.

## Applied, not reopened

These are source observations from the collected reviews. They are not a Forge pass. The coordinator did not reopen them after cross-review.

- Camelot zap-out compares the share amount with `maxAmountIn` before burn. October RC-02.
- `contracts/protocols/dexes/uniswap/v3` is absent. Named launch and DETF callers cited by Grok and re-read by the Kimi replacement construct FullSpread, not the deleted package. October RC-03. The owner is deleting `contracts/protocols/dexes/uniswap/v4`. That deletion is not this RC-03 item, and it is not a reason to keep repairing that package.
- V3 FullSpread rejects an incomplete exact-output quote and checks the post-swap output delta. A distinct settlement-witness test is present. Whether that fixture reaches the settlement comparison at runtime was not executed. October RC-04 / REQ-C03. The input-ceiling error name remains a recorded non-goal.
- Rocket Pool stakes sleeve excess in one decision. October RC-05. The earlier never-combine draft stays withdrawn.
- `_retainSubSharePairResidual` books only after a successful Standard Exchange preview of that leftover returns zero. October RC-06. That helper is not the hook-zero repair.
- V3 FullSpread yield redemption calls the inherited settlement and passes the holder. Ordinary redemption passes the original caller. The shared native SY adapter does not external-call `address(this)` to burn vault-held shares.
- README lines 3 and 56 match the 2026-10-14 reading of REQ-C05: removed legacy V3, and the holder is passed as an argument. Line 38 is a separate September defect below. The sentence that the legacy V4 package remains is withdrawn with that package.
- RC-07, the selector-size script, remains an owner-ignored item. That ignore is not closure of Stage-1 REQ-08.

## REQ-C04 — Closed 2026-10-16 by owner clarification

The owner closed this item as a requirements ruling, not as an executed code change. Do not preview the DETF residual join. Call the hook join with `sharesMin` 0. A hook revert ends the DETF call. Do not add a zero-return revert. The old preview-and-revert plan stays withdrawn and must not be executed. Controlling text: `docs/reviews/apex-req-c04-hook-zero/REMEDIATION_PRD.md`. The historical finding below is not an open repair.

- **Severity:** Medium
- **File and line:** `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:604-616` and `:618`. Comments at `:548-549` and `:612-613`.
- **Owner ruling, 2026-10-15:** Do not preview this join. Call the hook join. Pass `0` as `sharesMin`. If the hook reverts, including a revert from the underlying Standard Exchange deposit, the DETF call reverts. Do not catch it, book from it, or start the other mode after it. Do not add a DETF check that a returned `0` must revert. The 2026-10-11 rule that kept the preview and reverted on a quote of `0` is withdrawn. Controlling text: `docs/reviews/apex-req-c04-hook-zero/REMEDIATION_PRD.md`. Its plan is withdrawn and must not be executed.
- **Intended behavior:** The ruling above. Book-and-wait for a successful Standard Exchange `previewExchangeIn` of `0` stays in `_retainSubSharePairResidual` and is not this repair.
- **Broken requirement or invariant:** `_entryJoinResidualAtomic` previews, returns `0` when that preview is `0`, and never calls the join. The underlying vault cannot revert. The caller can treat that `0` as a stop, try the other mode, and book the local balance.
- **Acceptance criteria:**
  - Neither preview call remains in `_entryJoinResidualAtomic`.
  - `joinSingleAssetExactIn` and `joinUnbalanced` are called with `sharesMin` of `0`.
  - The exact quote match is gone.
  - A hook join revert rolls the DETF call back. The other mode is not called. No reserve update from that call is committed.
  - No new `catch` and no new zero-return revert are added.
  - `_retainSubSharePairResidual` is unchanged.
- **Non-goals:** Do not change `_retainSubSharePairResidual`. Do not delete the terminal reserve update as the repair. Do not change the hook join signature. Do not reroute `joinResidualAtomic`. Do not claim demonstrated loss.

## Withdrawn — `contracts/protocols/dexes/uniswap/v4` is being deleted

Owner ruling, 2026-10-15: that legacy Standard Exchange vault is deprecated. Another agent is deleting the tree. Do not implement a repair, interface swap, flatten, facet split, or size workaround for it. These gaps are removed:

- REQ-V4-01 and REQ-V4-02, including `docs/reviews/apex-req-v4-01-internal-settlement/`.
- REQ-ERC5115, including `docs/reviews/legacy-v4-erc5115-interface/`.
- The flatten redesign, including `docs/reviews/legacy-v4-architecture-redesign-prd-review/`.
- The interface facet split recorded in `docs/reviews/legacy-v4-interface-facet-split/EXECUTION_REPORT.md`. Its remaining size overrun is not an open gap.
- Stage-2 REQ-C01, the legacy V4 `exchangeIn` self-call.
- The legacy V4 half of REQ-H03. The V3 FullSpread half stays below.
- The stored-reserve-minus-deployed credit residual of this package. Deleting the package removes it. Do not preserve the package to keep that residual.
- Every "do not delete legacy V4" sentence in the explicit-holder PRD, the Stage-2 confirmation, and this file.

These are not that vault. REQ-C04 and REQ-C06 are closed. Still open: REQ-04, REQ-SEP-04, REQ-SEP-01, REQ-ADJ-01, and the V3 half of REQ-H03. Wings, hookless, and Pons copies are not this deletion.

## REQ-C06 — Closed 2026-10-16

The 21 measurement-first sites were repaired. Confirmation: `docs/reviews/apex-req-c06-execution-confirmation/REMEDIATION_PRD.md`. This confirmation did not rerun Forge. The saved log is not an independent rerun. EtherFi and Slipstream remain recorded and were not edited. The historical text below is not an open site list.

- **Severity:** Low
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol:94-101` and `:165-169`. The Pons-family file has the same order. V3 mint delegate: `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:102-110`. The V3 quoted exact-output branch at `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:81-84` already checks the caller before measurement.
- **Intended behavior:** REQ-C06. On a pretransfer, the caller is authenticated before the credit is measured. A code-less caller is rejected with `EOAPretransferNotAllowed` even when the pushed credit is also short. The credit check remains and runs after that caller check.
- **Broken requirement or invariant:** The short-credit comparison now sits behind `requirePretransferCaller`. Measurement, and a plan built from that measurement, still run first on the hookless, Pons, and V3 mint branches. That is partial application. It is diagnostic order, not an authorization bypass, and not REQ-C02.
- **Acceptance criteria:**
  - On each prepaid branch that measures credit before authentication, `requirePretransferCaller` runs before `_pretransferCredit` and before a quote or plan that consumes that credit.
  - A code-less caller with short credit still reverts `EOAPretransferNotAllowed`. No tokens move.
  - A contract caller allowed to pretransfer, with short credit, still reverts the credit error. No tokens move.
  - A false-flag path does not receive this caller check merely because the caller has no bytecode.
  - V3 quoted exact-output, which already has the required order, is cited and left alone.
- **Non-goals:** Do not remove the credit check. Do not treat an input-ceiling comparison that the controlling examples already place before the caller check as this defect. Do not restore Slipstream.

## REQ-SEP-04 — Owner ruling, 2026-10-16: use only what the requested output needs, then refund

- **Severity:** Low as a README contradiction. The owner ruling below also withdraws the old accounting rule. A later PRD must name the code sites before any edit. This section does not authorize that edit.
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/README.md:32` and `:38`.
- **Owner ruling:** The refund is only the unused part of the quantity this caller declared. Undeclared unbooked tokens are not refunded. A non-atomic pretransfer is the sender's responsibility. Controlling text: `docs/reviews/apex-req-sep-04-amount-out-refund/REMEDIATION_PRD.md`.
- **Broken requirement or invariant:** The README still says a call reverts unless the declaration equals the whole surplus, and it does not state the declared-bound refund.
- **Acceptance criteria:** The dedicated PRD's replacement sentences are the wording. Vault paths that already cap the refund at the declaration are not changed to refund all unbooked value.
- **Non-goals:** Do not recreate the deleted V3 package. Do not implement the accounting change in this review session. Do not treat the old "do not change executable credit code" sentence as still controlling.

## REQ-SEP-01 — Closed 2026-10-16

The callback test now checks `locked_`. Confirmation: `docs/reviews/apex-req-sep-01-execution-confirmation/REMEDIATION_PRD.md`. This confirmation did not rerun Forge. The historical text below is not an open repair.

- **Severity:** Medium. This is a required-test gap. The production lock and approval cleanup were not re-read in this confirmation and are not claimed defective.
- **File and line:** `test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol:493-520`. Helper at `:108-122` reads `address(adapter)`. The exercised instance is `locked_` at `:495` and `:511`.
- **Intended behavior:** September council RC-01. A successful callback-capable operation on the exercised production adapter leaves that adapter's router and Permit2 allowances at zero.
- **Broken requirement or invariant:** The test operates on `locked_` and then asserts allowances of the separate fixture `adapter`. A passing cleanup assertion does not establish cleanup on the instance under test.
- **Acceptance criteria:**
  - The zero-allowance assertions name the adapter that executed the callback route.
  - Router and Permit2 allowances for that instance are zero after success.
  - The nested-entry lock assertion remains.
- **Non-goals:** Do not treat this test-oracle gap as a demonstrated production allowance leak. Do not add a `catch` to clear allowances.

## REQ-04 — Closed 2026-10-16

If the amount out rounds to zero, the preview returns 0 and the execution reverts. Confirmation: `docs/reviews/apex-req-04-execution-confirmation/REMEDIATION_PRD.md`. This confirmation did not rerun Forge. The historical text below is not an open repair.

- **Severity:** Medium
- **File and line:** Weighted control at `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol:216-225` and the share assertion at `:282`. The same preview-echo acceptance is at dual `:321-322`, single-CP `:286-287`, orbital `:308-309`, Balancer-quad `:338-339`, and curve-quad `:286-287`.
- **Intended behavior:** Stage-1 REQ-04. A rounding control expects the family's exact rounding error, or a measured successful zero-output and retained book, including the branch precondition. Share movement is exact, not merely a strict decrease.
- **Broken requirement or invariant:** On preview failure, weighted expects that preview's revert bytes. The five named siblings accept an execution selector that matches a failed preview, in addition to named selectors. Weighted's exact-output assertion checks only that SE shares decreased. Removing a broad `catch` does not make this applied. The single non-CP file was not shown by search to use `previewMatch` in that control and is not included.
- **Acceptance criteria:**
  - Each named behavior expects the family's exact rounding result, or a measured zero-output and retained book, without taking the expected failure from an arbitrary failed preview.
  - The weighted exact-output assertion reconciles the SE debit with the shares required for that output.
  - Sibling share assertions are checked the same way where they still use a strict decrease for this control. A file that already reconciles the exact debit is cited and left alone.
- **Non-goals:** Do not delete funded swap, refund, or code-less-caller controls that already assert exact deltas. Do not mark a row compatible on the strength of a preview echo.

## REQ-H03 — Closed 2026-10-17

A short burn reverts `ERC20InsufficientBalance`. The three named tests expect that error. The Crane pointer stopped at gate 3 and was not delivered. Confirmation: `docs/reviews/apex-req-h03-execution-confirmation/REMEDIATION_PRD.md`. This confirmation did not rerun Forge. The historical text below is not an open repair.

- **Severity:** Low. This does not reopen REQ-C02. The code-less ordinary-success assertion is present. Grok's dissent on that point is accepted.
- **File and line:** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol:147`. The legacy V4 twin is withdrawn with that package.
- **Intended behavior:** The holder plan requires an insufficient holder balance to revert with balances unchanged. The production-first negative rule requires the test to identify that condition, not any revert.
- **Broken requirement or invariant:** The V3 test uses bare `vm.expectRevert()`. An unrelated quote, pool, or route failure can satisfy a test named for holder insufficiency. Balance assertions do not identify the cause.
- **Acceptance criteria:**
  - The V3 test expects the holder-balance error for that route.
  - Holder, vault, and recipient balances are unchanged.
  - The code-less ordinary-success tests remain, and a contract caller is not substituted for them.
- **Non-goals:** Do not weaken the production burn to make a broad revert acceptable. Do not treat this gap as evidence that the current holder argument is wrong.

## REQ-ADJ-01 — Closed 2026-10-17

The redeem comment names an explicit holder and says this function does not call `address(this)`. The exemption remains. Confirmation: `docs/reviews/apex-req-adj-01-execution-confirmation/REMEDIATION_PRD.md`. The prescribed execution report is missing. This confirmation did not rerun Forge and did not compute a whole-tree diff. The historical text below is not an open repair.

- **Severity:** Low. Adjacent to the RC-01 comment rule. Not a new money-path defect.
- **File and line:** `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol:44` and the exemption at `:57-58`.
- **Intended behavior:** Comments must not tell a later agent that internal-balance redemption is a vault self-call. The inspected function already chooses an explicit holder and does not call `address(this)`.
- **Broken requirement or invariant:** The NatSpec says the vault's own self-call path is unaffected. The caller check is skipped when `msg.sender == address(this)`. No production self-call into this function was established.
- **Acceptance criteria:**
  - The comment describes explicit-holder redemption, not a current self-call path.
  - No self-call is added to make the old sentence true.
- **Non-goals:** Do not delete the `msg.sender == address(this)` exemption in this item. Reachability of that exemption was not established. Do not redesign custody SY.

## Closed after this draft

- **REQ-C04:** Closed 2026-10-16 by owner clarification. The residual join must call the hook join with `sharesMin` 0 and must not preview first. A hook revert ends the DETF call. No zero-return revert is added. The preview-and-revert plan is withdrawn and was not executed. This close is not a claim that the source was edited or that Forge was run.
- **Stage-1 REQ-02:** Closed 2026-10-14. `previewResidualBuffer` is `internal`, still a direct quote, and the four sweeps still stop on a returned zero. DepositCommon and WithdrawalLib each have a zero-quote witness and a reverting-quote witness. Confirmation: `docs/reviews/apex-req-02-execution-confirmation/REMEDIATION_PRD.md`. This confirmation did not rerun Forge. The saved implementation log is not an independent rerun. REQ-C04 is a different zero and is closed above by owner clarification.
- **REQ-ADJ-01:** Closed 2026-10-17. The redeem comment names the vault or `msg.sender` as the holder and says this function does not call `address(this)`. The exemption remains. The prescribed execution report is missing. Confirmation: `docs/reviews/apex-req-adj-01-execution-confirmation/REMEDIATION_PRD.md`. This application round did not rerun Forge.
- **REQ-H03:** Closed 2026-10-17. A short burn reverts `ERC20InsufficientBalance` before writing storage. The V3, ERC-4626, and Lido expectations use that error. The saved retry records 69 passed, 0 failed. The Crane pointer stopped at gate 3 and was not committed. Confirmation: `docs/reviews/apex-req-h03-execution-confirmation/REMEDIATION_PRD.md`. This application round did not rerun Forge.
- **REQ-04:** Closed 2026-10-16. Zero-rounded output previews return 0 and the deposit execution reverts. Both quad preview paths and the authorized Dual early return are present. The saved logs record 175 focused passes and 3,642 full-suite passes, 0 failed. Confirmation: `docs/reviews/apex-req-04-execution-confirmation/REMEDIATION_PRD.md`. This application round did not rerun Forge.
- **REQ-SEP-01:** Closed 2026-10-16. The helper takes the exercised adapter. Line 520 passes `locked_`. The four fixture calls still pass `adapter`. The saved log records 20 passed, 0 failed. Confirmation: `docs/reviews/apex-req-sep-01-execution-confirmation/REMEDIATION_PRD.md`. This application round did not rerun Forge.
- **REQ-C06:** Closed 2026-10-16. The 21 named measurement-first sites authenticate a true-flag caller before credit measurement. The V3 mint check was moved, not added to a false flag. Four imports were added. The seven named suites contain 86 C06 controls. The preserved log records 176 passed, 0 failed, and a scanner `--check` exit of 1 with 317 existing bare `expectRevert()` sites. This item added none. Confirmation: `docs/reviews/apex-req-c06-execution-confirmation/REMEDIATION_PRD.md`. This application round did not rerun Forge.
- **Stage-1 REQ-03:** Closed 2026-10-15. The observation test lets the outer deposit finish and then checks the surviving nested `IReentrancyLock.IsLocked` record. The rollback test remains. The exact-output success half checks total supply. The scanner `roots` tuple has the seventeen listed directories. The preserved implementation logs record 25 tests passed, 0 failed, and a scanner `--check` exit of 1 with 317 existing bare `expectRevert()` sites. Nine of those sites were already selected; 308 were added by the new roots. That split does not reopen the item. The tests were not rewritten to make the check pass. Record: `docs/reviews/apex-req-03-custody-negatives/EXECUTION_REPORT.md`. Log confirmation: `docs/reviews/apex-req-03-execution-confirmation/REMEDIATION_PRD.md`. This application round did not rerun Forge. The saved log is not an independent rerun.

## Dissent and unverified items

- **REQ-V4-01, REQ-V4-02, REQ-ERC5115, and the flatten:** Withdrawn with the package. The earlier severity dissent is historical and is not an open choice.
- **REQ-C04 label:** Historical. MiniMax's first pass said regressed. Astra and Grok dissented. The owner then closed the item by clarification. That close is not an execution confirmation.
- **REQ-C06:** The cross-reviews accept a Low measurement-order gap. The Kimi replacement does not adopt an inference that the input-ceiling error is the one reached. That inference stays unverified. Forge was not run.
- **REQ-C03 witness:** The test file is distinct from the quote-stage tests. Whether the pool returns a short delta or reverts inside `swap` was not executed. That is an evidence gap, not a confirmed missing witness.
- **REQ-04 siblings:** Search confirmed the six preview-echo sites named above. Exact-share assertions outside the weighted file were not re-read by the coordinator. The Kimi replacement left that sub-claim unverified.
- **Single non-CP matrix file:** Search did not show `previewMatch` in its rounding control. It is not closed and not confirmed defective.
- **Stage-1 REQ-05, REQ-06, and REQ-07:** Still unverified. REQ-02 and REQ-03 are closed above. Reviewers reported source alignment on several of these and disagreed on whether the required tests are complete. The 2026-10-14 application round did not re-read those bodies. No requirement is added for them yet.
- **Stage-1 REQ-08:** Unverified. Ignoring the selector script is not closure.
- **September council RC-02, RC-03, RC-05, RC-06, RC-07, and RC-08:** Unverified. Later V3 deletion and explicit-holder law withdraw only the conflicting sentences, not these unrelated items.
- **Legacy V4 stored-reserve-minus-deployed credit:** Withdrawn with the package. It is not a reason to keep the tree.
- **Kimi replacement:** Does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. Overlap among Astra, Grok, and MiniMax before the replacement is not four-member consensus. The completed cross-review is a four-member round only with that replacement labeled as such.
- No current source hash was computed. No live-instance inventory was made. No test was executed.

## Non-goals for the whole draft

No code, test, config, or deployment changes in this review session. No live-instance upgrade. No restoration of legacy V3. No new `catch`. No EtherFi change. No repair of `scripts/r12_selector_size_compare.py`. No exploit procedure, proof-of-concept, payload, or attack parameter. Owner approval of a later implementation task is a separate decision. Deleting `contracts/protocols/dexes/uniswap/v4` is the owner's separate deletion, not a repair this file reopens.
