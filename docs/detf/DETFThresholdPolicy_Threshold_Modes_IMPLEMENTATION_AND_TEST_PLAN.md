# DETFThresholdPolicy — Threshold Modes Implementation & Test Plan

## 1. Normative refs

| Resource | Path |
|----------|------|
| Product law | [`../DETF_Threshold_Modes_PRD.md`](../DETF_Threshold_Modes_PRD.md) — **PRODUCT LAW LOCKED** + **§16 Pre-plan encoding locks** |
| Progress tracker | [`../DETF_Threshold_Modes_PROGRESS.md`](../DETF_Threshold_Modes_PROGRESS.md) |
| Current lib | [`DETFThresholdPolicy.sol`](./DETFThresholdPolicy.sol) |
| AGENTS.md | Repo root — DETF common expectations; CREATE3/registry N/A for pure lib |

**Conforms to product law + §16; no re-litigation.**

This plan is **P0**. Families import this API; they must not redefine defaults or invent alternate Open short-circuit logic.

---

## 2. Goals / non-goals

### Goals

1. Own **`ThresholdMode`**, default constants, `resolveThresholds`, and mode-aware pure allow helpers in one library.
2. Open short-circuits mint/burn **threshold** checks (no `live` param in lib).
3. Preserve strict Policy inequalities: mint `price > threshold`; burn `price < threshold` (equality = deadband).
4. Provide pure Foundry unit tests with **no diamond / no deploy path**.
5. Keep backward-compatible 2-arg Policy wrappers so unported families (F4–F7) keep compiling until they migrate.

### Non-goals

- Live / inert checks (family responsibility).
- Storage, events, PkgArgs, facets, fee oracle.
- Deploy validation reverts for invalid mode / mint≤burn (family DFPkg/init; lib may expose pure predicates only).
- Claim redeem, UI, asymmetric modes.
- Production Diamond packages.

---

## 3. Current state audit

| Item | Today |
|------|--------|
| File | `contracts/vaults/detf/common/core/DETFThresholdPolicy.sol` |
| API | `_isMintingAllowed(uint256 threshold_, uint256 price_)` → `price_ > threshold_` |
| | `_isBurningAllowed(uint256 threshold_, uint256 price_)` → `price_ < threshold_` |
| Enum / mode | **None** |
| Defaults | **Not in lib** — duplicated in each family DFPkg (`_DEFAULT_MINT_THRESHOLD = 1.05e18`, `_DEFAULT_BURN_THRESHOLD = 0.95e18`) and Common (`DEFAULT_MINT_THRESHOLD` / `DEFAULT_BURN_THRESHOLD`) |
| Resolve | **Not in lib** — each DFPkg: `args.mintThreshold == 0 ? default : args.mintThreshold` |
| Pure unit tests | **None** under `test/foundry/spec/vaults/detf/common/core/` |
| Callers (grep) | F1/F2/F3 Common; F4 `ComposedStableCommonDetfCommon`; F5 `SingleVaultDetfCommon` |

---

## 4. Target API (exact signatures)

All functions `internal pure` on library `DETFThresholdPolicy` unless noted. Prefer existing underscore convention for Crane/IndexedEx internal libs.

### 4.1 Enum and constants

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/// @notice Deploy-time primary-market gate mode (PRD DETF_Threshold_Modes).
enum ThresholdMode {
    Policy, // 0 — default; deadband gates
    Open    // 1 — threshold gates always pass; live still enforced by family
}

