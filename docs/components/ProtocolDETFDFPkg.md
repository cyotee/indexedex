ProtocolDETFDFPkg

## Intent
- Deploy and configure the ProtocolDETF composite proxy (CHIR system). Responsible for wiring Protocol-owned child components (ProtocolNFTVault, RICHIR, reserve Balancer pool, StandardExchange vaults) and for initializing protocol-owned liquidity and seigniorage flows.

What this package configures
## Proxy
- `IProtocolDETFProxy` (immutable production proxy)
- Facets (high level): ERC20/ERC2612/ERC5267 composition for CHIR, ProtocolDETF exchange-in/out logic, bonding, preview helpers, postDeploy orchestration helpers, mint/burn accounting facets.

## Facets
- `ERC20_FACET`
- `ERC5267_FACET`
- `ERC2612_FACET`
- `ERC4626_BASIC_VAULT_FACET`
- `ERC4626_STANDARD_VAULT_FACET`
- `PROTOCOL_DETF_EXCHANGE_IN_FACET`
- `PROTOCOL_DETF_EXCHANGE_IN_QUERY_FACET`
- `PROTOCOL_DETF_EXCHANGE_OUT_FACET`
- `PROTOCOL_DETF_BONDING_FACET`
- `PROTOCOL_DETF_BONDING_QUERY_FACET`

## Trust boundaries
- MUST revert unless called by `IVaultRegistryDeployment` (vault package → registry-first deployment model). Treat `processArgs()` as a strict trust boundary for mainnet.

Repo-wide invariants to copy from PROMPT.md (apply to this package)
- Preview policy: exact-in previews must satisfy `previewOut <= executeOut`; exact-out previews must satisfy `previewIn >= executeIn` on the same state. Document any buffers (BPT/RICHIR) in the tests.
- No cached redemption rate: any redemptionRate() used by RICHIR or related logic MUST be computed fresh each call (no cached/global `lastRateUpdateBlock`/`cachedRedemptionRate`).
- Permit2: user-facing swap/deposit flows should prefer Permit2; ProtocolDETF post-deploy fund pulls MUST use Permit2 (tests must assert Permit2 flows and fallback behavior where allowed).
- Deterministic deployments: use Crane Diamond Callback Factory for all deployments; do NOT use `new` for production deployments.
- Vault package gating: this package MUST gate `processArgs()` to `IVaultRegistryDeployment` as above (mainnet requirement).

## Initialization
- Must set owner (timelocked multi-step owner per project policy).
- Must initialize CHIR ERC20 metadata and EIP712 domain, repo pointers (ProtocolDETFRepo, ERC20Repo, ERC4626Repo if used internally), fee oracle defaults, and any rate-provider pointers required.
- Any Permit2 approvals required for `postDeploy()` must be recorded/validated in tests (updatePkg semantics documented in PROMPT.md).

Post-deploy behavior (`postDeploy()`)
- Runs in proxy context (delegatecall). Expected actions:
  - Pull initial funds from package via Permit2 (if `updatePkg()` prepared funds).
  - Mint CHIR for initial seigniorage/backing flows.
  - Deploy two StandardExchange vaults (CHIR/WETH and RICH/CHIR) via configured DFPkgs and ensure they are registered via `IVaultRegistryDeployment`.
  - Deploy Balancer 80/20 reserve pool (via deterministic factory) and initialize rate providers.
  - Deploy ProtocolNFTVault and RICHIR child proxies and perform initial mint/seeding flows.
- MUST limit successful calls to the Diamond Callback Factory lifecycle hook and the expectedProxy context; tests must prove arbitrary EOAs/contracts cannot call `postDeploy()` to mutate state after deployment.

Child deployments and registration
- Any child VAULT deployed by `postDeploy()` MUST be deployed through `IVaultRegistryDeployment` and registered in the active-only vault indexes.
- Non-vault children (Balancer pool, rate providers) may be unregistered but MUST be persisted in repo storage and emitted in indexable events for discoverability.

Deterministic salts & squatting guidance
- Use Crane Diamond Callback Factory flow exclusively (no ad-hoc salts). If `deploy-with-initial-deposit` helper exists, tests MUST include an adversarial front-run deployment scenario and prove no squatting advantage.

Preview / execution invariants
- All preview helpers that feed into mint/burn must obey global preview policy (exact-in: `previewOut <= executeOut`; exact-out: `previewIn >= executeIn`). Document where buffering is applied (BPT buffers, RICHIR buffers) and require fuzz/invariant tests to prove conservatism.

## Required tests
- (documented, not implemented here)
- Production-pattern deployment test: DFPkg → CREATE3 → `IDiamondPackageCallBackFactory.deploy` → `initAccount()` delegatecall → `postDeploy()` lifecycle exercised and proven uncallable later by arbitrary callers.
- Child deployment registration tests: vaults deployed by `postDeploy()` are registered and appear in vault registry queries; unregistered children are persisted and emitted in events.
- Protocol invariants: no ERC4626 selectors are reachable on the ProtocolDETF proxy; preview/execution parity tests for all exchange routes; seigniorage split math fuzz/invariant tests.

## Validation
- 
- Inventory reference: `docs/components/ProtocolDETFDFPkg.md`
- PROMPT.md placeholder: `PENDING-MAINTAINER-REVIEW`

## postDeploy() / Post-deploy behavior
- PENDING-MAINTAINER-REVIEW
