# MiniMax M3 — Legacy V4 redesign plan cross-review

- **Date:** 2026-10-14
- **Reviewer:** MiniMax M3, one cross-review continuation. No peer original used as authority. No code, REDESIGN_PRD.plan.md, or REMEDIATION_PRD.md was read or written this round except the three peer plan drafts. No Forge run. No exploit procedure.
- **Question:** Agree or dissent on two points only: (1) the package has sixteen cuts, not twenty-one; (2) the SY shim is deleted only after its importers are repointed.

## Verdict

**Agree on both points.** I agree with the three peer plans on the count and the deletion order.

- **Point 1 (sixteen cuts, not twenty-one):** All three peer plans say sixteen cuts. I agree. My own plan had a math error: it listed ten family names but wrote "14" instead of "16". The correct count is 5 shared + 1 callback + 10 family = 16. The PRD's selector list at lines 39-61 is the source of truth: it has 16 rows (5 shared + 1 callback + 10 family = 16 cuts total).
- **Point 2 (SY shim deleted only after its importers are repointed):** All three peer plans and my own say: first create the new error file, second repoint every importer's import, third delete the shim only after a search shows zero remaining importers. I agree.

## Dissent note for my own plan

My plan file at `reviewers/minimax-plan.md` wrote "14 cuts" at the package cut order section. That is a math error. The correct count, matching the PRD's selector list, is 16. The selector list itself in my plan (5 shared + 1 callback + 10 family = 16 names) is correct. The replacement sentence for my own plan, in case the plan is edited: "The package has 16 cuts: 5 shared + 1 callback + 10 family. No other family facet is added or dropped." This is the only correction I would make to my own plan; the rest of my plan is consistent with the three peer plans and the PRD.

## Why I agree

- **Point 1:** The PRD's line 63 explicitly lists the install order: "the five shared facets, then callback, IN, IN query, position import, OUT, OUT query, liquid reserve, IN multi, IN multi query, OUT multi, OUT multi query." That is 5 + 1 + 10 = 16. Astra, Grok, and Kimi each list 16. My own plan listed the same 10 family names and 5 shared names but wrote "14" by mistake.
- **Point 2:** The PRD's line 86 says: "Do not delete `NativeStandardYieldTarget.sol`. Other families change only import paths from the deleted shim to `NativeStandardYieldTarget.sol` or `NativeStandardYieldErrors.sol`." This means the shim is deleted only after the repoint is in place. Astra (step 24), Grok (step 1), and Kimi (steps 1 and 6) all encode this order. My own plan (step 1) encodes the same order: "Add the SY error file and repoint shim imports — the shim cannot be deleted while importers remain."

I do not dissent on either point. I am not providing a replacement sentence because the three peer plans and the PRD already specify the correct count and the correct deletion order.

I did not run Forge.