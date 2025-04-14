ProtocolNFTVaultDFPkg

## Intent
- Deploy and configure the ProtocolNFTVault child proxy: ERC721 vault that holds protocol-owned positions (BPT) and supports reward accounting, position minting, selling to protocol, and protocol-exclusive operations.

What this package configures
## Proxy
- `IProtocolNFTVaultProxy` (immutable child proxy deployed and initialized by ProtocolDETF package)
- Facets (high level): ERC721 mint/burn/transfer overrides, position/accounting facets, rewards harvesting/reallocation facets, admin-only protocol operations.

## Facets
- `ERC721_FACET`
- `ERC4626_BASIC_VAULT_FACET`
- `ERC4626_STANDARD_VAULT_FACET`
- `PROTOCOL_NFT_VAULT_FACET`

## Trust boundaries
- As a child proxy deployed by `ProtocolDETFDFPkg.postDeploy()`, `processArgs()` MUST be gated to enforce only the intended deploying package or factory lifecycle can initialize it. Tests must prove unintended callers cannot initialize or hijack the vault.

## Initialization
- Must set protocol owner (ProtocolDETF), mint the protocol NFT to `address(this)` if intended, and set repo pointers (`ProtocolNFTVaultRepo`, `ERC721Repo`).
- Must persist any reward token pointers and initial BPT holdings if seeding is part of the deploy flow.

Post-deploy behavior (`postDeploy()`)
- May perform initial seeding of BPT or link to the ProtocolDETF proxy. Any on-chain state mutation must be constrained to the Diamond Callback Factory lifecycle hook and proven in tests to be uncallable later by arbitrary callers.

Runtime invariants & mainnet requirements
## Proxy
- MUST be immutable (must NOT expose `IDiamondCut`).
- Transfers to ProtocolDETF address must be forbidden (existing code enforces `to != protocolDETF`). Tests must assert this invariant.
- `reallocateProtocolRewards` must be restricted to `feeTo` (FeeCollector) and tests must assert caller gating.

Repo-wide invariants to copy from PROMPT.md (apply to this package)
- Deterministic deployments: parent package must use Crane Diamond Callback Factory; any initial seeding helpers must include adversarial front-run tests.
- Preview policy: any preview helpers exposed by the vault (e.g., previewClaimLiquidity) must be conservative and satisfy the exact-in/exact-out preview inequalities where applicable.
- Permit2: where the ProtocolNFTVault interacts with user token flows that can be pre-approved, prefer Permit2 and document fallbacks in tests.

Deterministic salts & squatting guidance
- Use parent package deterministic flow. If deploy helpers allow initial deposits, add adversarial front-run deployment tests.

## Required tests
- (documented, not implemented here)
- Owner-only operations: `createPosition`, `initializeProtocolNFT`, `sellPositionToProtocol`, `markProtocolNFTSold`.
- Permissionless operations: `redeemPosition`, `claimRewards`, ERC721 transfers (with forbidden-destination assertions).
- Reallocate rewards: only `feeTo` may call; assert correct amounts transferred and event emission.

## Validation
- 
- Inventory reference: `docs/components/ProtocolNFTVaultDFPkg.md`
- PROMPT.md placeholder: `PENDING-MAINTAINER-REVIEW`

## postDeploy() / Post-deploy behavior
- PENDING-MAINTAINER-REVIEW
