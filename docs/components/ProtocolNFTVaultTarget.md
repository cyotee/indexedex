### Target: contracts/vaults/protocol/ProtocolNFTVaultTarget.sol

## Validation
- CONFIRMED-WITH-MAINTAINER (2026-02-13)

## Intent
- Protocol-owned NFT vault for time-locked bonding positions; supports user reward claims and ProtocolDETF-controlled flows (create/sell/reward reallocation).

Routes:

- Route ID: TGT-ProtocolNFTVault-01
  - Selector / Function: `createPosition(uint256,uint256,address)`
  - Entry Context: Proxy -> delegatecall Target
  - Auth: OwnerOnly (ProtocolDETF)
  - State Writes: `ProtocolNFTVaultRepo` (positions, reward accounting), `ERC721Repo` (mint)
  - External Calls: none (emits events); reentrancy protected by `lock`
  - Inputs: `shares>0`; `lockDuration` validated; `recipient` should be nonzero (verify)
  - Outputs: `tokenId` minted to `recipient`
  - Events: `NewLock`
  - Execution Outline: validate duration; compute bonus multiplier; update global rewards; compute effectiveShares; mint ERC721; create position with reward debt; emit
  - Invariants: only owner can create; global rewards updated before mutating position; effectiveShares = shares * bonusMultiplier / 1e18
  - Failure Modes: `BaseSharesZero`, lock-duration validation reverts
  - Tests Required: owner-only; duration bounds; effectiveShares math; global reward update ordering

- Route ID: TGT-ProtocolNFTVault-02
  - Selector / Function: `initializeProtocolNFT()`
  - Entry Context: Proxy -> delegatecall Target
  - Auth: OwnerOnly
  - State Writes: `ProtocolNFTVaultRepo` (protocolNFTId), `ERC721Repo` (mint)
  - External Calls: none; reentrancy protected by `lock`
  - Inputs: none
  - Outputs: `tokenId` (existing or newly minted)
  - Events: none
  - Execution Outline: if protocol NFT already minted, return id; else mint to `address(this)` and persist id
  - Invariants: protocol NFT minted once; stored id matches minted token
  - Failure Modes: none expected (review ERC721 mint invariants)
  - Tests Required: idempotent behavior; only owner; minted owner is vault itself

- Route ID: TGT-ProtocolNFTVault-03
  - Selector / Function: `redeemPosition(uint256,address,uint256)`
  - Entry Context: Proxy -> delegatecall Target
  - Auth: Permissionless (but caller must be bond holder or ProtocolDETF per service validation)
  - State Writes: `ProtocolNFTVaultRepo` (position removal, reward accounting), `ERC721Repo` (burn + approvals)
  - External Calls: `layout.protocolDETF.claimLiquidity` (external call into ProtocolDETF), reward token transfers in `_executeHarvestTransfer`; reentrancy protected by `lock`
  - Inputs: `deadline>=now`; `tokenId` must exist and not be protocol NFT; must be unlocked
  - Outputs: `wethOut` sent to `recipient`
  - Events: `IProtocolNFTVault.PositionRedeemed`
  - Execution Outline: validate deadline; validate caller vs owner (service); forbid protocol NFT; enforce unlockTime; update global rewards; harvest rewards; compute lpAmount from effectiveShares; remove position; allow DETF burn flow via per-token approval; burn NFT; call `claimLiquidity(lpAmount, recipient)` on ProtocolDETF
  - Invariants: cannot redeem protocol NFT; unlock enforced; rewards harvested before position removal; principal withdrawal goes through ProtocolDETF (canonical unwind)
  - Failure Modes: `DeadlineExceeded`, `NotBondHolder`, `ProtocolNFTRestricted`, `LockDurationNotExpired`
  - Tests Required: deadline; unlock; protocol-NFT restriction; caller validation (owner vs DETF); rewards paid; lpAmount conversion correctness; no reentrancy via external call

- Route ID: TGT-ProtocolNFTVault-04
  - Selector / Function: `claimRewards(uint256,address)`
  - Entry Context: Proxy -> delegatecall Target
  - Auth: Permissionless (must be NFT owner)
  - State Writes: `ProtocolNFTVaultRepo` (reward debt)
  - External Calls: reward token transfer; reentrancy protected by `lock`
  - Inputs: `tokenId` owned by caller
  - Outputs: `rewards`
  - Events: `IProtocolNFTVault.RewardsClaimed`
  - Execution Outline: validate ownership; update global rewards; harvest rewards to recipient
  - Invariants: only owner can claim; idempotent if no rewards
  - Failure Modes: `NotBondHolder`
  - Tests Required: owner-only; no-rewards returns 0; recipient handling

- Route ID: TGT-ProtocolNFTVault-05
  - Selector / Function: `addToProtocolNFT(uint256,uint256)`
  - Entry Context: Proxy -> delegatecall Target
  - Auth: OwnerOnly
  - State Writes: `ProtocolNFTVaultRepo` (position shares)
  - External Calls: none
  - Inputs: `tokenId == protocolNFTId`; `shares` amount
  - Outputs: none
  - Events: none
  - Execution Outline: restrict to protocol NFT id; update global rewards; add shares to position
  - Invariants: only protocol NFT can be augmented; rewards updated first
  - Failure Modes: `ProtocolNFTRestricted`
  - Tests Required: owner-only; rejects non-protocol tokenId; shares accounting

