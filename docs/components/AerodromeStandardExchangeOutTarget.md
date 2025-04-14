### Target: contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeOutTarget.sol

## Intent
- Exact-out exchanges for Aerodrome pools and vaults. Previews must be conservative (previewIn >= executeIn) and account for Aerodrome fee math.

Preview policy: exact-out previews MUST satisfy `previewIn >= executeIn` on identical state. Tests must include decimal/precision fuzzing and refund correctness.

Routes (summary):

- Route ID: TGT-Aero-SE-Out-01 — Swap Exact-Out
- Route ID: TGT-Aero-SE-Out-02 — ZapOut Exact-Out
- Route ID: TGT-Aero-SE-Out-03 — Vault Withdrawal Exact-Out

Tests Required: preview parity, slippage enforcement, decimal-offset edge cases, integration with vault share accounting

Files to review:
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeOutTarget.sol`

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
