### Target: contracts/protocols/dexes/balancer/v3/vaults/StandardExchangeSingleVaultSeigniorageDETFExchangeInTarget.sol

## Intent
- Exact-in exchange entrypoints for the Balancer single‑vault Seigniorage DETF strategy. Implements `IStandardExchangeIn.previewExchangeIn` and `exchangeIn(...)` logic for the Seigniorage DETF single‑vault: 1:1 sRBT↔DETF conversions, DETF mint (reserve→DETF via single‑sided add), DETF burn (DETF→reserve via single‑asset exit and unwind), and composed flows that call the Balancer router prepay relay to perform pool joins/exits.

Preview policy: exact‑in previews must satisfy `previewOut <= executeOut` on the same on‑chain state. The Target uses Balancer math (`WeightedMath`, `BalancerV38020WeightedPoolMath`) and oracle fee modifiers; any preview implementation must be conservative with 1‑wei or 1‑bp tolerances where Balancer rounding can differ. Tests must include same‑block parity checks `previewExchangeIn(...) <= exchangeIn(...)`, fuzzing around rounding boundaries, and invariant checks for seigniorage split math.

Primary entrypoints (implemented/behaviour):

- Selector / Function: `previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)` (view)
  - Entry Context: Proxy -> delegatecall Target; view-only quote
  - Purpose: Return conservative `amountOut` for a given `amountIn` when executed via `exchangeIn` on the same state
  - Invariants: must be conservative for every branch implemented by `exchangeIn` (1:1 sRBT conversions, DETF mint/burn, zap-in/zap-out)

- Selector / Function: `exchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut, uint256 minAmountOut, address recipient, bool pretransferred, uint256 deadline)`
  - Entry Context: Proxy -> delegatecall Target; permissionless execution entrypoint
  - Auth: Permissionless
  - State Writes: burns/mints via `ERC20Repo` and seigniorage token `IERC20MintBurnProxy`, transfers to/from Balancer Vault, calls to Balancer router prepay proxy (prepayRemoveLiquidityProportional / prepayAddLiquidityUnbalanced), updates `ERC4626Repo._setLastTotalAssets`
  - External Calls: `BalancerV3Vault.getCurrentLiveBalances`, `WeightedMath.computeOutGivenExactIn`, `BalancerV38020WeightedPoolMath` helpers, `prepayRemoveLiquidityProportional`, `prepayAddLiquidityUnbalanced`, reserve vault `exchangeIn` when unwrapping reserveVault contents, WETH handling delegated to router where applicable

Routes / Branches implemented in `exchangeIn` (high level):

- Route A: sRBT mint (sRBT ← RBT)
  - Condition: `tokenIn == DETF && tokenOut == seigniorageToken` (address equality)
  - Behaviour: burn RBT from caller (or from contract if pretransferred), mint sRBT 1:1 to recipient
  - Invariants: 1:1 conversion; no price gate (seigniorage mints always allowed)
  - Failure Modes: burn reverts for insufficient balance
  - Tests: 1:1 symmetry, pretransferred true/false, preview returns amountIn

- Route B: sRBT burn → RBT mint (sRBT -> DETF)
  - Condition: `tokenIn == seigniorageToken && tokenOut == DETF`
  - Behaviour: burn seigniorage token and mint DETF 1:1 to recipient (fast path)
  - Invariants: 1:1, no price gate; burns happen first to fail fast
  - Tests: 1:1 symmetry, preview parity

- Route C: DETF burn → Reserve Vault token (single‑asset exit)
  - Condition: `tokenIn == DETF && tokenOut == reserveVault` (redeem DETF into reserveVault shares)
  - Behaviour: Requires diluted price <= peg (below-or-equal) to allow burn; burn DETF; apply reduced fee via `feeOracle.seigniorageIncentivePercentageOfVault`; compute `amountOut` with `WeightedMath.computeOutGivenExactIn`; calculate expected BPT to remove via `_calcBptInGivenProportionalOut`; transfer BPT to Balancer router and call `prepayRemoveLiquidityProportional`; transfer reserveVault token to recipient and redeposit leftovers via `prepayAddLiquidityUnbalanced` if present
  - Invariants: burn only when diluted price <= ONE_WAD; after execution protocol holds only BPT; `amountOut >= minAmountOut` enforced
  - Failure Modes: `PriceAbovePeg`, `MinAmountNotMet`, Balancer router failures
  - Tests: preview <= execute; proportional exit correctness; redeposit triggers and final invariant that no stray vault shares remain

- Route D: DETF burn → Reserve Vault constituent (zap‑out)
  - Condition: `tokenIn == DETF && tokenOut == reserveVault constituent` (e.g., underlying tokens)
  - Behaviour: Similar to Route C but after proportional exit the reserveVault shares are exchanged via `reserveVault.exchangeIn` into the requested constituent token; unused tokens are redeposited
  - Invariants: same peg gate as C; `minAmountOut` enforced; no leftover shares
  - Tests: nested preview/execute parity; zap-out redeposit paths

- Route E: DETF mint from Reserve Vault deposit (single‑sided add)
  - Condition: `tokenIn == reserveVault && tokenOut == DETF` (deposit reserveVault shares to mint DETF)
  - Behaviour: Requires diluted price > peg to mint; secure deposit (via `ERC4626Service._secureReserveDeposit` or `exchangeIn` on reserve vault), compute expected BPT via `_calcBptOutGivenSingleIn`, call router `prepayAddLiquidityUnbalanced`, compute `amountOut` using reduced fee math (WeightedMath), compute profit margin and convert to sRBT to mint to `seigniorageNFTVault`, mint DETF to recipient
  - Invariants: mint only when diluted price > ONE_WAD; seigniorage split math: protocol captures profit margin and mints sRBT equal to `profitMargin / ONE_WAD` to NFT vault; `amountOut >= minAmountOut`
  - Failure Modes: `PriceBelowPeg`, `MinAmountNotMet`, Balancer router failures
  - Tests: preview <= execute for mint branch; seigniorage accounting — assert sRBT minted equals computed `sRBTToMint` and split semantics are preserved

