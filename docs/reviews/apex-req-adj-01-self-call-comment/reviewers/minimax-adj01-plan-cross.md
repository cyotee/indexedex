# MiniMax M3 — REQ-ADJ-01 plan cross-review (replacement session)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** One defensive cross-review of the REQ-ADJ-01 plan drafts. Close whether the plan includes a Forge command. If I dissent, give one closed alternative. Otherwise say "No Forge command."
- **Method:** Read the three peer plan originals (`astra-adj01-plan.md`, `grok-adj01-plan.md`, `kimi-adj01-plan.md`). Re-read the PRD to confirm whether a build or test is required.
- **Untrusted:** the three peer originals, treated as model content.
- **Forge:** Not run. No code edit. No PRD/plan rewrite.

---

## 1. The question — is a Forge command in the plan?

The coordinator's note: "Kimi's draft adds a forge build. The PRD does not require a build or a test."

| Plan | Forge command? | Wording |
|---|---|---|
| Astra (74 lines) | **No.** | Step 3 is "static acceptance only." "Do not run Forge, builds, tests or deployments for this task. No runtime outcome is claimed." "No Forge run or claim of runtime validation." |
| Grok (49 lines) | **No.** | "Do not run Forge." |
| Kimi (37 lines) | **Yes — `forge build`.** | Step 2 verification: "per the repo rule the implementing session runs the standard `forge build` gate before recording the result (no test run is needed — no test is added or changed, per the PRD). Record the diff and the build result in the execution report." |
| Mine (this session) | **No.** | "No Forge command (no test was added or changed; PRD non-goal does not require a Forge run)." |

The vote is 3-of-4 against including a Forge command. Kimi is the only peer that includes a `forge build`.

---

## 2. The PRD's stance on Forge

I re-read `docs/reviews/apex-req-adj-01-self-call-comment/REMEDIATION_PRD.md` in full. The PRD's acceptance criteria (`:38-41`) and non-goals (`:42`) do not require a build or a test:

- `:38` "Do not change the function signature or body."
- `:39` "Do not add a self-call. Do not delete the exemption at lines 57–58."
- `:40` "Do not edit any other file. Do not add or change a test."
- `:41` "If lines 41–44 or 57–63 no longer match the text read for this PRD, stop and report. Do not choose another sentence."
- `:42` "Do not redesign custody. Do not describe an allowance spend. Do not claim the exemption is reachable. Do not claim it is unreachable."

No acceptance bullet or non-goal requires `forge build` or any other Forge command. The edit is comment-only — the function signature, function body, exemption, and source/owner selection are all preserved verbatim. A `forge build` would compile the contracts but would not validate anything specific to this comment edit, because comments do not affect bytecode generation.

Kimi's Step 2 cites a "repo rule" requiring `forge build` before recording the result. I do not find that rule in the PRD or in `CLAUDE.md`. The PRD's non-goal (`:42`) does not require it. The implementing session can record the diff and the result without a build, because the change is comment-only and a static diff (matching the pre-edit and post-edit NatSpec) is the only verification that matters for this documentation item.

---

## 3. Headline — "No Forge command."

I agree with Astra, Grok, and my own first pass. The plan does not include a Forge command. No closed alternative is needed because I am not dissenting from the convergent answer.

Kimi's `forge build` step is the minority position. The reasons not to include it:

1. **The PRD does not require it.** The PRD's acceptance criteria and non-goals are silent on a build step.
2. **The edit is comment-only.** Comments are stripped or kept as metadata during compilation; they do not affect bytecode generation. A `forge build` would not validate anything specific to this comment edit.
3. **A static diff is the only verification that matters.** The pre-edit NatSpec at lines 41-44 is known; the post-edit NatSpec is the six-line block in the PRD. A byte-for-byte comparison of the two is sufficient. A `forge build` would add 20-40+ minutes of compile time (per `CLAUDE.md` item 8) without validating anything the diff did not already validate.
4. **No test was added or changed.** The PRD non-goal (`:40`) forbids tests in this item. Without a test, there is nothing for `forge test` to validate. Without `forge test`, `forge build` has no Forge-side benefit.
5. **Kimi's "repo rule" citation is not pinned to a source I can verify.** I do not find the rule in the PRD or in the canonical testing guidance I read earlier this session. If the rule exists in a project doc I did not read, it does not change the PRD's silence on this item.

---

## 4. Per-reviewer synthesis

### Astra (`astra-adj01-plan.md`, 74 lines)

- **Headline:** "No blocking question." One comment replacement in one source file.
- **Forge stance:** "Do not run Forge, builds, tests or deployments for this task." Step 3 is "static acceptance only" — the implementer compares the target against its pre-edit copy. "No Forge run or claim of runtime validation."
- **Verification:** Static diff between pre-edit and post-edit NatSpec. No runtime outcome.
- **Completion criteria:** Both pre-edit anchor ranges matched; only the exact NatSpec replacement applied; no tests or other files changed; no Forge run.

### Grok (`grok-adj01-plan.md`, 49 lines)

- **Headline:** "No blocking question." One edit, no implementer choice.
- **Forge stance:** "Do not run Forge." Concise. The "Stop first" block at the top of the plan says "Do not choose another sentence."
- **Verification:** Pre-edit anchor check; replacement applied verbatim; function body unchanged.
- **No tests or other files changed.**

### Kimi (`kimi-adj01-plan.md`, 37 lines)

