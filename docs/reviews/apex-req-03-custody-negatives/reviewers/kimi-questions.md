# Kimi K3 — question list: REQ-03 custody-negatives PRD

- **Label:** Replacement-session question list. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. Not a defect review, not a cross-review; no peer files were read for this turn.
- **Date:** 2026-10-14.
- **Subject PRD:** `docs/reviews/apex-req-03-custody-negatives/REMEDIATION_PRD.md` (re-read in full this turn).
- I did not run Forge.

## Blocking questions

### Q1 — REQ-03-R1: what proof channel is intended, given that nothing inside the reverted outer call survives?

**Blocking: yes, for REQ-03-R1.** The later session cannot choose a construction without this answer.

The acceptance criteria and non-goals, read together, constrain the shape tightly:

- The proof that the nested deposit was rejected with `IReentrancyLock.IsLocked` must not be "only an assertion inside the frame that the pull wraps as `TransferFromFailed`" (criterion 3).
- Storage written inside the reverting callback does not survive (non-goal, and true — the deliberate re-bubble at `RebasingAwareERC4626_Adversarial.t.sol:32` rolls back everything the callback wrote).
- The existing no-partial-credit assertions "stay" (criterion 4), which presumes the outer call still reverts; and the outer call "may still expect `TransferFromFailed`" (criterion 5).

The difficulty: if the outer call reverts, the entire call tree below it rolls back — storage writes, events, everything the observer recorded. The only channels that survive a reverted outer call are the call trace (which `vm.expectCall` can use to prove the nested *attempt* with exact arguments and count, but not its revert *reason*) and the final revert data (which the production pull wraps into `TransferFromFailed`, per the file's own comment at `:26-27` and the `safeTransferFrom` pull at `RebasingAwareERC4626Common.sol:274-278`). I see no channel that carries the nested revert's identity out of a reverting outer transaction.

The constructions that remain, and the decision I need:

- **(a) Observation leg with a surviving outer call.** The callback records `(ok, reason)` and returns normally instead of re-bubbling; the nested attempt was already rejected by the production guard, so the outer deposit then succeeds legitimately. The test asserts the recorded `(false, IsLocked)` after the call. Consequence: the outer call no longer reverts, so the existing rollback assertions cannot apply to this leg — they would live in a separate rollback leg (the current shape, unchanged).
- **(b) Two separate tests:** an observation test shaped like (a), plus the existing rollback test kept as-is. Astra's original text allowed separate observation and rollback controls; this PRD's criteria are written around one test and criterion 4 presumes the rollback shape.

**Decision needed:** does the PRD intend (a), (b), or a channel I have not seen? If the outer call must keep reverting with the rollback assertions in the same test that proves the nested error, I do not have a construction and the item needs an owner-approved mechanism before implementation. If (a) or (b) is acceptable, say which, and confirm that the observation leg's successful outer deposit (with its own exact-success assertions replacing the rollback set on that leg) satisfies "the production deposit path is still used."

### Q2 — REQ-03-R3: if neither named source contains a consumable R2.4 test inventory, may the implementer derive the family-to-test-file map for owner approval, or must the session stop?

**Blocking: yes, for REQ-03-R3's first acceptance bullet.**

The bullet says the inventory "is taken from `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md` and `docs/audits/apex-2026-09-17-evidence/`, or from a later owner-approved map of those documents." From my earlier reading, the locked plan's D16 row (`apex-2026-09-17-remediation-and-regression-tests.md:335`, mirrored in the plan) enumerates production families and packages, not test files, and I am not aware of a family-to-test-file mapping in the evidence bundle. The non-goal forbids inventing the inventory from a grep.

**Decision needed:** when the named documents yield a family list but no consumable test-file inventory, is the implementer authorized to derive the map mechanically (each D16 family named in the locked plan → its existing `test/foundry/spec/**` regression files), record it as the "later owner-approved map" for the owner's sign-off, and classify the two cited escape files against it? Or must the session stop and request an already-approved map before touching the scanner? The distinction matters because "derive and record for approval" and "grep for bare `expectRevert()` and add what you find" can produce different sets, and only the former is on the table.

## Non-blocking questions (answers would help; absence does not stop the work)

1. **REQ-03-R3, recording format.** "Recorded where the scanner can consume it" leaves the carrier open: a checked-in inventory file the script reads, or an explicit third path list in the script parallel to `roots` and `custody`. I would default to the in-script explicit list for reviewability unless the coordinator prefers an external file. No decision needed before implementation starts; the acceptance criteria are satisfiable either way.
2. **REQ-03-R1, harness reuse.** Under construction (a) or (b), I assume the existing `ReentrantERC20Harness` (`setReenter`, `setBubbleRevert`) is reused unchanged, with only the observer's deliberate re-bubble removed on the observation leg. If the owner instead expects a new harness variant, say so; otherwise I treat this as answered by the PRD's silence.
3. **REQ-03-R2.** No question. The one-assertion addition against the captured `supplyBefore` (`RebasingAwareERC4626_Fuzz.t.sol:65`) is fully specified, including its Low severity and the recorded dissent.

No other questions. REQ-03-R2 and the "already satisfied, not reopened" sections need nothing from the owner.

I did not run Forge.
