# Grok questions on the remediation PRD

Reviewer: Grok. Targeted follow-up only. No new defects. No peer question files were read.

One blocking question. REQ-01 through REQ-06 and REQ-08 can be implemented without another owner choice: where those requirements say "remove or amend," the amendment exists only if the owner has already written it, and the search recorded in the PRD did not find one. The implementer therefore removes the unauthorized catch or mis-label, and pins the exact error or exact residual the current production path already defines. That is specific enough.

## GQ-01

- **Id:** GQ-01
- **REQ:** REQ-07
- **Ambiguity:** The removal branch still says a failed `quoteState` must follow "the locked hard or exact-length rule." Those are different behaviors. The acceptance test then says to assert "the approved rate or the approved revert," which also does not pick one.
- **Outcomes that change the fix:**
  1. Delete the soft snapshot. `_getRate` does not call `quoteState`. The live-supply probe is the only empty-state path. Tests must not require a snapshot call. A low remaining-gas call still returns the live-probe rate, or reverts only if that live probe reverts.
  2. Keep a `quoteState` read, but failure is a hard revert of the public rate call. No fall-through to the live-supply probe. Tests expect that revert on a failed call, a short reply, and a budget that cannot pay for the snapshot.
  3. Keep a `quoteState` read, but failure uses the D48 exact-length rule: failed call or a reply that is not exactly 32 bytes does not revert, and the existing search continues on the live probe or on `(false, 0)`. Tests expect the approved rate, not a revert, for those three failure shapes.
- **Why the PRD does not already decide it:** REQ-07 allows an owner amendment to keep the gas-gated fall-through, and otherwise requires removal plus "the locked hard or exact-length rule." D48's exact-length rule applies to `_safePreviewExchangeIn`. The same requirement says other dependency failures stay hard, and that D41 and D49 do not permit this path. It never says whether this `quoteState` call is deleted, reverted, or converted to exact-length. The non-goal only preserves `_safePreviewExchangeIn`. It does not choose among the three `_getRate` outcomes above.
