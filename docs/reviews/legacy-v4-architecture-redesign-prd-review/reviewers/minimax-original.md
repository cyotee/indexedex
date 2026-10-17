# MiniMax M3 — Legacy V4 architecture-redesign PRD review

- **Date:** 2026-10-14
- **Reviewer:** MiniMax M3, independent quality review. No peer notes read. No code, plan, or REMEDIATION_PRD.md was read or written this round except the draft itself and the cited source files. No Forge run. No exploit procedure.
- **Verdict (yes/no on whether the council should treat this draft as ready to implement):** **No.**

## Summary

The draft is a process document with ten requirements, a validation matrix, nine decisions, and an explicit "_no plan yet_" placeholder at line 167. It is not yet the flattening PRD the implementer can execute from without making architecture choices. Per the coordinator's criterion — "A good flattening PRD names the resulting components, selector ownership, and what is deleted, and leaves no implementer architecture choice. A process document that defers those choices is not yet that PRD" — the draft fails on the resulting-components and selector-ownership points. The implementer will have to choose which files to create, which selectors go on which facets, and which declarations to remove.

The 31,908-byte figure is a claim, not a saved measurement. I did not find a saved measurement log for the InFacet. The draft cites partial compiler source-map attribution and acknowledges that those attributions "are partial compiler attributions, including instruction operands, not measurements of removable bytes." The plan must measure the actual size after the edit.

The "Decided" vs "Assumed" decision table at lines 153-163 leaves four architecture-shaping decisions as "Assumed" without owner sign-off. The implementer cannot choose them. They are listed below.

## Findings

### F1 — The draft is a process document, not yet a flattening PRD

