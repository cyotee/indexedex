# IDXEX-085: Replace Hardcoded Preview Discount with Compound State Simulation

**Status:** Ready
**Priority:** Medium
**Created:** 2026-02-08
**Source:** IDXEX-072 review — user identified that the 0.15% hardcoded discount is a hack

## Problem Statement

IDXEX-072 fixed the RICHIR preview/execution rate divergence by adding a hardcoded 0.15% vault share discount and 0.1% binary search buffer across 5 locations in 3 files. While this made all tests pass, the approach is empirically tuned rather than analytically correct. The user correctly identified this as a hack:

> "If the discrepancy is coming from the Aerodrome fee compounding during execution, wouldn't the correct solution be to calculate the Aerodrome fee compounding in the preview?"

The root cause is that `previewExchangeIn()` returns more vault shares than `exchangeIn()` actually produces, because Aerodrome fee compounding during execution changes the pool reserves (price curve), producing slightly different output than the preview calculated against stale reserves.

There are **two distinct sources** of divergence that must NOT be conflated:
1. **Accrued fee compounding** — collecting accrued fees and depositing them as liquidity changes the reserves and thus the price curve. This should be simulated in the preview using the existing `_previewCompoundState()` pattern.
2. **Swap fees** — the fee charged on each trade, which should be retrieved from the pool and factored into swap math. This is already handled by the swap preview functions.

## Existing Patterns to Use

### 1. `_previewCompoundState()` (AerodromeStandardExchangeCommon.sol:606-641)

Already simulates the post-compound pool state including updated reserves and LP total supply. Returns a `PreviewCompoundState` struct with:
- `reserve0`, `reserve1` — post-compound reserves
- `lpTotalSupply` — post-compound total supply
- `lpMinted` — LP tokens that compounding would produce

### 2. `getPoolTokenInfo()` (Balancer V3 IVaultExplorer)

Used in `SeigniorageDETFUnderwritingTarget.sol:201`:
```solidity
(,, data.balancesRaw, data.currentRatedBalances) = balV3Vault.getPoolTokenInfo(address(reservePool_));
```

Returns both raw and rated balances for Balancer V3 pools. Raw balances are needed for proper pool math when simulating vault share deposits (vault shares are raw, not rated).

## Locations to Fix

### Hardcoded 0.15% vault share discounts (replace all 5):

1. `contracts/vaults/protocol/ProtocolDETFExchangeOutTarget.sol:699` — `_previewRichToRichirForward()`
2. `contracts/vaults/protocol/ProtocolDETFExchangeOutTarget.sol:820` — `_previewWethToRichirForward()`
3. `contracts/vaults/protocol/ProtocolDETFBondingTarget.sol:689` — `previewRichToRichir()`
4. `contracts/vaults/protocol/ProtocolDETFBondingTarget.sol:797` — `previewWethToRichir()`
5. `contracts/vaults/protocol/ProtocolDETFExchangeInTarget.sol:847` — `_previewRichToRichir()`

### Hardcoded 0.1% binary search buffers (remove or recalculate):

6. `contracts/vaults/protocol/ProtocolDETFExchangeOutTarget.sol:681` — `_previewRichToRichirExact()`
7. `contracts/vaults/protocol/ProtocolDETFExchangeOutTarget.sol:802` — `_previewWethToRichirExact()`

### Missing discount (from IDXEX-072 review Finding 1):

8. `contracts/vaults/protocol/ProtocolDETFExchangeInTarget.sol` — `_previewWethToRichir()` — was missing the 0.15% discount entirely. The proper simulation should be added here too.

## User Stories

### US-IDXEX-085.1: Simulate Aerodrome fee compounding in vault share preview

**As** the ProtocolDETF preview system,
**I want** to simulate the post-compound state of Aerodrome pools before calculating vault share output,
**So that** the preview reflects the actual reserves the execution will use.

**Acceptance Criteria:**
- [ ] All 5 forward preview functions simulate compound state instead of using hardcoded discounts
- [ ] The `_previewCompoundState()` pattern from AerodromeStandardExchangeCommon is reused or adapted
- [ ] The compound state simulation uses the Aerodrome pool's actual accrued fees (not a magic number)
- [ ] All 3 previously-failing tests still pass (test_exchangeOut_rich_to_richir_exact, test_exchangeIn_rich_to_richir_preview, test_route_rich_to_richir_single_call)

### US-IDXEX-085.2: Use raw balances for Balancer pool state simulation

**As** the ProtocolDETF preview system,
**I want** to use `getPoolTokenInfo().balancesRaw` when simulating the effect of vault share deposits on the Balancer reserve pool,
**So that** the preview correctly accounts for the rated/raw balance distinction.

**Acceptance Criteria:**
- [ ] Where Balancer pool math is used in previews, raw balances are used (not rated)
- [ ] The pattern from `SeigniorageDETFUnderwritingTarget.sol:201` is followed

### US-IDXEX-085.3: Remove all hardcoded discount magic numbers

**As** a maintainer,
**I want** no hardcoded discount constants in the preview system,
**So that** the preview is analytically correct for any fee rate, pool size, or token amount.

**Acceptance Criteria:**
- [ ] All instances of `vaultShares * 15 / 10000` are removed (5 locations)
- [ ] All instances of `low / 1000` buffer are removed or replaced with proper bounds (2 locations)
- [ ] The `_previewWethToRichir` in ExchangeInTarget also gets the proper simulation (was inconsistent in IDXEX-072)
- [ ] No new magic numbers are introduced

### US-IDXEX-085.4: Validate preview accuracy across all RICHIR routes

**As** a tester,
**I want** all RICHIR route preview tests to pass with the proper simulation approach,
**So that** we can be confident the fix is correct.

**Acceptance Criteria:**
- [ ] All 19 ProtocolDETFExchangeOut tests pass
- [ ] All 43 ProtocolDETF_Routes tests pass
- [ ] All 143+ protocol tests pass (zero regressions)
- [ ] Build succeeds

## Design Notes

The key insight is that the Aerodrome vault calls `compoundFees()` during `exchangeIn()`, which changes the pool reserves. The preview doesn't account for this because `previewExchangeIn()` calculates against the current (pre-compound) reserves. The fix is to preview the compound effect first, then use the post-compound reserves for the vault share calculation.

The approach should NOT involve:
- Hardcoded percentage discounts
- Empirically-tuned buffer values
- Conflating accrued fee compounding with swap fees

## Dependencies

- IDXEX-072 (Complete) — this task supersedes the IDXEX-072 approach
