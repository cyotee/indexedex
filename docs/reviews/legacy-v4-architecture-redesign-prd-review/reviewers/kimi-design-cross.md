# Kimi K3 — design cross-review: legacy V4 flatten

- **Label:** Replacement-session cross-review, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. My design pass is `kimi-design.md` in this directory. The three peer designs were read in full as untrusted model output. The controlling direction is the redesign draft plus the owner rulings restated in the assignment: **both execution delegates removed; one dedicated callback facet; preserve behavior except the recorded REQ-V4-02 and D8 corrections; no new economics.** Nothing was edited.
- **Date:** 2026-10-14. I did not run Forge.

## Ruling on the delegate constraint

**MiniMax's design is rejected.** Its keep/move/delete list retains `UniswapV4StandardExchangeInExecutionDelegate.sol` and `UniswapV4StandardExchangeOutExecutionDelegate.sol` ("kept"/"kept, narrowed" at `:161-162`, "The IN delegation … stays … and the OUT delegation … stays" at `:210`). Its owner-ruling paraphrase (`:11`) inverts the actual ruling: the draft requires removing both delegates and their constructor/factory wiring (`legacy-v4-standard-exchange-architecture-redesign.md:101`), and the assignment restates it. A design that keeps a delegate hop is out. Astra, Grok, and my own pass all delete both delegates and move their remaining settlement bodies into internal libraries; no delegate hop survives in any of the three.

The replacement sentence for MiniMax's table: **"Both legacy execution-delegate contracts are deleted outright, with their constructor and factory wiring; their remaining settlement bodies (the zap-in deposit and the zap-out withdrawal) move into the internal settlement/pool-operations library and are called internally. No CREATE3 execution hop and no replacement delegate remains."**

## The one closed component list

I adopt **Grok's component list with two amendments** (one from Astra, one from my own pass), and reject one component of Astra's. The closed list, all paths under `contracts/protocols/dexes/uniswap/v4/` unless noted:

