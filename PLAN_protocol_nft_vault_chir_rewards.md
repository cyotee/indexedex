# Plan: Refactor Protocol NFT Vault Rewards To CHIR

## Goal

Refactor the Protocol NFT Vault so bond NFT holders accrue and claim CHIR, not RICH, and add full test coverage proving that real seigniorage CHIR minted by Protocol DETF becomes claimable by bond NFT holders.

This plan is intentionally implementation-oriented. A later agent should be able to execute it without reconstructing the earlier investigation.

## Problem Summary

The current implementation has a token-model mismatch:

1. Protocol DETF mints seigniorage CHIR to the ProtocolNFTVault contract address.
2. ProtocolNFTVault reward accounting only tracks a single configured reward token.
3. That reward token is currently configured and documented as RICH.
4. As a result, CHIR minted as seigniorage is not part of the bond NFT claim flow.

The current system therefore treats CHIR seigniorage as protocol-held inventory, while bond NFT rewards remain RICH-only.

## Critical Design Constraint

There is a second issue adjacent to the reward-token bug:

- Protocol DETF currently calls `addToProtocolNFT(..., calc.protocolChir)` after minting seigniorage CHIR to the vault.
- `addToProtocolNFT` ultimately calls `_addToPosition`, which increases `originalShares`, `effectiveShares`, and `totalShares` directly.
- Those fields represent bonded principal share accounting, not arbitrary reward-token balances.

This means the refactor should not simply change the configured reward token from RICH to CHIR and stop there. It must remove the current CHIR-to-principal coupling so CHIR rewards are not double-counted as additional principal shares.

Code review resolves the implementation facts behind this constraint:

- Both DETF package deployment flows currently wire the Protocol NFT Vault reward token to RICH, not CHIR.
- Both exact-in and exact-out seigniorage paths currently mint CHIR to the vault and then incorrectly route that CHIR amount through `addToProtocolNFT(...)`.
- `addToProtocolNFT(...)` is principal-share accounting because it mutates `originalShares`, `effectiveShares`, and `totalShares`.

## Intended End State

After the refactor:

1. Bond NFT reward accounting uses CHIR as the reward token.
2. Minted seigniorage CHIR increases claimable rewards for bond NFT holders.
3. `claimRewards` transfers CHIR.
4. `pendingRewards` reports CHIR.
5. The protocol-owned NFT also participates in CHIR reward accrual.
6. `reallocateProtocolRewards` remains as the mechanism for redirecting protocol-owned CHIR rewards.
7. Selling a bond NFT to the protocol harvests any accrued CHIR to the seller-designated recipient.
8. Interface docs, comments, test names, deploy tests, and negative tests all reflect CHIR.
9. Principal share accounting remains about bonded reserve-pool principal, not reward-token balances.
10. The protocol-owned NFT behavior is explicitly tested so its reward participation is intentional, not accidental.

## Resolved Product Decisions

The following design choices are now fixed and should be treated as requirements during implementation:

1. The protocol-owned NFT accrues CHIR rewards too.
2. Seigniorage CHIR is reward-only and must not increase principal share accounting.
3. Selling a bond NFT to the protocol should harvest accrued CHIR during the sale flow.
4. `reallocateProtocolRewards` stays in the design.
5. The first implementation pass should cover both Base and Ethereum.
6. Preserve the generic `rewardToken()` API name.

## Files That Must Be Reviewed

Primary implementation files:

- `contracts/vaults/protocol/ProtocolNFTVaultRepo.sol`
- `contracts/vaults/protocol/ProtocolNFTVaultTarget.sol`
- `contracts/vaults/protocol/ProtocolNFTVaultService.sol`
- `contracts/vaults/protocol/ProtocolNFTVaultCommon.sol`
- `contracts/vaults/protocol/ProtocolNFTVaultDFPkg.sol`
- `contracts/interfaces/IProtocolNFTVault.sol`

Seigniorage source and capture paths:

- `contracts/vaults/protocol/BaseProtocolDETFExchangeInTarget.sol`
- `contracts/vaults/protocol/EthereumProtocolDETFExchangeInTarget.sol`
- `contracts/vaults/protocol/BaseProtocolDETFExchangeOutTarget.sol`
- `contracts/vaults/protocol/EthereumProtocolDETFExchangeOutTarget.sol`
- `contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol`
- `contracts/vaults/protocol/EthereumProtocolDETFBondingTarget.sol`

Existing test and fixture files:

