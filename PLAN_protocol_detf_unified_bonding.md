# Plan: Consolidate Protocol DETF Bonding Into A Unified Token-In Entry Point

## Goal

Replace the separate `bondWithWeth(...)` and `bondWithRich(...)` entrypoints with a single bonding function that:

1. accepts `tokenIn` explicitly,
2. validates `tokenIn` against an `AddressSet` of supported bond tokens,
3. supports both current bond assets (`WETH` and `RICH`) through a shared dispatch path,
4. optionally accepts native ETH via a `wethAsEth` flag and wraps it into WETH before continuing,
5. preserves existing principal, share, and NFT-position semantics.

This is a planning document only. No implementation should start until this plan is reviewed and approved.

## Current State Summary

The current bonding API is split across two dedicated functions in the bonding targets:

- `bondWithWeth(uint256 amountIn, uint256 lockDuration, address recipient, uint256 deadline)`
- `bondWithRich(uint256 amountIn, uint256 lockDuration, address recipient, uint256 deadline)`

These are implemented separately in both:

- `contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol`
- `contracts/vaults/protocol/EthereumProtocolDETFBondingTarget.sol`

Both functions are structurally similar:

1. validate deadline and zero amounts,
2. validate reserve-pool initialization,
3. normalize `recipient`,
4. transfer the specific token from the user,
5. route into the corresponding vault path,
6. add reserve-pool shares,
7. create the Protocol NFT Vault position.

The main difference is the asset-specific deposit route:

- WETH route: balanced WETH -> CHIR/WETH LP -> CHIR/WETH vault -> reserve pool
- RICH route: RICH -> RICH/CHIR vault -> reserve pool

## Design Intent

The unified bonding surface should make the accepted bond assets configurable and introspectable rather than hardcoded in public function names.

The intended end state is:

1. Users call one primary bond function with `tokenIn`.
2. The DETF checks whether `tokenIn` is present in a bond-token `AddressSet`.
3. The DETF routes internally to the correct asset-specific bonding path.
4. If `tokenIn` is WETH and `wethAsEth == true`, the function wraps `msg.value` into WETH first, following the same UX pattern already used in the Standard Exchange Router.
5. The NFT-position creation and lock semantics remain unchanged.
6. Existing WETH/RICH support becomes data-driven via the accepted-token set, rather than encoded in separate public APIs.

## Core API Direction

### New primary entry point

Introduce a unified entry point on the bonding surface with a parameter shape along these lines:

```solidity
function bond(
    IERC20 tokenIn,
    uint256 amountIn,
    uint256 lockDuration,
    address recipient,
    bool wethAsEth,
    uint256 deadline
) external payable returns (uint256 tokenId, uint256 shares);
```

This plan intentionally avoids locking the final name if the maintainer prefers `bondWithToken(...)` or `bondTokenIn(...)`, but the shape should remain token-driven and include the native-ETH flag.

### Backward compatibility decision

The cleanest target state is to make the unified token-in function the canonical public API and remove the old split entrypoints from the DETF bonding interface and facet metadata.

However, execution should be staged conservatively:

1. Phase 1 implementation may keep `bondWithWeth(...)` and `bondWithRich(...)` as thin wrappers around the new unified function to reduce migration risk.
2. Phase 2 cleanup can remove them only after tests, scripts, and frontend callers are updated.

That allows review of behavior changes separately from API removal.

## Storage And Validation Model

### New accepted bond token set

Use an `AddressSet` in `BaseProtocolDETFRepo.Storage` to hold the accepted bond tokens.

This repo already uses `AddressSetRepo` and already stores an `AddressSet` in the DETF storage layout for `allowedRichirRedeemAddresses`, so the pattern is consistent with existing code.

Recommended new storage member:

- `AddressSet acceptedBondTokens;`

Recommended repo helpers:

- `_addAcceptedBondToken(...)`
- `_removeAcceptedBondToken(...)`
- `_isAcceptedBondToken(...)`
- `_acceptedBondTokens(...)`

### Initial accepted tokens

For the first pass, initialize the accepted bond-token set with:

- `layout.richToken`
- `layout.wethToken`

That keeps runtime behavior equivalent to today while making the surface extensible.

### Validation rule

The unified bond function should revert if `tokenIn` is not in the accepted-bond-token set.

This should be a DETF-specific error, not a generic `TokenNotSupported()` if a more precise bonding error is appropriate.

Recommended explicit error shapes:

- `BondTokenNotSupported(address token)`
- `InvalidEthBondRoute(address tokenIn)`
- `IncorrectEthValue(uint256 expected, uint256 actual)`

## Native ETH / WETH UX Model

### Desired behavior

Match the Standard Exchange Router pattern conceptually:

1. if `wethAsEth == false`, the function behaves like a normal ERC20 path and expects token transfer/approval semantics,
2. if `wethAsEth == true`, the function only permits the WETH bond route,
3. native ETH is accepted via `msg.value`,
4. the function wraps ETH into WETH internally,
5. the rest of the bonding flow runs exactly as if WETH had been provided directly.

### Required route rules

The plan should enforce these route constraints:

