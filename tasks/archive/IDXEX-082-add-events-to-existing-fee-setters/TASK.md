# Task IDXEX-082: Add Events to Existing Fee Setters

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-08
**Dependencies:** IDXEX-054
**Worktree:** `feature/IDXEX-082-add-events-to-existing-fee-setters`
**Origin:** Code review suggestion from IDXEX-054

---

## Description

The usage fee setters (`setDefaultUsageFee`, `setDefaultUsageFeeOfTypeId`, `setUsageFeeOfVault`) and DEX swap fee setters (`setDefaultDexSwapFee`, `setDefaultDexSwapFeeOfTypeId`, `setVaultDexSwapFee`) in `VaultFeeOracleManagerFacet` silently write to storage without emitting events. The `VaultFeeOracleRepo` already returns old values from all internal setters, so adding event emissions requires minimal changes.

Events are already declared in `IVaultFeeOracleManager` (`NewDefaultVaultFee`, `NewDefaultDexFee`, `NewVaultFee`) but are never emitted by the facet. This is a pre-existing oversight discovered during IDXEX-054 code review.

The IDXEX-054 seigniorage setters established the correct pattern: capture old value from Repo, emit event with old+new values. Apply this same pattern to the usage fee and DEX swap fee setters for consistency.

(Created from code review of IDXEX-054)

## Dependencies

- IDXEX-054: Add Seigniorage Manager Setter Functions (parent task, complete)

## User Stories

### US-IDXEX-082.1: Emit events from usage fee setters

As a protocol operator, I want fee changes to emit on-chain events so that off-chain monitoring can track all fee parameter changes.

**Acceptance Criteria:**
- [ ] `setDefaultUsageFee` emits event with old and new values
- [ ] `setDefaultUsageFeeOfTypeId` emits event with typeId, old and new values
- [ ] `setUsageFeeOfVault` emits event with vault address, old and new values

### US-IDXEX-082.2: Emit events from DEX swap fee setters

As a protocol operator, I want DEX swap fee changes to also emit events for monitoring parity.

**Acceptance Criteria:**
- [ ] `setDefaultDexSwapFee` emits event with old and new values
- [ ] `setDefaultDexSwapFeeOfTypeId` emits event with typeId, old and new values
- [ ] `setVaultDexSwapFee` emits event with vault address, old and new values

### US-IDXEX-082.3: Test event emissions

**Acceptance Criteria:**
- [ ] Tests verify event emission for each of the 6 setters
- [ ] Existing auth tests continue to pass
- [ ] Build succeeds

## Files to Create/Modify

**Modified Files:**
- `contracts/oracles/fee/VaultFeeOracleManagerFacet.sol` - Capture old values from Repo and emit events
- `contracts/interfaces/IVaultFeeOracleManager.sol` - Verify/add event declarations if any are missing

**Test Files:**
- Existing test files for VaultFeeOracleManagerFacet (add event assertion tests)

## Inventory Check

Before starting, verify:
- [ ] IDXEX-054 is complete
- [ ] `VaultFeeOracleManagerFacet.sol` exists and has usage fee + DEX fee setters
- [ ] `IVaultFeeOracleManager.sol` has event declarations

## Completion Criteria

- [ ] All 6 existing fee setters emit events with old/new values
- [ ] Events follow the same pattern as IDXEX-054 seigniorage setters
- [ ] Tests verify event emissions
- [ ] All existing tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>PHASE_DONE</promise>`

**If blocked, output:** `<promise>BLOCKED: [reason]</promise>`
