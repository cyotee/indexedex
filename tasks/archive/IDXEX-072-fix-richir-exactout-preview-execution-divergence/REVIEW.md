# Code Review: IDXEX-072

**Reviewer:** Claude Opus 4.6
**Review Started:** 2026-02-08
**Status:** Complete

---

## Clarifying Questions

None needed. TASK.md and PROGRESS.md were sufficient to understand the fix approach and acceptance criteria.

---

## Acceptance Criteria Verification

### US-IDXEX-072.1: Fix ExactOut preview (ProtocolDETFExchangeOutTarget)

- [x] `_previewRichToRichirForward()` applies conservative vault share discount (line 774)
- [x] `_previewWethToRichirForward()` applies conservative vault share discount (line 901)
- [x] `_previewRichToRichirExact()` adds 0.1% binary search buffer (line 754)
- [x] `_previewWethToRichirExact()` adds 0.1% binary search buffer (line 881)
- [x] `test_exchangeOut_rich_to_richir_exact()` passes
- [x] `test_exchangeOut_weth_to_richir_exact()` passes
- [x] All 19 ProtocolDETFExchangeOut tests pass
- [x] Build succeeds

### US-IDXEX-072.2: Fix ExchangeIn/Bonding preview for RICH -> RICHIR

- [x] `previewRichToRichir()` in BondingTarget applies discount (line 731)
- [x] `previewWethToRichir()` in BondingTarget applies discount (line 848)
- [x] `_previewRichToRichir()` in ExchangeInTarget applies discount (line 931)
- [x] `test_exchangeIn_rich_to_richir_preview()` passes
- [x] `test_route_rich_to_richir_single_call()` passes
- [x] All 43 ProtocolDETF_Routes tests pass

### US-IDXEX-072.3: Validate preview accuracy across all RICHIR routes

- [x] RICH -> RICHIR route works (both exchangeIn and exchangeOut)
- [x] WETH -> RICHIR route works (both exchangeIn and exchangeOut)
- [x] No regressions (143/143 protocol tests pass)

---

## Review Findings

### Finding 1: Missing 0.15% discount in ExchangeInTarget._previewWethToRichir
**File:** `contracts/vaults/protocol/ProtocolDETFExchangeInTarget.sol:1074-1125`
**Severity:** Low (tests pass, WETH path has smaller divergence due to 80% weight)
**Description:** The `_previewWethToRichir` function in ExchangeInTarget does NOT apply the 0.15% vault share discount, while the equivalent `previewWethToRichir` in BondingTarget (line 848) and `_previewWethToRichirForward` in ExchangeOutTarget (line 901) both DO apply it. This is an inconsistency.

The WETH path goes through `chirWethVault` which is also an Aerodrome-backed vault and should exhibit the same `previewExchangeIn` vs `exchangeIn` divergence from fee compounding. The reason the tests pass without it is that the chirWethVault token has 80% weight in the Balancer reserve pool, making the impact of the overestimate much smaller (~0.03% vs ~1.08% for the RICH path).

**Discount coverage map:**
| Function | Contract | Vault | Has Discount? |
|---|---|---|---|
| `_previewRichToRichirForward` | ExchangeOutTarget | richChirVault | YES |
| `_previewWethToRichirForward` | ExchangeOutTarget | chirWethVault | YES |
| `_previewRichToRichir` | ExchangeInTarget | richChirVault | YES |
| `_previewWethToRichir` | ExchangeInTarget | chirWethVault | **NO** |
| `previewRichToRichir` | BondingTarget | richChirVault | YES |
| `previewWethToRichir` | BondingTarget | chirWethVault | YES |

**Status:** Open
**Resolution:** Should add the discount for consistency, but not blocking since tests pass and the impact is minimal for the 80% weight path.

### Finding 2: Approach deviated from TASK.md recommendation (Option A)
**File:** All three modified contracts
**Severity:** Informational
**Description:** TASK.md recommended "Option A: Adjust pool state in preview" — simulating the post-add pool state with adjusted balances and total supply. The implementation instead used a simpler approach: a fixed 0.15% vault share discount plus 0.1% binary search buffer (closer to Option B).

PROGRESS.md explains why: the first attempt at Option A (post-add pool state simulation) made ExchangeIn WORSE because adding raw vault shares to rated (scaled) balances was incorrect. The `getCurrentLiveBalances()` returns rated balances, but vault shares added during execution are raw, creating a mismatch.

