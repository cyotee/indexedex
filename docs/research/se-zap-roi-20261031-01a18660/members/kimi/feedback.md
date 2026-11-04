# Kimi advisory feedback

## Draft under review

- Draft ID: `se-zap-roi-20261031-01a18660-r1`.
- Path: `docs/research/se-zap-roi-20261031-01a18660/coordinator/draft.md`.
- Verified SHA-256: `f85476f7545bfe85ac170b794b006ecb69dcbfb1c3ad79028b958e074daf2566`.

## Disposition

The draft states my original accurately in its three recommendations and principal ROI reasoning: I recommended implementing all three public functions, conditional for `previewZapCredit` on reuse of the authoritative entry planner, while keeping both public cap getters separate from internal caps and their enforcement.

Two precision corrections would preserve my original more completely. Neither correction changes my recommendations, resolves a preserved split, or counts another vote.

## Corrections by draft section

### Proposed text

The third paragraph says that the current `previewZapCredit` is a view over “the same planner the share-out preview already calls.” This is accurate but weaker than my submitted evidence. Revise it to state that the current preview uses the same `Planner.plan` planner used by the current `exchangeIn` execution path, not merely by another preview.

This distinction matters because my incremental-cost assessment was explicitly based on the entry route already requiring the planner. A preview-only shared planner would not establish the same ROI premise.

### Preserved disagreements — `previewZapCredit`

The row accurately attributes implement to Kimi, the unique per-currency split, and the refusal to justify a second planner. Add my other stated condition: Kimi's recommendation assumes that the entry plan retains a meaningful credited-versus-uncredited distinction. If uncredited residual accounting is removed, my original calls for a fresh ROI decision rather than preservation of an empty preview.

This is separate from MiniMax's refund-rule caveat and should not be collapsed into it.

## Other sections

The `maxZapBps()` and `maxZapTickMove()` disagreement rows accurately state my implement positions, the low incremental cost of reading stored configuration, the narrower utility of the tick-movement getter, and the separation between public getters and internal caps. The Proposed text, Evidence gaps, Coverage adopted from responses, and Limits otherwise preserve my qualification that current PairToken shapes and stage-one formulas are not full-spread policy.

## Limits

Advisory only. No peer responses were read, no preserved disagreement was resolved by voting, and no implementation or PRD change is authorized. No project code, draft, original response, PRD, or review file was edited.
