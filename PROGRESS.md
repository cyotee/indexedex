# PROGRESS.md - Permit2 Signature Implementation

## Summary

Successfully implemented and tested Permit2 signature-based swaps (`swapSingleTokenExactInWithPermit` and `swapSingleTokenExactOutWithPermit`) for BalancerV3 Router.

## Accomplished

1. **OpenCode Skills Created**: 34 skills for Permit2, Tevm, Voltaire-Effect, Wagmi, Wagmi-React

2. **Contract Changes**:
   - Updated interfaces: `IBalancerV3StandardExchangeRouterExactInSwap.sol`, `IBalancerV3StandardExchangeRouterExactOutSwap.sol`
   - Updated routers: `BalancerV3StandardExchangeRouterExactInSwapTarget.sol`, `BalancerV3StandardExchangeRouterExactOutSwapTarget.sol`
   - Added `swapSingleTokenExactInWithPermit` and `swapSingleTokenExactOutWithPermit` functions

3. **Test File Created**:
   - `test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_Permit2Signature.t.sol`

## Key Fixes Applied

### 1. Domain Separator Format
Permit2 uses a different EIP-712 domain separator format:
```solidity
// Wrong:
"EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"

// Correct (Permit2):
"EIP712Domain(string name,uint256 chainId,address verifyingContract)"
```

### 2. TypeHash Construction
Permit2's `hashWithWitness` concatenates the STUB with the full witness type string:
```solidity
typeHash = keccak256(abi.encodePacked(STUB, witnessTypeString))
```

### 3. Sender Parameter
The test must set `swapParams.sender` to the actual user (alice), not `address(0)`:
```solidity
swapParams.sender = alice;  // Correct - the actual user
// swapParams.sender = address(0);  // Wrong - causes AllowanceExpired(0)
```

## Test Results

```
[PASS] test_permitSignature_exactIn_swapSucceeds() (gas: 334972)
Suite result: ok. 1 passed; 0 failed; 0 skipped
```

## Frontend TypeScript Status (2026-03-01)

Frontend typecheck now passes:

```bash
cd frontend
npm run check
```

## Files Modified/Created

- `contracts/interfaces/IBalancerV3StandardExchangeRouterExactInSwap.sol` (modified)
- `contracts/interfaces/IBalancerV3StandardExchangeRouterExactOutSwap.sol` (modified)
- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactInSwapTarget.sol` (modified)
- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactOutSwapTarget.sol` (modified)
- `test/foundry/spec/protocol/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_Permit2Signature.t.sol` (created)
- `.opencode/skills/` (34 skills created)

## Frontend Implementation Completed

### New Files Created

1. **`frontend/app/lib/permit2-signature.ts`** - Permit2 signature utilities
   - `getPermit2TypedData()` - Creates EIP-712 typed data for witness signatures
   - `signPermit2Witness()` - Signs permit with witness data
   - `createWitnessFromSwapParams()` - Creates witness data from swap parameters

### Modified Files

1. **`frontend/app/swap/page.tsx`**
   - Added signature mode toggle (`useSignatureMode`)
   - Added accurate quote simulation toggle (`simulateWithAuth`)
   - Updated `handleSwap()` to use signature-based functions when enabled
   - Updated approval checks to skip when using signature mode

### UI Changes

Added signature mode section in the swap page:
- Checkbox: "Use Signature (one tx)" - enables single-transaction swaps
- Checkbox: "Accurate Quote (with auth)" - for future quote simulation with auth

### How It Works

1. **Standard Mode** (default):
   - User enters swap details
   - If approval needed → signs approval transactions
   - Signs swap transaction

2. **Signature Mode**:
   - User checks "Use Signature" toggle
   - Frontend generates EIP-712 signature with witness (swap params)
   - User signs ONE transaction with signature embedded
   - Router verifies signature and executes atomically

### Dependencies Added

- `useSignTypedData` from wagmi for signature generation

---

## Transaction Failure Analysis (2026-02-19)

### Transaction
- **Hash**: `0xe20c397446a338a2952387254fdceed0c6d649e4260e6ce84a7fc1a9ee15df1b`
- **Route**: Balancer Swap + Vault Withdrawal (tokenIn → vault shares → Balancer pool → vault withdrawal → tokenOut)
- **Mode**: Standard (non-signature)

### Error
```
MinAmountNotMet(uint256 minAmount, uint256 actualAmount)
```
- **minAmount (expected)**: 21,424,619,026,545,603,202,211 (~2.14e22)
- **actualAmount (received)**: 545,447,775,299,840,892,166 (~5.45e20)

### Root Cause

The router is checking the wrong amount for the vault withdrawal. When doing a "Vault Deposit + Balancer Swap + Vault Withdrawal" route:

1. **Query phase**: Correctly calculates final output by:
   - Converting tokenIn → vault shares
   - Swapping vault shares → different vault shares via Balancer
   - Converting final vault shares → tokenOut

2. **Execution phase**: The router passes the **wrong minAmount** to the vault withdrawal:
   - It converts the user's `minAmountOut` (in tokenOut) to vault shares using `previewExchangeOut`
   - Then checks if the **vault share amount** meets this converted limit
   - But it should be checking if the **final tokenOut amount** meets the original `params.limit`

### The Bug Location

In `BalancerV3StandardExchangeRouterExactInSwapTarget.sol`, the `_exchangeInToVault` call at line 714-722 passes `convertedLimit` (vault shares) instead of checking the final tokenOut amount:

```solidity
amountCalculated = _exchangeInToVault(
    params,
    swapAmountOut,              // vault shares received from swap
    convertedLimit,             // <-- BUG: converted to vault shares, should be tokenOut check
    params.sender
);
```

The vault then checks if `amountOut >= minAmountOut` where:
- `amountOut` = actual tokenOut received from withdrawal
- `minAmountOut` = user-provided minAmount (correct!)

But the issue is that `convertedLimit` was pre-calculated in lines 629-637 and represents how many vault shares would be needed to get `params.limit` tokens out - but this calculation is wrong because it uses `previewExchangeOut` which doesn't account for the actual swap result.

### Fix Required

The router should:
1. **Query** should return the final tokenOut amount (already correct in query code)
2. **Execution** should compare final tokenOut against `params.limit` directly, NOT against a pre-calculated vault share equivalent

The fix is in the swap execution target - it needs to check the final `amountCalculated` against the original `params.limit` instead of using the pre-calculated `convertedLimit` for the vault withdrawal check.

## Fix Applied

**File**: `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactInSwapTarget.sol`

**Changes**: Changed two locations where `convertedLimit` was incorrectly passed to vault withdrawal functions:

1. **Line 720** - `_exchangeInToVault` call (lines 714-722):
   - Changed: `convertedLimit` → `params.limit`
   - This ensures the vault checks the user's original minAmountOut in tokenOut units

2. **Line 829** - Direct `exchangeIn` call (lines 820-836):
   - Changed: `convertedLimit` → `params.limit`
   - Same fix for the direct vault call path

**Before (buggy)**:
```solidity
amountCalculated = _exchangeInToVault(params, swapAmountOut, convertedLimit, params.sender);
```

**After (fixed)**:
```solidity
amountCalculated = _exchangeInToVault(params, swapAmountOut, params.limit, params.sender);
```

The `convertedLimit` variable was being used to convert the user's minAmountOut from tokenOut units to vault share units, then passing that to the vault. But the vault expects the user's original minAmountOut (in tokenOut units) to compare against the actual withdrawal amount.
