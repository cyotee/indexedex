# Uniswap V4 Single-Vault DETF Implementation Plan

## Objective

Implement an additional DETF under `contracts/vaults/detf/composed/single` that composes:

- a `CHIR` DETF token
- the same ERC20 and token-related facet stack used by Protocol DETF for the `CHIR` token surface
- the concrete Uniswap V4 Standard Exchange Vault implementation under `contracts/protocols/dexes/uniswap/v4` for the `WETH/RICH` pair
- a Balancer V3 80/20 reserve pool holding:
  - `CHIR` at 80%
  - the `WETH/RICH` Standard Exchange Vault token at 20%
- a Standard Exchange Rate Provider that rates the vault token in `WETH`
- the existing Protocol NFT flow pattern for bonded positions

The corresponding test suite should live under `test/foundry/spec/vaults/detf/composed/single`.

## Design Intent

This DETF is materially simpler than the current Protocol DETF:

- only one external Standard Exchange Vault is composed into reserve backing, and it must be the IndexedEx Uniswap V4 vault from `contracts/protocols/dexes/uniswap/v4`
- the CHIR token itself should keep the same ERC20-facing facet composition already used by Protocol DETF
- reserve pricing comes from the Balancer reserve pool spot price and the vault-token rate provider
- synthetic price uses full dilution of total `CHIR` supply against the full reserve position value
- `RICH <-> WETH` routes are delegated directly to the Uniswap V4 Standard Exchange Vault
- `CHIR -> RICH` redeems through the Balancer prepay router into vault tokens, then exits the vault into `RICH`
- mint/burn seigniorage logic remains conceptually aligned with Protocol DETF, but the price signal changes from the current multi-pool synthetic calculation to reserve-pool spot price

## Findings From Protocol DETF Comparison

Reviewing `contracts/vaults/protocol` clarified several intended behaviors that this plan must treat as canonical unless product explicitly chooses to diverge.

### 1. Canonical reserve-entry shape

Protocol DETF minting and bonding do not add freshly minted `CHIR` directly to the Balancer reserve pool.

- minting deposits the input asset into an external Standard Exchange vault
- the reserve pool receives only the resulting vault-share token
- `CHIR` minting happens separately as user output and protocol reward accrual

For the single-vault DETF, this means the canonical reserve-entry flow is:

- deposit `WETH` into `wethRichVault`
- receive `wethRichVault` shares
- add those vault shares to the Balancer reserve pool
- mint `CHIR` separately according to the seigniorage policy

If product later wants a design where freshly minted `CHIR` is paired directly into reserve entry, that is a deliberate departure from Protocol DETF and should be specified as such rather than described as parity.

Correction note:

- although reserve entry should remain vault-share based, the mint quote itself should not be a simple reserve-ratio calculation
- the intended correction is to mint `CHIR` on the same Balancer reserve-pool curve that backs the DETF
- the incentive offset should be applied in the same logical place as Protocol DETF: before the curve quote is evaluated

### 2. ABI compatibility vs slim surface

`IProtocolDETF` already includes `RICHIR`, bridge, and dual-vault-era getters.

- if `ISingleVaultDetf` extends `IProtocolDETF` for compatibility, exposing `richirToken`, bridge previews, and compatibility getters is expected behavior
- if product wants a materially smaller single-vault ABI, `ISingleVaultDetf` should become the primary interface and should not inherit the full legacy surface

This is a product choice, not an implementation bug by itself.

### 3. Package-composition expectation

`BaseDualSelfCommonDETFDFPkg` is responsible for composing major dependencies during deployment:

- underlying Standard Exchange vault instances
- Balancer rate providers
- reserve pool creation and initialization
- Protocol NFT vault deployment
- `RICHIR` deployment when compatibility mode is enabled

The single-vault package should either:

- follow that same composition model in simplified form, or
- explicitly document that some dependencies are injected externally and that this is an intentional departure from Protocol DETF deployment semantics

The production path should prefer package-owned composition. Externally supplied dependencies are acceptable for narrow tests and harnesses, but they should not be the only documented deployment story.

## Reference Code To Reuse

### Existing DETF patterns

