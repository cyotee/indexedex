# Task IDXEX-106: IndexedexManager initAccount Verification (Vault Fee Oracle focus)

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-11
**Dependencies:** IDXEX-002
**Worktree:** `feature/IDXEX-106-indexedexmanager-initaccount-verification`

---

## Description

Clarify and expand the existing `IDXEX-106` verification work to explicitly test the Vault Fee Oracle instances deployed by the IndexedexManager package. This task adds broader integration tests that deploy the manager package, exercise `initAccount`, and validate the Vault Fee Oracle instances created by the manager are correctly deployed, registered, and wired for use.

The goal is to ensure the manager's deterministic CREATE3 deployment, the registry bookkeeping, and basic oracle behavior (events, access control, and read APIs) are covered end-to-end.

## Dependencies

- IDXEX-002: Core test infra / base fixtures (required for test harness)

## User Stories

### US-IDXEX-106.1: Manager deploys Vault Fee Oracle instances

As an integrator, I want `IndexedexManager.initAccount` to deploy Vault Fee Oracle instances so that downstream packages and vaults have a deterministic oracle available for fee configuration.

**Acceptance Criteria:**
- [ ] Calling `initAccount` via the manager deploys a Vault Fee Oracle contract instance
- [ ] The deployed oracle address is recorded/registrable by the manager/registry
- [ ] The oracle emits a deployment/registration event (or manager emits an event) that includes the oracle address

### US-IDXEX-106.2: Oracle basic behavior and access control

As a protocol operator, I want the manager-deployed oracle to have correct owner/operator permissions and respond to basic read calls so that monitoring and configuration tooling can query it.

**Acceptance Criteria:**
- [ ] Deployed oracle has owner/operator set to the expected manager or operator address
- [ ] Read-only functions (e.g., fee getters, type queries) return sensible defaults and don't revert
- [ ] Unauthorized callers cannot call privileged setters (access control enforced)
- [ ] Events are emitted on meaningful state changes (where applicable)

### US-IDXEX-106.3: Integration test harness

As a test author, I want a reproducible integration test that deploys the manager package, calls `initAccount`, and asserts the oracle behavior so that CI protects this behavior.

**Acceptance Criteria:**
- [ ] Test implemented at `test/foundry/spec/manager/IndexedexManager_InitAccount.t.sol`
- [ ] Test deploys the manager package via the project's factory/CREATE3 helpers (use existing Crane/Factory fixtures)
- [ ] Tests run in CI-local (`forge test --match-path ...`) and pass

## Technical Details

- Tests should use existing Crane test fixtures and factory helpers to deploy the IndexedexManager package deterministically (CREATE3) so addresses are stable.
- After `initAccount`, obtain the Vault Fee Oracle address from the manager registry or manager return value and assert the contract's bytecode and expected interface exist at that address.
- Verify events: manager emits registration event or oracle emits its own creation event. If no creation event exists, assert registry bookkeeping state instead.
- Access control: attempt a privileged setter from an unauthorized address and assert revert; verify owner/operator can set a test value and that event(s) are emitted.
- Minimal oracle read behavior: call one or two representative getters (e.g., default fee) to verify non-reverting reads and expected default values.

## Files to Create/Modify

**New Files:**
- `test/foundry/spec/manager/IndexedexManager_InitAccount.t.sol` - Integration tests described above

**Modified Files:**
- (none required; prefer adding tests only. If test infra is missing, add small test helpers under `test/`.)

**Tests:**
- `test/foundry/spec/manager/IndexedexManager_InitAccount.t.sol` - deploy manager via factory, call `initAccount`, assert oracle deployment/registration/events/access control/read APIs

## Inventory Check

Before starting, verify:
- [ ] Crane factory CREATE3 helpers are available in test base (existing test fixtures)
- [ ] IndexedexManager package test fixtures exist or can be bootstrapped
- [ ] VaultFeeOracle interface contract path and selectors are available

## Completion Criteria

- [ ] All acceptance criteria met for the user stories above
- [ ] Tests pass locally and in CI (`forge test --match-path test/foundry/spec/manager/IndexedexManager_InitAccount.t.sol`)
- [ ] Build succeeds
- [ ] TASK.md and PROGRESS.md are up to date

---

**When complete, output:** `<promise>PHASE_DONE</promise>`

**If blocked, output:** `<promise>BLOCKED: [reason]</promise>`
