### Target: contracts/protocols/dexes/balancer/v3/vaults/StandardExchangeSingleVaultSeigniorageDETFExchangeOutTarget.sol

## Intent
- Exact-out exchange entrypoints for the Balancer single‑vault Seigniorage DETF strategy. Complements the `ExchangeIn` Target: accepts desired `amountOut` of `tokenOut` and computes the minimal `amountIn` required (or executes the flow consuming at most `maxAmountIn` on execution). Typical flows include 1:1 sRBT↔DETF conversions, DETF redemptions to reserveVault tokens (single‑asset exits), and mint paths where the caller supplies reserveVault (or its constituents) to receive a specific DETF amount.

Preview policy: exact‑out previews must satisfy `previewIn >= executeIn` (same on‑chain state). Preview functions must apply ceiling math where needed (rounding up inputs) so that an execution using the returned `amountIn` will deliver at least the requested `amountOut`. Any small rounding/1‑wei tolerances used by Balancer math must be explicitly documented and fuzz‑tested.

Primary entrypoints (expected behaviour):

- Selector / Function: `previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 exactAmountOut)` (view)
  - Entry Context: Proxy -> delegatecall Target; view-only quote
  - Purpose: Return conservative `amountIn` required to obtain `exactAmountOut` of `tokenOut` when executed via `exchangeOut` on the same state
  - Invariants: must return an amount >= the actual execution consumption; ceilings are applied in inverse Balancer math

- Selector / Function: `exchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 exactAmountOut, uint256 maxAmountIn, address recipient, bool pretransferred, uint256 deadline)`
  - Entry Context: Proxy -> delegatecall Target; permissionless
  - Auth: Permissionless
  - State Writes: burns/mints via `ERC20Repo` and seigniorage token proxies, transfers to/from Balancer Vault, calls to Balancer router prepay proxy for joins/exits, updates `ERC4626Repo._setLastTotalAssets` as needed

Routes / Branches (exact-out semantics):

- Route A: sRBT → DETF (exact-out)
  - Condition: `tokenIn == seigniorageToken && tokenOut == DETF`
  - Behaviour: exact‑out DETF requires exact‑in sRBT one‑to‑one (`amountIn == amountOut`), burn sRBT then mint DETF to recipient
  - Invariants: 1:1 conversion
  - Tests: previewIn == executeIn == amountOut; pretransferred variants

- Route B: DETF → reserveVault (exact-out redemption)
  - Condition: `tokenIn == DETF && tokenOut == reserveVault`
  - Behaviour: allowed only when diluted price <= peg; compute required DETF in using inverse `computeInGivenExactOut` logic with reduced fee applied (ceilings); compute expected BPT required via `_calcBptInGivenProportionalOut` and call `prepayRemoveLiquidityProportional`; transfer reserveVault tokens to recipient; redeposit leftovers via `prepayAddLiquidityUnbalanced` as in the `exchangeIn` flow
  - Invariants: previewIn >= executeIn; `PriceAbovePeg` prevents burns when above peg; final protocol state holds only BPT
  - Tests: previewIn >= executeIn across fuzz ranges; proportional BPT math; redeposit and no-stray-share invariant

- Route C: DETF → reserveVault constituent (exact-out zap-out)
  - Condition: `tokenIn == DETF && tokenOut == reserveVault constituent` (e.g., underlying tokens)
  - Behaviour: preview composes inverse proportional exit + downstream `reserveVault.previewExchangeOut` for conversion into constituent token; execution burns DETF, removes BPT via `prepayRemoveLiquidityProportional`, then calls `reserveVault.exchangeOut` to obtain requested constituent amounts; unused tokens are redeposited
  - Invariants: previewIn >= executeIn; `minAmountOut` semantics enforced on execution
  - Tests: nested preview/execute parity; reentrancy and refund/redeposit paths

- Route D: reserveVault → DETF (exact-out mint)
  - Condition: `tokenIn == reserveVault && tokenOut == DETF`
  - Behaviour: allowed only when diluted price > peg; preview computes required reserveVault deposit (ceilings) and expected BPT via `_calcBptOutGivenSingleIn` inverse math, then obtains expected DETF out under reduced fee; execution secures deposit, calls `prepayAddLiquidityUnbalanced`, and mints DETF to recipient; profit margin converted and sRBT minted to NFT vault as in `ExchangeIn`
  - Invariants: previewIn >= executeIn; `PriceBelowPeg` blocks minting; sRBT split math preserved
  - Tests: previewIn >= executeIn; sRBT mint accounting for exact-out amounts (i.e., ensure sRBT minted matches profit margin for the executed amount)

- Route E: reserveVault constituent → DETF (exact-out mint via constituent)
  - Condition: `WeightedPoolReserveVaultRepo._isReserveAssetContents(tokenIn) && tokenOut == DETF`
  - Behaviour: preview composes `reserveVault.previewExchangeOut` to determine required reserveVault shares then follows Route D inverse math; execution converts constituent → reserveVault shares then mints DETF accordingly
  - Invariants: same as D; nested previews must compose upstream vault previews then local exact-out math
  - Tests: composition preview/execution parity; pretransferred handling

Important invariants & test notes:

- Exact‑out inequalities: for every exact‑out preview route assert `previewIn >= executeIn` (same state). Where inverse math uses divisions/ceilings, tests must prove ceilings are sufficient under rounding extremes.
- Price gating: mint vs burn gates same as `ExchangeIn` Target (peg comparisons using freshly computed diluted price; no cached redemption rate).
- Balancer rounding slack: where Balancer math yields fractional wei differences, previews must apply conservative ceilings (e.g., add 1 wei or an agreed tiny bps) and tests must fuzz these edges.
- Redeposit behavior: execution paths that compute `unUsedAmountOut` and call `prepayAddLiquidityUnbalanced` must be covered by integration tests and asserted to leave no residual balances.

Failure modes to exercise in tests:

- `PriceBelowPeg` / `PriceAbovePeg` gating on forbidden flows
- `MinAmountNotMet` when downstream conversions cannot meet requested outputs
- `InsufficientPayment` from prepay hooks if `settle` returns less than hints

Tests required (high priority):

1) Same‑block exact‑out parity: For each route A–E, call `previewExchangeOut(...)` and then `exchangeOut(...)` with identical state and confirm `previewIn >= actualIn` returned and/or used by execution (use `maxAmountIn` = preview value and assert execution succeeds). Include pretransferred variants.
2) Ceiling/rounding fuzz tests: fuzz amounts near low supply and near rounding boundaries to ensure previews remain conservative.
3) Integration: prepay router interactions and settle/refund behavior for exact‑out removes/adds (mock Balancer Vault to simulate settle returning slightly different amounts to test refund and InsufficientPayment paths).
4) Accounting: for exact‑out mints, verify sRBT minted equals computed profit split; when exact‑out consumes partial profit margin, ensure corresponding sRBT arithmetic holds.

Files to review when validating this table:

- `contracts/protocols/dexes/balancer/v3/vaults/StandardExchangeSingleVaultSeigniorageDETFExchangeInTarget.sol`
- `contracts/protocols/dexes/balancer/v3/vaults/StandardExchangeSingleVaultSeigniorageDETFCommon.sol`
- `contracts/protocols/dexes/balancer/v3/utils/BalancerV38020WeightedPoolMath.sol`
- `contracts/protocols/dexes/balancer/v3/routers/prepay/BalancerV3StandardExchangeRouterPrepayHooksTarget.sol`
- `contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol`

## Validation
- (leave untagged until maintainer confirmation)

## postDeploy() / Post-deploy behavior
- PENDING-MAINTAINER-REVIEW
