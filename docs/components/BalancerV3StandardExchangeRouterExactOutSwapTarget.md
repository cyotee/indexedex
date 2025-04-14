### Target: contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactOutSwapTarget.sol

## Intent
- Execute exact-out swaps routed through Balancer V3 Vault. This Target accepts user-specified maximum input and desired exact output, coordinates Balancer swaps and StandardExchange vault unwraps/withdrawals, and enforces exact-out invariants.

Preview policy: matching query target must be conservative (`previewIn >= executeIn`). Execution must enforce `amountIn <= maxAmountIn` and revert otherwise. Tests must include same-block comparisons between `querySwapSingleTokenExactOut` and execution.

Routes:

- Route ID: TGT-BalancerRouterExactOutSwap-01
  - Selector / Function: `swapSingleTokenExactOut(...)` — exact-out execution entrypoint
  - Entry Context: Proxy -> delegatecall Target; permissionless
  - Auth: Permissionless
  - State Writes: Permit2 transfers, calls to StandardExchange `exchangeIn`/`exchangeOut`, Balancer Vault operations (`swap`, `settle`, `sendTo`), WETH wrap/unwrap
  - External Calls: Permit2, Balancer Vault, StandardExchange vaults, WETH
  - Inputs: pool, tokens/vaults, exactAmountOut, maxAmountIn, deadline, wethIsEth, userData
  - Outputs: `amountIn` consumed (must be <= maxAmountIn)
  - Invariants: final delivered `exactAmountOut` to recipient; consume at most `maxAmountIn`; revert with `MaxAmountInExceeded` or `MinAmountOutNotMet` per internal checks
  - Failure Modes: deadline, insufficient input (preview underestimated or slippage), underlying vault reverts
  - Tests Required:
    - Integration: exact-out across branches, assert `amountIn <= maxAmountIn` and recipient gets `exactAmountOut`
    - Round-trip: `querySwapSingleTokenExactOut(...) >= swapSingleTokenExactOut(...)`
    - Edge cases: WETH sentinel, vault pass-through rounding, Permit2 flows

- Route ID: TGT-BalancerRouterExactOutSwap-02
  - Selector / Function: `swapSingleTokenExactOutHook(...)` — Balancer-only hook performing the simulated & executed path
  - Entry Context: Balancer Vault `unlock(...)` / `swap(...)` only
  - Auth: VaultOnly
  - State Writes: transient Balancer accounting; transfers via settle/sendTo
  - External Calls: vault `exchangeOut`/`exchangeIn` as required
  - Invariants: must implement same logic as query hook but in a stateful fashion and perform final transfers
  - Tests Required: hook auth; settlement invariants; reentrancy protections; exact-out ceilings/ceilings/rounding tests

Files to review:

- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactOutSwapTarget.sol`
- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterCommon.sol`

## Validation
- (leave untagged until maintainer confirmation)

Repo-wide invariants applied: see PROMPT.md

- Preview policy: exact-in previews must satisfy `previewOut <= executeOut`; exact-out previews must satisfy `previewIn >= executeIn`. Tests must compare preview and execution on the same on-chain state and include fuzz/invariant checks for any rounding buffers.
- Deterministic deployments: production deploys must use Crane CREATE3 + Diamond Package Callback Factory; do NOT use `new()` in production deploy paths. Adversarial front-run deployment tests required for any deploy-with-initial-deposit helpers.
- Permit2: routers MUST enforce Permit2; vaults should prefer Permit2 and may document ERC20 `approve` fallback where explicitly permitted and tested.
- No cached rates: rate/redemption providers used in accounting must compute fresh values each call; avoid stale cached rates without explicit invalidation and tests.
- Vault gating: vault packages MUST gate `processArgs()` to `IVaultRegistryDeployment` (registry-first model) for all vaults intended to be discoverable.
- Post-deploy safety: `postDeploy()` hooks may contain wiring logic but must only be callable by the deterministic factory callback during deployment; tests must prove arbitrary EOAs/contracts cannot invoke `postDeploy()` to mutate state.

## postDeploy() / Post-deploy behavior
- PENDING-MAINTAINER-REVIEW
