SeigniorageDETFDFPkg

## Intent
- Deploy and configure Seigniorage DETF vaults and orchestration for seigniorage flows. These packages implement seigniorage-specific mint/burn and underwriting behaviors and deploy Seigniorage child vaults where needed.

What this package configures
## Proxy
- Seigniorage DETF vault proxy (implements StandardExchange-like surface with seigniorage extensions)
- Facets (high level): ERC20/ERC4626 composition (if applicable), seigniorage exchange-in/out facets, underwriting facets, repo wiring for seigniorage accounting, preview helpers.

## Facets
- `ERC20_FACET`
- `ERC5267_FACET`
- `ERC2612_FACET`
- `ERC4626_BASIC_VAULT_FACET`
- `ERC4626_STANDARD_VAULT_FACET`
- `SEIGNIORAGE_DETF_EXCHANGE_IN_FACET`
- `SEIGNIORAGE_DETF_EXCHANGE_OUT_FACET`
- `SEIGNIORAGE_DETF_UNDERWRITING_FACET`

Additional DFPkg facets/wiring (from source):
- `VAULT_FEE_ORACLE_QUERY` (dependency)
- `VAULT_REGISTRY_DEPLOYMENT` (dependency)
- `PERMIT2` (dependency)
- `BALANCER_V3_VAULT` / `BALANCER_V3_PREPAY_ROUTER` (dependencies)
- `WEIGHTED_POOL_8020_FACTORY`, `DIAMOND_FACTORY`
- Child DFPkgs wired: `SEIGNIORAGE_TOKEN_PKG`, `SEIGNIORAGE_NFT_VAULT_PKG`, `RESERVE_VAULT_RATE_PROVIDER_PKG`

## Trust boundaries
- MUST revert unless called by `IVaultRegistryDeployment` for vault deployments.

## Initialization
- Must set owner, initialize seigniorage repo pointers, configure fee oracle access, and record any underwriting parameters and epoch/lock defaults.

Post-deploy behavior (`postDeploy()`)
- May deploy child components; any child vault MUST be registered via `IVaultRegistryDeployment`. `postDeploy()` must be constrained to factory lifecycle and proven uncallable by arbitrary callers.

Runtime invariants & mainnet requirements
- Vault proxy MUST be immutable (no `IDiamondCut`).
- Seigniorage invariants: solvency/peg bounds, underwriting constraints, and no-free-claims; these must be enforced and covered by fuzz/invariant tests.

Repo-wide invariants to copy from PROMPT.md (apply to this package)
- Preview policy: all seigniorage preview helpers must be conservative vs execution; add explicit buffer docs where applied and fuzz tests validating preview <= execute (exact-in) / previewIn >= executeIn (exact-out).
- Deterministic deployments: use Crane Diamond Callback Factory for all production deployments; front-run tests required for any deploy-with-initial-deposit helpers.
- Permit2: user-facing flows should prefer Permit2; tests must exercise Permit2 flows and document fallback allowance usage where explicitly permitted.

Deterministic salts & squatting guidance
- Use Diamond Callback Factory deterministic flow only. Any deploy-with-initial-deposit helpers require front-run adversarial tests.

## Required tests
- (documented, not implemented here)
- Seigniorage invariants: solvency/peg bound invariant tests, underwriting invariants, preview/execution parity for exchange routes, failure modes for underwriting flows.
- Production-pattern deployment tests: factory lifecycle + `postDeploy()` call gating tests.

## Validation
- 
- Inventory reference: `docs/components/SeigniorageDETFDFPkg.md`
- PROMPT.md placeholder: `PENDING-MAINTAINER-REVIEW`

## postDeploy() / Post-deploy behavior
- PENDING-MAINTAINER-REVIEW
