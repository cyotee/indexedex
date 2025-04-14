### Target: contracts/vaults/seigniorage/SeigniorageDETFUnderwritingTarget.sol

## Intent
- Underwriting (bonding) flows for Seigniorage DETF. Users deposit reserve-vault tokens or reserve-vault constituents to receive NFT positions representing BPT shares; positions earn boosted rewards based on lock duration. The DETF holds BPT and the NFT vault tracks user shares.

Preview policy: previewUnderwrite must be conservative for original/effective shares relative to execution. For exact-in style underwrite, preview originalShares/effectiveShares MUST be <= executed awarded shares. Tests must assert same-block parity: `previewUnderwrite(...) <= underwrite(...)` outcome (compare awarded shares/derived LP amounts) when state is unchanged.

Routes:

- Route ID: TGT-SeigniorageDETFUnderwriting-01
  - Selector / Function: `underwrite(IERC20 tokenIn, uint256 amountIn, uint256 lockDuration, address recipient, bool pretransferred)`
  - Entry Context: Proxy -> delegatecall Target; permissionless
  - Auth: Permissionless
  - State Writes: `SeigniorageDETFRepo` (reserve pool initialized flag), `ERC20Repo._mint` (mint RBT to balancer vault), `ERC4626Repo._setLastTotalAssets` via `_syncLpReserve`, NFT minting through `seigniorageNFTVault.lockFromDetf` (updates NFT vault repo)
  - External Calls: `reserveVault.exchangeIn` (when tokenIn is constituent), Balancer prepay router `prepayAddLiquidityUnbalanced`/`prepayInitialize`, `IBasePool.computeInvariant` on init path, `seigniorageNFTVault.lockFromDetf`; reentrancy protected by `lock`
  - Inputs: `tokenIn` either reserve-vault shares or a reserve-vault constituent; `amountIn>0`; `lockDuration` must be validated against bond terms
  - Outputs: `tokenId` minted to `recipient`
  - Events: NFT vault events via `lockFromDetf`, any downstream router/pool events
  - Execution Outline:
    1. Normalize recipient (defaults to caller)
    2. Convert `tokenIn` to reserve-vault shares if necessary (`reserveVault.exchangeIn`) and transfer shares to Balancer vault
    3. Load pool state and compute equivalent RBT amount for deposit (init vs existing pool branches).
    4. Mint RBT (ERC20Repo._mint) to Balancer vault to satisfy pool self-side deposit.
    5. Add liquidity via prepay router: `prepayAddLiquidityUnbalanced` or `prepayInitialize` for first deposit. `expectedBptOut` computed via Balancer math or pool invariant.
    6. Sync LP reserve view and call `seigniorageNFTVault.lockFromDetf` with the minted BPT amount and `bptReserveBefore` to credit the user NFT position.
  - Invariants:
    - Pool initialization branch must compute invariant-consistent `expectedBptOut` that matches `computeInvariant` behavior.
    - For existing pools: `expectedBptOut` calculated via `calcEquivalentProportionalGivenSingle` + `calcBptOutGivenProportionalIn` must match router outcome within a 1-wei tolerance.
    - RBT minted equals `equivRbtAmount` used in depositAmounts; no net mint leak.
    - After execution, DETF holds BPT and NFT vault records `rewardShares` that map to BPT proportionally.
  - Failure Modes:
    - `InvalidRoute` for unsupported `tokenIn`
    - Reverts from reserveVault.exchangeIn when underlying swap fails or deadline passed
    - Balancer prepay router reverts on slippage/ratio errors
  - Tests Required:
    - Unit: `previewUnderwrite` vs `underwrite` parity (originalShares/effectiveShares <= executed shares awarded)
    - Integration: init pool path (`poolTotalSupply == 0`) reproduces `computeInvariant` behavior and results in correct `expectedBptOut`.
    - Fuzz: various `amountIn`, `lockDuration` combos; enforce total share accounting and bonus multiplier correctness
    - Loupe-driven selector surface check: ensure the deployed vault proxy does not expose `IDiamondCut` and that `facetInterfaces()` matches the runtime selectors for immutability guarantees.

