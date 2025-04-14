# Code Review: IDXEX-032

**Reviewer:** Claude Opus 4.6
**Review Started:** 2026-02-06
**Status:** Complete

---

## Clarifying Questions

No clarifying questions needed. The task requirements are well-specified and the implementation is straightforward to verify.

---

## Review Findings

### Finding 1: All acceptance criteria met - NatSpec correctly updated
**File:** `contracts/interfaces/IVaultFeeOracleQuery.sol`
**Severity:** N/A (positive finding)
**Description:** The PPM NatSpec (`Fees as denominated in PPM (parts per million)` with PPM examples `1000 = 0.1%`, `10000 = 1%`, etc.) was correctly replaced with WAD NatSpec (`All fee percentages are denominated in WAD (1e18 = 100%)`) with accurate WAD examples (`1e15 = 0.1%`, `1e16 = 1%`, etc.). Zero-value sentinel behavior is documented. Fallback cascade is documented.
**Status:** Resolved
**Resolution:** Correct and complete.

### Finding 2: Manager interface NatSpec added correctly
**File:** `contracts/interfaces/IVaultFeeOracleManager.sol`
**Severity:** N/A (positive finding)
**Description:** Contract-level NatSpec block added with WAD convention, fallback semantics, and zero-sentinel docs. All usage fee and DEX swap fee setter functions have `@param` annotations specifying WAD scale with examples. "Set to 0 to clear the override" is documented on per-vault setters.
**Status:** Resolved
**Resolution:** Correct and complete.

### Finding 3: Constants annotations are accurate
**File:** `contracts/constants/Indexedex_CONSTANTS.sol`
**Severity:** N/A (positive finding)
**Description:** File-level comment `// All fee percentages use WAD scale (1e18 = 100%).` added. Each active constant has `(WAD)` suffix. Legacy PPM constants annotated as `(legacy PPM, unused)`. Lending terms annotated as `(legacy PPM scale, not yet migrated to WAD)`. Seigniorage spelling typo in section header fixed (`Seigniroage` -> `Seigniorage`).
**Status:** Resolved
**Resolution:** Correct and complete.

### Finding 4: Tests are comprehensive and well-structured
**File:** `test/foundry/spec/oracles/fee/VaultFeeOracle_Units.t.sol`
**Severity:** N/A (positive finding)
**Description:** 17 tests covering: WAD scale constant verification (4), oracle-constant alignment (4), fee calculation correctness via `BetterMath._percentageOfWAD()` (3), zero-value sentinel fallback (2), override behavior (2), global default update (2). All tests pass. Tests correctly use `address(0xdead)` for `view`-compatible tests and `makeAddr()` only in state-modifying tests.
**Status:** Resolved
**Resolution:** Correct and complete.

### Finding 5: BetterMath._percentageOfWAD confirms WAD scale
**File:** `lib/daosys/lib/crane/contracts/utils/math/BetterMath.sol`
**Severity:** N/A (verification finding)
**Description:** Verified that `_percentageOfWAD(total, percentage)` delegates to `_percentageOf(total, percentage, ONE_WAD)` where `ONE_WAD = 1e18`. Implementation: `(total * percentage) / 1e18`. The legacy `percentageOfPPM` function is fully commented out. This confirms the WAD convention is correct.
**Status:** Resolved
**Resolution:** Verified - implementation matches documentation.

### Finding 6: No input validation on fee setters (pre-existing, not introduced)
**File:** `contracts/oracles/fee/VaultFeeOracleManagerFacet.sol`
**Severity:** Low (informational, pre-existing)
**Description:** Fee setter functions accept any `uint256` value without bounds checking. A fee > 1e18 (>100%) would be accepted. This is pre-existing behavior, not introduced by this task, and is access-controlled by `onlyOwnerOrOperator`. However, documenting the lack of upper-bound validation would be useful.
**Status:** Resolved (out of scope)
**Resolution:** Pre-existing design choice. Access control mitigates risk. Noted as suggestion for future task.

---

## Suggestions

Actionable items for follow-up tasks:

