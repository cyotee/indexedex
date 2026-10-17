# Kimi K3 — review: legacy V4 architecture redesign draft PRD

- **Label:** Replacement-session review, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No other reviewers' notes were read. The draft was not edited; no code was edited.
- **Date:** 2026-10-14.
- **Subject:** `contracts/protocols/dexes/uniswap/v4/legacy-v4-standard-exchange-architecture-redesign.md` (169 lines, read in full).
- **Question:** is this a good PRD for simplifying and flattening the legacy Uniswap V4 Standard Exchange vault?
- I did not run Forge. A present assertion is not a pass; the draft's size figures are treated as claims.

## Intent assessment

The draft's intent is sound and honestly framed: it correctly identifies the family's real structural problems — an all-purpose `Common` base, duplicate settlement/quote cores, delegate hops, self-call reuse of public previews, an import-only SY shim, and imported-NFT maintenance branches — and it sets the right invariants (measured-not-assumed sizes, no `via_ir` evasion, no self-call or substitute-delegate recurrence, production-proxy testing, fresh-instance storage cleanup only). Its epistemics are unusually careful: it labels its own byte attributions as "partial compiler attributions, including instruction operands, not measurements of removable bytes" (`:16`).

But measured against the rubric for a flattening PRD — name the resulting components, the selector ownership, and what is deleted, and leave no implementer architecture choice — the draft is a **direction and process document, not yet that PRD**. Its decisive content is explicitly deferred: the component decomposition ("The implementation plan fixes component paths, dependencies, and selector ownership before coding", `:47`) and the selector-to-facet table ("Freeze a complete selector-to-facet table in the implementation plan", `:99`) are the architecture, and both are postponed to a later document. What the draft names concretely is mostly what is *removed*; what the family is *rebuilt as* is described only by properties ("narrowly scoped internal components for configuration/storage access, accounting/quotes, custody, pool operations, and reserve management", `:43`) without naming those components, their file paths, their contents, or their consumers.

## Findings

### F1 — The resulting architecture is deferred, so no implementer (or plan author) can start without making the architecture choice

- **Severity:** Medium (specification completeness; it gates the entire redesign).
- **Section:** Requirements 2 (`:42-47`) and 9 (`:96-104`), with the deferral sentences at `:47` and `:99`.
- **Broken requirement or invariant:** The rubric for this class of PRD: the resulting components, selector ownership, and deletions are named, and no architecture choice is left downstream. The draft instead requires a future plan to (a) invent the component inventory that replaces `UniswapV4StandardExchangeCommon` (how many Repo/Service/Target units, with what contents), (b) decide whether and how "smaller groups" consolidate (`:98` — "measuring opportunities to consolidate" is an open design loop, not a frozen table), and (c) draw the selector-to-facet map. An implementer handed only this document must design the architecture the document exists to define.
- **Impact class:** Process / specification completeness. Risk of divergent reimplementations or a stalled plan stage.
- **Fix direction:** Either extend this PRD (or produce its plan as an owner-reviewed gate *before* any coding, with the plan named as a hard approval checkpoint) so that the following are enumerated: the successor component list with paths and responsibilities replacing `UniswapV4StandardExchangeCommon`; the facet inventory with each external selector's single owner; the deletion list at function granularity (the draft already does this well for the import-maintenance branches at `:75` and the delegates at `:101` — extend that standard to the whole family); and the disposition of each current target/common file (kept, split, deleted). Until then the document should be labeled a design direction, not an implementable PRD.

### F2 — The motivating measurement (31,908 bytes) and the source-map attributions are unrecorded claims

- **Severity:** Low.
- **Section:** Summary, `:14-16`.
- **Broken requirement or invariant:** The draft's own constraint discipline — "Report exact sizes and compiler settings" (`:103`), "Abstract classes, import shims, source lines, and ABI entry counts are not substitutes for measured deployed bytecode" (`:149`) — is not applied to the draft's own foundational numbers. A repo-wide search for the figure finds it only in this document; no saved build log, artifact record, or evidence file preserves the 31,908-byte IN-facet measurement, the 7,332-byte excess, or the per-file attributions (8,864 / 2,509 / 2,331 / 849 bytes). "Validation stopped at that gate; no passing redemption test was established" (`:14`) is likewise an unrecorded runtime claim.
- **Impact class:** Evidence / provenance. A later session cannot distinguish a measured gate failure from a remembered one, and cannot reproduce the attribution baseline the redesign's sizing arguments rest on.
- **Fix direction:** Preserve the artifact (build log or artifact JSON with toolchain) beside this document, or annotate the figures as unrecorded recollection. This does not challenge the direction; it asks the redesign to meet the evidence standard it imposes on the implementer.

