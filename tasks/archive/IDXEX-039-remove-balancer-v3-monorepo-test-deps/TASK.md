# Task IDXEX-039: Remove Balancer V3 Monorepo Test Dependencies (IndexedEx)

**Repo:** IndexedEx
**Status:** Complete
**Created:** 2026-02-04
**Dependencies:** CRANE-218
**Worktree:** `feature/remove-balancer-v3-test-deps`

---

## Description

Complete the IndexedEx-specific portion of Balancer V3 test dependency removal. This task depends on CRANE-218, which ports Balancer V3 *test* mocks/tokens/utilities into the Crane submodule. After CRANE-218 is present, verify IndexedEx builds/tests and ensure IndexedEx does not import Balancer V3 monorepo *test trees* in active code.

**Goal:** IndexedEx has zero dependencies on Balancer V3 monorepo test sources:
- `@balancer-labs/**/contracts/test/**`
- `@balancer-labs/**/test/foundry/utils/**`

This task does **not** aim to remove all Balancer V3 production package imports (e.g. `@balancer-labs/v3-interfaces/...`).

## Dependencies

- **CRANE-218** - Port Balancer V3 Test Mocks and Tokens to Crane

## User Stories

### US-IDXEX-039.1: Remove All Balancer Imports from IndexedEx

### US-IDXEX-039.1: Verify IndexedEx Builds with Updated Crane

As a developer, I want to verify IndexedEx compiles and tests pass after CRANE-218 updates the Crane submodule.

**Acceptance Criteria:**
- [x] Crane submodule contains CRANE-218 changes
- [x] `forge build` succeeds in IndexedEx
- [x] All non-fork IndexedEx tests pass offline (avoid Foundry network-config panic)
- [x] No `@balancer-labs/.*/contracts/test` imports remain in IndexedEx active code (excluding `old/`)
- [x] No `@balancer-labs/.*/test/foundry/utils` imports remain in IndexedEx active code (excluding `old/`)

### US-IDXEX-039.2: Create Base Mainnet Fork Tests

As a developer, I want fork tests against Base mainnet to verify Balancer V3 integration works correctly with ported code.

**Acceptance Criteria:**
- [x] Base mainnet fork tests exist under `test/foundry/fork/base_main/balancer/v3/`
- [x] Fork tests cover swap and vault integration behaviors
- [x] Fork tests can be run with `--fork-url $BASE_RPC_URL`

### US-IDXEX-039.3: Update Progress Notes

As a developer, I want the progress notes file updated to reflect completed work.

**Acceptance Criteria:**
- [x] Update `BALANCER_V3_TEST_DEPS_NOTES.md` with completed items
- [x] Mark all items as complete
- [x] Document that Crane submodule contains all ported test infrastructure

## Technical Details

### Scope Clarification

This task is specifically for **IndexedEx-only** work:

**In Scope:**
- Verifying IndexedEx builds after CRANE-218
- Verifying Base mainnet fork tests exist in IndexedEx
- Updating `BALANCER_V3_TEST_DEPS_NOTES.md`

**Out of Scope (handled by CRANE-218):**
- Porting test tokens (ERC20TestToken, WETHTestToken, ERC4626TestToken)
- Porting vault mocks (VaultMock, VaultAdminMock, VaultExtensionMock)
- Porting WeightedPoolContractsDeployer
- Updating imports in Crane's BaseTest.sol, VaultContractsDeployer.sol
- Ethereum mainnet fork tests (done in Crane)

### Base Mainnet Balancer V3 Addresses

```solidity
// Base Mainnet Balancer V3 Vault
address constant BASE_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

// Note: Verify current deployment addresses before testing
```

### Fork Test Strategy

Base mainnet fork tests should:
1. Fork Base mainnet at a recent block
2. Interact with real Balancer V3 Vault and pools on Base
3. Verify IndexedEx's router/vault integrations work with on-chain state
4. Compare swap amounts, BPT calculations to expected values
5. Assert equality within acceptable tolerances

## Files to Create/Modify

**Modified Files:**
- `BALANCER_V3_TEST_DEPS_NOTES.md` - final update marking completion

## Inventory Check

Before starting, verify:
- [x] CRANE-218 is marked Complete
- [x] Crane submodule has been updated to include CRANE-218 changes
- [ ] Base mainnet RPC URL is configured *(only needed if running fork tests)*

## Handy Commands

```bash
# Verify no Balancer test imports remain in IndexedEx
rg "@balancer-labs/.*/contracts/test|@balancer-labs/.*/test/foundry/utils" --glob "*.sol" contracts test | rg -v "^old/"

# Build IndexedEx
forge build

# Run all IndexedEx tests
forge test --offline

# Run all non-fork IndexedEx tests (offline)
forge test --offline --no-match-path "test/foundry/fork/**"

# Run Base fork tests (after creating them)
forge test --match-path "test/foundry/fork/base_main/balancer/v3/*" --fork-url $BASE_RPC_URL
```

## Completion Criteria

- [x] CRANE-218 is complete (test mocks ported)
- [x] `forge build` succeeds
- [x] `forge test --offline --no-match-path "test/foundry/fork/**"` passes
- [x] Base mainnet fork tests exist under `test/foundry/fork/base_main/balancer/v3/`
- [x] No Balancer V3 monorepo test-tree imports in IndexedEx active code

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
