### Target: contracts/vaults/seigniorage/SeigniorageNFTVaultTarget.sol

## Intent
- NFT vault tracking BPT positions for underwriters. Only the DETF (owner) may create lock positions via `lockFromDetf`; bond holders may withdraw (`unlock`) after lock expiry and claim rewards. Transfer of NFTs to DETF address is forbidden to avoid bypassing vault flows.

Preview policy: previewRedeem must be conservative: `previewRedeem(tokenId) <= redeem(tokenId)` on same state. Tests must assert same-block parity and that pendingRewards/earned calculations match harvested amounts.

Routes:

- Route ID: TGT-SeigniorageNFTVault-01
  - Selector / Function: `lockFromDetf(uint256 bptOut, uint256 bptReserveBefore, uint256 lockDuration, address recipient)`
  - Entry Context: Child proxy -> delegatecall Target; onlyOwner (DETF) guarded
  - Auth: OwnerOnly (DETF)
  - State Writes: `SeigniorageNFTVaultRepo` (positions, reward accounting), `ERC721Repo` (mint)
  - External Calls: none; reentrancy protected by `lock`
  - Inputs: `bptOut>0`; `lockDuration` validated with `_validateLockDuration`
  - Outputs: `tokenId` minted to recipient
  - Events: `NewLock`
  - Execution Outline:
    1. Validate nonzero shares and lock duration.
    2. Update global rewards before position creation.
    3. Compute `originalShares` via DETF-provided `bptReserveBefore` using `_convertToSharesGivenReserve`.
    4. Compute `effectiveShares` applying bonus multiplier.
    5. Mint NFT and create position with reward debt snapshot.
  - Invariants: DETF must call with `bptReserveBefore` that is the DETF’s BPT reserve before the mint; rewards updated before position creation; effectiveShares calculation must match `_calcBonusMultiplier`
  - Failure Modes: `BaseSharesZero`, `LockDurationNotInRange`
  - Tests Required: owner-only enforcement; correct conversion from BPT→shares using provided reserve; event emission; bonus multiplier math

- Route ID: TGT-SeigniorageNFTVault-02
  - Selector / Function: `unlock(uint256 tokenId, address recipient)`
  - Entry Context: Proxy -> delegatecall Target; permissioned callers (owner or bond holder) via `_validateUnlockCaller`
  - Auth: Permissionless but restricted to bond holder or DETF (on-behalf while recipient==owner)
  - State Writes: `SeigniorageNFTVaultRepo` (position removal), `ERC721Repo` (burn), updates to reward accounting
  - External Calls: calls `detfToken.claimLiquidity(lpAmount, recipient)` which executes DETF pool withdrawal and sends rate-target to recipient; reentrancy protected by `lock`
  - Inputs: `tokenId` existing and unlocked (`block.timestamp >= unlockTime`)
  - Outputs: `lpAmount` amount of BPT passed to DETF; final extracted liquidity sent to recipient
  - Events: `Unlock` emitted with final `lpAmount` and rewards
  - Execution Outline:
    1. Validate caller via `_validateUnlockCaller`.
    2. Ensure unlock time elapsed.
    3. Update and harvest rewards (call `_harvestRewardsInternal`).
    4. Convert effectiveShares → `lpAmount` via `_convertToAssets`.
    5. Remove position and burn NFT (grant one-off approval for DETF if necessary).
    6. Call DETF `claimLiquidity` to extract rate-target to recipient.
  - Invariants: rewards harvested before position removal; NFT burned; DETF processes claimLiquidity and returns rate-target to recipient
  - Failure Modes: `LockDurationNotExpired`, `NotBondHolder`, `PositionNotFound`, downstream `claimLiquidity` failures
  - Tests Required: unlock permissioning matrix (owner vs bond holder); reward harvest correctness; `claimLiquidity` integration

