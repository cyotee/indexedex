# Grok original — legacy V4 architecture redesign PRD

- **Date:** 2026-10-15
- **Draft:** `contracts/protocols/dexes/uniswap/v4/legacy-v4-standard-exchange-architecture-redesign.md`, read in full. Not edited.
- **Question:** Is this a good PRD for simplifying and flattening the legacy Uniswap V4 Standard Exchange vault?
- **Answer:** The intent is sound. The draft is not yet that PRD. It is a process document that defers the architecture.
- **Ready to implement:** No.

## Facts from the current tree

- `UniswapV4StandardExchangeInBase` inherits `UniswapV4StandardExchangeCommon` (`UniswapV4StandardExchangeInBase.sol:20`). `UniswapV4StandardExchangeOutBase` inherits that IN base (`UniswapV4StandardExchangeOutBase.sol:22-23`).
- The yield helper now calls inherited `_executeZapOutExactIn` and then pokes (`UniswapV4StandardYieldExecutionTarget.sol:29-30`). The ordinary share exit does the same with holder `address(this)` (`UniswapV4StandardExchangeInTarget.sol:81`). The two redemption wrappers are gone from the IN delegate. The deposit hop remains (`:93-96`).
- OUT execution still calls `previewExchangeOut` on `address(this)` and still delegatecalls a zap-out withdrawal (`UniswapV4StandardExchangeOutExecuteTarget.sol:51`, `:68-69`).
- `NativeStandardYieldExecutionTarget.sol` is a five-line import shim. `_quoteZapOutAmount` exists in both `UniswapV4StandardExchangeInBase.sol` and `UniswapV4StandardExchangeOutBase.sol`.
- `unlockCallback` is on `UniswapV4StandardExchangeInTarget`, which `UniswapV4StandardExchangeInFacet` inherits. It is not a separate facet.
- I found no saved measurement of **31,908** bytes for that facet. The number is not in `docs/reviews/apex-req-v4-01-internal-settlement/`, and it is not in `out/UniswapV4StandardExchangeInFacet.sol/UniswapV4StandardExchangeInFacet.json`. The draft's own source-map figures are labeled partial attributions, not removable-byte measurements.

## Findings

### Grok-01 — The draft defers the architecture it would have to freeze

- **Severity:** High
- **Section:** Requirements 1, 2, and 9; Execute.
- **Broken requirement or invariant:** A flattening PRD names the resulting components, selector ownership, and what is deleted, and leaves no implementer architecture choice. This draft says the later plan must produce the selector manifest, component paths, dependencies, and one owner per selector (`:36-37`, `:47`, `:99`). Execute says `_no plan yet` (`:167`). Requirement 9 also says to measure opportunities to consolidate smaller groups (`:98`).
- **Impact class:** Implementer architecture choice. Coding from this file would choose the facet split, the successor components, and the deletion boundary.
- **Fix direction:** Do not implement from this draft. A later document must name the successor components, the selector-to-facet table, and the keep/delete list before any edit. Do not invent that table in this review.

### Grok-02 — The size gate is a claim, not recorded evidence

- **Severity:** Medium
- **Section:** Summary, lines 14-16.
- **Broken requirement or invariant:** A present assertion is not a pass. The draft says the refreshed IN facet compiled to 31,908 bytes, 7,332 over 24,576, and that validation stopped with no passing redemption test. I did not find a saved measurement or that failed run.
- **Impact class:** Unverified evidence. The overage may be real, but this number cannot set the redesign gate by itself.
- **Fix direction:** Attach the artifact measurement, compiler settings, and the command that produced 31,908, or mark the figure unverified. Do not treat it as a completed size result.

## Owner questions

The draft marks these assumed. They are product choices. I am not answering them.

- **D3:** Is removing `NativeStandardYieldExecutionTarget.sol` and limiting other families to mechanical import changes accepted?
- **D4:** Is a dedicated callback facet accepted, with the other selector groups still unassigned?
- **D7:** Are fresh instances and no existing-instance migration accepted?
- **D9:** Is 23,000 bytes a required design target, or is 24,576 the only limit?

D1, D2, D5, D6, and D8 are marked decided. I do not reopen them.

## Not a defect in the intent

The current inheritance and the remaining OUT self-call and delegate hop match the problem the draft names. Deposit delegation remains. Those observations support a redesign. They do not supply the missing component or selector table.

No. The council should not treat this draft as ready to implement.

I did not run Forge.
