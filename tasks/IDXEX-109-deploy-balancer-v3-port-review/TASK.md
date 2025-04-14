# Task IDXEX-109: Review & Verify Ported Balancer V3 for Production Deployment

**Repo:** IndexedEx
**Status:** Superseded (moved to Crane tasks)
**Created:** 2026-02-11
**Dependencies:** -
**Worktree:** `feature/deploy-balancer-v3-port-review`

---

## Description

This task has been moved into the Crane submodule task list as `CRANE-270` so it can be worked on inside a Crane-only worktree. See: `lib/daosys/lib/crane/tasks/CRANE-270-verify-balancer-v3-port/TASK.md`.

Original description (moved):

We ported a deployable subset of Balancer V3 into the Crane codebase at `lib/daosys/lib/crane/contracts/protocols/dexes/balancer/v3/` while keeping the original upstream sources under `lib/daosys/lib/crane/contracts/external/balancer/v3/`.
We are currently uncertain about the completeness, quality, and parity of the port: some features may be partially implemented, refactored, or missing tests. This task requires a thorough review of all ported components and any existing tests that claim to prove parity.
This task verifies the port is production‑ready by exercising representative operations (swaps, add/remove liquidity), comparing behavior and accounting against the upstream deployed Balancer V3 on an Ethereum Mainnet fork, and producing a gaps report with recommended follow‑up tasks.

## Scope & Purpose

- Target network for verification: **Ethereum Mainnet (fork tests against a live mainnet state)**.
- Parity goal: **Exact parity** with upstream Balancer V3 for core behaviors where feasible.
 - Primary comparison: run identical operation sequences against (A) the live, deployed Balancer V3 contracts (via a mainnet fork) and (B) the locally compiled/deployable port, then compare results, events, and on‑chain accounting.
 - Explicit review requirement: audit all existing port files and any tests under the port path that claim to validate parity. Confirm which tests actually assert parity vs upstream and include their results in the gaps report.

## User Stories

### US-IDXEX-109.1: Operation Parity Verification

As a systems architect, I want the ported Balancer V3 to behave identically for core operations so that vaults depending on Balancer behave predictably.

Acceptance Criteria:
- [ ] Execute a representative set of sequences (swap exact in/out, add liquidity, remove liquidity) against upstream on a mainnet fork and against the locally deployed port; results (amounts, events, final balances) match within acceptable tolerance (1 wei exact where possible).
- [ ] Tests capture and persist inputs/outputs for reproducibility.
 - [ ] Review and validate any existing tests under the port path; document which tests prove parity, which are incomplete, and include their pass/fail status in the artifacts.

### US-IDXEX-109.2: Deployability & Size Validation

As an engineer, I want to ensure the port compiles and can be deployed within realistic chain limits so that production deployment is possible.

Acceptance Criteria:
- [ ] All port contracts compile with Solidity 0.8.30 and Foundry config (no viaIR).
- [ ] Contracts required for deployment are within typical EVM size limits (no single contract exceeds chain deployment limits for targeted networks).
- [ ] A scripted local CREATE3 deployment (test-only) succeeds for the ported package.

### US-IDXEX-109.3: Gap Reporting

As a release manager, I want a clear gaps report listing behavioral diffs, missing interfaces, and suggested remediation tasks.

Acceptance Criteria:
- [ ] Produce a report enumerating any functional differences, missing interfaces/selectors, gas regressions >10% on critical paths, and tests that fail to match.
- [ ] For each gap, include recommended follow-up task(s) with estimated effort (small/medium/large).

## Technical Details

- Compare code paths and ABIs between:
  - Upstream sources: `lib/daosys/lib/crane/contracts/external/balancer/v3/` (reference)
  - Ported sources: `lib/daosys/lib/crane/contracts/protocols/dexes/balancer/v3/` (subject)
- Create a Foundry mainnet fork test suite that:
  1. Deploys the ported contracts via CREATE3 (test-only factory instance) onto the forked state at deterministic addresses.
  2. Executes scripted operation scenarios (fixtures) against both the live deployed Vault/Pool addresses and the locally deployed port.
  3. Records outputs (return values, events, token deltas, storage reads) and compares.
- Keep tolerances strict; where exact equality is impossible due to deterministic salt/address differences, compare functional outputs and accounting invariants.
 - As part of the suite, run any existing tests in `lib/daosys/lib/crane/contracts/protocols/dexes/balancer/v3/test/` (or `test/` under that path). Record which existing tests were reused, which needed modification, and which new tests were added to prove parity.

## Files To Create / Modify

**New Files (recommended):**
- `test/foundry/spec/protocols/dexes/balancer/v3/BalancerV3_PortComparison.t.sol` - Fork tests to run scenarios against upstream and ported deployments and assert parity.
- `scripts/compare_balancer_port.sh` - Shell helper to run the fork, execute test scenarios, and produce an artifacts directory with JSON comparisons.

**Modified Files (possible):**
- `foundry.toml` - may add remapping or test profile for mainnet fork (non-invasive; add as a test profile).

**Artifacts / Outputs:**
- `out/test-artifacts/IDXEX-109/` - JSON logs of scenarios, per-scenario diff reports, gas comparison table, and the gaps report `GAPS.md`.

