# Task IDXEX-062: Add Permit2 Path Test Coverage for _secureTokenTransfer

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-07
**Dependencies:** IDXEX-035 (complete)
**Worktree:** `feature/add-permit2-path-test-coverage`
**Origin:** Code review suggestion from IDXEX-035 (Suggestion 2)

---

## Description

The `BasicVaultCommon._secureTokenTransfer` tests only exercise the ERC20 allowance path (`allowance >= amount`). The Permit2 path (`allowance < amount`) is not tested because `Permit2AwareRepo` is not initialized in the test harness.

While the balance-delta logic is identical for both paths, a Permit2 test would provide complete branch coverage of the transfer mechanism. This could be done with a fork test (using the deployed Permit2 contract) or with a Permit2 mock in spec tests.

Note: The ProtocolDETF fork tests implicitly cover the Permit2 path through the BalancerV3Router integration, so this is a completeness concern, not a correctness gap.

(Created from code review of IDXEX-035)

## Dependencies

- IDXEX-035: Fix BasicVaultCommon._secureTokenTransfer Full-Balance Issue (parent task, complete)

## User Stories

### US-IDXEX-062.1: Add Permit2 branch test coverage

As a developer, I want `_secureTokenTransfer` tests to exercise the Permit2 transfer path so that all code branches are verified.

**Acceptance Criteria:**
- [ ] Test harness initializes Permit2AwareRepo with a Permit2 mock or fork address
- [ ] Test: ERC20 with `allowance < amount` triggers Permit2 path, returns correct balance delta
- [ ] Test: Permit2 path with fee-on-transfer token returns net delta
- [ ] All existing tests pass
- [ ] Build succeeds

## Files to Create/Modify

**Modified Files:**
- `test/foundry/spec/vaults/basic/BasicVaultCommon_TokenTransfer.t.sol`

## Inventory Check

Before starting, verify:
- [ ] IDXEX-035 is complete
- [ ] Test file exists with existing ERC20 path tests
- [ ] Permit2 mock or fork Permit2 deployment is available

## Clarifications / Decisions (from requester)

- Test type: prefer a fork test (use real on-chain Permit2 state) rather than a local mock/spec-only test.
- Mainnet address files (for reference):
  - `/Users/cyotee/Development/github-cyotee/indexedex/lib/daosys/lib/crane/contracts/constants/networks/BASE_MAIN.sol`
  - `/Users/cyotee/Development/github-cyotee/indexedex/lib/daosys/lib/crane/contracts/constants/networks/ETHEREUM_MAIN.sol`
- Existing Permit2 stub location (available but not used for fork):
  - `/Users/cyotee/Development/github-cyotee/indexedex/lib/daosys/lib/crane/contracts/protocols/utils/permit2`
- RPC aliases for forks are defined in `foundry.toml` in the repo root; use those aliases for `createSelectFork()`.
- Test harness initialization: modify `BasicVaultCommonHarness` to add a constructor that initializes `Permit2AwareRepo` (call out the change to be made in the `setUp()`/harness constructor so fork tests use Permit2-aware state).
- Token stubs: reuse the existing fee-on-transfer token stub for the fee-token test; also add tests using a normal ERC20 token (non-fee) as required by acceptance criteria.
- Scope: keep scope limited to successful Permit2 routes only (no failure-mode tests in this task).
- Fork blocks:
  - Base mainnet fork: use block `40_446_736` for deterministic state.
  - Ethereum mainnet fork: use an Ethereum block number (e.g. `20_000_000`) since Base block numbers are not valid on chainid 1.
    - Optional: allow overriding via `ETH_FORK_BLOCK` env var.

Note:
- Permit2 is deployed at the same address on Ethereum and Base: `0x000000000022D473030F116dDEE9F6B43aC78BA3`.


## Completion Criteria

- [ ] All acceptance criteria met
- [ ] Tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
