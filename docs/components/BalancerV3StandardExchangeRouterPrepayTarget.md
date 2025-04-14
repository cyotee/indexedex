### Target: contracts/protocols/dexes/balancer/v3/routers/prepay/BalancerV3StandardExchangeRouterPrepayTarget.sol

## Intent
- Execute/add/remove single-sided and proportional liquidity operations via a prepay relay to Balancer V3 Vault. This Target implements `prepayAddLiquidityUnbalanced` / `prepayRemoveLiquidityProportional` wrappers used by vaults and manager flows to move tokens into/out of Balancer with transient settlement semantics.

Preview policy: these are execution Targets (not preview), but any public query counterparts must simulate conservative outcomes. Tests must assert that prepay operations leave no stray vault shares and that rounding margins (1-wei) are respected where downstream Balancer math applies.

Routes:

- Route ID: TGT-BalancerRouterPrepay-01
  - Selector / Function: `prepayAddLiquidityUnbalanced(IERC20 token, uint256 amount, address pool, bytes userData)`
  - Entry Context: Proxy -> delegatecall Target; called by trusted vaults/packages
  - Auth: Permissionless (intended)
  - State Writes: transfers into Balancer Vault; may emit `PrepayAdd` events
  - External Calls: Permit2 transfers, Balancer Vault `swap`/`settle` calls, WETH wrapping
  - Invariants: caller must ensure token approvals/Permit2 wiring; final BPT credited to requested recipient; no leftover tokens remain in router
  - Failure Modes: Balancer vault reverts, Permit2 failures
  - Tests Required: integration tests with mocked Balancer Vault to assert correct settle/send flows, edge rounding cases for `calcBptOutGivenSingleIn` usage

- Route ID: TGT-BalancerRouterPrepay-02
  - Selector / Function: `prepayRemoveLiquidityProportional(address pool, uint256 bptAmount, address recipient)`
  - Entry Context: Proxy -> delegatecall Target
  - Auth: Permissionless (intended)
  - State Writes: transfers BPT into Balancer vault and triggers proportional exit; returns constituent tokens
  - External Calls: Balancer Vault `withdraw`/`settle`, Permit2 interactions
  - Invariants: exact proportional balancing; returned tokens match expected preview within rounding tolerances
  - Tests Required: proportional exit math under small/large bpt supplies; ensure no extra share residue

Files to review:

- `contracts/protocols/dexes/balancer/v3/routers/prepay/BalancerV3StandardExchangeRouterPrepayTarget.sol`
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
