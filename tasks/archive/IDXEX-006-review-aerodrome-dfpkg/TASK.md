# Task IDXEX-006: Review Aerodrome V1 DFPkg deployVault (Pool Creation + Initial Deposit)

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-01-12
**Type:** Code Review
**Dependencies:** None
**Worktree:** N/A (review task)

---

## Description

Code review of the Aerodrome V1 DFPkg `deployVault` functionality. Focus on safe pool creation, proportional deposit math, and LP-to-vault deposit flow.

## Review Focus

Safe pool creation, proportional deposit math, and LP-to-vault deposit flow.

## Primary Risks

- Incorrect proportional math leading to unexpected token pulls
- Minting LP to wrong recipient or leaving approvals behind
- Incorrect handling of "new pool" reserves=0 scenario

## Review Checklist

### Pool Existence Check
- [ ] Uses `getPool(tokenA, tokenB, false)` correctly
- [ ] Creates pool only when needed

### Proportional Calculation
- [ ] Uses reserves correctly
- [ ] Never exceeds user-provided max amounts
- [ ] Leaves excess tokens with caller (never pulled)

### Initial Deposit Conditions
- [ ] Matches spec (both amounts > 0 and recipient != 0)

### LP Token Flow
- [ ] LP tokens minted to the package
- [ ] Then deposited into the vault using `pretransferred=true`

### Preview Function
- [ ] `previewDeployVault()` exists
- [ ] Matches on-chain calculation exactly

### Test Coverage
- [ ] Tests cover: new pool no-deposit
- [ ] Tests cover: new pool with deposit
- [ ] Tests cover: existing pool proportional deposit
- [ ] Tests cover: existing pool no-deposit

## Files to Review

**Primary:**
- `contracts/protocols/dexes/aerodrome/v1/*DFPkg*.sol`
- `contracts/protocols/dexes/aerodrome/v1/*FactoryService*.sol`

**Tests:**
- `test/foundry/spec/protocols/dexes/aerodrome/v1/`

## Completion Criteria

- [ ] All checklist items verified
- [ ] Findings documented in `docs/reviews/YYYY-MM-DD_IDXEX-006_aerodrome-dfpkg.md`
- [ ] No Blocker or High severity issues remain unfixed

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
