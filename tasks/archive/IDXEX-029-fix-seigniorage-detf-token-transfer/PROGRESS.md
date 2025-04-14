# Progress Log: IDXEX-029

## Current Checkpoint

**Last checkpoint:** Implementation complete
**Next step:** Code review
**Build status:** Passing (forge build - compiler run successful)
**Test status:** Passing (5/5 regression tests pass)

---

## Session Log

### 2026-02-06 - Fix Implemented

**Fix applied to:** `contracts/vaults/seigniorage/SeigniorageDETFCommon.sol`

Changes:
1. Added `pretransferred_` early-return: if tokens already transferred, return `amount_` (matching ProtocolDETFCommon pattern)
2. Added `balBefore` snapshot before transfer
3. Changed `actualIn_` from `tokenIn_.balanceOf(address(this))` (full balance) to `balAfter - balBefore` (delta only)

**Regression tests created:** `test/foundry/spec/protocol/vaults/seigniorage/SeigniorageDETF_TokenTransfer.t.sol`

Tests:
- `test_secureTokenTransfer_dustDoesNotInflateCredit` - vault with dust, deposit returns delta only
- `test_secureTokenTransfer_erc20Path_noDust` - standard ERC20 transfer returns correct amount
- `test_secureTokenTransfer_pretransferred_returnsAmount` - pretransferred returns stated amount
- `test_secureTokenTransfer_feeOnTransfer_returnsNetAmount` - FOT token returns net (after tax)
- `test_secureTokenTransfer_feeOnTransfer_withDust` - FOT + dust returns only delta

All 5 tests pass. Build successful.

### 2026-02-02 - Task Created

- Task designed from REVIEW_REPORT.md critical issue #4
- TASK.md populated with requirements
- Ready for agent assignment via /backlog:launch
