# Task IDXEX-007: Review Camelot V2 DFPkg deployVault (Pair Creation + Initial Deposit)

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-01-12
**Type:** Code Review
**Dependencies:** None
**Worktree:** N/A (review task)

---

## Description

Code review of the Camelot V2 DFPkg `deployVault` functionality. Identical scope to Aerodrome review (IDXEX-006) but with Camelot factory/pair semantics.

## Review Focus

Safe pair creation, proportional deposit math, LP-to-vault deposit flow with Camelot-specific semantics.

## Primary Risks

- Incorrect proportional math leading to unexpected token pulls
- Minting LP to wrong recipient or leaving approvals behind
- Incorrect handling of "new pair" reserves=0 scenario
- Camelot-specific quirks not handled

## Review Checklist

### Factory Integration
- [ ] Uses `getPair()` correctly
- [ ] Uses `createPair()` correctly
- [ ] Creates pair only when needed

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
- `contracts/protocols/dexes/camelot/v2/*DFPkg*.sol`
- `contracts/protocols/dexes/camelot/v2/*FactoryService*.sol`

**Tests:**
- `test/foundry/spec/protocols/dexes/camelot/v2/`

## Completion Criteria

- [ ] All checklist items verified
- [ ] Findings documented in `docs/reviews/YYYY-MM-DD_IDXEX-007_camelot-dfpkg.md`
- [ ] No Blocker or High severity issues remain unfixed

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
