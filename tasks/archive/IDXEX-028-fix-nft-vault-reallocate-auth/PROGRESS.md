# Progress Log: IDXEX-028

## Current Checkpoint

**Last checkpoint:** Implementation complete - all tests pass
**Next step:** Ready for code review
**Build status:** ✅ PASS (Compiler run successful)
**Test status:** ✅ PASS (10/10 tests)

---

## Session Log

### 2026-02-03 - Implementation Complete

#### Summary

Fixed `ProtocolNFTVaultTarget.reallocateProtocolRewards` authorization bug and added comprehensive tests.

#### Changes Made

1. **Fixed authorization check** (`contracts/vaults/protocol/ProtocolNFTVaultTarget.sol:473-477`):
   ```solidity
   // BEFORE:
   if (msg.sender != address(feeOracle)) {

   // AFTER:
   if (msg.sender != address(feeOracle.feeTo())) {
   ```

2. **Registered function in facet** (`contracts/vaults/protocol/ProtocolNFTVaultFacet.sol`):
   - Added `reallocateProtocolRewards.selector` to `facetFuncs()` and `facetMetadata()`
   - Increased array size from 21 to 22

3. **Added authorization tests** (`test/foundry/spec/vaults/protocol/ProtocolNFTVaultPermissions_Negative.t.sol`):
   - `test_reallocateProtocolRewards_revertsForUnauthorizedCaller()` - random address reverts
   - `test_reallocateProtocolRewards_revertsForFeeOracle()` - oracle itself reverts (key test for fix)
   - `test_reallocateProtocolRewards_revertsForOwner()` - owner reverts
   - `test_reallocateProtocolRewards_succeedsForFeeTo()` - FeeCollector succeeds

#### Test Results

```
Ran 10 tests for ProtocolNFTVaultPermissions_Negative_Test
[PASS] test_addToProtocolNFT_revertsForNonOwner()
[PASS] test_createPosition_revertsForNonOwner()
[PASS] test_createPosition_revertsForZeroShares_evenForOwner()
[PASS] test_initializeProtocolNFT_revertsForNonOwner()
[PASS] test_markProtocolNFTSold_revertsForNonOwner()
[PASS] test_reallocateProtocolRewards_revertsForFeeOracle()
[PASS] test_reallocateProtocolRewards_revertsForOwner()
[PASS] test_reallocateProtocolRewards_revertsForUnauthorizedCaller()
[PASS] test_reallocateProtocolRewards_succeedsForFeeTo()
[PASS] test_sellPositionToProtocol_revertsForNonOwner()
Suite result: ok. 10 passed; 0 failed; 0 skipped
```

#### Acceptance Criteria Status

**US-IDXEX-028.1: Align Authorization with Intent**
- [x] Determine intended caller (manager vs fee collector) → **feeTo (FeeCollector)**
- [x] Code check matches intended caller
- [x] Interface documentation matches code (docs were already correct)

**US-IDXEX-028.2: Add Authorization Tests**
- [x] Test: intended caller can call `reallocateProtocolRewards`
- [x] Test: other addresses revert with `NotAuthorized`
- [x] Test: rewards are correctly transferred to recipient

#### Files Modified

| File | Change |
|------|--------|
| `contracts/vaults/protocol/ProtocolNFTVaultTarget.sol` | Fixed auth check |
| `contracts/vaults/protocol/ProtocolNFTVaultFacet.sol` | Registered function selector |
| `test/foundry/spec/vaults/protocol/ProtocolNFTVaultPermissions_Negative.t.sol` | Added 4 new tests |

---

### 2026-02-03 - Implementation Started

#### Design Decision: Code Bug, Not Documentation Bug

**Analysis:**
- Interface NatSpec says: "Can only be called by feeTo address from VaultFeeOracle"
- Code comment says: "Only allow feeTo address from VaultFeeOracle to call this"
- Code check: `if (msg.sender != address(feeOracle))` ← INCORRECT

Both documentation sources agree the intended caller is `feeTo`, but the code checks `feeOracle` instead.

**Evidence:**
1. `feeOracle` is type `IVaultFeeOracleQuery` (the oracle/manager diamond)
2. `feeOracle.feeTo()` returns `IFeeCollectorProxy` (the fee collector contract)
3. The function reallocates protocol rewards - this is a fee management operation that logically belongs to the FeeCollector

**Decision:** Fix the code to check `feeOracle.feeTo()` instead of `feeOracle`.

### 2026-02-02 - Task Created

- Task designed from REVIEW_REPORT.md critical issue #3
- TASK.md populated with requirements
- Ready for agent assignment via /backlog:launch
