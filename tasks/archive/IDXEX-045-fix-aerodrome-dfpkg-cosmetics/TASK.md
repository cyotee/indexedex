# Task IDXEX-045: Fix Aerodrome DFPkg Cosmetic Issues

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-06
**Type:** Cleanup
**Dependencies:** IDXEX-006 ✓
**Worktree:** `feature/fix-aerodrome-dfpkg-cosmetics`
**Origin:** Code review findings F-04 and F-05 from IDXEX-006

---

## Description

Two cosmetic issues found during code review of the Aerodrome V1 DFPkg:

1. **F-04 (Nit):** Comment header on line ~157-158 says "IUniswapV2StandardExchangeDFPkg" but should say "IAerodromeStandardExchangeDFPkg"
2. **F-05 (Nit):** Field name `vaultFeeOracelQuery` in the `PkgInit` struct (line ~78) has a typo — "Oracel" should be "Oracle". This typo also appears in `Aerodrome_Component_FactoryService.sol` (line ~137).

(Created from code review of IDXEX-006, findings F-04 and F-05)

## Files to Modify

- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol` (lines ~78, ~157-158)
- `contracts/protocols/dexes/aerodrome/v1/Aerodrome_Component_FactoryService.sol` (line ~137)

## Important

The `vaultFeeOracelQuery` rename affects a struct field. Search for all references to this field name across the codebase before renaming — it may be used in tests or other contracts.

## Acceptance Criteria

- [ ] Comment on line ~157 references "IAerodromeStandardExchangeDFPkg" (not Uniswap)
- [ ] `vaultFeeOracelQuery` renamed to `vaultFeeOracleQuery` everywhere it appears
- [ ] All existing tests pass
- [ ] Build succeeds

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] Tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
