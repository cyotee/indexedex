# REQ-03 PRD completeness review — MiniMax M3

- **Date:** 2026-10-14
- **Reviewer:** MiniMax M3, independent completeness pass. Not a cross-review. No peer text read. PRD re-read in full at `docs/reviews/apex-req-03-custody-negatives/REMEDIATION_PRD.md` (87 lines). The cited tests and scanner were re-read only as needed to check whether a PRD sentence is ambiguous against current code.
- **Question:** Does this PRD leave any decision for a later implementer? The owner requires that it does not.

## Verdict

**The PRD is complete. No decision remains for the implementer.**

The owner rulings on REQ-03-R1 (line 30) and REQ-03-R3 (lines 54-71) have resolved the two blocking questions from my prior clarifying pass. R1's fix shape is closed: two tests, the observation test records-and-returns while the rollback test stays as-is. R3's inventory is closed: a directory list is provided and the implementer does not decide which families to include. R2's acceptance criteria are precise and have no remaining ambiguity.

I re-read the disputed source lines to verify that the PRD's sentences are not ambiguous against current code. Every path in the R3 directory list exists in the current tree; the singular/plural split in the list matches the actual `protocol/` vs. `protocols/` layout. The R1 callback shape is achievable with the current `ReentrantERC20Harness` (the harness's `bubbleRevert` toggle already supports the split, and the callback can use a try/catch or low-level call to record without reverting). The R2 assertion is mechanical.

The implementer can start. No question needs to be answered before the implementer can begin.

## Why each PRD sentence that I previously flagged is now closed

### B1 from my clarifying pass — was: blocking. Now: closed.

My clarifying pass identified B1 as blocking: the implementer could not start R3 without knowing whether the D16 R2.4 inventory was defined as a concrete file list in the cited plan/evidence bundle, or whether the owner needed to provide an approved map. The owner ruling at PRD line 54 closes this:

> "Do not hallucinate filenames, and do not leave the search to the implementer. The PRD writers searched. The implementer selects the directories below and does not decide which families belong."

The "directories below" are the explicit list at PRD lines 55-71. The owner has taken the responsibility for the search. The implementer has the list.

I re-checked the list against the current tree. All 15 new directories plus the 2 already-selected roots exist:

- `test/foundry/spec/hooks/uniswap/v4/standardExchange` (already selected, PRD line 56)
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap` (already selected, PRD line 56)
- `test/foundry/spec/vaults/standard/erc4626` (line 57) — exists
- `test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue` (line 58) — exists
- `test/foundry/spec/protocols/staking/rebasingVault` (line 59) — exists
- `test/foundry/spec/protocol/staking/rocket-pool` (line 60) — exists
- `test/foundry/spec/protocol/staking/lido` (line 61) — exists
- `test/foundry/spec/protocol/staking/etherfi` (line 62) — exists
- `test/foundry/spec/protocol/lending/aave/v3.6` (line 63) — exists
- `test/foundry/spec/protocol/lending/aave/cross-version` (line 64) — exists
- `test/foundry/spec/protocol/dexes/uniswap/v2` (line 65) — exists
- `test/foundry/spec/protocol/dexes/camelot/v2` (line 66) — exists
- `test/foundry/spec/protocol/dexes/aerodrome/v1` (line 67) — exists
- `test/foundry/spec/protocols/dexes/aerodrome/slipstream` (line 68) — exists
- `test/foundry/spec/protocol/dexes/balancer/v3` (line 69) — exists
- `test/foundry/spec/protocols/dexes/balancer/v3` (line 70) — exists
- `test/foundry/spec/vaults/detf` (line 71) — exists

The singular/plural split (`protocol/` for uniswap, camelot, aerodrome, balancer, lido, rocket-pool, etherfi, aave; `protocols/` for rebasingVault, aerodrome/slipstream, balancer/v3) matches the actual tree layout. Both Balancer paths are included because both directories exist and contain different tests. No path is wrong; no path is missing from the implementer's perspective.

The PRD acceptance criterion 1 at line 73 ("The scanner selects every directory in that list, recursively, with or without an APEX marker") is the scanner behavior. The implementer adds the 15 new directories to the existing `roots` tuple in the scanner script. This is mechanical.

### N1 from my clarifying pass — was: non-blocking. Now: also closed.

My clarifying pass identified N1 as a design-choice question: which shape satisfies "the nested pin must survive the wrap"? The owner ruling at PRD line 30 closes it:

> "Let the deposit finish. The observation test is a separate call from the rollback test."

The R1 acceptance criteria now specify the shape:

- AC 2 (line 33): "In the observation test, the callback records that the nested deposit was attempted and rejected with `IReentrancyLock.IsLocked`, then returns without reverting. The outer deposit finishes. The test reads that record after the call. A wrong nested error, or a nested success, fails this test."
- AC 3 (line 34): "The existing rollback test stays. Its outer call still reverts `TransferFromFailed`, and its no-partial-credit assertions for supply, recipient shares, vault assets, and reserve stay. That test does not have to carry the nested-error pin."

The split is explicit. The observation test is a new test with a new callback shape (records and returns, outer deposit finishes). The rollback test is the existing test, unchanged. The non-goal at line 35 ("Do not require one call both to revert and to leave a readable record") confirms the split.

The mechanism (try/catch in callback, low-level call, or a new harness variant) is not specified in the PRD, but it is a design choice within the closed acceptance criteria, not a decision the PRD leaves open. The implementer can pick any mechanism that satisfies "the callback records... then returns without reverting" and "the test reads that record after the call." The current `ReentrantERC20Harness` (at `contracts/test/stubs/ReentrantERC20Harness.sol:58-75` per my prior read) supports both `bubbleRevert=true` (for the existing rollback test) and `bubbleRevert=false` (for the new observation test). A try/catch in the callback is the standard Solidity mechanism and is compatible with the current harness.

### N2 from my clarifying pass — was: non-blocking. Now: also closed.

My clarifying pass identified N2 as a format question for the inventory. The owner ruling at PRD line 54 and the directory list at lines 55-71 imply a single answer: the list is given verbatim and the implementer uses it as-is. The PRD does not specify a format (inline shell list vs. external file), but the existing scanner at `scripts/apex_bare_expectrevert_scan.sh:14-21` uses inline Python tuples (`roots` and `custody`). The natural extension is a third inline tuple. The implementer can pick the representation; the owner can accept or reject. This was already not blocking; the owner ruling doesn't make it more closed, it just makes the list available.

## What I am NOT flagging

- **R2 (total supply on success).** The acceptance criteria at line 44 are precise: "After the successful exact-output call, total supply equals the captured supply plus the requested shares." The implementer writes one additional assertion alongside the existing ones at lines 97-100. The non-goals at line 46 (no production change, no fuzz-domain widening) are clear. No decision remains.
- **R1 non-goals.** The non-goals at line 35 are explicit: do not change production pull wrapping, do not require one call to both revert and leave a record, do not make the outer selector `IsLocked`, do not replace either test with a bare `expectRevert()`. The implementer knows what not to do.
- **The "already satisfied" declarations** at PRD lines 18-22 (ownership, minimality rejection, named custody inclusion) are not gaps and not reopened.
- **The production bytecode check** at `RebasingAwareStandardYieldTarget.sol:57-59` is not to be weakened (PRD line 20). The implementer keeps it.
- **The new observation test's name, location, and storage layout** are not specified. These are implementation details the implementer picks within the closed acceptance criteria. The functional target is closed; the representation is not.

## Evidence gaps

- I did not run Forge. No execution, no scanner run, no Foundry assertion behavior verified at runtime. The PRD acceptance criteria are source-assertion verdicts, not passing-run claims.
- I did not enumerate every test file in the R3 directory list. The list is given; the implementer verifies each path exists and each selected file is covered.
- I did not body-read the rest of the cited test files beyond the lines needed to verify the PRD sentences. The R1 shape is achievable with the current harness; the R2 assertion is mechanical; the R3 directory list matches the current tree. No further re-read was needed for completeness.

I did not run Forge.