- **Headline:** "No blocking question." Plan in three steps.
- **Forge stance:** Step 2 ("verification") adds a `forge build` step. "per the repo rule the implementing session runs the standard `forge build` gate before recording the result (no test run is needed — no test is added or changed, per the PRD). Record the diff and the build result in the execution report."
- **Verification:** Diff shows one changed region in one file, all inside a comment; `forge build` confirms the file still compiles.
- **Note on Kimi's pre-edit check:** Kimi correctly notes the PRD's dissent (`:46`) — that "the flag can be true when the caller is the vault" — which means the original comment's "only when true and `msg.sender != address(this)`" opening (which Kimi had in their first-pass review) had to go. Kimi adopts the PRD's text verbatim. This is correct.

### Mine (this session's `minimax-adj01-plan.md`)

- **Headline:** "No blocking question." Comment-only edit.
- **Forge stance:** "No Forge command (no test was added or changed; PRD non-goal does not require a Forge run)."
- **Verification:** Static diff; preconditions verified by direct re-read.
- **Five ordered steps:** verify preconditions; replace NatSpec; no other file; no self-call/exemption/test; no Forge command.

---

## 5. Where I agree

1. **No Forge command in the plan.** Three of four reviewers (Astra, Grok, mine) agree. Kimi is the minority; I disagree on Kimi's `forge build` step.
2. **Static diff is the verification.** A byte-for-byte comparison of the pre-edit NatSpec (lines 41-44) and the post-edit NatSpec (the PRD's six-line block) is the only verification that matters for a comment-only edit. The preconditions at lines 57-63 are verified by direct read, not by compilation.
3. **No test was added or changed.** The PRD non-goal (`:40`) forbids it. Without a test, `forge test` has nothing to validate; without `forge test`, `forge build` has no Forge-side benefit.
4. **The replacement text is fixed.** All four reviewers cite the same six-line NatSpec from the PRD. No wording alternative.

## Where I add precision

1. **Kimi's "repo rule" citation is the source of the disagreement.** I do not find this rule in the PRD or in the canonical testing guidance I read earlier this session. If the rule exists in a project doc I did not read (e.g., a CONTRIBUTING.md or a build-policy doc), it does not override the PRD's silence on this item. The PRD is the controlling text; its non-goals do not require a build. Even if a build policy exists in another doc, the PRD is more specific to this item and is the controlling text.
2. **`forge build` would not validate the comment edit.** The change is NatSpec only. NatSpec does not appear in bytecode. A successful build confirms the file compiles, which is a property the static diff already establishes (no executable line changes). An unsuccessful build would indicate a syntax error in the comment, which a text diff would also reveal.
3. **The implementing session can record the diff and the result without a build.** The "result" Kimi wants to record is the pre-edit anchor check, the post-edit anchor check, and the diff. None of these require a build.

---

## 6. Findings

### Cross-ADJ01-1 — "No Forge command" is the consensus

- **Severity:** N/A (convergence, not a defect).
- **File and line:** the plan-level question of whether to include a `forge build` step.
- **Verification:** Three of four reviewers (Astra, Grok, mine) agree there is no Forge command in the plan. The PRD does not require a build or a test. The edit is comment-only; a static diff is sufficient verification. Kimi's `forge build` is the minority position and the reasons to omit it (no PRD requirement, comment-only edit, no test to run, build does not validate the comment change) outweigh the "best practice" argument.
- **Impact class:** No source defect. No delivery defect. The plan is closed at "No Forge command."
- **Confidence:** High on the PRD's silence on this item; high on the comment-only nature of the edit.

### Cross-ADJ01-2 — Kimi's `forge build` step is the only divergence

- **Severity:** N/A (minority dissent, not a defect).
- **File and line:** `docs/reviews/apex-req-adj-01-self-call-comment/reviewers/kimi-adj01-plan.md` Step 2.
- **Verification:** Kimi cites a "repo rule" that requires `forge build` before recording the result. I do not find that rule in the PRD or in the canonical testing guidance I read. The PRD's non-goals (`:42`) do not require a build. The edit is comment-only; `forge build` does not validate the comment change.
- **Impact class:** None. The cross-review closed on "No Forge command." Kimi's plan is an alternate; this review adopts the majority position.
- **Confidence:** High.

---

## 7. Dissent or unresolved items

**Dissent from Kimi:** The plan does not include a `forge build` step. The PRD does not require a build; the edit is comment-only; a static diff is sufficient verification. The reasons to omit `forge build` outweigh the "best practice" argument.

**Agreement with Astra, Grok, and my own first pass:** "No Forge command."

**Unresolved item:** None. The plan is closed at "No Forge command." No closed alternative is needed.

---

## 8. Files examined (this cross-review)

- `docs/reviews/apex-req-adj-01-self-call-comment/reviewers/astra-adj01-plan.md` — read in full (74 lines).
- `docs/reviews/apex-req-adj-01-self-call-comment/reviewers/grok-adj01-plan.md` — read in full (49 lines).
- `docs/reviews/apex-req-adj-01-self-call-comment/reviewers/kimi-adj01-plan.md` — read in full (37 lines).
- `docs/reviews/apex-req-adj-01-self-call-comment/reviewers/minimax-adj01-plan.md` — re-read for self-consistency. Not treated as a peer.
- `docs/reviews/apex-req-adj-01-self-call-comment/REMEDIATION_PRD.md` — re-read in full (50 lines) to confirm the PRD's stance on Forge.

No Forge / build / test was executed. No code was edited.

---

I did not run Forge.