# Astra — REQ-SEP-01 independent confirmation

**Replacement-session original.** I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. This confirmation uses fresh source inspection, not another reviewer's notes. No other reviewer artifact was read.

## Verdict

**The specified helper and all five call-site edits are complete and accurately match the controlling PRD and plan. No implementation defect was found in those edits.** The protected callback assertions are present and still operate on the exercised adapter.

**Full historical execution accuracy remains only partially independently confirmed:** I cannot verify that production files were unchanged during this item, or byte-for-byte preservation of the rest of the test, from the accessible evidence. The execution report claims both and reports a successful whole-file run, but those claims are not independent verification. This limitation does not establish an unauthorized production edit or a failed test.

## Current source checks — facts

Source: `test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol` (read in full).

| Requirement | Current evidence | Result |
|---|---|---|
| Existing `IStandardExchange` import | Line 15 | Present |
| Explicit subject and token helper parameters | Line 108: `_assertNoMaxAllowances(IStandardExchange subject_, IERC20 token_) internal view` | Exact match |
| All five owner expressions use `subject_` | Lines 110, 114, 118, 120, 121 | Exact match; no fixture-owner read remains inside helper |
| Preserve all six assertions | Lines 109–122 | Three not-max checks and three exact-zero checks remain, including the Permit2 packed amount |
| BPT exact-in fixture check | Line 330: `_assertNoMaxAllowances(adapter, bpt)` | Exact match |
| BPT exact-out fixture check | Line 341: `_assertNoMaxAllowances(adapter, bpt)` | Exact match |
| DAI exact-in fixture check | Line 374: `_assertNoMaxAllowances(adapter, dai)` | Exact match |
| DAI exact-out fixture check | Line 388: `_assertNoMaxAllowances(adapter, dai)` | Exact match |
| Callback-success check | Line 520: `_assertNoMaxAllowances(locked_, IERC20(address(probe)))` | Exact match |

A file-scoped search found exactly one helper definition and these five calls, with no `catch` match. The helper does not add nonce or expiry assertions.

The callback test obtains `locked_` at line 495, executes its exchange at line 511, and checks that same instance at line 520. Outer success remains at line 513; callback activity, lock-hit equality and nested-failure checks remain at 514–516; in-flight approval budget checks remain at 517–519; consumed-input equality remains at 521. There is no early return or conditional bypass around the corrected cleanup assertion.

The fixture is initialized separately at line 73. The decimal-pool helper's fixture assignment at 310–314 is not an assignment to the callback's `locked_`. `_deployProbePool` returns its separate instance at 607–616, without retargeting the test's fixture member. The rollback twin at 525–553 still uses `locked_`, checks caller restoration and checks its router allowance. The probe contract remains present at 620–691. These are current-source observations, not a claim of independently established historical byte equality.

**Inference, high confidence:** the original wrong-instance test oracle is repaired. Successful execution of the corrected assertion would now require the exercised instance's two ERC-20 allowances and Permit2 packed amount to be exactly zero. This is not a finding that production previously leaked allowances.

## Execution report — untrusted claims and evidence limits

`EXECUTION_REPORT.md` exists. Lines 20–26 record the exact planned artifact-aware whole-file command without a test-name filter. Lines 28–37 distinguish an initial tooling crash from a later claimed successful run of 20 tests, including both callback tests. Thus the plan's requirement to **record** the command and result is fulfilled as documentation.

I attempted direct reads of the report's cited `/tmp/req-sep-01-before.sol`, `/tmp/req-sep-01-status-before.txt`, and `/tmp/req-sep-01-forge-retry.log`. All three were denied by the tool's access guard. I did not retry through alternate paths or tools. Their contents and continued existence were not established. Even an accessible saved log would not be an independent rerun.

No shell or Git execution was performed or available within this review's allowed workflow. There is no independently inspected before/after production-content comparison. Reading today's production code alone cannot establish that it was not edited for this item, particularly when the report describes a pre-existing dirty worktree. I therefore do **not** certify the report's no-production-edit claim at lines 10, 16 and 45.

## Astra evidence gap (not a code defect)

- **Title:** No-production-edit and unchanged-remainder claims lack independently accessible comparison evidence.
- **Severity:** Informational / verification limitation.
- **File and line:** `docs/reviews/apex-req-sep-01-callback-adapter/EXECUTION_REPORT.md:16,45–47`; acceptance boundary at `REMEDIATION_PRD.plan.md:81`.
- **Intended behavior:** Change only the named helper and five invocations, preserving the rest of the test and making no production-file change for REQ-SEP-01.
- **Broken invariant:** No implementation invariant is demonstrated broken; the evidence needed to independently certify this historical scope invariant is unavailable to this reviewer.
- **Impact class:** Auditability / scope-verification uncertainty, not demonstrated runtime harm.
- **Fix direction:** Supply an authorized, accessible item-specific before/after diff or content comparison tied to the execution baseline, separating pre-existing worktree changes. No code remediation is indicated by this review.
- **Confidence:** High that the limitation exists; no conclusion that production actually changed.

## Files examined without a scoped implementation defect

- `test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol` — full current source; helper, five callers, fixture separation, callback controls, rollback twin and probe inspected.
- `docs/reviews/apex-req-sep-01-callback-adapter/REMEDIATION_PRD.md` — controlling exact edit and preservation requirements.
- `docs/reviews/apex-req-sep-01-callback-adapter/REMEDIATION_PRD.plan.md` — implementation and recorded-validation requirements.
- `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md:110–122` — confirms the item-specific PRD controls.

Also read `CLAUDE.md`, `docs/agent/SKILL_CATALOG.md`, and the relevant canonical Crane/local testing skill guidance. The execution report was examined as a claim, with the evidence limitation above. All supplied in-repository input paths were present. The assigned output did not exist before this write.

Only this assigned Markdown report was created. No code, tests, production files, PRD, plan or configuration were edited. No new implementation work is recommended for the confirmed source changes. Return the evidence limitation to the coordinator/human rather than inventing a defect or claiming a full historical verification.

I did not run Forge.