library DETFThresholdPolicy {
    uint256 internal constant DEFAULT_MINT_THRESHOLD = 1.05e18;
    uint256 internal constant DEFAULT_BURN_THRESHOLD = 0.95e18;

    // ... functions below
}
```

**Enum location lock:** define `ThresholdMode` in the **same file** as the library (file-level enum) so families and DFPkg interfaces can import:

```solidity
import {
    DETFThresholdPolicy,
    ThresholdMode
} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
```

Do **not** nest the enum only inside the library in a way that breaks `I*DFPkg.PkgArgs` usage (Solidity allows file-level enum import).

### 4.2 Resolve

```solidity
/// @notice Map PkgArgs zeros to defaults. Mode-agnostic. Does not validate mint > burn.
function resolveThresholds(uint256 mintArg_, uint256 burnArg_)
    internal
    pure
    returns (uint256 mintThreshold_, uint256 burnThreshold_)
{
    mintThreshold_ = mintArg_ == 0 ? DEFAULT_MINT_THRESHOLD : mintArg_;
    burnThreshold_ = burnArg_ == 0 ? DEFAULT_BURN_THRESHOLD : burnArg_;
}
```

### 4.3 Validation helpers (pure predicates — families revert)

```solidity
/// @notice True if mode is Policy or Open only.
function isValidThresholdMode(ThresholdMode mode_) internal pure returns (bool) {
    return uint8(mode_) <= uint8(ThresholdMode.Open);
}

/// @notice After resolve: Policy and Open both require mintThreshold > burnThreshold.
function isValidThresholdPair(uint256 mintThreshold_, uint256 burnThreshold_)
    internal
    pure
    returns (bool)
{
    return mintThreshold_ > burnThreshold_;
}
```

Optional convenience used by DFPkg:

```solidity
function resolveAndValidateThresholds(uint256 mintArg_, uint256 burnArg_)
    internal
    pure
    returns (uint256 mintThreshold_, uint256 burnThreshold_)
{
    (mintThreshold_, burnThreshold_) = resolveThresholds(mintArg_, burnArg_);
    // Note: pure lib does not revert with family errors — either:
    // (A) return bool ok via separate check, or
    // (B) revert with a lib error InvalidThresholdPair(mint, burn).
}
```

**Plan choice (locked for implementers):** prefer **(B)** one lib error for invalid pair so families share one selector:

```solidity
error InvalidThresholdPair(uint256 mintThreshold, uint256 burnThreshold);
error InvalidThresholdMode(uint8 mode);

function resolveAndRequireValidThresholds(uint256 mintArg_, uint256 burnArg_)
    internal
    pure
    returns (uint256 mintThreshold_, uint256 burnThreshold_)
{
    (mintThreshold_, burnThreshold_) = resolveThresholds(mintArg_, burnArg_);
    if (mintThreshold_ <= burnThreshold_) {
        revert InvalidThresholdPair(mintThreshold_, burnThreshold_);
    }
}

function requireValidThresholdMode(ThresholdMode mode_) internal pure {
    if (!isValidThresholdMode(mode_)) {
        revert InvalidThresholdMode(uint8(mode_));
    }
}
```

Families may still wrap with their own errors if desired; default is use lib errors at init.

### 4.4 Mode-aware allow (primary API)

```solidity
/// @dev No live flag. Open → true. Policy → strict >.
function _isMintingAllowed(ThresholdMode mode_, uint256 mintThreshold_, uint256 price_)
    internal
    pure
    returns (bool allowed_)
{
    if (mode_ == ThresholdMode.Open) return true;
    // Policy (and any future default to Policy-only behavior)
    allowed_ = price_ > mintThreshold_;
}

/// @dev No live flag. Open → true. Policy → strict <.
function _isBurningAllowed(ThresholdMode mode_, uint256 burnThreshold_, uint256 price_)
    internal
    pure
    returns (bool allowed_)
{
    if (mode_ == ThresholdMode.Open) return true;
    allowed_ = price_ < burnThreshold_;
}
```

### 4.5 Optional helper

```solidity
function _isOpenMode(ThresholdMode mode_) internal pure returns (bool) {
    return mode_ == ThresholdMode.Open;
}
```

### 4.6 Backward-compatible 2-arg wrappers (Policy-only)

Existing call sites:

```solidity
DETFThresholdPolicy._isMintingAllowed(s.mintThreshold, _syntheticPrice());
```

**Keep** 2-arg overloads as **Policy** semantics until all families pass mode:

```solidity
/// @notice Policy-only wrapper (legacy). Prefer 3-arg form with explicit mode.
function _isMintingAllowed(uint256 threshold_, uint256 price_)
    internal
    pure
    returns (bool allowed_)
{
    allowed_ = _isMintingAllowed(ThresholdMode.Policy, threshold_, price_);
}

