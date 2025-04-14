### Target: contracts/vaults/seigniorage/SeigniorageDETFExchangeInTarget.sol

## Intent
- Exact-in exchange entrypoints for Seigniorage DETF: mint (reserve→DETF), burn (DETF→reserve), zap-in/out via reserve vault constituents, and 1:1 DETF↔sRBT conversions. Previews mirror execution math and enforce peg gates.

Preview policy: exact-in previews must satisfy `previewOut <= executeOut` on the same on-chain state. Tests must include same-block checks that `previewExchangeIn(...) <= exchangeIn(...)` (when all args identical and state unchanged). Any small rounding/1-wei tolerance used by downstream Balancer math must be explicitly documented in tests; prefer proving parity/favorability with fuzz/invariant checks.

Routes:

- Route ID: TGT-SeigniorageDETFExchangeIn-01
  - Selector / Function: `previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)` (view) / `exchangeIn(IERC20,uint256,IERC20,uint256,address,bool,uint256)`
  - Entry Context: Proxy -> delegatecall Target; permissionless external entrypoint
  - Auth: Permissionless
  - State Writes: `SeigniorageDETFRepo` (reads config); execution: `ERC20Repo._mint` (mint DETF to recipient), `SeigniorageNFTVault` (mint sRBT when seigniorage > 0)
  - External Calls: Reads pool state; calls to `layout.reserveVault.previewExchangeIn` (preview branch), `layout.balancerV3PrepayRouter.prepayAddLiquidityUnbalanced`, Balancer math libraries, and transfer to Balancer Vault; reentrancy protected by `lock`
  - Inputs: `tokenIn` is a reserve-vault token; `tokenOut` is the DETF token; `amountIn>0`; preview checks peg via dilutedPrice; `deadline` enforced in execution path
  - Outputs: `amountOut` = DETF minted to recipient
  - Events: ERC20 `Transfer` (mint), any emitted by prepay router or reserveVault
  - Execution Outline: (ReserveVault→DETF mint)
    1. Load reserve pool state and diluted price.
    2. Require price > peg (mint allowed); otherwise revert `PriceBelowPeg`.
    3. Secure token deposit (`_secureTokenTransfer`).
    4. Compute fee-reduced effective input (seigniorage incentive oracle adjustment).
    5. Compute expected BPT via `BalancerV38020WeightedPoolMath.calcBptOutGivenSingleIn`.
    6. Transfer tokens into Balancer via `prepayAddLiquidityUnbalanced`.
    7. Compute `amountOut` using `WeightedMath.computeOutGivenExactIn` at reduced fee.
    8. Enforce `amountOut >= minAmountOut`.
    9. Mint DETF to recipient and, if seigniorage > 0, mint sRBT to `seigniorageNFTVault`.
  - Invariants: mint allowed only when dilutedPrice > 1 (ONE_WAD); `amountOut >= minAmountOut`; after execution protocol holds only BPT (no stray vault shares); seigniorage split math (user vs NFT) must match oracle percentage semantics
  - Failure Modes: `PriceBelowPeg`, `MinAmountNotMet`, `ReservePoolNotInitialized`, `InvalidRoute`, downstream prepay router/balancer calls may revert
  - Tests Required:
    - Unit: preview vs execute parity (`previewOut <= executeOut`) for Reserve→DETF route (same-block, pretransferred true/false).
    - Integration: full add-liquidity path with `balancerV3PrepayRouter` mocked/integration; assert BPT accounted on NFT and protocol holds only BPT afterwards.
    - Fuzz: seigniorage incentive edge-cases; rounding margins around 1-wei tolerances for `calcBptOutGivenSingleIn`.