- `contracts/vaults/protocol/BaseDualSelfCommonDETFDFPkg.sol`
- `contracts/vaults/protocol/BaseDualSelfCommonDETFRepo.sol`
- `contracts/vaults/protocol/BaseDualSelfCommonDETFCommon.sol`
- `contracts/vaults/protocol/BaseDualSelfCommonDETFExchangeInTarget.sol`
- `contracts/vaults/protocol/BaseDualSelfCommonDETFExchangeOutTarget.sol`
- `contracts/vaults/protocol/BaseDualSelfCommonDETFBondingTarget.sol`
- `contracts/vaults/protocol/ProtocolNFTVaultTarget.sol`
- `contracts/vaults/protocol/ProtocolNFTVaultRepo.sol`
- `contracts/vaults/protocol/TestBase_BaseDualSelfCommonDETF.sol`

### Uniswap V4 vault dependency

- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol`
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol`
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol`
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutTarget.sol`
- `contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol`

The WETH/RICH vault for this DETF should not be a new bespoke vault implementation under `contracts/vaults/detf/...`. It should be an instance deployed from the Uniswap V4 Standard Exchange package that already exists under `contracts/protocols/dexes/uniswap/v4`.

### Balancer reserve and rate-provider dependencies

- `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol`
- `contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol`

## Proposed Production Files

Create a new single-vault DETF slice with the normal Crane Facet/Target/Repo split.

## Facet Reuse Requirement

The new DETF should reuse the same ERC20-related facets as Protocol DETF for the CHIR token surface.

At minimum, the package plan should assume reuse of the same token facet trio currently wired by `BaseDualSelfCommonDETFDFPkg`:

- `erc20Facet`
- `erc5267Facet`
- `erc2612Facet`

This means the new single-vault DETF should not introduce a separate token-standard package shape or a different ERC20 facet mix for CHIR unless there is a later explicit requirement to diverge.

If the package preserves the same broader account-management shape as Protocol DETF, it should also prefer reusing the same adjacent common facets already present there rather than inventing parallel token-management surfaces.

### Core state and shared logic

- `contracts/vaults/detf/composed/single/SingleVaultDetfRepo.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetfCommon.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetfPreviewHelpers.sol`

### Exchange surface

- `contracts/vaults/detf/composed/single/SingleVaultDetfExchangeInTarget.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetfExchangeInFacet.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetfExchangeInQueryTarget.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetfExchangeInQueryFacet.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetfExchangeOutTarget.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetfExchangeOutFacet.sol`

### Bonding / reserve operations

- `contracts/vaults/detf/composed/single/SingleVaultDetfBondingTarget.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetfBondingFacet.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetfBondingQueryTarget.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetfBondingQueryFacet.sol`

### Package + deployment wiring

- `contracts/vaults/detf/composed/single/SingleVaultDetfDFPkg.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetf_Component_FactoryService.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetf_Facet_FactoryService.sol`
- `contracts/vaults/detf/composed/single/SingleVaultDetf_Pkg_FactoryService.sol`

### Optional interface layer

If the existing `IProtocolDETF` surface is too specific to RICHIR / bridge / dual-vault semantics, create a new interface instead of overloading the old one:

- `contracts/interfaces/ISingleVaultDetf.sol`

This should be preferred unless product requirements explicitly require strict compatibility with the current Protocol DETF ABI.

Decision note:

- compatibility mode: `ISingleVaultDetf` may extend `IProtocolDETF`, and legacy `RICHIR` / bridge methods are acceptable
- slim mode: `ISingleVaultDetf` should be the primary ABI and legacy Protocol DETF methods should be omitted unless re-approved

## Proposed Test Files

### Test base / fixtures

- `contracts/vaults/detf/composed/single/TestBase_SingleVaultDetf.sol`

### Spec tests

- `test/foundry/spec/vaults/detf/composed/single/SingleVaultDetf_IntegrationBase.t.sol`
- `test/foundry/spec/vaults/detf/composed/single/SingleVaultDetf_Routes.t.sol`
- `test/foundry/spec/vaults/detf/composed/single/SingleVaultDetf_Minting.t.sol`
- `test/foundry/spec/vaults/detf/composed/single/SingleVaultDetf_Burning.t.sol`
- `test/foundry/spec/vaults/detf/composed/single/SingleVaultDetf_Bonding.t.sol`
- `test/foundry/spec/vaults/detf/composed/single/SingleVaultDetf_SyntheticPrice.t.sol`
- `test/foundry/spec/vaults/detf/composed/single/SingleVaultDetf_ReservePool.t.sol`