- `test/foundry/spec/vaults/protocol/ProtocolNFTVault.t.sol`
- `test/foundry/spec/vaults/protocol/ProtocolNFTVaultPermissions_Negative.t.sol`
- `test/foundry/spec/protocol/vaults/protocol/ProtocolNFTVaultDFPkg_Deploy.t.sol`
- `test/foundry/spec/vaults/protocol/ProtocolDETF_IntegrationBase.t.sol`
- `test/foundry/spec/vaults/protocol/EthereumProtocolDETF_IntegrationBase.t.sol`

## Refactor Strategy

Implement this in four phases.

## Phase 1: Correct The Reward Token Model

### Objective

Make ProtocolNFTVault reward accounting point at CHIR, not RICH.

### Required changes

1. Update all documentation and interface comments in `IProtocolNFTVault.sol`:
   - `rewardToken()` should describe CHIR.
   - `pendingRewards()` should describe CHIR.
   - `claimRewards()` should describe CHIR.
   - `sellPositionToProtocol()` docs should no longer promise harvested RICH rewards.
   - `reallocateProtocolRewards()` docs should describe CHIR.

2. Update `ProtocolNFTVaultRepo.sol` comments and metadata strings:
   - replace RICH-specific reward wording with CHIR-specific wording.
   - update the NFT SVG label from `Pending RICH` to `Pending CHIR`.

3. Update `ProtocolNFTVaultTarget.sol` comments and getter docs so the public API no longer claims the reward token is RICH.

4. Update `ProtocolNFTVaultDFPkg.sol` so the package args and comments reflect that the vault reward token must be CHIR.

### Fixed API decision

Preserve the generic `rewardToken()` public API and generic storage naming.

Required runtime change:

- In both DETF package `initAccount()` deployment flows, change the NFT vault wiring from the current RICH token to CHIR.
- In package deployment context, CHIR is `IERC20(address(this))` because the DETF proxy is the CHIR token.

## Phase 2: Separate Reward Accrual From Principal Share Accounting

### Objective

Prevent minted CHIR rewards from being mixed into bonded principal share math.

### Current risk

`addToProtocolNFT` currently increases:

- `originalSharesOf[tokenId]`
- `effectiveSharesOf[tokenId]`
- `totalShares`

This is appropriate for added principal position value and inappropriate for reward-token balances.

### Required review

Audit all current call sites of `addToProtocolNFT(...)` and classify them:

1. BPT or reserve-pool principal added to protocol NFT:
   - remains share-accounted.

2. CHIR seigniorage minted to vault:
   - must not be treated as principal shares.

### Recommended implementation shape

Split the concepts explicitly:

1. Keep `addToProtocolNFT(tokenId, shares)` for principal-share additions only.
2. Do not call `addToProtocolNFT` when seigniorage CHIR is minted to the vault.
3. Let CHIR become claimable via reward-token balance deltas alone through `_updateGlobalRewards`.
4. Preserve protocol NFT reward participation through normal reward-share accounting, not through synthetic principal-share inflation.

### Files to inspect closely

- `BaseProtocolDETFExchangeInTarget.sol`
- `EthereumProtocolDETFExchangeInTarget.sol`
- `BaseProtocolDETFExchangeOutTarget.sol`
- `EthereumProtocolDETFExchangeOutTarget.sol`
- `BaseProtocolDETFBondingTarget.sol`
- `EthereumProtocolDETFBondingTarget.sol`

### Expected code changes

For seigniorage mint paths, change from:

- mint CHIR to vault
- add CHIR amount to protocol NFT shares

to:

- mint CHIR to vault
- do not mutate principal-share accounting

The protocol-owned NFT should still benefit from CHIR rewards, but only because it participates in reward-share accounting, not because CHIR rewards are reclassified as additional principal.

## Phase 3: Wire ProtocolNFTVault Deployments To CHIR

### Objective

Ensure real Protocol DETF deployments initialize the NFT vault with CHIR as its reward token.

### Required changes

1. Update both Protocol DETF package deployment flows, which currently pass RICH as `rewardToken` to `ProtocolNFTVaultDFPkg`.
   - This change should be made inside `initAccount()` in both DETF package contracts.
2. Change the reward token to the CHIR token address, which is the Protocol DETF proxy itself.
3. Update any deploy tests that still use placeholder reward token naming or assumptions.

### Important verification

The deploy flow should prove all of the following:

1. `protocolNFTVault.rewardToken() == IERC20(address(detf))`
2. `protocolNFTVault.lpToken()` is still the reserve-pool BPT token
3. claim and pending logic use CHIR balances

