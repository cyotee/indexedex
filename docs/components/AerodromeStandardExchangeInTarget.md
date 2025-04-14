### Target: contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeInTarget.sol

## Intent
- Exact-in exchanges for Aerodrome (Solidly-style) pools. Handles swaps, zap-in/out, and vault deposit/withdraw flows while preserving ERC4626 share invariants and decimal constraints.

Preview policy: exact-in previews MUST satisfy `previewOut <= executeOut`. Because Aerodrome pools may use different fee math and decimals, tests must cover decimal-offset & share conversion edge cases.

Routes (summary):

- Route ID: TGT-Aero-SE-In-01 — Pass-through Swap
  - Description: swap within Aerodrome pool; preview uses ConstProdUtils/_saleQuote-like math adapted to pool model
  - Tests: preview parity; ensure fee handling matches pool implementation

- Route ID: TGT-Aero-SE-In-02 — ZapIn / LP mint
  - Description: swap+deposit into pool token; preview composes swap quote + vault deposit math
  - Tests: preview parity; deposit share math with decimal offsets

- Route ID: TGT-Aero-SE-In-03 — Vault Deposit / ZapIn Vault Deposit
  - Tests: vault share calculations and minted shares checks; pretransferred handling

Files to review:
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeInTarget.sol`
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol`

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
