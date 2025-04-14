### Target: contracts/protocols/dexes/balancer/v3/routers/prepay/BalancerV3StandardExchangeRouterPrepayHooksTarget.sol

## Intent
- Balancer V3 Vault-only hooks used during `quote`/`unlock`/`swap` flows to initialize, add liquidity, and remove liquidity on behalf of callers using the prepay relay. These hooks are invoked by the Balancer Vault and implement `prepayInitializeHook`, `prepayAddLiquidityHook`, and `prepayRemoveLiquidityHook` behaviors.

Auth model: Vault-only (`onlyBalancerV3Vault`) — these functions must only be callable via the Balancer V3 Vault during its `quote`/`unlock` hooks. Tests must assert these entrypoints revert when called directly by non-vault callers.

Routes:

- Route ID: TGT-BalancerPrepayHooks-01
  - Selector / Function: `prepayInitializeHook(InitializeHookParams calldata params)`
  - Entry Context: only Balancer Vault (callback during `initialize`/`quote`)
  - Auth: VaultOnly
  - State Writes: calls `IVault.initialize(...)` which mints BPT and then calls `settle` to settle prepaid token credits
  - External Calls: Balancer `IVault.initialize`, `IVault.settle` for each token
  - Invariants: `settle` must be called for each token to account for prepaid deposits; refunds (tokenInCredit - amountIn) are returned to sender where applicable
  - Failure Modes: `InsufficientPayment` if `settle` returns < hinted amount; underlying Vault `initialize` reverts
  - Tests Required: vault-only auth; asserts `settle` behaviour and refunds; edge-case when token amounts are zero

- Route ID: TGT-BalancerPrepayHooks-02
  - Selector / Function: `prepayAddLiquidityHook(AddLiquidityHookParams calldata params)`
  - Entry Context: only Balancer Vault (callback during `addLiquidity`/`quote`)
  - Auth: VaultOnly
  - State Writes: calls `IVault.addLiquidity(...)`, then `settle` per token, computes refund to sender if `tokenInCredit > amountIn`
  - External Calls: `IVault.addLiquidity`, `IVault.getPoolTokens`, `IVault.settle`, `_sendTokenOut` to refund
  - Invariants: `InsufficientPayment` revert if credit < maxAmountsIn hint; refunds handled correctly; ETH/WETH handling via `wethIsEth` flags (router-level wrap/unwrap managed by router)
  - Failure Modes: `InsufficientPayment`, underlying Vault reverts
  - Tests Required: vault-only auth; refund math; correctness of `amountsIn` array mapping to tokens; ETH/ WETH refund semantics

- Route ID: TGT-BalancerPrepayHooks-03
  - Selector / Function: `prepayRemoveLiquidityHook(RemoveLiquidityHookParams calldata params)`
  - Entry Context: only Balancer Vault
  - Auth: VaultOnly
  - State Writes: calls `IVault.removeLiquidity(...)` and then sends out token amounts via `_sendTokenOut`
  - External Calls: `IVault.removeLiquidity`, `IVault.getPoolTokens`
  - Invariants: `amountsOut` mapping must match tokens in pool; `_sendTokenOut` invoked with correct `wethIsEth` semantics
  - Failure Modes: underlying Vault reverts
  - Tests Required: vault-only auth; per-token outputs; wethIsEth handling

Files to review when validating this table:

- `contracts/protocols/dexes/balancer/v3/routers/prepay/BalancerV3StandardExchangeRouterPrepayHooksTarget.sol`
- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterPrepayTarget.sol`

## Validation
- (leave untagged until maintainer confirmation)

Repo-wide invariants applied: see PROMPT.md

- Preview policy: exact-in previews must satisfy `previewOut <= executeOut`; exact-out previews must satisfy `previewIn >= executeIn`. Tests must compare preview and execution on the same on-chain state.
- Deterministic deployments: production deploys must use Crane CREATE3 + Diamond Package Callback Factory; do NOT use `new()` in production deploy paths. Adversarial front-run deployment tests required for any deploy-with-initial-deposit helpers.
- Permit2: routers MUST enforce Permit2; vaults should prefer Permit2 and may document ERC20 `approve` fallback where explicitly permitted and tested.
- No cached rates: rate/redemption providers used in accounting must compute fresh values each call; avoid stale cached rates without explicit invalidation and tests.
- Vault gating: vault packages MUST gate `processArgs()` to `IVaultRegistryDeployment` (registry-first model) for all vaults intended to be discoverable.
- Post-deploy safety: `postDeploy()` hooks may contain wiring logic but must only be callable by the deterministic factory callback during deployment; tests must prove arbitrary EOAs/contracts cannot invoke `postDeploy()` to mutate state.

## postDeploy() / Post-deploy behavior
- PENDING-MAINTAINER-REVIEW
