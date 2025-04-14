# ProtocolDETFExchangeInTarget

## Target: `contracts/vaults/protocol/ProtocolDETFExchangeInTarget.sol`

## Intent
- Execute exact-in style protocol exchanges for CHIR and related assets (WETH/RICH/RICHIR), including minting (above peg) and redemption (below peg).

## Validation
- CONFIRMED-WITH-MAINTAINER (2026-02-14)

Repo-wide invariants applied: see PROMPT.md

- Preview policy: exact-in previews must satisfy `previewOut <= executeOut`; exact-out previews must satisfy `previewIn >= executeIn`. Tests must compare preview and execution on the same on-chain state.
- Deterministic deployments: production deploys must use Crane CREATE3 + Diamond Package Callback Factory; do NOT use `new()` in production deploy paths. Adversarial front-run deployment tests required for any deploy-with-initial-deposit helpers.
- Permit2: routers MUST enforce Permit2; vaults should prefer Permit2 and may document ERC20 `approve` fallback where explicitly permitted and tested.
- No cached rates: rate/redemption providers used in accounting must compute fresh values each call; avoid stale cached rates without explicit invalidation and tests.
- Vault gating: vault packages MUST gate `processArgs()` to `IVaultRegistryDeployment` (registry-first model) for all vaults intended to be discoverable.
- Post-deploy safety: `postDeploy()` hooks may contain wiring logic but must only be callable by the deterministic factory callback during deployment; tests must prove arbitrary EOAs/contracts cannot invoke `postDeploy()` to mutate state.

## Routes

### Route ID: TGT-ProtocolDETFExchangeIn-01 (WETH → CHIR)
- Selector / Function: `exchangeIn(IERC20,uint256,IERC20,uint256,address,bool,uint256)`
- Entry Context: Proxy -> delegatecall Target; permissionless entrypoint
- Auth: Permissionless
- State Writes: `ProtocolDETFRepo` (reads config), `ERC20Repo` (mints/burns), `ERC4626Repo` (reserve tracking via downstream calls)
- External Calls: StandardExchange vaults (`chirWethVault`, `richChirVault`), `protocolNFTVault.addToProtocolNFT`, ERC20 transfers; reentrancy protected by `lock`
- Inputs: `tokenIn=WETH`, `tokenOut=CHIR`, `amountIn>0`, `deadline>=now`, `minAmountOut` enforced
- Outputs: `amountOut` = CHIR minted to `recipient` (includes discount incentive)
- Events: ERC20 `Transfer` (mint), any downstream vault events, NFT vault events
- Execution Outline: 
  1. Validate deadline/amount.
  2. Pull/accept WETH from user (pretransfer supported).
  3. Get current live balances from underlying Aerodrome pool of CHIR/WETH vault.
  4. Apply seigniorage incentive: add `IVaultFeeOracleQuery.seigniorageIncentivePercentageOfVault` to WETH amount.
  5. Use `ConstProdUtils._saleQuote` with the increased WETH amount to calculate base CHIR amount.
  6. Split seigniorage:
     - User receives: `baseCHIR * (1 - seigniorageIncentivePercentageOfVault / 2)`
     - Example: 100 CHIR * 0.95 = 95 CHIR to user
     - Protocol DETF NFT receives: `baseCHIR * (seigniorageIncentivePercentageOfVault / 2)`
     - Example: 100 CHIR * 0.05 = 5 CHIR to NFT
  7. Deposit WETH into CHIR/WETH Standard Exchange Vault → get vault shares.
  8. Deposit vault shares into Balancer reserve pool as unbalanced deposit → get BPT.
  9. Add BPT to Protocol NFT position.
  10. Mint CHIR reward to ProtocolDETF NFT.
  11. Mint CHIR to user.
  12. Return total CHIR minted to user.
