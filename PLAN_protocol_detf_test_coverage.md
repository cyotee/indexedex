# Plan: Protocol DETF Route Coverage Completion

## Goal

Complete Protocol DETF route testing so every supported route is covered by:

1. at least one successful execution test in the regime where the route should succeed,
2. at least one revert test in the regime where the route should fail,
3. preview-versus-execution parity where the route supports previewing and execution, and
4. explicit deadband enforcement tests for user-facing routes, not just query helpers.

This plan is written to support interruption-safe resumption. If implementation stops midway, a new agent should be able to read only this file plus the referenced test files and continue without rebuilding the entire prior conversation context.

## Current State

### Protocol Semantics

The current gate behavior is intentional and already implemented in the shared helpers:

- minting allowed when `syntheticPrice < burnThreshold`
- burning allowed when `syntheticPrice > mintThreshold`
- neither allowed inside the deadband

Current threshold values in package defaults:

- `mintThreshold = 1.005e18` which is the upper deadband bound
- `burnThreshold = 0.995e18` which is the lower deadband bound

### Current Test Status

The following suites already pass:

```bash
forge test --match-path test/foundry/spec/vaults/protocol/ProtocolDETF_Routes.t.sol
forge test --match-path test/foundry/spec/vaults/protocol/EthereumProtocolDETF_Routes.t.sol
forge test --match-path test/foundry/spec/vaults/protocol/ProtocolDETFExchangeOut.t.sol
forge test --match-path test/foundry/spec/vaults/protocol/EthereumProtocolDETFExchangeOut.t.sol
forge test --match-path test/foundry/spec/vaults/protocol/ProtocolDETFSyntheticThresholds.t.sol
```

### What Is Already Covered

Successful execution already exists for:

- base `CHIR -> WETH` exact-in
- Ethereum `CHIR -> WETH` exact-in
- base `CHIR -> WETH` exact-out
- Ethereum `CHIR -> WETH` exact-out
- base `WETH -> CHIR` exact-in in a custom mint-enabled fixture
- base and Ethereum `WETH -> RICH`
- base and Ethereum `RICH -> WETH`
- base and Ethereum supported RICHIR-related execution routes already present in the route suites

Revert-only coverage currently exists for the mint-gated CHIR routes in the default fixtures, especially:

- base `WETH -> CHIR`
- Ethereum `WETH -> CHIR`
- base `RICH -> CHIR`
- Ethereum `RICH -> CHIR`
- exact-out mint variants for `WETH -> CHIR` and `RICH -> CHIR` in the default fixtures

## Primary Gap

The major missing coverage is not generic test quantity. The missing coverage is successful execution of mint-capable CHIR routes under mint-enabled conditions across both chains and both exact-in and exact-out interfaces.

The second missing coverage category is route-level deadband enforcement under a near-peg fixture.

## Files To Modify

Primary files:

- `test/foundry/spec/vaults/protocol/ProtocolDETF_Routes.t.sol`
- `test/foundry/spec/vaults/protocol/EthereumProtocolDETF_Routes.t.sol`
- `test/foundry/spec/vaults/protocol/ProtocolDETFExchangeOut.t.sol`
- `test/foundry/spec/vaults/protocol/EthereumProtocolDETFExchangeOut.t.sol`
- `test/foundry/spec/vaults/protocol/ProtocolDETFSyntheticThresholds.t.sol`

Supporting fixture sources to inspect before edits:

- `test/foundry/spec/vaults/protocol/ProtocolDETF_IntegrationBase.t.sol`
- `test/foundry/spec/vaults/protocol/EthereumProtocolDETF_IntegrationBase.t.sol`

Protocol behavior references:

- `contracts/vaults/protocol/BaseProtocolDETFCommon.sol`
- `contracts/interfaces/IProtocolDETF.sol`

## Implementation Strategy

Implement in three phases. Do not try to jump directly to a massive one-shot patch.

### Phase 1: Reusable Mint-Enabled Fixture Helpers

Objective:

- create or centralize helper logic to deploy custom low-price DETFs for both base and Ethereum tests
- avoid duplicating custom deployment setup across many test functions

Recommended approach:

1. Keep the current custom deployment helper logic in `ProtocolDETFSyntheticThresholds.t.sol` as the base pattern.
2. Extract or duplicate minimal helpers for route suites only if needed.
3. Prefer private/internal helpers inside test files over adding new shared infrastructure unless duplication becomes significant.

