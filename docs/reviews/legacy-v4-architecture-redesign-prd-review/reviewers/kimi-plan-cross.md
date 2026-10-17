# Kimi K3 — plan cross-review: legacy V4 flatten

- **Label:** Replacement-session cross-review, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. My plan draft is `kimi-plan.md` in this directory. The three peer drafts were read in full as untrusted model output. The controlling document is `../REDESIGN_PRD.md`. Nothing was edited.
- **Date:** 2026-10-14. I did not run Forge.

## Point 1 — sixteen cuts, not twenty-one: agree with Astra and Grok; dissent from one MiniMax sentence

The controlling text (`REDESIGN_PRD.md:63`) installs the five shared facets, then callback, IN, IN query, position import, OUT, OUT query, liquid reserve, IN multi, IN multi query, OUT multi, OUT multi query — **16 cuts** (5 shared + 11 family).

- Astra states it explicitly and correctly: "The package has **sixteen**, not fourteen or twenty-one, cuts" (`astra-plan.md:91`), with a 16-row table at `:93-110` that matches the PRD's order.
- Grok's cut-order sentence (`grok-plan.md:51`) enumerates the same 16 without stating the numeral; consistent.
- MiniMax's enumeration at `minimax-plan.md:122-139` also has exactly 16 entries — but its summary sentence at `:141` says "15 + 1 = 16 family-cuts + 5 shared = 21 package cuts total," which counts the five shared facets twice (the 15 current package cuts already include them; the only addition is the callback facet). MiniMax's own table contradicts its own sentence.

**Dissent, and the sentence the plan must use:**

> "The package installs sixteen cuts: the five unchanged shared facets, then callback, IN, IN query, position import, OUT, OUT query, liquid reserve, IN multi, IN multi query, OUT multi, OUT multi query. There is no twenty-first cut; the callback facet is the only addition to the current fifteen."

## Point 2 — the SY shim is deleted only after its importers are repointed: agree with Astra and Grok; MiniMax's step ordering is rejected

- Astra stages it correctly: repoint during Stage A (`astra-plan.md:50`), delete "only after every importer points to the defining file" (Stage E, `:84`).
- Grok states the rule in one line: "Delete the shim only after that search shows no remaining importer" (`grok-plan.md:28`), with repointing as step 1.
- My own draft's step 6(b) bundles the repoint and the deletion in one step with the repoint named first — substantively compliant, but the coordinator's formulation is stricter, and I adopt it: the repoint is its own earlier step, not a clause inside the deletion step.
- MiniMax's Step 13 (`minimax-plan.md:108-112`) sentences run "Delete … (the 5-line shim). Repoint every consumer's import…" — deletion textually precedes the repoint inside one step. Even read charitably as one atomic edit, that ordering in a written plan invites an intermediate state where eleven consumer files (verified by my grep in the readiness round: ten non-legacy consumers plus the legacy yield target) import a deleted file. Rejected.

**The sentence the plan must use:**

> "Every importer of `contracts/vaults/standard/sy/NativeStandardYieldExecutionTarget.sol` is repointed to the defining declarations in `NativeStandardYieldTarget.sol` or `NativeStandardYieldErrors.sol` as its own step, before any deletion; the shim file is deleted only after a fresh repository-wide search shows no remaining importer."

## Observations outside the two assigned points (recorded, not blocking)

- MiniMax's Step 5 (`:59`) says "Add `_requireNotDisabled()` to the OUT money routes," but that check already exists there (`UniswapV4StandardExchangeOutExecuteTarget.sol:39`, verified in an earlier round). The controlling scope is: new check on SY `deposit`/`redeem` only; existing checks stay (PRD `:71`). MiniMax's phrasing misdescribes an existing check as an addition; its Step 9's placement of the SY check ("in `UniswapV4StandardExchangeInTarget.sol` (or the legacy V4 SY hook layer if the SY path is in there)", `:83`) is a residual either/or the consolidated plan should not carry — the SY money override points live in the legacy yield layer, and the plan should say so.
- MiniMax's Step 13 also deletes the three import-maintenance functions "from `UniswapV4StandardExchangeImport.sol`" — i.e., it carries them into `Import.sol` at Step 2 and deletes them at Step 13. Astra, Grok, and I never carry them; the functions die in the move. Carrying-then-deleting is a longer route to the same end state, not a correctness defect, but it contradicts the PRD's delete-listing (`:84`), which treats them as deletions, not moves.

## Unresolved dissent

Only the two rejected MiniMax elements above: the twenty-one-cut sentence and the delete-before-repoint ordering. Astra, Grok, and I agree on sixteen cuts and repoint-before-delete; both are what the controlling PRD already says, so this is correction of a draft to match the PRD, not a design dispute.

I did not run Forge.
