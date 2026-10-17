# MiniMax M3 — REQ-03 PRD completeness cross-review

- **Date:** 2026-10-14
- **Reviewer:** MiniMax M3, one cross-review continuation. No peer original used as authority. No peer cross or REMEDIATION_PRD.md was read or written this round. The PRD at `docs/reviews/apex-req-03-custody-negatives/REMEDIATION_PRD.md` was re-read in full and is the same document the three peers reviewed.
- **Question:** agree or dissent on whether any choice is still open, including how the observation callback stores the nested result, and whether the scanner adds the listed directories to the existing roots tuple.

## Verdict

**Agree with all three peers. The PRD is complete. No sentence needs to be added.**

The owner rulings on REQ-03-R1 (line 30) and REQ-03-R3 (lines 54-71) close the two blocking questions from my prior clarifying pass. REQ-03-R2's acceptance criteria are precise and have no remaining ambiguity. The two specific points the coordinator asked about — how the observation callback stores the nested result, and whether the scanner adds the listed directories to the existing roots tuple — are coding details, not owner decisions. The PRD's acceptance criteria describe the behavior; the implementer picks the implementation.

## (1) Observation callback storage

**Agree with all three peers. Not an open choice.**

The PRD at line 33 says: "In the observation test, the callback records that the nested deposit was attempted and rejected with `IReentrancyLock.IsLocked`, then returns without reverting. The outer deposit finishes. The test reads that record after the call. A wrong nested error, or a nested success, fails this test."

The constraint "The test reads that record after the call" is the load-bearing requirement. It implies the record must be in a location the test can read after the outer call returns. The constraint is satisfied by any storage the test can access — test-contract storage is the standard and natural choice. Other mechanisms are eliminated by the constraint:

- **Events** are readable off-chain but not from the test in a way that allows `assertEq` / `assertTrue`. They do not satisfy the constraint.
- **Callback return values** are not exposed to the test; the callback is invoked by the harness's `transferFrom`, not by the test directly. They do not satisfy the constraint.
- **Test-contract storage** is the only mechanism that satisfies the constraint.

The PRD's sentence is sufficient. No additional sentence is needed. The implementer picks the storage layout (single field, struct, multiple fields) as a coding detail within the closed constraint. This is what Kimi means by "the single reasonable reading of 'the callback records … the test reads that record after the call'" and what Astra means by "Callback/record identifiers are routine coding details, not missing owner decisions."

Grok's framing also holds: "The dissent sentence about storage dying inside a reverted callback applies to the rollback test, not to the observation test, whose callback returns." The observation test's callback returns without reverting, so storage writes on the test contract survive. This is the natural read.

I do not propose a sentence. The PRD's line 33 is sufficient.

## (2) Scanner carrier

**Agree with all three peers. Not an open choice.**

The PRD at line 55 says: "These directories exist and contain the named D16 families' regression tests. The two roots already in the scanner stay. Add the rest." Line 73 says: "The scanner selects every directory in that list, recursively, with or without an APEX marker."

These sentences describe the scanner behavior: every directory in the list (including the two already-selected roots at line 56 and the 15 new ones at lines 57-71) must be selected. The carrier — whether the directories are added to the existing `roots` tuple, a new parallel tuple, or read from an external file — is a coding detail. All three carriers satisfy the behavioral criteria.

The current scanner at `scripts/apex_bare_expectrevert_scan.sh:14-21` uses two inline Python tuples (`roots` and `custody`). The natural extension is to add the 15 new directories to the `roots` tuple. The implementer may pick this or an equivalent structure. Kimi states this explicitly: "The choice of carrier (extending `roots` versus a parallel list) is constrained by the behavioral acceptance criteria and needs no owner input."

I do not propose a sentence. The PRD's lines 55 and 73 are sufficient.

## (3) Other potential choices I checked and did not flag

- **R1 callback/record identifiers** (the exact Solidity types, field names, struct shapes): coding details. Astra, Grok, and Kimi all agree. The PRD's "the callback records" and "the test reads that record" are sufficient.
- **R1 harness configuration** (whether to set `bubbleRevert=false` on the existing harness or create a new harness variant): coding detail. The current `ReentrantERC20Harness` supports both modes. The implementer picks.
- **R1 observation test location** (same file as the rollback test, or new file): coding detail. The acceptance criteria name the test's role; the location is the implementer's choice.
- **R2 assertion line** (the exact Solidity line to add): mechanical. The implementer writes one `assertEq` line.
- **R3 scanner format choice** (inline tuple vs. external file): coding detail. The current scanner uses inline Python tuples; the implementer follows that style or proposes a change. The owner can accept or reject.
- **R3 the `protocol` vs. `protocols` singular/plural split** in the directory list: not a choice. The split matches the actual tree (verified at `test/foundry/spec/` which contains both `protocol/` and `protocols/`). Both Balancer paths are listed deliberately. Kimi notes this: "the `protocol`/`protocols` singular/plural pair. The PRD asserts these directories exist, and this repository does use both spellings elsewhere in the test tree, so I take the pair as deliberate."
- **The PRD's three "already satisfied" declarations** at lines 18-22 (ownership, minimality rejection, named custody inclusion): not reopened. Astra, Grok, and Kimi all agree.

## Unresolved dissent

None. The three peers and I agree on all material points. The PRD is complete; the implementer can start.

## Evidence gaps

- I did not run Forge. The PRD acceptance criteria are source-assertion verdicts, not passing-run claims.
- I re-read the disputed source lines to verify that the PRD's sentences are not ambiguous against current code, but I did not body-read every test file in the R3 directory list. The directory list matches the current tree; the implementer verifies each path exists during implementation.
- The storage mechanism in the observation test is a coding detail. I did not write a sample callback or test contract; the implementer picks the storage layout. The PRD's line 33 constrains the mechanism; the layout is the implementer's choice.

I did not run Forge.