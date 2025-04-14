# Progress Log: IDXEX-021

## Current Checkpoint

**Last checkpoint:** Task Complete
**Build status:** :white_check_mark: Compiles successfully
**Test status:** :white_check_mark: All 16 tests pass

---

## Session Log

### 2026-01-28 - Task Created

- Task designed during IDXEX-001 Protocol DETF review (Section 5.11)
- Currently requires 2 calls: bondWithWeth() + sellNFT()
- Single-call wrapper should combine atomically
- Ready for agent assignment via `/backlog:launch`

### 2026-01-31 - In-Session Work Started

- Task started via /backlog:work
- Working directly in current session (no worktree)
- Ready to begin implementation

### 2026-01-31 - Implementation Complete

**Files Modified:**

1. `contracts/vaults/protocol/ProtocolDETFBondingTarget.sol`
   - Added `wethToRichir()` function (lines 742-797)
   - Added `previewWethToRichir()` function (lines 799-856)
   - Added interface declarations to `IProtocolDETFBonding`

2. `contracts/interfaces/IProtocolDETF.sol`
   - Added `wethToRichir()` and `previewWethToRichir()` to main interface

3. `test/foundry/spec/vaults/protocol/ProtocolDETF_Routes.t.sol`
   - Added `test_route_weth_to_richir_single_call()` - Basic single-call conversion
   - Added `test_route_weth_to_richir_single_call_slippage_protection()` - Verify slippage reverts
   - Added `test_route_weth_to_richir_single_call_deadline_protection()` - Verify deadline reverts
   - Added `test_route_weth_to_richir_single_call_vs_two_step()` - Compare single vs two-step approach

**Implementation Details:**

- `wethToRichir()` atomically:
  1. Transfers WETH from user
  2. Deposits WETH into CHIR/WETH vault → vault shares
  3. Adds vault shares to 80/20 reserve pool → BPT
  4. Adds BPT to protocol-owned NFT (no user NFT created)
  5. Mints RICHIR to recipient (1:1 with BPT)
  6. Validates slippage and deadline

- `previewWethToRichir()` calculates expected output using:
  1. `chirWethVault.previewExchangeIn()` for vault shares
  2. `BalancerV38020WeightedPoolMath.calcBptOutGivenSingleIn()` for BPT
  3. Simulates post-mint rebasing state for accurate RICHIR output

**Test Results:**

```
Ran 16 tests for ProtocolDETF_Routes.t.sol:ProtocolDETFRoutesIntegrationTest
[PASS] test_route_weth_to_richir_single_call() (gas: 1835215)
[PASS] test_route_weth_to_richir_single_call_deadline_protection() (gas: 43143)
[PASS] test_route_weth_to_richir_single_call_slippage_protection() (gas: 1664482)
[PASS] test_route_weth_to_richir_single_call_vs_two_step() (gas: 2811214)
Suite result: ok. 16 passed; 0 failed; 0 skipped
```

**Acceptance Criteria Status:**

- [x] Single function call converts WETH to RICHIR (`wethToRichir()`)
- [x] No intermediate Bond NFT created for user (BPT goes directly to protocol NFT)
- [x] BPT goes directly to protocol-owned NFT (`addToProtocolNFT()`)
- [x] RICHIR minted directly to recipient (`mintFromNFTSale()`)
- [x] Deadline protection (`block.timestamp > deadline` check)
- [x] Minimum output protection (`richirOut < minRichirOut` check)
- [x] Preview function (`previewWethToRichir()`) returns expected RICHIR
- [x] Tests pass
- [x] Build succeeds

**Task Status:** Ready for completion via `/backlog:complete IDXEX-021`