- Route ID: TGT-SeigniorageDETFExchangeIn-02
  - Selector / Function: same as above
  - Entry Context: Proxy -> delegatecall Target; permissionless
  - Auth: Permissionless
  - State Writes: `SeigniorageDETFRepo`, `ERC20Repo._burn` (burn DETF), transfers to Balancer/recipient, possible `_redepositUnusedTokens` writes via internal transfers
  - External Calls: Balancer `prepayRemoveLiquidityProportional`, `IERC20.safeTransfer` to Balancer Vault, reserveVault `exchangeIn` for vault-level swaps; reentrancy protected by `lock`
  - Inputs: `tokenIn` == DETF token, `tokenOut` == reserve-vault token; require `syntheticPrice < peg` (burn allowed)
  - Outputs: `amountOut` reserve-vault token transferred to `recipient`
  - Events: ERC20 `Transfer` (burn), router events
  - Execution Outline (DETF→Reserve burn):
    1. Verify price < peg; otherwise `PriceAbovePeg`.
    2. Burn DETF from caller (`_secureSelfBurn`).
    3. Apply reduced fee percentage via feeOracle.
    4. Compute `amountOut` using `WeightedMath.computeOutGivenExactIn`.
    5. Calculate expected BPT for proportional exit (`calcBptInGivenProportionalOut`).
    6. Transfer BPT to Balancer Vault and call `prepayRemoveLiquidityProportional`.
    7. Transfer reserve vault token out to recipient and call `_redepositUnusedTokens` to re-add any leftovers.
  - Invariants: burn allowed only when dilutedPrice < 1; withdrawn WETH (or reserve) must cover intended deficit; no leftover vault shares remain after completion
  - Failure Modes: `PriceAbovePeg`, `MinAmountNotMet`, downstream Balancer or reserveVault reverts
  - Tests Required:
    - Unit/integration: `previewExchangeIn` vs `exchangeIn` parity for burn branch (`previewOut <= executeOut`).
    - Integration: proportional exit correctness; redeposit path triggers correctly when unused tokens exist.

- Route ID: TGT-SeigniorageDETFExchangeIn-03
  - Selector / Function: preview/exchangeIn
  - Entry Context: Proxy -> delegatecall Target
  - Auth: Permissionless
  - State Writes: mints `ERC20Repo` DETF, mints sRBT to NFT vault as applicable
  - External Calls: `layout.reserveVault.previewExchangeIn` / `reserveVault.exchangeIn` used to convert constituent token → reserve vault shares; then single-sided add to Balancer as in mint route
  - Inputs: `tokenIn` is a reserve-vault constituent (valid mint token); `tokenOut` is DETF
  - Outputs: `amountOut` DETF minted
  - Execution Outline (ZapIn):
    1. Secure token deposit from user.
    2. Call `reserveVault.previewExchangeIn(tokenIn, amountIn, IERC20(address(reserveVault)))` (preview) or `reserveVault.exchangeIn(...)` (exec) to get reserve-vault shares.
    3. Use reserve-vault shares as `originalAmountIn` into the standard mint-with-pool flow (`_executeMintWithPool`).
  - Invariants: underlying reserveVault preview/execution parity; peg gate (must be above peg)
  - Failure Modes: `PriceBelowPeg`, underlying reserveVault reverts or returns less than expected causing `MinAmountNotMet`
  - Tests Required: preview equivalence when composing upstream preview + local mint math; ensure `pretransferred` flag handling across nested calls

- Route ID: TGT-SeigniorageDETFExchangeIn-04
  - Selector / Function: preview/exchangeIn
  - Entry Context: Proxy -> delegatecall Target
  - Auth: Permissionless
  - State Writes: burns DETF (`ERC20Repo._burn`) and may transfer reserveVault-derived tokens to recipient; redeposits leftover tokens
  - External Calls: `_executeRedeemWithPool` (removes liquidity), `reserveVault.exchangeIn` for final conversion to constituent token
  - Inputs: `tokenIn` == DETF, `tokenOut` is reserve-vault constituent
  - Outputs: `amountOut` final constituent token amount
  - Execution Outline (ZapOut):
    1. Burn DETF tokens from caller.
    2. Run `_executeRedeemWithPool` to compute and remove proportional liquidity to obtain reserveVault tokens.
    3. Convert reserve vault tokens to requested `tokenOut` by calling `reserveVault.exchangeIn`.
    4. Redeposit unused tokens back to pool if present.
  - Invariants: peg check enforces burned only when below peg; `minAmountOut` enforced for final amount
  - Failure Modes: `PriceAbovePeg`, `MinAmountNotMet`, underlying reserveVault failures
  - Tests Required: nested preview/execute composition checks (preview path composes previewExchangeIn of reserve vault + local burn math); redemption path correctness and redeposit behavior