- Route ID: TGT-ProtocolNFTVault-06
  - Selector / Function: `sellPositionToProtocol(uint256,address,address)`
  - Entry Context: Proxy -> delegatecall Target
  - Auth: OwnerOnly
  - State Writes: `ProtocolNFTVaultRepo` (remove sold position, add to protocol position), `ERC721Repo` (burn)
  - External Calls: reward token transfer; reentrancy protected by `lock`
  - Inputs: `tokenId` must exist, not protocol NFT; `seller` must be current owner; rewardsRecipient defaulting
  - Outputs: `(principalShares, rewardsClaimed)`
  - Execution Outline: forbid protocol NFT; validate seller owns token; load principalShares; update global rewards; harvest rewards to rewardsRecipient; remove position; add principalShares to protocol NFT position; burn sold NFT
  - Invariants: bonus shares are removed (effectiveShares burned) while principal migrates; sold NFT cannot persist
  - Failure Modes: `ProtocolNFTRestricted`, `NotBondHolder`, `PositionNotFound`
  - Tests Required: principal migrated; rewards paid; bonus removed; only owner callable

- Route ID: TGT-ProtocolNFTVault-07
  - Selector / Function: `markProtocolNFTSold(uint256)`
  - Entry Context: Proxy -> delegatecall Target
  - Auth: OwnerOnly
  - State Writes: `ProtocolNFTVaultRepo` (`protocolNFTSold`)
  - External Calls: none
  - Inputs: `tokenId == protocolNFTId`
  - Outputs: none
  - Events: `ProtocolNFTSaleMarked`
  - Execution Outline: set sold flag true
  - Invariants: only protocol NFT can be marked; should be one-way
  - Failure Modes: `ProtocolNFTRestricted`
  - Tests Required: owner-only; one-way semantics; event emitted

- Route ID: TGT-ProtocolNFTVault-08
  - Selector / Function: `reallocateProtocolRewards(address)`
  - Entry Context: Proxy -> delegatecall Target
  - Auth: RegistryOnly (FeeCollector via feeTo); restricted to `StandardVaultRepo._feeOracle().feeTo()`
  - State Writes: `ProtocolNFTVaultRepo` (reward debt)
  - External Calls: reward token transfer
  - Inputs: `recipient` for protocol NFT rewards
  - Outputs: `amount`
  - Events: `IProtocolNFTVault.ProtocolRewardsReallocated`
  - Execution Outline: enforce caller == feeTo; update global rewards; harvest protocol NFT rewards to recipient
  - Invariants: cannot redirect unless caller is feeTo; protocol tokenId used
  - Failure Modes: `NotAuthorized`
  - Tests Required: only feeTo; correct tokenId; amount matches pending rewards

- Route ID: TGT-ProtocolNFTVault-09
  - Selector / Function: ERC721 transfer overrides (`safeTransferFrom`/`transferFrom`)
  - Entry Context: Proxy -> delegatecall Target
  - Auth: Permissionless (standard ERC721 ownership/approval enforced by ERC721Repo)
  - State Writes: `ERC721Repo` (ownership)
  - External Calls: ERC721 receiver checks for safe transfer; guarded receiver block
  - Inputs: `to != protocolDETF` enforced (reverts)
  - Outputs: none
  - Events: ERC721 `Transfer`
  - Execution Outline: forbid transfers to ProtocolDETF address; otherwise delegate to ERC721Repo transfer
  - Invariants: DETF must not receive bond NFTs (prevents bypassing vault logic)
  - Failure Modes: `IERC721Errors.ERC721InvalidReceiver`
  - Tests Required: cannot transfer to DETF; normal ERC721 transfers remain functional

- Route ID: TGT-ProtocolNFTVault-10
  - Selector / Function: view getters (`getPosition`, `positionOf`, `pendingRewards`, `lockInfoOf`, `tokenURI`, `totalShares`, `rewardPerShares`, `protocolDETF`, `protocolNFTSold`, `lpToken`, `rewardToken`, `protocolNFTId`, ERC721 view fns)
  - Entry Context: Proxy -> delegatecall Target; view-only
  - Auth: Permissionless
  - State Writes: None
  - External Calls: none (except internal repo helpers)
  - Invariants: getters must reflect init-time wiring; `pendingRewards` matches earned math
  - Tests Required: getters consistent; protocolNFTSold toggles only via mark; tokenURI reverts for nonexistent

Repo-wide invariants (copy from PROMPT.md):
- Preview policy: exact-in previews must satisfy `previewOut <= executeOut`; exact-out previews must satisfy `previewIn >= executeIn` on the same on-chain state. Tests must compare preview and execution on the same state and include fuzz/invariant checks for any rounding buffers.
- Deterministic deployments: production deploys MUST use Crane CREATE3 + Diamond Package Callback Factory; do NOT use `new()` in production deploy paths. Any deploy-with-initial-deposit helpers require adversarial front-run deployment tests.
- Permit2: routers MUST enforce Permit2; vaults should prefer Permit2. Any ERC20 approve/transferFrom fallback must be explicitly documented and covered by tests where permitted.
- No cached rates: rate/redemption values used in accounting MUST be computed fresh on every call; avoid stale cached rates without explicit invalidation and tests.
- Vault gating: vault packages MUST gate `processArgs()` to `IVaultRegistryDeployment` for all vaults intended to be discoverable via the VaultRegistry.
- postDeploy() gating: `postDeploy()` must be constrained to the Diamond Callback Factory lifecycle and tests must prove arbitrary EOAs/contracts cannot call `postDeploy()` to mutate state after deployment.

## postDeploy() / Post-deploy behavior
- PENDING-MAINTAINER-REVIEW