- Invariants: mint only allowed when `syntheticPrice > mintThreshold`; `amountOut >= minAmountOut`; backing deposit happens before minting to user; Protocol DETF holds only BPT (reserve pool token) after transaction completes
- Failure Modes: `DeadlineExceeded`, `ZeroAmount`, `ReservePoolNotInitialized`, `MintingNotAllowed`, `SlippageExceeded`, downstream reverts
- Tests Required: exact-in preview/execution parity (preview <= execute on same state); above-threshold gate; `pretransferred` true/false paths; seigniorage mint credited; reentrancy guard coverage; slippage revert

### Route ID: TGT-ProtocolDETFExchangeIn-02 (CHIR → WETH)
- Selector / Function: `exchangeIn(IERC20,uint256,IERC20,uint256,address,bool,uint256)`
- Entry Context: Proxy -> delegatecall Target
- Auth: Permissionless
- State Writes: `ERC20Repo` (burn), Balancer reserve pool state via router, `ERC4626Repo._setLastTotalAssets` via internal helper in this Target
- External Calls: Balancer V3 prepay router, StandardExchange vault `exchangeIn`, token transfers; reentrancy protected by `lock`
- Inputs: `tokenIn=CHIR`, `tokenOut=WETH`, `amountIn>0`, `deadline>=now`, `minAmountOut` enforced
- Outputs: `amountOut` = WETH sent to `recipient`
- Events: ERC20 `Transfer` (burn), downstream vault/router events
- Execution Outline:
  1. Validate deadline/amount.
  2. Only allow burning when `syntheticPrice < peg`.
  3. Add `IVaultFeeOracleQuery.seigniorageIncentivePercentageOfVault` to CHIR amount.
  4. Quote virtual WETH out using `ConstProdUtils._saleQuote` with increased CHIR as amountIn.
  5. Transfer CHIR to CHIR/WETH vault, call `exchangeIn(CHIR → WETH, pretransferred=true)`.
  6. Calculate WETH deficit: `virtualWETH - actualWETHFromVault`.
  7. Get Aerodrome pool reserves, use `ConstProdUtils._equivLiquidity` to calculate equivalent amount of CHIR for the WETH deficit amount.
  8. Use ConstProdUtils._depositQuote to find target LP to withdraw.
  9. Use `previewExchangeOut` to get reserve pool target withdrawal.
  10. Get reserve pool reserves from Balancer Vault via `IVaultExplorer.getPoolTokenInfo`.
  11. Use `BalancerV38020WeightedPoolMath._calcEquivalentProportionalGivenSingle` → equivalent CHIR/RICH vault shares.
  12. Use `BalancerV38020WeightedPoolMath._calcBptInGivenProportionalOut` → BPT to burn.
  13. Withdraw BPT proportionally → CHIR/WETH vault shares + CHIR/RICH vault shares.
  14. Redeposit CHIR/RICH + add BPT to Protocol NFT position.
  15. Transfer CHIR/WETH vault shares → burn via `exchangeIn` → withdraw LP.
  16. Withdraw LP → get CHIR + WETH.
  17. Verify: withdrawn WETH ≥ WETH deficit.
  18. Burn withdrawn CHIR.
  19. Send WETH deficit to user.
- Invariants: burn only allowed when `syntheticPrice < peg`; slippage enforced; Protocol DETF holds only BPT before unwind, then only WETH after; no stray vault shares after transaction
- Failure Modes: `BurningNotAllowed`, `ZeroAmount`, `SlippageExceeded`, downstream reverts
- Tests Required: below-threshold gate; slippage; BPT proportional math edge cases (small supply/bpt); execution does not leave stray CHIR/WETH balances; preview <= execute for exact-in CHIR->WETH

