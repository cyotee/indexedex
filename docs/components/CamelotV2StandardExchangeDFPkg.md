CamelotV2StandardExchangeDFPkg

## Intent
- Deploy and configure StandardExchange vaults that integrate with Camelot V2 pairs. Shares the StandardExchange vault surface and behaviors with UniswapV2-style DFPkg but includes Camelot-specific pool validation and deposit/withdraw semantics.

What this package configures
## Proxy
- `IStandardExchangeProxy` (immutable StandardExchange vault proxy)
- Facets (high level): ERC20/ERC2612/ERC5267/ERC4626 composition, Standard vault accounting, CamelotV2 exchange-in/out facets, preview helpers, fee-oracle wiring, Permit2 awareness, reserve-vault repo wiring.

## Facets
- `ERC20_FACET`
- `ERC5267_FACET`
- `ERC2612_FACET`
- `ERC4626_FACET`
- `ERC4626_BASIC_VAULT_FACET`
- `ERC4626_STANDARD_VAULT_FACET`
- `CAMELOT_V2_STANDARD_EXCHANGE_IN_FACET`
- `CAMELOT_V2_STANDARD_EXCHANGE_OUT_FACET`

## Trust boundaries
- MUST revert unless called by `IVaultRegistryDeployment`. Vault packages are required to enforce registry-first deployments to preserve indexing and trust boundaries.

## Initialization
- Must initialize ERC20 metadata and EIP712 domain, ERC4626 reserve parameters, StandardVaultRepo pointers, fee oracle configuration, Camelot router/factory addresses, Permit2 operator approvals for safe deposit/withdraw flows, and reserve-vault repo entries.

Post-deploy behavior (`postDeploy()`)
- If `postDeploy()` performs any additional wiring or validation (e.g., pool-type checks), it must be callable only during the factory lifecycle hook and proven uncallable by arbitrary callers later.

Runtime invariants & mainnet requirements
- Vault proxy MUST be immutable (must NOT expose `IDiamondCut`).
- `processArgs()` enforced gating is mandatory for mainnet; `initAccount()` must leave no uninitialized critical fields.
- Must reject stableSwap pools (per PROMPT.md requirement). Tests must assert rejection of stable pools.

Repo-wide invariants to copy from PROMPT.md (apply to this package)
- Preview policy: ensure all preview helpers satisfy exact-in/exact-out inequalities and are fuzz-tested.
- Deterministic deployments: use Crane Diamond Callback Factory only; include adversarial front-run tests for any deploy-with-initial-deposit helpers.
- Permit2 guidance: prefer Permit2 for user-facing flows; document fallback behavior in tests.

Deterministic salts & squatting guidance
- Use Diamond Callback Factory deterministic flow only. Any deploy-with-initial-deposit helpers must be tested for front-run/squatting resilience.

## Required tests
- (documented, not implemented here)
- Production-pattern deployment test exercising factory lifecycle.
- Pool-type validation tests: ensure stable pools are rejected.
- Exchange and ERC4626 invariants: preview/execution parity, slippage enforcement, reentrancy safety.

## Validation
- 
- Inventory reference: `docs/components/CamelotV2StandardExchangeDFPkg.md`
- PROMPT.md placeholder: `PENDING-MAINTAINER-REVIEW`

## postDeploy() / Post-deploy behavior
- PENDING-MAINTAINER-REVIEW