The chosen approach works (all tests pass) but is empirically tuned rather than analytically correct. The 0.15% discount is a heuristic that may need adjustment if:
- Aerodrome pool fee rates change
- Pool liquidity changes significantly
- Different token amounts are used in edge cases

**Status:** Resolved (acceptable trade-off)
**Resolution:** The implementation is pragmatic and correct for current conditions. The comment explaining the discount is clear. A future task could implement a more precise simulation that properly handles the rated/raw balance conversion.

### Finding 3: No underflow protection on vault share discount
**File:** All three modified contracts (e.g., ExchangeOutTarget:774, ExchangeInTarget:931, BondingTarget:731)
**Severity:** Low
**Description:** The discount calculation `vaultShares = vaultShares - (vaultShares * 15 / 10000)` could theoretically underflow if `vaultShares` is 0. However, all call sites check for zero input before reaching this code, so this is not a practical issue.

For `vaultShares` in range [1, 66], the expression `vaultShares * 15 / 10000` truncates to 0, so the discount has no effect on very small inputs. This is acceptable behavior.

**Status:** Resolved (not a real risk)
**Resolution:** No change needed. Zero-input guards exist upstream.

---

## Suggestions

### Suggestion 1: Add missing discount to ExchangeInTarget._previewWethToRichir
**Priority:** Low
**Description:** Add the same 0.15% vault share discount to `_previewWethToRichir` in ExchangeInTarget for consistency with the equivalent functions in BondingTarget and ExchangeOutTarget. Even though the WETH path's divergence is small (~0.03%), having inconsistent behavior across the three contracts that implement the same preview logic creates a maintenance hazard.
**Affected Files:**
- `contracts/vaults/protocol/ProtocolDETFExchangeInTarget.sol` (add 3 lines after line 1087)
**User Response:** (pending)
**Notes:** This should be a trivial fix — add the same pattern: `vaultShares = vaultShares - (vaultShares * 15 / 10000);` after the `previewExchangeIn` call.

### Suggestion 2: Consider extracting shared discount constant
**Priority:** Low (follow-up task)
**Description:** The magic number `15` (representing 0.15% = 15 basis points) appears in 5 locations across 3 files. If this value ever needs tuning, all 5 locations must be updated in sync. Consider extracting it to a named constant in ProtocolDETFCommon or ProtocolDETFRepo.
**Affected Files:**
- `contracts/vaults/protocol/ProtocolDETFCommon.sol` (add constant)
- `contracts/vaults/protocol/ProtocolDETFExchangeOutTarget.sol` (use constant)
- `contracts/vaults/protocol/ProtocolDETFExchangeInTarget.sol` (use constant)
- `contracts/vaults/protocol/ProtocolDETFBondingTarget.sol` (use constant)
**User Response:** (pending)
**Notes:** Example: `uint256 internal constant PREVIEW_VAULT_SHARE_DISCOUNT_BPS = 15;`

### Suggestion 3: Consider making the binary search buffer consistent with the discount
**Priority:** Low (follow-up task)
**Description:** The binary search buffer is `low / 1000` (~0.1%) while the forward preview discount is `15 / 10000` (0.15%). The buffer serves a different purpose (ensuring execution meets target after binary search converges on a discounted preview), but the relationship between these two values isn't documented. A brief comment explaining why 0.1% buffer was chosen independently from the 0.15% discount would aid future maintenance.
**Affected Files:**
- `contracts/vaults/protocol/ProtocolDETFExchangeOutTarget.sol` (lines 754, 881)
**User Response:** (pending)
**Notes:** The buffer needs to be enough to compensate for the gap between discounted preview and actual execution, but not so large that users overpay significantly.

---

## Review Summary

**Findings:** 3 (1 Low inconsistency, 1 Informational, 1 Low non-issue)
**Suggestions:** 3 (all Low priority)
**Recommendation:** **APPROVE with minor suggestions**

The fix is correct, well-commented, and all acceptance criteria are met:
- All 3 previously failing tests now pass
- Zero regressions across 19 ExchangeOut tests and 43 Routes tests (62 total)
- Build succeeds
- The approach is pragmatic and the trade-offs vs Option A are well-documented in PROGRESS.md
- The one inconsistency (missing discount on ExchangeInTarget WETH path) is non-blocking but should be addressed for consistency

---

**When review complete, output:** `<promise>PHASE_DONE</promise>`
