# Task IDXEX-072: Fix RICHIR Preview/Execution Rate Divergence

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-07
**Dependencies:** None
**Worktree:** `feature/fix-richir-preview-divergence`
**Origin:** Failing tests in ProtocolDETFExchangeOut.t.sol and ProtocolDETF_Routes.t.sol

---

## Description

All RICH -> RICHIR preview functions diverge from execution because the preview calls `previewBptToWeth(newPositionShares)` against the **current** Balancer pool reserves, but execution first mutates the pool (adds liquidity via unbalanced add), so the subsequent `_getCurrentRedemptionRate()` -> `previewBptToWeth()` call sees a different pool state, yielding a different rate.

This manifests in three failing tests across two contracts:

### ExactOut (ProtocolDETFExchangeOut.t.sol):
- `test_exchangeOut_rich_to_richir_exact` — `SlippageExceeded(100e18, 99.94e18)` — preview overestimates output by ~0.06%

### ExchangeIn / Bonding (ProtocolDETF_Routes.t.sol):
- `test_exchangeIn_rich_to_richir_preview` — `assertApproxEqRel` fails, preview=3113e18 vs actual=3147e18, delta=1.08% > 1% tolerance — preview underestimates output
- `test_route_rich_to_richir_single_call` — same divergence via `previewRichToRichir()` bonding preview

The divergence is larger for the RICH path (20% weight vault index) than the WETH path (80% weight index).

## Dependencies

- None (all prerequisites met)

## Root Cause Analysis

### Preview path (`_previewRichToRichirForward`, lines 757-796):
1. Calculate `vaultShares` from RICH input via `previewExchangeIn`
2. Calculate `bptOut` via `calcBptOutGivenSingleIn` with **current** pool state
3. Calculate `newWethValue = previewBptToWeth(newPositionShares)` with **current** pool state
4. `richirOut = (bptOut * newRate) / ONE_WAD`

### Execution path (`_executeRichToRichirExact`, lines 801-835):
1. Execute `exchangeIn` to get vault shares (same as preview)
2. Execute `_addToReservePoolForExactOut()` -> **mutates pool: adds vault shares, mints BPT**
3. Execute `addToProtocolNFT(bptOut)` -> updates position
4. Execute `mintFromNFTSale(bptOut)`:
   - `_mintShares()` -> increases totalShares
   - `_getCurrentRedemptionRate()` -> calls `previewBptToWeth()` against **post-liquidity-add pool state**
   - The unbalanced add shifted pool ratios, so proportional exit math yields less WETH per BPT
   - `richirMinted = (bptOut * rate) / ONE_WAD` -> **rate is lower than preview predicted**
5. Slippage check: `richirOut(99.94e18) < amountOut(100e18)` -> **reverts**

### Magnitude
- ExactOut: ~0.06% divergence for 100 RICHIR via RICH route (preview overestimates)
- ExchangeIn: ~1.08% divergence for 5000 RICH input (preview underestimates)
- Only affects low-weight vault index paths (RICH -> RICHIR)
- WETH -> RICHIR (high-weight index) passes due to smaller impact

## User Stories

### US-IDXEX-072.1: Fix ExactOut preview to account for post-add pool state

As a user exchanging RICH for RICHIR via exact-out, I want the preview to correctly predict my RICHIR output so that the exchange does not revert due to preview/execution divergence.

**Acceptance Criteria:**
- [ ] `_previewRichToRichirForward()` in ProtocolDETFExchangeOutTarget computes `previewBptToWeth()` against post-liquidity-add pool state
- [ ] `_previewWethToRichirForward()` in ProtocolDETFExchangeOutTarget gets the same treatment for consistency
- [ ] `test_exchangeOut_rich_to_richir_exact()` passes
- [ ] `test_exchangeOut_weth_to_richir_exact()` still passes
- [ ] All other ProtocolDETFExchangeOut tests still pass (18 currently passing)
- [ ] Build succeeds

### US-IDXEX-072.2: Fix ExchangeIn/Bonding preview for RICH -> RICHIR

As a user converting RICH to RICHIR via exchangeIn or richToRichir(), I want the preview to match execution within 1% so that slippage protection is reliable.

