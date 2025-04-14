### Targets: Balancer V3 Batch Routers

## Intent
- Batch exact-in and exact-out router surfaces for multi-swap/batch operations. These Targets provide convenience multi-swap flows that coordinate many `swapSingleTokenExactIn` or `swapSingleTokenExactOut` calls atomically via Balancer V3 Vault batching.

Preview policy: each batch must be decomposed in tests into per-swap previews and the global batch preview must remain conservative relative to execution. Exact-in previews: `previewOut <= executeOut` per swap. Exact-out previews: `previewIn >= executeIn` per swap.

Routes (high level):

- `contracts/protocols/dexes/balancer/v3/routers/batch/BalancerV3StandardExchangeBatchRouterExactInTarget.sol`
  - Purpose: atomically execute multiple exact-in swaps; use Balancer batch unlocking under a single vault callback
  - Key invariants: per-swap minAmountOut enforced; reentrancy locked; batch atomicity (either all succeed or revert)
  - Tests: batch atomicity, mixed-route coverage, same-block previews vs execution per swap

- `contracts/protocols/dexes/balancer/v3/routers/batch/BalancerV3StandardExchangeBatchRouterExactOutTarget.sol`
  - Purpose: atomically execute multiple exact-out swaps with per-swap maxAmountIn ceilings
  - Key invariants: per-swap ceiling enforcement; total gas/settle mechanics do not leave partial state
  - Tests: ceiling enforcement, batch revert behavior, multi-route preview accuracy

Files to review:

- both batch router targets under `contracts/protocols/dexes/balancer/v3/routers/batch/`

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
