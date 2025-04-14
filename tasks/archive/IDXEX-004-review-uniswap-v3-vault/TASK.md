# Task IDXEX-004: Review Uniswap V3 Standard Exchange Vault

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-01-12
**Type:** Code Review
**Dependencies:** IDXEX-003 (shares patterns with Slipstream)
**Worktree:** N/A (review task)

---

## Description

Code review of the Uniswap V3 Standard Exchange Vault. This is Slipstream-derived logic adapted to V3 periphery (NPM), with multi-chain configuration injection.

## Review Focus

Slipstream-derived logic adapted to V3 periphery (NPM), multi-chain configuration injection.

## Primary Risks

- Incorrect handling of NPM callbacks / approvals
- Tick spacing mistakes per fee tier
- Configuration injection mistakes (wrong addresses per chain)

## Review Checklist

### Configuration
- [ ] Vault config includes correct chain-specific addresses (NPM, factory, wrapped native)
- [ ] Configuration is correctly injected per deployment chain

### Tick Alignment
- [ ] Tick alignment enforced per pool's tick spacing
- [ ] Different fee tiers handled correctly

### Fee Collection
- [ ] Fee collection via NPM `collect()` is correct
- [ ] Compounding logic works as expected

### Preview Functions
- [ ] Preview paths use Crane's quoter/zap quoter consistently
- [ ] Preview matches actual execution

### Testing
- [ ] Fork tests on Ethereum mainnet cover the same behaviors as Slipstream vault (IDXEX-003)
- [ ] Minus rewards (V3 doesn't have gauge rewards like Slipstream)

## Review Artifacts to Produce

- [ ] A table of invariants:
  - Position-slot correctness
  - Conservation across deposit/withdraw
  - Fee accounting consistency
  - Preview vs actual semantics

## Files to Review

**Primary:**
- `contracts/protocols/dexes/uniswap/v3/` (concentrated liquidity vault)
- `contracts/vaults/concentrated/uniswap/v3/`

**Tests:**
- `test/foundry/spec/protocols/dexes/uniswap/v3/`

## Completion Criteria

- [ ] All checklist items verified
- [ ] Findings documented in `docs/reviews/YYYY-MM-DD_IDXEX-004_uniswap-v3-vault.md`
- [ ] Invariant table produced
- [ ] No Blocker or High severity issues remain unfixed

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