**Acceptance Criteria:**
- [ ] `previewRichToRichir()` in ProtocolDETFBondingTarget accounts for post-add pool state
- [ ] `previewExchangeIn(RICH, *, RICHIR)` in ProtocolDETFExchangeInTarget accounts for post-add pool state
- [ ] `test_exchangeIn_rich_to_richir_preview()` passes (within 1% tolerance)
- [ ] `test_route_rich_to_richir_single_call()` passes (within 1% tolerance)
- [ ] All other ProtocolDETF_Routes tests still pass
- [ ] Build succeeds

### US-IDXEX-072.3: Validate preview accuracy across all RICHIR routes

As a developer, I want all RICHIR preview functions to produce results matching execution so that all routes are reliable.

**Acceptance Criteria:**
- [ ] Preview matches execution for RICH -> RICHIR route (both exchangeIn and exchangeOut)
- [ ] Preview matches execution for WETH -> RICHIR route (both exchangeIn and exchangeOut)
- [ ] No regressions in any exchange routes

## Technical Details

### Fix Approach

The fix is in the preview forward simulation functions. Currently they call `previewBptToWeth(newPositionShares)` using the current pool state. They need to simulate what `previewBptToWeth` would return **after** the unbalanced add has changed the pool.

**Option A: Adjust pool state in preview (Recommended)**

In `_previewRichToRichirForward()` and `_previewWethToRichirForward()`, after calculating `bptOut`, simulate the post-add pool state:
- New pool total supply = `resPoolTotalSupply + bptOut`
- New pool balances = `currentRatedBalances` with `vaultShares` added to the appropriate index
- Then use these adjusted values when simulating the proportional exit in `previewBptToWeth`

This may require refactoring `previewBptToWeth()` to accept pool state parameters, or creating an internal version that can take hypothetical pool data.

**Option B: Add buffer to binary search target**

Make the binary search in `_previewRichToRichirExact()` search for a slightly higher target (e.g., `exactRichirOut * 10001 / 10000`) to account for the rate drift. Simpler but less precise.

**Option C: Compute rate inline in execute**

Instead of relying on `mintFromNFTSale` to compute the return value, compute the rate inline in `_executeRichToRichirExact` using the same hypothetical math as the preview. This requires changing how `mintFromNFTSale` works or adding a new mint variant.

### Recommended: Option A

Option A is the most correct because it makes the preview truly mirror the execution. The preview should simulate all state changes that the execution will perform.

## Files to Create/Modify

**Modified Files:**
- `contracts/vaults/protocol/ProtocolDETFExchangeOutTarget.sol` - Fix `_previewRichToRichirForward()` and `_previewWethToRichirForward()` to account for post-add pool state
- `contracts/vaults/protocol/ProtocolDETFBondingTarget.sol` - Fix `previewRichToRichir()` and `previewWethToRichir()` to account for post-add pool state

**Potentially Modified:**
- `contracts/vaults/protocol/ProtocolDETFExchangeInTarget.sol` - Fix `_previewRichToRichir()` and `_previewWethToRichir()` if they have separate preview paths; also may need to refactor `previewBptToWeth()` to accept hypothetical pool state
- `contracts/vaults/protocol/ProtocolDETFCommon.sol` - If shared helpers are extracted

**Tests (should all pass after fix):**
- `test/foundry/spec/vaults/protocol/ProtocolDETFExchangeOut.t.sol` - All 19 tests should pass
- `test/foundry/spec/vaults/protocol/ProtocolDETF_Routes.t.sol` - All tests should pass (2 currently failing)

## Inventory Check

Before starting, verify:
- [ ] `test_exchangeOut_rich_to_richir_exact` currently fails with `SlippageExceeded(100e18, 99.94e18)`
- [ ] `test_exchangeIn_rich_to_richir_preview` currently fails with delta=1.08% > 1% tolerance
- [ ] `test_route_rich_to_richir_single_call` currently fails with same delta
- [ ] `test_exchangeOut_weth_to_richir_exact` currently passes
- [ ] Understand `_previewChirRedemptionReserveShares` proportional exit math
- [ ] Understand Balancer V3 weighted pool math for unbalanced add impact

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] All 19 ProtocolDETFExchangeOut tests pass (18 existing + the 1 that was failing)
- [ ] All ProtocolDETF_Routes tests pass (2 currently failing should be fixed)
- [ ] No regressions in other test suites
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
