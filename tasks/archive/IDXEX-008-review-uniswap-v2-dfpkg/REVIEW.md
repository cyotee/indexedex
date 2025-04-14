# Review: IDXEX-008-review-uniswap-v2-dfpkg

## Review Header

- **Task:** IDXEX-008-review-uniswap-v2-dfpkg
- **Reviewer:** GitHub Copilot (GPT-5.2)
- **Date:** 2026-01-13
- **Scope:** See TASK.md
- **Tests run:** `forge build`; `forge test --match-path test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_DeployWithPool.t.sol`
- **Environment:** macOS

## Findings Table

| ID | Severity | Area | Summary | Evidence | Recommendation | Fix Now? |
|----|----------|------|---------|----------|----------------|----------|
| 1 | Low | Proportional calc | Potential div-by-zero if one reserve is zero | `UniswapV2StandardExchangeDFPkg._calculateProportionalAmounts()` previously only handled both reserves zero | Treat `reserveA == 0 || reserveB == 0` as an empty/invalid state (align with preview) | ✅ Fixed |
| 2 | Info | Maintainability | Preview + execution duplicate proportional math | `previewDeployVault()` duplicates `_calculateProportionalAmounts()` logic | Optional refactor to a shared helper to reduce drift | ❌ |
| 3 | Info | Hygiene | LP approval not cleared after `exchangeIn()` | `_depositLPToVault()` approves `lpAmount` and leaves allowance | Optional `safeApprove(vault, 0)` after call (low priority) | ❌ |

## Deferred Debt

| ID | Category | Description | Rationale for Deferring | Converted To |
|----|----------|-------------|--------------------------|--------------|
| D1 | Refactor | Extract shared proportional math for preview + execution | Avoids drift; not required for correctness | IDXEX-014 |
| D2 | Hygiene | Clear temporary LP token approvals | Cosmetic; LP is standard and allowance is bounded | IDXEX-015 |

## Review Summary

- **Blockers:** 0
- **High:** 0
- **Medium:** 0
- **Low/Nits:** 1
- **Recommended next action:** Approve; optionally schedule D1/D2 cleanup.
