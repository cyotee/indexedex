# Astra original — legacy V4 architecture-redesign PRD review

**Date:** 2026-10-15. **Scope:** Independent quality/readiness review of `contracts/protocols/dexes/uniswap/v4/legacy-v4-standard-exchange-architecture-redesign.md`, read in full. No peer notes were read. No implementation, shell, build, test, or delegation was performed.

## Assessment

**The intent is sound, but this is not yet an implementation-ready flattening PRD.** It is a useful set of redesign constraints and discovery/validation tasks. It does not specify the resulting architecture sufficiently to prevent a later planner or implementer from designing it.

The strongest parts are the explicit-holder rule; preservation of observable SE/SY behavior; distinction between local custody and external protocol state; prohibition on substitute self-calls/delegate hops; acknowledgement that internal libraries and fewer source files do not automatically reduce bytecode; callback/lock-context preservation; and measured runtime acceptance. D6 and D8 are recorded decisions and should not be reopened.

The decisive weakness is explicit deferral: requirements 2 and 9 say the **implementation plan** will choose component paths, dependencies, and selector ownership. That is the core architectural answer the requested PRD needs to contain. A future instruction not to choose an alternative architecture cannot make an unspecified architecture concrete.

## Findings

### Astra-01 — The resulting components and selector ownership are deferred rather than specified

- **Severity:** Medium — implementation-readiness blocker, not a demonstrated production vulnerability.
- **Section / lines:** Requirements 1, 2, and 9; draft `:36-47,96-104`, especially `:47` and `:99`.
- **Broken requirement or invariant:** A flattening PRD must name the resulting components, their dependencies, and the owner of every installed selector, leaving no implementer architecture choice. Here the document lists responsibility categories and instructs a future plan to supply that design.
- **Observed fact:** “Narrowly scoped internal components” at 43 does not identify files or interfaces. “Measured operation/query groups” and opportunities to consolidate groups at 98 do not select the facet partition. A dedicated callback facet is specified in principle, but its concrete component and the remaining selector owners are not named.
- **Current-source evidence:** `UniswapV4StandardExchangeInFacet.sol:13-29` currently exposes exchangeIn, unlockCallback, and appended SY execution selectors through one inherited implementation. `UniswapV4StandardExchangeOutBase.sol:22-24` inherits InBase, and `UniswapV4StandardExchangeInQueryTarget.sol:10-14` also inherits InBase. These are the concrete dependency/ownership relationships the redesign must replace, not just classify.
- **Impact class:** Architecture ambiguity, selector/package integration risk, and unbounded refactoring scope.
- **Fix direction:** Before implementation planning, place the complete target component/dependency diagram and exhaustive selector-to-component/facet/interface table in this PRD or a frozen, explicitly incorporated design appendix. Identify the callback owner and every money/query/transition/import/reserve owner. The implementation plan should sequence that selected design, not invent it. Do not promise that moving unlockCallback alone resolves the size limit.
- **Confidence:** High. The deferral is explicit. Whether a particular candidate partition fits is unverified; no replacement partition is proposed here.

### Astra-02 — Deletion and storage/shared-SY migration boundaries remain conditional work items

