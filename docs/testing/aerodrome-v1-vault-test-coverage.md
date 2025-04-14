# Aerodrome V1 Standard Exchange Vault Test Coverage Report

**Date**: 2025-12-31
**Status**: All Tests Passing (119/119)
**Test Location**: `test/foundry/spec/protocol/dexes/aerodrome/v1/`

## Summary

The Aerodrome Standard Exchange vault implementation has comprehensive test coverage across all 7 exchange routes. All 119 tests are passing after bug fixes completed on 2025-12-31.

### Test Results by Route

| Route | Description | Tests | Status |
|-------|-------------|-------|--------|
| 1 | Swap (Token A ↔ Token B) | 24 | PASS |
| 2 | ZapIn (Token → LP) | 17 | PASS |
| 3 | ZapOut (LP → Token) | 17 | PASS |
| 4 | VaultDeposit (LP → Vault Shares) | 12 | PASS |
| 5 | VaultWithdraw (Vault Shares → LP) | 12 | PASS |
| 6 | ZapInDeposit (Token → Vault Shares) | 14 | PASS |
| 7 | ZapOutWithdraw (Vault Shares → Token) | 14 | PASS |
| Setup | Debug/Setup Tests | 9 | PASS |

## Route Details

### Route 1: Swap (24 tests)
**File**: `AerodromeStandardExchangeIn_Swap.t.sol`

Pass-through swap between pool constituent tokens.

- **Execution vs Preview**: 6 tests (balanced/unbalanced/extreme, A→B and B→A)
- **Preview vs Math**: 6 tests (verify preview matches pool.getAmountOut)
- **Balance Changes**: 4 tests
- **Fuzz Tests**: 4 tests
- **Slippage Protection**: 2 tests (exact minimum, revert when too high)
- **Pretransferred**: 2 tests (true/false)

### Route 2: ZapIn - Token to LP (17 tests)
**File**: `AerodromeStandardExchangeIn_ZapIn.t.sol`

Swaps half of input token for opposing token, then adds liquidity.

- **Execution vs Preview**: 6 tests
- **Balance Changes**: 3 tests
- **Fuzz Tests**: 4 tests
- **Reserve Impact**: 1 test
- **Slippage Protection**: 2 tests
- **Pretransferred**: 1 test

### Route 3: ZapOut - LP to Token (17 tests)
**File**: `AerodromeStandardExchangeIn_ZapOut.t.sol`

Removes liquidity and swaps opposing token to target token.

- **Execution vs Preview**: 6 tests
- **Balance Changes**: 3 tests
- **Fuzz Tests**: 4 tests
- **Reserve Impact**: 1 test
- **Slippage Protection**: 2 tests
- **Pretransferred**: 1 test

### Route 4: VaultDeposit - LP to Vault Shares (12 tests)
**File**: `AerodromeStandardExchangeIn_VaultDeposit.t.sol`

Deposits LP tokens into vault and mints vault shares.

- **Execution vs Preview**: 3 tests
- **Balance Changes**: 2 tests
- **Fuzz Tests**: 2 tests
- **First/Second Deposit**: 2 tests
- **Slippage Protection**: 2 tests
- **Pretransferred**: 1 test

### Route 5: VaultWithdraw - Vault Shares to LP (12 tests)
**File**: `AerodromeStandardExchangeIn_VaultWithdraw.t.sol`

Burns vault shares and returns LP tokens.

- **Execution vs Preview**: 3 tests
- **Balance Changes**: 2 tests
- **Fuzz Tests**: 2 tests
- **Full Withdrawal**: 1 test
- **Deposit/Withdraw Cycle**: 1 test
- **Slippage Protection**: 2 tests
- **Pretransferred**: 1 test

### Route 6: ZapInDeposit - Token to Vault Shares (14 tests)
**File**: `AerodromeStandardExchangeIn_ZapInDeposit.t.sol`

Single-token deposit: ZapIn + VaultDeposit in one transaction.

- **Execution vs Preview**: 5 tests
- **Balance Changes**: 2 tests
- **Fuzz Tests**: 3 tests
- **LP Verification**: 1 test (verify LP stays in vault)
- **Slippage Protection**: 2 tests
- **Pretransferred**: 1 test

### Route 7: ZapOutWithdraw - Vault Shares to Token (14 tests)
**File**: `AerodromeStandardExchangeIn_ZapOutWithdraw.t.sol`

