UniswapV2StandardExchangeDFPkg

## Intent
- Deploy and configure StandardExchange vaults that integrate with Uniswap V2 style pairs. Provides ERC20/ERC2612/ERC5267/ERC4626-compatible vault proxies wrapping LP positions and exchange-in/out logic.

What this package configures
## Proxy
- `IStandardExchangeProxy` (immutable StandardExchange vault proxy)
- Facets (high level): ERC20/ERC2612/ERC5267/ERC4626 composition, Standard vault accounting, UniswapV2 exchange-in/out facets, preview helpers, fee-oracle wiring, Permit2 awareness, reserve-vault repo wiring.

## Facets
- `ERC20_FACET`
- `ERC5267_FACET`
- `ERC2612_FACET`
- `ERC4626_FACET`
- `ERC4626_BASIC_VAULT_FACET`
- `ERC4626_STANDARD_VAULT_FACET`
- `UNISWAP_V2_STANDARD_EXCHANGE_IN_FACET`
- `UNISWAP_V2_STANDARD_EXCHANGE_OUT_FACET`

## Trust boundaries
- MUST revert unless called by `IVaultRegistryDeployment`. Vault packages are required to enforce registry-first deployments to preserve indexing and trust boundaries.

## Initialization
- Must initialize ERC20 metadata and EIP712 domain, ERC4626 reserve parameters, StandardVaultRepo pointers, fee oracle configuration, Uniswap V2 router/factory addresses, Permit2 operator approvals for safe deposit/withdraw flows, and reserve-vault repo entries.

Post-deploy behavior (`postDeploy()`)
- Vault packages typically have limited `postDeploy()` logic. If present, it must be constrained to the Diamond Callback Factory lifecycle and tested to ensure no arbitrary caller can mutate state after deployment. Any child deployments triggered must register through `IVaultRegistryDeployment` if they are vaults.

Runtime invariants & mainnet requirements
- Vault proxy MUST be immutable (must NOT expose `IDiamondCut`).
- `processArgs()` enforced gating is mandatory for mainnet; `initAccount()` must leave no uninitialized critical fields.
- Permit2 is preferred for user-facing deposit/withdraw flows; ERC20 approve/transferFrom fallback is allowed at contract layer but router integrations should prefer Permit2.
- Optional `deploy-with-initial-deposit` helpers MUST be tested for front-run/squatting resilience (no mint-with-0, correct receiver handling, no dust-loss surprises).

Repo-wide invariants to copy from PROMPT.md (apply to this package)
- Preview policy: all vault preview helpers must be conservative vs execution and be fuzz-tested; exact-in previewOut <= executeOut, exact-out previewIn >= executeIn.
- Deterministic deployments: use Crane Diamond Callback Factory for production deploys; include adversarial front-run tests for any deploy-with-initial-deposit helpers.

Deterministic salts & squatting guidance
- Use Diamond Callback Factory deterministic flow only. Tests MUST include adversarial front-run deployment scenarios for any deploy-with-initial-deposit helper.

## Required tests
- (documented, not implemented here)
- Production-pattern deployment test: DFPkg → CREATE3 → `IDiamondPackageCallBackFactory.deploy` → `initAccount()` and `postDeploy()` lifecycle assertions.
- ERC4626 invariants: share/asset conversion tests, totalAssets tracking, preview/execution parity.
- Exchange tests: exact-in/exact-out preview parity, slippage enforcement, refund correctness for exact-out, reentrancy safety.
- Permit2 tests: ensure flows work under Permit2-only and approve fallback paths.

## Validation
- 
- Inventory reference: `docs/components/UniswapV2StandardExchangeDFPkg.md`
- PROMPT.md placeholder: `PENDING-MAINTAINER-REVIEW`

## postDeploy() / Post-deploy behavior
- PENDING-MAINTAINER-REVIEW
