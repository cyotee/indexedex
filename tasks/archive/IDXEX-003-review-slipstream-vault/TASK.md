# Task IDXEX-003: Review Slipstream Standard Exchange Vault (Concentrated Liquidity)

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-01-12
**Type:** Code Review
**Dependencies:** None
**Worktree:** N/A (review task)

---

## Description

Code review of the Slipstream (Aerodrome/Velodrome concentrated liquidity) Standard Exchange Vault implementation. Focus on multi-position NFT management, state transitions, volatility-based range calculation, and consolidation.

## Review Focus

Multi-position NFT management, state transitions, volatility-based range calculation, and consolidation.

## Primary Risks

- State transition bugs causing deposits into wrong positions
- Range calculation producing invalid ticks (tick spacing / bounds)
- Stack-too-deep / overly complex stack usage leading to fragile refactors
- Fee accounting inaccuracies (fees included/excluded inconsistently across preview vs actual)

## Review Checklist

### Position Management
- [ ] Exactly 3 logical slots (above/in/below) enforced
- [ ] Behavior defined when all slots occupied
- [ ] State transitions update bookkeeping consistently (no orphaned position references)

### Range Calculator
- [ ] Uses TWAP when available; uses spot fallback only as specified
- [ ] Produces tick ranges aligned to tick spacing
- [ ] Tick ranges within min/max ticks

### Consolidation
- [ ] Merges only adjacent ranges
- [ ] Skips when not beneficial

### Preview Functions
- [ ] Include uncollected fees where required
- [ ] Match actual semantics exactly

### Access Control
- [ ] Keeper-only functions restricted
- [ ] User flows permissionless

### External NFT Transfer Handling
- [ ] Vault must gracefully handle positions transferred away
- [ ] Either: prevent transfers, track ownership changes, or document expected failure modes

### Testing
- [ ] Fork tests on Base cover single-sided deposits
- [ ] Fork tests cover transitions
- [ ] Fork tests cover consolidation
- [ ] Fork tests cover compound
- [ ] Fork tests cover withdrawal
- [ ] Fork tests cover previews

## Review Artifacts to Produce

- [ ] A table of invariants:
  - Position-slot correctness
  - Conservation across deposit/withdraw
  - Fee accounting consistency
  - Preview vs actual semantics

## Files to Review

**Primary:**
- `contracts/protocols/dexes/aerodrome/slipstream/` (concentrated liquidity vault)
- `contracts/vaults/concentrated/`

**Tests:**
- `test/foundry/spec/protocols/dexes/aerodrome/slipstream/`

## Completion Criteria

- [ ] All checklist items verified
- [ ] Findings documented in `docs/reviews/YYYY-MM-DD_IDXEX-003_slipstream-vault.md`
- [ ] Invariant table produced
- [ ] No Blocker or High severity issues remain unfixed

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