- **Severity:** Medium.
- **Section / lines:** Requirements 4, 5, 6, and 10; draft `:56-77,101,107-112`; constraints `:146-147`.
- **Broken requirement or invariant:** The PRD must identify what survives, moves, and is deleted, including shared consumers and storage ownership. “Remove unused” and “inventory before removing” defer those dispositions to the implementation phase.
- **Observed fact:** The import shim, two execution delegates, and several imported-position functions are named for removal. However, the compatibility aggregate's final disposition, replacement error-declaration location, new owners of shared operations, affected shared-SY consumers, and per-field Repo disposition are not supplied. “Representative” outside-family behavioral checks at validation row 129 are not a fixed migration acceptance set.
- **Current-source evidence:** `contracts/vaults/standard/sy/NativeStandardYieldExecutionTarget.sol:4-5` is indeed an import-only shim. `NativeStandardYieldTarget.sol:14-16,84-95` contains the actual execution/aggregate declarations and error namespace. Deleting the shim does not itself select the fate of those contracts. `UniswapV4StandardExchangePositionImportTarget.sol:79-94,100-106` initializes temporary imported-position state, collects assets, then finishes conversion into the managed book. The temporary lifecycle is real, so deletion cannot be derived solely from the final imported flag being false.
- **Impact class:** Shared-consumer breakage, storage/callback lifecycle ambiguity, and incomplete flattening acceptance.
- **Fix direction:** Complete a current-to-result disposition table covering named files/contracts/functions and affected Repo fields, with exact replacement owners and readers/writers. Include the bounded shared-SY importer/reference list and the concrete checks that preserve their behavior. Resolve the temporary import-state readers before marking associated state removable. Preserve the draft's prohibition on other-family redesign.
- **Confidence:** High on missing specification. No claim that the named cleanup is inherently unsafe or that all imported-state readers must remain forever.

### Astra-03 — “One accounting model” does not define the persistent book used for pretransfer credit

- **Severity:** Medium.
- **Section / lines:** Requirements 5 and 7; draft `:64-69,80-87`; behavior-delta table deferred at `:40`.
- **Broken requirement or invariant:** Complete-book valuation and locally available pretransfer credit must have unambiguous storage meanings and update rules. The intended invariant “booked reserves never become caller credit” is stated, but the redesigned persisted-book semantics and the correction from current code are not specified.
- **Observed fact:** Requirement 5 defines complete-book contents, while requirement 7 refers to unbooked inventory and bounded operation credit without defining the stored baseline, its ownership, or its relationship to deployed inventory. The draft requests a later behavior-delta table instead of providing it.
- **Current-source evidence:** `UniswapV4StandardExchangeCommon.sol:593-600` writes total vault reserves into `_reserveOfToken`; `:607-618` composes free assets, deployed assets, and fees. The token delivery path at `:1250-1275` reconstructs face-booked credit using the stored total and live deployed inventory. These are materially different questions from explicit-holder settlement or replacing self-reads with Repo accessors. `UniswapV4StandardExchangeOutExecuteTarget.sol:51-60` also illustrates that current exact-output funding/refund behavior differs from draft requirement 7's quote-sized false-flag pull.
- **Impact class:** Value-accounting specification ambiguity and accidental preservation or alteration of known behavior during structural work.
- **Fix direction:** Supply the missing behavior-delta/accounting table before implementation: define each persistent book field's units and meaning, the exact pretransfer availability/budget rules, when operation snapshots are taken, and post-operation synchronization. Distinguish complete valuation inventory from local credit without asking the implementer to infer a storage design. Map each selected correction to the affected routes and exact expected results. D6 already selects inclusion of corrections; no new product ruling is needed merely to write them down.
- **Confidence:** High on the missing representation/transition specification. This is a PRD-quality finding, not a newly demonstrated accounting exploit.

### Astra-04 — Mandatory implementation requirements rely on decisions still marked “Assumed”

- **Severity:** Medium for D3/D4/D7 readiness; D9's advisory target alone is Low.
- **Section / lines:** Decisions table `:153-163`, compared with mandatory requirements 4, 6, and 9 and constraint 147.
- **Broken requirement or invariant:** An implementation-ready PRD cannot both mandate a cross-family migration, facet boundary, or storage-compatibility decision and leave its authorization labeled assumed. An implementer must not choose whether to accept those assumptions.
- **Observed fact:** D3, D4, D7, and D9 are marked “Assumed.” Elsewhere shim removal, a dedicated callback facet, fresh-instance storage cleanup, and size targets are written as required outcomes. D1/D2/D5/D6/D8 are marked decided, so the document itself distinguishes assumed from recorded authority.
- **Impact class:** Unresolved scope/architecture approval and compatibility policy.
- **Fix direction:** Resolve these specific assumptions before release for implementation: cite an existing owner ruling and mark decided where available, or obtain the bounded owner confirmations below. Do not reopen decisions already recorded as decided. Confirming these assumptions still does not fill the component/selector/deletion tables in Astra-01/02.
- **Confidence:** High.