### Suggestion 1: Add seigniorage manager setter functions to IVaultFeeOracleManager
**Priority:** Low
**Description:** Usage fees and DEX swap fees have public setter functions (`setDefaultUsageFee`, `setUsageFeeOfVault`, etc.) on `IVaultFeeOracleManager`, but seigniorage incentive percentages have no equivalent setters. The storage layer (`VaultFeeOracleRepo`) supports per-vault and per-type seigniorage overrides, but they can only be set during init. Adding `setDefaultSeigniorageIncentivePercentage`, `setDefaultSeigniorageIncentivePercentageOfTypeId`, and `setSeigniorageIncentivePercentageOfVault` would complete the interface symmetry.
**Affected Files:**
- `contracts/interfaces/IVaultFeeOracleManager.sol`
- `contracts/oracles/fee/VaultFeeOracleManagerFacet.sol`
**User Response:** Accepted
**Notes:** Converted to task IDXEX-054

### Suggestion 2: Add fee upper-bound validation
**Priority:** Low
**Description:** Fee setter functions accept any `uint256` without checking `fee <= 1e18`. While access-controlled, a `require(fee <= ONE_WAD)` guard would prevent misconfiguration (e.g., accidentally passing a PPM-scaled value to a WAD-scaled setter).
**Affected Files:**
- `contracts/oracles/fee/VaultFeeOracleManagerFacet.sol` (or a shared modifier)
**User Response:** Rejected
**Notes:** Skipped by user. May overlap with existing IDXEX-036 (Fee Oracle Authorization and Bounds Tests).

### Suggestion 3: Fix typo in VaultFeeOracleRepo internal function name
**Priority:** Low
**Description:** `_setDefaultSeigniorageIncentivePerecetageOfTypeId` (line 334) has a typo ("Perecetage" instead of "Percentage"). The public-facing wrapper at line 343 has the correct spelling and delegates to it, so this is only an internal code quality issue.
**Affected Files:**
- `contracts/oracles/fee/VaultFeeOracleRepo.sol`
**User Response:** Accepted
**Notes:** Converted to task IDXEX-055

### Suggestion 4: Migrate lending terms from PPM to WAD
**Priority:** Medium
**Description:** `DEFAULT_LENDING_BASE_RATE = 1000` is documented as `(legacy PPM scale, not yet migrated to WAD)`. When lending functionality is activated, these constants and their consumers should be migrated to WAD scale for consistency.
**Affected Files:**
- `contracts/constants/Indexedex_CONSTANTS.sol`
- (lending-related contracts, currently commented out)
**User Response:** Accepted
**Notes:** Converted to task IDXEX-056

---

## Review Summary

**Findings:** 6 findings, all resolved. No bugs or issues introduced by this change.
**Suggestions:** 4 follow-up suggestions (1 medium, 3 low priority).
**Recommendation:** APPROVE - This change correctly fixes the PPM-to-WAD documentation inconsistency across all active fee interfaces. The NatSpec is accurate, the constants annotations match their values, and the test suite comprehensively verifies WAD scale correctness including fallback behavior.

### Acceptance Criteria Verification

| Criterion | Status |
|-----------|--------|
| Determine whether fees are WAD or PPM | PASS - Confirmed WAD via `BetterMath._percentageOfWAD()` |
| Document the decision in code comments | PASS - File-level and contract-level NatSpec |
| `IVaultFeeOracleQuery.sol` NatSpec matches actual convention | PASS - WAD scale with examples |
| `Indexedex_CONSTANTS.sol` comments match values | PASS - All annotated with `(WAD)` |
| All fee-related interfaces have consistent unit documentation | PASS - Query + Manager interfaces updated |
| Test: default values produce expected fee percentages | PASS - 4 constant tests + 4 oracle alignment tests |
| Test: fee calculations produce expected outcomes | PASS - 3 BetterMath calculation tests |
| Zero-value sentinel behavior documented | PASS - Documented in both interfaces |
| Build succeeds | PASS |
| All tests pass | PASS - 17/17 |

---

**When review complete, output:** `<promise>PHASE_DONE</promise>`
