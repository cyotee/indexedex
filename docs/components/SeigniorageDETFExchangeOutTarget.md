### Target: contracts/vaults/seigniorage/SeigniorageDETFExchangeOutTarget.sol

## Intent
- Exact-out exchange entrypoints for Seigniorage DETF: requests that specify exact desired output amounts (withdraw/proportional exits) and the code paths to satisfy them while preserving peg and seigniorage invariants.

Preview policy: exact-out previews must satisfy `previewIn >= executeIn` on the same on-chain state. Tests must assert `previewExchangeOut(...) >= exchangeOut(...)` (same-block), and fuzz/invariant tests must cover rounding buffers used by Balancer proportional-exit math.

Routes:

- Route ID: TGT-SeigniorageDETFExchangeOut-01
  - Selector / Function: `previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)` (view) / corresponding `exchangeOut` exact-out entry
  - Entry Context: Proxy -> delegatecall Target; permissionless
  - Auth: Permissionless
  - State Writes: reads `SeigniorageDETFRepo` config; execution writes burn/mint or transfers depending on route
  - External Calls: Balancer math and `prepayRemoveLiquidityProportional`, `reserveVault.previewExchangeOut`/`reserveVault.exchangeOut` for constituent conversions; reentrancy protected by `lock` where state changes occur
  - Inputs: `tokenOut` desired amount; `tokenIn` can be DETF or reserve-vault token depending on route; `deadline` enforced
  - Outputs: `amountIn` required to get `amountOut`
  - Events: downstream transfer events, ERC20 burns/mints as applicable
  - Execution Outline (canonical exact-out burn/unwind):
    1. Load pool state and diluted price.
    2. Ensure route validity (e.g., exact-out for DETF→reserve constituent requires dilutedPrice < peg when burning DETF).
    3. Compute required DETF input using `WeightedMath` inverted formulas under reduced-fee semantics and using Balancer `calcBptInGivenProportionalOut` for proportional exits.
    4. Transfer/withdraw BPT via `prepayRemoveLiquidityProportional` when needed.
    5. Convert reserveVault tokens to desired `tokenOut` via reserveVault `exchangeOut`/`exchangeIn` paths.
    6. Enforce `amountIn <= maxAmountIn` on execution; preview must be pessimistic (`previewIn >= executeIn`).
  - Invariants: exact-out routes must ensure sufficient liquidity; peg gates apply where appropriate; protocol must not leave residual vault shares after execution
  - Failure Modes: `PriceAbovePeg` / `PriceBelowPeg` depending on route, `InsufficientLiquidity`, `MinAmountNotMet` (inverted to max checks), downstream router/balancer failures
- Tests Required:
    - Preview vs execute parity tests for exact-out routes (`previewIn >= executeIn`).
    - Integration tests exercising proportional exit calculations and `calcBptInGivenProportionalOut` with edge rounding; require fuzz tests proving preview conservatism.
    - Loupe-driven selector surface check: ensure that any composite proxy routing this Target does not expose unexpected selectors (match `facetInterfaces()` to runtime selectors).

- Route ID: TGT-SeigniorageDETFExchangeOut-02
  - Selector / Function: exact-out path when `tokenIn` is reserve-vault token and `tokenOut` is DETF (mint exact-out)
  - Execution Outline:
    1. Validate peg > 1 for mint exact-out; compute required reserveVault shares using `WeightedMath` inverse logic.
    2. Use `prepayAddLiquidityUnbalanced` to add single-sided liquidity if needed (exact-out mint may be complex; the code relies mostly on exact-in flows, test mapping carefully).
  - Tests Required: confirm whether code exposes exact-out mint or only exact-in; if exact-out is present, add parity tests and inversion correctness tests.

- Route ID: TGT-SeigniorageDETFExchangeOut-03
  - Selector / Function: exact-out for DETF→reserve constituent (DETF burn exact-out)
  - Execution Outline:
    1. Compute DETF required using inverse of `WeightedMath.computeOutGivenExactIn` with fee reductions applied.
    2. Burn DETF, compute expected BPT for proportional exit, call `prepayRemoveLiquidityProportional`, convert to desired token via reserveVault.exchangeIn
  - Tests Required: preview vs execute parity, edge-case rounding, and ensuring `redepositUnusedTokens` doesn't cause shortfall

- Route ID: TGT-SeigniorageDETFExchangeOut-04
  - Selector / Function: DETF↔sRBT exact-out (1:1)
  - Execution Outline: conversions are 1:1 when price conditions met; previewIn must be >= executeIn = amountOut (i.e., require at most amountIn equal to amountOut); tests assert boundary peg conditions

Other notes:

- The Seigniorage DETF codebase favors exact-in flows; exact-out support uses Balancer proportional exit inversion functions and may compose reserveVault exact-out functions. Review whether any exact-out mint routes are actually reachable or are only supported via preview helpers — tests must reflect live behavior.
- Preview buffers: proportional exits and Balancer math sometimes require 1-wei tolerances; any buffer applied must be tested using fuzz with assertions proving preview conservatism.

Files to review when validating this table:

- `contracts/vaults/seigniorage/SeigniorageDETFExchangeOutTarget.sol`
- `contracts/vaults/seigniorage/SeigniorageDETFRepo.sol`
- `contracts/vaults/seigniorage/SeigniorageDETFCommon.sol`
- `contracts/protocols/dexes/balancer/v3/utils/BalancerV38020WeightedPoolMath.sol`

## Validation
- PENDING-MAINTAINER-REVIEW

Repo-wide invariants (copy from PROMPT.md):
- Preview policy: exact-in previews must satisfy `previewOut <= executeOut`; exact-out previews must satisfy `previewIn >= executeIn` on the same on-chain state. Tests must compare preview and execution on the same state and include fuzz/invariant checks for any rounding buffers.
- Deterministic deployments: production deploys MUST use Crane CREATE3 + Diamond Package Callback Factory; do NOT use `new()` in production deploy paths. Any deploy-with-initial-deposit helpers require adversarial front-run deployment tests.
- Permit2: routers MUST enforce Permit2; vaults should prefer Permit2. Any ERC20 approve/transferFrom fallback must be explicitly documented and covered by tests where permitted.
- No cached rates: rate/redemption values used in accounting MUST be computed fresh on every call; avoid stale cached rates without explicit invalidation and tests.
- Vault gating: vault packages MUST gate `processArgs()` to `IVaultRegistryDeployment` for all vaults intended to be discoverable via the VaultRegistry.
- postDeploy() gating: `postDeploy()` must be constrained to the Diamond Callback Factory lifecycle and tests must prove arbitrary EOAs/contracts cannot call `postDeploy()` to mutate state after deployment.

## postDeploy() / Post-deploy behavior
- PENDING-MAINTAINER-REVIEW
