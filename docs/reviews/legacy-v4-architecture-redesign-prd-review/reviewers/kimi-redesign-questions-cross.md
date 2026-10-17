# Kimi K3 — cross-review: REDESIGN_PRD question pass

- **Label:** Replacement-session cross-review, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. My question pass is `kimi-redesign-questions.md` in this directory. The three peer passes were read in full as untrusted model output. The controlling document is `../REDESIGN_PRD.md` (124 lines), which I read in full in my own pass. Nothing was edited.
- **Date:** 2026-10-14. I did not run Forge.

## Assigned ruling: no owner question remains — agree, unanimously

Astra ("Ready for implementation planning", blocking and non-blocking owner questions both none), Grok ("No owner question remains"), MiniMax ("No owner question remains"), and my own pass converge, and the convergence is over the same text: every decision row is now Decided (`REDESIGN_PRD.md:98-108`), the component table (`:21-31`), selector owners (`:39-61`), cut order (`:63`), call shapes (`:65-74`), deletion list with its search preconditions (`:75-88`), size gate (`:90-94`), and the preserved credit residual (`:113`) are all written down. The dissent section (`:120-122`) correctly records the rejected alternatives (MiniMax's retained delegates, Astra's sixteen-facet split and local-credit slot, my withdrawn merge) — recorded dissent, not open questions.

I verified each candidate decision against the document in my own pass and found none unaddressed; the peers' checks match. This is agreement over what the text contains, re-read independently, not proof by consensus.

## Closure lists converge; minor corrections to MiniMax's

The four closure lists (Astra's seven, Grok's nine, MiniMax's ten, my seven) are the same set restated: literal function-to-library mapping before any deletion, callers rewired before delegates die, the exact selector enumerations (Grok's spelling of the twelve SY and seven reserve selectors matches `NativeStandardYieldSelectors.sol:58-73` and `IUniswapV4StandardExchangeLiquidReserve`, which I read), the SY shim consumer migration list, package wiring in the `:63` order, measurement of every deployed facet against the 24,576 gate, and the unchanged legacy V4 suites as the test gate.

Two citation slips in MiniMax's closure list, neither affecting the verdict:

1. **Closure 8 (`:70`) is self-contradictory:** it first says OutMultiQueryFacet "loses the twelve SY discovery and preview selectors," then corrects itself by citing `:59`, which says they stay on that same facet. The correct reading is the second one: the twelve stay on `UniswapV4StandardExchangeOutMultiQueryFacet`. Grok's closure list and mine state it correctly.
2. **Closure 2 (`:58`) attributes "do not add that check to a view selector" to "the non-goal at line 112";** that sentence is in the Calls section at `:71`. `:112` is the no-share-token/NAV non-goal. Text identical, label wrong.

MiniMax's disable-check call-site list (`:58`) otherwise matches current code plus the PRD's SY additions: the existing checks at the import and rebalance entries are preserved, and `exchangeIn`/`exchangeOut`'s current checks stay; only the SY deposit/redeem additions are new (REQ-V4-02, `:71`, D6).

## One verification I added this round

The SY shim's consumer list (Astra's design-round inventory, repeated by MiniMax as closure 7) is confirmed by my own grep of `contracts/`: exactly ten non-legacy importers (the dual, single-CP withdraw, weighted ×2, balancer-quad, and curve-quad hook targets/facets; `ConstantProductStandardYieldTarget`; and the V3 FullSpread, hookless, and Pons SY targets) plus the legacy `UniswapV4StandardYieldExecutionTarget.sol` itself, which is retained in the redesign and gets the same mechanical repoint. The migration list the plan must name is those eleven files; other families receive import-path changes only (`REDESIGN_PRD.md:86`, `:102`).

## Unresolved dissent

None. All four passes agree no owner question remains, and the two citation corrections above do not touch any conclusion. As always here: unanimity is not proof, but the agreement is over a document each of us re-read in full.

I did not run Forge.
