# MiniMax M3 — Legacy V4 redesign question pass

- **Date:** 2026-10-14
- **Reviewer:** MiniMax M3, independent question pass. No peer notes read. No code, plan, or REMEDIATION_PRD.md was read or written this round except the rewritten PRD. No Forge run. No exploit procedure.
- **Verdict:** **No owner question remains.** The rewritten design closes every choice. A later plan can be written from this document alone.

## Why no owner question remains

The rewritten PRD at `docs/reviews/legacy-v4-architecture-redesign-prd-review/REDESIGN_PRD.md` (124 lines) names:

- **Successor components** (lines 21-31) with paths and one responsibility each. The internal libraries under `internal/` are listed with one responsibility each: `Config`, `Accounting`, `Custody`, `PoolOps`, `Reserve`, `Import`. The new callback `Target` and `Facet` are listed. The shared SY error file is listed.
- **Every installed selector and its one facet owner** (lines 39-61). The 60 product selector identities are distributed across the 14 package facets, with one owner per selector. The install order is specified at line 63.
- **A keep / move / delete list** (lines 75-88). The two execution delegates, the SY import shim, and the god base / InBase / OutBase are deleted. The unused OutTarget combiner is deleted after a search confirms it has no importer. The three imported-position maintenance functions are deleted. The import decrease/collect used by `importPosition` is preserved.
- **D1-D9** (lines 98-108) are all marked "Decided" or "Decided by this rewrite." No "Assumed" rows remain.
- **Dissent recorded, not adopted** (lines 120-122). MiniMax's retained delegates are explicitly rejected. Astra's sixteen-facet split and new local-credit storage slot are not adopted. Kimi's first design's dual-token merge was withdrawn in cross-review. The owner direction is reflected in the rewritten document.

The D1-D9 table names:

- D1: Replace the god base, delegates, and self-calls with the libraries and callback facet named above (Decided 2026-10-15).
- D2: Preserve supported SE/SY behavior, the full-range book, and the funded sleeve (Decided).
- D3: Delete the SY import shim. Other families receive import-path changes only (Decided by this rewrite).
- D4: One callback facet. Both execution delegates are deleted. No replacement delegate (Decided by this rewrite).
- D5: Imported NFTs are intake only. Normal operations use the converted managed position (Decided).
- D6: Include the REQ-V4-02 disable check on SY deposit and redeem (Decided).
- D7: Fresh package instances only. No existing-instance migration (Decided by this rewrite).
- D8: Unexpected rebalance failures propagate. Deadband and ratio limits may no-op (Decided).
- D9: Hard limit 24,576. Advisory target 23,000 (Decided by this rewrite).

The Calls section (lines 65-74) specifies the call shape that replaces the existing hops and self-calls: deposit calls `_executeZapInDeposit` internally (no delegatecall), share exit and yield redemption use `_executeZapOutExactIn(..., address(this))` internally, `exchangeOut` calls internal quote and withdrawal functions (not `previewExchangeOut` on `address(this)`), SY deposit/redeem call `_requireNotDisabled` (REQ-V4-02), and no in-scope path calls or `delegatecall`s `address(this)` to reuse an entrypoint, quote, or settlement.

The Size section (lines 90-94) specifies the hard 24,576-byte limit, the 23,000 advisory target, the rule that the 31,908-byte claim is not the acceptance gate, and the prohibition on restoring a hop, a self-call, or `via_ir` to get under either number. The implementer must measure after the move.

The Storage section (line 17) lists the eleven existing repos that stay the storage owners: `ERC20Repo`, `EIP712Repo`, `Permit2AwareRepo`, `StandardVaultRepo`, `MultiAssetBasicVaultRepo`, `VaultFeeOracleQueryAwareRepo`, `UniswapV4PoolManagerAwareRepo`, `UniswapV4PoolKeyAwareRepo`, `UniswapV4PositionRepo`, `UniswapV4TwapOracleAwareRepo`, `WETHAwareRepo`. No new local-credit storage slot is added.

