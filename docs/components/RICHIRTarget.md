# RICHIRTarget

## Target: `contracts/vaults/protocol/RICHIRTarget.sol`

## Intent
- Rebasing ERC20 token (RICHIR) whose balances derive from shares * redemptionRate; minted from protocol NFT sales and redeemable for WETH.

## Validation
- CONFIRMED-WITH-MAINTAINER (2026-02-14)

## Routes

### Route ID: TGT-RICHIR-01
- Selector / Function: ERC20 views (`totalSupply()`, `balanceOf(address)`, `sharesOf(address)`, `totalShares()`, `redemptionRate()`, `convertToShares(uint256)`, `convertToRichir(uint256)`, `previewRedeem(uint256)`)
- Entry Context: Proxy -> delegatecall Target; view-only
- Auth: Permissionless
- State Writes: None
- External Calls: `protocolDETF.previewExchangeIn` inside redemption-rate calc (values protocol-owned BPT)
- Inputs/Outputs: compute live balance from shares and current redemption rate (computed fresh each call, NO caching)
- Invariants: redemptionRate never returns 0; always computed fresh (no cache)
- Tests Required: shares<->balance conversions; previewRedeem scaling; verify no caching
- Tests Required (additional, maintainer-confirmed):
  - `previewRedeem(x)` then `redeem(x, recipient, false)` in the same on-chain state must satisfy `previewOut <= wethReceived` (same-block test to assert same-state optimistic preview invariant).
  - NO cached-rate behavior: redemption rate must be computed fresh on every call; verify `lastRateUpdateBlock` and `cachedRedemptionRate` are NOT used.

Repo-wide invariants (copy from PROMPT.md):
- Preview policy: exact-in previews must satisfy `previewOut <= executeOut`; exact-out previews must satisfy `previewIn >= executeIn` on the same on-chain state. Tests must compare preview and execution on the same state and include fuzz/invariant checks for any rounding buffers.
- Deterministic deployments: production deploys MUST use Crane CREATE3 + Diamond Package Callback Factory; do NOT use `new()` in production deploy paths. Any deploy-with-initial-deposit helpers require adversarial front-run deployment tests.
- Permit2: routers MUST enforce Permit2; vaults should prefer Permit2. Any ERC20 approve/transferFrom fallback must be explicitly documented and covered by tests where permitted.
- No cached rates: rate/redemption values used in accounting MUST be computed fresh on every call; avoid stale cached rates without explicit invalidation and tests.
- Vault gating: vault packages MUST gate `processArgs()` to `IVaultRegistryDeployment` for all vaults intended to be discoverable via the VaultRegistry.
- postDeploy() gating: `postDeploy()` must be constrained to the Diamond Callback Factory lifecycle and tests must prove arbitrary EOAs/contracts cannot call `postDeploy()` to mutate state after deployment.

### Route ID: TGT-RICHIR-02
- Selector / Function: `transfer(address,uint256)` / `transferFrom(address,address,uint256)` / `approve(address,uint256)`
- Entry Context: Proxy -> delegatecall Target
- Auth: Permissionless (standard ERC20 allowance enforcement)
- State Writes: `RICHIRRepo` (shares mapping), `ERC20Repo` (allowances)
- External Calls: none
- Inputs: amount converted to shares at current rate; rejects 0-address endpoints
- Outputs: bool success
- Events: `Transfer`, `Approval`
- Invariants: share transfer preserves proportional value at current rate; emits `Transfer` with nominal amount
- Failure Modes: `ZeroAmount`, `InsufficientBalance`
- Tests Required: share conversion rounding edge cases; allowance spend; transfer emits expected amount
- Tests Required (additional, maintainer-confirmed for transfer):
  - `transfer` reverts when `amount` converts to zero shares at current rate (`ZeroAmount`).
  - `Transfer` event emitted with nominal `amount` (not shares).

### Route ID: TGT-RICHIR-03
- Selector / Function: `mintFromNFTSale(uint256,address)`
- Entry Context: Proxy -> delegatecall Target
- Auth: OwnerOnly (ProtocolDETF)
- State Writes: `RICHIRRepo` (mint shares, totalShares)
- External Calls: none
- Inputs: `lpShares>0`; recipient
- Outputs: `richirMinted` (computed at current rate)
- Events: `IRICHIR.Minted`, ERC20 `Transfer` (mint)
- Invariants: shares minted 1:1 with lpShares; balance minted scales with current rate
- Failure Modes: `ZeroAmount`
- Tests Required: owner-only; minted shares==lpShares; event values; totalShares increments

### Route ID: TGT-RICHIR-04
- Selector / Function: `redeem(uint256,address,bool)`
- Entry Context: Proxy -> delegatecall Target
- Auth: Permissionless
- State Writes: `RICHIRRepo` (transfer shares to ProtocolDETF)
- External Calls: `protocolDETF.exchangeIn` (tokenIn=RICHIR, tokenOut=WETH); reentrancy protected by `lock`
- Inputs: `richirAmount>0`; recipient defaults to msg.sender if address(0); `pretransferred` flag passed to exchangeIn
- Outputs: `wethOut` (via exchangeIn return)
- Events: `IRICHIR.Redeemed` (via downstream)
- Execution Outline: forward RICHIR shares to ProtocolDETF via `protocolDETF.exchangeIn(tokenIn=RICHIR, amountIn=richirAmount, tokenOut=WETH, recipient=recipient, pretransferred=pretransferred, minAmountOut=0)`; ProtocolDETF handles burn, seigniorage logic, and returns WETH amount
- Invariants: RICHIR is forwarded to ProtocolDETF for processing; WETH returned directly to recipient by ProtocolDETF
- Failure Modes: `ZeroAmount`, downstream ProtocolDETF exchangeIn reverts (e.g., slippage if minAmountOut>0)
- Tests Required: redeem forwards correctly to ProtocolDETF; pretransferred flag behavior; recipient default; reentrancy guard

### Route ID: TGT-RICHIR-05
- Selector / Function: `burnShares(uint256 richirAmount)`
- Entry Context: Proxy -> delegatecall Target; called by ProtocolDETF after transferring RICHIR to this contract
- Auth: OwnerOnly (ProtocolDETF)
- State Writes: `RICHIRRepo` (burn shares from `address(this)`)
- External Calls: none; reentrancy protected by `lock`
- Inputs: `richirAmount>0`
- Outputs: `sharesBurned`
- Events: ERC20 `Transfer` (burn from address(this))
- Execution Outline: ProtocolDETF transfers RICHIR to RICHIR contract; calls `burnShares(richirAmount)`; RICHIR computes shares via `_balanceToShares(richirAmount, rate)`; burns shares from `address(this)` (its own balance)
- Invariants: burns the transferred RICHIR balance; sharesBurned computed at current rate; no WETH transfer
- Failure Modes: `ZeroAmount`, `InsufficientBalance` (if transferred balance < richirAmount)
- Tests Required: only owner; verifies balance burned matches transferred amount; sharesBurned rounding

## postDeploy() / Post-deploy behavior
- PENDING-MAINTAINER-REVIEW
