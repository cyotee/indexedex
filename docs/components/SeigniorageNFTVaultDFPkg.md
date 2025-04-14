SeigniorageNFTVaultDFPkg

## Intent
- Deploy and configure Seigniorage NFT vault child proxies that represent underwriting positions or protocol-owned seigniorage assets.

What this package configures
## Proxy
- Seigniorage NFT vault proxy (ERC721-based child proxy)
- Facets (high level): ERC721 mint/burn/transfer overrides, underwriting position accounting, rewards harvesting, protocol-only operations.

## Facets
- `ERC721_FACET`
- `ERC4626_BASIC_VAULT_FACET`
- `ERC4626_STANDARD_VAULT_FACET`
- `SEIGNIORAGE_NFT_VAULT_FACET`

## Trust boundaries
- As child proxies deployed by Seigniorage packages, `processArgs()` MUST be gated to prevent arbitrary initialization. Tests must assert only expected deployer/package can initialize.

## Initialization
- Must set owner (Seigniorage package), mint protocol NFT if required, and initialize repo pointers and reward token addresses.

Post-deploy behavior (`postDeploy()`)
- Must be callable only during the factory lifecycle hook; any seeding must be proven safe and uncallable afterward by arbitrary callers.

Runtime invariants & mainnet requirements
## Proxy
- MUST be immutable (no `IDiamondCut`).
- Transfers to protocol vaults must be constrained if intended; reward reallocation must be gated to `feeTo` where specified.

Repo-wide invariants to copy from PROMPT.md (apply to this package)
- Preview policy: any preview helpers used by seigniorage flows must follow exact-in/exact-out preview inequalities and be fuzz-tested.
- Deterministic deployments: use Crane Diamond Callback Factory only; deploy-with-initial-deposit helpers require adversarial front-run tests.
- Permit2: where user-facing deposit/swap flows touch this vault type, prefer Permit2 and document fallback behaviors in tests.

Deterministic salts & squatting guidance
- Use Diamond Callback Factory deterministic flow only. Any deploy-with-initial-deposit helper requires front-run tests.

## Required tests
- (documented, not implemented here)
- Underwriting invariants, reward accounting, owner-only operations, permissionless claim paths, and post-deploy gating tests.

## Validation
- 
- Inventory reference: `docs/components/SeigniorageNFTVaultDFPkg.md`
- PROMPT.md placeholder: `PENDING-MAINTAINER-REVIEW`

## postDeploy() / Post-deploy behavior
- PENDING-MAINTAINER-REVIEW
