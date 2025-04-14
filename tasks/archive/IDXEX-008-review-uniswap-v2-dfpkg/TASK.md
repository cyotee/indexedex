# Task IDXEX-008: Review Uniswap V2 DFPkg deployVault (Pair Creation + Initial Deposit)

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-01-12
**Type:** Code Review
**Dependencies:** None
**Worktree:** N/A (review task)

---

## Description

Code review of the Uniswap V2 DFPkg `deployVault` functionality. Identical scope to Camelot review (IDXEX-007) but for Uniswap V2. Confirm factory already exists in init.

## Review Focus

Safe pair creation, proportional deposit math, LP-to-vault deposit flow with Uniswap V2 semantics.

## Primary Risks

- Incorrect proportional math leading to unexpected token pulls
- Minting LP to wrong recipient or leaving approvals behind
- Incorrect handling of "new pair" reserves=0 scenario
- Factory initialization issues

## Review Checklist

### Factory Integration
- [ ] Factory in PkgInit is present
- [ ] Immutable use is correct
- [ ] Uses `getPair()` correctly
- [ ] Uses `createPair()` correctly

### Proportional Calculation
- [ ] Proportional math matches the spec
- [ ] Uses reserves correctly
- [ ] Never exceeds user-provided max amounts
- [ ] Leaves excess tokens with caller (never pulled)

### LP Token Flow
- [ ] Mint flow matches the spec
- [ ] LP tokens correctly deposited into vault

### Preview Function
- [ ] `previewDeployVault()` exists
- [ ] Matches on-chain calculation exactly

### Test Coverage (same scenarios as IDXEX-006)
- [ ] Tests cover: new pair no-deposit
- [ ] Tests cover: new pair with deposit
- [ ] Tests cover: existing pair proportional deposit
- [ ] Tests cover: existing pair no-deposit

## Files to Review

**Primary:**
- `contracts/protocols/dexes/uniswap/v2/*DFPkg*.sol`
- `contracts/protocols/dexes/uniswap/v2/*FactoryService*.sol`

**Tests:**
- `test/foundry/spec/protocols/dexes/uniswap/v2/`

## Completion Criteria

- [ ] All checklist items verified
- [ ] Findings documented in `docs/reviews/YYYY-MM-DD_IDXEX-008_uniswap-v2-dfpkg.md`
- [ ] No Blocker or High severity issues remain unfixed

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