### Route ID: TGT-ProtocolDETFExchangeIn-03 (RICH → CHIR)
- Selector / Function: `exchangeIn(IERC20,uint256,IERC20,uint256,address,bool,uint256)`
- Entry Context: Proxy -> delegatecall Target
- Auth: Permissionless
- State Writes: None (simple transfer)
- External Calls: `richChirVault.exchangeIn`; reentrancy protected by `lock`
- Inputs: `tokenIn=RICH`, `tokenOut=CHIR`, `amountIn>0`, `deadline>=now`, `minAmountOut` enforced
- Outputs: `amountOut` CHIR sent to recipient
- Events: downstream vault events
- Execution Outline:
  1. Validate deadline/amount.
  2. Pull/accept RICH from user.
  3. Swap RICH → CHIR via RICH/CHIR vault (`exchangeIn`).
  4. Enforce `minAmountOut`.
  5. Transfer CHIR to recipient.
- Invariants: simple vault-to-vault swap; Protocol DETF reserve unchanged; no mint/burn gates; no seigniorage
- Failure Modes: `DeadlineExceeded`, `ZeroAmount`, `SlippageExceeded`, downstream reverts
- Tests Required: slippage protection; vault swap correctness; Protocol DETF reserve unchanged

### Route ID: TGT-ProtocolDETFExchangeIn-04 (RICHIR → WETH)
- Selector / Function: `exchangeIn(IERC20,uint256,IERC20,uint256,address,bool,uint256)`
- Entry Context: Proxy -> delegatecall Target
- Auth: Permissionless
- State Writes: `RICHIRRepo` (burn shares), Balancer reserve pool, protocol NFT position, `ERC4626Repo`
- External Calls: `richirToken.burnShares`, StandardExchange vaults, Balancer prepay router, Aerodrome pools; reentrancy protected by `lock`
- Inputs: `tokenIn=RICHIR`, `tokenOut=WETH`, `amountIn>0`, `deadline>=now`, `minAmountOut` enforced
- Outputs: WETH transferred to recipient
- Events: RICHIR burn events, downstream vault/router/NFT events
- Execution Outline:
  1. Convert RICHIR amount → shares via `convertToShares`.
  2. Use `BetterMath._convertToAssetsDown(shares, protocolNFTBptReserve)` → BPT to withdraw.
  3. Proportional withdraw of BPT → CHIR/WETH vault shares + CHIR/RICH vault shares.
  4. Exchange CHIR/RICH vault shares → CHIR/RICH LP via `exchangeIn`.
  5. Withdraw CHIR/RICH LP → CHIR + RICH.
  6. Redeposit RICH in CHIR/RICH vault → CHIR/RICH vault shares.
  7. Swap CHIR → WETH via `exchangeIn` through CHIR/WETH vault.
  8. Exchange CHIR/WETH vault shares → CHIR/WETH LP via `exchangeIn`.
  9. Withdraw CHIR/WETH LP → CHIR + WETH.
  10. Redeposit CHIR in CHIR/WETH vault.
  11. Redeposit both vault shares in reserve pool → BPT.
  12. Add BPT to Protocol NFT position.
  13. Send all WETH to user.
- Invariants: Protocol DETF ends holding only BPT (reserve pool token); redemption maintains reserve backing; no stray vault shares after transaction
- Failure Modes: downstream reverts, `SlippageExceeded`
- Tests Required: ordering invariant (burn-before-exit); redemption maintains reserve; preview <= execute; reentrancy; no stuck assets

### Route ID: TGT-ProtocolDETFExchangeIn-05 (RICH → RICHIR)
- Selector / Function: `exchangeIn(IERC20,uint256,IERC20,uint256,address,bool,uint256)`
- Entry Context: Proxy -> delegatecall Target
- Auth: Permissionless
- State Writes: Balancer reserve pool, protocol NFT position, RICHIR shares via `mintFromNFTSale`, `ERC4626Repo._setLastTotalAssets`
- External Calls: `richChirVault.exchangeIn`, `chirWethVault.exchangeIn`, Balancer prepay router, `protocolNFTVault.addToProtocolNFT`, `richirToken.mintFromNFTSale`; reentrancy protected by `lock`
- Inputs: `tokenIn=RICH`, `tokenOut=RICHIR`, `amountIn>0`, `deadline>=now`, `minAmountOut` enforced
- Outputs: `amountOut` RICHIR minted to recipient
- Events: downstream vault/router/NFT events + RICHIR mint
- Execution Outline:
  1. Validate deadline/amount.
  2. Exchange RICH → CHIR via RICH/CHIR vault (`exchangeIn`).
  3. Exchange CHIR → WETH via CHIR/WETH vault (`exchangeIn`).
  4. Exchange WETH → CHIR/WETH vault shares via CHIR/WETH vault (`exchangeIn`).
  5. Deposit vault shares in reserve pool → get BPT.
  6. Add BPT to Protocol NFT position.
  7. Use `BetterMath._convertToSharesDown(BPT amount)` → RICHIR shares.
  8. Mint RICHIR shares to user via `mintFromNFTSale`.
  9. Enforce `minAmountOut`.
