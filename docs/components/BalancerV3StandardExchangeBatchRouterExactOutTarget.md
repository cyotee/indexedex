### Target: contracts/protocols/dexes/balancer/v3/routers/batch/BalancerV3StandardExchangeBatchRouterExactOutTarget.sol

## Intent
- Atomically execute multiple `exact-out` swaps in a single batch using Balancer V3 Vault batching. Each swap specifies desired exact output and a per-swap `maxAmountIn` ceiling.

Preview policy: for exact-out batch previews, each `previewIn` must satisfy `previewIn >= executeIn` when executed on same state. Tests must assert per-swap ceiling conservatism and batch-level resource constraints.

Routes:

- Route ID: TGT-BalancerBatchExactOut-01
  - Selector / Function: `batchSwapExactOut((pool,tokenIn,tokenInVault,tokenOut,tokenOutVault,amountOut,maxAmountIn,deadline,wethIsEth,userData)[] swaps)`
  - Entry Context: Proxy -> delegatecall Target; permissionless
  - Auth: Permissionless
  - State Writes: aggregated Permit2 transfers, Balancer Vault batch swap/settle, StandardExchange `exchangeOut`/`exchangeIn` writes
  - External Calls: Permit2, Balancer V3 Vault batch/unlock, StandardExchange vaults, WETH
  - Inputs: array of exact-out swaps with per-swap maxAmountIn ceilings
  - Outputs: per-swap `amountIn` consumed; ensure each `amountIn <= maxAmountIn`
  - Invariants: if any swap requires `amountIn > maxAmountIn`, batch reverts; atomicity; per-swap preview conservatism
  - Failure Modes: `MaxAmountInExceeded`, `SwapDeadline`, underlying reverts
  - Tests Required:
    - Unit: per-swap previewIn >= executeIn across fuzzed amounts
    - Integration: batch ceilings enforced and atomicity checks
    - Edge: multiple swaps against same pool in one batch (ordering and conservatism)

Files to review:

- `contracts/protocols/dexes/balancer/v3/routers/batch/BalancerV3StandardExchangeBatchRouterExactOutTarget.sol`

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