- **Severity:** Medium (the coordinator's criterion is not met; the implementer cannot execute without architecture choices)
- **Section:** Requirements, items 2-9
- **Broken requirement / invariant:** A flattening PRD must name resulting components, selector ownership, and what is deleted. The draft defers all three.
- **Impact class:** Implementation ambiguity. The implementer is asked to:
  - Decide which files replace the all-purpose `UniswapV4StandardExchangeCommon` (Requirement 2, line 42-43 lists five categories but no file paths).
  - Decide which selectors go on which facets (Requirement 9, line 98-101: "Keep external execution, public previews/discovery, transition simulation, reserve management, and position import as explicit selector groups"). Line 100 says "Freeze a complete selector-to-facet table in the implementation plan, with one owner per selector" — that table is deferred to the plan.
  - Decide which validations to consolidate (Requirement 4, line 61: "Consolidate repeated validation where a single check demonstrably dominates every relevant path").
  - Decide which unused legacy zap helpers to remove (Requirement 5, line 70: "Remove unused legacy zap quote helpers and their exclusive dependencies only after a repository-wide caller inventory proves they have no consumers").
  - Decide the concrete operation inputs with explicit `payer`, `holder`, `receiver` roles (Requirement 2, line 46: "Use structs where stack pressure requires them" — when to use structs is an implementer choice).
- **Fix direction:** Name the resulting files, freeze the selector-to-facet table, complete the deletion list, and state the consolidation rules. Alternatively, this draft stays as a process document and a follow-on PRD freezes those decisions before implementation.
- **Confidence:** High (text is unambiguous that the draft defers those choices to "the implementation plan" at lines 47, 100, 110).

### F2 — The 31,908-byte figure is a claim, not a saved measurement

- **Severity:** Low (the draft acknowledges the attribution is partial and the design target is 23,000 bytes)
- **Section:** Summary, paragraph 3 (line 14-16)
- **Broken requirement / invariant:** The coordinator's instruction: "Treat its 31,908-byte figure as a claim unless you find a saved measurement. A present assertion is not a pass."
- **Observed fact:** I searched `docs/` and `docs/audits/` for a saved log containing "31,908" or a saved InFacet size measurement. No saved measurement was found. The figure is stated in the draft only. The draft cites partial compiler source-map attributions: "8,864 runtime instruction bytes to `UniswapV4StandardExchangeCommon.sol`, 2,509 to `UniswapV4StandardExchangeInBase.sol`, 2,331 to Crane's `UniswapV4Quoter.sol`, and 849 to `NativeStandardYieldTarget.sol`."
- **Impact class:** Size-gate uncertainty. The hard limit is 24,576 bytes (line 103, line 41). The design target is 23,000 bytes (line 103). The 31,908-byte claim is consistent with exceeding the limit by 7,332 bytes, but a saved measurement log is not provided. The plan must measure the actual size after the edit, not rely on the claim.
- **Fix direction:** Either produce a saved measurement file (e.g., `docs/reviews/legacy-v4-architecture-redesign-prd-review/evidence/facet-size.txt`) or treat the figure as a claim and measure after the edit. The plan must report the measured size, not the claimed size.
- **Confidence:** High (the absence of a saved log is verifiable by glob; the claim is in the draft text).

### F3 — Decisions D3, D4, D7, D9 are marked "Assumed" without owner sign-off

- **Severity:** Medium (the implementer cannot choose these; they are product and architecture decisions)
- **Section:** Decisions table, lines 153-163
- **Broken requirement / invariant:** The coordinator's instruction: "Ask an owner question only when the draft marks a decision assumed or leaves a product choice."
- **Observed facts:**
  - **D3** (line 157): "Remove the execution import shim and simplify shared SY declaration scaffolding; other families receive mechanical compatibility changes only." Status: **Assumed**. This is an architecture choice (which shim, which declarations, which cross-family boundaries). Other families include V3 FullSpread, hookless V4, Pons-family V4, and V4 hook products.
  - **D4** (line 158): "Use a dedicated callback facet and measured operation/query groups; no replacement execution delegates or self-call reuse." Status: **Assumed**. This is an architecture choice (which selectors go on which facets, whether the callback facet is dedicated or shared with other operations).
  - **D7** (line 161): "Target fresh package instances and remove proven-unused family state; no existing-instance migration." Status: **Assumed**. This is a migration-scope choice.
  - **D9** (line 163): "Hard runtime limit 24,576 bytes; design target 23,000 bytes per facet." Status: **Assumed**. The hard limit is established by EIP-170; the design target adds 1,576 bytes of headroom. The 23,000 figure is an implementer choice, not an owner decision.
- **Impact class:** Implementation blocker. The implementer cannot choose these without owner sign-off.
- **Fix direction:** Ask the owner to confirm or change each Assumed decision before implementation begins. If the owner confirms, the draft can be re-issued with status "Decided" on those rows.
- **Confidence:** High (text is unambiguous; "Assumed" is the explicit status field).

### F4 — The "Decided" decisions are consistent with current source and existing owner rulings

- **Severity:** Low (informational; the "Decided" rows are correct)
- **Section:** Decisions table, lines 153-163
- **Observed facts:** The "Decided" decisions correspond to recorded owner rulings and the REQ-V4-01 / REQ-V4-02 PRDs:
  - **D1** (line 155): aligns with the source request at line 6 ("I agree. This will also make it easier to segment the external functions to reduce the size. Please write a PRD file defining your suggestions.") and the prior owner objective at line 7 ("redesign the whole thing from the ground up for the same functionality").
  - **D2** (line 156): aligns with the prior owner objective ("same functionality").
  - **D5** (line 159): aligns with DETF alignment §24.7 and the existing D57-D59 product law.
  - **D6** (line 160): aligns with the REQ-V4-02 PRD acceptance criteria at `apex-remediation-application-2026-10-14/REMEDIATION_PRD.md:88-91` and the owner selection "Include the corrections" on 2026-10-15.
  - **D8** (line 162): aligns with the owner selection "Propagate protocol errors" on 2026-10-15.
- **Impact class:** None. The "Decided" rows are correct.
- **Fix direction:** None for these rows.

### F5 — The draft explicitly says "_no plan yet_" and the implementer is asked to author the plan

- **Severity:** Low (informational; the draft self-identifies as incomplete)
- **Section:** Execute (lines 165-168)
- **Observed facts:** Line 167-168: "## Execute / _no plan yet_. Review this draft before creating its sibling implementation plan. Writing this document does not execute either the redesign or the earlier remediation plan."
- **Impact class:** Process note. The draft self-identifies as a process document, not the flattening PRD.
- **Fix direction:** None. The implementer is asked to create the implementation plan after this draft is approved.

## Owner questions

The draft marks four decisions as "Assumed" without owner sign-off. Per the coordinator's instruction, I ask them in four sentences.

**Q1.** Is D3 ("Remove the execution import shim and simplify shared SY declaration scaffolding; other families receive mechanical compatibility changes only") approved? The "Assumed" status is at line 157. Other families include V3 FullSpread, hookless V4, Pons-family V4, and V4 hook products. If yes, the implementer can remove `contracts/vaults/standard/sy/NativeStandardYieldExecutionTarget.sol` (5-line import-only shim) and the compatibility aggregate as error namespace.

**Q2.** Is D4 ("Use a dedicated callback facet and measured operation/query groups; no replacement execution delegates or self-call reuse") approved? The "Assumed" status is at line 158. If yes, the implementer can place `unlockCallback(bytes)` in a dedicated legacy V4 callback facet and freeze a selector-to-facet table with `unlockCallback` in that facet and other selectors in explicit groups (external execution, public previews/discovery, transition simulation, reserve management, position import).

**Q3.** Is D7 ("Target fresh package instances and remove proven-unused family state; no existing-instance migration") approved? The "Assumed" status is at line 161. If yes, the implementer can remove proven-unused family state during the redesign without advertising storage-compatibility with existing deployed instances.

**Q4.** Is D9 ("Hard runtime limit 24,576 bytes; design target 23,000 bytes per facet") approved? The "Assumed" status is at line 163. The hard limit is EIP-170. The design target adds 1,576 bytes of headroom below the limit. If yes, the implementer measures each facet's runtime after the edit and reports a target miss below the hard limit as a recorded gap.

If any of Q1-Q4 is "no" or modified, the draft must be re-issued before the council can treat it as ready to implement.

## What I am not doing

- I am not proposing a replacement architecture. The coordinator says "Do not invent a replacement architecture." The draft's component categories, validation consolidations, and selector groups are listed; the implementer picks the specific files and specific assertions within those categories.
- I am not proposing which files to delete or which to keep. The draft lists deletion categories; the implementer does the inventory.
- I am not proposing a new size target. D9's 23,000-byte target is a draft proposal; the owner must confirm.

## Verdict on whether the council should treat this draft as ready to implement

**No.** The draft is a process document that defers the implementer architecture choices (resulting component files, selector-to-facet table, complete deletion list, validation consolidation rules). The four "Assumed" decisions (D3, D4, D7, D9) require owner sign-off. The 31,908-byte figure is a claim, not a saved measurement. Until the implementer has a flat resulting-architecture PRD (with named files, named facets, named deletions, named selector ownership) and the four "Assumed" decisions are confirmed by the owner, the draft is not ready to implement.

I did not run Forge.