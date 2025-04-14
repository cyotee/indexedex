# Review Header

- **Task/Worktree:** IDXEX-006 / feature/review-aerodrome-dfpkg
- **Reviewer:** Claude Opus 4.6
- **Date:** 2026-02-06
- **Scope (files/dirs):** `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol`, `*FactoryService.sol`, `*Common.sol`, `*InTarget.sol`, `*Repo.sol`, `test/.../AerodromeStandardExchange_DeployWithPool.t.sol`
- **Tests run (exact commands):** `forge test --match-path "test/foundry/spec/protocol/dexes/aerodrome/v1/AerodromeStandardExchange_DeployWithPool.t.sol" -vvv` (8/8 pass)
- **Environment:** Foundry, Solc 0.8.30, spec tests with mock Aerodrome stubs

## Findings Table

| ID | Severity | Area | Summary | Evidence | Recommendation | Fix Now? |
|----|----------|------|---------|----------|----------------|----------|
| F-01 | Medium | LP Deposit | `exchangeIn` called with `pretransferred=false` but LP held by DFPkg; works via approve+transferFrom but TASK.md specifies pretransferred=true | DFPkg:198-207 | Switch to `safeTransfer` + `pretransferred=true` for gas savings and spec compliance | Yes |
| F-02 | Low | Approval | `safeApprove` may leave stale allowance on partial consumption | DFPkg:198 | Use `approve` or clear after exchangeIn | No |
| F-03 | Low | Code Duplication | Proportional math duplicated between `_depositLiquidity` and `previewDeployVault` | DFPkg:340-353 vs DFPkg:256-270 | Extract `_proportionalDeposit` helper per IDXEX-014 pattern | No |
| F-04 | Nit | Naming | Comment header says "IUniswapV2StandardExchangeDFPkg" | DFPkg:157 | Fix to "IAerodromeStandardExchangeDFPkg" | No |
| F-05 | Nit | Typo | `vaultFeeOracelQuery` misspells "Oracle" | DFPkg:78 | Rename to `vaultFeeOracleQuery` | No |

## Deferred Debt

| ID | Category | Description | Rationale for Deferring | Suggested Deadline/Trigger |
|----|----------|-------------|--------------------------|----------------------------|
| D-01 | Refactor | Extract shared `_proportionalDeposit` helper | IDXEX-014 established pattern; IDXEX-042 covers Camelot first | After IDXEX-042, create Aerodrome follow-up |
| D-02 | Testing | Add fuzz tests for proportional math edge cases | Fixed-amount tests pass; fuzz would catch rounding issues | Before mainnet deployment |
| D-03 | Testing | Test repeated deployVault-with-deposit on same pool | Exercises safeApprove path twice; current tests only once | Before mainnet deployment |

## Review Summary

- **Blockers:** 0
- **High:** 0
- **Medium:** 1
- **Low/Nits:** 4
- **Recommended next action:** Address F-01 (switch to pretransferred=true). Create follow-up task for D-01 proportional math refactor after IDXEX-042.