- Invariants: Protocol DETF ends holding only BPT (reserve pool token); RICHIR minted proportional to BPT added
- Failure Modes: `SlippageExceeded`, downstream reverts
- Tests Required: preview <= execute; BPT → RICHIR shares conversion; minOut; reserve unchanged except BPT

### Route ID: TGT-ProtocolDETFExchangeIn-06 (WETH → RICHIR)
- Selector / Function: `exchangeIn(IERC20,uint256,IERC20,uint256,address,bool,uint256)`
- Entry Context: Proxy -> delegatecall Target
- Auth: Permissionless
- State Writes: Balancer reserve pool, protocol NFT position, RICHIR shares via `mintFromNFTSale`, `ERC4626Repo._setLastTotalAssets`
- External Calls: `chirWethVault.exchangeIn`, Balancer prepay router, `protocolNFTVault.addToProtocolNFT`, `richirToken.mintFromNFTSale`; reentrancy protected by `lock`
- Inputs: `tokenIn=WETH`, `tokenOut=RICHIR`, `amountIn>0`, `deadline>=now`, `minAmountOut` enforced
- Outputs: `amountOut` RICHIR minted to recipient
- Events: downstream + RICHIR mint
- Execution Outline:
  1. Validate deadline/amount.
  2. Exchange WETH → CHIR/WETH vault shares via `exchangeIn`.
  3. Deposit vault shares in reserve pool → get BPT.
  4. Add BPT to Protocol NFT position.
  5. Use `BetterMath._convertToSharesDown(BPT amount)` → RICHIR shares.
  6. Mint RICHIR shares to user via `mintFromNFTSale`.
  7. Enforce `minAmountOut`.
- Invariants: Protocol DETF ends holding only BPT (reserve pool token); RICHIR minted proportional to BPT added
- Failure Modes: `SlippageExceeded`, downstream reverts
- Tests Required: preview <= execute; BPT → RICHIR shares conversion; minOut

### Route ID: TGT-ProtocolDETFExchangeIn-07 (WETH → RICH)
- Selector / Function: `exchangeIn(IERC20,uint256,IERC20,uint256,address,bool,uint256)`
- Entry Context: Proxy -> delegatecall Target
- Auth: Permissionless
- State Writes: none (simple swap)
- External Calls: `chirWethVault.exchangeIn`, `richChirVault.exchangeIn`; reentrancy protected by `lock`
- Inputs: `tokenIn=WETH`, `tokenOut=RICH`, `amountIn>0`, `deadline>=now`, `minAmountOut` enforced on final hop
- Outputs: RICH sent to recipient
- Events: downstream vault events
- Execution Outline:
  1. Validate deadline/amount.
  2. Exchange WETH → CHIR via CHIR/WETH vault.
  3. Exchange CHIR → RICH via CHIR/RICH vault with user as recipient.
  4. Enforce `minAmountOut`.
- Invariants: simple multi-hop swap; Protocol DETF reserve unchanged; no mint/burn
- Failure Modes: `DeadlineExceeded`, `ZeroAmount`, `SlippageExceeded`, downstream reverts
- Tests Required: multi-hop preview <= execute; final minOut enforced; deadline

