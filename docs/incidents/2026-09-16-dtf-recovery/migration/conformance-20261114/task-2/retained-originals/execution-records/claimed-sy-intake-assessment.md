# Raw TokenStaking descendant intake: current seam assessment

2026-11-12. Read-only assessment against the complete retained phase11 claims contract section4 and the immutable ED cumulative source at3ec0912b. No new source or production admission follows. Phase21 delivery is running and was not touched.

## Observed source and implementation

TokenStaking0xE4c9Ff4Cfd17AE73ECb3825ebDf7db113C146d00 exposes caller-owned reassign/withdrawClaim, not an approved Migration pull or callback. Its recorded source behavior can let an actual holder claim SY to itself before Migration. That prior source transaction has a separate rollback boundary. Native18 weights, native19 vault shares and native9 SY are not interchangeable units; the historical64890781291192882058375->117153341 example is not a general conversion rate. The phase11 source report is behavioral evidence with explicit missing exact-source equivalence, not current policy for old NFT handling.

In the accepted ED tree, IUniswapV4DetfMigration.sol:166-175 defines WeightedSyEntitlementInput with originalId, originalWallet, fixed source, originalUnits, originalEth, originalDtf, evidenceId and contributionsKnown. UniswapV4DetfMigrationAllocationTarget.sol:186-216 accepts the fixed SY source and positive units, checks canonical origin and unconsumed state, evaluates the complete original ETH/DTF inputs once, then assigns remainingUnits=originalUnits and remainingCredit=that quote. There is no parent-weight quantity, conversion receipt mapping or inherited remaining-credit input in this tuple. This inspection is of the immutable ED base, not an assertion that a currently committing candidate was modified.

## Consequence for source closure

Existing SY support alone does not authenticate a raw-weight descendant or close T. Loading only a partial descendant quantity with the entire original contribution would assign the entire quoted credit to that subset; the current loader does not itself enforce a parent-weight fraction. Re-quoting scaled original components is not a substitute for conserving the original frozen credit. Neither an arbitrary credit override nor a historic single-claim ratio is admitted.

A bounded candidate for later source investigation is a complete eligible original whose full eligible weight is actually converted to measured native SY before loading, retaining the same economic origin and complete original contribution. This is an inference to test, not an approved mapping or operational original: evidence must establish full eligible-weight coverage, every exact claimed-SY quantity and rounding, no overlapping independent/backing/receipt award, the actual original wallet and current control. Extra/reward weights and unrelated SY cannot be silently included. Partial/prior-delivered originals need an explicit conserved remaining-credit mapping rather than this full-original shortcut.

Any eventual integrated proof must use a real controlled original holder performing its own source claim, then configured atomic SY pull/funding/fresh bond. A failed Migration transaction restores SY custody and Migration credit but not the already-completed raw-weight claim. Direct ordinary-Migration raw pull remains a required negative. Specialized account execution, role manufacture and a two-step compensated handoff are not selected. No full raw-weight support or owner-data approval is inferred.

No RPC, new fork, tests, code edits, ref/index changes or source-evidence modification occurred. Only this root intake assessment was created. Further admission needs actual source witnesses and the precise original-unit/credit binding; the overall source/provenance task remains open.
