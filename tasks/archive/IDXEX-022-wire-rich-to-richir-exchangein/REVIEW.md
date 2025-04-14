# Code Review: IDXEX-022

**Reviewer:** OpenCode (AI)
**Review Started:** 2026-01-31
**Status:** In Progress

---

## Clarifying Questions

Questions asked to understand review criteria:

- None.

---

## Review Findings

### Finding 1: Potential BPT dust + stale reserve accounting
**File:** `contracts/vaults/protocol/ProtocolDETFExchangeInTarget.sol`
**Severity:** Medium
**Description:** `_addToReservePoolForRichir()` computes `bptOut_` with `calcBptOutGivenSingleIn(...)` and returns that value, but does not capture/return the actual BPT minted by `prepayAddLiquidityUnbalanced` (which returns `bptAmountOut`). If actual minted BPT differs (rounding / internal Balancer math), the route can either (a) revert unexpectedly (minBptOut too high) or (b) mint/credit RICHIR against a lower `bptOut_` than the contract actually received, leaving unaccounted BPT in the vault.
**Status:** Open
**Resolution:** Prefer using the router’s returned BPT amount (or measuring `balanceOf` delta) as the canonical `bptOut` for (1) protocol-NFT position credit and (2) RICHIR mint.

### Finding 2: Preview correctness depends on Richir mint semantics
**File:** `contracts/vaults/protocol/ProtocolDETFExchangeInTarget.sol`
**Severity:** Low
**Description:** `_previewRichToRichir()` simulates a post-deposit “rate” and returns `bptOut * newRate`. This matches the BondingTarget preview logic and aligns with `RICHIRTarget.mintFromNFTSale` minting shares 1:1 with the BPT credited, but the coupling is non-obvious; drift can still occur if upstream BPT-out math diverges from actual minted.
**Status:** Open
**Resolution:** Add a brief comment tying the preview math to the exact `mintFromNFTSale` semantics (and/or a unit test that asserts preview monotonicity/consistency across a range of inputs).

### Finding 3: Tests allow false positives on reverts
**File:** `test/foundry/spec/vaults/protocol/ProtocolDETF_Routes.t.sol`
**Severity:** Low
**Description:** Slippage/deadline tests use bare `vm.expectRevert()` (no selector). They can pass due to unrelated failures/regressions.
**Status:** Open
**Resolution:** Expect specific revert selectors (e.g., `SlippageExceeded`, deadline revert) to ensure tests fail for the right reason.

### Finding 4: Public docs / NatSpec route list drift
**File:** `contracts/vaults/protocol/ProtocolDETFExchangeInTarget.sol`
**Severity:** Low
**Description:** `previewExchangeIn` documentation lists supported routes but doesn’t reflect the newly-added RICH -> RICHIR path.
**Status:** Open
**Resolution:** Update the route list in NatSpec to match actual dispatch behavior.

### Finding 5: “Parity” is true for standard ERC20 allowance but not necessarily for edge tokens
**File:** `contracts/vaults/protocol/ProtocolDETFExchangeInTarget.sol`, `contracts/vaults/protocol/ProtocolDETFBondingTarget.sol`
**Severity:** Low
**Description:** `exchangeIn` route uses `_secureTokenTransfer` (Permit2 fallback + fee-on-transfer tolerant accounting) while `richToRichir` uses a strict `transferFrom(richIn)` then forwards `richIn`. If RICH ever behaves non-standard (fee-on-transfer), or caller relies on Permit2 rather than ERC20 allowance, the two entry points can diverge.
**Status:** Open
**Resolution:** Either explicitly scope the parity guarantee to standard ERC20 allowance flows, or consider aligning the transfer-in semantics between the two entrypoints.

---

## Suggestions

Actionable items for follow-up tasks:

### Suggestion 1: Capture actual BPT minted and keep reserve accounting consistent
**Priority:** High
**Description:** Update `_addToReservePoolForRichir()` / `_executeRichToRichir()` to rely on actual minted BPT (router return value or measured balance delta), avoid leaving BPT dust, and set `ERC4626Repo._setLastTotalAssets(...)` after the final BPT move (or document why it’s correct to set earlier).
**Affected Files:**
- `contracts/vaults/protocol/ProtocolDETFExchangeInTarget.sol`
**User Response:** (pending)
**Notes:** This is the biggest functional-risk area if math rounding ever diverges from Balancer internals.

### Suggestion 2: Tighten revert assertions in tests
**Priority:** Medium
**Description:** Replace bare `vm.expectRevert()` with selectors for slippage/deadline tests; add `assertGt(expectedRichir, 0)` in the slippage test before computing `unrealisticMinOut`.
**Affected Files:**
- `test/foundry/spec/vaults/protocol/ProtocolDETF_Routes.t.sol`
**User Response:** (pending)
**Notes:** Improves signal when debugging regressions.

### Suggestion 3: Add end-state parity assertions
**Priority:** Low
**Description:** In the parity test, also assert important side effects match (e.g., DETF has no unexpected RICH/BPT dust; protocol NFT position updated as expected).
**Affected Files:**
- `test/foundry/spec/vaults/protocol/ProtocolDETF_Routes.t.sol`
**User Response:** (pending)
**Notes:** Makes the parity test more meaningful than “same return value”.

---

## Review Summary

**Findings:** 5 (1 medium-risk functional/accounting issue, 2 medium/low correctness-doc/test issues)
**Suggestions:** 3
**Recommendation:** Request changes (address BPT dust/accounting + tighten tests/docs).

## Local Verification Notes

- I was not able to re-run `forge build` cleanly in this worktree due to a submodule/dependency install error attempting to clone `lib/frontend-monorepo` into an existing non-empty directory. The task PROGRESS.md reports build/tests passing; recommend re-running in a clean environment to confirm.

---

**When review complete, output:** `<promise>PHASE_DONE</promise>`