If the first implementation reuses `ProtocolNFTVault`, add at least one focused test for that integration rather than duplicating the full Protocol NFT vault suite.

## Storage Model

`SingleVaultDetfRepo` should hold only the state needed for the single-vault design.

### Required references

- `IERC20 richToken`
- `IERC20 wethToken`
- `IStandardExchange wethRichVault` implemented by the deployed Uniswap V4 Standard Exchange vault instance
- `IProtocolNFTVault protocolNFTVault`
- `address reservePool`
- `IRateProvider vaultRateProvider`
- `IBalancerV3StandardExchangeRouterPrepay balancerV3PrepayRouter`
- `IVaultFeeOracleQuery feeOracle`

### Reserve-pool metadata

- `uint256 chirIndex`
- `uint256 vaultTokenIndex`
- `uint256 chirWeight`
- `uint256 vaultTokenWeight`
- `uint256 mintThreshold`
- `uint256 burnThreshold`
- `bool isReservePoolInitialized`

### Bonding metadata

- accepted bond-token set should include both `WETH` and `RICH` in v1
- `RICH` bonding should be normalized into the `WETH` bonding path via the Standard Exchange Vault rather than creating a separate reserve-entry branch
- protocol NFT id

Do not carry forward dual-vault fields that exist only to support the old `CHIR/WETH` plus `RICH/CHIR` topology.

## Functional Requirements By Module

### 1. Package / deployment

`SingleVaultDetfDFPkg` should:

- initialize `CHIR` using the same Protocol DETF token facet stack and token initialization flow
- reuse the same ERC20-related facet inputs used by `BaseDualSelfCommonDETFDFPkg` for:
  - `erc20Facet`
  - `erc5267Facet`
  - `erc2612Facet`
- deploy or attach the `WETH/RICH` vault specifically through `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol`
- treat that vault as the canonical `wethRichVault` dependency for all direct `WETH <-> RICH` routing and reserve-side vault-token accounting
- deploy the Standard Exchange Rate Provider with:
  - `reserveVault = wethRichVault`
  - `rateTarget = wethToken`
- create the Balancer V3 80/20 reserve pool where:
  - token 0/1 ordering follows Balancer sorting rules
  - `CHIR` is configured as `STANDARD`
  - the vault token is configured as `WITH_RATE`
  - the rate provider returns value in WETH terms
- initialize reserve-pool indexes after token sorting
- deploy or attach the NFT vault implementation used for bonded positions

Clarification from Protocol DETF comparison:

- the preferred production implementation is package-owned composition, mirroring `BaseDualSelfCommonDETFDFPkg` in simplified form
- if test harnesses pass predeployed `wethRichVault`, `vaultRateProvider`, `reservePool`, or `protocolNFTVault`, document that as harness-only setup rather than the primary deployment flow
- `RICHIR` and bridge deployment are only required if the project selects ABI compatibility mode

### 2. Price model

`SingleVaultDetfCommon` should expose two distinct price concepts.

#### Reserve spot price

Used for mint/burn gating and seigniorage calculations.

- read live reserve-pool balances
- convert the vault-token side through the configured rate provider into WETH terms
- derive reserve-pool spot price using the Balancer weighted math path already used elsewhere in the repo

#### Synthetic price

Used as the “fully diluted” DETF valuation signal.

- numerator: total reserve value in WETH terms
- denominator: total `CHIR` supply
- vault-token side should be valued as:
  - full vault token supply represented by reserve backing
  - multiplied by the rate-provider value to WETH
- no dependency on the current multi-pool CHIR/WETH or RICH/CHIR synthetic derivation

Implementation note:

- keep `spotPrice()` and `syntheticPrice()` separate internally even if only one is currently public
- this avoids reintroducing the current Protocol DETF documentation/behavior confusion around price signals and thresholds

### 3. Minting and burning

Preserve the current seigniorage model conceptually, but source price from reserve-pool spot price.

#### WETH -> CHIR mint

- verify minting is allowed from reserve-pool spot price against `mintThreshold`
- calculate the actual input received:
  - `actualIn = postTransferWethBalance - preTransferWethBalance`
- deposit user WETH into the `WETH/RICH` Standard Exchange Vault
- receive vault shares:
  - `vaultShares = wethRichVault.exchangeIn(wethToken, actualIn, wethRichVault, 0, address(this), true, deadline)`
