# Progress Log: IDXEX-085

## Current Checkpoint

**Last checkpoint:** Approach 3 implemented; fee oracle access fixed (use `ProtocolDETFRepo._feeOracle()`); merged to `main`
**Current issue:** Residual preview buffers remain; CRANE/IDXEX-085 requires exact (no scalar buffers)
**Next step:** Remove *all* preview buffers by switching Balancer preview math to Vault queries (exact execution math), then delete buffer constants/usages
**Build status:** PASS (as of last run in this log)
**Test status:** PASS (as of last run in this log)

Note: added a tiny epsilon in the debug-only intermediate test for BPT-out due to Balancer rounding (few wei).

### 2026-02-11 - Verification

- Re-ran `forge test --match-path test/foundry/spec/vaults/protocol/ProtocolDETF_Routes.t.sol` -> PASS (43/43)
- Re-ran `forge test --match-test test_exchangeIn_rich_to_richir_preview` -> PASS
- Re-ran `forge test` -> PASS (all suites; output truncated but no failures)

### 2026-02-12 - Follow-up: CRANE/IDXEX-085 Compliance Audit

- Found remaining scalar buffers that violate the objective (“remove buffers like that and do exact”):
  - `contracts/vaults/protocol/ProtocolDETFExchangeOutTarget.sol`: `_previewRichToRichirExact()` adds `+ ((richIn_ * 2) / 10_000) + 1` (2 bps + 1 wei), plus an unused `PREVIEW_EXACT_OUT_INPUT_BUFFER_BPS` constant.
  - `contracts/vaults/protocol/ProtocolDETFExchangeInQueryTarget.sol`: `PREVIEW_OUT_BUFFER_BPS = 36` applied via `_applyPreviewOutBuffer()`.
  - `contracts/vaults/protocol/ProtocolDETFPreviewHelpers.sol`: `PREVIEW_OUT_BUFFER_BPS = 36` applied to the computed WETH value.
  - `contracts/vaults/protocol/ProtocolDETFBondingQueryTarget.sol`: defines `BONDING_PREVIEW_OUT_BUFFER_BPS = 36` (matches ExchangeInQueryTarget’s buffer intent).

- Plan to remove buffers safely:
  - Replace Balancer preview calculations (BPT-out from unbalanced add + proportional exit valuation) with Balancer Vault query functions so the preview uses the *exact same math + rounding* as execution.
  - After previews are computed via Balancer queries, delete the `*_BUFFER_BPS` constants and remove `_applyPreviewOutBuffer()` and the exact-out “2 bps + 1 wei” adjustment.

---

## Key Finding: Root Cause Analysis

The TASK.md states the divergence comes from Aerodrome fee compounding changing pool reserves. Through debugging, I discovered this is only a **tiny fraction** of the actual divergence:

### Measured Impact Breakdown

| Source | Measured Impact | Notes |
|--------|----------------|-------|
| Compound effect on LP minting | ~0.005% | lpPreCompound=1429781e18, lpPostCompound=1429710e18 |
| LP math approximation vs router | ~1.08% | `_quoteSwapDepositWithFee` vs `_swapDepositVolatile` |
| **Total divergence** | **~1.08%** | Preview underestimates vs execution |

### The Real Divergence Source

