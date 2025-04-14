AerodromeStandardExchangeDFPkg

## Intent
- Deploy and configure StandardExchange vaults that integrate with Aerodrome V1 pools. Offers the same StandardExchange vault surface as Uniswap/Camelot but with Aerodrome-specific pool and decimal handling.

What this package configures
## Proxy
- `IStandardExchangeProxy` (immutable StandardExchange vault proxy)
- Facets (high level): ERC20/ERC2612/ERC5267/ERC4626 composition, Standard vault accounting, Aerodrome exchange-in/out facets, preview helpers, fee-oracle wiring, Permit2 awareness, reserve-vault repo wiring.

## Facets
- `ERC20_FACET`
- `ERC5267_FACET`
- `ERC2612_FACET`
- `ERC4626_FACET`
- `ERC4626_BASIC_VAULT_FACET`
- `ERC4626_STANDARD_VAULT_FACET`
- `AERODROME_STANDARD_EXCHANGE_IN_FACET`
- `AERODROME_STANDARD_EXCHANGE_OUT_FACET`

## Trust boundaries
- Deployment / init: this package is intended to be deployed via the Diamond Callback Factory through `IVaultRegistryDeployment` / IndexedexManager (registry-first). Direct manual/EOA deployments are discouraged — the registry/factory flow is the production deployment pattern.

- `processArgs()`: validates package arguments and enforces registry-only invocation. The implementation reverts with `NotCalledByRegistry(msg.sender)` unless called by the configured `VAULT_REGISTRY_DEPLOYMENT`. It also validates that the provided `reserveAsset` is an Aerodrome V1 pool (via `AERODROME_POOL_FACTORY.isPool`) and will revert with `NotAerodromeV1Pool` otherwise. Additionally, it rejects stable Aerodrome pools and will revert with `PoolMustNotBeStable` if the provided `reserveAsset` is stable. Implementations should document these guards and tests must assert all behaviors.

- Administrative actions / child deployments: this package contains no runtime administration functions and does not create child vaults during deployment.

- Immutability: production instances are immutable proxies deployed via the Diamond Callback Factory and must not expose `IDiamondCut`.

## Initialization
- `initAccount()` responsibilities: initialize ERC20 metadata and EIP712 domain, set ERC4626 reserve parameters, wire StandardVaultRepo pointers, configure the fee oracle, record the Aerodrome pool reference, and (optionally) set Permit2 operator approvals / reserve-vault repo entries where applicable.

- Access control: `initAccount()` does not require special access-control restrictions — implementations should not assume a privileged caller. It must validate inputs and be safe when invoked by the factory/manager deployment flow.

- Constraints: enforce share decimals <= 18 and ensure ERC4626 decimal offset correctness (see PROMPT.md guidance).

Post-deploy behavior (`postDeploy()`)
- This package does not implement any post-deploy behavior. `postDeploy()` is not used and no post-deploy callbacks are expected for production deployments.

Runtime invariants & mainnet requirements
- Vault proxy MUST be immutable (must NOT expose `IDiamondCut`).
- `processArgs()` gating mandatory; share decimals constraint must be enforced.
- Permit2 preferred, approve fallback allowed at contract layer.

Repo-wide invariants to copy from PROMPT.md (apply to this package)
- Preview policy: enforce exact-in/exact-out preview inequalities and fuzz-test previews vs execution for multi-hop routes.
- Deterministic deployments: use Crane Diamond Callback Factory; include adversarial front-run tests for any deploy-with-initial-deposit helpers.
- Permit2 guidance: prefer Permit2 for user-facing flows; fallback allowed at contract layer but router flows should prefer Permit2 per PROMPT.md.

Deterministic salts & squatting guidance
- Use Diamond Callback Factory deterministic flow only. Deploy-with-initial-deposit helpers require adversarial front-run tests.

## Required tests / Reviewer responsibilities
- This document does not prescribe specific test names. Instead, a reviewer assigned to this package must confirm that existing tests adequately cover the package responsibilities and are high quality (clear assertions, deterministic, not redundant). At minimum, the reviewer should verify tests covering:
  - Production deployment pattern (CREATE3 + Diamond Callback Factory via `VAULT_REGISTRY_DEPLOYMENT`) and that unauthorized/EOA deployment attempts are rejected.
  - `processArgs()` behavior: registry-only invocation, Aerodrome pool validation (`NotAerodromeV1Pool`), and stable-pool rejection (`PoolMustNotBeStable`).
  - `initAccount()` initialization results: ERC20 metadata, EIP712 domain, ERC4626 parameters, StandardVaultRepo wiring, fee-oracle wiring, Permit2 awareness, and pool metadata wiring.
  - Preview vs execution parity for deploy-with-deposit flows (`previewDeployVault()` vs `deployVault(...)`), including proportional calculations and expected LP token accounting.
  - Decimal edge cases and share-decimal constraints (share decimals <= 18, ERC4626 decimal offsets).
  - Reserve deposit/withdraw integration with Aerodrome pools and correctness of `exchangeIn`/`exchangeOut` flows.

- Reviewer output: for each area above, the reviewer must record whether coverage is `Adequate` / `Partial` / `Missing`, list the relevant test files/functions, and note any gaps or flaky/non-deterministic tests. The reviewer should also provide exact commands to reproduce failing or flaky tests.

## Validation
- 
- Inventory reference: `docs/components/AerodromeStandardExchangeDFPkg.md`
- PROMPT.md placeholder: `PENDING-MAINTAINER-REVIEW`

## postDeploy() / Post-deploy behavior
- None. This package does not define or require `postDeploy()`.
