# Kimi K3 — plan draft: legacy V4 flatten (REDESIGN_PRD)

- **Label:** Replacement-session plan draft, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No reviewers' notes were read. This is not `REDESIGN_PRD.plan.md` and not any `REMEDIATION_PRD.md`; nothing was edited.
- **Date:** 2026-10-14.
- **Status:** DRAFT. Writing this plan does not authorize code, test, config, or script edits. A later session must be explicitly asked to implement it.
- **Controlling document:** `docs/reviews/legacy-v4-architecture-redesign-prd-review/REDESIGN_PRD.md` (read in full; 124 lines). Where this draft conflicts with it, the PRD controls.
- **Remaining choice:** **None.** The PRD names the components, selector owners, cut order, call shapes, deletions, size gate, and corrections. The closures below are mechanical statements of that text against current source; if an implementer believes a choice remains, stop and report rather than choosing.
- I did not run Forge.

## 0. Pre-implementation verification (searches; results recorded today, re-run at implementation time)

Today's results, to be re-verified in the implementation session before relying on them:

- **Shim consumers (11 files):** the hook targets/facets `UniswapV4DualStandardExchangeBufferConstantProductHookSeTarget.sol`, `UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawTarget.sol`, `UniswapV4StandardExchangeWeightedBufferHookSeTarget.sol`, `UniswapV4StandardExchangeWeightedBufferHookExitTarget.sol`, `UniswapV4StandardExchangeBalancerQuadStableBufferHookExitFacet.sol`, `UniswapV4StandardExchangeCurveQuadStableBufferHookExitFacet.sol`, plus `ConstantProductStandardYieldTarget.sol`, `UniswapV3FullSpreadStandardYieldExecutionTarget.sol`, `UniswapV4FullSpreadHooklessStandardYieldExecutionTarget.sol`, `UniswapV4FullSpreadPonsFamilyStandardYieldExecutionTarget.sol`, and the legacy `UniswapV4StandardYieldExecutionTarget.sol` itself. All take a mechanical import repoint only.
- **Qualified SY error references:** inside `NativeStandardYieldTarget.sol` itself (`:20-34`) and in `contracts/test/bases/TestBase_FullSpreadG5GuardClosure.sol:332-336`; a fresh grep for `NativeStandardYieldTarget.<ErrorName>` at implementation time governs the full repoint set.
- **Dissolving-base imports:** today, nothing outside `contracts/protocols/dexes/uniswap/v4/` imports `UniswapV4StandardExchangeCommon.sol`, `InBase.sol`, `OutBase.sol`, or the combiner `OutTarget.sol`; the in-family import graph is exactly: `Common ← {InBase, OutBase, LiquidReserveTarget}`, `InBase ← {InTarget, OutBase, PositionImportTarget, InQueryTarget, InMultiTarget, InMultiQueryTarget, InExecutionDelegate}`, `OutBase ← {OutExecuteTarget, OutQueryTarget, OutMultiTarget, OutMultiQueryTarget, OutExecutionDelegate}`. The combiner has zero importers.
- **Current InTarget post-REQ-V4-01 (verified today):** the share exit is already the internal call (`UniswapV4StandardExchangeInTarget.sol:81`); the deposit still delegatecalls (`:74`, `:89-93`); the constructor still takes `executionDelegate` (`:36`); `unlockCallback` is still hosted at `:32`.
- **Quote-helper consumers:** per PRD `:88`, a repository-wide consumer search for each QuoteService zap helper before any deletion; a found consumer is reported, not deleted around.

## 1. Order of work (callers rewired before deletions; compile at each numbered boundary)

