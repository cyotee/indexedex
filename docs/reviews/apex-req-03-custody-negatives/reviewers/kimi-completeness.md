# Kimi K3 — original: completeness of the REQ-03 custody-negatives PRD

- **Label:** Replacement-session original, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No `reviewers/` content for this round was read; no peer text was used. I did not write the PRD under review.
- **Date:** 2026-10-14.
- **Question:** Does `docs/reviews/apex-req-03-custody-negatives/REMEDIATION_PRD.md` leave any decision for a later implementer? The owner requires that it does not.
- **Method:** the PRD was re-read in full this turn. The cited tests and scanner were re-read in my immediately prior passes of this session; the PRD's citations match those reads, and no sentence I checked is ambiguous against current code. I did not run Forge.

## Verdict

**No remaining decision blocks an implementer.** The two decisions I flagged in my question turn are closed by owner rulings now present in the PRD, and the third requirement was already fully specified. The residual latitudes I found are mechanical, are each constrained to a single reasonable reading by the acceptance criteria, and are listed below only so the completeness claim is auditable — none needs an owner answer.

## Ruling 1 — REQ-03-R1: the proof-channel decision is closed

My earlier blocking question: criteria requiring the nested-error pin to survive the `TransferFromFailed` wrap, while the no-partial-credit rollback assertions stay and callback storage cannot survive a reverted outer call, appeared jointly satisfiable only by choosing between an observation leg whose outer deposit succeeds and a two-test split.

The PRD now closes this with the owner ruling at `:30` ("Let the deposit finish. The observation test is a separate call from the rollback test.") and the rewritten criteria at `:32-34`: the observation test's callback records the attempt and the exact `IReentrancyLock.IsLocked` rejection, returns without reverting, the outer deposit finishes, and the record is read after the call; the rollback test stays as it is. The non-goal at `:35` ("Do not require one call both to revert and to leave a readable record") resolves the tension explicitly. The forbidden MiniMax shape (harness returning success so the outer test can pin `IsLocked`) remains excluded, and the permitted shape is distinguishable from it: in the permitted shape the outer deposit simply succeeds and no `IsLocked` selector is expected on it.

Residual latitudes, and why they are not owner decisions:

- The record carrier (storage on the test contract written by the non-reverting callback) is the single reasonable reading of "the callback records … the test reads that record after the call" (`:33`); events or an external recorder would also work but nothing in the criteria prefers one, and either satisfies them.
- The observation leg needs a callback variant that returns instead of re-bubbling (`:32` of the test file is the current re-bubble). Writing that variant is the edit the PRD orders.
- Whether the observation test additionally asserts the outer deposit's success state is unconstrained; "the outer deposit finishes" (`:33`) already forces the meaningful assertion, since a reverted outer call would roll the record back and fail the test.

## Ruling 2 — REQ-03-R2: already closed

The acceptance criteria at `:43-45` name the exact assertion (total supply equals the captured supply plus the requested shares, after the successful call), its inputs (`supplyBefore` at `RebasingAwareERC4626_Fuzz.t.sol:65`), and what stays. The dissent record at `:82` documents the withdrawn objection. No decision remains.

## Ruling 3 — REQ-03-R3: the inventory decision is closed

My earlier blocking question: the acceptance bullet required an R2.4 inventory "taken from" documents that enumerate families rather than test files, leaving unclear whether the implementer might derive the map or must stop.

The PRD now closes this with the owner ruling at `:54` ("The PRD writers searched. The implementer selects the directories below and does not decide which families belong.") and the explicit directory inventory at `:55-71`, with acceptance criteria at `:72-76` (recursive selection of every listed directory; the two cited escape files selected through their directories; the two named custody files retained; bare `expectRevert()` still rejected) and non-goals at `:77` (no added or dropped directories). The implementer's work is mechanical: extend the script's selection to the listed directories. The choice of carrier (extending `roots` versus a parallel list) is constrained by the behavioral acceptance criteria and needs no owner input.

One verification note, not a decision: the list contains both `test/foundry/spec/protocol/dexes/balancer/v3` (`:69`) and `test/foundry/spec/protocols/dexes/balancer/v3` (`:70`) — the `protocol`/`protocols` singular/plural pair. The PRD asserts these directories exist (`:55`), and this repository does use both spellings elsewhere in the test tree, so I take the pair as deliberate. If the implementer finds one spelling absent, that is an execution-time fact to report, not a license to drop or substitute an entry (`:77` forbids both).

## What I checked for ambiguity against current code

- `RebasingAwareERC4626_Adversarial.t.sol:26-32,128-146` — matches the PRD's description of the current callback and outer expectation; the owner ruling's shape is implementable against this code without production edits (the wrap at `RebasingAwareERC4626Common.sol:274-278` is untouched by design).
- `RebasingAwareERC4626_Fuzz.t.sol:65,70-84,96-100` — matches the R2 citations; the success half indeed omits total supply today.
- `scripts/apex_bare_expectrevert_scan.sh:14-26` — matches the R3 description of the current selection rule; the two cited escape files sit outside it as the PRD states.

## Conclusion

No remaining question. The PRD, as revised with the 2026-10-14 owner rulings, leaves no decision that would require an implementer to choose between owner-level alternatives. Nothing above reopens a closed choice or adds product work.

I did not run Forge.