### Route ID: TGT-ProtocolDETFExchangeIn-08 (RICH → WETH)
- Selector / Function: `exchangeIn(IERC20,uint256,IERC20,uint256,address,bool,uint256)`
- Entry Context: Proxy -> delegatecall Target
- Auth: Permissionless
- State Writes: none (simple swap)
- External Calls: `richChirVault.exchangeIn`, `chirWethVault.exchangeIn`; reentrancy protected by `lock`
- Inputs: `tokenIn=RICH`, `tokenOut=WETH`, `amountIn>0`, `deadline>=now`, `minAmountOut` enforced on final hop
- Outputs: WETH sent to recipient
- Events: downstream vault events
- Execution Outline:
  1. Validate deadline/amount.
  2. Exchange RICH → CHIR via CHIR/RICH vault.
  3. Exchange CHIR → WETH via CHIR/WETH vault to user as recipient.
  4. Enforce `minAmountOut`.
- Invariants: simple multi-hop swap; Protocol DETF reserve unchanged; no mint/burn
- Failure Modes: `DeadlineExceeded`, `ZeroAmount`, `SlippageExceeded`, downstream reverts
- Tests Required: multi-hop preview <= execute; final minOut enforced; deadline

## postDeploy() / Post-deploy behavior
- PENDING-MAINTAINER-REVIEW

## Implementation Review Findings (2026-02-14)

I reviewed the implementation at `contracts/vaults/protocol/ProtocolDETFExchangeInTarget.sol` against the requirements in this document. Below are the issues and mismatches I found (ordered by severity).

- Critical: mint path does not deposit reserve backing before minting to user — The spec requires that WETH deposits are converted to vault shares, those vault shares are deposited into the Balancer reserve pool (unbalanced add) and BPT added to the protocol NFT before any CHIR is minted to the user. In the implementation (`_executeMintWithWeth`), WETH is deposited into `chirWethVault` (getting vault shares) but those vault shares are NOT added to the reserve pool; instead CHIR is minted directly to the protocol NFT and to the user (ERC20Repo._mint). This breaks the invariant "backing deposit happens before minting to user" and allows minting without the required reserve-side backing (see `contracts/vaults/protocol/ProtocolDETFExchangeInTarget.sol::_executeMintWithWeth`).

- Critical: protocol backing minted as CHIR instead of BPT — The requirements describe a flow where the protocol position receives BPT from the reserve-pool deposit and (separately) receives a seigniorage CHIR reward. In the implementation the code mints CHIR directly to `protocolNFTVault` (line where `ERC20Repo._mint(address(layout_.protocolNFTVault), calc.seigniorageTokens)` is used) but does not produce BPT for the protocol NFT in the mint flow. This both violates the reserve-backed invariant and changes accounting for the protocol position.

- High: seigniorage split differs from spec — The spec text describes applying a seigniorage incentive percentage to the WETH amount and splitting seigniorage so the user receives base*(1 - pct/2) and the protocol NFT receives base*(pct/2). The implementation instead computes gross seigniorage from price arithmetic and then applies a reduction percentage to compute `discountMargin` (added to user) and `seigniorageTokens` (minted to protocol) where `seigniorageTokens = gross - discountMargin`. The effective split and math are different from the doc; if the split semantics (half/half or other) are important they must be clarified and implementation aligned (see `ProtocolDETFCommon._calcSeigniorage` and `_executeMintWithWeth`).

- Medium: minAmountOut check is applied on base amount before adding discount — In `_executeMintWithWeth` the code checks `if (amountOut_ < p_.minAmountOut) revert SlippageExceeded` before adding the `discountMargin` to the final user amount. This makes the minAmountOut requirement stricter than necessary and can cause valid calls (where final minted = base + discount ≥ minAmountOut) to revert because base < minAmountOut. The check should be against the actual amount the user will receive (base + discountMargin).

