### Target: contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactInQueryTarget.sol

## Intent
- Conservative exact-in quote surface for the Balancer V3 Standard Exchange Router. This Target implements `querySwapSingleTokenExactIn(...)` which delegates to the Balancer V3 Vault `quote(...)` flow and exposes a Vault-only hook `querySwapSingleTokenExactInHook(...)` used to simulate swaps deposit/withdraw flows.

Preview policy: exact-in previews must satisfy `previewOut <= executeOut` on the same on-chain state. Tests must include same-block checks that quoting via `querySwapSingleTokenExactIn(...)` returns an amount <= the amount actually delivered by the corresponding `swapSingleTokenExactIn(...)` execution for identical inputs and unchanged state. Any small rounding/1-wei slack used by downstream vault previews must be called out and fuzz-tested.

Routes:

- Route ID: TGT-BalancerRouterExactInQuery-01
  - Selector / Function: `querySwapSingleTokenExactIn(address pool, IERC20 tokenIn, IStandardExchangeProxy tokenInVault, IERC20 tokenOut, IStandardExchangeProxy tokenOutVault, uint256 exactAmountIn, address sender, bytes calldata userData)`
  - Entry Context: Proxy -> delegatecall Target; public external entrypoint
  - Auth: Permissionless (any caller may request a quote)
  - State Writes: None (delegates into Balancer `quote()` which executes a simulated hook call with transient accounting)
  - External Calls: calls `BalancerV3Vault.quote(...)` which may invoke the `querySwapSingleTokenExactInHook` callback restricted to Balancer Vault
  - Inputs: pool, tokenIn/tokenOut, vaults (or address(0)) and exactAmountIn; expects `userData` to encode any pool-specific parameters
  - Outputs: `amountOut` amount of tokenOut quoted
  - Invariants: must return conservative (pessimistic) amount such that `amountOut <= amountReceived` when executed; WETH sentinel handling: when pool == WETH sentinel and both tokens are WETH, returns exactAmountIn
  - Failure Modes: `InvalidRoute` (if route conditions unmatched in hook), underlying Balancer `quote()` reverts
  - Tests Required:
    - Unit: same-block parity `querySwapSingleTokenExactIn(...) <= swapSingleTokenExactIn(...)` for direct pool swap and each vault path
    - Access control: ensure `querySwapSingleTokenExactInHook` is only callable via Balancer Vault `quote()` (simulate unauthorized call -> revert)
    - Branch coverage: fuzz tests exercise all hook branches (Direct swap, Vault pass-through, Vault deposit, Vault withdrawal, Deposit+swap, Deposit+swap+withdrawal, Swap+withdrawal)

- Route ID: TGT-BalancerRouterExactInQuery-02
  - Selector / Function: `querySwapSingleTokenExactInHook(StandardExchangeSwapSingleTokenHookParams calldata params)`
  - Entry Context: Called by Balancer V3 Vault via `quote()` only
  - Auth: VaultOnly (`onlyBalancerV3Vault`) — must revert on external calls
  - State Writes: may read transient Balancer accounting; should not mutate persistent repo state
  - External Calls: may call downstream vault preview functions (`previewExchangeIn`/`previewExchangeOut`), and Balancer vault internal swap simulation
  - Inputs: hook params struct (sender, kind=EXACT_IN, pool, tokenIn, tokenInVault, tokenOut, tokenOutVault, amountGiven, limit, deadline, wethIsEth, userData)
  - Outputs: `amountCalculated` amountOut computed for the simulation
  - Invariants: hook must match the same branching logic used by the swap hook to ensure quote semantics mirror execution; special-case ETH <-> WETH sentinel returns amountGiven 1:1
  - Failure Modes: revert on Unauthorized caller (not Balancer Vault), `InvalidRoute` for unsupported param combinations
  - Tests Required:
    - Hook auth: assert only Balancer Vault can call the hook (direct external call reverts)
    - Branch parity: for each branch the hook returns the same arithmetic result as running the full on-chain swap flow (compare against settle/unlock flows in test harness)

Files to review when validating this table:

- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactInQueryTarget.sol`
- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterCommon.sol`
- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterRepo.sol`

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
