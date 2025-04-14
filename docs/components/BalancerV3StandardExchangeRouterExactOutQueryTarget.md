### Target: contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactOutQueryTarget.sol

## Intent
- Conservative exact-out quote surface for the Balancer V3 Standard Exchange Router. Implements `querySwapSingleTokenExactOut(...)` delegating to Balancer `quote(...)` and a Vault-only hook `querySwapSingleTokenExactOutHook(...)` which simulates required input amounts for exact output.

Preview policy: exact-out previews must satisfy `previewIn >= executeIn` on the same on-chain state. Tests must assert `querySwapSingleTokenExactOut(...) >= swapSingleTokenExactOut(...)` (i.e., preview requires at least the execute input). Any rounding/ceil math must be validated with fuzz/invariant tests.

Routes:

- Route ID: TGT-BalancerRouterExactOutQuery-01
  - Selector / Function: `querySwapSingleTokenExactOut(address pool, IERC20 tokenIn, IStandardExchangeProxy tokenInVault, IERC20 tokenOut, IStandardExchangeProxy tokenOutVault, uint256 exactAmountOut, address sender, bytes calldata userData)`
  - Entry Context: Proxy -> delegatecall Target; public
  - Auth: Permissionless
  - State Writes: None
  - External Calls: Balancer `quote(...)` and downstream vault preview functions
  - Inputs: exactAmountOut and route params
  - Outputs: `amountIn` (required input amount)
  - Invariants: must be conservative (ceilings applied where required) so execution with returned `amountIn` yields at least `exactAmountOut`
  - Failure Modes: `InvalidRoute`, downstream preview reverts
  - Tests Required:
    - Same-block inequality: `previewIn >= executeIn` across branch types
    - Ceiling math correctness: test rounding boundaries and ensure preview does not understate required input

- Route ID: TGT-BalancerRouterExactOutQuery-02
  - Selector / Function: `querySwapSingleTokenExactOutHook(StandardExchangeSwapSingleTokenHookParams calldata params)`
  - Entry Context: Balancer Vault `quote()` callback only
  - Auth: VaultOnly
  - State Writes: None
  - External Calls: vault preview helpers
  - Inputs: hook params
  - Outputs: `amountCalculated` required input amount
  - Invariants: hook must mirror swap hook branches; must handle vault deposit/withdraw previews correctly
  - Tests Required: hook auth; branch parity and rounding/ceiling correctness

Files to review:

- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactOutQueryTarget.sol`
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
