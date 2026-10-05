# Kimi K3 — clarifying questions on REMEDIATION_PRD.md

Scope: questions whose answer would change the required fix, the acceptance test, or an
explicit non-goal. Where the PRD already decides the outcome (e.g., REQ-03's exact-error
pinning, REQ-04's per-family rounding disposition, REQ-06's rounding-consistency rule,
REQ-08's single-current-matrix-count rule), no question is asked. I have four questions.

---

## K-Q1 — REQ-01 and REQ-02: is residual-maintenance liveness a product requirement, or is fail-closed acceptable?

- **Affects:** REQ-01 (all seven catch groups in `UniswapV4DetfCommon.sol`), REQ-02
  (`previewResidualBuffer`).
- **Ambiguity:** Both REQs offer two dispositions — remove the catch so dependency
  reverts propagate, or keep it under a written owner amendment. The branches produce
  different user-visible behavior. Today, `_joinResidualCapped` / `_joinResidualUnbalanced`
  defer on `AlignmentNotAchievable`, `_retainSubSharePairResidual` retains sub-share dust
  locally, and `_parkUnmintablePairDust` can park residual into the SE; a zero quote from
  `previewResidualBuffer` routes to local retention. If all catches are simply removed,
  operations that currently complete with a deferred/parked residual will instead revert.
- **Outcomes that change the fix:**
  - (a) Residual-maintenance liveness is required → the implementer must draft per-site
    amendments (function, permitted error, retention/rollback semantics, at D49
    specificity) for owner sign-off, and acceptance tests assert the retained-residual
    outcome plus propagation of every other error.
  - (b) Fail-closed is acceptable → the catches are deleted, acceptance tests assert the
    exact propagated errors, and a liveness regression shows the supported join/bond
    flows still complete without the deferred-residual branch.
- **Why the PRD does not decide it:** The acceptance criteria are written to cover either
  branch symmetrically and never state which behavior the product wants. An implementer
  cannot write the owner amendment on the owner's behalf, and choosing branch (b) where
  the owner wanted (a) silently changes residual-handling behavior on live DETF flows.

## K-Q2 — REQ-05: what are the replacement-side equality and greater-than cases?

- **Affects:** REQ-05 acceptance criterion 1.
- **Ambiguity:** R3.3's "equality case and greater-than case relative to the old
  stored-total baseline" describes the preserved implementation's accounting (stored
  total vs deployed). The replacement FullSpread has no stored-total baseline of that
  kind; its book is local custody. The PRD says "Replacement credit is checked after a
  partial mismatch, an equality case, and a greater-than case relative to the old
  stored-total baseline," which cannot be applied literally to the replacement.
- **Outcomes that change the fix:**
  - (a) The equality/greater-than boundaries are preserved-implementation-only; the
    replacement-side control is a funded external pool trade (no vault synchronization)
    followed by a credit check → fewer, simpler replacement tests.
  - (b) The replacement must demonstrate analogous boundaries of its own model (e.g.,
    free sleeve empty vs present, partial mismatch against its local book) with credit
    asserted at each boundary → a larger test matrix whose exact boundary set the owner
    must name, because the reviewers cannot derive it from the old baseline language.
- **Why the PRD does not decide it:** It imports R3.3's old-baseline vocabulary while
  simultaneously requiring the control to bind the replacement. The existing supplement
  (`test_R3_3_deployedEqualsTotal_whenFreeSleeveEmpty`) gestures at (b) but was found
  mis-aimed; which boundary set closes the criterion is an owner/product decision.

## K-Q3 — REQ-07: is the gas-gated `quoteState` probe already authorized elsewhere, and is it load-bearing?

- **Affects:** REQ-07 disposition (removal vs amendment) and the risk assessment of
  removal.
- **Ambiguity:** The PRD states "D60 does not authorize a gas-dependent snapshot path,"
  but its own Inputs table records that not all reviewers read every open-item PRD —
  specifically the open-item-10 PRD underlying D59/D60, which restructured held-reserve
  valuation on all seven hooks and amended the rate provider twice during execution
  (initial-mint rate, metadata-scale conversions). Separately, if the snapshot path is
  load-bearing for correct rates on some SE family (e.g., an SE whose live-supply probe
  misprices an unlock-context state), removing it introduces a valuation regression of
  the same class REQ-07 exists to prevent.
- **Outcomes that change the fix:**
  - (a) A later ruling already authorizes the probe → REQ-07 becomes amendment-writing
    plus success/failed-call/short-data/low-gas tests and refreshed D48 evidence; no code
    removal.
  - (b) No authorization exists and the probe is not load-bearing → removal, with tests
    asserting the locked hard or exact-length failure behavior.
  - (c) No authorization exists but the probe *is* load-bearing for some family → the fix
    is neither deletion nor ratification but a bounded, gas-independent redesign the owner
    must specify.
- **Why the PRD does not decide it:** It asserts non-authorization from an input set it
  acknowledges was incompletely read, and it does not address whether removal degrades
  any production SE's rate. Both facts change what the implementer should do.

## K-Q4 — REQ-08: is the current FullSpread V4 package split itself within the authorized change set?

- **Affects:** REQ-08 scope of work (evidence remapping vs structural remediation).
- **Ambiguity:** The current V4 implementation is split into `fullSpread/hookless/` and
  `fullSpread/ponsFamilyV2Hook/` variants composed from separate inventory, protection,
  transition-planner, quote, and execution-context units, with an `operationScope`
  modifier. The locked plan authorized D19-style `Ext` splits for measured size overflow
  and named specific files; a multi-variant restructure with new shared components is a
  larger change than a D19 split. The PRD says "this does not prove the refactor is
  unauthorized or incorrect" — leaving both possibilities open.
- **Outcomes that change the fix:**
  - (a) The restructure was authorized (or is ratified now) → REQ-08 is the documented
    evidence-regeneration task: snapshot-to-current map, selector-set diffs, regenerated
    build/size/regression evidence.
  - (b) The restructure was not authorized → the remediation must first obtain a
    retroactive scope ruling, and the implementation work may include restructuring or
    reverting toward the named package shape before any evidence is regenerated. The
    acceptance tests then include authorization-dependent package/selector declarations,
    not just evidence citations.
- **Why the PRD does not decide it:** It deliberately suspends judgment on authorization
  while requiring evidence bound to the current tree. If the tree's structure itself
  lacks owner approval, binding evidence to it certifies a scope that was never granted.

---

No further blocking questions. REQ-03, REQ-04, and REQ-06 are specific enough to
implement without an owner choice.