| Step | Work | Compile gate |
| --- | --- | --- |
| 1 | Create `contracts/vaults/standard/sy/NativeStandardYieldErrors.sol` with the five existing errors, signatures unchanged; repoint qualified references (`NativeStandardYieldTarget.*` → `NativeStandardYieldErrors.*`) in every file the step-0 grep finds | Whole repo compiles; no behavior change |
| 2 | Create the six internal libraries under `contracts/protocols/dexes/uniswap/v4/internal/` with bodies moved verbatim from `Common`/`InBase`/`OutBase`: `Config`, `Accounting`, `Custody`, `PoolOps`, `Reserve`, `Import` per the PRD's responsibility table (`:21-31`). The unlock-boundary types (`OperationParams` and its decode) live in `PoolOps` — this keeps the PRD's component list closed; no seventh file is added. The two `_quoteZapOutAmount` copies collapse into one in `Accounting`; the self-preview at `OutExecuteTarget.sol:51` and the delegate self-previews at `OutExecutionDelegate.sol:88,94` are replaced by internal `Accounting`/quote calls during this move | New files compile; old files still in place |
| 3 | Create `UniswapV4StandardExchangeCallbackTarget.sol` and `UniswapV4StandardExchangeCallbackFacet.sol`: the `_unlockCallback` decode/dispatch moves from `Common` to the callback target, which validates the PoolManager caller and settles via `PoolOps` | Compiles; not yet wired |
| 4 | Rewire the family targets/facets onto the libraries and off the delegates and bases. In `UniswapV4StandardExchangeInTarget.sol`: the deposit branch calls `_executeZapInDeposit` internally (PRD `:67`); `_delegateExecuteZapInDeposit` and the `executionDelegate` constructor argument/immutable are removed; `unlockCallback` (`:32`) is removed (its selector moves to the callback facet). The share exit (`:81`) already matches the PRD and stays. In `UniswapV4StandardYieldExecutionTarget.sol`: the file stays as the family's SY hook layer; its bodies call the internal libraries; add `_requireNotDisabled` to the SY `deposit` and `redeem` money entries (REQ-V4-02; PRD `:71`) — those two entries only; every existing check elsewhere stays; no view selector gains the check. `OutExecuteTarget` loses `_delegateExecuteZapOutWithdrawal`; the withdrawal body is called internally from `PoolOps` (PRD `:70`). The remaining targets (query, multi, import, liquid-reserve) become thin bodies over the libraries; none inherits `Common`, `InBase`, or `OutBase`; no query facet inherits an execution target | Family compiles with delegates still present but unwired |
| 5 | Package wiring: `IUniswapV4StandardExchangeDFPkg.sol`, `UniswapV4StandardExchangeDFPkg.sol`, and `UniswapV4_Component_FactoryService.sol` gain the callback facet and lose both delegate deployments and every delegate constructor argument. `facetCuts` order is exactly PRD `:63`: the five shared facets, then callback, IN, IN query, position import, OUT, OUT query, liquid reserve, IN multi, IN multi query, OUT multi, OUT multi query. No other family facet is added or dropped | Package compiles |
| 6 | Deletions, in this order, each after a zero-reference search: (a) both execution delegates (`UniswapV4StandardExchangeInExecutionDelegate.sol`, `UniswapV4StandardExchangeOutExecutionDelegate.sol`); (b) `contracts/vaults/standard/sy/NativeStandardYieldExecutionTarget.sol`, with the eleven importers from step 0 repointed at `NativeStandardYieldTarget.sol` or `NativeStandardYieldErrors.sol` — import paths only, no architecture change in any other family; (c) `UniswapV4StandardExchangeOutTarget.sol` (combiner) after the zero-importer search; (d) `Common.sol`, `InBase.sol`, `OutBase.sol` after no file references them. `_deployExcessImported`, `_increaseImportedPositionCommon`, and `_increaseImportedPosition` disappear with the move in step 2/4 — they are never carried into `Import.sol`; the import's decrease/collect is carried (PRD `:84`, `:86`) | Whole repo compiles after each deletion |
| 7 | Update `contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol` to the new FactoryService/package shape; production-proxy deployment path unchanged. The full-range book suite's facet-size assertion is re-enumerated over the new facet set with the same 24,576 hard limit — that re-enumeration is wiring, not a weakened assertion | Test infrastructure compiles |

## 2. Exact calls (from the PRD, restated so they are not paraphrased)

- Deposit: internal `_executeZapInDeposit`; no `delegatecall` (PRD `:67`).
- Share exit: the current internal `_executeZapOutExactIn(..., address(this))` (PRD `:68`; current `InTarget.sol:81` already matches).
- Yield redemption: internal `_executeZapOutExactIn` followed by `_pokeBoundPoolTwap()`; vault-held passes `address(this)`; ordinary passes `msg.sender` (PRD `:69`; current `UniswapV4StandardYieldExecutionTarget.sol:29,35` shape is kept).
- `exchangeOut`: internal quote and withdrawal functions; never `previewExchangeOut` on `address(this)`; the withdrawal body moves once from the OUT delegate into `PoolOps` (PRD `:70`).
- SY `deposit`/`redeem`: call `_requireNotDisabled` before burn or movement (PRD `:71`). No other entrypoint gains or loses a check.
- `rebalanceLiquidReserve`: deadband/rounding/insufficient-ratio may no-op; any other external failure reverts; no catch-all (PRD `:72`, D8).
- No in-scope path calls or `delegatecall`s `address(this)` to reuse an entrypoint, quote, or settlement (PRD `:73`).

