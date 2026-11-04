## Identity

- Run: `se-fullspread-hook-matrix-20261104`.
- Member: astra.
- Profile: research.
- Phase: one advisory review of the frozen draft.
- Requested role: council-member.
- Requested model: `chatgpt-subscription/gpt-6-astra:high`.
- Actual runtime role, model, and reasoning setting: not exposed.
- Peers read before submission: no.

## Draft under review

- File: `docs/research/se-fullspread-hook-matrix-20261104/coordinator/draft.md`.
- Draft ID: `draft-se-fullspread-hook-matrix-20261104-r1`.
- Coordinator-supplied raw-file SHA-256: `0ee55f1e89a984afe5b6f20fe2491b7220f7114bd1ea8120da99aaf57482932c`.
- Provenance: supplied by the coordinator; not recomputed.
- The complete frozen draft and the run brief were read. No different draft was substituted.

## Disposition

requested-changes

The draft correctly identifies the seven live behaviors, preserves the V3 rows, names concrete V4 row files, separates PoolKey currencies from buffered share inventory, and distinguishes exact-input directions from exact-output support. Its PairToken choice and direct-row adaptation are acceptable choices in place of my original alternatives. The remaining corrections concern incomplete bindings and contradictory implementation instructions, not that choice.

## Concerns

**1. Section 12, “Other SE,” and “Dual”: the identity rejection must not imply an unspecified runnable replacement.**

The draft fixes the dual arguments to PairToken as both the second SE and its leg token. It correctly says an identity rejection is not a pass and does not close FS-A26. It then says, “The runnable proof is the share transfer the hook accepts without calling that vault.”

That sentence does not specify a different accepted configuration, and the preceding configuration may be the one rejected. One implementer could retain the identity bind as unresolved; another could treat PairToken shares as an unbound raw currency or change the SE argument and call that the canonical proof. Those are different bindings. FS-HOOK-02 permits a share transfer that the hook actually accepts; it does not establish acceptance merely because conversion is forbidden.

Correction: retain the selected `(standardExchange1 = PairToken, token1 = PairToken share)` bind and state that it is a passing transfer-only proof only if that exact configuration is accepted and executes without a PairToken money call. If it rejects, retain the FS-HOOK-04 record and the open canonical proof. Remove the unconditional “runnable proof” sentence; do not imply an unnamed substitute configuration.

**2. Sections “Other SE,” “Dual,” “Orbital,” “Weighted” N3, “Curve quad,” and “Balancer quad” five-leg: PairToken's provider is not bound completely.**

This vault's providers have explicit `reserveVault`, `rateSubject`, and `rateTarget` arguments. The PairToken provider is only “that vault's own provider” or “its own provider.” The draft neither names that instance's deployment/binding nor fixes its target. In the larger weighted and Balancer descriptions, the PairToken token role is stated but the complete matching SE/provider array record is not repeated or unambiguously defined by a common record.

Two implementers could use a provider quoting PairToken shares into different underlying faces, or interpret “own provider” as a getter on the vault rather than a separately configured instance. A token address and the statement “not asked to convert” do not resolve valuation denomination.

Correction: define one common PairToken identity-leg record, including the exact token and SE addresses, provider instance, provider argument triple, and selected target/denomination. Apply that same record to the dual, orbital, N3 weighted, Curve, and five-leg Balancer rows. State how the companion raw test tokens are denominated for the stable fixtures; do not infer a peg from share decimals. This does not require changing the chosen PairToken family.

**3. Section 12 introduction and “Migration”: the prohibition on editing behaviors conflicts with required inherited decoder migration.**

The introduction says, “Do not edit the seven behavior contracts.” Later, the draft says, “One-word `previewExchangeIn` comparisons in inherited bind tests read `amountOut` after the migration below.” The migration is repo-wide and explicitly includes implementations, overrides, callers, helpers, and tests.

The previously read behavior sources contain those one-word expressions in their own test bodies. Overriding a test in the new row does not remove the inherited source from compilation. One implementer would change those expressions mechanically; another would obey the absolute no-edit sentence and leave code that cannot compile against the widened return.

Correction: make the prohibition apply to behavioral assertions and other families' expected results, with an explicit exception for the required mechanical tuple-decoder migration. Keep family-specific expected-result changes in the new rows. The same qualification belongs in “Rejected alternatives” and the proposed section 3 replacement if they are intended to prohibit all edits rather than assertion changes.

**4. Sections “Dual,” “Orbital,” “Weighted” N3, “Curve quad,” and “Balancer quad”: overriding setup and bind assertions does not adapt the inherited execution helpers to the selected legs.**