## Owner questions — only the marked assumptions

1. **D3, blocking for the shared-SY migration:** Do you approve removal of the shared execution import shim and migration out of the compatibility aggregate's error namespace, with other families restricted to mechanical compatibility changes?
2. **D4, blocking for the architectural specification:** Do you approve the dedicated legacy V4 callback facet and the prohibition on replacement execution delegates as fixed redesign constraints?
3. **D7, blocking for storage-layout cleanup:** Do you approve a fresh-instance-only storage redesign with no existing-instance compatibility or migration promise, while preserving shared layouts used by active other families?
4. **D9, non-blocking to the established hard cap but needed to close the assumption:** Do you approve 23,000 bytes as an advisory per-facet headroom target, with misses below 24,576 bytes reported rather than treated as completion failures?

If existing owner records already answer any question, incorporate that authority instead of asking it again. No question is asked about error naming, routine line layout, D6 correction inclusion, or D8 propagation: the last two are expressly decided. The missing concrete architecture is a design-authoring deliverable, not a request for the owner to pick arbitrary filenames.

## Spot-checks supporting the intent

The draft accurately distinguishes the completed source-level redemption reroute from remaining architectural complexity:

- `UniswapV4StandardYieldExecutionTarget.sol:26-30` now uses internal settlement and retains the TWAP update.
- `UniswapV4StandardExchangeInTarget.sol:79-83` uses internal share-exit settlement, but `:89-98` still delegates deposits. `UniswapV4StandardExchangeInExecutionDelegate.sol:8-17` retains that deposit wrapper.
- `UniswapV4StandardExchangeOutExecuteTarget.sol:51,105-122` still uses a self-preview and an OUT delegate hop. `UniswapV4StandardExchangeOutExecutionDelegate.sol:77-96` performs local total-supply/self-preview reads. Removing the old redemption hop is therefore not equivalent to flattening the whole family.
- `UniswapV4StandardExchangeInBase.sol:129-143` and `UniswapV4StandardExchangeOutBase.sol:89-102` contain the duplicated quote implementation the draft identifies.
- The existing IN facet already owns unlockCallback with other execution selectors (`UniswapV4StandardExchangeInFacet.sol:25-29`). A dedicated callback facet would require a concrete package-cut change, not just moving a source function.
- Import conversion and temporary imported state are visible in `UniswapV4StandardExchangePositionImportTarget.sol:79-109`; the draft's warning not to remove temporary readers solely from the final state is well founded.

These are scoped factual checks, not full behavioral validation. I found no contradiction in those descriptions, and no new production defect is opened from these spot-checks.

## Measurement and evidence limits

The **31,908-byte** size and source-map attribution figures at draft lines 14-16 remain **unverified claims in this review**. I did not locate a relevant saved measurement in the named remediation directory, matching report/log searches under `docs/`, or the searched `implementation-artifacts` records. Numeric matches belonging to unrelated gas traces, hashes, or other artifacts do not establish this facet's size. This is not proof that no measurement exists elsewhere.

The draft correctly warns that attributed instruction bytes are not removable-byte budgets and that no passing redemption test was established by the reported gate. Preserve that distinction. Attach or cite the actual artifact-size/source-map record with source identity and compiler settings, or label the figures as reported rather than independently evidenced. Do not turn a PRD review into an invented build result.

I also read the relevant canonical Crane architecture skill directly; no skill was invoked. No missing supplied draft/source path was encountered. The linked product-law documents were not comprehensively re-audited; this review does not certify every economics assertion in the draft.

## Readiness disposition

Keep this document as a direction/constraints draft while its authors resolve the assumed decisions and fill the resulting-component graph, selector ownership, deletion/storage migration tables, and accounting behavior deltas. The later implementation plan should then order a specified redesign rather than select one. Runtime feasibility still requires measurement, but the lack of a run is not the main readiness failure: the destination architecture is not yet specified.

**Should the council treat this draft as ready to implement? No.**

I did not run Forge.