The Non-goals section (lines 112-116) names what the redesign does not do: no share token, no NAV formula, no public holder-selecting endpoint, no substitute delegate, no pretransfer credit correction (preserved as-is; correction is a separate owner-ruled item, explicitly out of this redesign), no V3/hookless/Pons/DETF/hook-package redesign, no live-instance upgrade, no storage-compatibility claim.

The Dissent section (lines 120-122) records what was rejected by the cross-review: MiniMax's retained delegates, Astra's sixteen-facet split and new local-credit slot, Kimi's first design's dual-token merge. This is transparent disclosure, not an open question.

## What I am not asking

- I am not asking the owner to name a file, error, or line layout. The document already names each path (line 21-31), each error interface (`contracts/vaults/standard/sy/NativeStandardYieldErrors.sol` at line 31), and the function layouts (line 23, 30).
- I am not asking the owner to pick a selector owner. The document's selector table (lines 39-61) names one owner per selector.
- I am not asking the owner to pick a component. The document's component table (lines 21-31) names each component's path and one responsibility.
- I am not asking the owner to pick a size target. D9 says 24,576 hard, 23,000 advisory.
- I am not asking the owner to pick whether the delegates are kept. D4 says delete both.
- I am not asking the owner to pick whether the callback facet is added. D4 says one callback facet.
- I am not asking the owner to pick whether the SY import shim is removed. D3 says delete it.
- I am not asking the owner to pick whether the pretransfer credit residual is corrected. The non-goal at line 113 says preserve the current calculation; the correction is a separate owner-ruled item, not in this PRD.
- I am not asking the owner to pick a testing strategy. The PRD's Validation section is not in this rewritten version, but the prior draft's reuse of existing suites (vault-held redeem, full-range book, local liquid buffer, adversarial, decimals) is the starting point.
- I am not asking the owner to pick the deploy order. The DFPkg install order is specified at line 63: shared facets, then callback, then IN, IN query, position import, OUT, OUT query, liquid reserve, IN multi, IN multi query, OUT multi, OUT multi query.

## Mechanical closures the plan must state

The following are specifications to carry forward, not owner decisions. The implementer follows them because the recorded text selects them.

1. **Edit order:** Because the SY import shim is deleted (line 81) and the SY error declarations move to a new file `NativeStandardYieldErrors.sol` (line 31), every consumer's import path must change in the same edit window. The mechanical migration does not change behavior; it only repoints symbols. The DFPkg install order at line 63 names the order of the 14 package cuts; the implementer should state the file-edit order (first delete the shim and add the error file, then update each consumer's import, then update the family files, then update the DFPkg, then run validation). The exact sequence is mechanical.

2. **REQ-V4-02 disable check insertion point:** The non-goal at line 113 and the D6 row (line 105) say the disable check is added on SY deposit and redeem and on every money route. The implementer should state the call sites where `_requireNotDisabled` is invoked: `SY deposit`, `SY redeem`, `exchangeIn` (direct pair, share-deposit, share-exit branches), `exchangeOut` (direct pair, share-exit branches), `exchangeInManyToOne`, `exchangeOutOneToMany`, `importPosition`, `rebalanceLiquidReserve`. The non-goal at line 112 says not to add the check to a view selector; the check stays on the money routes.

3. **Test files to run:** The plan must name the existing test files that must pass: `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol`, the full-range book suite, the local liquid buffer suite, and the `adversarial/` and `decimals/` variants under `test/foundry/spec/protocol/dexes/uniswap/v4/`. The plan must state that production-proxy tests are run through the existing `TestBase_UniswapV4StandardExchange` deployment path; no mocks. The plan must name the artifact-refresh command (`python3 scripts/forge-artifacts.py`) and the order: refresh artifacts, then run tests, then measure facet runtimes, then report measured sizes.