Required helper capabilities:

- deploy custom base DETF with skewed initial deposits producing `syntheticPrice < burnThreshold`
- deploy custom Ethereum DETF with skewed initial deposits producing `syntheticPrice < burnThreshold`
- optionally deploy a near-peg DETF fixture where `burnThreshold <= syntheticPrice <= mintThreshold`

Recommended helper names:

- `_deployMintEnabledDetf()`
- `_deployMintEnabledEthereumDetf()`
- `_deployDeadbandDetf()`
- `_deployDeadbandEthereumDetf()`

Important rule:

- do not mutate default fixtures in-place when a fresh custom deployment is cleaner
- keep default fixtures intact for existing revert-path tests

### Phase 2: Positive Mint Execution Tests

Objective:

- add successful execution coverage for all missing CHIR mint routes

Add these tests.

#### Base Exact-In

Add to `ProtocolDETF_Routes.t.sol`:

1. `test_route_weth_to_chir_when_minting_allowed()`
   - deploy mint-enabled DETF
   - execute `exchangeIn(WETH -> CHIR)`
   - assert CHIR output is non-zero
   - assert user CHIR balance increased

2. `test_route_rich_to_chir_when_minting_allowed()`
   - deploy mint-enabled DETF
   - execute `exchangeIn(RICH -> CHIR)`
   - assert CHIR output is non-zero
   - assert user CHIR balance increased

3. `test_exchangeIn_weth_to_chir_preview_matches_execution_when_minting_allowed()`
   - deploy mint-enabled DETF
   - compare `previewExchangeIn` against actual `exchangeIn`
   - use bounded relative tolerance rather than exact equality

4. `test_exchangeIn_rich_to_chir_preview_matches_execution_when_minting_allowed()`
   - same pattern for `RICH -> CHIR`

#### Ethereum Exact-In

Add to `EthereumProtocolDETF_Routes.t.sol`:

5. `test_route_weth_to_chir_when_minting_allowed()`
6. `test_route_rich_to_chir_when_minting_allowed()`
7. `test_exchangeIn_weth_to_chir_preview_matches_execution_when_minting_allowed()`
8. `test_exchangeIn_rich_to_chir_preview_matches_execution_when_minting_allowed()`

#### Base Exact-Out

Add to `ProtocolDETFExchangeOut.t.sol`:

9. `test_exchangeOut_weth_chir_exact_when_minting_allowed()`
   - deploy mint-enabled DETF
   - preview required WETH
   - execute exact-out
   - assert exact CHIR received
   - assert actual WETH used is within preview expectations

10. `test_exchangeOut_rich_to_chir_exact_when_minting_allowed()`
    - same for `RICH -> CHIR`

11. `test_previewExchangeOut_weth_chir_matches_execution_when_minting_allowed()`
12. `test_previewExchangeOut_rich_to_chir_matches_execution_when_minting_allowed()`

#### Ethereum Exact-Out

Add to `EthereumProtocolDETFExchangeOut.t.sol`:

13. `test_exchangeOut_weth_chir_exact_when_minting_allowed()`
14. `test_exchangeOut_rich_to_chir_exact_when_minting_allowed()`
15. `test_previewExchangeOut_weth_chir_matches_execution_when_minting_allowed()`
16. `test_previewExchangeOut_rich_to_chir_matches_execution_when_minting_allowed()`

### Phase 3: Symmetric Failure Tests In Alternate Regimes

Objective:

- prove routes fail correctly in the opposite regime, not just in the default fixture

#### Burn Reverts In Mint-Enabled Fixtures

Add to both route and exact-out suites:

1. exact-in `CHIR -> WETH` reverts with `BurningNotAllowed` in mint-enabled fixture
2. exact-out `CHIR -> WETH` preview reverts with `BurningNotAllowed` in mint-enabled fixture
3. exact-out `CHIR -> WETH` execution reverts with `BurningNotAllowed` in mint-enabled fixture if preview path does not short-circuit first

#### Mint Reverts In Burn-Enabled Fixtures

This already exists in the default fixtures. Keep those tests and do not replace them.

#### Deadband Route-Level Reverts

Add tests using near-peg fixture in `ProtocolDETFSyntheticThresholds.t.sol` or a new dedicated route-level deadband test file.

Base:

1. exact-in `WETH -> CHIR` reverts in deadband
2. exact-in `CHIR -> WETH` reverts in deadband
3. exact-out `WETH -> CHIR` reverts in deadband
4. exact-out `CHIR -> WETH` reverts in deadband

Ethereum:

5. exact-in `WETH -> CHIR` reverts in deadband
6. exact-in `CHIR -> WETH` reverts in deadband
7. exact-out `WETH -> CHIR` reverts in deadband
8. exact-out `CHIR -> WETH` reverts in deadband

## Detailed Test Matrix

Use this as the completion checklist.

### Base Supported Routes

| Route | Exact-In Success | Exact-In Revert | Exact-Out Success | Exact-Out Revert | Preview Parity |
|------|------------------|-----------------|-------------------|------------------|----------------|
| WETH -> CHIR | required in mint-enabled fixture | present in default fixture | required in mint-enabled fixture | present in default fixture | required |
| RICH -> CHIR | required in mint-enabled fixture | present in default fixture | required in mint-enabled fixture | present in default fixture | required |
| CHIR -> WETH | present in default fixture | required in mint-enabled + deadband fixture | present in default fixture | required in mint-enabled + deadband fixture | required |
| WETH -> RICH | present | present where appropriate via slippage / route checks | present | present via slippage | already adequate |
| RICH -> WETH | present | optional only if explicit unsupported state exists | optional | optional | already adequate |
| WETH -> RICHIR | present | not needed unless regime-gated | exact-out unsupported | present | already adequate |
| RICH -> RICHIR | present | not needed unless regime-gated | exact-out unsupported | present | already adequate |
| RICHIR -> WETH | present | depends on allowed address policy | exact-out unsupported | present | already adequate |
| RICHIR -> RICH | present on base only | depends on allowed address policy | not currently exact-out-supported | verify explicit behavior if needed | already adequate |

### Ethereum Supported Routes

| Route | Exact-In Success | Exact-In Revert | Exact-Out Success | Exact-Out Revert | Preview Parity |
|------|------------------|-----------------|-------------------|------------------|----------------|
| WETH -> CHIR | required in mint-enabled fixture | present in default fixture | required in mint-enabled fixture | present in default fixture | required |
| RICH -> CHIR | required in mint-enabled fixture | present in default fixture | required in mint-enabled fixture | present in default fixture | required |
| CHIR -> WETH | present in default fixture | required in mint-enabled + deadband fixture | present in default fixture | required in mint-enabled + deadband fixture | required |
| WETH -> RICH | present | present where appropriate via slippage / route checks | present | present via slippage | already adequate |
| RICH -> WETH | present | optional only if explicit unsupported state exists | optional | optional | already adequate |
| WETH -> RICHIR | present | not needed unless regime-gated | exact-out unsupported | present | already adequate |
| RICH -> RICHIR | present | not needed unless regime-gated | exact-out unsupported | present | already adequate |
| RICHIR -> WETH | present | depends on allowed address policy | exact-out unsupported | present | already adequate |
| RICHIR -> RICH | unsupported / not exposed in current Ethereum fixture | keep explicitly unsupported if unchanged | unsupported | keep explicitly unsupported | not applicable |

## Suggested File-Level Changes

### `ProtocolDETFSyntheticThresholds.t.sol`

Expand this file into the fixture authority for alternate pricing regimes.

Add:

- `_deployCustomBaseDetf(uint256 richInitialDeposit, uint256 wethInitialDeposit)` if the current helper needs clearer naming
- `_deployCustomEthereumDetf(uint256 richInitialDeposit, uint256 wethInitialDeposit)`
- route-level deadband reversion tests
- optional helper assertions:
  - `_assertMintEnabled(IProtocolDETF detf_)`
  - `_assertBurnEnabled(IProtocolDETF detf_)`
  - `_assertDeadband(IProtocolDETF detf_)`

### `ProtocolDETF_Routes.t.sol` and `EthereumProtocolDETF_Routes.t.sol`

Add the missing positive exact-in mint tests and their preview parity tests.

Keep the current revert tests in the default fixtures.

Do not delete existing black-box RICHIR tests.

### `ProtocolDETFExchangeOut.t.sol` and `EthereumProtocolDETFExchangeOut.t.sol`

Add the missing positive exact-out mint tests.

Keep the current burn-positive tests and default-fixture mint-revert tests.

## Acceptance Criteria

Work is complete only when all of the following are true:

1. Every supported CHIR route has at least one successful execution test in the regime where it should succeed.
2. Every supported CHIR route has at least one failure test in the regime where it should fail.
3. Deadband enforcement is proven on route execution or preview paths, not just query helpers.
4. Base and Ethereum each have mint-enabled success coverage for both `WETH -> CHIR` and `RICH -> CHIR`.
5. Base and Ethereum each have burn-disabled failure coverage for `CHIR -> WETH` in mint-enabled fixtures.
6. All previously passing suites still pass.

## Validation Commands

Run after each phase instead of waiting for the end.

### After Phase 1

```bash
forge test --match-path test/foundry/spec/vaults/protocol/ProtocolDETFSyntheticThresholds.t.sol
```

### After Base Route Changes

```bash
forge test --match-path test/foundry/spec/vaults/protocol/ProtocolDETF_Routes.t.sol
forge test --match-path test/foundry/spec/vaults/protocol/ProtocolDETFExchangeOut.t.sol
```

### After Ethereum Route Changes

```bash
forge test --match-path test/foundry/spec/vaults/protocol/EthereumProtocolDETF_Routes.t.sol
forge test --match-path test/foundry/spec/vaults/protocol/EthereumProtocolDETFExchangeOut.t.sol
```

### Final Focused Sweep

```bash
forge test --match-path test/foundry/spec/vaults/protocol/ProtocolDETF_Routes.t.sol
forge test --match-path test/foundry/spec/vaults/protocol/EthereumProtocolDETF_Routes.t.sol
forge test --match-path test/foundry/spec/vaults/protocol/ProtocolDETFExchangeOut.t.sol
forge test --match-path test/foundry/spec/vaults/protocol/EthereumProtocolDETFExchangeOut.t.sol
forge test --match-path test/foundry/spec/vaults/protocol/ProtocolDETFSyntheticThresholds.t.sol
```

### Optional Broader Confidence Sweep

```bash
forge test --match-path test/foundry/spec/protocol/vaults/protocol/ProtocolDETFDFPkg_Deploy.t.sol
forge test --match-path test/foundry/spec/protocol/vaults/protocol/EthereumProtocolDETFDFPkg_Deploy.t.sol
```

## Expected Failure Modes

If implementation stops due to a critical failure, these are the most likely causes.

### 1. Custom Ethereum Fixture Does Not Reach Mint-Enabled State

Symptoms:

- expected mint-success tests revert with `MintingNotAllowed`

Response:

1. log `syntheticPrice`, `burnThreshold`, `mintThreshold`
2. skew initial deposits further toward WETH backing dominance if needed
3. compare deployment ratios to the already working base low-price fixture

### 2. Near-Peg Fixture Lands Outside Deadband

Symptoms:

- deadband tests unexpectedly enter mint-enabled or burn-enabled state

Response:

1. print the actual synthetic price
2. adjust deposit ratio in smaller increments
3. avoid changing core gate logic just to make a fixture land cleanly

### 3. Preview Parity Is Too Strict

Symptoms:

- preview tests fail by small bounded amounts

Response:

1. compare with existing parity tolerances already used elsewhere
2. use `assertApproxEqRel` or bounded conservative inequality rather than exact equality
3. only tighten if execution truly diverges beyond established preview buffers

### 4. Default Fixtures Break Accidentally

Symptoms:

- existing burn-positive or mint-revert tests start failing without touching gate logic

Response:

1. ensure new helpers are using custom deployments rather than mutating the shared default fixture
2. confirm no new helper is reusing contract state from prior tests in an unsafe way

## If Work Is Interrupted

A new agent should resume in this order:

1. read this file
2. run the current focused suite set listed above
3. inspect the five test files listed in `Files To Modify`
4. implement Phase 1 first if not already done
5. then implement Phase 2 base, Phase 2 Ethereum, and Phase 3 last
6. after each file burst, rerun only the affected suites

## Minimal First Slice If Time Is Limited

If implementation must be split into the smallest safe milestone, do this first:

1. add base `RICH -> CHIR` mint-enabled exact-in and exact-out success tests
2. add Ethereum `WETH -> CHIR` mint-enabled exact-in and exact-out success tests
3. add Ethereum `RICH -> CHIR` mint-enabled exact-in and exact-out success tests
4. rerun the five focused suites

That slice closes the largest remaining functional gap while minimizing fixture churn.
