# REQ-03 clarifying questions — MiniMax M3

- **Date:** 2026-10-14
- **Reviewer:** MiniMax M3, targeted clarifying-question turn. Not a new defect review. Not a cross-review. No peer artifacts read. PRD re-read in full at `docs/reviews/apex-req-03-custody-negatives/REMEDIATION_PRD.md` (71 lines).
- **Format:** blocking questions first, then non-blocking. Per-question: requirement ID, blocking status, the decision the implementer needs.

## Blocking questions

### B1 — R3: is the D16 R2.4 regression inventory defined as a concrete file list anywhere the implementer can read?

- **Requirement:** REQ-03-R3 (PRD lines 49-61, specifically acceptance criterion 1 at line 56).
- **Blocking:** Yes.
- **Decision needed:** REQ-03-R3 acceptance criterion 1 says: "The D16 R2.4 inventory is taken from `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md` and `docs/audits/apex-2026-09-17-evidence/`, or from a later owner-approved map of those documents." The PRD does not commit to either source. The implementer cannot start REQ-03-R3 without knowing which is the case:
  - If the plan and evidence bundle together contain a concrete file-level D16 R2.4 inventory, the implementer reads it and binds the scanner to that list. No owner ruling is required.
  - If those documents do not contain such a list, the "later owner-approved map" is the controlling source, and the owner must provide it before the implementer can complete the acceptance criterion.

  The two cited escape files in the PRD (`test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol` bare `expectRevert` sites; `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Accounting.t.sol:131` and `:143`) are not the inventory; they are instances whose classification depends on the inventory. The PRD acceptance criterion 3 says: "If the inventory includes them, the scanner selects them. If it does not, the record says they are outside the inventory." That classification step is blocked on the inventory being readable.

  A confirming pass through the two cited documents is required to determine the answer. If they contain a file list, the question closes. If they contain only the D16 family scope at `apex-2026-09-17-remediation-and-regression-tests.md:335` (which the PRD itself acknowledges is "family scope alone is not that inventory" via the dissent at line 67), the owner must provide a map.

  This question is not "is the inventory small" or "is the inventory discoverable" — those are post-blocking design questions. The blocker is the binary: does a list exist, and if not, who is producing it.

## Non-blocking questions

### N1 — R1: which shapes satisfy "the nested pin must survive the wrap"?

- **Requirement:** REQ-03-R1 (PRD lines 24-36).
- **Blocking:** No. The implementer can pick a shape that satisfies the acceptance criteria, demonstrate it with a passing test, and let the owner accept or reject the choice.
- **Decision needed (background for the implementer):** The PRD non-goals rule out two shapes:
  - "Do not make the harness return success so the outer test can expect `IsLocked`." (PRD line 36)
  - "Do not store the nested result in the reverting callback and assume that storage survives the revert." (PRD line 36; reinforced by the dissent at line 65: "Ordinary storage written inside the reverted callback does not survive it.")

  The PRD accepts that the outer `expectRevert(TransferFromFailed)` may stay (PRD line 35 acceptance criterion 5). The remaining shapes the implementer can choose between include, but are not limited to:
  - **(a)** Restructure the harness so the reentrancy does not go through `transferFrom`. For example, the reentrant callback could target a function that is not the underlying-token pull, so the bubble never converts to `TransferFromFailed`. The outer error then has the original nested `IsLocked` reason (or a derivative that pins it). The `setReenter` target changes; the test no longer "knows" the old target.
  - **(b)** Add a separate test surface that proves the lock fires on a different path, separate from the existing wrapped test. The existing test keeps `TransferFromFailed`. The new test pins `IsLocked` directly via a non-`transferFrom` path or via a non-reentrant observation that survives the wrap.
  - **(c)** Some hybrid: split the proof between the existing test (no-partial-credit, outer error) and a new test (nested pin).

  The PRD does not pick among (a), (b), (c), or other variants. The acceptance criterion 3 ("A wrong nested error, or a nested success, must fail the test even if the outer call still reverts `TransferFromFailed`") is satisfied by any shape that load-bears the pin. The implementer records the choice; the owner may accept it.

### N2 — R3: in what format and location is the inventory "recorded where the scanner can consume it"?

- **Requirement:** REQ-03-R3 (PRD line 56).
- **Blocking:** No. The implementer can pick a format; the current scanner uses inline Python lists at `scripts/apex_bare_expectrevert_scan.sh:14-21` (the `roots` tuple, the `custody` tuple, and the APEX regex). A natural extension is a third list inline, or a separate text/json file. The owner can accept or reject the choice. The blocker is the inventory content (B1), not the inventory representation.

## What I am not asking

- **R2** has no questions. The acceptance criteria are precise: total supply equals `supplyBefore + shares` on success; existing assertions stay. The non-goals (no production mint change, no fuzz-domain widening) are clear. The "shares" ambiguity that the dissent records is resolved by the PRD's explicit addition of the total supply assertion.
- **R1 acceptance criterion 1** (production path used, vault not mocked) and **criterion 4** (no-partial-credit assertions stay) are explicit. No question.
- **R1 non-goal on `expectRevert`** (do not replace with bare `expectRevert()`) is explicit. No question.
- **The three "already satisfied" declarations** in PRD lines 18-22 (ownership, minimality rejection, named custody inclusion) are not gaps. No question.
- **Production bytecode check** at `RebasingAwareStandardYieldTarget.sol:57-59` is not to be weakened (PRD line 20). The PRD says this; the implementer keeps it. No question.

I did not run Forge.