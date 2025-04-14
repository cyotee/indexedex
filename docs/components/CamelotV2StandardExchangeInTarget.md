### Target: contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeInTarget.sol

## Intent
- Exact-in exchanges for Camelot V2 StandardExchange vaults. Behavior mirrors UniswapV2 flows but enforces Camelot-specific pool constraints (rejects stableSwap pools). Preview parity expectations are identical to Uniswap case.

Preview policy: exact-in previews MUST satisfy `previewOut <= executeOut` on identical state. Tests must include Camelot-specific fee and pool validation scenarios.

Routes (summary):

- Route ID: TGT-Camelot-SE-In-01 — Pass-through Swap
  - Description: Swap via Camelot router; preview uses analogous ConstProdUtils math
  - Tests: preview vs execute parity; ensure stable pools rejected by processArgs/init

- Route ID: TGT-Camelot-SE-In-02 — ZapIn / LP mint
  - Description: Swap+deposit into pool token; preview uses quoteSwapDepositWithFee
  - Tests: fee-on scenarios; pretransferred/pull paths

- Route ID: TGT-Camelot-SE-In-03 — Vault Deposit / ZapIn Vault Deposit
  - Description: same as Uniswap vault deposit flows, adapted to Camelot
  - Tests: composed preview parity; vault-share minting checks

Files to review:
- `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeInTarget.sol`
- `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeCommon.sol`

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