The draft specifies mixed legs and new cardinalities, but it does not consistently say which remaining inherited test entrypoints must stop using helpers that assume the old layout. Examples from the behavior files read during the independent pass:

- Weighted `_amounts` constructs two entries, and `_joinBoth` uses it. An N3 setup alone does not change those helpers.
- Curve `_amounts`, `_fixtureOf`, and the per-leg funding paths assume four nonzero fixtures. The proposed two raw legs and PairToken identity leg are not four V4 fixture faces.
- Balancer amount, funding, and balance loops use `LEGS = 4`. Avoiding `_buildLegs` and `_rowPkgArgs`, and changing the bind test's token-count assertion, does not change the helpers called by the remaining tests.
- Dual's other-leg funding uses the second fixture's `fund`. That cannot be copied as minting PairToken shares; the selected shares must already have been acquired outside the unlock.

One implementer could override every affected test body and use role-aware helpers; another could override only the entrypoints explicitly named and retain invalid two/four-leg or all-buffered assumptions. Both would appear to follow the draft.

Correction: specify that each mixed-leg or variable-count row overrides every inherited public test entrypoint that reaches an incompatible fixed-size or all-fixture helper. Name the family-local replacement helpers' responsibilities: runtime-length amount arrays, funding raw tokens through their token fixture, funding the V4 face through the V4 fixture, transferring pre-acquired PairToken shares, and measuring inventory by leg role. Preserve the shared behaviors' other-family expectations. Do not try to override a non-virtual internal helper or make it virtual as a workaround.

**5. Sections with “does not call `super.setUp()`”: the retained TestBase initialization step is missing.**

Avoiding the behavior's old same-family setup is correct. However, the draft forbids `super.setUp()` without stating how the ancestor TestBase initialization still runs. The row factory path and `_ctx()` depend on initialized manager, factory, registry, facets, router, and package handles.

An implementer could call the appropriate TestBase setup directly and then perform the new row setup; another could omit ancestor initialization and try to construct the fixture from uninitialized context. “Deploys through the same package factory” does not resolve that initialization order.

Correction: distinguish the skipped `*_SeMatrixBehavior.setUp()` from the required underlying TestBase initialization. State that the row explicitly initializes that existing TestBase once, then constructs the fixture, binds the selected hook arguments, and funds the role-specific legs. This is a clarification of the existing harness path, not a new harness.

**6. Section 12 “Index rule” and the two-target cases: address-rank descriptions do not require both physical index placements.**

The index rule correctly computes whichever order happens to occur. The second target case changes the face from backing `currency0` to backing `currency1`, but both addresses can still be on the same side of the counter-leg address. Thus both target cases can leave this vault's buffered leg at the same product-pool index. Running both swap directions does not change its index.

The governing FS-OWN-29 text, considered in the independent pass, requires coverage that the integrated token can be token0 or token1. The current draft can be implemented either with explicit index-placement fixtures or with incidental address order and no such coverage.

Correction: add explicit assertions and fixture cases covering product index 0 and product index 1 for the integrated leg, separately from the two rate-target cases. Keep the same-vault/two-provider proof intact. State that backing currency order, rate-target selection, and product-pool index placement are three distinct observations; changing one is not evidence of changing the others.

## What was not adopted from others

No peer responses or peer feedback were read, so I cannot attribute proposals to another member.

I do not request restoration of my original sibling-behavior files, V3 counterleg, extra two-V4 control, four-leg larger weighted choice, or storage-read book observations. Their omission is not a defect merely because the draft chose differently. PairToken as the non-converting other SE, three legs as the larger weighted setup, and direct `.t.sol` adaptations are acceptable selections when their bindings and inherited execution paths are made complete.

The draft accurately carries forward the central requirements for external providers, user refunds, maintenance remainder, exact-output rejection, disjoint backing, and the unverified same-backing-pool case. The concerns above identify the remaining copyable details, not grounds to reopen those locks.

## Limits

This is the single requested advisory review. It does not authorize implementation and does not replace the frozen draft.

Only the brief and the complete frozen draft were opened in this review. Source observations above use the admitted behavior files already read during the independent pass; no new implementation inspection or runtime verification was performed. In particular, I do not claim that the selected PairToken identity binding is accepted or rejected by current production code.

No hash was recomputed. No peer material, tests, installs, deployments, Git operations, or sub-agents were used. Only `docs/research/se-fullspread-hook-matrix-20261104/members/astra/feedback.md` was written. No second review round is requested.