## Tests

- Fork tests (Foundry): run scenario suites against mainnet fork with live addresses and with port deployed via CREATE3 in the same fork; compare outputs.
- Unit tests: ensure port compiles and unit tests in `contracts/protocols/dexes/balancer/v3` (if present) pass.

## Inventory Check (Preflight)

- [ ] `lib/daosys/lib/crane/contracts/external/balancer/v3/` exists and contains upstream sources (reference)
- [ ] `lib/daosys/lib/crane/contracts/protocols/dexes/balancer/v3/` contains the ported sources (subject)
- [ ] Foundry + Anvil/Anvil fork access and an RPC key with archive access for mainnet fork (or local archive snapshot)
- [ ] `Create3Factory` test helper available in test infra (`contracts/test/CraneTest.sol`)
 - [ ] Existing tests under the port path are located and runnable: e.g. `lib/daosys/lib/crane/contracts/protocols/dexes/balancer/v3/test/` and `test/foundry/...`; document any failures when run against the port.

### Port Inventory (discovered)

The following components were found under the ported path (`lib/daosys/lib/crane/contracts/protocols/dexes/balancer/v3/`) and should be included in the review scope. Confirm these are the authoritative ported implementations and list any missing upstream modules:

- Router (diamond): `router/diamond/` — `BalancerV3RouterDFPkg.sol`, router facets (`RouterSwapFacet.sol`, `RouterAddLiquidityFacet.sol`, `RouterRemoveLiquidityFacet.sol`, `BatchSwapFacet.sol`, `BufferRouterFacet.sol`, `CompositeLiquidityERC4626Facet.sol`, `CompositeLiquidityNestedFacet.sol`), storage repos and modifiers.
- Pool types:
  - Weighted pools: `pool-weighted/` (`BalancerV3WeightedPoolFacet.sol`, `BalancerV3WeightedPoolTarget.sol`, repos, DFPkg)
  - Stable pools: `pool-stable/` (`BalancerV3StablePoolFacet.sol`, targets, repo, DFPkg)
  - Constant-product (constProd): `pool-constProd/` (`BalancerV3ConstantProductPoolFacet.sol`, target, DFPkg)
  - Gyro pools: `pool-gyro/` (2CLP & ECLP implementations + FactoryService)
  - LB pools: `pool-weighted/lbp/` (LBPool facets/targets/repos)
- Vault & tokens: `vault/` (`BalancerV3PoolTarget.sol`, `BetterBalancerV3PoolTokenFacet.sol`, vault-aware facets/repo/authentication)
- Hooks and hook examples: `hooks/` (SurgeHook, MevCaptureHook, ExitFeeHook, etc.) and `hooks/BaseHooksTarget.sol`
- Pool utils & factories: `pool-utils/` (`BalancerV3BasePoolFactory.sol`, `PoolInfo.sol`, FactoryWidePauseWindowTarget.sol)
- ReClamm (re-generating AMM) implementation: `reclamm/` (ReClammPool, extensions, factory)
- Cow & CowRouter (CoW routing): `pools/cow/`
- Rate providers: `rateProviders/` (ERC4626RateProvider)
- Test utilities and deployers: `test/utils/` (WeightedPoolContractsDeployer.sol, VaultContractsDeployer.sol, TestBase_BalancerV3Router.sol)

Note: This inventory is non-exhaustive; run `ls -R` over the port directory to confirm full list.

### Refactor Policy

- The `contracts/external/balancer/v3/` directory is a reference copy of upstream. Do NOT modify upstream files in `external/` to implement fixes or refactors.
- Any refactor, fix, or new integration MUST be added under the ported path: `lib/daosys/lib/crane/contracts/protocols/dexes/balancer/v3/` so it becomes part of the Crane/IndexedEx maintained port. This ensures we keep a clear separation between upstream reference and our deployable implementation.
- If a refactor requires extracting shared utilities, place them under `protocols/dexes/balancer/v3/utils/` inside the ported path and update import remappings accordingly.

### Preflight Verification Steps

1. Run `ls -la lib/daosys/lib/crane/contracts/protocols/dexes/balancer/v3/` and confirm the directories listed in "Port Inventory" exist.
2. Verify upstream reference exists: `ls -la lib/daosys/lib/crane/contracts/external/balancer/v3/`.
3. Confirm `foundry.toml` remappings include `@balancer-labs/` pointing to `lib/daosys/lib/crane/lib/balancer-v3-monorepo/pkg/` or adjust to prefer the ported path for tests.
4. Ensure `contracts/test/CraneTest.sol` (or equivalent) exposes CREATE3 factory helper for test scaffolding.
5. Validate there are test deployer helpers in `test/utils/` for creating pool fixtures; if missing, plan to add simple deployers for each pool type.


## Completion Criteria

- [ ] All acceptance criteria in user stories satisfied or documented in GAPS.md with remediation tasks
- [ ] Fork test suite runs and produces comparison artifacts
- [ ] GAPS.md produced listing diffs, recommendations, and estimated effort
- [ ] Task entry in INDEX.md updated

---

**When complete, output:** `<promise>PHASE_DONE</promise>`

**If blocked, output:** `<promise>BLOCKED: [reason]</promise>`
