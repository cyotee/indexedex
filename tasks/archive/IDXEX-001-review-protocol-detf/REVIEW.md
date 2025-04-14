# Review: IDXEX-001-review-protocol-detf

## Review Header

- **Task:** IDXEX-001-review-protocol-detf
- **Reviewer:** Claude Opus 4.5
- **Date:** 2026-01-28
- **Scope:** Full Protocol DETF implementation review per TASK.md checklist
- **Tests run:** Existing spec tests verified passing
- **Environment:** IndexedEx main branch

## Findings Table

| ID | Severity | Area | Summary | Evidence | Recommendation | Fix Now? |
|----|----------|------|---------|----------|----------------|----------|
| F-001 | HIGH | Donation Flow | WETH donations don't deposit vault shares to reserve pool | `ProtocolDETFBondingTarget.sol:604-640` - vault shares sent to NFT vault instead of reserve pool via `_addToReservePool()` | Create IDXEX-018 to fix donation flow | Yes |
| F-002 | HIGH | Donation Flow | CHIR donations transferred instead of burned | `ProtocolDETFBondingTarget.sol:629-631` - uses `safeTransfer` instead of `ERC20Repo._burn()` | Include in IDXEX-018 fix | Yes |
| F-003 | MEDIUM | Route Support | WETH → CHIR exact-out not implemented | `ProtocolDETFExchangeOutTarget.sol` reverts with `ExchangeOutNotAvailable()` for all routes | Create IDXEX-019 - user confirmed this should be implemented | No |
| F-004 | LOW | Route Support | RICH → RICHIR requires 2 calls | No single-call wrapper exists; requires `bondWithRich()` + `sellNFT()` | Create IDXEX-020 for convenience wrapper | No |
| F-005 | LOW | Route Support | WETH → RICHIR requires 2 calls | No single-call wrapper exists; requires `bondWithWeth()` + `sellNFT()` | Create IDXEX-021 for convenience wrapper | No |
| F-006 | INFO | Dead Code | Wrong rounding in disabled exchangeOut | `ProtocolDETFExchangeOutTarget.sol:_executeMintExactChir` uses floor instead of ceiling | Low priority - code is disabled | No |

## Checklist Verification

### Section 1: Peg Oracle

| Item | Status | Notes |
|------|--------|-------|
| 1.1 Proportional CHIR split | ✓ | `_calcSyntheticPrice()` correctly splits CHIR supply proportionally across pools |
| 1.2 Rounding | ✓ | Seigniorage calculation rounds down (vault-favorable) |
| 1.3 Threshold comparisons | ✓ | `_isMintingAllowed`: `syntheticPrice > mintThreshold`, `_isBurningAllowed`: `syntheticPrice < burnThreshold` |

### Section 2: Donation Flow

| Item | Status | Notes |
|------|--------|-------|
| 2.1 WETH donation routes to reserve | ❌ | **BUG**: Vault shares go to NFT vault, not reserve pool |
| 2.2 CHIR donation burns CHIR | ❌ | **BUG**: CHIR transferred instead of burned |

### Section 3: Token Mechanics

| Item | Status | Notes |
|------|--------|-------|
| 3.1 RICH static supply | ✓ | Deployed via `ERC20PermitDFPkg`, no mint capability |
| 3.2 RICHIR shares model | ✓ | `sharesOf`/`totalShares` correctly tracked in `RICHIRRepo` |
| 3.3 Live balanceOf/totalSupply | ✓ | Computed from redemption rate via `_sharesToBalance()` |
| 3.4 Partial redemptions | ✓ | Rounding is consistent, no underflow risk |

### Section 4: Redemption Unwind Path

| Item | Status | Notes |
|------|--------|-------|
| 4.1 Slippage/deadline protections | ✓ | `minAmountOut` and `deadline` parameters propagated |
| 4.2 CHIR burned | ✓ | Uses `_secureChirBurn()` → `ERC20Repo._burn()` |

### Section 5: Route Support

| Item | Status | Notes |
|------|--------|-------|
| 5.1 WETH → CHIR exact-in | ✓ | Gated by `syntheticPrice > mintThreshold` |
| 5.2 WETH → CHIR exact-out | ❌ | Not implemented (IDXEX-019) |
| 5.3 CHIR → RICH not exposed | ✓ | Correctly not exposed |
| 5.4 CHIR → WETH 2-leg unwind | ✓ | Matches intended flow |
| 5.5 RICH → CHIR wrapper | ✓ | Routes RICH → CHIR → WETH → CHIR mint |
| 5.6 RICHIR → WETH | ✓ | Always redeemable (no price gate) |
| 5.7 WETH → Bond NFT | ✓ | Matches step enumeration |
| 5.8 Bond NFT → WETH | ✓ | Lock enforced via `block.timestamp < unlockTime` |
| 5.9 Bond NFT → RICHIR | ✓ | Principal-only transfer, rewards claimed, NFT burned |
| 5.10 RICH → RICHIR wrapper | ⚠️ | Missing single-call wrapper (IDXEX-020) |
| 5.11 WETH → RICHIR wrapper | ⚠️ | Missing single-call wrapper (IDXEX-021) |