- Route ID: TGT-SeigniorageDETFUnderwriting-02
  - Selector / Function: `previewUnderwrite(IERC20 tokenIn, uint256 amountIn, uint256 lockDuration)` (view)
  - Entry Context: Proxy -> delegatecall Target; view-only
  - Auth: Permissionless
  - State Writes: None
  - External Calls: `reserveVault.previewExchangeIn` when tokenIn is constituent; Balancer `getPoolTokenInfo` and `totalSupply` read; `IBasePool.computeInvariant` on init branch
  - Inputs: same as underwrite
  - Outputs: `(originalShares, effectiveShares, bonusMultiplier)` — effectiveShares apply `_calcBonusMultiplier` quadratic curve
  - Execution Outline:
    1. Compute `reserveVaultAmountIn` via `_previewReserveVaultAmount` (passes through constituent-preview or direct amount)
    2. Compute `expectedBptOut` via `_previewBptOut` (init vs existing pool math mirrored)
    3. Compute `originalShares` proportionally to existing totalShares / bptReserveBefore (ceil rounding when totalShares>0)
    4. Compute `bonusMultiplier` via `_calcBonusMultiplier(lockDuration)` and `effectiveShares`
  - Invariants: preview math mirrors execution branches including invariant-based init math and uses ceil rounding to avoid optimistic previews
  - Failure Modes: `InvalidRoute` if tokenIn unsupported
  - Tests Required: same as underwrite parity; ensure `previewUnderwrite` clamps and does not revert on out-of-range durations

- Route ID: TGT-SeigniorageDETFUnderwriting-03
  - Selector / Function: `redeem(uint256 tokenId, address recipient)` / `previewRedeem(uint256 tokenId)`
  - Entry Context: Proxy -> delegatecall Target
  - Auth: Permissionless (redeem gated by NFT vault unlock semantics)
  - State Writes: `seigniorageNFTVault.unlock` performs state updates within NFT vault repo
  - External Calls: `seigniorageNFTVault.unlock(tokenId, recipient)` which triggers `claimLiquidity` back to DETF; reentrancy protected by `lock`
  - Inputs/Outputs: `previewRedeem` returns BPT-equivalent `amountOut` (floor rounding); `redeem` triggers NFT vault unlock which ultimately calls `claimLiquidity` and transfers rate target tokens to recipient
  - Execution Outline: `redeem` simply delegates to NFT vault; `previewRedeem` computes proportional share via `Math.mulDiv(shares, totalLpReserve, totalShares, Floor)`
  - Invariants: previewRedeem must be conservative (`previewOut <= executeOut`) — tests must assert same-block parity
  - Failure Modes: `PositionNotFound` or `LockDurationNotExpired` from NFT vault; ensure caller validation in NFT vault
  - Tests Required: preview vs execute parity for redeem; integration for full unlock/claim path

- Route ID: TGT-SeigniorageDETFUnderwriting-04
  - Selector / Function: `claimLiquidity(uint256 lpAmount, address recipient)`
  - Entry Context: Proxy -> delegatecall Target; only callable by `seigniorageNFTVault` (auth enforced)
  - Auth: Registry/Repo enforced (`msg.sender == seigniorageNFTVault`), else reverts `NotNFTVault`
  - State Writes: transfers BPT out (balance changes), redeposit RBT back to pool via `_redepositRbtToPool` (may call `prepayAddLiquidityUnbalanced`), `_syncLpReserve` updates last total assets
  - External Calls: Balancer prepay router `prepayRemoveLiquidityProportional`, reserveVault.previewExchangeIn/exchangeIn for the final conversion, `prepayAddLiquidityUnbalanced` to redeposit RBT
  - Inputs: `lpAmount>0`, `recipient` nonzero
  - Outputs: `extractedLiquidity` amount of rate target tokens sent to recipient
  - Execution Outline:
    1. Verify caller == NFT vault
    2. Remove liquidity proportionally from Balancer pool using `prepayRemoveLiquidityProportional` and apply the same 1-wei rounding tolerance used in previews
    3. Verify amounts received (reserveVaultOut & selfOut) meet expected values; revert on shortfall
    4. Exchange reserveVaultOut to rate target via `reserveVault.exchangeIn` and send to recipient
    5. Redeosit `selfOut` (RBT) back to pool using `_redepositRbtToPool` with cap logic (maxRbtIn) and 1-bps safety margin for `minBptOut`
    6. Sync LP reserve view
  - Invariants: caller enforcement; expected exit amounts use 1-wei tolerant subtraction in both preview and execution; redeposit caps to avoid exceeding Balancer’s max in-ratio
  - Failure Modes: `NotNFTVault`, `ReserveExpectedAmountNotReceived`, `SelfExpectedAmountNotReceived`, downstream reserveVault or Balancer reverts
  - Tests Required:
    - Access control: only NFT vault may call
    - Preview vs execution parity for `previewClaimLiquidity` and `claimLiquidity` (exact-in preview semantics: `previewOut <= executeOut`)
    - Redeposit cap edge cases: when `maxRbtIn == 0` (no redeposit), when `rbtAmount > maxRbtIn` (cap applies), and dust rounding

Files to review when validating this table:

- `contracts/vaults/seigniorage/SeigniorageDETFUnderwritingTarget.sol`
- `contracts/vaults/seigniorage/SeigniorageDETFRepo.sol`
- `contracts/vaults/seigniorage/SeigniorageNFTVaultTarget.sol` (interaction surface)

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