1. `wethAsEth == true` is only valid when `tokenIn == layout.wethToken`.
2. `msg.value` must equal `amountIn` when `wethAsEth == true`.
3. `msg.value` must be zero when `wethAsEth == false`.
4. The implementation should wrap via the canonical WETH contract already configured in DETF storage.
5. No ETH mode should be supported for RICH.

### Why use a flag instead of `address(0)`

Keep `tokenIn` equal to WETH even in ETH mode.

That preserves a single canonical asset identity for routing, set membership, quoting, and test expectations. The boolean only changes transport semantics, not token semantics.

## Files That Must Be Touched During Execution

### Primary implementation files

- `contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol`
- `contracts/vaults/protocol/EthereumProtocolDETFBondingTarget.sol`
- `contracts/vaults/protocol/BaseProtocolDETFRepo.sol`
- `contracts/interfaces/IProtocolDETF.sol`

### Likely supporting files

- `contracts/vaults/protocol/BaseProtocolDETFDFPkg.sol`
- `contracts/vaults/protocol/EthereumProtocolDETFDFPkg.sol`
- `contracts/vaults/protocol/TestBase_BaseProtocolDETF.sol`
- `test/foundry/spec/vaults/protocol/...` bonding specs that currently call `bondWithWeth` or `bondWithRich`

### Possibly affected query / helper surfaces

These should be reviewed for API drift even if not all require changes:

- `contracts/vaults/protocol/BaseProtocolDETFBondingQueryTarget.sol`
- `contracts/vaults/protocol/EthereumProtocolDETFBondingQueryTarget.sol`
- test helpers and fixture helpers that currently encode separate WETH vs RICH bond setup paths
- scripts or frontend callers that directly invoke the old split functions

## Execution Phases

## Phase 1: Add Storage And Repo Helpers For Accepted Bond Tokens

### Objective

Make accepted bond assets explicit in storage rather than implied by branching on hardcoded public methods.

### Changes

1. Extend `BaseProtocolDETFRepo.Storage` with `acceptedBondTokens`.
2. Add `AddressSetRepo` usage to `BaseProtocolDETFRepo.sol`.
3. Add repo helpers for add/remove/contains/list operations.
4. Initialize the set during DETF deployment with current supported assets:
   - WETH
   - RICH
5. Decide whether the set is immutable-after-init for now or owner-managed in a follow-up phase.

### Review note

For the first pass, this plan recommends initialization-only behavior, not admin mutability. That keeps the refactor narrowly scoped to bonding consolidation without introducing governance surfaces.

## Phase 2: Introduce The Unified Bond Function And Internal Dispatch

### Objective

Replace duplicated public logic with one token-driven entrypoint and shared validation.

### Changes

1. Add the new unified bond entrypoint to the bonding interface.
2. Centralize common validation:
   - deadline
   - zero amount
   - reserve initialization
   - recipient normalization
   - token acceptance
   - ETH mode validation
3. Split asset-specific work into internal helpers rather than public functions.

Recommended internal shape:

- `_bondWithToken(...)`
- `_bondFromWeth(...)`
- `_bondFromRich(...)`
- `_prepareBondInput(...)`
- `_wrapEthToWethIfNeeded(...)`

### Routing model

Dispatch by `tokenIn`:

- `tokenIn == layout.wethToken` -> WETH bonding path
- `tokenIn == layout.richToken` -> RICH bonding path
- else -> revert unsupported bond token

### Keep asset-specific core math intact

Do not rewrite the economics in this refactor.

The goal is API consolidation and shared validation, not changing:

- quote behavior
- LP mint path
- reserve-pool additions
- lock calculations
- NFT share creation

## Phase 3: Add Native ETH Support For The WETH Route

### Objective

Allow the unified bond function to accept native ETH when the user is bonding through the WETH route.

### Changes

1. Make the unified bond function `payable`.
2. When `wethAsEth == true`:
   - require `tokenIn == layout.wethToken`
   - require `msg.value == amountIn`
   - call WETH `deposit{value: amountIn}()`
   - continue using the normal WETH bonding helper
3. When `wethAsEth == false`:
   - require `msg.value == 0`
   - preserve current ERC20 approval + transfer behavior

### ETH handling constraints

The implementation should not silently accept extra ETH or partial ETH.

It should enforce exact-value semantics so users and tests cannot accidentally desynchronize `amountIn` from `msg.value`.

### Router-consistency requirement

The plan should mirror the existing Standard Exchange Router semantics conceptually, but keep the DETF bond flow simpler:

- wrap incoming ETH only for WETH token-in paths,
- do not add outbound ETH logic because the bond flow outputs NFT positions, not WETH.

## Phase 4: Migrate Existing Public Split Functions

### Objective

Move external callers onto the unified function without unnecessary breakage.

### Recommended staged approach

#### Step 1

Keep `bondWithWeth(...)` and `bondWithRich(...)` as thin wrappers that call the new unified function.

That allows:

- scripts and tests to continue working during the refactor,
- easier diff review,
- easier bisection if behavior changes.

#### Step 2

Update internal tests, helpers, and any scripts/frontend call sites to use the unified function directly.

#### Step 3

