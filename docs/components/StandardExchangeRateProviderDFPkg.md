StandardExchangeRateProviderDFPkg

## Intent
- Deploy and configure a lightweight rate-provider proxy used by vaults and ProtocolDETF to fetch reserve / peg / rate information for Balancer V3 reserve pools.

What this package configures
## Proxy
- `IRateProvider`-style proxy (immutable production proxy)
- Facets (high level): single rate-provider facet implementing live rate queries, initialization + view helpers, and storage repo wiring for the reserve vault and target token.

## Trust boundaries
- This package MAY be deployed directly via the Diamond Callback Factory and therefore MAY leave `processArgs()` ungated; however, discoverability and wiring rules apply (see below). Reviewer must validate caller expectations in the DFPkg source.

## Initialization
- Must initialize reserve vault pointer, target token address, decimals, and persist any configuration used for onchain discovery.
- Must emit an indexable event on deploy (pool/rate provider registration event) so offchain systems can discover rate providers even if not VaultRegistry-registered.

Post-deploy behavior (`postDeploy()`)
- Typically minimal; must be constrained to the factory lifecycle hook. If `postDeploy()` performs linking to other repos, tests must prove the linking is correct and idempotent.

Runtime invariants & mainnet requirements
## Proxy
- MUST be immutable (must NOT expose `IDiamondCut`).
- Discoverability requirement: if a vault/protocol component relies on this rate provider, its address MUST be persisted in the corresponding repo storage AND emitted in an indexable event.
- Rate queries must be deterministic and gas-bounded; rate-provider outputs used in accounting must be tested under adversarial inputs and edge decimals.

Repo-wide invariants to copy from PROMPT.md (apply to this package)
- Deterministic deployments: use Crane Diamond Callback Factory; if multiple rate providers for same pair are possible, manager-driven registry is required (PROMPT.md marks absence as a blocker).
- No cached rates: rate providers used in accounting should avoid storing cached rates that can go stale without explicit invalidation; consumers must compute live rates where required.
- Preview policy: rate-provider previews used by vault previews must be conservative and tested as part of preview/execution parity tests.

Deterministic salts & squatting guidance
- Use Diamond Callback Factory deterministic flow. If multiple rate providers for the same pool/token pair can be deployed, require manager-driven registry to prevent squatting; PROMPT.md already marks the absence of a manager-driven registry as a blocker for mainnet readiness.

## Required tests
- (documented, not implemented here)
- Deployment/test pattern: factory deploy reproducible; event emission for discovery.
- Rate correctness tests: edge decimals, precision, rounding-mode documentation, and invariants for rate usage in downstream accounting.

## Validation
- 
- Inventory reference: `docs/components/StandardExchangeRateProviderDFPkg.md`
- PROMPT.md placeholder: `PENDING-MAINTAINER-REVIEW`

## postDeploy() / Post-deploy behavior
- PENDING-MAINTAINER-REVIEW
