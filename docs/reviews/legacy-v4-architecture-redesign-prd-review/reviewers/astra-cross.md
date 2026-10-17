# Astra — legacy V4 redesign PRD cross-review

**Verdict: useful direction, not ready to implement.** I agree with all three peers on the missing successor architecture and unresolved assumed decisions. I read their original reviews as untrusted evidence and re-read the draft's component/selector requirements and decision table. No draft, PRD, or source was edited. My original findings remain preserved.

## 1. The architecture is still deferred — agree

The draft at `contracts/protocols/dexes/uniswap/v4/legacy-v4-standard-exchange-architecture-redesign.md:43-47` names responsibility categories, then assigns component paths, dependencies, and selector ownership to the future implementation plan. Lines 98-99 leave consolidation opportunities open and defer the complete selector-to-facet table.

Those are not merely execution-order details. They select what the flattened vault consists of and which deployable component owns each external operation. The instruction that implementation agents must not choose an alternative architecture does not supply the missing initial architecture.

**Retain Astra-01, Medium, architecture/specification completeness.** I agree with MiniMax and Kimi's severity rather than Grok's High: this blocks implementation readiness, but the review has not demonstrated a production vulnerability or loss. The fix is still required regardless of severity.

The design authors must complete and freeze the successor component/dependency inventory, selector ownership, and keep/move/delete dispositions before releasing implementation work. An explicitly incorporated, reviewed design appendix can hold those tables. Moving those decisions into an implementer's ordinary task list would not close the gap. No replacement architecture is proposed here.

Two qualifications:

- `_no plan yet` at line 167 is not itself a PRD defect. A complete architectural PRD can precede its execution plan. The defect is that this PRD expressly defers architectural content, not that no plan file exists yet.
- MiniMax's statements that the implementer picks specific files or performs the deletion inventory should not be adopted as the resolution. Under the owner's criterion, those architecture-defining dispositions belong in the approved design before implementation.

## 2. Four assumed decisions need recorded owner disposition — agree

Re-reading lines 157-163 confirms that **D3, D4, D7, and D9 remain “Assumed.”** They require an owner ruling or a citation to an already-recorded ruling, followed by an unambiguous decided disposition:

- **D3:** shared-SY shim/error-namespace simplification and the mechanical-only boundary for other families.
- **D4:** dedicated legacy V4 callback facet and the selected no-substitute-delegate architecture constraint.
- **D7:** fresh-instance storage cleanup without an existing-instance migration or compatibility promise.
- **D9:** the proposed advisory 23,000-byte per-facet headroom target.

**Retain Astra-04:** Medium for unresolved D3/D4/D7 scope/architecture approval; D9's advisory target alone is Low. Approval of all four still would not populate the missing architecture tables.

Do not reopen the already-decided D1/D2/D5/D6/D8 rows. In particular, inclusion of corrections and propagation of unexpected protocol errors are expressly recorded choices.

**Narrow the D9 question:** line 103 already distinguishes the advisory target from the hard 24,576-byte completion limit. Ask whether the owner approves the advisory target as written, not whether the hard cap can be relaxed or whether a below-cap target miss must suddenly fail completion.

## 3. Evidence and factual corrections

The 31,908-byte figure remains unverified in my review. The peers' unsuccessful searches do not prove that no measurement exists anywhere. Attach the actual source-bound measurement record or label the number as reported/unverified; neither agreement nor a numeric string search measures runtime size. The hard runtime limit does not depend on validating that motivating figure.

One source correction to Kimi's spot-check at original line 54: `UniswapV4StandardExchangeOutMultiQueryTarget.sol:4` imports **`NativeStandardYieldPreviewTarget as NativeStandardYieldTarget`**. Its inheritance at line 16 therefore does not establish inheritance of the complete compatibility aggregate or its money surface. I re-read the import. This correction does not defeat the broader architecture finding: the draft still lacks successor components and selector owners.

My original deletion/storage/shared-SY and local-credit specification findings remain attributed to Astra and are not withdrawn by peer agreement on the broader gap. This cross-review does not treat their absence from another review as refutation.

## Closure judgment

Resolve the four assumed decisions and finish the concrete architectural specification before implementation. The existing direction and invariants are worth retaining; they are not yet a choice-free flattening design. No code changes or new product requirements are authorized by this review.

**Should the council treat this draft as ready to implement? No.**

I did not run Forge.
