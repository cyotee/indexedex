# Astra — REQ-02 execution cross-review

**Date:** 2026-10-14 review round. I read all three supplied execution originals in full as untrusted evidence. My original is preserved. I did not read this round's prohibited REMEDIATION_PRD.md, delegate, or edit code.

## Overall disposition

**Agree with Grok and Kimi: the scoped plan is executed in the inspected source and test assertions, with artifact refresh and a passing focused run documented.** Independent replay and current artifact/source identity remain unverified. I retain my original conclusion: no confirmed incomplete or incorrect execution finding.

The original source inspection established the internal direct preview, external buffer operation, retained four helper calls/zero stops, two distinct cases for each installed sweep, documented unreached copies, and no new preview selector. Peer agreement does not add proof to those observations.

I re-read `docs/reviews/apex-req-02-residual-preview-internal/EXECUTION_REPORT.md:54-80` and `evidence/focused-tests.log:37-64`. They document the artifact-helper commands and a later result of 21 passed, zero failed/skipped, including both reverting witnesses. These remain recorded results, not my execution.

## Case 2 checked-arithmetic donation

**Agree with Grok, Kimi's non-defect disposition, and MiniMax's statement that no requirement is broken. Dissent from treating this construction as incorrect execution or requiring a replacement witness.**

Re-read evidence:

- `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview.t.sol:94-121` has separate deposit and withdrawal rejection tests, successful parent-preview preconditions, and rollback checks.
- The same file at `:153-170` prepares state through the existing fixture token and checks the bound SE's actual quote. It does not override a return value, replace code, or fault a harness read.
- Lines `:173-181` expect the exact residual quote and receipt conversion calls, rather than accepting an arbitrary parent failure.
- `contracts/test/stubs/SimpleYieldERC4626.sol:102-105` contains the existing checked conversion arithmetic. The test invokes that behavior rather than adding a throwing dependency.
- Controlling plan `docs/reviews/apex-req-02-residual-preview-internal/REMEDIATION_PRD.plan.md:85-89` permits an existing rejection of the same bound vault and specifically forbids vault mocking, harness `balanceOf` faulting, and throwing-only replacements. It does not restrict the witness to pause/disable errors or exclude arithmetic rejection in the prescribed fixture.

**Fact:** The tested rejection is already implemented by the bound fixture, and the required quote/parent paths have explicit assertions. **Inference:** This is a conforming witness of quote-failure propagation; it is not evidence about every deployed receipt implementation or economically typical balances. No construction parameters or procedure are reproduced here.

The earlier stop/report instruction applies if no permitted state is reached. It does not require stopping after a permitted witness has been found. Kimi's interpretive reservation therefore does not establish an execution defect. Confidence is high on specification/source conformance; runtime confidence is limited to the inspected saved results.

MiniMax's future-arithmetic-change concern is not a current finding. Changing the dependency so the expected rejection disappears should cause these precise revert tests to fail, not silently certify the old behavior. The existing test header at `:22-23` and helper documentation at `:153-155` already identify the dependency on checked arithmetic. No additional documentation work is required by the plan.

## Corrections to MiniMax's completeness objections

1. **Directory mismatch finding F1 — dissent.** The assignment explicitly locates the controlling PRD, plan, and execution records under `apex-req-02-residual-preview-internal/`; `apex-req-02-execution-confirmation/reviewers/` is the review-output destination. The peer originals were successfully read from that destination in this continuation. No requirement places copies of the controlling records there. Even if the destination did not exist at the start of a peer's session, that is not incomplete execution of REQ-02. Do not duplicate, relocate, or symlink the controlling documents to resolve an invented requirement.
2. **Sandbox crash F3 / “partial” run verdict — dissent as a completion defect.** Plan lines 93-97 require artifact refresh and a reported run, not a successful first attempt or a sandbox-specific run. The execution report lines 72-80 discloses the initial crash and later successful invocation; the focused log lines 37-64 records the required suites. The reporting obligation is satisfied. Authenticity, source binding, and independent replay are evidence limitations, not proof that the documented recovery was incomplete. No automatic rerun outside restrictions is recommended by this review.

## Remaining dissent and limits

No new remediation finding is adopted. I disagree with MiniMax's directory/process findings and partial-run label for the reasons above. I see no supplied requirement that makes the arithmetic witness incorrect. Independent Forge replay, artifact identity, and the historical byte-for-byte diff remain unverified; neither agreement nor saved passing logs independently proves broader security.

Only this assigned cross-review report was written. No original findings were rewritten.

I did not run Forge.
