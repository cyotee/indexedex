FeeCollectorDFPkg

## Intent
- Deploy and configure the Fee Collector proxy which aggregates protocol fees and exposes manager surfaces to push or sweep collected tokens to the fee-to recipient.

What this package configures
## Proxy
- `IFeeCollectorProxy` (upgradeable fee collector proxy)
- Facets (high level): `IDiamondCut`, `IMultiStepOwnable`, `IFeeCollectorSingleTokenPush`, `IFeeCollectorManager`, accounting facets, token-rescue facet.

## Facets
- `DIAMOND_CUT_FACET`
- `MULTI_STEP_OWNABLE_FACET`
- `FEE_COLLECTOR_SINGLE_TOKEN_PUSH_FACET`
- `FEE_COLLECTOR_MANAGER_FACET`

## Trust boundaries
- This package MAY leave `processArgs()` ungated because deployment is expected to be owner-controlled and performed via the Diamond Callback Factory. Review the DFPkg source to confirm intended caller assumptions.

## Initialization
- Must initialize the owner (timelocked multi-step owner per project policy), set default `feeTo` recipient, and configure any fee-type defaults in the FeeCollector repo.
- Token-rescue operations (if exposed) MUST be owner-only and timelocked; `initAccount()` must set required event context mappings if applicable.

Post-deploy behavior (`postDeploy()`)
- Typically minimal. If `postDeploy()` wires external manager addresses or repos, it must be callable only during the factory lifecycle and tests must assert idempotence and post-deploy uncallability by arbitrary EOAs/contracts.

Runtime invariants & mainnet requirements
- If `IDiamondCut` is present on this proxy, `diamondCut` MUST be timelocked owner-only. Operators must not be able to perform cuts.
- Token-rescue / sweep functions MUST be owner-only and emit indexed events describing token, recipient, and reason/context.

Repo-wide invariants to copy from PROMPT.md (apply to this package)
- Preview policy: N/A for FeeCollector but ensure any query helpers used in integration follow preview conservatism rules when interacting with vaults.
- Deterministic deployments: use Crane Diamond Callback Factory for all deployments.
- Permit2: fee flows that interact with user transfers must prefer Permit2 where applicable; document any fallback allowance usage in tests.

Deterministic salts & squatting guidance
- Use Diamond Callback Factory deterministic flow. Because this package may be owner-deployed, ensure owner-controlled creation flows are documented and tests exercise expected role constraints.

## Required tests
- (documented, not implemented here)
- Production-pattern deployment test: DFPkg -> CREATE3 -> `IDiamondPackageCallBackFactory.deploy` -> `initAccount()` and `postDeploy()` lifecycle tests.
- Timelock tests for `diamondCut` (if present) and token-rescue gating + event emission tests.
- Access control matrix test: loupe-driven enumeration and classification of selectors.

## Validation
- 
- Inventory reference: `docs/components/FeeCollectorDFPkg.md`
- PROMPT.md placeholder: `PENDING-MAINTAINER-REVIEW`

## postDeploy() / Post-deploy behavior
- PENDING-MAINTAINER-REVIEW
