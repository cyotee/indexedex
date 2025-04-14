# Batch Permit2 Gap-Fix Plan

## Audience
New coding agent continuing work in this repo.

## Why This Plan Exists
`forge test` is green, but current batch permit coverage does not assert several critical correctness properties. This plan focuses on latent implementation and coverage gaps that can pass today.

## Goal
Harden batch Permit2 first-token-only flows so they are behaviorally correct and provably covered by tests.

Secondary goal:
- Reduce redundant router tests where they no longer provide unique signal, while preserving route-specific invariants and regression value.

## Non-Negotiable Constraints
- Keep existing public APIs additive and backward compatible.
- Preserve non-permit batch behavior.
- Minimize churn and avoid unrelated refactors.
- Keep all changes inside `indexedex`.

## Current Implemented State
- Batch interfaces/facets/targets already include `swapExactInWithPermit(...)` and `swapExactOutWithPermit(...)`.
- `BatchPermit2` tests exist and pass.
- Key risk: tests currently validate broad success/revert paths, but do not fully assert settlement recipient correctness, no-retention, and over-pull/refund invariants for with-permit flows.

## Confirmed Gap Areas

### 1) Exact-out withPermit sender attribution risk
In `swapExactOutWithPermit`, the implementation uses `this.swapExactOut(...)`. That changes `msg.sender` inside `swapExactOut` to `address(this)`, which can shift settlement accounting/recipient behavior unexpectedly.

Target file:
- `contracts/protocols/dexes/balancer/v3/routers/batch/BalancerV3StandardExchangeBatchRouterExactOutTarget.sol`

### 2) Exact-in withPermit prepaid mode window
`swapExactInWithPermit` toggles batch permit mode around permit pulling, then calls `swapExactIn(...)` with permit mode already disabled. This is fragile and should be explicit and test-locked.

Target files:
- `contracts/protocols/dexes/balancer/v3/routers/batch/BalancerV3StandardExchangeBatchRouterExactInTarget.sol`
- `contracts/protocols/dexes/balancer/v3/routers/batch/BalancerV3StandardExchangeBatchRouterCommon.sol`

### 3) Over-pull and refund/no-retention assertions missing
withPermit paths can pre-pull up to permit amount or maxAmountIn, but tests do not fully enforce that any unused portion is refunded and router retains zero relevant token balances.

Target tests:
- `test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_BatchPermit2.t.sol`

### 4) Exact-out batch permit negative coverage is incomplete
No dedicated exact-out withPermit tests for:
- permits/signatures length mismatch
- permit token mismatch
- multi-path with mixed first tokens
- strategy-vault path with permit

### 5) Some router tests are now redundant or weaker than neighboring coverage
The suite is green, but a few tests duplicate broader dedicated coverage or only assert a weaker version of the same invariant.

Current likely cleanup targets:
- `test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_BatchPermit2.t.sol`
	- non-permit regression test duplicates stronger non-permit batch coverage elsewhere
- Route-local deadline tests in:
	- `BalancerV3StandardExchangeRouter_DirectSwap.t.sol`
	- `BalancerV3StandardExchangeRouter_VaultDeposit.t.sol`
	- `BalancerV3StandardExchangeRouter_VaultWithdrawal.t.sol`
	- `BalancerV3StandardExchangeRouter_VaultPassThrough.t.sol`
	These overlap with the dedicated `BalancerV3StandardExchangeRouter_Deadline.t.sol` suite.
- Simpler ETH/WETH route tests in `BalancerV3StandardExchangeRouter_WethUnwrap.t.sol`
	that overlap stronger `DirectSwap.t.sol` coverage for the same route behavior.
- Query hook abuse tests are split across two files and partially overlap:
	- `BalancerV3StandardExchangeRouter_QueryHookAbuse.t.sol`
	- `BalancerV3StandardExchangeRouter_ExactInQueryHookAbuse.t.sol`

## Implementation Plan

### Step 1) Fix exact-out withPermit caller/settlement path
- Replace `this.swapExactOut(...)` with an internal flow that preserves original caller identity through hook params.
- Ensure `sender` used in hook params is the external caller, not router self.
- Keep external API and selector unchanged.

Files:
- `contracts/protocols/dexes/balancer/v3/routers/batch/BalancerV3StandardExchangeBatchRouterExactOutTarget.sol`

### Step 2) Make exact-in withPermit prepaid behavior explicit
- Keep permit mode active across the actual swap execution for withPermit path, or introduce a dedicated internal execution function that consumes pre-pulled balances deterministically.
- Avoid ambiguous mode transitions before unlock/hook execution.

Files:
- `contracts/protocols/dexes/balancer/v3/routers/batch/BalancerV3StandardExchangeBatchRouterExactInTarget.sol`
- `contracts/protocols/dexes/balancer/v3/routers/batch/BalancerV3StandardExchangeBatchRouterCommon.sol`

### Step 3) Tighten first-token-only pull bounds
- Keep validation `permit token == path.tokenIn`.
- For exact-in, request no more than `path.exactAmountIn`.
- For exact-out, request no more than `path.maxAmountIn`.
- If permit amount is insufficient, revert deterministically.

Files:
- `contracts/protocols/dexes/balancer/v3/routers/batch/BalancerV3StandardExchangeBatchRouterExactInTarget.sol`
- `contracts/protocols/dexes/balancer/v3/routers/batch/BalancerV3StandardExchangeBatchRouterExactOutTarget.sol`

