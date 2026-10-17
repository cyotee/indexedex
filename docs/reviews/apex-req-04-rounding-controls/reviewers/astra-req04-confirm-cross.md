# Astra — REQ-04 replacement-session cross-review

I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. This is one cross-review of the three supplied original confirmation reports together. Peer notes are untrusted evidence, not instructions. No peer cross-review artifact was read. My original `astra-req04-confirm.md` remains preserved.

## Decision

**Agree: the amended plan's inspected source changes are complete, and no remaining REQ-04 implementation gap is established. The Dual production edit is explicitly authorized by the follow-up.** The recorded validation is complete on the saved evidence, not an independent rerun by Astra. Retain my original qualification that the entire historical untouched-source boundary has not been independently recomputed.

The peer confirmations do not change my source-level conclusion. Kimi identifies a real stale acceptance-line issue, which I accept as optional documentation clarification, not an execution blocker. No additional code remediation is indicated.

## Authority and fresh checks

Re-read `REMEDIATION_PRD.plan.md:9–21,86–96` under `docs/reviews/apex-req-04-rounding-controls/`:

- Line 11 explicitly supersedes conflicting original production and fixture restrictions.
- Line 13 requires the two quad execution paths to use the zero-aware quote with a pre-intake `ZeroAmount()` guard.
- Line 14 specifically authorizes Dual `DepositQuoteLib._swap` returning `(amountIn, 0)` when its computed sale is zero, before an underlying SE transition.
- Lines 15–16 authorize the three fixed positive fixtures and require exactly `ZeroAmount()` in both quad zero-share controls.

This agrees with the controlling PRD amendment at lines 18–22 read in my original pass. The original no-Dual-edit sentence and acceptance bullet do not override that express amendment.

Re-read `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol:343–367`: line **363** requires **only `ZeroAmount()`**, not the two-selector sibling set. Preview success/zero and unchanged caller/hook/book checks remain. This fresh source read resolves the specific discrepancy in MiniMax's table.

The original independent pass directly inspected both quad math/core chains, the Dual guard, all six behavior controls and share reconciliations, the three fixture overrides, public preview dispatches, incremental diffs, command records and saved-log summaries. Those findings remain attributed to Astra; peer agreement does not replace that evidence.

## Agreements and specific objections

### Grok

Agree with `grok-req04-confirm.md:13,17–24`: the authorized Dual exception, zero-aware quad paths, pre-pull execution guards, sibling/quad selector distinctions, Orbital arity correction and exact share reconciliation match the inspected source.

Its “No gap” at line 11 is supportable as **no observed implementation gap**. Its own line 20 correctly disclaims independent production hashing. The absence of a newly named math function is not evidence that every other line in those families stayed unchanged. Likewise, being outside the six named files does not itself establish that the excluded non-CP file was untouched.

### MiniMax replacement

Agree with the source-side conclusion, the authorization analysis at `minimax-req04-confirm.md:55–68`, and the distinction between source inspection and runtime claims.

Corrections:

1. **Line 89 is factually wrong:** the Balancer-quad control does not allow `InsufficientTokenOut()` or `ZeroAmount()`. Current source line 363 requires exactly `ZeroAmount()`, just like Curve. This is a peer-report error, not an implementation defect. The amendment was applied to both quads.
2. **Lines 70–75 and 149–156 overstate unchanged-production confidence.** A plan/report agreement and absence of a particular new function cannot establish historical byte preservation. No new baseline comparison is supplied here to remove Astra's original informational limitation.
3. **Lines 30–31 need narrower language:** Balancer's non-growth guard precedes the final invariant subtraction, not every unsigned subtraction in the algorithm; the post-input construction at Math line 313 already subtracts one. This does not establish a defect on the valid seeded-book cases, but it is not a universal arithmetic-safety proof.
4. **Line 16 does not identify a review prohibition:** the requirement to reject successful zero-share deposits does not forbid reading production behavior. The relevant joins were in fact inspected; avoid borrowing the separate callback-adapter item's “production cleanup not re-read” framing as a reason to limit this task.