- quote `CHIR` output on the Balancer reserve-pool curve:
  - load current live reserve-pool balances in rated units
  - identify:
    - `balanceIn = reserveVaultRatedBalance`
    - `weightIn = reserveVaultWeight`
    - `balanceOut = chirRatedBalance`
    - `weightOut = chirWeight`
    - `swapFee = reservePoolSwapFee`
  - compute the incentive-adjusted vault-share input in the same place as Protocol DETF applies its WETH boost:
    - `boostedVaultSharesIn = vaultShares + vaultShares * seignioragePct / 1e18`
  - apply Balancer swap fee handling to that boosted input before the curve quote
  - compute `baseChirOut` with a Crane library helper built on Balancer weighted-pool math:
    - `baseChirOut = computeSelfOutGivenReserveVaultIn(balanceIn, weightIn, balanceOut, weightOut, boostedVaultSharesIn, swapFee)`
  - split `baseChirOut` between user output and protocol reward accrual using the same policy used by Protocol DETF
- add the received vault shares to the reserve pool
- mint `CHIR` separately to the user and to the protocol reward path according to the selected seigniorage split

Exact-in implementation note:

- the corrected implementation should derive `CHIR` output from the Balancer weighted-pool swap curve, not from a simple reserve ratio
- the incentive offset should be applied before the curve quote, matching the ordering used in Protocol DETF's `ConstProdUtils._saleQuote(...)` path
- keep a bootstrap path only for truly uninitialized reserve states; once the reserve pool is live, mint quoting should be curve-based

Preview implementation note:

- `previewMintWithWeth` should mirror the same path using `wethRichVault.previewExchangeIn(...)` for `vaultShares`
- the preview should then apply the same boosted-input Balancer curve quote used by execution

Canonical parity note:

- this flow should match Protocol DETF's incentive placement and reserve-entry shape while changing the quote surface from the external CHIR pool to the Balancer reserve pool

Correction implementation plan:

1. Add a Crane math library for weighted-pool self-mint and self-burn quoting.
   - preferred location: a Crane math or Balancer utility library rather than a DETF-local helper
   - minimum helpers:
     - `computeOutGivenExactInAfterFee(...)`
     - `computeInGivenExactOutBeforeFee(...)`
     - a small wrapper oriented to DETF terminology is acceptable if it still lives in Crane
2. Update `SingleVaultDetfCommon` to load the reserve pool's rated balances, normalized weights, and swap fee in the form required by that library.
3. Replace `_calcProportionalChirForVaultShares(...)` with a curve-based mint quote helper.
   - do not keep the reserve-ratio formula as the normal mint path
   - keep bootstrap configuration only for zero-liquidity initialization if needed
4. Apply `seigniorageIncentivePercentageOfVault(address(this))` to the reserve-vault input before the curve quote, mirroring Protocol DETF's input-boost ordering.
5. Update execution and preview paths together so `mintWithWeth(...)` and `previewMintWithWeth(...)` share the same quote logic.
6. Add focused tests proving:
   - minted `CHIR` matches the Balancer curve quote
   - increasing the incentive increases quoted `CHIR`
   - preview and execution stay aligned
   - bootstrap behavior only applies before the reserve is live

#### CHIR -> WETH burn / redeem

- verify burning is allowed from reserve-pool spot price against `burnThreshold`
- compute the incentive-adjusted burn input using half of the configured incentive percentage:
  - `effectiveChirIn = chirAmountIn + chirAmountIn * seignioragePct / 2e18`
- use that increased `CHIR` amount as the input to the Balancer reserve-pool swap quote, with the reserve-vault token rate applied normally:
  - load the DETF-owned share of current reserve-pool balances
  - derive owned raw balances from the DETF's current `BPT` position:
    - `ownedChirBalance = chirPoolBalance * reservePoolBptHeld / reservePoolTotalSupply`
    - `ownedReserveVaultBalance = reserveVaultPoolBalance * reservePoolBptHeld / reservePoolTotalSupply`
  - apply the configured reserve-vault rate provider to the owned reserve-vault balance for the swap calculation:
    - `reserveVaultRate = configuredRateProvider.getRate()` or `1e18` if unset
    - `ownedReserveVaultRatedBalance = ownedReserveVaultBalance * reserveVaultRate / 1e18`
  - use the raw `CHIR` balance and the rated reserve-vault balance as the swap reserves
  - identify:
    - `balanceIn = ownedChirBalance`
    - `weightIn = chirWeight`
    - `balanceOut = ownedReserveVaultRatedBalance`
    - `weightOut = reserveVaultWeight`
    - `swapFee = reservePoolSwapFee`
  - compute the rated reserve-vault output target with Crane weighted-pool quote math:
    - `vaultTokensOutRated = computeReserveVaultOutGivenSelfIn(balanceIn, weightIn, balanceOut, weightOut, effectiveChirIn, swapFee)`
  - convert the rated quote back into raw reserve-vault tokens due:
    - `vaultTokensOut = vaultTokensOutRated * 1e18 / reserveVaultRate`
