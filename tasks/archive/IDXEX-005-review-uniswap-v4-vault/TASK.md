# Task IDXEX-005: Review Uniswap V4 Standard Exchange Vault

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-01-12
**Type:** Code Review
**Dependencies:** None
**Worktree:** N/A (review task)

---

## Description

Code review of the Uniswap V4 Standard Exchange Vault. Focus on PoolManager unlock callback pattern, ERC-6909 balance handling, and V4-specific accounting.

**SCOPE LIMITATION:** This vault explicitly supports **hookless pools only** (pools where `hooks` address is `address(0)`). Pools with custom hooks introduce reentrancy, fee extraction, and delta manipulation risks that are out of scope.

## Review Focus

PoolManager unlock callback pattern, ERC-6909 balance handling, and V4-specific accounting.

## Primary Risks

- Incorrect lock/unlock callback flow causing stuck balances
- ERC-6909 vs ERC20 input detection edge cases
- Mis-handling PoolKey ordering and deltas
- **Accidental hook pool usage:** vault must reject pools with non-zero hook addresses

## Review Checklist

### Hookless Pool Enforcement
- [ ] Vault reverts if `PoolKey.hooks != address(0)` during initialization
- [ ] Vault reverts if `PoolKey.hooks != address(0)` during deposit

### unlockCallback()
- [ ] Validates caller is PoolManager
- [ ] Correctly settles/takes balances
- [ ] Handles deltas correctly

### ERC-6909 Support
- [ ] Correct token-id derivation / stored ERC-6909 config
- [ ] Deposits work for both ERC20 and ERC-6909 inputs
- [ ] Previews work for both ERC20 and ERC-6909 inputs
- [ ] Withdrawals return ERC20 as specified

### Position Identification
- [ ] Uses PoolKey + tick range
- [ ] Remains stable across upgrades

### Testing
- [ ] Fork tests on Ethereum mainnet cover ERC-6909 scenario
- [ ] Fork tests cover core flows
- [ ] Fork tests verify rejection of hook-enabled pools

## Review Artifacts to Produce

- [ ] A table of invariants:
  - unlockCallback safety
  - Delta settlement correctness
  - Conservation across deposit/withdraw
  - Preview vs actual semantics

## Files to Review

**Primary:**
- `contracts/protocols/dexes/uniswap/v4/`
- `contracts/vaults/concentrated/uniswap/v4/`

**Tests:**
- `test/foundry/spec/protocols/dexes/uniswap/v4/`

## Completion Criteria

- [ ] All checklist items verified
- [ ] Findings documented in `docs/reviews/YYYY-MM-DD_IDXEX-005_uniswap-v4-vault.md`
- [ ] Invariant table produced
- [ ] No Blocker or High severity issues remain unfixed

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
