# MiniMax M3 — Legacy V4 architecture-redesign PRD review cross-review

- **Date:** 2026-10-14
- **Reviewer:** MiniMax M3, one cross-review continuation. No peer original used as authority. No draft, plan, or REMEDIATION_PRD.md was read or written this round except the three peer originals and my own original. No Forge run.
- **Question:** Agree or dissent on (1) the draft is a useful direction, not a ready flattening PRD, (2) it does not name the successor components or selector owners, (3) the four assumed decisions still need an owner.

## Verdict

**Agree with all three peers on all three points.** The draft is a useful direction, not a ready flattening PRD. It does not name the successor components or selector owners. The four assumed decisions (D3, D4, D7, D9) still need an owner.

The three peers reach the same conclusion by the same path. My own original reaches the same conclusion. Four independent reads (three peers plus mine) reach the same verdict for the same reasons.

## (1) The draft is a useful direction, not a ready flattening PRD

**Agree with all three peers.**

- **Astra** (line 7): "The intent is sound, but this is not yet an implementation-ready flattening PRD. It is a useful set of redesign constraints and discovery/validation tasks. It does not specify the resulting architecture sufficiently to prevent a later planner or implementer from designing it."
- **Grok** (line 6): "The intent is sound. The draft is not yet that PRD. It is a process document that defers the architecture."
- **Kimi** (line 11): "The draft's intent is sound and honestly framed: it correctly identifies the family's real structural problems... But measured against the rubric for a flattening PRD — name the resulting components, the selector ownership, and what is deleted, and leave no implementer architecture choice — the draft is a **direction and process document, not yet that PRD**."
- **Mine** (`minimax-original.md` F1): "The draft is a process document that defers the implementer architecture choices (resulting component files, selector-to-facet table, complete deletion list, validation consolidation rules)."

The four reads agree because the draft explicitly defers the architecture: line 47 says "The implementation plan fixes component paths, dependencies, and selector ownership before coding"; line 99 says "Freeze a complete selector-to-facet table in the implementation plan"; line 167 says "_no plan yet_". An implementer handed this draft must design the architecture the draft exists to define.

I do not dissent.

## (2) It does not name the successor components or selector owners

**Agree with all three peers.**

- **Astra** (line 19-24): "A flattening PRD must name the resulting components, their dependencies, and the owner of every installed selector, leaving no implementer architecture choice. Here the document lists responsibility categories and instructs a future plan to supply that design. 'Narrowly scoped internal components' at 43 does not identify files or interfaces. 'Measured operation/query groups' and opportunities to consolidate groups at 98 do not select the facet partition."
- **Grok** (line 23-26): "A flattening PRD names the resulting components, selector ownership, and what is deleted, and leaves no implementer architecture choice. This draft says the later plan must produce the selector manifest, component paths, dependencies, and one owner per selector (`:36-37`, `:47`, `:99`). Execute says `_no plan yet` (`:167`)."
- **Kimi** (line 13, 21): "What the family is *rebuilt as* is described only by properties ('narrowly scoped internal components for configuration/storage access, accounting/quotes, custody, pool operations, and reserve management', `:43`) without naming those components, their file paths, their contents, or their consumers. The draft instead requires a future plan to (a) invent the component inventory that replaces `UniswapV4StandardExchangeCommon`... (b) decide whether and how 'smaller groups' consolidate... (c) draw the selector-to-facet map."
- **Mine** (`minimax-original.md` F1): "Decide which files replace the all-purpose `UniswapV4StandardExchangeCommon`... Decide which selectors go on which facets... Decide which validations to consolidate... Decide which unused legacy zap helpers to remove... Decide the concrete operation inputs with explicit `payer`, `holder`, `receiver` roles."

The four reads agree because the draft's own text confirms the deferral: line 42-43 lists five categories ("configuration/storage access, accounting/quotes, custody, pool operations, and reserve management") without naming files; line 47 says the plan fixes the components; line 100 says the plan freezes the selector table; line 167 says the plan doesn't exist.

I do not dissent.

## (3) The four assumed decisions still need an owner

**Agree with all three peers.** D3, D4, D7, and D9 are marked "Assumed" at draft lines 157, 158, 161, and 163. The four peers each ask the owner to ratify or amend these.

- **Astra** (line 60-63): "D3, blocking for the shared-SY migration... D4, blocking for the architectural specification... D7, blocking for storage-layout cleanup... D9, non-blocking to the established hard cap but needed to close the assumption."
- **Grok** (line 40-44): "D3, D4, D7, and D9 are marked 'Assumed.' Elsewhere shim removal, a dedicated callback facet, fresh-instance storage cleanup, and size targets are written as required outcomes. D1/D2/D5/D6/D8 are marked decided. I do not reopen them."
- **Kimi** (line 42-43): "The Decisions table marks D3, D4, D7, and D9 'Assumed.' Does the owner ratify all four as written — specifically D4's dedicated-callback-facet shape and D9's 23,000-byte design target — or amend any of them before the component/selector inventory is frozen?"
- **Mine** (`minimax-original.md` Q1-Q4): four one-sentence owner questions for D3, D4, D7, and D9.

The four reads agree because the draft's own table marks the four decisions as "Assumed," which by the council's own rule ("the owner requires that it does not") means they cannot be implemented without owner ratification. The four peers' questions are consistent: ratify or amend.

I do not dissent.

## What I am not adding

- I am not adding findings the four reads already cover.
- I am not asking the owner a fifth question. The four questions from my original (and the peers' questions) cover the four Assumed decisions. One consolidated question per decision is the format the four reads converged on.
- I am not proposing a replacement architecture. The coordinator said "Do not invent a replacement architecture."

## Verdict on whether the council should treat this draft as ready to implement

**No.** The draft is a direction and process document. The architecture is deferred. The four Assumed decisions require owner ratification. The 31,908-byte figure is a claim, not a saved measurement. Four independent reads reach the same conclusion.

I did not run Forge.