Single-token withdrawal: VaultWithdraw + ZapOut in one transaction.

- **Execution vs Preview**: 4 tests
- **Balance Changes**: 2 tests
- **Fuzz Tests**: 3 tests
- **Full Withdrawal**: 1 test
- **Full Cycle**: 1 test
- **Slippage Protection**: 2 tests
- **Pretransferred**: 1 test

## Pool Configurations Tested

All routes are tested against multiple pool configurations:

| Config | Token A Reserve | Token B Reserve | Notes |
|--------|----------------|-----------------|-------|
| Balanced | 10,000 | 10,000 | 1:1 ratio |
| Unbalanced | 10,000 | 5,000 | 2:1 ratio |
| Extreme | 10,000 | 100 | 100:1 ratio |

## Test Categories

### 1. Execution vs Preview (execVsPreview)
Verifies that `previewExchangeIn()` returns the exact amount that `exchangeIn()` actually transfers.

### 2. Balance Changes
Verifies correct token movements between sender, vault, pool, and recipient.

### 3. Fuzz Tests
Property-based tests with random inputs to catch edge cases.

### 4. Slippage Protection
- **exactMinimum**: Succeeds when minAmountOut equals actual output
- **reverts_whenMinimumTooHigh**: Reverts when minAmountOut exceeds output

### 5. Pretransferred Mode
Tests the `pretransferred` flag for pre-deposited tokens.

### 6. Reserve/State Impact
Verifies correct pool reserve changes after operations.

## Bugs Fixed (2025-12-31)

### 1. Missing Slippage Protection (Routes 2-7)
**Issue**: `minAmountOut` parameter was not being checked
**Fix**: Added `MinAmountNotMet` error checks to all routes
**Location**: `AerodromeStandardExchangeInTarget.sol`

### 2. ZapOutWithdraw Preview Reserve Sorting
**Issue**: Preview sorted reserves by `address(tokenIn)` which was the vault address
**Fix**: Changed to sort by `address(tokenOut)` (the actual output token)
**Location**: `AerodromeStandardExchangeInTarget.sol:273-280`

### 3. ZapIn Fee Denominator Mismatch
**Issue**: Execution used `FEE_DENOMINATOR=100000` but Aerodrome uses `10000`
**Fix**: Added `AERO_FEE_DENOM=10000` and used 4-arg `_swapDepositSaleAmt`
**Location**: `lib/daosys/lib/crane/contracts/protocols/dexes/aerodrome/v1/services/AerodromService.sol:111-125`

### 4. Test Assertion Fix (Route 2 Reserve Impact)
**Issue**: Test expected both reserves to increase in ZapIn
**Fix**: For single-token ZapIn, only input token reserve increases; opposing stays ~same
**Location**: `test/.../AerodromeStandardExchangeIn_ZapIn.t.sol:277-283`

## Coverage Gaps / Future Work

### Not Applicable
1. **Stable pools** - Not used in our vaults. All implementations use volatile pools only (`stable=false`).

### Future Work (Low Priority)
These items are documented for potential future enhancement but are not blocking:

- [ ] **Fee-on-transfer tokens** - No tests with deflationary tokens
- [ ] **Multiple consecutive operations** - Limited state persistence tests
- [ ] **Gas optimization benchmarks** - No gas regression tests
- [ ] **Permit2 integration** - Permit2 setup exists but not exercised in routes
- [ ] **Fee accrual tests** - Trading activity → fee claims flow
- [ ] **Multi-user scenario tests** - Concurrent user interactions
- [ ] **Gas snapshot comparisons** - Track gas usage over time

## Running the Tests

```bash
# Run all Aerodrome tests
forge test --match-path "test/foundry/spec/protocol/dexes/aerodrome/*"

# Run specific route tests
forge test --match-contract AerodromeStandardExchangeIn_Swap_Test
forge test --match-contract AerodromeStandardExchangeIn_ZapIn_Test
# etc.

# Run with verbosity
forge test --match-path "test/foundry/spec/protocol/dexes/aerodrome/*" -vvv
```

## Test Infrastructure

### Base Classes
- `TestBase_AerodromeStandardExchange` - Core test setup
- `TestBase_AerodromeStandardExchange_MultiPool` - Multi-pool configuration

### Key Dependencies
- Crane framework (`lib/daosys/lib/crane/`)
- Aerodrome pool stubs
- ERC20PermitMintableStub for test tokens
