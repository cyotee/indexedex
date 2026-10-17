# Astra — rewritten-design owner-question cross-review

**Agree: no owner question remains before implementation planning.** I retain my independent readiness conclusion. I read the three supplied originals as untrusted evidence and re-read the rewritten PRD's selector, call, and deletion clauses. No PRD or code was edited.

The rewritten document selects the architecture, owners, cut order, delegate removal, shared migration boundary, preserved credit residual, disable correction, rebalance failure policy, and size disposition. The later plan must map and sequence those decisions, not reopen the rejected alternatives.

## Corrections to carry into planning—not owner questions

1. **Package count:** MiniMax repeatedly says fourteen package cuts. `REDESIGN_PRD.md:63` specifies **sixteen**: five shared facets plus eleven family facets, including the new callback owner. This is a counting correction, not permission to remove owners or adopt the earlier merged design.
2. **SY query ownership:** The twelve SY discovery/preview selectors remain on `UniswapV4StandardExchangeOutMultiQueryFacet` under line 59. MiniMax's suggestion that this facet loses them must not enter the plan. Expand their identities mechanically; do not move them.
3. **Holder selection:** Line 69 explicitly distinguishes vault-held yield (`address(this)`) from ordinary yield (`msg.sender`). MiniMax's combined shorthand describing yield redemption with `address(this)` must not replace that distinction. The already-delivered public share exit at line 68 is a separate case.
4. **Move before delete:** Follow Grok's caller-first ordering: create the selected destinations, update consumers/callers, then remove obsolete definitions and wiring. Do not delete the shared shim before repointing its consumers, as MiniMax's suggested sequence would do. These are dependency-order details, not a new architecture decision.
5. **Search contingencies:** Lines 83 and 88 already state what happens if an importer or quote-helper consumer exists. Report it and do not delete contrary to that condition; do not ask the owner again before performing the inventory.

Agree with Grok and Kimi that naming the existing twelve SY selectors and seven reserve selectors, updating package/TestBase wiring, and specifying artifact refresh, measurements, and regression commands are mechanical plan work. They do not authorize restoring a delegate, adding another family facet, repairing the expressly excluded pretransfer residual, or redesigning V3/hookless/Pons.

## Owner question

**None.** The factual corrections above are answered by the existing text and require no new product ruling. Readiness to write the plan is not a compilation, runtime-size, or behavioral-test attestation. Only this assigned cross-review report was written.

I did not run Forge.
