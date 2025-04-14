# Task IDXEX-066: Add On-Chain Fee Oracle Bounds Validation

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-02-07
**Dependencies:** IDXEX-036 (complete)
**Worktree:** `feature/add-fee-oracle-bounds-validation`
**Origin:** Code review suggestion from IDXEX-036 (Suggestion 2)

---

## Description

The fee oracle currently accepts ANY `uint256` value for fee parameters. The IDXEX-036 bounds tests proved that:

- Usage fees >100% (>1e18 WAD) cause excess extraction from vault yield
- Extreme values cause arithmetic overflow on large yield amounts
- Bond terms accept inverted min/max and extreme durations
- Swap fees have no Balancer-compatible range check

While access control limits who can set fees, a misconfigured fee (e.g., entering `1e18` intending 1% but getting 100%) could drain vault yield. Adding upper bounds validation in the setter functions provides defense-in-depth.

**Suggested bounds:**
- Usage fee: `require(fee <= 1e18, "Fee exceeds 100%")` (1e18 WAD = 100%)
- Swap fee: Balancer V3 compatible range check
- Bond terms: `require(minBondDuration <= maxBondDuration)`

The existing "accepts" tests in `VaultFeeOracle_Bounds.t.sol` should be converted to "reverts" tests when bounds are implemented.

(Created from code review of IDXEX-036)

## Dependencies

- IDXEX-036: Add Fee Oracle Authorization and Bounds Tests (parent task, complete)

## User Stories

### US-IDXEX-066.1: Add bounds validation to fee setters

As a protocol operator, I want fee parameters to be validated on-chain so that accidental misconfiguration cannot drain vault yield.

**Acceptance Criteria:**
- [ ] `setDefaultUsageFee` reverts for values > 1e18 (100% WAD)
- [ ] `setDefaultUsageFeeOfTypeId` reverts for values > 1e18
- [ ] `setUsageFeeOfVault` reverts for values > 1e18
- [ ] `setDefaultDexSwapFee` reverts for values outside Balancer-compatible range (or reasonable bound)
- [ ] Bond terms setters validate `minDuration <= maxDuration`
- [ ] Existing valid-range tests still pass
- [ ] "Accepts above 100%" tests converted to "reverts above 100%"
- [ ] Build succeeds

## Files to Create/Modify

**Modified Files:**
- `contracts/oracles/fee/VaultFeeOracleManagerFacet.sol`
- `contracts/oracles/fee/VaultFeeOracleRepo.sol`
- `test/foundry/spec/oracles/fee/VaultFeeOracle_Bounds.t.sol` (convert accepts -> reverts)

## Inventory Check

Before starting, verify:
- [ ] IDXEX-036 is complete
- [ ] Fee setter functions exist in VaultFeeOracleManagerFacet
- [ ] Current bounds tests document the "no validation" behavior

## Completion Criteria

- [ ] All acceptance criteria met
- [ ] Tests pass
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
