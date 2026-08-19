# Plan: De-mock + inert-bootstrap + interface removal — DualLiquidity (removed)Detf

Status: READY TO EXECUTE. Consolidates decisions made 2026-07-07 while removing test mocks
surfaced three real production gaps and the reserve-bootstrap design was settled.

## Why (findings)

Removing the protocol mocks (`MockStandardExchange`, `MockVaultFeeOracle`) surfaced that the mock
`TestBase`/harness hid real deployment gaps — the 60+ green tests ran against a hand-seeded state the
real DFPkg never produces:

1. **Inert deployment is never initialized.** `DualLiquidity (removed)DetfDFPkg` creates the reserve
   weighted pool but never initializes it, so `reservePool.balanceOf(detf) == 0` and every route
   reverts. Bootstrapping is a manual post-deploy procedure (deposit into legs → init reserve pool →
   deposit BPT for shares).
2. **Hollow pre-minted dust.** The DFPkg mints `dustShares` (1e6) to `0xdEaD` at deploy, so an
   "inert" vault has non-zero `totalSupply` backed by zero BPT. Wrong — inert must be `totalSupply == 0`.
3. **Config getters missing from the deployed diamond.** `IDualLiquidity (removed)Detf` declares config
   getters implemented only on the test harness; the shipped diamond reverts `NoTargetFor` on them.

## Decisions (from the user)

- Tests use REAL forked protocol code — no protocol mocks. Role tokens are real `ERC20PermitDFPkg`
  diamonds; exercise deposits with BOTH explicit approvals AND Permit2. Keep the hostile
  `ReentrantMockERC20` (attacker fixture, not a protocol mock).
- Deploy is inert: `totalSupply == 0`, reserve pool created but uninitialized. No dust pre-mint.
- First DETF deposit mints **1:1** (`shares = bptIn`); usual fee split then applies. NO DETF-level
  MINIMUM_LIQUIDITY lock — Balancer already locks minimum liquidity when the reserve pool is
  initialized.
- Remove `IDualLiquidity (removed)Detf` entirely. Config is read from the standard vault surface
  (`IBasicVault.vaultTokens()` → `[self, vaultA, vaultB, pairVault, reservePool]`;
  `IBasicVault.reserveOfToken(reservePool)` → `totalReserveBpt`) plus token balances / leg queries.

## Execution steps

### 1. Remove `IDualLiquidity (removed)Detf`; remap errors
- Delete `contracts/interfaces/IDualLiquidity (removed)Detf.sol`.
- Error remap in Common/Targets/QueryTargets/DFPkg:
  - `UnsupportedRoute(IERC20,IERC20)` (×15) → `IStandardExchangeErrors.InvalidRoute(address,address)`.
  - `DeadlineExpired(uint256)` → `IStandardExchangeErrors.DeadlineExceeded(deadline, block.timestamp)`.
  - `ZeroAmount()`, `ReservePoolNotInitialized()`, `ResidualInventory(IERC20,uint256)` → move into
    `DualLiquidity (removed)DetfRepo` (library errors, alongside `AlreadyInitialized`).
- Replace any config-getter reads with `IBasicVault`/`IStandardVault` + balances.

### 2. Bootstrap / dust redesign (inert + 1:1 first deposit)
- `DualLiquidity (removed)DetfMathLib._sharesForBpt`: if `totalShares_ == 0 || totalBpt_ == 0` return
  `bptIn_` (1:1 first deposit). (Guards the div-by-zero.)
- `DualLiquidity (removed)DetfCommon`: split `_requireLive` into `_requireActive(deadline, amount)`
  (deadline + zero-amount, universal) and `_requireReserveLive()` (`reserveBpt.balanceOf(this) > 0`).
- `ExchangeInTarget.exchangeIn`: `_requireActive`; classify; treat
  `kindOut == Shares && kindIn == ReserveBpt && totalSupply == 0` as the bootstrap deposit → skip
  `_requireReserveLive`; all other routes call `_requireReserveLive`. Confirm `_depositBpt` quotes
  BEFORE pulling the BPT (it does: `_mintSharesForBpt` then `transferFrom`), so the 1:1 quote sees the
  pre-deposit empty state.
- `ExchangeOutTarget.exchangeOut`: `_requireActive` + `_requireReserveLive` (exact-out is never the
  bootstrap).
- `DualLiquidity (removed)DetfDFPkg`: delete `_mint(DUST_SINK, dustShares)`, `DUST_SINK`, and the
  `dustShares` field from `PkgArgs`/`DeployConfig` (+ the interface struct). Deploy inert.

### 3. Real ProductionBase + bootstrap helper
- `DualLiquidity (removed)DetfProductionBase` (abstract), mirroring `SingleVaultDetfProductionBase`:
  real `ERC20PermitDFPkg` tokens (fixed supply to test, distributed via transfer), real V4 pools + V2
  pair, real leg DFPkgs, real rate providers, real DETF via registry; `feeOracle = indexedexManager`.
- `_bootstrapReserve()`: deposit commonToken→vaultAShare, commonToken→vaultBShare, zap
  tokenA→pairVaultShare (pair pre-seeded), `router.initialize` the reserve pool with the three shares
  (tokens in `vault.getPoolTokens` order) → BPT, then `exchangeIn(reserveBpt → shares)` (the 1:1
  bootstrap deposit). No dust-backing transfer (obsolete model).
- Helpers: explicit-approval deposit, Permit2 deposit, redeem, pool-skew (for best-route tests),
  read config via `IBasicVault.vaultTokens()`.

### 4. Migrate suites onto the real base (delete mock affordances)
- Deposits, Swaps, Redemptions, ExactOut: target the real `detf`; shares via real deposits (no
  `seedShares`); best-route via real pool skews (no `setRate`); add explicit + Permit2 variants.
- Invariant: handler drives real deposits/swaps/redeems (retain zero-drop ratio check).
- ShareInflation: recfrom "genesis dust" to "first deposit mints 1:1"; donation/ front-run tests over
  real deposits.
- Reentrancy: keep `ReentrantMockERC20` in the tokenB slot over the real deployment.

### 5. Delete mocks + prove
- Delete `MockStandardExchange`, `MockVaultFeeOracle`, mock `TestBase_DualLiquidity (removed)Detf` + harness.
- `grep -r` confirms no references remain. Full family suite green over real code.
- Update `test_facetCuts_installsNineFacets_noDiamondCut` if facet count changed (interface removal
  does not add/remove facets; verify).

### 6. Docs
- PRD: already updated for manual bootstrap; update the "inert = totalSupply 0, 1:1 first deposit, no
  dust pre-mint" detail and the "config via standard vault surface (no bespoke interface)" note.

## Verify
Real bootstrap → deposit → redeem passes; preview==execution stays exact; zero-drop invariant holds;
reentrancy `IsLocked`; inflation tests pass under the 1:1 model; no `Mock*` protocol types remain.
