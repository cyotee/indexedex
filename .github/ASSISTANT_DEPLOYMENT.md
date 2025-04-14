# Assistant Deployment Rules

These rules apply to package deployment, factory usage, and deterministic deployment patterns used by the repo.

Core rules
- No `new` keyword in production deployment code or scripts. All deterministic deployments must use the repository's CREATE3 factory patterns (e.g., `factory().create3(...)`, Diamond Factory Packages).
- Packages that create vault-proxy instances must implement the `IDiamondFactoryPackage` interface and provide `facetInterfaces()`, `facetCuts()`, `diamondConfig()`, `calcSalt(...)`, `processArgs(...)`, and `initAccount(...)` following existing examples (e.g., `UniswapV2StandardStrategyVaultPkg.sol`).
- Token metadata initialization (ERC20 metadata) must be performed in `initAccount(...)` using the ERC20-permit facet initializer (or equivalent) so deployed proxies expose correct `name()`, `symbol()`, and `decimals()`.

Naming rules
- DETF token symbol: `DETF`.
- DETF token name convention: `<rateTargetName> DETF of <strategyVaultName>`.
- DETF token decimals: `18`.

Testing deployments
- Add focused tests to assert that deployed vault tokens return expected `name()` and `symbol()` values.
- Deployments created in tests must use the repository's factory/registry helpers to mirror production flows.

Approval & exceptions
- Any exception to these rules requires an explicit approver comment (maintainer/owner) in the issue or PR.