## Phase 4: Add Full CHIR Claim Test Coverage

### Objective

Prove end to end that bond NFT holders can claim CHIR minted as seigniorage.

### Test philosophy

Do not rely only on pure arithmetic tests. Add integration tests that exercise the actual Protocol DETF mint path that creates seigniorage CHIR.

### Test file plan

#### 1. Upgrade the current lightweight spec file

File:

- `test/foundry/spec/vaults/protocol/ProtocolNFTVault.t.sol`

Current state:

- mostly arithmetic or conceptual tests
- not enough runtime coverage

Action:

- keep the simple arithmetic tests that still validate isolated math or share-accounting behavior
- add runtime-focused CHIR claim coverage in dedicated integration files

#### 2. Add real integration claim tests on Base Protocol DETF

Test file:

- `test/foundry/spec/vaults/protocol/ProtocolNFTVault_ClaimChir.t.sol`

Base fixture:

- inherit from `ProtocolDETF_IntegrationBase`

Required tests:

1. `test_rewardToken_isChir()`
   - assert `address(protocolNFTVault.rewardToken()) == address(detf)`

2. `test_pendingRewards_zero_before_seigniorage()`
   - create a bond NFT position
   - assert pending rewards are zero before any CHIR seigniorage is minted

3. `test_claimRewards_transfersChir_after_seigniorage_mint()`
   - create at least one bond NFT position
   - execute a mint-above-peg flow that mints protocol seigniorage CHIR into the vault
   - assert `pendingRewards(tokenId) > 0`
   - claim rewards
   - assert recipient CHIR balance increases
   - assert post-claim pending rewards returns to zero or near-zero as appropriate

4. `test_multipleBondHolders_split_chir_pro_rata_by_effectiveShares()`
   - create two or more bond NFTs with different lock durations and therefore different effective shares
   - mint seigniorage CHIR
   - assert pending CHIR is distributed proportionally to effective shares

5. `test_claimRewards_only_owner_can_claim_for_token()`
   - preserve the existing ownership requirement while claiming CHIR instead of RICH

6. `test_claimRewards_updates_rewardDebt_and_does_not_double_pay()`
   - claim once
   - claim again without new seigniorage
   - assert second claim is zero

7. `test_seigniorage_claim_seigniorage_claim_preserves_incremental_entitlement()`
   - create multiple bond NFTs
   - mint first seigniorage tranche
   - have only a subset of NFT holders claim
   - mint second seigniorage tranche
   - assert the already-claimed NFTs only receive their proportional share of the second tranche
   - assert the unclaimed NFTs receive the sum of their proportional share of both tranches
   - assert no holder loses or gains CHIR due to another holder claiming early

8. `test_new_bond_nft_does_not_back_claim_old_chir()`
   - create first NFT
   - mint seigniorage CHIR
   - create second NFT after rewards accrued
   - assert second NFT cannot claim prior rewards due to `userRewardPerSharePaid` initialization

9. `test_protocol_nft_reward_participation_is_explicit()`
   - assert that the protocol-owned NFT shares in CHIR rewards
   - test `reallocateProtocolRewards` as the collection path for protocol-owned CHIR rewards

#### 3. Add Ethereum parity tests

Test file:

- `test/foundry/spec/vaults/protocol/EthereumProtocolNFTVault_ClaimChir.t.sol`

Ethereum fixture:

- inherit from `EthereumProtocolDETF_IntegrationBase`

Required tests:

1. `test_rewardToken_isChir()`
2. `test_claimRewards_transfersChir_after_seigniorage_mint()`
3. `test_multipleBondHolders_split_chir_pro_rata_by_effectiveShares()`
4. `test_claimRewards_updates_rewardDebt_and_does_not_double_pay()`
5. `test_seigniorage_claim_seigniorage_claim_preserves_incremental_entitlement()`
6. `test_protocol_nft_reward_participation_is_explicit()`

#### 4. Update deploy tests

File:

- `test/foundry/spec/protocol/vaults/protocol/ProtocolNFTVaultDFPkg_Deploy.t.sol`

Required changes:

1. stop using generic `Reward Token` naming in expectations where the real product meaning is CHIR
2. add an assertion in integration deploy coverage that the deployed ProtocolNFTVault reward token equals the CHIR token address

#### 5. Update negative and authorization tests

File:

- `test/foundry/spec/vaults/protocol/ProtocolNFTVaultPermissions_Negative.t.sol`