### F3 — Four decisions are marked "Assumed" and need owner ratification

- **Severity:** Low (the draft itself flags them; nothing is contradicted by current code).
- **Section:** Decisions table, `:153-163`.
- **Broken requirement or invariant:** The owner rule for this council's PRDs is that decisions are recorded, not assumed. D3 (remove the import-only SY shim, with cross-family mechanical migration), D4 (dedicated callback facet; no replacement execution delegates), D7 (fresh-package-instance storage cleanup), and D9 (23,000-byte design target under the 24,576 hard limit) are marked "Assumed". D4 in particular is an architecture choice the rest of requirement 9 depends on.
- **Impact class:** Governance / decision provenance.
- **Fix direction:** one owner question (below); on ratification, flip the four rows to Decided or amend them.

### Owner question (the only one)

The Decisions table marks D3, D4, D7, and D9 "Assumed." Does the owner ratify all four as written — specifically D4's dedicated-callback-facet shape and D9's 23,000-byte design target — or amend any of them before the component/selector inventory is frozen? Everything else in the draft is either recorded as Decided or verifiable against current source.

## Spot-check record — the draft's descriptions of current code are accurate

Verified against current source this round:

- **REQ-V4-01 post-state (`:14`):** accurate. `UniswapV4StandardYieldExecutionTarget.sol:29` now makes the internal call (`amount_ = _executeZapOutExactIn(tokenOut_, shares_, minimum_, receiver_, holder_);`); no delegatecall remains in that file. `UniswapV4StandardExchangeInExecutionDelegate.sol` now contains only `executeZapInDeposit` (`:12-17`) — the two wrappers were deleted; its `SELF`/`DelegateCallRequired` declarations remain (`:9-10`), unused.
- **Import-only shim (`:57`):** accurate. `contracts/vaults/standard/sy/NativeStandardYieldExecutionTarget.sol` is five lines re-exporting from `./NativeStandardYieldTarget.sol`.
- **Self-call reuse of public previews (`:12`, `:52`):** accurate. `UniswapV4StandardExchangeOutExecutionDelegate.sol:88,94` call `IStandardExchangeOut/In(address(this)).previewExchange*`; `UniswapV4StandardExchangeOutExecuteTarget.sol:51` calls `IStandardExchangeOut(address(this)).previewExchangeOut(...)`.
- **Duplicate zap-out quote implementations (`:66`):** accurate. `_quoteZapOutAmount` exists in both `UniswapV4StandardExchangeInBase.sol:129` and `UniswapV4StandardExchangeOutBase.sol:89`.
- **Import-maintenance branches (`:75`):** accurate. `_deployExcessImported` (`UniswapV4StandardExchangeCommon.sol:849`), `_increaseImportedPositionCommon` (`:951`), and the forwarding `_increaseImportedPosition` (`UniswapV4StandardExchangeInBase.sol:399-401`) all exist.
- **Broad inheritance surface (requirement 2-3 direction):** consistent with the current graph — e.g., `UniswapV4StandardExchangeOutMultiQueryTarget.sol:16` inherits both `UniswapV4StandardExchangeOutBase` and the full `NativeStandardYieldTarget` aggregate (preview + money surface), while SY execution also lives on the IN facet via `UniswapV4StandardYieldExecutionTarget`.
- **The 31,908-byte figure:** no saved measurement found (repo-wide search; the only hits are this draft and unrelated data files). Treated as a claim, per F2.

## What is already good

- The behavioral preservation invariants (requirements 1, 5, 7, 8) are specific and testable: holder selection rules, pretransfer credit semantics, false-flag pull-quoted-not-maximum, disable policy including REQ-V4-02 without importing FullSpread's exemption (`:85`), single-lock entry, TWAP/reserve-sync preservation.
- The non-goals and constraints correctly fence the known failure modes: no self-call or delegate-hop substitutes, no `via_ir`, no compiler-policy evasion, no size claims from file counts (`:149`), no mock-based tests (`:108`), fresh-instance storage scoping (`:147`).
- The validation matrix (`:114-129`) names concrete areas and existing starting suites without claiming they pass.

## Verdict

**No — the council should not treat this draft as ready to implement.** It is a competent design-direction document. To become an implementable flattening PRD it needs the frozen successor-component inventory and selector-to-facet table (F1), preserved size evidence or an honest unrecorded-measurement label (F2), and owner ratification of the four Assumed decisions (F3). Until then, an implementation session would be authoring the architecture the PRD exists to fix.

I did not run Forge.
