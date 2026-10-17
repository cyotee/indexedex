# Grok cross-review — REQ-03 PRD completeness

- **Date:** 2026-10-15
- **Label:** Cross-review of the three completeness notes. Not a rewrite of `grok-completeness.md`.
- **Peers read:** `astra-completeness.md`, `minimax-completeness.md`, `kimi-completeness.md`. Treated as untrusted evidence.
- **PRD:** `docs/reviews/apex-req-03-custody-negatives/REMEDIATION_PRD.md`, lines 24-77, re-read this turn. Not edited.
- **Question:** Does any implementer choice remain, including how the observation callback stores the nested result, and whether the scanner adds the listed directories to the existing `roots` tuple?
- **Answer:** Yes. Two representation choices remain. R2 does not.

## Agreement

- Astra, MiniMax, and Kimi are right that the observation call and the rollback call are separate. The observation callback returns. The rollback test still expects `TransferFromFailed` and keeps the no-partial-credit assertions. The outer selector is not changed to `IsLocked`. The vault is not mocked.
- They are right that REQ-03-R2 is closed: after the successful exact-output call, total supply equals the captured supply plus the requested shares. The existing assertions stay.
- They are right that the directory list is the inventory. The implementer does not choose families, add a directory, or drop one. Both Balancer spellings stay. The two named custody files stay. Bare `expectRevert()` in a selected file still fails the scanner. Those tests are not rewritten here.
- Kimi is right that a reverted outer observation call would erase a storage record, so "the outer deposit finishes" already rules out keeping the current callback revert. That does not pick the record's carrier.

## Dissent

I dissent from all three "no choice remains" verdicts. The owner requires no implementer choice. Both of the named representations are still open in the PRD, and the peer notes say so.

### REQ-03-R1 — record carrier

PRD line 33 says the callback records the attempt and the `IsLocked` rejection, then returns, and the test reads that record after the call. It does not say where the record lives.

- Kimi, residual latitudes: storage, an event, or an external recorder each satisfy that sentence.
- MiniMax, "What I am NOT flagging": the storage layout is not specified, and the implementer picks the representation. MiniMax also leaves try/catch, a low-level call, or a new harness variant open.
- Astra calls the record identifiers a routine coding detail.

Those are different implementations. An implementer cannot know which one the owner will accept. The current callback at `RebasingAwareERC4626_Adversarial.t.sol:28-32` already makes a low-level `deposit` call and then reverts. The harness bubbles only when that callback call fails, so a callback that stores and returns needs no harness change.

**Sentence to add under REQ-03-R1 acceptance criteria:**

In the observation test, the callback keeps its low-level `deposit` call, writes `nestedAttempted = true` and `nestedReason = reason` on the test contract, and returns without reverting. After that deposit finishes, the test asserts `nestedAttempted` and asserts `nestedReason` equals `abi.encodeWithSelector(IReentrancyLock.IsLocked.selector)`. Do not put that pin in an event, another contract, or a harness change.

### REQ-03-R3 — selection tuple

PRD line 55 says the two roots stay and to add the rest. Line 73 says every listed directory is selected recursively. The script's only recursive selector is the `roots` tuple at `scripts/apex_bare_expectrevert_scan.sh:14-17`. The PRD never says to append the new directories to that tuple.

- Astra reads the change as adding the listed roots. That is one reading, not a PRD sentence.
- MiniMax line 49 says add them to `roots`, then line 68 says the implementer may use a third tuple or another representation.
- Kimi leaves extending `roots` versus a parallel list as needing no owner input.

A second list that is also walked with `rglob` meets line 73. So does appending to `roots`. The owner asked which one. The PRD does not say.

**Sentence to add under REQ-03-R3 acceptance criteria:**

Add each directory on this list that is not already in `roots` to the existing `roots` tuple in `scripts/apex_bare_expectrevert_scan.sh`. Do not add a second selection list. Leave the `custody` tuple and the APEX-marker scan unchanged.

## Correction to my earlier note

`grok-completeness.md` said no choice remained. That is withdrawn for these two representations only. I do not withdraw the split, the total-supply assertion, or the directory inventory.

## Not reopened

Test names are not an owner decision once the carrier and the tuple are fixed. I do not add a sentence for them. I do not reopen R2, the rollback expectation, the bytecode check, or the ban on a broader `expectRevert()`.

I did not run Forge.