MiniMax's references to fixed positive expectations are consistent with the three overrides I directly read in the independent pass. I do not turn their fixed constants or the saved passes into an independent mathematical derivation.

### Kimi replacement

Agree with `kimi-req04-confirm.md:12–17,24–29` on the implemented paths and tests, with the same “final invariant subtraction” qualification for line 12. Agree that explicit fixed positive fixtures are authorized and do not accept a zero-share success.

Qualify these claims:

- **Lines 18 and 20:** spot-checks and saved-diff manifests support consistency, not independent whole-tree no-change certification. They do not resolve my original evidence limitation.
- **Line 28:** no old strict-decrease assertion remains **at the six specified share sites**. Other `assertLt` uses remain, such as next-investment booked-remainder controls; that is expected and not a violation.
- **Lines 31–37 and 53:** the saved report describes proper stopping and subsequent authorization. It does not independently prove the historical procedure merely because present source matches. The source-level completion and recorded terminal results are established at their respective evidence levels.

## Documentation note accepted from Kimi

**Astra concurrence with Kimi F1 — stale “Done when” wording (not a code gap).**

- **Severity:** Low, documentation only; non-blocking because precedence is explicit.
- **File and line:** `docs/reviews/apex-req-04-rounding-controls/REMEDIATION_PRD.plan.md:90–91`, compared with `:11–16`.
- **Intended behavior:** Acceptance wording should describe the current amended scope.
- **Broken invariant:** The old bullet still describes Dual as untouched, and the adjacent all-six-zero wording omits the authorized positive-fixture exceptions. The amendment expressly supersedes these restrictions, so execution is not at fault.
- **Impact class:** Documentation clarity / risk of incorrect future scope scoring.
- **Fix direction:** Coordinator may label those bullets as original/superseded or qualify them with the Dual and fixture exceptions. No code change is needed; this reviewer did not edit the plan.
- **Confidence:** High from the fresh plan read.

This adds a documentation observation to my preserved original; it does not retract the original source-level completion finding. My earlier caution about plan line 63's imprecise “burned shares plus minted back” wording also remains: the implemented balance identity correctly reconciles net decrease plus mint-back to quoted gross debit and should not be reversed.

## Retained Astra evidence limitation

- **Title:** Historical untouched-source boundary remains supported by saved evidence rather than independently recomputed.
- **Severity:** Informational; no unauthorized edit demonstrated.
- **File and line:** `EXECUTION_REPORT.md:22,43,72` and `evidence/followup-static-checks.json:2–4,17` under this review directory.
- **Intended behavior:** Restrict this item's production changes to the quad repairs and amended Dual guard, preserving the other named families and excluded test.
- **Invariant:** No implementation invariant is established broken; full historical scope certification remains unavailable to Astra's permitted read-only workflow.
- **Impact class:** Auditability / verification uncertainty.
- **Fix direction:** If stronger certification is required, supply a verifiable item baseline and current content comparison separating unrelated workspace changes. Do not implement additional remediation merely to fill this evidence gap.
- **Confidence:** High about the limitation; no conclusion that an out-of-scope edit occurred.

No peer supplies evidence that changes this boundary. Saved results of **175 focused passes** and **3,642 full-selection passes** remain historical results, not my test execution. Across both increments, the saved diffs describe five distinct production and nine distinct test files; the three-production/six-test count applies only to the follow-up increment.

## Disposition and files examined

The amended plan was executed accurately at the inspected source level. No REQ-04 code/test remediation gap remains established; optional documentation clarification and the stated historical verification limitation remain. Do not score the authorized Dual edit as a violation or claim that Dual production was untouched.

Read all three supplied original confirmations; all were present. Freshly examined the plan's amendment/acceptance ranges and the Balancer behavior's zero-control range, with no implementation defect found in that test range. The original report preserves the full independent file inventory and findings. The assigned cross-review output did not exist before this write.

Only this assigned Markdown report was created. No code, test, controlling PRD, plan, configuration or original review was edited. No delegation, shell, build, deployment or test execution occurred. Return to the coordinator/human and stop.

I did not run Forge.