- Route F: DETF mint from Reserve Vault contents deposit (constituent→DETF)
  - Condition: `WeightedPoolReserveVaultRepo._isReserveAssetContents(tokenIn) && tokenOut == DETF`
  - Behaviour: Convert constituent -> reserveVault shares via `reserveVault.exchangeIn`, then follow Route E; same reduced fee, BPT add via prepay
  - Invariants: same as E; nested previews must compose upstream vault previews then local mint math
  - Tests: composition preview/execution parity; pretransferred handling

Important invariants & design notes:

- Price gating: diluted price uses live pool balances and sRBT state; no cached redemption rate — price is recomputed on every call. Minting and burning are gated by comparisons to ONE_WAD (peg).
- Fee/incentive semantics: `VaultFeeOracleQueryAwareRepo._feeOracle().seigniorageIncentivePercentageOfVault(address(this))` is applied as a reduced-fee factor for user math and used to compute sRBT minted to the Seigniorage NFT vault. Tests must assert the split: user receives base*(1 - incentive/2), NFT receives base*(incentive/2) per repo-wide policy.
- Balancer interactions: single‑sided adds use `BalancerV38020WeightedPoolMath._calcBptOutGivenSingleIn`; proportional exits use `_calcBptInGivenProportionalOut`; rounding differences can occur — previews must apply conservative 1‑wei (or small bps) buffers where necessary and be explicitly fuzz-tested.
- Cleanup: after removing liquidity for redemptions the contract may have leftover reserveVault or self balances — the code computes `unUsedAmountOut` and re-adds them via `prepayAddLiquidityUnbalanced` to avoid leaving stray tokens. Tests must assert no residual balances remain and that `ERC4626Repo._setLastTotalAssets` is updated.

Failure modes to test for (non-exhaustive):

- PriceBelowPeg / PriceAbovePeg reverts on guarded branches
- MinAmountNotMet when expected outputs are below `minAmountOut`
- Balancer router prepay calls revert or return insufficient settlement amounts
- InsufficientPayment from prepay hooks when `settle` returns less than hinted

Tests required (high priority)

1) Preview parity tests (same-block): for each branch above, assert `previewExchangeIn(tokenIn, amountIn, tokenOut) <= exchangeIn(tokenIn, amountIn, tokenOut, minAmountOut=0, recipient, pretransferred=false, deadline=max)` when state is unchanged between calls. Include pretransferred=true variants.
2) Fuzz/invariant tests: fuzz amountIn across ranges and pool balances to prove preview conservatism under rounding edges (especially for `calcBptOutGivenSingleIn` and proportional BPT math). Assert no leftover balances in contract after execution (protocol holds only BPT for reserve pool flows).
3) Integration tests (router interactions): run full add/remove flows with a mocked Balancer V3 Vault and Router prepay implementation to assert `prepayRemoveLiquidityProportional` and `prepayAddLiquidityUnbalanced` are invoked with expected parameters and that refunds/settles behave as expected.
4) Accounting tests: assert sRBT minting math — `sRBTToMint == floor(profitMargin / 1e18)` and that minted sRBT is sent to `SeigniorageNFTVault` (and not to other accounts).
5) Edge-case tests: tiny supplies / tiny balances (1 wei), ETH/WETH handling via router, deadline enforcement.

Files to review when validating this table:

- `contracts/protocols/dexes/balancer/v3/vaults/StandardExchangeSingleVaultSeigniorageDETFExchangeInTarget.sol`
- `contracts/protocols/dexes/balancer/v3/vaults/StandardExchangeSingleVaultSeigniorageDETFCommon.sol`
- `contracts/protocols/dexes/balancer/v3/utils/BalancerV38020WeightedPoolMath.sol`
- `contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol`
- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterPrepayTarget.sol`
- `contracts/protocols/dexes/balancer/v3/routers/prepay/BalancerV3StandardExchangeRouterPrepayHooksTarget.sol`

## Validation
- (leave untagged until maintainer confirmation)

Repo-wide invariants (copy from PROMPT.md):
- Preview policy: exact-in previews must satisfy `previewOut <= executeOut`; exact-out previews must satisfy `previewIn >= executeIn` on the same on-chain state. Tests must compare preview and execution on the same state and include fuzz/invariant checks for any rounding buffers.
- Deterministic deployments: production deploys MUST use Crane CREATE3 + Diamond Package Callback Factory; do NOT use `new()` in production deploy paths. Any deploy-with-initial-deposit helpers require adversarial front-run deployment tests.
- Permit2: routers MUST enforce Permit2; vaults should prefer Permit2. Any ERC20 approve/transferFrom fallback must be explicitly documented and covered by tests where permitted.
- No cached rates: rate/redemption values used in accounting MUST be computed fresh on every call; avoid stale cached rates without explicit invalidation and tests.
- Vault gating: vault packages MUST gate `processArgs()` to `IVaultRegistryDeployment` for all vaults intended to be discoverable via the VaultRegistry.
- postDeploy() gating: `postDeploy()` must be constrained to the Diamond Callback Factory lifecycle and tests must prove arbitrary EOAs/contracts cannot call `postDeploy()` to mutate state after deployment.

## postDeploy() / Post-deploy behavior
- PENDING-MAINTAINER-REVIEW