Required changes:

1. keep ownership and authorization tests as-is
2. rename descriptions/comments that still say RICH rewards
3. make `reallocateProtocolRewards` semantics CHIR-specific in test names and comments

## Detailed Runtime Test Sequence

Use this exact sequence for the primary end-to-end claim test:

1. Deploy the standard Protocol DETF fixture.
2. Create one or more bond positions via `bondWithWeth` or `bondWithRich`.
3. Confirm `pendingRewards(tokenId) == 0` initially.
4. Move the DETF into a mint-enabled regime.
5. Execute a route that mints protocol seigniorage CHIR.
6. Confirm the ProtocolNFTVault CHIR balance increased.
7. Call `pendingRewards(tokenId)` and assert it is positive.
8. Call `claimRewards(tokenId, recipient)` as the NFT owner.
9. Assert recipient CHIR balance increased by the claimed amount.
10. Assert `userRewardPerSharePaid[tokenId]` was advanced indirectly through public state effects.
11. Assert a second claim without new rewards yields zero.

Use a second runtime sequence for partial-claim proportionality:

1. Deploy the standard Protocol DETF fixture.
2. Create multiple bond NFT positions with intentionally different effective shares.
3. Mint a first seigniorage tranche.
4. Record pending rewards for all NFTs.
5. Have only a subset of holders claim.
6. Mint a second seigniorage tranche.
7. Claim for all remaining holders and re-claim for the early claimers.
8. Assert each NFT holder ends with exactly its proportional share across both tranches.
9. Assert early claimers only receive new rewards from the second tranche on their second claim.
10. Assert late claimers receive accumulated rewards from both tranches in one claim.
11. Assert total CHIR distributed matches the aggregate user-claimable portion expected from both seigniorage events.

## Implementation-Critical Economic Rules

1. The protocol-owned NFT should share in CHIR rewards.
   - `reallocateProtocolRewards` is the path for redirecting those protocol-owned CHIR emissions.

2. Seigniorage CHIR should not increase principal weight.
   - Current code suggests otherwise by calling `addToProtocolNFT(calc.protocolChir)`.
   - The refactor should remove that coupling.

3. Sold-NFT reward harvesting remains part of `sellPositionToProtocol`.
   - After the refactor, that harvested reward should be CHIR.

## Acceptance Criteria

The refactor is complete only when all of the following are true:

1. `protocolNFTVault.rewardToken()` returns CHIR.
2. A bond NFT holder can claim CHIR after a real seigniorage event.
3. `pendingRewards()` measures CHIR, not RICH.
4. Claiming rewards transfers CHIR.
5. The protocol-owned NFT accrues CHIR rewards and `reallocateProtocolRewards` can collect them.
6. Selling a bond NFT harvests CHIR.
7. Claim tests pass on both Base and Ethereum Protocol DETF suites in the first implementation pass.
8. Multi-tranche reward accounting remains proportional even when only some NFT holders claim between seigniorage events.
9. No path incorrectly treats CHIR rewards as bonded principal shares.
10. The public `rewardToken()` API is preserved while returning CHIR in Protocol DETF deployments.
11. All comments, docs, metadata strings, and test descriptions no longer claim rewards are RICH.

## Suggested Execution Order

1. Update comments and interface wording so the intended behavior is explicit.
2. Change Protocol DETF deployment wiring so the vault reward token is CHIR.
3. Remove `addToProtocolNFT(..., protocolChir)` from seigniorage mint paths.
4. Update sale-flow reward harvesting semantics from RICH to CHIR.
5. Add Base and Ethereum integration tests for CHIR claiming and protocol NFT participation.
6. Update deploy and negative tests.
7. Run focused suites first, then broader DETF suites.

## Suggested Test Commands

Run these after implementation:

```bash
forge test --match-path test/foundry/spec/vaults/protocol/ProtocolNFTVault*.t.sol
forge test --match-path test/foundry/spec/vaults/protocol/EthereumProtocolNFTVault*.t.sol
forge test --match-path test/foundry/spec/vaults/protocol/ProtocolDETF_Routes.t.sol
forge test --match-path test/foundry/spec/vaults/protocol/EthereumProtocolDETF_Routes.t.sol
forge test --match-path test/foundry/spec/protocol/vaults/protocol/ProtocolNFTVaultDFPkg_Deploy.t.sol
```

If regressions appear in route tests, inspect the seigniorage mint paths first because they currently mix reward-token minting with `addToProtocolNFT` share mutation.