- Route ID: TGT-SeigniorageDETFExchangeIn-05
  - Selector / Function: preview/exchangeIn (DETF→sRBT)
  - Entry Context: Proxy -> delegatecall Target
  - Auth: Permissionless
  - State Writes: burns DETF (`_secureSelfBurn`), mints sRBT (`seigniorageToken.mint`) to recipient
  - External Calls: none beyond token mints/burns
  - Inputs: `tokenIn` is DETF, `tokenOut` is `seigniorageToken`; require dilutedPrice > peg
  - Outputs: `amountOut` equal to `amountIn` (1:1)
  - Execution Outline: enforce peg, burn DETF from caller (or use pretransferred), mint sRBT to recipient, enforce `minAmountOut`
  - Invariants: only allowed when above peg; 1:1 conversion; `minAmountOut` enforced
  - Failure Modes: `PriceBelowPeg`, `MinAmountNotMet`
  - Tests Required: permissionless mint-to-sRBT path; preview parity (preview returns amountIn); pretransferred behavior

- Route ID: TGT-SeigniorageDETFExchangeIn-06
  - Selector / Function: preview/exchangeIn (sRBT→DETF)
  - Entry Context: Proxy -> delegatecall Target
  - Auth: Permissionless
  - State Writes: burns sRBT (`seigniorageToken.burn`), mints DETF via `ERC20Repo._mint`
  - External Calls: none beyond token burns/mints
  - Inputs: `tokenIn` is `seigniorageToken`, `tokenOut` is DETF; require dilutedPrice >= ONE_WAD (at-or-above peg)
  - Outputs: `amountOut` equal to `amountIn` (1:1)
  - Execution Outline: check peg, burn sRBT (from contract or caller depending on `pretransferred`), mint DETF to recipient, check `minAmountOut`
  - Invariants: 1:1 conversions; peg boundary respected; `minAmountOut` enforced
  - Failure Modes: `PriceBelowPeg`, `MinAmountNotMet`
  - Tests Required: burn/mint symmetry; preview parity tests; ensure `recipient==address(0)` fallback works

Other notes / implementation details:

- Price gating: diluted price calculation uses on-chain pool balances + sRBT state; no redemption-rate caching — the repo computes price fresh per call.
- Fee/incentive semantics: `feeOracle.seigniorageIncentivePercentageOfVault(address(this))` is applied as a reduced-fee factor for user-facing math and used to compute sRBT minted to the NFT vault. Ensure tests assert the split: user receives base*(1 - incentive/2), NFT receives base*(incentive/2).
- Balancer interactions: single-sided add uses `BalancerV38020WeightedPoolMath.calcBptOutGivenSingleIn`; proportional exits use `calcBptInGivenProportionalOut`. Prepay router is used for both add/remove liquidity. Tests must exercise these calculations and assert any 1-wei slack or rounding policy.
- Cleanup: `_redepositUnusedTokens` must return any unused tokens to the pool using `prepayAddLiquidityUnbalanced` — tests should verify this path triggers when expected and does not leave residual balances in the vault.

Files to review when validating this table:

- `contracts/vaults/seigniorage/SeigniorageDETFExchangeInTarget.sol`
- `contracts/vaults/seigniorage/SeigniorageDETFRepo.sol`
- `contracts/vaults/seigniorage/SeigniorageDETFCommon.sol`
- `contracts/protocols/dexes/balancer/v3/utils/BalancerV38020WeightedPoolMath.sol`

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
