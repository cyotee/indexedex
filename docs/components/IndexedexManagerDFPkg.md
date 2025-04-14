IndexedexManagerDFPkg

## Intent
- Deploy and configure the Indexedex Manager proxy which provides global operational surfaces: package management, vault registry orchestration, fee oracle manager, owner/operator controls, and factory integrations.

What this package configures
## Proxy
- `IIndexedexManagerProxy` (upgradeable manager proxy)
- Facets (high level): `IDiamondCut`, `IMultiStepOwnable`, `IOperable`, package registry faceting, vault registry deployment manager, fee oracle management, deployment helper facets.

## Facets
- `DIAMOND_CUT_FACET`
- `MULTI_STEP_OWNABLE_FACET`
- `VAULT_FEE_QUERY_FACET`
- `VAULT_FEE_MANAGER_FACET`
- `OPERABLE_FACET`
- `VAULT_REGISTRY_DEPLOYMENT_FACET`
- `VAULT_REGISTRY_VAULT_MANAGER_FACET`
- `VAULT_REGISTRY_VAULT_PACKAGE_MANAGER_FACET`
- `VAULT_REGISTRY_VAULT_PACKAGE_QUERY_FACET`
- `VAULT_REGISTRY_VAULT_QUERY_FACET`

## Trust boundaries
- `processArgs()` may be ungated (expected owner-controlled deployment via Diamond Callback Factory). However, `initAccount()` must securely set the owner and multi-step timelock parameters (mainnet expects 3 day delay per PROMPT.md).

## Initialization
- Must initialize owner (timelocked multi-step owner, 3 day delay), Create3Factory awareness, DiamondPackageFactory pointers, default fee-oracle parameters, and `feeTo` recipient.
- Must ensure interface ordering comments in `facetInterfaces()` match `facetAddresses()` where applicable.

Post-deploy behavior (`postDeploy()`)
- Can perform manager-specific registrations; any `postDeploy()` logic must be callable only by the Diamond Callback Factory/lifecycle and should be proven uncallable by arbitrary contracts thereafter.

Runtime invariants & mainnet requirements
- This proxy MAY be upgradeable in production. If `IDiamondCut` is exposed, `diamondCut` MUST be timelocked owner-only and operators must NOT be able to perform cuts or bypass delay logic.
- Operators are permitted broad day-to-day permissions but must not be able to execute `diamondCut` or change `VaultFeeOracle.feeTo()`.

Repo-wide invariants to copy from PROMPT.md (apply to this package)
- Deterministic deployments: manager must use Crane Diamond Callback Factory for package/vault deployments and ensure salts are not ad-hoc.
- Vault registry gating: any vault deployment entrypoints must enforce `IVaultRegistryDeployment` rules and active-only index semantics.
- Preview policy: manager-provided helpers that expose previews must follow the global preview inequalities and be tested.

Deterministic salts & squatting guidance
- Manager package may leave `processArgs()` ungated but must still use the Diamond Callback Factory deterministic flow.

## Required tests
- (documented, not implemented here)
- Production-pattern deployment test: owner-driven CREATE3 + package deploy, `initAccount()` init checks, `diamondCut` timelock gating tests, token-rescue timelock and event emission tests.
- Access control matrix test: loupe-driven enumeration of selectors and classification (Permissionless/OwnerOnly/Operator/RegistryOnly/InternalOnly).

## Validation
- 
- Inventory reference: `docs/components/IndexedexManagerDFPkg.md`
- PROMPT.md placeholder: `PENDING-MAINTAINER-REVIEW`

## postDeploy() / Post-deploy behavior
- PENDING-MAINTAINER-REVIEW