## 3. Selector ownership (unchanged except the one mandated move)

The PRD's table (`:39-61`) is repeated in the plan verbatim: the twelve SY discovery/preview selectors stay on `UniswapV4StandardExchangeOutMultiQueryFacet`; the seven reserve selectors stay on `UniswapV4StandardExchangeLiquidReserveFacet`; every other selector keeps its current facet; `IUnlockCallback.unlockCallback` alone moves, from `UniswapV4StandardExchangeInFacet` to `UniswapV4StandardExchangeCallbackFacet`. Each facet's `facetFuncs` is rewritten to exactly its row. The five shared facets are untouched. The plan spells out the twelve SY selector identities and the seven reserve selector identities (from `NativeStandardYieldSelectors._appendQuery` and `IUniswapV4StandardExchangeLiquidReserve`) so the loupe check is exact.

## 4. Build, measure, test, report

This is a production rewrite, so artifacts are refreshed before any test run:

```sh
python3 scripts/forge-artifacts.py plan <edited family sources> --test-root test/foundry/spec/protocol/dexes/uniswap/v4
python3 scripts/forge-artifacts.py test <edited family sources> --test-root test/foundry/spec/protocol/dexes/uniswap/v4 -- -vv
```

The positional source list is enumerated from the actual diff at implementation time (the family directory's edited files plus `NativeStandardYieldTarget.sol` and the repointed consumers). Default hermetic profile; `via_ir` stays false; `out/` and `cache_forge/` are retained.

- **Measure:** every deployed family facet's runtime after the refresh — 24,576 hard, 23,000 advisory. A hard-limit exceedance stops the work and is reported with the measured size and the facet's identity; no hop, self-call, or `via_ir` is restored to pass (PRD `:92`). The 31,908-byte figure is not a baseline (PRD `:94`).
- **Test gate:** the existing legacy V4 suites through the updated production TestBase — the vault-held redeem suite, the full-range book suite, the local liquid buffer suite, and the `adversarial/` and `decimals/` variants under `test/foundry/spec/protocol/dexes/uniswap/v4/`. Assertions are not rewritten to bless a removed hop; a test that encodes the old delegation is reported as a conflict, not edited green.
- **Shared-SY migration check:** every repointed consumer compiles and its existing suites run; no other family's redemption architecture changes.
- **Report:** commands actually run, toolchain, per-facet measured sizes, the step-0 search results as re-run, test results, and any stop condition hit.

## 5. What not to do

- No delegate, substitute delegate, execution library with public/external linked settlement, self-call, or trampoline, in any size emergency.
- No deletion ahead of its zero-reference search; no deletion of the import decrease/collect, a shared repo field, `NativeStandardYieldTarget.sol`, or any V3/hookless/Pons file.
- No new family storage slot; the stored-reserve pretransfer credit calculation is preserved exactly as it stands (PRD `:17`, `:113`).
- No behavior change beyond the REQ-V4-02 SY disable checks and the D8 failure-propagation semantics; no share token, NAV formula, holder-selecting endpoint, or economic edit.
- No selector move other than `unlockCallback`; no facet added or dropped beyond the callback facet.
- No live-instance action, migration, or storage-compatibility claim.

## Done when

- The six internal libraries and the callback facet/target exist with the named contents; the delegates, combiner, shim, bases, and the three import-maintenance functions are gone; the grep for `address(this))` typed calls in the family is clean.
- The package installs the sixteen product facets in the PRD's order with one owner per selector, verified by facet declarations and the deployed proxy's loupe.
- Every deployed family facet measures at most 24,576 bytes (or the oversized identity and measurement are reported and the work stops).
- The named suites pass on the refreshed artifacts through the production TestBase, and the report records commands, toolchain, sizes, and results.

I did not run Forge.