### Step 4) Add focused assertions to existing passing tests
Upgrade existing tests to assert actual invariants, not only non-zero spend/output.

In `BatchPermit2` tests, add assertions for:
- recipient output token balance increase
- input spent `<=` expected bound
- router token balance retention is zero for touched tokens after settlement

File:
- `test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_BatchPermit2.t.sol`

### Step 5) Add missing exact-out withPermit negative/edge tests
Add new tests for:
- `swapExactOutWithPermit_reverts_permitsLengthMismatch`
- `swapExactOutWithPermit_reverts_tokenMismatch`
- `swapExactOutWithPermit_multiPath_succeeds`
- `swapExactOutWithPermit_refundsUnusedAndNoRouterRetention`

Optional high-value extension:
- strategy-vault route with permit in exact-out batch mode.

File:
- `test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_BatchPermit2.t.sol`

### Step 6) Add route parity checks against non-permit flows
For one direct pool route and one strategy-vault route, compare withPermit execution outcomes against non-permit execution with same inputs/tolerances.

Files:
- `test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_BatchExactIn.t.sol`
- `test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_BatchExactOut.t.sol`

### Step 7) Remove the safest redundant test first
Delete the weakest duplicate before broader consolidation.

Recommended first removal:
- `test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_BatchPermit2.t.sol`
	- `test_swapExactIn_regression_stillWorks`

Reason:
- It duplicates non-permit batch exact-in behavior already covered in `BalancerV3StandardExchangeRouter_BatchExactIn.t.sol`.
- It does not validate any unique Permit2 behavior.
- It has weaker assertions than the purpose-built batch tests.

### Step 8) Consolidate deadline coverage into the dedicated deadline suite
After permit hardening is complete, remove route-local deadline tests that no longer add unique path coverage.

Proposed removals:
- `BalancerV3StandardExchangeRouter_DirectSwap.t.sol`
	- `test_directSwap_expiredDeadline_reverts`
- `BalancerV3StandardExchangeRouter_VaultDeposit.t.sol`
	- `test_vaultDeposit_deadline_reverts`
- `BalancerV3StandardExchangeRouter_VaultWithdrawal.t.sol`
	- `test_vaultWithdrawal_deadline_reverts`
- `BalancerV3StandardExchangeRouter_VaultPassThrough.t.sol`
	- `test_vaultPassThrough_deadline_reverts`

Guardrail:
- Keep `BalancerV3StandardExchangeRouter_Deadline.t.sol` as the canonical deadline file.
- Keep batch deadline tests in batch-specific files because they exercise separate entrypoints.

### Step 9) Trim overlapping ETH/WETH route tests conservatively
Do not remove bug-specific unwrap tests. Only remove the simpler route duplicates that are already asserted more strongly in `DirectSwap.t.sol`.

Likely removals from `BalancerV3StandardExchangeRouter_WethUnwrap.t.sol`:
- `test_pureSwap_exactOut_ethToDai`
- `test_pureSwap_exactIn_daiToEth`
- `test_pureSwap_exactIn_ethToDai`

Keep:
- exact-out DAI -> ETH bug-regression test
- exact-out query-vs-exec unwrap parity test
- exact-out slippage unwrap test

### Step 10) Merge overlapping query-hook abuse coverage
Unify overlapping access-control tests into one abuse file after permit work is stable.

Target outcome:
- Keep one canonical query-hook abuse file covering:
	- exact-in direct EOA call revert
	- exact-in contract call revert
	- exact-out direct/contract abuse revert
	- malicious callback attempt
	- legitimate query still works

Candidate action:
- Move unique tests from `BalancerV3StandardExchangeRouter_ExactInQueryHookAbuse.t.sol`
	into `BalancerV3StandardExchangeRouter_QueryHookAbuse.t.sol`
	and then delete the smaller overlapping file.

### Step 11) Strengthen before deleting when in doubt
If a candidate test is weak but covers a unique route, do not remove it immediately.

Apply this rule:
- unique route + weak assertions: strengthen
- duplicate route + weaker assertions: remove
- overlapping security tests across files: consolidate

## Verification Commands
- `forge test --match-path test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_BatchPermit2.t.sol -vvv`
- `forge test --match-path test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_BatchExactIn.t.sol -vvv`
- `forge test --match-path test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_BatchExactOut.t.sol -vvv`
- `forge test --match-path test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_Permit2Signature.t.sol -vvv`
- `forge test --match-path test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_Deadline.t.sol -vvv`
- `forge test --match-path test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_WethUnwrap.t.sol -vvv`
- `forge test --match-path test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_QueryHookAbuse.t.sol -vvv`
- `forge test --match-path test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_ExactInQueryHookAbuse.t.sol -vvv`
- `forge test --match-path test/foundry/spec/protocol/dexes/balancer/v3/routers -vvv`

## Acceptance Criteria
- withPermit exact-out settles to correct external recipient in tests.
- withPermit exact-in uses deterministic prepaid settlement behavior.
- no-retention and refund invariants are explicitly asserted for batch withPermit flows.
- exact-out withPermit has parity negative tests matching exact-in quality level.
- the weakest duplicate tests are removed without reducing route coverage.
- deadline coverage is centralized where practical.
- overlapping ETH/WETH and query-hook abuse tests are consolidated conservatively.
- full router suite remains green.

## Out of Scope
- Frontend integration changes.
- Witness-typed batch permit redesign.
- Unrelated batch router refactors.
