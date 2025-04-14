### Target: contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactInSwapTarget.sol

## Intent
- Execute exact-in swaps routed through Balancer V3 Vault and pass-through to StandardExchange vaults where required. This Target implements `swapSingleTokenExactIn(...)` and the Balancer-only hook `swapSingleTokenExactInHook(...)` which performs the real token movements, calls into vault `exchangeIn` functions for wrap/unwrap, and settles via Balancer `settle()`/`sendTo()` semantics.

Preview policy: execution is not a preview; however, all corresponding query variants must be conservative (`querySwapSingleTokenExactIn(...)` must return amount <= swap execution). Tests must assert same-block inequality between query and execution for identical inputs and unchanged state.

Routes:

- Route ID: TGT-BalancerRouterExactInSwap-01
  - Selector / Function: `swapSingleTokenExactIn(address pool, IERC20 tokenIn, IStandardExchangeProxy tokenInVault, IERC20 tokenOut, IStandardExchangeProxy tokenOutVault, uint256 exactAmountIn, uint256 minAmountOut, uint256 deadline, bool wethIsEth, bytes calldata userData) payable returns (uint256 amountOut)`
  - Entry Context: Proxy -> delegatecall Target; permissionless; `saveSender` wrapper to capture original sender
  - Auth: Permissionless
  - State Writes: may transfer tokens via Permit2 to Balancer Vault or vaults; calls to StandardExchange `exchangeIn` may mint/burn/reserve changes in those vaults; Balancer Vault settles transiently then sends out tokens
  - External Calls: Balancer V3 Vault `unlock(...)/swap(...)/settle(...)/sendTo(...)`, Permit2 transfers, StandardExchange `exchangeIn` calls, WETH wrap/unwrap via WETH contract
  - Inputs: pool, tokenIn/tokenOut addresses and vault pointers, exactAmountIn, minAmountOut limit enforced in multiple spots, deadline
  - Outputs: `amountOut` delivered to sender or recipient
  - Invariants: deadline check (revert if expired), minAmountOut enforced at final unwrapping/transfer step, ETH/WETH sentinel special-case handled 1:1, reentrancy protected by `lock` within hook
  - Failure Modes: `SwapDeadline`, `MinAmountOutNotMet`, `InvalidRoute`, underlying Balancer swap reverts, underlying vault `exchangeIn` may revert
  - Tests Required:
    - Integration: full swap paths for each branch (direct Balancer swap, vault pass-through, vault deposit+swap, deposit+swap+withdrawal, swap+withdrawal) asserting final `amountOut >= minAmountOut` and tokens moved as expected
    - Edge cases: ETH wrap/unwrap sentinel behavior, refund ETH remainder path, Permit2 transfers and reentrancy guard
    - Same-block parity: compare against `querySwapSingleTokenExactIn(...)` for identical params

- Route ID: TGT-BalancerRouterExactInSwap-02
  - Selector / Function: `swapSingleTokenExactInHook(StandardExchangeSwapSingleTokenHookParams calldata params)` (only callable by Balancer Vault)
  - Entry Context: Called by Balancer Vault via `unlock(...)` hook
  - Auth: VaultOnly (`onlyBalancerV3Vault`) and protected by `lock` modifier
  - State Writes: transfers/approvals via Permit2, calls to vaults that may change vault accounting, may call `_weth.deposit`/`withdraw`
  - External Calls: Permit2 transfers, WETH contract, StandardExchange vault `exchangeIn`, Balancer Vault settle/sendTo
  - Inputs: hook params struct
  - Outputs: `amountCalculated` amount out per swap math
  - Invariants: hook must perform the same token movement and vault calls as the query hook simulates; final token transfers must satisfy `minAmountOut` checks
  - Failure Modes: unauthorized caller, `MinAmountOutNotMet`, underlying vault reverts
  - Tests Required:
    - Hook auth: ensure only Balancer Vault can call swap hook
    - Settlement invariants: after swap and settle, no stray vault shares remain; when ETH used, ETH remainder returned

Files to review when validating this table:

- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactInSwapTarget.sol`
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