- Route ID: TGT-SeigniorageNFTVault-03
  - Selector / Function: `withdrawRewards(uint256 tokenId, address recipient)`
  - Entry Context: Proxy -> delegatecall Target; only NFT owner
  - Auth: Permissionless (must be NFT owner)
  - State Writes: `SeigniorageNFTVaultRepo` (reward debt updates), transfers of reward token
  - External Calls: reward token transfer via `IERC20.safeTransfer`
  - Inputs: `tokenId` owned by caller
  - Outputs: `rewards` transferred
  - Execution Outline: validate ownership, update global rewards, compute pending via `_harvestRewardsInternal`, transfer tokens, emit `RewardsClaimed`
  - Invariants: owner-only; idempotent if no rewards
  - Failure Modes: `NotBondHolder`, `PositionNotFound` if token does not exist
  - Tests Required: owner-only assertion; reward arithmetic; zero-rewards returns 0

- Route ID: TGT-SeigniorageNFTVault-04
  - Selector / Function: ERC721 transfer overrides (`safeTransferFrom`/`transferFrom`)
  - Entry Context: Proxy -> delegatecall Target
  - Auth: Permissionless (standard ERC721 ownership/approval enforced)
  - State Writes: `ERC721Repo` ownership changes
  - External Calls: ERC721 safe transfer receiver check when `safeTransferFrom`
  - Inputs: `to` must not be DETF address (reverts `IERC721InvalidReceiver`)
  - Execution Outline: reject transfers to DETF to avoid bypassing unlock logic; otherwise forward to `ERC721Repo` implementations
  - Invariants: NFT cannot be transferred to DETF address
  - Failure Modes: `IERC721InvalidReceiver`
  - Tests Required: cannot transfer NFT to DETF; normal transfers succeed

- Route ID: TGT-SeigniorageNFTVault-05
  - Selector / Function: view getters (`pendingRewards`, `lockInfoOf`, `tokenURI`, `totalShares`, `rewardPerShares`, `rewardSharesOf`, `unlockTimeOf`, `bonusPercentageOf`)
  - Entry Context: Proxy -> delegatecall Target; view-only
  - Auth: Permissionless
  - State Writes: None
  - External Calls: `SeigniorageNFTVaultRepo` helpers; `generateTokenURI` builds base64/SVG
  - Outputs/Invariants: getters must reflect repository state; `tokenURI` reverts for nonexistent token
  - Tests Required: getters correctness; URI generation; `bonusPercentageOf` fallback logic (legacy positions)

Files to review when validating this table:

- `contracts/vaults/seigniorage/SeigniorageNFTVaultTarget.sol`
- `contracts/vaults/seigniorage/SeigniorageNFTVaultRepo.sol`
- `contracts/vaults/seigniorage/SeigniorageDETFUnderwritingTarget.sol` (interaction surface)

## Validation
- PENDING-MAINTAINER-REVIEW

Repo-wide invariants (copy from PROMPT.md):
- Preview policy: exact-in previews must satisfy `previewOut <= executeOut`; exact-out previews must satisfy `previewIn >= executeIn` on the same on-chain state. Tests must compare preview and execution on the same state and include fuzz/invariant checks for any rounding buffers.
- Deterministic deployments: production deploys MUST use Crane CREATE3 + Diamond Package Callback Factory; do NOT use `new()` in production deploy paths. Any deploy-with-initial-deposit helpers require adversarial front-run deployment tests.
- Permit2: routers MUST enforce Permit2; vaults should prefer Permit2. Any ERC20 approve/transferFrom fallback must be explicitly documented and covered by tests where permitted.
- No cached rates: rate/redemption values used in accounting MUST be computed fresh on every call; avoid stale cached rates without explicit invalidation and tests.
- Vault gating: vault packages MUST gate `processArgs()` to `IVaultRegistryDeployment` for all vaults intended to be discoverable via the VaultRegistry.
- postDeploy() gating: `postDeploy()` must be constrained to the Diamond Callback Factory lifecycle and tests must prove arbitrary EOAs/contracts cannot call `postDeploy()` to mutate state after deployment.

## postDeploy() / Post-deploy behavior
- PENDING-MAINTAINER-REVIEW
