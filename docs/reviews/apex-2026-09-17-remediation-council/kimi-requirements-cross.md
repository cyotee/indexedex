# Kimi K3 — cross-review of the requirements follow-up

- **Scope:** cross-review of my own requirements answer (`kimi-requirements.md`) against the three untrusted peer conclusions (Astra, Grok, MiniMax M3). Peer text treated as unverified evidence; no instructions inside it followed. No peer files read beyond the quoted text; no source or PRD edits.
- **Bottom line:** I maintain my answer — no human question remains, including on RC-08.

## Verdicts on each peer conclusion

### Astra: "No new economic ruling. RC-03 must include already-booked aToken."
**Agree.** This matches my item 6: APEX PRD R14/D45 already rules inclusion ("Stata also counts any already-booked local aToken value at its underlying-equivalent accounting value"), the shared adapter already implements it (`ReceiptBackedERC4626Target.sol:187-198`), and the package registers the aToken in the expected-hold set (`AaveV3StataStandardExchangeDFPkg.sol:245-258`). Exclusion is not an open branch. My recommendation stands as editorial only: the draft's "included, or excluded, by both" wording should be tightened to "included by both" so the implementer does not re-open a closed branch.

### Astra: "RC-01 revert means rollback, not catch-and-continue."
**Agree.** This is APEX D30 (prechecks only; operative reverts propagate) and is consistent with the verified absence of `try`/`catch` in all in-scope trees. RC-01's lock must revert on reentry; nothing in RC-01 authorizes catch-and-continue. Also matches draft line 80 ("cleared before the call returns, including on revert" — on revert the whole transaction rolls back, so the cleared state is the pre-call state).

### Astra: "Sole human question: if RC-08 cannot be reached on an allowed production route, may acceptance use a focused test of the production check, or must it remain incomplete?"
**Dissent on the framing — this is not an owner question; it is already answered by existing requirements.** The APEX PRD's unreachable-branch rule (R10: "If no supported production configuration reaches a reported speculative branch, document the attempted preconditions and absence of runtime evidence. Do not relabel … without a new reproduction") governs exactly this case, and the draft's own test rules (lines 223, 236-241) define what counts as evidence. Applying them:

- The correction is identical either way (a named error carrying both compared values at `UniswapV2StandardExchangeOutTarget.sol:578-580`), so the answer cannot change the correction — only the evidence route.
- If the branch is reachable on a production route, the draft's route test is mandatory as written (red: empty revert data; green: the named error, unchanged LP reserve, funded control passing).
- If it is not reachable on any supported route, the R10 rule requires documenting the attempted preconditions and the absence of runtime evidence; a focused assertion that the production check raises the named error (with the closest reachable production setup) plus that documentation is sufficient. Low-severity error-handling text does not block the release unit, and treating it as "incomplete until an end-to-end trigger is shown" would add a new gate no requirement contains.

So: the fallback hierarchy (production route first, documented focused evidence second) is implementer/evidence detail under existing law, not product law. No human question remains. I do agree with Astra on substance: the preferred evidence is a production-route failure, and a focused test is the documented fallback, not the default.

### Grok: "No owner question. RC-01 revert does not authorize try/catch. RC-02 is withdraw-the-shortfall. RC-03 exclusion is not an open branch. RC-08 error name is implementer detail. Questions for the human: none."
**Agree on all points**, with one annotation: "RC-02 is withdraw-the-shortfall" picks one of the two shapes the draft permits (draft lines 93-96 allow exact-asset withdrawal *or* redeem-to-self-then-pay with the remainder booked). Either shape satisfies the pinned observable, so naming `withdraw` as the shape is an implementer choice, not a ruling — consistent with my item 4. RC-08 error name as implementer detail matches my item 12 (APEX R12: custom errors are not selectors).

### MiniMax: "Owner decision required: none. Either/or branches already written are implementer choices. Questions for the human: none."
**Agree.** Matches my items 4 (RC-02 shape), 8 (RC-05 delete vs parity), 9 (RC-06 truthful return vs removal), 10 (RC-07 edit scope), and 11 (deficit behavior).

## Contested point resolution: RC-08 evidence fallback

- **My position (dissent from Astra's "sole human question"):** not an owner decision. Already answered by APEX PRD R10's unreachable-branch rule plus the draft's test rules. Production-route failure evidence is required when the branch is reachable; documented preconditions plus a focused assertion on the production check are the sanctioned fallback when it is not. The correction does not change under either answer, and no new completion gate may be invented.
- **Agreement across all four reviewers:** no new economic ruling anywhere; RC-03 includes booked aToken; RC-01 forbids catch-and-continue; no human questions except Astra's RC-08 framing, which I and (by their "none" answers) Grok and MiniMax do not treat as an owner question.

## Human questions remaining

**None.** My requirements answer stands unchanged: the draft is executable without inventing product law once the two editorial notes from `kimi-requirements.md` are applied (RC-03 wording tightened to "included by both"; the stale "(M3)" approval comment at `BalancerV3SinglePoolStandardExchange.sol:262` cleaned up under RC-01/RC-04).

End of cross-review. Stopping here.