**Preview path** (vault's `previewExchangeIn` for ZapIn Vault Deposit, line 154-174 of AerodromeStandardExchangeInTarget.sol):
1. `lpFromZapIn = _quoteSwapDepositWithFee(amountIn, lpTotalSupply, reserveIn, reserveOut, fee)` - **pure math approximation**
2. `state = _calcPreviewState(...)` - adjusts vaultLpReserve for compound
3. `shares = _convertToSharesDown(lpFromZapIn, state.vaultLpReserve, state.vaultTotalShares, ...)`

**Execution path** (line 385-416):
1. `_claimAndCompoundFees(...)` - actually compounds
2. `lpMinted = AerodromeService._swapDepositVolatile(...)` - **actual on-chain router swap+deposit**
3. `shares = _convertToSharesDown(lpMinted, vs.vaultLpReserve, vs.vaultTotalShares, ...)`

The `_quoteSwapDepositWithFee` pure math systematically **underestimates LP** compared to the actual Aerodrome router execution. The vault's `_calcPreviewState()` already handles compound for share conversion. The compound effect on LP reserves is negligible (~0.005%).

### Aerodrome Pool Swap Fee Mechanics (Confirmed from Pool.sol Source)

- In `Pool.swap()` (line 377-379), fees are physically transferred OUT to `poolFees` contract via `_update0`/`_update1`
- After swap: `new_reserve_in = old_reserve_in + amountInAfterFee` (fee is NOT in reserves)
- This matches the preview's `newReserveIn = reserveIn + amountInWithFee`
- So the swap math and reserve tracking ARE the same between preview and execution
- The divergence comes from how LP is calculated from the balanced deposit, not from swap math

### Aerodrome Router Execution Flow (from AerodromeService.sol + Router.sol + Pool.sol)

1. `_swapDepositVolatile()` calculates `saleAmt` via `_swapDepositSaleAmt` (same formula as preview)
2. Actual swap via router → pool.swap() → real `swapAmountOut`
3. `router.addLiquidity()` → `_addLiquidity()` adjusts amounts for optimality → transfers tokens → `pool.mint()`
4. `pool.mint()` line 321: `liquidity = min((amount0 * totalSupply) / reserve0, (amount1 * totalSupply) / reserve1)`

### Why the 0.15% Discount "Worked" (IDXEX-072)

The old 0.15% discount was NOT compensating for compound (which is ~0.005%). It was a fudge factor compensating for the LP math underestimation. Without the discount, preview OVERESTIMATES vault shares (per IDXEX-072 findings). With my code removing the discount, preview drops below execution.

### Compound Simulation Debug Output (RICH/CHIR Vault)

```
_previewClaimableFeesExternal:
  pool: 0x88d58872...
  claimable0 (direct): 0, claimable1 (direct): 0
  supplied (balanceOf): 15867991941653560296749
  index0: 954944349547857, supplyIndex0: differs
  added0 from index: 15153049243352995582  (~15.15 RICH tokens)
  final claimable0: 15153049243352995582, final claimable1: 0

_previewVaultSharesPostCompound:
  vault: 0xC38158...  (richChirVault)
  amountIn: 5000e18, vaultShares (from vault preview): 1429387946120365785722
  sim.compoundLP: 4368831031424187805  (~4.37 LP from compound)
  lpPreCompound: 1429781096664144628011, lpPostCompound: 1429710126070212733320
  adjusted vaultShares: 1429316995041398567603  (only ~0.005% reduction)
```

### Note on Excess Tokens

The vault's internal `_previewCompoundState()` also includes `AerodromeStandardExchangeRepo._excessToken0()` and `_excessToken1()`. My external simulation does NOT include these (internal vault storage). Typically dust < 1000 wei.

---

## Implementation Status

### Three Approaches Tried

**Approach 1 (Full Reconstruction with _quoteSwapDepositWithFee):** Calculate vault shares from scratch using post-compound state, but still using `_quoteSwapDepositWithFee` for LP estimation. Same 1.08% error because `_quoteSwapDepositWithFee` is the bottleneck.

**Approach 2 (LP Ratio Adjustment):** Use `vault.previewExchangeIn()` as base, scale by `lpPostCompound / lpPreCompound` ratio. Compound ratio is ~0.99995 (barely changes anything). Same 1.08% error.

**Approach 3 (Current - pool.getAmountOut + mint formula):** Full reconstruction using:
- `pool.getAmountOut()` for accurate swap output (matches router's actual swap)
- `ConstProdUtils._swapDepositSaleAmt()` for optimal split (same as router)
- Pool's actual `mint()` formula: `min((amountA * totalSupply) / reserveA, (amountB * totalSupply) / reserveB)`
- Router's `_addLiquidity()` optimal amount adjustment
- Compound simulation for correct post-compound pool state
- `ProtocolDETFRepo._feeOracle()` for protocol fee on compound LP
- `BetterMath._convertToSharesDown()` for LP → vault share conversion

### Current Issue with Approach 3

First attempt used `VaultFeeOracleQueryAwareRepo._feeOracle()` which reads from Diamond storage. But ProtocolDETF is a DIFFERENT Diamond than the vault - the fee oracle is not stored there. Error: "call to non-contract address 0x0000000000000000000000000000000000000000".

**Fix applied:** Changed to `ProtocolDETFRepo._feeOracle().usageFeeOfVault(address(vault_))` which reads from the ProtocolDETF's own storage. Also removed the unused `VaultFeeOracleQueryAwareRepo` import. Also removed all debug `console.log` statements and the `forge-std/console.sol` import.

**Status:** Fix verified (build + targeted suites + full `forge test`).

### Files Modified

1. `contracts/vaults/protocol/ProtocolDETFCommon.sol` - Compound sim infrastructure + Approach 3 implementation
2. `contracts/vaults/protocol/ProtocolDETFExchangeOutTarget.sol` - 4 changes (2 discounts replaced, 2 buffers removed)
3. `contracts/vaults/protocol/ProtocolDETFExchangeInTarget.sol` - 2 changes (1 discount replaced, 1 added to _previewWethToRichir)
4. `contracts/vaults/protocol/ProtocolDETFBondingTarget.sol` - 2 changes (2 discounts replaced)

### Compound Simulation Infrastructure (ProtocolDETFCommon.sol)

- `AeroCompoundSim` struct (reserve0, reserve1, lpTotalSupply, compoundLP, swapFeePercent, token0)
- `SwapDepositCalcs` struct (stack-too-deep avoidance)
- `_previewVaultSharesPostCompound()` - main entry point (Approach 3)
- `_buildCompoundSim()` - loads pool state and runs simulation
- `_simulateCompound()` - mirrors `_previewCompoundState` from vault
- `_previewClaimableFeesExternal()` - mirrors `_previewClaimableFees` using public pool functions
- `_proportionalDeposit()` - proportional deposit calculation
- `_simulateSwapDeposit()` - single-sided zap simulation (used by compound sim)
- Constants: `AERO_FEE_DENOM = 10000`, `COMPOUND_DUST_THRESHOLD = 1000`

---

## Errors Encountered and Fixed

1. **Stack too deep in `_previewVaultSharesPostCompound`** - Fixed with `AeroCompoundSim` struct + scoped blocks
2. **Stack too deep in `_simulateSwapDeposit`** - Fixed with `SwapDepositCalcs` struct
3. **uint256 vs uint8 type mismatch** for `BetterMath._convertToSharesDown` decimal offset - Fixed by passing literal `0`
4. **`sim` vs `sim_` naming** after refactor to in-place mutation - Fixed all references
5. **Fee oracle returns address(0)** - `VaultFeeOracleQueryAwareRepo._feeOracle()` reads from vault Diamond storage, not ProtocolDETF. Fixed by using `ProtocolDETFRepo._feeOracle()` instead.

---

## Session Log

### 2026-02-08 - Session 2 (Continued)

- Task prepared for agent launch
- PROGRESS.md initialized
- Worktree: feature/IDXEX-085-fix-richir-preview-compound-simulation
- Task record created and status set to `in_progress`

### 2026-02-08 - Status Update

- Task marked `in_progress` to indicate active implementation in worktree

- Implemented Approach 3: full reconstruction with `pool.getAmountOut()` + pool mint formula
- Studied Aerodrome Pool.sol source: confirmed fee mechanics (fees transferred to poolFees, not in reserves)
- Studied Router.sol `addLiquidity` and Pool.sol `mint()` to match execution formula exactly
- Built successfully, but tests failed with "call to non-contract address 0x0" - fee oracle not in ProtocolDETF Diamond
- Fixed fee oracle access: `ProtocolDETFRepo._feeOracle()` instead of `VaultFeeOracleQueryAwareRepo._feeOracle()`
- Removed all debug console.log statements and forge-std/console.sol import
- Needs rebuild and retest

### 2026-02-08 - Session 2 (Start)

- Resumed from compacted context
- Built and ran tests - 3 critical tests still failing with 1.08% divergence
- Added console.log debugging to trace compound simulation
- Discovered compound effect is only ~0.005%, not ~1.08%
- Root cause: `_quoteSwapDepositWithFee` pure math vs actual router `_swapDepositVolatile`
- Updated PROGRESS.md with findings

### 2026-02-08 - Session 1 (Initial Implementation)

- Read TASK.md, CLAUDE.md, AGENTS.md
- Explored codebase: understood compound → zapIn → share conversion pipeline
- Studied `_previewCompoundState()` pattern in AerodromeStandardExchangeCommon
- Implemented compound simulation infrastructure in ProtocolDETFCommon.sol
- Replaced all 5 hardcoded 0.15% discounts
- Added missing compound sim to `_previewWethToRichir`
- Removed both 0.1% binary search buffers
- Build succeeded
- Approach 1 (full reconstruction with _quoteSwapDepositWithFee) failed: 1.08% divergence
- Approach 2 (LP ratio adjustment) failed: same divergence
- Context ran out during debugging

(End of file - total ~190 lines)