- Medium: preview vs execute semantics need explicit parity verification for mint route — Query target (`ProtocolDETFExchangeInQueryTarget`) computes the same discount and base amounts as the execution code, but because execution currently omits the reserve pool deposit step (which would change protocol state and could affect subsequent calculations), the preview may lie about the final state (or conversely previews may be conservative). Tests must assert preview <= execute on the same on-chain state, and the missing backing deposit widens the gap between expected and actual state changes.

- Low: documentation/requirements vs code using different primitives — The requirements mention using `ConstProdUtils._saleQuote` in the mint flow; the implementation uses `_calcMintAmount` (oracle-driven price arithmetic) instead. This is not necessarily wrong but should be a conscious design choice and documented: which pricing primitive drives the mint base calculation (synthetic oracle vs AMM sale quote). If the intention is oracle-driven minting, update the requirements to match.

- Low: minor style/consistency
  - The code sometimes enforces slippage with `SlippageExceeded` and elsewhere with `MinAmountNotMet`; standardize which error is used for `minAmountOut` failures across routes.
  - Verify Permit2 usage is acceptable for all caller flows (the code uses `Permit2AwareRepo._permit2()` fallback in `_secureTokenTransfer`) and that tests exercise both Permit2 and ERC20 `approve` fallback paths as per repo policy.

Suggested next steps
1. Fix the mint path to perform the unbalanced deposit of vault shares into the Balancer reserve pool and add resulting BPT to the protocol NFT before minting any CHIR to the user. Update `_executeMintWithWeth` and any wrapper routes that call it (e.g., `_executeRichToChir`).
2. Ensure the protocol receives both: (a) BPT into `protocolNFTVault` (the reserve backing) and (b) any CHIR seigniorage reward — if both are intended. Align code with the document or update the doc to reflect the intended economics.
3. Correct the minAmountOut check to validate the final user amount (including discountMargin) rather than the pre-discount base amount.
4. Add/adjust unit and integration tests: minting above peg must show preview ≤ execute, protocol NFT BPT balance increases, and no mint occurs if reserve deposit fails. Add tests for pretransferred true/false, Permit2 fallback, and seigniorage accounting.
5. Decide on the canonical seigniorage split and update both `ProtocolDETFCommon._calcSeigniorage` and this requirements doc to be explicit about math and where the split is applied (amountIn vs baseCHIR vs grossSeigniorage).

If you want, I can open a PR that updates the implementation to perform the reserve deposit + BPT addition before mint, and adjust the minAmountOut check and tests; let me know and I'll prepare the change set and tests.

## Implementation Plan (2026-02-14)

### Overview
Fix the mint path (WETH → CHIR) to properly deposit reserve backing before minting, and correct the minAmountOut check.

### Step 1: Create helper for CHIR/WETH vault shares deposit
Add a new internal function to handle unbalanced deposit of CHIR/WETH vault shares to the Balancer reserve pool:

```solidity
function _unbalancedDepositChirWethAndAddToProtocolNFT(
    ProtocolDETFRepo.Storage storage layout_,
    uint256 chirWethVaultShares_
) internal {
    // Mirror _unbalancedDepositAndAddToProtocolNFT but use chirWethVaultIndex
    // 1. Build amounts array with chirWethVaultShares_ at chirWethVaultIndex
    // 2. Transfer vault shares to Balancer vault
    // 3. Call prepayAddLiquidityUnbalanced
    // 4. Add resulting BPT to protocol NFT via protocolNFTVault.addToProtocolNFT
}
```

Location: Add after existing `_unbalancedDepositAndAddToProtocolNFT` (around line 514).

### Step 2: Fix `_executeMintWithWeth`
File: `contracts/vaults/protocol/ProtocolDETFExchangeInTarget.sol`

Current (broken) flow:
1. Secure WETH transfer
2. Calculate base mint amount
3. Check minAmountOut (too early!)
4. Deposit WETH → chirWethVault (gets shares)
5. Mint CHIR seigniorage to protocol NFT
6. Mint CHIR to user