### Section 6: Balancer Reserve Pool

| Item | Status | Notes |
|------|--------|-------|
| 6.1 Pool math/asset ordering | ✓ | Indices determined by address comparison, validated in `_initializeReservePool()` |
| 6.2 Unbalanced deposits/withdrawals | ✓ | Uses `calcBptOutGivenSingleIn()` with proper invariant/fee math |

### Section 7: Access Control

| Item | Status | Notes |
|------|--------|-------|
| 7.1 Reentrancy protection | ✓ | All external state-changing functions have `lock` modifier |
| 7.2 Administrative access | ✓ | NFT vault internal functions use `onlyOwner` |

### Section 8: Testing

| Item | Status | Notes |
|------|--------|-------|
| 8.1 Fuzz tests | ✓ | `testFuzz_calcSyntheticPrice_nonZero`, `testFuzz_bonusMultiplier_bounds`, `testFuzz_conversion_roundTrip` |
| 8.2 Invariant tests | ❌ | None found - tracked in IDXEX-010 |
| 8.3 Integration tests | ✓ | `ProtocolDETF_Routes.t.sol`, `ProtocolDETF_IntegrationBase.t.sol` |

## Invariant Table

| Invariant | Description | Verified |
|-----------|-------------|----------|
| INV-001 | CHIR totalSupply = sum of all holder balances | ✓ ERC20 standard |
| INV-002 | BPT held by CHIR contract >= sum of all NFT position shares | ✓ Share accounting in NFT vault |
| INV-003 | RICHIR totalShares = sum of all holder shares | ✓ Share accounting in RICHIRRepo |
| INV-004 | Redemption: CHIR burned = CHIR input (no CHIR leakage) | ✓ `_secureChirBurn()` called |
| INV-005 | Reserve pool indices are 0 or 1 and different | ✓ Validated in `_initializeReservePool()` |
| INV-006 | chirWethVaultWeight + richChirVaultWeight = 1e18 | ✓ 80% + 20% = 100% |

## MEV/Slippage Assumptions

| Interaction | Protection | Notes |
|-------------|------------|-------|
| Aerodrome LP deposit | `minAmountOut` on vault shares | Propagated through `exchangeIn()` |
| Aerodrome LP withdrawal | `minAmountOut` on underlying tokens | Propagated through `exchangeIn()` |
| Balancer pool deposit | `minBptOut` computed via `calcBptOutGivenSingleIn()` | Exact amount used as minimum |
| Balancer pool withdrawal | Proportional exit (no slippage) | Uses `(balance * bptIn) / totalSupply` |
| Multi-hop swaps | Route-level `deadline` | Propagated through all hops |

## Deferred Debt

| ID | Category | Description | Rationale for Deferring | Suggested Deadline/Trigger |
|----|----------|-------------|--------------------------|----------------------------|
| D-001 | Testing | Invariant tests missing | Tracked separately in IDXEX-010 | Before mainnet deployment |
| D-002 | Feature | WETH → CHIR exact-out | Not critical for MVP | IDXEX-019 |
| D-003 | UX | Single-call wrappers | Convenience only, not blocking | IDXEX-020, IDXEX-021 |

## Tasks Created During Review

| Task ID | Title | Severity | Status |
|---------|-------|----------|--------|
| IDXEX-018 | Fix Protocol DETF Donation Flow | HIGH | Ready |
| IDXEX-019 | Implement WETH → CHIR Exact-Out Exchange | MEDIUM | Ready |
| IDXEX-020 | Implement RICH → RICHIR Single-Call Wrapper | LOW | Ready |
| IDXEX-021 | Implement WETH → RICHIR Single-Call Wrapper | LOW | Ready |

## Review Summary

- **Blockers:** 0
- **High:** 2 (both in IDXEX-018)
- **Medium:** 1 (IDXEX-019)
- **Low/Nits:** 2 (IDXEX-020, IDXEX-021)
- **Recommended next action:** Fix IDXEX-018 (donation flow bugs) before production deployment

## Conclusion

The core Protocol DETF implementation is **correct** for all supported routes. The synthetic price oracle, token mechanics, redemption paths, reserve pool integration, and access control all function as designed.

**Critical Issue:** The donation flow (IDXEX-018) has two HIGH severity bugs that must be fixed before production:
1. WETH donations don't deposit to reserve pool
2. CHIR donations are transferred instead of burned

**Feature Gaps:** Three convenience wrappers are missing (IDXEX-019, IDXEX-020, IDXEX-021) but are not blocking for core functionality.

**Testing Gap:** Invariant tests are missing (tracked in IDXEX-010).

---

**Review Status:** Complete

**Recommendation:** Mark IDXEX-001 as Complete. IDXEX-018 must be prioritized for immediate fix.