- calculate the `BPT` amount that must be withdrawn to receive that many raw reserve-vault tokens from a proportional reserve exit:
  - `bptIn = ceil(vaultTokensOut * reservePoolTotalSupply / reserveVaultPoolBalance)`
  - the swap quote uses only DETF-owned reserve liquidity, but the proportional-withdraw conversion still uses the full reserve-pool balance because `BPT` claims are against total pool supply
  - revert if the computed `bptIn` or resulting proportional withdrawal rounds to zero
- remove proportional liquidity using that `bptIn`
- redeposit the withdrawn `CHIR` leg back into the reserve pool as unbalanced liquidity
- unwrap the withdrawn reserve-vault token leg back through `wethRichVault` to `WETH`
- send the resulting `WETH` to the user
- burn `CHIR` principal as the input to the process, but do not mint any seigniorage on burn

Exact-in implementation note:

- for `CHIR -> WETH` exact-in, the quote path should be the inverse of minting
- start from user `chirAmountIn`, apply half of the incentive percentage to create `effectiveChirIn`, then quote rated reserve-vault output from the Balancer reserve-pool curve using only the DETF-owned reserve liquidity as the quote reserves
- convert that rated output back into raw reserve-vault tokens due using the configured rate provider
- convert that raw reserve-vault token amount into the required proportional `BPT` withdrawal
- withdraw that `BPT` amount proportionally, redeposit the withdrawn `CHIR`, and redeem only the reserve-vault token leg to `WETH`
- no burn-side seigniorage mint occurs; the incentive only affects the quote used to determine how much reserve-vault token value may be withdrawn

Exact-out implementation note:

- for `CHIR -> WETH` exact-out, first compute the reserve-vault token amount required to realize the requested `WETH` amount via `wethRichVault.previewExchangeOut(...)`
- then solve for the `BPT` amount required to receive that reserve-vault token amount from a proportional exit:
  - `bptIn = ceil(vaultSharesNeeded * reservePoolTotalSupply / reserveVaultPoolBalance)`
- use the proportional exit preview to determine the corresponding `CHIR` amount that will be withdrawn and redeposited
- then convert `vaultSharesNeeded` into rated reserve-vault output using the configured rate provider and invert the Balancer quote path using only the DETF-owned reserve liquidity to determine the minimum raw `CHIR` principal whose half-incentive-adjusted input would justify that rated reserve-vault withdrawal target
- this keeps exact-out aligned with the same inverse-of-mint pricing model as exact-in instead of using a separate proportional-claim formula

Reserve exit note:

- the reserve exit itself remains proportional
- route control comes from sizing `bptIn` from the target reserve-vault token amount, then recycling the withdrawn `CHIR` back into reserve after the exit

### 4. Swap routes

Minimum route set requested by product:

#### Direct vault passthrough

- `RICH -> WETH`
- `WETH -> RICH`

Implementation:

- transfer funds into the deployed Uniswap V4 Standard Exchange vault instance at `wethRichVault`
- delegate to the Standard Exchange Vault `exchangeIn` / `exchangeOut` path
- avoid copying pricing logic already implemented in the Uniswap V4 vault

#### Reserve-assisted route

- `CHIR -> RICH`

Implementation:

- exit reserve through the Balancer prepay router into the vault token
- redeem or swap the vault token through `wethRichVault` into `RICH`

Recommended additional v1 route:

- `CHIR -> WETH`

Even if product focuses on `CHIR -> RICH`, this route will simplify testability and reserve-exit validation.

### 5. Bonding / NFT flow

Bonding should preserve the same overall flow shape as `BaseDualSelfCommonDETFBondingTarget.bond(...)`:

- collect an accepted bond token
- convert the input into the reserve-entry asset mix required by this DETF
- add the resulting position into the reserve pool
- mint the bonded NFT position from the received BPT shares

For `WETH` bonding:

