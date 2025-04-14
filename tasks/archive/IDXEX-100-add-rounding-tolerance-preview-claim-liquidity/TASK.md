Title: Add rounding-tolerance to previewClaimLiquidity and parity tests
ID: IDXEX-100
Status: Ready
Priority: High
Dependencies: IDXEX-064

Summary
- Ensure previewClaimLiquidity accounts for the same 1-wei rounding tolerance used in _removeLiquidityFromPool, or explicitly document parity behavior. Add unit tests asserting previewClaimLiquidity(lpAmount) does not overestimate actual claimLiquidity by more than 1 wei.

Problem
- previewClaimLiquidity previously used scaled or normalized balances which can lead to slight overestimates vs actual execution that consumes raw pool balances. This causes parity failures in tests and may mislead callers relying on previews.

Goal
- Update previewClaimLiquidity to use the same balance source/units as removeLiquidity (balancesRaw) or document and align expected tolerance. Add deterministic unit tests that check preview <= execution + 1 wei across representative scenarios.

Acceptance Criteria
- previewClaimLiquidity either adjusted or documented so previews do not overestimate actual extracted liquidity by more than 1 wei.
- Tests added: parity tests for an initialized pool, near-empty pool, and token with a rate provider.
- Tests pass on CI (forge test).

Notes
- Depends on IDXEX-064 which fixed the balance source.
