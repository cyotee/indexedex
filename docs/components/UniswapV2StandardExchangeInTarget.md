### Target: contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInTarget.sol

## Intent
- Exact-in entrypoints for UniswapV2-style StandardExchange vaults (pass-through swaps, zap-in/out, vault deposit/withdraw). Previews mirror the on-chain math (ConstProd/UniswapV2 formulas) so preview<=execute must hold for exact-in flows.

Preview policy: exact-in previews MUST satisfy `previewOut <= executeOut` on identical state. Tests must call `previewExchangeIn(...)` then `exchangeIn(...)` in the same block and assert the inequality holds for all supported routes.

Routes (summary):

- Route ID: TGT-UniV2-SE-In-01 — Pass-through Swap
  - Selector / Function: `previewExchangeIn` / `exchangeIn`
  - Auth: Permissionless
  - Description: Swap tokenA↔tokenB using underlying Uniswap pair via router; preview uses pool reserves and ConstProdUtils._saleQuote
  - Failure Modes: `MinAmountNotMet`, deadline, router reverts
  - Tests: preview vs execute parity; router slippage paths; pretransferred vs pull flows

- Route ID: TGT-UniV2-SE-In-02 — Pass-through ZapIn / LP mint via swap+deposit
  - Description: Swap constituent → LP token (pool token) via router swap+deposit flow; preview uses _quoteSwapDepositWithFee
  - Tests: preview parity; fee-on/factory fee toggle scenarios (feeTo != address(0))

- Route ID: TGT-UniV2-SE-In-03 — Vault Deposit (LP token → vault shares)
  - Description: Deposit pool token into vault (ERC4626-style shares mint). preview computes shares against post-deposit reserve to match execution
  - Tests: shares calculation edge cases; post-deposit reserve handling

- Route ID: TGT-UniV2-SE-In-04 — ZapIn Vault Deposit (constituent → vault shares via swap)
  - Description: Combines ZapIn quote + deposit; preview composes upstream preview from swap + local deposit math
  - Tests: composed preview parity; pretransferred handling

Files to review:
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInTarget.sol`
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol`
- `contracts/vaults/ConstProdReserveVaultRepo.sol`

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
