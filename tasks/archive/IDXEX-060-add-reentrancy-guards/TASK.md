# Task IDXEX-060: Add Reentrancy Guards to CamelotV2/Aerodrome

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-08
**Dependencies:** IDXEX-034
**Worktree:** `feature/IDXEX-060-add-reentrancy-guards`

---

## Description

Add reentrancy guards to vulnerable external entry points in CamelotV2 and Aerodrome StandardExchange facets.

This hardening prevents reentrancy attacks during swaps and liquidity operations where external token transfers or callbacks may re-enter protocol logic.

## Dependencies

- IDXEX-034: Fix StandardExchangeOut Pretransferred Refund Semantics (must be applied first)

## User Stories

### US-IDXEX-060.1: Prevent reentrancy during swaps

As a protocol maintainer, I want swaps to be protected by reentrancy guards so that malicious token callbacks cannot re-enter swap logic and manipulate state.

**Acceptance Criteria:**
- [ ] Add and apply reentrancy guards to swap entry points in CamelotV2StandardExchange and AerodromeStandardExchange facets
- [ ] Ensure no storage writes are left unprotected
- [ ] Add unit tests demonstrating that attempted reentrancy reverts

### US-IDXEX-060.2: Prevent reentrancy during liquidity updates

As a protocol maintainer, I want liquidity add/remove operations to be guarded so callbacks cannot drain or corrupt pool/vault state.

**Acceptance Criteria:**
- [ ] Guard liquidity add/remove entry points where external transfers occur
- [ ] Add tests for edge-case callback behavior

## Technical Details

- Prefer OpenZeppelin-style nonReentrant modifier or an internal reentrancy lock pattern compatible with Crane diamond facets.
- Avoid changing external function selectors; implement guards in facet logic and shared libraries where appropriate.
- Update tests under contracts/protocols/* to cover reentrancy scenarios.

## Files to Create/Modify

**Modified Files:**
- `contracts/protocols/camelot/v2/*StandardExchange*.sol` - add reentrancy guards
- `contracts/protocols/aerodrome/v1/*StandardExchange*.sol` - add reentrancy guards

**Tests:**
- `test/protocols/*/ReentrancyGuard.t.sol` - new tests demonstrating revert on reentrant callback

## Inventory Check

- [ ] Crane factory and test base are available (IndexedexTest)

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] Tests added and passing
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