- accept WETH
- deposit WETH into `wethRichVault`
- receive vault shares representing the WETH/RICH leg
- add the vault shares to the reserve pool
- receive BPT
- mint a position in the NFT vault using the same flow shape as the existing Protocol DETF NFT

Canonical parity note:

- Protocol DETF bonding routes input into an external vault token first and contributes that vault token into reserve
- the single-vault DETF should mirror that shape unless product explicitly wants a different reserve-entry model

For `RICH` bonding:

- accept `RICH`
- route `RICH` through the deployed `wethRichVault` to exchange into `WETH`
- once normalized into `WETH`, follow the same `WETH` bonding path above
- do not maintain a second bond-accounting branch for `RICH`; the only difference from `WETH` bonding should be the initial Standard Exchange Vault conversion step

Implementation note:

- unlike the current Protocol DETF, the new bond flow should not branch into distinct reserve-entry paths for different external vaults
- the bond path should converge on one reserve-entry routine built around:
  - `wethRichVault` share creation
  - reserve-pool deposit
  - NFT position minting

Reuse target:

- reuse `ProtocolNFTVaultDFPkg`, `ProtocolNFTVaultTarget`, and `ProtocolNFTVaultRepo` unless the new DETF requires materially different position accounting
- reuse the existing Uniswap V4 Standard Exchange vault package as-is for the WETH/RICH leg rather than creating a DETF-local WETH/RICH vault

Do not clone the NFT code into `composed/single` unless a real difference appears.
Do not clone the Uniswap V4 vault code into `composed/single` either; the composed DETF should depend on the existing protocol package under `contracts/protocols/dexes/uniswap/v4`.

## Execution Phases

### Phase 1. Define the surface

- choose whether to reuse `IProtocolDETF` or create `ISingleVaultDetf`
- lock the required route matrix for v1
- decide whether RICHIR / sell-to-protocol / bridge are in scope or explicitly deferred

Recommended outcome:

- choose one of two explicit modes:
  - slim mode: create a new interface and exclude bridge and `RICHIR` from v1 unless explicitly required
  - compatibility mode: retain `IProtocolDETF` compatibility and accept the legacy `RICHIR` / bridge surface as intentional
- keep only the routes and NFT behaviors required for this DETF beyond the selected interface mode

### Phase 2. Build the storage and common math

- implement `SingleVaultDetfRepo`
- implement reserve-pool state loading helpers
- implement spot-price and synthetic-price helpers
- implement threshold checks
- add or reuse a Crane weighted-pool quote library for reserve-vault-in to `CHIR`-out mint pricing and the inverse burn path
- port only the preview helpers actually needed for the chosen route surface

### Phase 3. Wire deployment and dependencies

- implement facet factory service
- implement package factory service
- implement component factory service for:
  - Protocol DETF-compatible ERC20 facet reuse
  - Uniswap V4 Standard Exchange vault deployment via `UniswapV4StandardExchangeDFPkg`
  - Standard Exchange Rate Provider deployment
  - Balancer reserve pool deployment
  - NFT vault deployment
  - `RICHIR` deployment only if compatibility mode is selected
- implement `SingleVaultDetfDFPkg`

### Phase 4. Implement exchange routes

- direct vault passthrough routes first
- reserve-assisted CHIR redemption routes second
- replace ratio-based mint quoting with reserve-pool curve quoting before considering the mint path complete
- exact-in before exact-out
- only add exact-out routes once quote math is stable

### Phase 5. Implement bonding

- port the Protocol DETF NFT entry flow, but replace the old per-token reserve-entry branches with one shared reserve-entry routine:
  - if input is `RICH`, exchange `RICH -> WETH` through `wethRichVault`
  - deposit the resulting `WETH` into `wethRichVault`
  - add the resulting vault shares to the reserve pool
- validate BPT accounting against the reused NFT vault

### Phase 6. Harden previews and edge cases

- preview mint
- preview burn / claim
- preview route inputs for supported exact-out paths
- add slippage buffers only where strictly necessary

### Phase 7. Add tests and run focused validation

- build a dedicated test base under `contracts/vaults/detf/composed/single`
- add route tests under `test/foundry/spec/vaults/detf/composed/single`
- validate first with narrow test targets, then the full new folder

## Test Plan

### Fixture coverage

