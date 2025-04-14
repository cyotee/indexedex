# Negative Test Coverage Report

This report tracks *missing* and *partial* negative test coverage for the `feature/exactout-variants` worktree.

Goal: prove security properties with explicit revert selectors / accounting assertions (not just `vm.expectRevert()`), with a focus on:
- Owner-only mint/create functions (Protocol-only entry points)
- Donation/skim/direct-transfer scenarios (ERC4626 reserve accounting and rounding safety)

## Key Semantics (Ground Truth From Code)

### ERC4626 reserve deposit accounting

Crane's `ERC4626Service._secureReserveDeposit(...)` (imported via `@crane/contracts/tokens/ERC4626/ERC4626Service.sol`) treats deposits as:
- `actualIn = reserveAsset.balanceOf(vault) - lastTotalAssets`
- If `actualIn != amountTokenToDeposit`, it pulls `amountTokenToDeposit` from `msg.sender` (Permit2 if needed), then re-checks.
- If still mismatched, it reverts with `IERC4626Errors.ERC4626TransferNotReceived(expected, actual)`.
- It then snapshots `lastTotalAssets = currentBalance`.

Implication: a direct-transfer donation **changes** `balanceOf(vault)` without updating `lastTotalAssets`, so the next call that uses `_secureReserveDeposit` may:
- consume the donation as part of `actualIn` (if `actualIn` happens to equal the declared `amountTokenToDeposit`), or
- revert because `actualIn` no longer equals `amountTokenToDeposit`.

This needs explicit negative tests.

## Checklist: Missing / Partial Negative Tests

Each item includes: what to test, where to add it, and what to assert.

### A) Owner-Only Access Control (Protocol Entry Points)

#### A1) RICHIR: only owner can mint from NFT sale
- Target: `contracts/vaults/protocol/RICHIRTarget.sol::mintFromNFTSale(uint256,address)` (has `onlyOwner`)
- Add test: `test/foundry/spec/vaults/protocol/RICHIRPermissions_Negative.t.sol`
- Assertions:
  - `vm.prank(attacker); vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, attacker)); richir.mintFromNFTSale(1, attacker);`
  - Also assert `lpShares==0` reverts with `IProtocolDETFErrors.ZeroAmount()` when called by owner.

Status: done (test added).

#### A2) ProtocolNFTVault: only owner can create/manage protocol NFT state
- Target: `contracts/vaults/protocol/ProtocolNFTVaultTarget.sol`
- Functions:
  - `createPosition(uint256,uint256,address)`
  - `initializeProtocolNFT()`
  - `addToProtocolNFT(uint256,uint256)`
  - `sellPositionToProtocol(uint256,address,address)`
  - `markProtocolNFTSold(uint256)`
- Add test: `test/foundry/spec/vaults/protocol/ProtocolNFTVaultPermissions_Negative.t.sol`
- Assertions:
  - For each `onlyOwner` function: `vm.prank(attacker); vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, attacker)); <call>`
  - Additional negative assertions already implied by code:
    - `addToProtocolNFT` reverts `ProtocolNFTRestricted(tokenId)` when tokenId != protocol id
    - `sellPositionToProtocol` reverts `NotBondHolder(owner,seller)` when seller mismatch
    - `markProtocolNFTSold` reverts `ProtocolNFTRestricted(tokenId)` when tokenId != protocol id

Status: done for `onlyOwner` gating.

Note: `test/foundry/spec/vaults/protocol/ProtocolNFTVault.t.sol` currently contains only pure “math/spec” assertions and does not exercise on-chain ownership gates.

### B) Donation / Skim / Direct-Transfer (ERC4626 Reserve Sync Safety)

#### B1) Route4 VaultDeposit (Aerodrome): direct-transfer causes strict reserve mismatch revert
- Context: `test/foundry/spec/protocol/dexes/aerodrome/v1/AerodromeStandardExchangeIn_VaultDeposit.t.sol` already tests `pretransferred=true` happy-path.
- Add tests to the same file:

1) `test_Route4VaultDeposit_reverts_whenDonationMakesActualInMismatch()`
- Arrange:
  - Choose a vault/pool config, compute `lpAmount`.
  - Direct-transfer *donation* `donation = lpAmount / 2` into `vault`.
  - Then call `exchangeIn(... pretransferred=false ...)` for `lpAmount`.
- Assert:
  - Expect revert selector `IERC4626Errors.ERC4626TransferNotReceived.selector` with `expected=lpAmount` and `actual != expected`.
  - (The exact `actual` depends on whether the vault pulls `lpAmount` before re-check; but the revert payload includes both numbers, so assert full encoding if stable, else assert selector only.)

2) `test_Route4VaultDeposit_reverts_whenPretransferredTrueButDonationPlusAmountInMismatch()`
- Arrange:
  - Direct-transfer `donation` and `lpAmount` (or donate a different amount than declared).
  - Call `exchangeIn(... pretransferred=true ...)` with `amountIn=lpAmount`.
- Assert:
  - Same `ERC4626TransferNotReceived` revert.

Status: done (tests added).

Rationale: This proves the vault is strict about exact-in accounting and cannot be tricked via “dust donations” into mis-accounting.

#### B2) Route4 VaultDeposit (Uniswap V2): same donation mismatch behavior
- Target test file: `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchangeIn_VaultDeposit.t.sol`
- Coverage:
  - Donation/direct-transfer mismatch reverts with `ERC4626TransferNotReceived`
  - `previewExchangeIn` matches `exchangeIn` for LP -> vault shares deposits

Status: done (tests added).

#### B3) Positive safety property: donation does not let attacker profit (if the design intends to accept donations)

Important: Based on `ERC4626Service._secureReserveDeposit`, the system is *strict* and tends to revert on donation-induced mismatches rather than accepting them.

If the intended design is “donations should benefit next depositor”, then the implementation likely needs a `sync()` or a different accounting scheme; until then, the correct negative tests are the *revert* tests (B1/B2).

Status: pending design decision; do not write profit-extraction tests until we agree whether donation should revert or be accepted.

### C) pretransferred misuse cases (Exact-in)

#### C1) pretransferred=true is not a strict “must already be sent” flag

Because `ERC4626Service._secureReserveDeposit` will attempt to pull from `msg.sender` whenever `balanceOf(vault) - lastTotalAssets != amountIn`, a call with `pretransferred=true` can still succeed by pulling funds (if approvals/Permit2 are configured).

What to test instead:
- Donation mismatch reverts (Section B) with explicit `ERC4626TransferNotReceived` payloads.
- (Optional) If the intended UX is “pretransferred=true must never pull,” then the implementation must change; tests would then assert *no balance change* for the caller even when the vault is short.

### D) Existing coverage observed (for reference)

- Owner gating revert pattern exists in `test/foundry/spec/protocol/vaults/seigniorage/SeigniorageNFTVault.t.sol` using `IMultiStepOwnable.NotOwner.selector`.
- Exact-out pretransferred refund semantics already covered in `test/foundry/spec/vaults/protocol/ProtocolDETFExchangeOut.t.sol`.

## Proposed Implementation Order

1) Add access-control negative tests for `onlyOwner` functions (A1, A2) using explicit `NotOwner` selector.
2) Add donation mismatch revert tests for Aerodrome Route4 deposit (B1 + C1) using `ERC4626TransferNotReceived` selector.
3) Mirror the same donation tests for Uniswap V2 deposit routes once the matching test harness file is identified.