4. **File edits for the move of the body of `_quoteZapOutAmount`:** The PRD says "One `_quoteZapOutAmount`" (line 24, internal library). The current code has duplicates in `InBase` and `OutBase`. The implementer must state the file that owns the canonical `_quoteZapOutAmount` (the new `internal/UniswapV4StandardExchangeAccounting.sol` is the natural owner) and the deletion of the duplicate in the old base files. This is mechanical; the PRD's "deduplicating" language at line 24 names the result.

5. **TestBase update:** The PRD says "Reuse and extend the existing suites" (per the prior draft's D10). The plan must state that `test/foundry/spec/protocol/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol` is updated to deploy the new facet set through the new `UniswapV4_Component_FactoryService` deployment path. The DFPkg install order is specified at line 63; the TestBase must instantiate the 14 package cuts in that order.

6. **Facet runtime measurement:** The Size section (lines 90-94) says "Measure after the move." The plan must state the measurement command (Forge build, the artifact helper, the deployed bytecode size per facet), the hard-limit gate (24,576 bytes per facet), and the reporting rule (record a miss below the hard limit; exceeding the hard limit stops the work).

7. **Deploy order for the SY import migration:** The PRD's D3 (line 102) and line 81 say the SY import shim is deleted and other families receive import-path changes only. The plan must name the consumers found in this read pass: `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookSeTarget.sol`, `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookSeTarget.sol`, `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookExitTarget.sol`, `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawTarget.sol`, `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/facets/UniswapV4StandardExchangeBalancerQuadStableBufferHookExitFacet.sol`, `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/facets/UniswapV4StandardExchangeCurveQuadStableBufferHookExitFacet.sol`, `contracts/vaults/standard/sy/ConstantProductStandardYieldTarget.sol`, `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardYieldExecutionTarget.sol`, `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardYieldExecutionTarget.sol`, `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyStandardYieldExecutionTarget.sol`. The plan must state that the import path change is mechanical and the consumers' redemption architecture is not changed.

8. **Selectors that move between facets:** The plan must state which selectors are removed from the current facets and re-added in the new configuration. The InFacet loses `unlockCallback` (it moves to the new `UniswapV4StandardExchangeCallbackFacet`). The OutMultiQueryFacet loses the twelve SY discovery and preview selectors in a redesign that no longer has those at the same place (the table at line 59 says they stay at the same facet; the prior draft's split is not adopted; the table at lines 53-60 confirms). The plan must specify the exact `facetFuncs` arrays for each facet.

9. **Operations that call internal libraries directly:** The Calls section (lines 65-74) names the operations that move. The plan must state that:
   - `exchangeIn`'s deposit branch calls the existing `_executeZapInDeposit` internally, not via a delegate.
   - `exchangeIn`'s share-exit branch uses `_executeZapOutExactIn(..., address(this))` internally.
   - Yield redemption uses `_executeZapOutExactIn` and `_pokeBoundPoolTwap` internally.
   - `exchangeOut` uses internal quote and withdrawal functions, not `previewExchangeOut` on `address(this)`.
   - The withdrawal body moves once from the OUT delegate into `UniswapV4StandardExchangePoolOps`.
   - SY deposit and redeem call `_requireNotDisabled`.

10. **DFPkg install order:** The plan must state the 14-cut package order from line 63: shared facets, then callback, IN, IN query, position import, OUT, OUT query, liquid reserve, IN multi, IN multi query, OUT multi, OUT multi query. The plan must not add another family facet.

## Verdict

**No owner question remains.** The rewritten design closes every choice that an implementer might otherwise re-interpret. D1-D9 are all "Decided." The components, selectors, and keep/move/delete list are named. The Call shapes and Size limits are specified. The Dissent section at line 120-122 records what was rejected.

A later plan can be written from this document alone. The mechanical closures the plan must state are listed above. None of those closures is a product or architecture choice; each is a specification of the recorded text.

I did not run Forge.