Required flow:
1. Secure WETH transfer
2. Calculate base mint amount
3. Deposit WETH → chirWethVault (gets shares)
4. **Deposit vault shares to Balancer reserve pool (unbalanced) → get BPT**
5. **Add BPT to protocol NFT** (reserve backing)
6. Calculate seigniorage (discountMargin + seigniorageTokens)
7. **Check minAmountOut against final user amount (base + discountMargin)**
8. Mint CHIR seigniorage to protocol NFT (separate from BPT)
9. Mint CHIR to user

Changes to make:
- Move the minAmountOut check to AFTER computing `userMintAmount = amountOut_ + calc.discountMargin`
- Insert call to new helper after vault deposit, before CHIR minting:
  ```solidity
  // After: layout_.chirWethVault.exchangeIn(...)
  // Add:
  if (chirWethShares > 0) {
      _unbalancedDepositChirWethAndAddToProtocolNFT(layout_, chirWethShares);
  }
  ```

Note: Need to capture the vault shares received from the chirWethVault deposit. Currently the code doesn't capture the return value.

### Step 3: Capture vault shares from chirWethVault deposit
Current code (lines 221-225):
```solidity
p_.tokenIn.safeTransfer(address(layout_.chirWethVault), actualIn);
layout_.chirWethVault
    .exchangeIn(
        p_.tokenIn, actualIn, IERC20(address(layout_.chirWethVault)), 0, address(this), true, p_.deadline
    );
```

Change to:
```solidity
p_.tokenIn.safeTransfer(address(layout_.chirWethVault), actualIn);
uint256 chirWethShares = layout_.chirWethVault
    .exchangeIn(
        p_.tokenIn, actualIn, IERC20(address(layout_.chirWethVault)), 0, address(this), true, p_.deadline
    );
```

### Step 4: Fix minAmountOut check
Current (lines 211-213):
```solidity
if (amountOut_ < p_.minAmountOut) {
    revert SlippageExceeded(p_.minAmountOut, amountOut_);
}
```

Move to AFTER calculating userMintAmount (around line 229):
```solidity
uint256 userMintAmount = amountOut_ + calc.discountMargin;
if (userMintAmount < p_.minAmountOut) {
    revert SlippageExceeded(p_.minAmountOut, userMintAmount);
}
```

### Step 5: Verify `_executeRichToChir` works correctly
This function (lines 249-284) calls `_executeMintWithWeth` internally. With the fix, it will now:
1. Swap RICH → CHIR via richChirVault
2. Swap CHIR → WETH via chirWethVault
3. Call `_executeMintWithWeth` with the WETH output

The internal `_executeMintWithWeth` will now properly deposit backing. No changes needed here, but verify the flow.

### Step 6: Update query target if needed
File: `contracts/vaults/protocol/ProtocolDETFExchangeInQueryTarget.sol`

The preview function (`_previewWethToChir` via lines 117-131) should already compute the same amounts. With the implementation fix, ensure preview also accounts for:
- The reserve deposit (which could affect subsequent calculations)
- The final user amount (base + discount)

The preview may need a buffer/slippage adjustment to guarantee `preview ≤ execute`. Current implementation already has buffers for RICHIR routes; verify mint route doesn't need similar treatment.

### Files to Modify
1. `contracts/vaults/protocol/ProtocolDETFExchangeInTarget.sol`
   - Add new helper function `_unbalancedDepositChirWethAndAddToProtocolNFT`
   - Modify `_executeMintWithWeth` to capture vault shares and deposit to reserve
   - Fix minAmountOut check

2. `contracts/vaults/protocol/ProtocolDETFExchangeInQueryTarget.sol` (if needed)
   - Verify preview accounts for reserve deposit

### Testing Requirements
- exact-in preview ≤ execute for mint route (same on-chain state)
- Protocol NFT BPT balance increases after mint
- No mint occurs if reserve deposit fails (or should handle gracefully)
- pretransferred true/false paths work
- Permit2 vs ERC20 approve fallback
- Seigniorage accounting: protocol gets BPT backing + CHIR seigniorage (if intended)
- Slippage protection works with discountMargin included