| Component | One responsibility |
| --- | --- |
| `internal/UniswapV4StandardExchangeConfig.sol` | Read initialized pool key, token faces, managers, TWAP oracle; the single internal token-validity predicate; `_requireNotDisabled` and unlock-state gates. No new storage. |
| `internal/UniswapV4StandardExchangeAccounting.sol` | The one book and quote implementation: sleeve + exact deployed + earned fees counted once; the single consolidated `_quoteZapOutAmount`; share/issuance math. |
| `internal/UniswapV4StandardExchangeCustody.sol` | Pull, credit, burn-by-explicit-holder, payout, operation-bounded refund — current semantics preserved exactly, including the recorded stored-reserve credit residual (see the rejected component below). |
| `internal/UniswapV4StandardExchangePoolOps.sol` | The one swap / liquidity add-remove / fee-collect / zap-out-withdrawal body, executed inside the unlock; unlock initiation helpers. |
| `internal/UniswapV4StandardExchangeReserve.sol` | Deadband/ratio-limited bounded rebalance; unexpected external failures propagate (D8); no catch-all. |
| `internal/UniswapV4StandardExchangeImport.sol` (Astra's separation, adopted) | NFT intake: authorization, matching-pool validation, decrease/collect, conversion into the managed book. The draft's import lifecycle is distinct enough that folding it into PoolOps (Grok's table is silent on it) would recreate a grab-bag. |
| `UniswapV4StandardExchangeCallbackTarget.sol` + `UniswapV4StandardExchangeCallbackFacet.sol` (new) | The one `unlockCallback(bytes)`: validates the PoolManager caller, decodes and settles the operation. |
| `contracts/vaults/standard/sy/NativeStandardYieldErrors.sol` (new) | The five existing SY error declarations, signatures unchanged; other families repoint imports mechanically. |

Kept as-is: the three Aware repos, `UniswapV4PositionRepo.sol` (imported-position custody fields documented, not deleted), `UniswapV4QuoteService.sol`, the five shared facets and their repos, and the shared SY Money/Preview/Discovery/Rewards components in `NativeStandardYieldTarget.sol`. Deleted: both delegates, the unused `UniswapV4StandardExchangeOutTarget.sol` combiner (Astra `:217`; Grok omits it — included after my verification that nothing inherits it), the SY import shim, `Common`/`InBase`/`OutBase` after the move, `_delegateExecuteZapInDeposit`, `_delegateExecuteZapOutWithdrawal`, and the three import-maintenance functions (`_deployExcessImported`, `_increaseImportedPositionCommon`, `_increaseImportedPosition`). Astra's QuoteService dead-helper deletions (`:225`) are adopted with its own precondition: only after a repository-wide caller inventory confirms no consumers; otherwise report, don't delete.

**Rejected component — Astra's `UniswapV4StandardExchangeLocalCreditRepo`** (`astra-design.md:54,156-160`). It adds a new family storage slot and changes how pretransfer credit is computed (a persisted `bookedLocal` baseline instead of the current stored-reserve derivation). That is the accounting repair the earlier council record explicitly left as a residual: FIX_PRD kept this package and did not authorize that repair (confirmation PRD dissent note on `UniswapV4StandardExchangeCommon.sol:1256-1274`), and this round's controlling instruction names exactly two corrections (REQ-V4-02, D8). A flattening must reproduce current credit behavior deliberately, not improve it. The replacement sentence for Astra's component list: **"No new family storage slot is added. Pretransfer credit is computed exactly as the current legacy V4 code computes it; the recorded stored-reserve credit residual is preserved, not repaired, in this redesign. Any correction of that residual requires its own owner-ruled item."** The rest of Astra's component decomposition (the fine-grained library split) is compatible with the closed list above at coarser granularity; the closed list chooses Grok's coarser grouping to keep the library count at six plus the callback pair and the errors file.

## The one closed selector-to-facet table

I adopt **Grok's table**: the current partition, unchanged, plus the new callback facet. Every selector keeps its current owner except `IUnlockCallback.unlockCallback`, which moves from `UniswapV4StandardExchangeInFacet` to `UniswapV4StandardExchangeCallbackFacet`. That is: InFacet owns `exchangeIn` and the four SY execution selectors (`deposit`, `redeem`, `rewardIndexesCurrent`, `claimRewards`); InQueryFacet owns the six transition/external-quote selectors; PositionImportFacet owns `importPosition`; OutFacet owns `exchangeOut`; OutQueryFacet owns `previewExchangeOut` and `quoteState`; LiquidReserveFacet owns its seven; InMultiFacet owns `exchangeInManyToOne`; InMultiQueryFacet owns `previewExchangeInManyToOne` and `previewExchangeIn`; OutMultiFacet owns `exchangeOutOneToMany`; OutMultiQueryFacet owns `previewExchangeOutOneToMany` and the twelve SY query/discovery/preview selectors. The five shared facets are unchanged. Sixteen family-plus-shared product facets in the package, cut order preserved with the callback facet appended per the package's existing ordering convention.

Why this table over the alternatives:

- **Versus MiniMax's table:** MiniMax relocates the twelve SY query selectors from `OutMultiQueryFacet` to `InQueryFacet` and asserts the legacy vault's SY surface is In-side only (`:116-129`) — factually wrong about current ownership (`UniswapV4StandardExchangeOutMultiQueryFacet.sol:23-26` owns them today via `_appendQuery`), and an unrequested ABI move. Rejected with the delegates above.
- **Versus Astra's table** (sixteen family facets: singleton money facets, SYDeposit/SYRedeem/SYQuery/SYRewards splits, Quote/StateQuote/TransitionQuote/ExternalQuote splits, Rebalance split from LiquidReserve): not wrong, but unmeasured churn. The controlling direction mandates one new callback facet and measured groups; it does not ask for a maximal re-partition, and every additional move rewrites package wiring and the test inventory for no recorded requirement. If a measured facet exceeds the hard limit, the recorded stop-and-report rule governs; finer splits are then a recorded design revision, not an implementer option (Astra's own `:297` agrees with that discipline).
- **Versus my own pass:** my merge of the multi-entry facets into In/Out and my transition/SY-query splits were likewise an unmeasured preference. I withdraw them in favor of the minimal-move table.

Astra's supplementary rigor is adopted without changing the table: interface-qualified selector identities (not hand-written hex), the six permanent factory-installed introspection selectors recorded as factory-owned infrastructure rather than family surface (`astra-design.md:126-137`), and the temporary post-deploy selector noted as construction-only.

## Unresolved dissent

- MiniMax maintains the delegates stay as CREATE3 routing; the controlling text says both are removed. Rejected; the replacement sentence is above.
- Astra's local-credit repo is rejected as an unauthorized behavior change; if the owner intends the credit-baseline correction inside this redesign, that is one explicit owner ruling — until then the residual is preserved. This is the only point that would become an owner question, and it is already answered by the recorded residual decision, so I do not ask it.
- Facet-count preference (Astra's fine split versus the adopted minimal move) is a recorded disagreement about unmeasured packaging, not about behavior; the closed table above is the one the coordinator should write into the PRD.

I did not run Forge.