- deploy mock or local test `WETH` and `RICH`
- deploy a Uniswap V4 pool and `UniswapV4StandardExchangeDFPkg` vault
- deploy a Standard Exchange Rate Provider against that vault and `WETH`
- deploy a Balancer 80/20 reserve pool using `CHIR` + vault token
- deploy the new DETF package and reused NFT vault package

### Behavior coverage

#### Pricing

- synthetic price matches full-dilution expectation from total supply and rated reserve value
- reserve spot price changes as reserve composition changes
- mint threshold and burn threshold gate behavior correctly

#### Routes

- `WETH -> RICH` delegates correctly to the Uniswap V4 vault
- `RICH -> WETH` delegates correctly to the Uniswap V4 vault
- `CHIR -> RICH` exits reserve, converts vault token, and returns `RICH`
- unsupported routes revert clearly

#### Mint / burn

- mint adds reserve backing and increases CHIR supply consistently
- burn removes reserve backing and decreases CHIR supply consistently
- seigniorage split between user and protocol path matches current policy

Clarification:

- reserve backing for minting is satisfied by added vault-share backing, not by directly depositing minted `CHIR` into the reserve pool, unless product explicitly changes the model
- mint quantity should be quoted off the Balancer reserve-pool curve with Protocol-DETF-style incentive placement, not off a linear reserve ratio

#### Bonding / NFT

- bonding with WETH creates a position with correct BPT shares
- bonding with RICH first converts through the Standard Exchange Vault, then creates the same bonded position shape as WETH bonding
- protocol NFT accounting matches deposited reserve shares
- reward accrual path remains isolated from principal shares if Protocol NFT vault reuse is retained

## Key Implementation Risks

### 1. Reserve price vs synthetic price confusion

The current Protocol DETF already has interface/documentation drift around threshold semantics. Avoid this by naming price helpers explicitly and documenting which one controls:

- threshold gates
- previews
- seigniorage
- public analytics

### 2. Balancer token ordering

This design is sensitive to address ordering because the reserve pool is only two tokens. Persist explicit token indexes after pool creation and never assume `CHIR` is token 0.

### 3. Exact-out quote complexity

The reserve exit plus vault redemption path will make exact-out routes harder than exact-in. Implement exact-in first and add exact-out only after tests prove reserve accounting is stable.

### 4. NFT reuse boundaries

`ProtocolNFTVault` is reusable if this DETF still wants:

- BPT-backed positions
- reward-token accrual ledger
- protocol-owned aggregate NFT

If the new DETF does not need protocol-owned reward compounding or future sell-to-protocol mechanics, that reuse may be heavier than necessary.

### 5. Package creep

Do not port bridge, RICHIR, or dual-vault abstractions into `composed/single` unless a concrete requirement appears. The single-vault design should stay materially smaller than `vaults/protocol`.

Compatibility note:

- if the project intentionally selects `IProtocolDETF` compatibility mode, `RICHIR` and bridge support are no longer considered accidental package creep
- in that mode, the risk is not feature presence but undocumented scope expansion

## Recommended First Implementation Slice

Build and validate the smallest end-to-end slice in this order:

1. deploy `SingleVaultDetfDFPkg` with `CHIR + WETH/RICH vault token` reserve
2. verify `syntheticPrice()` and reserve spot price math
3. implement `WETH -> RICH` and `RICH -> WETH` direct passthrough routes
4. implement `bond(WETH, ...)`
5. implement `WETH -> CHIR` mint
6. implement `CHIR -> RICH` redeem

This sequence gets the core composition working before expanding the public surface.

## Initial Acceptance Criteria

The first production-ready milestone is complete when:

- the new DETF deploys from the intended package path
- reserve initialization succeeds with `CHIR` and the Uniswap V4 vault token
- the rate provider prices the vault token as `WETH`
- direct `RICH <-> WETH` passthrough routes succeed
- `bond(WETH, ...)` creates a valid NFT position backed by reserve BPT
- mint and burn gating use reserve spot price and pass deterministic tests
- synthetic price tests confirm full-dilution valuation behavior
- the selected interface mode is documented explicitly:
  - slim mode with no legacy `RICHIR` / bridge surface, or
  - compatibility mode with those surfaces intentionally retained

## Deferred Unless Required

- `RICHIR` integration in slim mode
- sell-NFT-to-protocol flow in slim mode
- superchain bridge integration in slim mode
- multi-token bond inputs beyond WETH and any explicitly approved v1 token set
- broad exact-out route parity with exact-in
