# Task IDXEX-081: Remove Token-Specific Exchange Routes from Protocol DETF

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-08
**Dependencies:** IDXEX-072 (in progress)
**Worktree:** `feature/IDXEX-081-remove-token-specific-exchange-routes`
**Origin:** Architecture cleanup — all exchange routes should use the generic exchangeIn/exchangeOut interface

---

## Description

The Protocol DETF exposes token-specific exchange functions (`richToRichir()`, `wethToRichir()`, `previewRichToRichir()`, `previewWethToRichir()`, `previewBptToWeth()`) as public interface functions. These violate the architectural principle that all token exchange routes — including deposits and withdrawals — are processed through the generic `exchangeIn`/`exchangeOut` and `previewExchangeIn`/`previewExchangeOut` interface.

The generic exchange router in `ProtocolDETFExchangeInTarget` already supports RICH→RICHIR and WETH→RICHIR routes via `previewExchangeIn`/`exchangeIn`. The standalone functions are redundant surface area that creates maintenance burden and interface bloat.

`previewBptToWeth` is additionally used internally by RICHIRTarget for rate calculation — it should be converted to route through `previewExchangeIn(BPT, amount, WETH)` or become an internal-only helper, not a public interface function.

`previewClaimLiquidity` and `claimLiquidity` are pool liquidity operations (not exchange routes) and are out of scope.

**Note:** IDXEX-072 is currently fixing preview/execution rate divergence for the RICH→RICHIR routes. This task should be done after IDXEX-072 merges to avoid conflicts.

## Dependencies

- IDXEX-072: Fix RICHIR Preview/Execution Rate Divergence (in progress — fixes the preview accuracy that these routes depend on)

## User Stories

### US-IDXEX-081.1: Remove richToRichir/wethToRichir from IProtocolDETFBonding

As a developer, I want token-specific bonding convenience functions removed from the public interface so that all exchange routes go through the canonical exchangeIn/exchangeOut interface.

**Acceptance Criteria:**
- [ ] `richToRichir()` removed from `IProtocolDETFBonding` interface
- [ ] `previewRichToRichir()` removed from `IProtocolDETFBonding` interface
- [ ] `wethToRichir()` removed from `IProtocolDETFBonding` interface
- [ ] `previewWethToRichir()` removed from `IProtocolDETFBonding` interface
- [ ] Corresponding selectors removed from `ProtocolDETFBondingFacet.facetFuncs()` and `facetMetadata()` (if they were registered — verify)
- [ ] Internal implementation functions (`_previewRichToRichir`, `_previewWethToRichir`, etc.) are kept as internal helpers since they're used by the generic exchange router
- [ ] Build succeeds

### US-IDXEX-081.2: Remove richToRichir/wethToRichir from IProtocolDETF

As a developer, I want the duplicate token-specific function declarations removed from `IProtocolDETF` so the interface reflects only non-exchange operations.

**Acceptance Criteria:**
- [ ] `richToRichir()` removed from `IProtocolDETF` interface
- [ ] `previewRichToRichir()` removed from `IProtocolDETF` interface
- [ ] `wethToRichir()` removed from `IProtocolDETF` interface
- [ ] `previewWethToRichir()` removed from `IProtocolDETF` interface
- [ ] Build succeeds

### US-IDXEX-081.3: Remove previewBptToWeth from public interface

As a developer, I want `previewBptToWeth` removed from the public `IProtocolDETF` interface and routed through `previewExchangeIn` or made internal-only.

**Acceptance Criteria:**
- [ ] `previewBptToWeth()` removed from `IProtocolDETF` interface
- [ ] `previewBptToWeth.selector` removed from `ProtocolDETFExchangeInFacet.facetFuncs()` and `facetMetadata()` (lines 45, 60)
- [ ] Either: (a) add BPT→WETH as a recognized route in `previewExchangeIn` so `RICHIRTarget` can call `previewExchangeIn(BPT, amount, WETH)`, or (b) refactor `previewBptToWeth` to be an internal-only function and update `RICHIRTarget` to call it via a non-public mechanism (e.g., internal delegatecall or shared library)
- [ ] `RICHIRTarget._getCurrentRedemptionRate()` (line 390) updated to use the new pattern instead of `layout_.protocolDETF.previewBptToWeth(...)`
- [ ] All internal callers in `ProtocolDETFBondingTarget`, `ProtocolDETFExchangeInTarget`, and `ProtocolDETFExchangeOutTarget` that call `IProtocolDETF(address(this)).previewBptToWeth(...)` updated to call the internal version directly
- [ ] Build succeeds

### US-IDXEX-081.4: Update tests to use generic exchange interface

As a developer, I want all tests to call the generic `exchangeIn`/`previewExchangeIn` interface instead of token-specific functions.

