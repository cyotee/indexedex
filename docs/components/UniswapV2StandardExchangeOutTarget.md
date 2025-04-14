### Target: contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol

## Intent
- Exact-out entrypoints for UniswapV2-style StandardExchange vaults (withdraw/swap exact-out). Previews must be conservative: previewIn >= executeIn for exact-out flows.

Preview policy: exact-out previews MUST satisfy `previewIn >= executeIn` on identical state. Tests must assert same-block parity and cover rounding/dust edges.

Routes (summary):

- Route ID: TGT-UniV2-SE-Out-01 — Pass-through Swap Exact-Out
  - Selector / Function: `previewExchangeOut` / `exchangeOut`
  - Auth: Permissionless
  - Description: Quote required input for exact output using UniswapV2 math (reverse of saleQuote); preview computes pessimistic input
  - Tests: previewIn >= executeIn; slippage enforcement; deadline handling

- Route ID: TGT-UniV2-SE-Out-02 — ZapOut Exact-Out (LP → token exact-out)
  - Description: Withdraw LP tokens → pool token + swap to desired token; preview composes vault withdrawal math + swap inversion
  - Tests: composed preview parity; rounding/dust tests

- Route ID: TGT-UniV2-SE-Out-03 — Vault Withdrawal Exact-Out
  - Description: Convert shares back to LP assets then swap/withdraw to desired token; preview uses BetterMath conversions and vault reserves
  - Tests: preview parity; share->asset conversion edge cases

Files to review:
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol`
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol`

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
