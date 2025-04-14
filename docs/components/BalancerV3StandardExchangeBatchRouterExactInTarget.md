### Target: contracts/protocols/dexes/balancer/v3/routers/batch/BalancerV3StandardExchangeBatchRouterExactInTarget.sol

## Intent
- Atomically execute multiple `exact-in` swaps in a single batch using Balancer V3 Vault batch/unlock semantics. This Target aggregates many `swapSingleTokenExactIn`-style operations and settles them under a single vault callback to reduce gas and ensure atomic composability.

Preview policy: batch exact-in previews must be conservative per-swap: each previewed `amountOut` in the batch must satisfy `previewOut <= executeOut` when executed on the same state. Tests must decompose batches into per-swap previews and assert per-swap inequalities; additionally, fuzz batch ordering and mixed-route combinations to ensure no batch ordering creates optimistic previews.

Routes:

- Route ID: TGT-BalancerBatchExactIn-01
  - Selector / Function: `batchSwapExactIn((pool,tokenIn,tokenInVault,tokenOut,tokenOutVault,amountIn,minAmountOut,deadline,wethIsEth,userData)[] swaps)`
  - Entry Context: Proxy -> delegatecall Target; permissionless
  - Auth: Permissionless
  - State Writes: Permit2 transfers for aggregated inputs, transient Balancer accounting via `unlock`/`swap`/`settle`, possible StandardExchange `exchangeIn` writes (when vault paths involved), WETH wrap/unwrap
  - External Calls: Permit2, Balancer V3 Vault batch/unlock, StandardExchange `exchangeIn` hooks, WETH
  - Inputs: array of swap descriptors; each swap has own `minAmountOut` and `deadline`; total gas must fit transaction
  - Outputs: per-swap `amountOut` array returned; overall batch must revert if any individual swap's `minAmountOut` fails
  - Invariants: atomicity (all swaps succeed or revert); per-swap `minAmountOut` enforced; per-swap exact-in preview inequality must hold; no partial state persisted on revert
  - Failure Modes: `SwapDeadline`, `MinAmountOutNotMet` for any swap, underlying vault/Balancer reverts, Permit2 transfer failures
  - Tests Required:
    - Unit: per-swap preview vs execution parity (`previewOut <= executeOut`) across randomized swap arrays
    - Integration: atomicity tests (one swap failing reverts full batch), mixed vault/pool combos, ETH sentinel handling in batches
    - Fuzz: varied swap lengths, boundary rounding where swaps interact on shared pools (ensure conservatism)

Files to review when validating this table:

- `contracts/protocols/dexes/balancer/v3/routers/batch/BalancerV3StandardExchangeBatchRouterExactInTarget.sol`
- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterCommon.sol`

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
