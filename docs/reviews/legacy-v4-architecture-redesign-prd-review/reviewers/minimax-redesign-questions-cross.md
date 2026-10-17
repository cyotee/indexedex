# MiniMax M3 — Legacy V4 redesign question cross-review

- **Date:** 2026-10-14
- **Reviewer:** MiniMax M3, one cross-review continuation. No peer original used as authority. No PRD or code was read or written this round except the three peer question passes and my own question pass. No Forge run. No exploit procedure.
- **Question:** Agree or dissent: no owner question remains on the rewritten design. If you still have one, ask it in one sentence.
- **Verdict:** **Agree. No owner question remains.** I am not asking the owner anything.

## Agreement with the three peer question passes

All three peers reach the same conclusion. My own question pass (`minimax-redesign-questions.md`) reaches the same conclusion. Four independent reads reach the same verdict for the same reasons.

- **Astra** (line 3): "Ready for implementation planning. No owner question remains on the product decisions in this document."
- **Astra** (line 28): "Blocking owner questions: None. Non-blocking owner questions: None."
- **Grok** (line 6): "No owner question remains."
- **Kimi** (line 9): "Answer: no owner question remains — ready."
- **Mine** (`minimax-redesign-questions.md`): "No owner question remains. The rewritten design closes every choice."

The four reads agree because the rewritten PRD closes every choice that an implementer might otherwise re-interpret:

- D1-D9 are all "Decided" or "Decided by this rewrite" (lines 100-108). No "Assumed" rows remain.
- The component paths and one responsibility each are listed (lines 21-31).
- Every installed selector and its one facet owner is named (lines 39-61).
- The keep / move / delete list is enumerated (lines 75-88).
- The Dissent section at lines 120-122 explicitly records what was rejected: MiniMax's retained delegates, Astra's sixteen-facet split, Kimi's first design's dual-token merge. The owner direction is reflected in the rewritten document.
- The Call shapes (lines 65-74) and Size limits (lines 90-94) are specified.
- The pretransfer credit residual is explicitly out of this item (line 113: "Do not repair the stored-reserve pretransfer credit residual in this redesign. Preserve the current calculation. A correction of that residual is a separate owner-ruled item.").

The four reads agree because the rewritten document's text is closed. No owner question is left for the implementer to ask. The mechanical closures that the plan must state are listed in all four reads and are not owner questions.

## What I am not asking

- I am not asking the owner to name a file, error, or line layout. The document already names each path, each error interface, and the function layouts.
- I am not asking the owner to pick a selector owner. The document's selector table names one owner per selector.
- I am not asking the owner to pick a component. The document's component table names each component's path and one responsibility.
- I am not asking the owner to pick a size target. D9 says 24,576 hard, 23,000 advisory.
- I am not asking the owner to pick whether the delegates are kept. D4 says delete both.
- I am not asking the owner to pick whether the callback facet is added. D4 says one callback facet.
- I am not asking the owner to pick whether the SY import shim is removed. D3 says delete it.
- I am not asking the owner to pick whether the pretransfer credit residual is corrected. The non-goal at line 113 says preserve the current calculation; the correction is a separate owner-ruled item, explicitly out of this PRD.
- I am not asking the owner to pick a testing strategy. The plan reuses the existing suites.
- I am not asking the owner to pick the deploy order. The DFPkg install order is specified at line 63.

## Mechanical closures the plan must state

The four reads converge on the same list. I do not repeat the full list; I refer to my question pass (`minimax-redesign-questions.md`) for the ten mechanical closures. The key shared items across the four reads are:

- **Edit order:** delete nothing before callers are rewired. Move bodies into the six internal libraries first; rewire targets/facets; delete the two delegates and their wiring only after their last callers are gone; delete `Common` / `InBase` / `OutBase` / `OutTarget` only after a zero-reference search; then the SY shim deletion and error-namespace repoint, with other families' import-path edits last and mechanical.
- **Disposition of `UniswapV4StandardYieldExecutionTarget.sol`:** the file stays as the legacy family's SY hook layer (`_redeemVaultHeld` / `_standardRoute` overrides and `_settleNamedHolder`), narrowed to call the internal libraries, with the REQ-V4-02 `_requireNotDisabled` on the SY money entries.
- **Measured units:** every deployed family facet, 24,576 hard / 23,000 advisory, measured after the artifact refresh.
- **Test gate:** the existing legacy V4 suites run unchanged against the rebuilt package through the updated TestBase; the plan forbids rewriting assertions to bless the old hops.
- **Search preconditions:** the zero-importer search for `UniswapV4StandardExchangeOutTarget.sol` and the repository-wide consumer search before any quote-helper deletion are plan steps, not options.

## What I am not adding

- I am not adding findings the four reads already cover.
- I am not asking a fifth question. The four reads converge on "no owner question."
- I am not proposing an alternative architecture. The Dissent section at lines 120-122 records what was rejected; the rewritten document's choices are closed.

## Verdict

**No owner question remains.** The rewritten design closes every choice. A later plan can be written from the rewritten document alone. The mechanical closures the plan must state are listed across the four reads.

I did not run Forge.