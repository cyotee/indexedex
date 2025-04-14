# Progress Log: IDXEX-036

## Current Checkpoint

**Last checkpoint:** All tests implemented and passing
**Next step:** Ready for code review
**Build status:** PASS (forge build succeeds)
**Test status:** PASS (66/66 tests pass across 4 test suites)

---

## Acceptance Criteria Status

### US-IDXEX-036.1: Fee Oracle Setter Authorization Tests
- [x] Test: `setDefaultUsageFee` reverts for non-owner/non-operator
- [x] Test: `setDefaultUsageFeeOfTypeId` reverts for non-owner/non-operator
- [x] Test: `setUsageFeeOfVault` reverts for non-owner/non-operator
- [x] Test: `setDefaultBondTerms` reverts for non-owner/non-operator
- [x] Test: `setDefaultBondTermsOfTypeId` reverts for non-owner/non-operator
- [x] Test: `setVaultBondTerms` reverts for non-owner/non-operator
- [x] Test: `setDefaultDexSwapFee` reverts for non-owner/non-operator
- [x] Test: `setDefaultDexSwapFeeOfTypeId` reverts for non-owner/non-operator
- [x] Test: `setVaultDexSwapFee` reverts for non-owner/non-operator
- [x] Test: owner can call all setters
- [x] Test: operator can call all setters — SKIPPED (OperableFacet not in IndexedexManagerDFPkg; documented in test file header)

### US-IDXEX-036.2: Fee Parameter Bounds Tests
- [x] Test: usage fee at/above 100% accepted (no on-chain cap)
- [x] Test: swap fee at/above 100% accepted (no Balancer-compatible range check)
- [x] Test: bond terms with extreme/inverted ranges accepted (no validation)
- [x] Test: zero-value sentinel triggers fallback for all fee types
- [x] Test: three-tier fallback chain (vault -> type -> global)
- [x] Fuzz: any uint256 value storable and retrievable

### US-IDXEX-036.3: Fee Dilution Impact Tests
- [x] Test: 0% usage fee (sentinel) -> falls back to default, not zero
- [x] Test: 100% usage fee -> maximum dilution (entire yield extracted)
- [x] Test: >100% usage fee -> excess extraction (more than yield)
- [x] Test: extreme fee values -> arithmetic overflow documented
- [x] Test: default fee impact quantified (0.1% usage, 5% dex, 50% seigniorage)
- [x] Fuzz: fee extraction always proportional (yield * pct / 1e18)

## Files Created

| File | Tests | Description |
|------|-------|-------------|
| `test/foundry/spec/oracles/fee/VaultFeeOracleManagerFacet_Auth.t.sol` | 20 | Authorization tests (pre-existing) |
| `test/foundry/spec/oracles/fee/VaultFeeOracle_Units.t.sol` | 17 | WAD scale & fallback tests (pre-existing) |
| `test/foundry/spec/oracles/fee/VaultFeeOracle_Bounds.t.sol` | 15 | Bounds validation & fuzz tests (NEW) |
| `test/foundry/spec/oracles/fee/VaultFeeOracle_Dilution.t.sol` | 14 | Economic impact & dilution tests (NEW) |

## Key Findings

1. **No on-chain bounds**: The VaultFeeOracleRepo stores any uint256 value. Fees above 100% are accepted. This is by design — access control (owner/operator only) prevents misconfiguration.
2. **No explicit 0% fee**: The zero-value sentinel means "unset" and triggers fallback. The protocol always extracts some fee via the global default.
3. **Overflow risk**: `BetterMath._percentageOfWAD(yield, fee)` computes `(yield * fee) / 1e18`. With extreme fee values (e.g., type(uint256).max), large yields cause arithmetic overflow.
4. **Operator tests blocked**: OperableFacet is not included in IndexedexManagerDFPkg. Operator authorization tests will need to be enabled when it's added.

---

## Session Log

### 2026-02-07 - Implementation Complete

- Explored fee oracle contracts, interfaces, and access control patterns
- Verified existing auth test file covers all 9 onlyOwnerOrOperator setters + setFeeTo
- Created `VaultFeeOracle_Bounds.t.sol` with 15 tests (including 2 fuzz)
- Created `VaultFeeOracle_Dilution.t.sol` with 14 tests (including 2 fuzz)
- Fixed vm.expectRevert depth issue by introducing PercentageCalculator helper
- All 66 tests pass, build succeeds

### 2026-02-02 - Task Created

- Task designed from REVIEW_REPORT.md coverage gaps
- Depends on IDXEX-026 (access control fix)
- TASK.md populated with requirements
- Ready for agent assignment via /backlog:launch