After all direct callers have migrated and the change has soaked in review, optionally remove the split functions and shrink facet metadata.

This should be a deliberate cleanup commit, not mixed into the initial behavioral refactor.

## Phase 5: Update Interfaces, Docs, And Facet Metadata

### Objective

Keep the public contract surface, docs, and selector declarations coherent.

### Changes

1. Update `IProtocolDETF.sol` to document the new unified bond function.
2. If wrappers remain temporarily, document them as compatibility shims.
3. Update NatSpec to describe:
   - accepted bond-token set semantics,
   - `wethAsEth` semantics,
   - `msg.value` rules,
   - revert conditions for invalid routes.
4. Update any facet selector lists if the unified function becomes part of the DETF public proxy surface.

## Phase 6: Update Tests And Fixtures

### Objective

Prove the new surface preserves current behavior and adds ETH-mode safely.

### Required test categories

#### 1. Backward-compatibility tests

If wrappers remain:

- `bondWithWeth(...)` still succeeds and matches the unified WETH path
- `bondWithRich(...)` still succeeds and matches the unified RICH path

#### 2. Unified-token success tests

Add coverage for:

- bond with `tokenIn = WETH`, `wethAsEth = false` 
- bond with `tokenIn = RICH`, `wethAsEth = false`
- bond with `tokenIn = WETH`, `wethAsEth = true`, `msg.value = amountIn`

Each should validate:

- NFT mint success
- expected owner/recipient
- nonzero shares
- expected vault position state

#### 3. Accepted-token set validation tests

Add failure coverage for:

- unsupported `tokenIn`
- valid token not in set after fixture manipulation

#### 4. ETH mode negative tests

Add failure coverage for:

- `wethAsEth = true` with `tokenIn = RICH`
- `wethAsEth = true` with `msg.value != amountIn`
- `wethAsEth = false` with nonzero `msg.value`

#### 5. Regression tests for share accounting

Re-run or add checks proving unified routing does not change:

- reserve-pool share outcomes materially beyond existing rounding bounds
- NFT lock durations
- position ownership
- subsequent sale/redeem behavior

### Likely test files to update

- `contracts/vaults/protocol/TestBase_BaseProtocolDETF.sol`
- current Protocol DETF bonding specs in `test/foundry/spec/vaults/protocol/`
- any Base/Ethereum integration suites that currently call `_bondWithWeth(...)` / `_bondWithRich(...)`

## Phase 7: Review Frontend And Script Impact

### Objective

Prevent API drift after the contract refactor.

### Review checklist

1. Search for direct calls to:
   - `bondWithWeth`
   - `bondWithRich`
2. Update frontend ABI consumers if the unified function becomes canonical.
3. Update scripts and local dev helpers to pass:
   - `tokenIn`
   - `amountIn`
   - `wethAsEth`
4. Confirm ETH-mode UX only appears when `tokenIn` is WETH.

This phase is a required review even if no immediate frontend changes are implemented in the first execution pass.

## Non-Goals For This Refactor

This plan should not expand into the following unless explicitly approved later:

1. adding arbitrary new bond tokens beyond current WETH and RICH,
2. changing bond economics or quote math,
3. adding admin UX for modifying accepted bond tokens post-deploy,
4. changing the Protocol NFT Vault reward model,
5. changing sell/redeem semantics.

## Risks To Watch During Execution

1. Selector churn risk:
   - Removing old public functions too early may break tests, scripts, or frontend consumers.

2. ETH accounting risk:
   - Incorrect `msg.value` handling can strand ETH or create mismatches between wrapped WETH and accounting assumptions.

3. Storage risk:
   - Adding `acceptedBondTokens` must preserve storage layout correctness in `BaseProtocolDETFRepo.Storage`.

4. Cross-target drift risk:
   - Base and Ethereum bonding targets must stay behaviorally aligned.

5. Test helper drift:
   - Existing helper methods may hide API inconsistencies if wrappers are removed before fixtures are updated.

## Acceptance Criteria

The refactor is complete when all of the following are true:

1. There is one canonical token-in bond function on the DETF bonding surface.
2. Supported bond assets are validated against an `AddressSet` in DETF storage.
3. WETH and RICH are initialized into that accepted-token set.
4. Native ETH can be bonded only through the WETH route using `wethAsEth`.
5. Invalid ETH/token combinations revert explicitly.
6. Base and Ethereum implementations both support the unified bond flow.
7. Existing bond behavior for WETH and RICH remains intact.
8. Focused Foundry tests cover token-in success paths and ETH-mode failures.
9. Any retained legacy wrappers are documented as compatibility shims.
10. Frontend/script call sites are reviewed for compatibility before old selectors are removed.

## Suggested Implementation Order

1. Add `acceptedBondTokens` storage and repo helpers.
2. Initialize WETH and RICH into the set during DETF deployment.
3. Add unified `bond(...)` interface and target implementation.
4. Refactor current WETH/RICH public methods into wrappers around the unified path.
5. Add ETH wrapping support behind `wethAsEth`.
6. Update tests and helper fixtures.
7. Review scripts/frontend consumers.
8. Decide in a follow-up cleanup whether to remove the legacy split entrypoints.