function _isBurningAllowed(uint256 threshold_, uint256 price_)
    internal
    pure
    returns (bool allowed_)
{
    allowed_ = _isBurningAllowed(ThresholdMode.Policy, threshold_, price_);
}
```

Solidity allows overloads on libraries. F1–F3 must migrate to 3-arg + stored mode; F4–F7 may keep 2-arg until their wave.

### 4.7 What families must NOT reimplement

| Forbidden local reimplementation | Use instead |
|----------------------------------|-------------|
| `1.05e18` / `0.95e18` default constants | `DETFThresholdPolicy.DEFAULT_*` |
| `0 → default` resolve | `resolveThresholds` / `resolveAndRequireValidThresholds` |
| `if (open) allow` short-circuit | `_isMintingAllowed(mode, …)` / `_isBurningAllowed(mode, …)` |
| Infer Open from `mint==1 && burn==max` | never |
| Live flag inside lib calls | family Common only |

---

## 5. Touch list

| File | Action |
|------|--------|
| `contracts/vaults/detf/common/core/DETFThresholdPolicy.sol` | **Extend** (enum, constants, resolve, validate, 3-arg allow, 2-arg wrappers, errors) |
| `test/foundry/spec/vaults/detf/common/core/DETFThresholdPolicy.t.sol` | **Create** pure unit tests |

No FactoryService, DFPkg, or diamond work in this phase.

---

## 6. Init / validation (lib scope)

Lib does not write storage. It provides:

| Concern | Function |
|---------|----------|
| Resolve zeros | `resolveThresholds` |
| Require mint > burn after resolve | `resolveAndRequireValidThresholds` |
| Require mode ∈ {Policy, Open} | `requireValidThresholdMode` |

Invalid raw `uint8` mode: families cast `ThresholdMode(args.thresholdMode)` then `requireValidThresholdMode`. For ABI, `PkgArgs` field is typed `ThresholdMode` so only out-of-range via assembly/malformed encode is a concern — still check `uint8(mode) <= uint8(Open)`.

---

## 7. Synthetic confirmation

**N/A for pure lib.** Price is a `uint256` parameter; families always pass `_syntheticPrice()` (or migrated synthetic), never spot.

---

## 8. Test map (pure unit)

**Contract:** `test/foundry/spec/vaults/detf/common/core/DETFThresholdPolicy.t.sol`  
**Harness:** plain `forge-std/Test.sol` — **no** `CraneTest` / diamond required.

Map to program T-IDs where pure-applicable:

| PRD ID | Proposed test | Expect |
|--------|---------------|--------|
| T1 (resolve) | `test_resolveThresholds_zerosMapToDefaults` | `(0,0)` → `(1.05e18, 0.95e18)` |
| T2 (resolve) | `test_resolveThresholds_customPassthrough` | non-zero preserved |
| T3 / Open | `test_isMintingAllowed_openAlwaysTrue` | Open + any price → true |
| T3 / Open | `test_isBurningAllowed_openAlwaysTrue` | Open + any price → true |
| T4 | `test_resolveAndRequireValidThresholds_revertsWhenMintLeBurn` | e.g. mint=0.9e18 burn=1.0e18 after resolve; `1,1`; `0,0` is valid |
| T4 edge | `test_resolveAndRequireValidThresholds_equalityReverts` | mint==burn after resolve reverts |
| T4 edge | `test_resolveAndRequireValidThresholds_openStillValidatesPair` | Open path uses same resolve helper at family; unit: pair check independent of mode |
| T5 equality | `test_isMintingAllowed_policyEqualityIsDeadband` | Policy, price==mint → false |
| T5 equality | `test_isBurningAllowed_policyEqualityIsDeadband` | Policy, price==burn → false |
| T5/T6 | `test_isMintingAllowed_policyStrictGreater` | price mint+1 → true; price mint → false |
| T5/T7 | `test_isBurningAllowed_policyStrictLess` | price burn-1 → true; price burn → false |
| T18 | `test_twoArgWrappersAssumePolicy` | 2-arg matches 3-arg Policy |
| — | `test_requireValidThresholdMode_acceptsPolicyAndOpen` | ok |
| — | `test_requireValidThresholdMode_revertsOnInvalid` | `ThresholdMode(uint8(2))` reverts |
| — | `test_isOpenMode` | Policy false, Open true |
| T19 unit | `test_openIgnoresThresholdNumbers` | Open + mint=type(uint256).max still mint allowed |

**N/A for pure lib:** T6–T19 execution/live/diamond cases (family plans).

---

## 9. Production-first rules

- Pure library only; no mocks of production DETF packages.
- Unit tests may use fixed numbers only (no protocol stubs required).
- Do not deploy facets via `new` in this phase (nothing to deploy).

---

## 10. Rollout order

1. Implement enum + constants + resolve + errors + mode-aware allow + 2-arg wrappers in `DETFThresholdPolicy.sol`.
2. Add pure unit test file; run until green.
3. Mark **P0 done** in `DETF_Threshold_Modes_PROGRESS.md`.
4. Hand off to F1 (P1) — families switch to 3-arg + resolve helpers.

**Compile note:** Adding 3-arg overloads alongside 2-arg must not break existing F4/F5 callers. Verify:

```bash
forge build
forge test --match-path 'test/foundry/spec/vaults/detf/common/core/DETFThresholdPolicy.t.sol' -vv
```

Optional smoke: run one existing F1 test that still uses 2-arg until F1 migrates — should still compile after P0.

---

## 11. Definition of done

- [x] `ThresholdMode` enum `Policy=0`, `Open=1` importable from core file
- [x] `DEFAULT_MINT_THRESHOLD` / `DEFAULT_BURN_THRESHOLD` only canonical defaults for new code
- [x] `resolveThresholds` + `resolveAndRequireValidThresholds` + mode require helpers
- [x] 3-arg `_isMintingAllowed` / `_isBurningAllowed` with Open short-circuit; **no** `live` parameter
- [x] 2-arg wrappers = Policy semantics
- [x] Pure unit tests cover resolve, Open, Policy strict inequalities, equality deadband, invalid pair, invalid mode
- [x] `forge test` for unit file green
- [x] PROGRESS.md P0 → `done` with date

---

## 12. Out of scope

- Claim redeem gates
- Frontend / UI
- Fee-oracle thresholds
- Asymmetric modes
- Family storage / `ThresholdModeSet` event (family plans)
- Spot→synthetic migration (F5 plan)
- AGENTS.md one-liner (P7)

---

## 13. API cheat sheet for family agents

```text
import {DETFThresholdPolicy, ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

// Init (DFPkg):
DETFThresholdPolicy.requireValidThresholdMode(args.thresholdMode);
(mint, burn) = DETFThresholdPolicy.resolveAndRequireValidThresholds(args.mintThreshold, args.burnThreshold);
// store mode + mint + burn; emit ThresholdModeSet(mode, mint, burn);

// Gate (Common) — live first:
if (!live) return false; // or revert ReservePoolNotInitialized on execution
return DETFThresholdPolicy._isMintingAllowed(mode, mintThreshold, syntheticPrice);
return DETFThresholdPolicy._isBurningAllowed(mode, burnThreshold, syntheticPrice);
```