**Acceptance Criteria:**
- [ ] `ProtocolDETF_Routes.t.sol` updated: calls to `previewRichToRichir()` replaced with `previewExchangeIn(RICH, amount, RICHIR)`
- [ ] `ProtocolDETF_Routes.t.sol` updated: calls to `previewWethToRichir()` replaced with `previewExchangeIn(WETH, amount, RICHIR)`
- [ ] Any other test files using removed functions updated
- [ ] All ProtocolDETF test suites pass
- [ ] Build succeeds

## Technical Details

### Functions to Remove from Public Interface

| Function | Current Location | Action |
|----------|-----------------|--------|
| `richToRichir()` | `IProtocolDETFBonding`, `IProtocolDETF` | Remove from both interfaces |
| `previewRichToRichir()` | `IProtocolDETFBonding`, `IProtocolDETF` | Remove from both interfaces |
| `wethToRichir()` | `IProtocolDETFBonding`, `IProtocolDETF` | Remove from both interfaces |
| `previewWethToRichir()` | `IProtocolDETFBonding`, `IProtocolDETF` | Remove from both interfaces |
| `previewBptToWeth()` | `IProtocolDETF` | Remove from interface, keep internal |

### Internal Functions to Keep

The internal helpers (`_previewRichToRichir`, `_previewWethToRichir`, `_previewChirToWethExact`, etc.) should remain as implementation details — they're used by the generic `previewExchangeIn`/`previewExchangeOut` router.

### previewBptToWeth Cross-Contract Call

Currently `RICHIRTarget` calls `layout_.protocolDETF.previewBptToWeth(position.originalShares)` cross-contract (line 390). Options:
1. **Add BPT as exchange route**: Add `_isBptToken()` helper and handle `BPT→WETH` in `previewExchangeIn` router, then call `previewExchangeIn(BPT, amount, WETH)` from RICHIRTarget
2. **Keep as internal + expose via shared Common**: Move the logic to `ProtocolDETFCommon` as internal, and have RICHIRTarget access it via a different mechanism

Option 1 is preferred as it aligns with the "all routes through exchangeIn/exchangeOut" principle.

### Diamond Facet Selector Changes

- `ProtocolDETFBondingFacet`: Verify whether richToRichir/wethToRichir selectors are registered (they may be on IProtocolDETFBonding but not in facetFuncs — check)
- `ProtocolDETFExchangeInFacet`: Remove `IProtocolDETF.previewBptToWeth.selector` from `facetFuncs()` (line 45) and `facetMetadata()` (line 60), update array sizes

## Files to Create/Modify

**Modified Files:**
- `contracts/interfaces/IProtocolDETF.sol` — Remove richToRichir, wethToRichir, previewRichToRichir, previewWethToRichir, previewBptToWeth
- `contracts/vaults/protocol/ProtocolDETFBondingTarget.sol` — Remove public richToRichir, wethToRichir, previewRichToRichir, previewWethToRichir from IProtocolDETFBonding interface; keep internal implementations
- `contracts/vaults/protocol/ProtocolDETFBondingFacet.sol` — Update facetFuncs/facetMetadata if selectors were registered
- `contracts/vaults/protocol/ProtocolDETFExchangeInFacet.sol` — Remove previewBptToWeth.selector, update array sizes
- `contracts/vaults/protocol/ProtocolDETFExchangeInTarget.sol` — Convert previewBptToWeth to internal, add BPT→WETH route to previewExchangeIn if needed
- `contracts/vaults/protocol/RICHIRTarget.sol` — Update _getCurrentRedemptionRate to use new pattern
- `contracts/vaults/protocol/ProtocolDETFExchangeOutTarget.sol` — Update internal previewBptToWeth callers
- `contracts/interfaces/proxies/IProtocolDETFProxy.sol` — Verify no compile issues after interface changes
- `test/foundry/spec/vaults/protocol/ProtocolDETF_Routes.t.sol` — Update test calls

## Inventory Check

Before starting, verify:
- [ ] IDXEX-072 has been merged (preview accuracy fixes must land first)
- [ ] `richToRichir`/`wethToRichir` are NOT registered as selectors in `ProtocolDETFBondingFacet.facetFuncs()` (they're in the interface but may not be in the diamond — verify)
- [ ] Count all external callers of `previewBptToWeth` (currently: RICHIRTarget, ProtocolDETFBondingTarget x2, ProtocolDETFExchangeInTarget x2, ProtocolDETFExchangeOutTarget x2)
- [ ] Understand that `ProtocolDETFBondingTarget` calls `IProtocolDETF(address(this)).previewBptToWeth(...)` — this is a self-call through the Diamond proxy, which means it uses the external function. Converting to internal requires changing this pattern.

## Completion Criteria

- [ ] All acceptance criteria met across all user stories
- [ ] No token-specific exchange functions remain in public interfaces
- [ ] `previewBptToWeth` is internal-only or routed through previewExchangeIn
- [ ] `previewClaimLiquidity` and `claimLiquidity` are untouched
- [ ] All ProtocolDETF test suites pass
- [ ] All ProtocolDETF_Routes tests pass
- [ ] Build succeeds
- [ ] No regressions in other test suites

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
