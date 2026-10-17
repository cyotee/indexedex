# Astra — selected redesign plan cross-review

**Agree on both controlling points: sixteen package cuts, and importer repointing before SY-shim deletion.** I read all three supplied plan originals as untrusted evidence and re-read the relevant PRD clauses and current shim. No code, PRD, or consolidated implementation plan was edited. My original plan is preserved.

## 1. Sixteen package cuts, not twenty-one

Agree with Grok's listed order and Kimi's sixteen-cut done-when condition. Dissent from MiniMax's contradictory totals: its step 14 says fourteen cuts, its numbered list contains sixteen, and its line 141 then adds the five shared cuts a second time to claim twenty-one.

`REDESIGN_PRD.md:63` specifies **five shared facets + the callback facet + the ten retained family facets = sixteen package cuts**. The factory's separate introspection infrastructure is not an additional family-package cut. My earlier twenty-one-cut design was not adopted and must not be imported into this plan.

**Sentence the plan must use:**

> Allocate exactly sixteen entries in both the package's `facetCuts` and `facetAddresses`, ordered as ERC20, ERC5267, ERC2612, MultiAssetBasicVault, MultiAssetStandardVault, callback, IN, IN query, position import, OUT, OUT query, liquid reserve, IN multi, IN multi query, OUT multi, and OUT multi query; the first five entries already count the shared facets and must not be counted again.

## 2. Repoint importers before deleting the SY shim

Agree with Grok's explicit repoint-then-delete sequence and Kimi's zero-reference prerequisite. MiniMax's general caller-first statement is correct, but its step 13 says to delete the shim and then repoint consumers; that local order must be corrected. Kimi's grouped deletion step should likewise make the ordering explicit rather than merely saying deletion occurs “with” importers repointed.

The current `contracts/vaults/standard/sy/NativeStandardYieldExecutionTarget.sol:4-5` is an import-only shim that exposes a declaration actually defined in `NativeStandardYieldTarget.sol`. The PRD requires deleting the shim while preserving the defining file and other-family behavior (`REDESIGN_PRD.md:81,86`). Deleting a still-imported path is not the mechanical migration required.

**Sentence the plan must use:**

> First create the selected independent SY error declaration and repoint every source/test importer of `contracts/vaults/standard/sy/NativeStandardYieldExecutionTarget.sol` to the file that defines the symbol it uses, preserving behavior; then verify that no source import still references the shim, and only afterward delete that shim, retaining `NativeStandardYieldTarget.sol` and making no other-family architectural changes.

Historical prose mentioning the shim is not a Solidity importer. Conversely, an unexpected active importer must be handled within the specified mechanical migration or reported, not ignored to complete the deletion.

No new owner decision is needed on either point. These sentences remove inconsistent count/order instructions without changing the selected design. No compilation or runtime result is claimed.

I did not run Forge.
