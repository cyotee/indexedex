# Non-18 decimal token test coverage

- **Status:** planned
- **Created:** 2026-08-29
- **Updated:** 2026-08-29 (plan written)
- **Source request:** Then we need to add full test coverage for using 6 decimal and 9 decimal tokens. Write a PRD file stating that every test scenario must either have 6 decimal and/or a 9 decimal version of the scenario. The PRD should list every test scenario, the test suites containing that scenaario and the exact tests covering that scenario of token combinations and clearly stating which tests need a 6 decimal and 9 decimal token test. These new testa may be implemented as new test suites. We need test scenarios where the underlying token is a 6 decimal and a 9 deicmal token, separate scenarios where there is only one token, for example with the Morpho Vault. In cases where there are two or more tokens, such as the Uniswap V3 and V4 SE Vaults, we need scenarios that combine 6/18, 9/18, 6/9 decimal tokens. We also need ttestt scenarios where the pair token is 6, 9, and 18 decimals. So, cases where the pair token of 6/18 is 6 decimals, and another scenario where the pair token of 6/18 is 18 decimals. An so on for all the other combinations. I know this will be a lot of tests. Many combinations can be consoldiated when testing the orbital, stable, and weighted pool DETF configurations.

## Summary

When this program is done, every in-scope IndexedEx money-path scenario has clones on **every combo required for that product’s arity** (catalog in §1) against production vaults, hooks, and DETFs. Only **configured underlyings** change decimals (`pairToken`, `rateAsset`, Morpho loan, Aave/Stata base). `vaultShare`, `detfToken`, `rebasingClaimToken`, and hook LP stay 18. Thin 18-dec gaps are filled first (Slipstream live zap exec in `SlipstreamStandardExchange_Routes.t.sol`, Balancer DETF D15-2..7), then cloned. Stata clones come from `AaveV3StataStandardExchange_Real.t.sol`, not the mock hermetic. Two-token SEs and the Aave cross-version loop run 6/6, 9/9, and 6/18, 9/18, 6/9 with both pair orientations. Dual SE buffer is gold ERC-4626×ERC-4626 only: eight new `D_U*` cells. N-leg books are the eight `B_*` shapes; weighted n=3 and n=4 get all eight, n=8 gets `B_P6_R18` and `B_P9_R18` only. Stage 11 runs every fixture × every book. Fuzz/invariants run every combo. New suites live under `decimals/` siblings. New TestBases construct underlyings with `contracts/test/stubs/MintableERC20Decimals.sol` (Aave loop keeps `ERC20MintBurnOwnableOperableDFPkg`). Gold 18-dec files are not retargeted. `TestBase_UniswapV4Detf.sol` is not edited.

## Requirements

### 1. Decimal combo catalog (law)

Every combo ID below is a distinct fixture. Tests name the combo in the suite or contract (`…_P6_R18`, `…_U6`, etc.). Amounts are always **raw token units** (`human * 10**decimals`). Internal protocol math stays WAD (scale to 18). Asserts compare raw units of the token that moved.

| Combo ID | Arity | Tokens | Pair / mint token | Other / rate / second | Status today |
|----------|-------|--------|-------------------|-----------------------|--------------|
| `U18` | 1 | one underlying | n/a | 18 | HAVE (default gold) |
| `U6` | 1 | one underlying | n/a | 6 | PARTIAL (Morpho `test_P7_non18_loanToken_mintRedeem_conservation` wrap/redeem only; Aave loop `tokenB` metadata) |
| `U9` | 1 | one underlying | n/a | 9 | NEED everywhere |
| `H6` | 2 | both 6 | either | 6 | NEED |
| `H9` | 2 | both 9 | either | 9 | NEED |
| `H18` | 2 | both 18 | either | 18 | HAVE (default gold; Crane `usdc` in Balancer TestBase is 18, not 6) |
| `P6_R18` | 2 | 6 + 18 | **6** (`pairToken`) | 18 | PARTIAL (some hook first-mint / scale tests; not SE/DETF money paths) |
| `P18_R6` | 2 | 6 + 18 | **18** (`pairToken`) | 6 | NEED |
| `P9_R18` | 2 | 9 + 18 | **9** | 18 | NEED |
| `P18_R9` | 2 | 9 + 18 | **18** | 9 | NEED |
| `P6_R9` | 2 | 6 + 9 | **6** | 9 | NEED |
| `P9_R6` | 2 | 6 + 9 | **9** | 6 | NEED |

`pairToken` is the DETF / hook pair (or AMM token treated as the mint/bond input). The other token is `rateAsset` or the second pool token. Sorting by address must not hide orientation: after PoolKey / token sort, the suite still records which **role** is 6 vs 9 vs 18.

Dual SE buffer (gold: two ERC-4626 SEs). Cell ID `D_<left>_<right>` is left-leg underlying × right-leg underlying. Gold HAVE is `D_U18_U18` only. This program adds the other eight cells. Do not add two-token Dual fixtures.

| Cell ID | Left SE underlying | Right SE underlying | Status today |
|---------|--------------------|---------------------|--------------|
| `D_U18_U18` | 18 | 18 | HAVE (gold Dual) |
| `D_U6_U6` | 6 | 6 | NEED |
| `D_U6_U9` | 6 | 9 | NEED |
| `D_U6_U18` | 6 | 18 | NEED |
| `D_U9_U6` | 9 | 6 | NEED |
| `D_U9_U9` | 9 | 9 | NEED |
| `D_U9_U18` | 9 | 18 | NEED |
| `D_U18_U6` | 18 | 6 | NEED |
| `D_U18_U9` | 18 | 9 | NEED |

N-leg consolidated books (orbital 3, weighted n, quad 4, mixed buffer):

| Book ID | Shape | Pair / mint token | Rest of raw legs |
|---------|-------|-------------------|------------------|
| `B_ALL6` | every raw leg 6 | 6 | 6 |
| `B_ALL9` | every raw leg 9 | 9 | 9 |
| `B_P6_R18` | mixed 6/18 | **6** | 18 |
| `B_P18_R6` | mixed 6/18 | **18** | one other leg 6, remaining 18 |
| `B_P9_R18` | mixed 9/18 | **9** | 18 |
| `B_P18_R9` | mixed 9/18 | **18** | one other leg 9, remaining 18 |
| `B_P6_R9` | mixed 6/9 | **6** | one other leg 9, remaining 18 if a third+ leg exists |
| `B_P9_R6` | mixed 6/9 | **9** | one other leg 6, remaining 18 if a third+ leg exists |

Do not add 8-decimal (WBTC) books in this program. Weighted n4 gold already uses 6/8/18/18 as a hook fixture; that does **not** satisfy 9-dec or pair-orientation law.

- [ ] Every in-scope product has a row in §3–§8 mapping each required combo to HAVE, PARTIAL, NEED, or N/A
- [ ] A combo marked NEED has no passing Foundry suite that deploys that product with those token decimals and runs the scenario IDs in §2
- [ ] `H18` / `U18` remaining green is not acceptance for this PRD

### 2. Scenario clone rule

**Every in-scope money-path scenario must run on every combo required for that product’s arity** (§1). “Scenario” means a named `test_*` that moves, prices, credits, or conserves token amounts (or gates mint/burn on a WAD synthetic that is derived from those amounts). New tests may live in new suites. Do not rewrite gold 18-dec suites to take decimals as a parameter if that would edit a locked TestBase.

**D12:** only configured underlyings change decimals: `pairToken`, `rateAsset`, Morpho **loan** token, Aave/Stata **base**, AMM pool tokens. `vaultShare`, `detfToken`, `rebasingClaimToken`, Bond NFT, and hook LP stay **18**.

**D13:** if the 18-dec money path is missing or mocked, write it on production SUT at 18-dec **first**, then clone. That includes Slipstream live zap exec (`SlipstreamStandardExchange_Routes.t.sol`) and Balancer DETF D15-2..7. Stata 18-dec gold is already `AaveV3StataStandardExchange_Real.t.sol`; do not rewrite the mock hermetic (D15).

In-scope scenario classes (canonical IDs). A product that has the 18-dec test must clone it onto every combo required for that product’s arity.

| Class | What it proves | Clone? |
|-------|----------------|--------|
| `SC-DEPLOY` | Registry deploy + vault/hook/DETF instance with the decimal tokens | YES |
| `SC-R1-IN` | `exchangeIn` exact-in wrap / zap token→shares, preview==exec | YES |
| `SC-R1-OUT` | `exchangeOut` exact-out wrap | YES |
| `SC-R2-IN` | `exchangeIn` shares→token redeem | YES |
| `SC-R2-OUT` | `exchangeOut` withdraw exact assets | YES |
| `SC-DIRECT` | token0↔token1 (or n-leg swap) exact-in and exact-out, both orientations | YES |
| `SC-MULTI` | second join / multi-join / multi-exit | YES |
| `SC-FEE` | usage fee: user full shares, feeTo mint, preview==exec | YES |
| `SC-I1` | `pretransferred=true`, booked inventory, no transfer → revert, no free mint | YES |
| `SC-I2` | claimed > delta → revert | YES |
| `SC-I3` | residual inventory cannot fund a second free pretransfer | YES |
| `SC-K1` | donation inventory is not another user’s mint credit | YES |
| `SC-A0` | donate before first mint/bond cannot free-mint | YES |
| `SC-CROPS` | disable gates inbound; mature close / redeem / burn / `exchangeOut` still work | YES |
| `SC-E6` | inflated max + unused inbound cannot skim (where the product has residual return) | YES if product has E6 |
| `SC-REENT` | `IsLocked` on mint / wrap | YES |
| `SC-DETF-BOND` | first bond goes live; later bond; inert mint reverts | YES |
| `SC-DETF-MINT` | live mint, preview, dust, diamond holds no joinable balances | YES |
| `SC-DETF-BURN` | burn conservation in native units | YES |
| `SC-DETF-CLOSE` | D25-1..7 + last-close | YES |
| `SC-DETF-SELL` | pre-maturity revert; post-maturity NFT sell mints claim | YES |
| `SC-DETF-D15` | claim redeem preview==exec, pays DETF only | YES |
| `SC-DETF-FC` | FC1–FC12 | YES |
| `SC-DETF-POL` | mint deadband, burn below 0.95, D31-1..3, T7.8, T1/T2/T5/(T6 n-leg) | YES |
| `SC-DETF-DN` | DN1–DN22 (minus NatSpec N/A) | YES |
| `SC-DETF-OWN` | hook owner is DETF; third-party add reverts | YES |
| `SC-HOOK-JOIN` | first mint / later join / exit, preview==exec | YES |
| `SC-HOOK-SWAP` | exact-in / exact-out all required directions | YES |
| `SC-HOOK-SCALE` | `invScale` / `ratedScale` / `_toWad` / `_fromWadFloor` match `10**(18-decimals)` or the product’s 36-dec scale | YES |
| `SC-NEST` | T-NEST-1..3 + T-LOCAL-I1 | YES |

Exempt from decimal clones (N/A). These do not move token amounts or do not depend on `decimals()`:

| Exempt class | Examples |
|--------------|----------|
| `EX-J` | J1–J3 facet/loupe/proxy selector smoke |
| `EX-IFACET` | `*Facet_IFacet_Test.t.sol` control lists |
| `EX-FACTORY` | CREATE3 salt, flag bits, idempotent redeploy address, staged-init door counting with 18-dec stubs that never join |
| `EX-MARKER` | interface id / vault type key view tests |
| `EX-FOT-NATS` | `test_T7_15` / `test_L2_FoT_forbidden` NatSpec N/A |
| `EX-LST-FIXED` | Lido wstETH / EtherFi weETH / Rocket rETH **receipt** decimals are protocol-fixed 18. Do not invent a 6-dec wstETH. |
| `EX-MOCK` | Suites that `vm.mockCall` the SUT or its protocol vault (today: `AaveV3StataStandardExchange.t.sol`). Do not decimal-clone mocks. |

L1 fuzz and L3 invariants: **every required combo** for that product (same matrix as example-based suites). Each combo is its own campaign or parameterized fixture, not a single representative book.

- [ ] Every non-exempt `test_*` listed in §3–§8 has a clone on every combo required for that product (tables in §3–§8)
- [ ] Exempt tests (`EX-*`, N/A) are marked in the product tables and are not re-implemented
- [ ] New suites may inherit existing abstract bodies (`UniswapV4Detf_Stage11OpenSuite`, Policy layer bases, hook Liquidity/Swap tests) onto a decimal TestBase

### 3. Single-underlying Standard Exchange

Required combos: `U6` and `U9` (keep `U18`).

#### 3.1 Morpho Blue SE

Production: `contracts/vaults/standard/exchange/protocols/morpho/blue/`. Test root: `test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/`. TestBase: `contracts/vaults/standard/exchange/protocols/morpho/blue/test/bases/TestBase_MorphoBlueStandardExchange.sol`. Underlying = Morpho **loan token**. Collateral stays 18 unless a test uses it as a money token (it must not).

| Scenario | Suite | Exact 18-dec tests | U6 | U9 |
|----------|-------|--------------------|----|----|
| SC-DEPLOY | `MorphoBlueStandardExchange_Deploy.t.sol` | `test_D1_registryDeploy_assetLoanToken_vaultTokens_marker`; `test_D2_deployVault_neverCreatedMarket_revertsMarketNotCreated` | NEED (D1 with 6-dec loan) | NEED |
| EX-J | same | `test_J1_targetSelectors_onFacetFuncs`; `test_J2_cuts_includeFacetSelectors`; `test_J3_proxyLoupe_andSmoke` | N/A | N/A |
| SC-R1-IN | `MorphoBlueStandardExchange_Routes.t.sol` | `test_P1_R1_in_previewEqExec_morphoSupplyUp_idleRounding` | NEED (P7 is wrap/redeem only, not P1 idle/reserve asserts) | NEED |
| SC-R1-OUT | same | `test_P2_R1_out_exactShares` | NEED | NEED |
| SC-R2-IN | same | `test_P3_R2_in_redeemShares` | PARTIAL (`test_P7_non18_loanToken_mintRedeem_conservation` covers wrap+redeem conservation at 6; does not cover P3 supply-down or P5 4626 parity) | NEED |
| SC-R2-OUT | same | `test_P4_R2_out_withdrawExactAssets` | NEED | NEED |
| SC-R1-IN / 4626 | same | `test_P5_IERC4626_matches_P1_P4_amounts` | NEED | NEED |
| invalid route | same | `test_P6_invalidRoute_LtoL_StoS_collateral_random` | NEED (selector encoding uses the 6/9 loan token) | NEED |
| SC-FEE | `MorphoBlueStandardExchange_Fees.t.sol` | `test_F1_usageFeeZero_noFeeToShares`; `test_F2_nonzeroUsageFee_feeSharesToFeeTo_userFullShares` | NEED | NEED |
| EX-MARKER | same | `test_F3_markerInterfaceId_isLendingTypeKey` | N/A | N/A |
| liquidity | `MorphoBlueStandardExchange_Liquidity.t.sol` | `test_U1_maxWithdraw_shrinksTowardIdle`; `test_U2_unwrapAboveMaxWithdraw_revertsInsufficientLiquidity`; `test_U3_previewR2_fullNav_whileExecuteWouldRevert`; `test_U4_deposit_stillSucceedsWhileUtilized`; `test_U5_partialWithdraw_equalMaxWithdraw_succeeds` | NEED | NEED |
| interest | `MorphoBlueStandardExchange_Interest.t.sol` | `test_I1_afterWarp_convertToAssets_matchesExpectedSupplyPlusIdle`; `test_I2_redeemAfterInterest_assetsOutGtAssetsIn` | NEED | NEED |
| rate provider | `MorphoBlueStandardExchange_RateProvider.t.sol` | `test_RP0_emptySe_getRateZero`; `test_RP1_afterDeposit_getRateMatchesPreviewScaling`; `test_RP2_afterInterestWarp_getRateRisesWithConvertToAssets`; `test_RP3_providerSourceUnmodified_quotesThisVaultNav` | NEED | NEED |
| SC-I1 / A0 | `adversarial/Adversarial_MorphoBlueStandardExchange_P0.t.sol` | `test_A0_donateBeforeFirstMint_noFreeShares`; `test_A0_morphoSupplyOnBehalf_beforeFirstMint_noFreeShares`; `test_A1_donateAfterLive_noFreeMint_victimNavRises`; `test_I1/I2/I3_*`; `test_E6_fatMaxIn_pretransferOnlyUsed_bookedIntact`; `test_C_reentrancy_nestedIsLocked`; `test_E1_roundTrip_conservation`; `test_CROPS_disabledVault_exchangeOutAndRedeemStillWork` | NEED | NEED |
| EX-FOT-NATS | adversarial | `test_L2_FoT_forbidden` | N/A | N/A |
| invariant | `invariant/MorphoBlueStandardExchange_Invariant.t.sol` | `invariant_N1`–`N6`; `test_N4_donationDoesNotMintShares` | NEED U6 | NEED U9 |
| fork | `test/foundry/fork/{base_main,ethereum_main,robinhood_main}/…/morpho/blue/` | `test_FK0`–`FK5` (uses `10 ** loanToken.decimals()`; live USDC is 6) | PARTIAL live USDC only; still NEED hermetic U6/U9 full catalog | NEED |

New suites (allowed): `decimals/MorphoBlueStandardExchange_Routes_U6.t.sol` and `_U9.t.sol` (and matching Fees/Liquidity/Interest/RateProvider/Adversarial). Do not treat P7 as the Morpho decimal program.

#### 3.2 ERC-4626 Standard Exchange

Test root: `test/foundry/spec/vaults/standard/erc4626/`. Asset of the protocol ERC-4626 is the underlying.

| Scenario | Suite | Exact 18-dec tests | U6 | U9 |
|----------|-------|--------------------|----|----|
| views | `ERC4626StandardExchange_Routes.t.sol` | `test_VT1_vaultTokens_containsProtocolVaultAndAsset`; `test_VT2_standardVaultConfig_tokensMatch` | NEED | NEED |
| SC-R1-IN | same | `test_SE1_wrapExactIn_previewEqualsExecution_zeroFee`; `test_F1_wrapExactIn_dilutionFee_userFull_feeToMints` | NEED | NEED |
| SC-R1-OUT | same | `test_O1_wrapExactOut_previewEqualsSpend`; `test_O1b_wrapExactOut_withDilutionFee`; `test_O2_protocolVaultToSeExactOut`; `test_O5_wrapExactOut_pullSurplus_refunded`; `test_O6_dustAbsorb_toFeeTo`; `test_O6b_dustSkip_noRevert` | NEED | NEED |
| SC-R2-IN | same | `test_SE2_unwrapExactIn_previewEqualsExecution`; `test_F3_unwrap_noExitFee_underNonZeroOracle`; `test_I4_yieldIncreasesUnwrapClaim` | NEED | NEED |
| SC-R2-OUT | same | `test_O3_unwrapExactOut_burnsOnlyAmountIn`; `test_O4_unwrapExactOut_underDelivery_revertsSlippage` | NEED | NEED |
| SC-I1 | same | `test_FreeMint_pretransferred_noDelta_protocolVaultToSe_reverts`; `test_FreeMint_pretransferred_noDelta_protocolVaultToSeExactOut_reverts`; `test_Z1_zeroAmountIn_reverts`; `test_ReserveInvariant_protocolVaultToSeExactIn` | NEED | NEED |
| Morpho flavor | `ERC4626StandardExchange_Morpho.t.sol` | `test_Morpho_vaultTokens_membership`; `test_Morpho_wrapUnwrap_previewEqualsExecution`; `test_I1_pretransferred_noTransfer_bookedReserve_reverts`; `test_Morpho_interestStrictIncrease_unwrap` | NEED | NEED |
| adversarial | `adversarial/ERC4626StandardExchange_Adversarial.t.sol` | `test_I1_pretransferred_noTransfer_bookedReserve_reverts`; `test_I1_wrapUnderlying_pretransferred_noTransfer_bookedReserve_reverts`; `test_I1_exchangeOut_pretransferred_noTransfer_bookedReserve_reverts`; `test_I2_pretransferred_claimedGtU_revertsExactArgs`; `test_I3_residualInventory_cannotFundSecondFreePretransfer`; J1–J3 EX-J; `test_L2_FoT_forbidden` EX-FOT-NATS | NEED I1–I3; N/A J and FoT | NEED I1–I3 |

#### 3.3 Aave V3 Stata SE

Test root: `test/foundry/spec/protocol/lending/aave/v3.6/`. Underlying = Stata **base** asset. Gold 18-dec money path is `AaveV3StataStandardExchange_Real.t.sol` (Crane StataTokenV2). `AaveV3StataStandardExchange.t.sol` is **EX-MOCK** (`vm.mockCall` on Stata/IERC4626): do not edit it, do not decimal-clone it (D15).

U6/U9 clones deploy a Crane Stata whose `asset().decimals()` is 6 and 9. Fork `deal(1e18)` of a live 6-dec underlying is not a U6 catalog.

| Scenario | Suite | Exact 18-dec tests | U6 | U9 |
|----------|-------|--------------------|----|----|
| EX-MOCK | `AaveV3StataStandardExchange.t.sol` | all `test_*` | N/A | N/A |
| SC-R1 / R2 / fee / routes | `AaveV3StataStandardExchange_Real.t.sol` | `test_Real_Route_*`; `testFuzz_Real_*` | NEED | NEED |
| SC-I1 | Real (pretransferred cases) + `adversarial/Adversarial_AaveV3StataSE_SecurePull.t.sol` | Real pretransferred `test_*`; adversarial I1/FreeMint/A0–A3; E1/E4/E5; H2/H3; J1–J3 EX-J | NEED (not J) | NEED (not J) |

If a Real route is missing versus the mock file’s route list, add that route to Real at **18-dec first**, then clone. Do not port mock tests.

#### 3.4 Aave cross-version loop

Test root: `test/foundry/spec/protocol/lending/aave/cross-version/`. Always **two** tokens (`tokenA` / `tokenB` from `TestBase_AaveCrossVersionLoop`). Required combos: the same eight two-token IDs as §4 (`H6`, `H9`, `P6_R18`, `P18_R6`, `P9_R18`, `P18_R9`, `P6_R9`, `P9_R6`). Keep `H18`. `pairToken` = `tokenA` (documented loop face in the TestBase); the other token is `tokenB`. Today `tokenA` 18 + `tokenB` 6 is **PARTIAL `P18_R6`** (metadata + some money paths), not the catalog.

New decimal TestBases keep `ERC20MintBurnOwnableOperableDFPkg` and pass the combo’s decimals into `deployToken` (D17).

| Scenario | Suite | Exact tests | All 8 non-18 combos |
|----------|-------|-------------|---------------------|
| metadata | `AaveCrossVersionLoopHarness.t.sol` | `test_testTokens_deployed_distinct`; `test_testTokens_metadata`; `test_testTokens_mintable_by_owner` | NEED (assert the combo’s decimals on tokenA/tokenB) |
| deposit / e2e / in / out / rebalance / markets | `AaveCrossVersionLoopDeposit.t.sol`, `…E2E.t.sol`, `…ExchangeIn.t.sol`, `…ExchangeOut.t.sol`, `…Rebalance.t.sol`, `…V3Market.t.sol`, `…V4Market.t.sol`, `…Detection.t.sol`, `…DFPkg.t.sol` | all money-path `test_*` | NEED |
| SC-I1 | `adversarial/Adversarial_AaveCrossVersionLoop_SecurePull.t.sol` | all `test_*` | NEED |

#### 3.5 LST Standard Exchange (fixed 18-dec receipts)

`LidoWstETHStandardExchange_*`, `EtherFiWeETHStandardExchange_*`, `RocketPoolRETHStandardExchange_*` under `test/foundry/spec/protocol/staking/{lido,etherfi,rocket-pool}/`.

- [ ] Marked `EX-LST-FIXED`. No 6-dec or 9-dec clone of wstETH / weETH / rETH
- [ ] Do not skip these products’ existing 18-dec tests
- [ ] Lido 18-dec money path (reference only): `test_P1_wethToSe_*`; `test_P1_wstToSe_*`; `test_P1_seToWeth_*`; `test_P1_seToWst_exactInAndOut`; `test_F1_usageFee_mintsSharesToFeeTo`; adversarial I1–I3 / A0
- [ ] EtherFi 18-dec money path (reference): `test_R1_wethToSe_inAndOut_previewEqExec` … `test_R12_*`; `test_IR1`–`IR5`; I1–I3
- [ ] Rocket 18-dec money path (reference): `test_R1_wethToSe_inAndOut_previewEqExec` … `test_R6_*`; `test_BP1`–`BP5`; `test_H1/H2_*` capacity; I1–I3

- [ ] Morpho Blue, ERC-4626, and Stata Real each have passing `U6` and `U9` clones of every non-exempt test listed in §3.1–§3.3
- [ ] `AaveV3StataStandardExchange.t.sol` has no `decimals/` clone
- [ ] Aave cross-version loop has passing clones of every listed money-path test on all eight two-token combos
- [ ] LST suites stay `EX-LST-FIXED`

### 4. Two-token AMM Standard Exchange

Required combos: `H6`, `H9`, `P6_R18`, `P18_R6`, `P9_R18`, `P18_R9`, `P6_R9`, `P9_R6` (keep `H18`).

`pairToken` orientation: for `P6_R18` the mint/zap-in token used as DETF pair (or the documented token0-as-pair in the SE TestBase) is 6. For `P18_R6` that same role is 18 and the other pool token is 6. Same for 9/18 and 6/9.

Crane Balancer `usdc` is **18 decimals**. DAI/USDC names in SE buffer / Aerodrome TestBases do **not** count as 6-dec coverage.

#### 4.1 Uniswap V2 SE

Test root: `test/foundry/spec/protocol/dexes/uniswap/v2/`.

| Scenario | Suite | Exact 18-dec tests | All 8 non-18 combos |
|----------|-------|--------------------|---------------------|
| SC-DEPLOY | `UniswapV2StandardExchange_DeployWithPool.t.sol` | `test_US13_1_CreateNewPairAndVaultWithoutDeposit`; `test_US13_2_CreatePairWithInitialDeposit`; `test_US13_2_RevertWhenRecipientZeroWithDeposit`; `test_US13_3_ExistingPairWithProportionalDeposit`; `test_US13_4_ExistingPairWithoutDeposit`; `test_US13_5_PreviewNewPair`; `test_US13_5_PreviewExistingPair`; `test_ExistingDeployVaultPairStillWorks` | NEED |
| SC-R1-IN vault | `UniswapV2StandardExchangeIn_VaultDeposit.t.sol` | `test_Route4VaultDeposit_execVsPreview_balanced`; `_unbalanced`; `_extreme`; `test_R4_previewEqualsExecute_route4` | NEED |
| slippage | `UniswapV2StandardExchangeIn_SlippageProtection.t.sol` | `test_Route1Swap_slippage_*`; `test_Route2ZapIn_slippage_*`; `test_Route3ZapOut_slippage_*`; `test_Route5VaultWithdrawal_slippage_*`; `test_Route7ZapOutWithdrawal_slippage_*` | NEED |
| SC-DIRECT out | `UniswapV2StandardExchangeOut_PassThrough.t.sol` | `test_exchangeOut_passthrough_{balanced,unbalanced,extreme}_{token0ToToken1,token1ToToken0}` | NEED |
| SC-CROPS | `UniswapV2StandardExchange_Disable.t.sol` | `test_disableByVaultAddress_blocksExchangeIn`; `test_reenableVaultAddress_allowsExchangeIn`; `test_disableByPackage_blocksExchangeIn`; `test_reenablePackage_allowsExchangeIn` | NEED |
| SC-E6 / A0 / I1 / CROPS | `UniswapV2StandardExchange_SecRemediation.t.sol` | `test_E6_exchangeOut_swap_inflatedMax_pretransferred_noExtraTransfer_noInventorySkim`; `test_A0_donateLp_thenZapInDeposit_cannotRedeemDonation`; `test_A0_emptyVault_residualLp_firstMinter_noDrain`; `test_I1_lpDeposit_pretransferredFalse_existingLpGap_doesNotMint`; `test_I1_lpDeposit_pretransferredTrue_bookedInventory_noTransfer_reverts`; `test_CROPS_disabled_still_allows_exchangeOut`; `test_CROPS_disabled_still_allows_vaultShare_exit` | NEED |
| invariant | `UniswapV2StandardExchange_InOutInvariant.t.sol`; `UniswapV2Vault_RouterRefund.t.sol` | `test_route{1–7}_*` + fuzz; `test_exchangeOut_withPretransferred_true`; `_withContractRecipient`; `_refundExcess` | NEED every combo, including invariant campaigns |
| EXEMPT empty | `UniswapV2StandardExchange_IStandardExchangeIn.t.sol` | no `test_*` (empty inherit) | N/A |
| adversarial | no Uni V2 peer under `test/foundry/spec/vaults/standard-exchange/adversarial/` | — | N/A (do not invent a Uni V2 adversarial suite in this program; SecRemediation covers E6/A0/I1) |

#### 4.2 Uniswap V3 SE

Test root: `test/foundry/spec/protocol/dexes/uniswap/v3/`. TestBase: `TestBase_UniswapV3StandardExchange`.

| Scenario | Suite | Exact 18-dec tests | All 8 non-18 combos |
|----------|-------|--------------------|---------------------|
| SC-DEPLOY | `UniswapV3StandardExchangeDFPkg_Deploy.t.sol` | all `test_*` that deploy with the pair | NEED |
| SC-DIRECT / zap | `UniswapV3StandardExchange_Routes.t.sol` | `test_exchangeIn_exactIn_bothDirections`; `test_exchangeOut_exactOut_bothDirections`; `test_zapIn_firstDeposit_createsPositionsAndShares`; `test_zapIn_subsequentDeposit_addsSameTicks`; `test_zapOut_paysMeasuredToken`; `test_unsupportedRoutes_revert`; `test_deadline_reverts`; `test_slippage_revertsWithoutPartialMint`; `test_callbackSpoof_reverts` | NEED |
| SC-MULTI | `UniswapV3StandardExchange_MultiJoinExit.t.sol` | `test_MJ1`–`MJ8`; `test_ME1`–`ME8`; `test_A0_residualDeadShares_firstMinterNotWhole` | NEED |
| book | `UniswapV3StandardExchange_FullRangeBook.t.sol`; `UniswapV3StandardExchange_LocalLiquidBuffer.t.sol` | `test_FR1`–`FR6`; `test_T1`–`T16`; `test_T4d` donation dilutes; `test_H4` 20% default | NEED |
| preview | `UniswapV3StandardExchange_Previews.t.sol` | `test_P_IN_01`–`05`; `test_P_OUT_01`–`04`; `test_P_PRE_01_pretransferred_exactIn` | NEED |
| import | `UniswapV3StandardExchange_Import.t.sol` | all `test_*` that move liquidity | NEED |
| SC-FEE | `UniswapV3StandardExchange_FeeCompound.t.sol` | all `test_*` | NEED |
| EX-IFACET | `UniswapV3StandardExchange*Facet_IFacet_Test.t.sol` | all | N/A |
| adversarial | `adversarial/Adversarial_{AccessDisable,Accounting,CallbackAuth,Donation,Griefing,Import,PriceManipulation,Reentrancy,SecRemediation}.t.sol` | all money-path `test_*` | NEED |

#### 4.3 Uniswap V4 SE

Test root: `test/foundry/spec/protocol/dexes/uniswap/v4/`.

| Scenario | Suite | Exact 18-dec tests | All 8 non-18 combos |
|----------|-------|--------------------|---------------------|
| SC-DIRECT / zap / preview | `UniswapV4StandardExchangeRoutes_Test.t.sol` | `test_exchangeIn_direct_token0ToToken1`; `test_exchangeIn_direct_token1ToToken0`; `test_previewExchangeIn_direct_matchesExecution_token0ToToken1`; `test_previewExchangeOut_direct_matchesExecution_token0ToToken1`; `test_previewExchangeIn_zap_firstDeposit_matchesExecution_token{0,1}ToShares`; `test_previewExchangeIn_zap_secondDeposit_matchesExecution_token{0,1}ToShares`; `test_previewExchangeOut_zap_matchesExecution_sharesToToken{0,1}`; `test_exchangeOut_direct_token0ToToken1`; `test_exchangeOut_direct_token1ToToken0`; `test_exchangeOut_direct_reverts_whenMaxInputTooLow`; `test_exchangeOut_direct_refunds_excess_input`; `test_exchangeIn_zap_token{0,1}ToShares_firstDeposit`; `test_exchangeIn_zap_token0ToShares_secondDeposit`; `test_exchangeIn_zap_reverts_whenMinSharesTooHigh`; `test_exchangeIn_zap_pretransferred_true`; `test_exchangeOut_zap_sharesToToken{0,1}`; `test_exchangeOut_zap_reverts_whenMaxSharesTooLow`; `test_exchangeOut_zap_pretransferred_true`; `test_exchangeIn_zap_secondDeposit_checkpointsAccruedFees_afterRoundTripTrading`; `test_exchangeIn_zap_secondDeposit_refreshesReserves_afterExternalPriceMove` | NEED |
| SC-MULTI | `UniswapV4StandardExchange_MultiJoinExit.t.sol` | `test_MJ1`–`MJ8`; `test_ME1`–`ME7` | NEED |
| book / buffer | `UniswapV4StandardExchange_FullRangeBook.t.sol`; `UniswapV4StandardExchange_LocalLiquidBuffer.t.sol`; `UniswapV4StandardExchange_LocalLiquidBuffer_H2.t.sol` | `test_FR1`–`FR6`; `test_T1`–`T16`; `test_H1/H3/H4`; `test_T4d`; `test_H2_realBufferHook_midSwap_buffersIntoV4Se` | NEED |
| native wrap | `UniswapV4StandardExchange_NativeEthWrap.t.sol` | `test_zapIn_nativeEthPool_unwrapsWethAndLeavesNoEthDust`; `test_swap_nativeEthPool_wrapsTakenEthToWeth`; `test_zapOut_nativeEthPool_paysWethNotEth` | NEED with the **non-native** token at 6 and at 9 (`P6_R18` / `P9_R18` where native is 18) |
| TWAP poke | `UniswapV4StandardExchange_TwapPoke.t.sol` | `test_H14`–`H17`; `H27`–`H29` | NEED |
| Pons V2 pool | `test/foundry/spec/protocols/dexes/uniswap/v4/pons/UniswapV4StandardExchange_PonsV2Pool.t.sol` | `test_T10_1`–`T10_7` | N/A launch-token decimals (stay 18). NEED `P18_R6` and `P18_R9` on the non-launch currency (mintable 6-dec and 9-dec stand-in; not native ETH) |
| nested caller | `UniswapV4StandardExchange_Univ4SeNestedCaller.t.sol` | all `test_*` | NEED |
| SC-DEPLOY | `UniswapV4StandardExchangeDFPkg_Deploy.t.sol` | deploy `test_*` | NEED |
| EX-IFACET | `UniswapV4StandardExchange*Facet_IFacet_Test.t.sol` | all | N/A |
| SC-I1 / E6 | `adversarial/Adversarial_UniswapV4SE_E6ImpA0.t.sol`; `Adversarial_UniswapV4SE_SecurePull.t.sol` | all `test_*` | NEED |

Oracle adapter (not an SE, but prices mixed decimals): `test/foundry/spec/oracles/uniswap/v4/twap/UniswapV4MultiPoolTwapOracle_Adapters.t.sol` `test_H19_non18SnapshotNativeAndMissingDecimals` HAVE 6. NEED the same snapshot asserts with a 9-dec token.

#### 4.4 Aerodrome V1 SE

Test root: `test/foundry/spec/protocol/dexes/aerodrome/v1/`.

| Scenario | Suite | Exact 18-dec tests (representative; every `test_*` in the file is in-scope unless EX-*) | All 8 non-18 combos |
|----------|-------|----------------------------------------------------------------------------------------|---------------------|
| SC-DEPLOY | `AerodromeStandardExchange_DeployWithPool.t.sol` | `test_US11_1`–`US11_5`; double-deploy; allowance | NEED |
| SC-DIRECT | `AerodromeStandardExchangeIn_Swap.t.sol` | `test_Route1Swap_previewVsMath_{balanced,unbalanced,extreme}_{AtoB,BtoA}`; `test_Route1Swap_execVsPreview_*`; `test_Route1Swap_balanceChanges_*`; `test_Route1Swap_slippageProtection_*`; `test_Route1Swap_pretransferred_true`; `test_Route1Swap_pretransferred_true_reverts_whenOnlyReservedDust`; `test_Route1Swap_pretransferred_true_retainsReservedDust`; `test_Route1Swap_pretransferred_false` | NEED |
| zap / vault | `AerodromeStandardExchangeIn_ZapIn.t.sol`; `…ZapInDeposit.t.sol`; `…ZapOut.t.sol`; `…ZapOutWithdraw.t.sol`; `…VaultDeposit.t.sol`; `…VaultWithdraw.t.sol`; `AerodromeStandardExchangeOut_Swap.t.sol` | `test_Route2ZapIn_*`; `test_Route3ZapOut_*`; `test_Route4VaultDeposit_*`; `test_Route5VaultWithdraw_*`; `test_Route6ZapInDeposit_*`; `test_Route7ZapOutWithdraw_*`; `test_exchangeOut_swap_*` | NEED |
| SC-FEE | `AerodromeStandardExchange_FeeCompound.t.sol` | `test_US10_1`–`US10_8` | NEED |
| deadline / fuzz | `AerodromeStandardExchange_Deadline.t.sol`; `AerodromeStandardExchange_Fuzz.t.sol` | money-path `test_*` | NEED every combo |
| SC-E6 / A0 / I1 | `AerodromeStandardExchange_E6_A0_I1.t.sol`; `AerodromeStandardExchange_ReentrancyGuard.t.sol` | all `test_*` | NEED |
| invariant | `AerodromeStandardExchange_InOutInvariant.t.sol`; `invariant/AerodromeStandardExchange.invariant.t.sol` | campaign | NEED every combo |
| adversarial | `test/foundry/spec/vaults/standard-exchange/adversarial/AerodromeSE_Adversarial.t.sol` | all money-path `test_*` | NEED |

#### 4.5 Camelot V2 SE

Test root: `test/foundry/spec/protocol/dexes/camelot/v2/`.

| Scenario | Suite | Exact 18-dec tests | All 8 non-18 combos |
|----------|-------|--------------------|---------------------|
| SC-DEPLOY | `CamelotV2StandardExchange_DeployWithPool.t.sol` | all `test_*` | NEED |
| SC-DIRECT | `CamelotV2StandardExchangeIn_Swap.t.sol` | all `test_*` | NEED |
| vault | `CamelotV2StandardExchangeIn_VaultDeposit.t.sol` | all `test_*` | NEED |
| slippage | `CamelotV2StandardExchangeIn_SlippageProtection.t.sol` | all `test_*` | NEED |
| invariant / reentrancy / sec | `CamelotV2StandardExchange_InOutInvariant.t.sol`; `…_ReentrancyGuard.t.sol`; `…_SecRemediation.t.sol` | all money-path `test_*` | NEED |
| adversarial | `test/foundry/spec/vaults/standard-exchange/adversarial/CamelotSE_Adversarial.t.sol` | all money-path `test_*` | NEED |

#### 4.6 Slipstream SE

Test root: `test/foundry/spec/protocols/dexes/aerodrome/slipstream/`.

| Scenario | Suite | Exact tests | All 8 non-18 combos |
|----------|-------|-------------|---------------------|
| quotes (not live vault) | `SlipstreamStandardExchangeRoutes_Test.t.sol` | `test_zapIn_depositQuote_*`; `test_zapInRoute_token{0,1}ToVaultShares`; `test_zapOut_*`; `test_invalidRoute_randomTokenToVault`; `test_deadline_validation`; `test_slippage_protection` | NEED quote math on 6/9 reserves. This file is `pure`/`view` ConstProdUtils and does **not** inherit `TestBase_SlipstreamStandardExchange` |
| **Fill first (D13)** | new gold `SlipstreamStandardExchange_Routes.t.sol` on `TestBase_SlipstreamStandardExchange` (this filename, no alias) | Live `exchangeIn`/`exchangeOut` zap token0/token1 → shares and reverse, preview==exec, first and subsequent join | Write at **18-dec** first, then clone all eight combos |
| live wrap (thin today) | `adversarial/Adversarial_SlipstreamSE_E6IJ.t.sol` | `test_E6_in_refund_doesNotSweepBookedInventory`; `test_E6_out_pretransferred_fatMax_*`; `test_I1_*` in and out | NEED all eight combos after the gold exec suite exists |
| EX-IFACET | `SlipstreamStandardExchangeInFacet_IFacet_Test.t.sol`; `…OutFacet_IFacet_Test.t.sol` | inherited `TestBase_IFacet` | N/A |

- [ ] Every two-token SE in §4.1–§4.6 has passing clones of every non-exempt listed `test_*` on all eight two-token combos
- [ ] `SlipstreamStandardExchange_Routes.t.sol` exists and is green at 18-dec before any `decimals/` Slipstream clone
- [ ] Uni V4 native-wrap clones only `P6_R18` and `P9_R18` (native stays 18)
- [ ] EX-IFACET / empty inherit rows are not cloned

### 5. Uniswap V4 hooks (swap + SE buffer)

N-leg products use the eight books in §1. Two-token CP / dual / single-SE-buffer hooks use the eight two-token combos in §4.

Existing 6-dec fragments (PARTIAL, not the program):

| Existing test | What it covers | Still NEED |
|---------------|----------------|------------|
| `UniswapV4StandardExchangeWeightedBufferHook_Scale.t.sol` `test_FIX_mixedDecimals_6and18` | first proportional join, 6 raw + 18 SE | 9-dec; pair orientations; swap/exit/fee/I1 |
| `UniswapV4StandardExchangeBalancerQuadStableBufferHook_Scale.t.sol` `test_FIX_SCALE_6_18_mixedDecimalsFirstMint` | first mint 6+18 | same |
| `UniswapV4StandardExchangeCurveQuadStableBufferHook_Scale.t.sol` `test_FIX_SCALE_6_18_mixedDecimalsFirstMint` | first mint 6+18 | same |
| Quad swap TestBase (`MintableDec` USDC/USDT 6 + DAI/USDS 18) + `test_L5_mixedDecimals_6_6_18_18` | default book is 6/6/18/18, **not** pair-orientation catalog, **not** 9 | `B_ALL9`, `B_P9_*`, `B_P18_R6` / `B_P6_R9` orientations |
| Weighted swap `_deployN3` USDC 6; `_deployN4` 6/8/18/18; `test_FIX_S1_scaleDescalemixedDecimals` (6, 8, 18) | math + one 6-dec n3 | 9-dec scale/descale; books in §1 |
| Weighted `UniswapV4WeightedSwapHook_StagedInit.t.sol` USDC 6 n3 | staged init with 6 | 9; full join/swap on books |
| Weighted deploy `MintableERC20Decimals` 5 and 19 | InvalidDecimals band | keep; 9 must **succeed** deploy |
| Orbital `UniswapV4OrbitalSwapHook_Decimals.t.sol` | asserts LP decimals 18 | does **not** test 6/9 underlyings |

Exempt on every hook: factory flag/salt/idempotent files, `*Facet` declaration, staged-init door-count tests that never join.

In-scope hook scenario sets (clone onto required books):

#### 5.1 Orbital swap hook

Suites: `test/foundry/spec/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHook_{Deploy,Liquidity,Swap,Fees,Preview,Permit2,Adversarial,Reentrancy}.t.sol`.

Must clone: `test_firstMint_setsRadiusAndMinLiquidity`; `test_firstMint_requiresTwoLegs`; `test_previewAdd_bitExact_firstMint`; `test_fullBook_threeLeg_previewBitExact`; `test_fullBook_oneSidedReverts`; `test_remove_bitExact_andBurnMsgSender`; `test_partial_seedOnly_sphereNav_notSumNav`; `test_exactIn_allSixDirections_previewBitExact`; `test_exactOut_previewBitExact_token0_to_token1`; `test_noFullDrain`; `test_zeroFee_path`; `test_tradingFee_residualStaysInReserve`; `test_growthFee_mintsToFeeTo_afterSwaps`; `test_feeOff_ownerFeeShareZero`; `test_A1_donationsIgnored_reserveOfUnchanged`; `test_reentrancy_addLiquidity_duringTransferFrom_reverts`; plus Permit2 money-path `test_*`. `test_lpDecimalsAlways18` is not 6/9 underlying coverage.

Books: all eight `B_*`. Consolidation: one new suite per book inheriting the liquidity+swap+fee bodies.

#### 5.2 Weighted swap hook

Suites: `…/weighted/UniswapV4WeightedSwapHook_{Liquidity,Swap,Fees,Preview,Partial,Permit2,Rates,Safety,Reentrancy,Math}.t.sol`.

Must clone: `test_L1_firstMintFull_minOnAddress0`; `test_L2_propJoinExit_previewEqExec`; `test_L4_exitBurnsMsgSenderOnly`; `test_L5_wouldZeroReserve_fullExitBlocked`; `test_L6_unbalancedJoin_fullBook`; `test_L7_singleAssetJoinExit`; `test_P1_partialFirstMint_n3`; `test_P2_n2_rejectsPartialFirstMint`; `test_P3_seedCompletesToFull`; `test_P4_unbalancedRestrictedWhilePartial`; `test_P5_partialExitProportional`; `test_S1_previewExactInExactOut`; `test_S2_swapExactIn_viaRouter_updatesReserves`; `test_S3_swapNotLive_partialLeg`; `test_S4_maxInRatio`; `test_S5_feeZero_stillWorks`; `test_S6_multiDoor_n3`; `test_FIX_S1_scaleDescalemixedDecimals` **extended with `baseScaleFromDecimals(9)`** (HAVE 6 and 8 in math; NEED 9); `test_G1_growthMintOnJoinAfterSwap` … `test_G4_growthOnExit`; `test_R1_rateProviderPath`; `test_R2_rateProviderFailClosed`; `test_R3_badReturndataFailClosed`; `test_X2_donateBlocked`; `test_X3_donationIgnored`; `test_RE1_reentrancyOnJoinReverts`. `_deployN3` HAVE USDC-6 join/swap; `_deployN4` 6/8/18/18 is **doors only**, not a live 8-dec book (8-dec is out of this PRD). **D14:** n=2 uses the eight two-token combos; n=3 and n=4 get all eight `B_*` books with live join/swap (n=4 must become a live book, not doors-only); n=8 smoke runs `B_P6_R18` and `B_P9_R18` only.

#### 5.3 Quad stable swap (Balancer and Curve)

Suites under `…/stable/quad/{balancer,curve}/` Liquidity, Swap, Zap, Rates, Safety, Reentrancy, Math.

Must clone: `test_L1_firstMint_locksMinLiqToZero`; `test_L2_firstMint_withOpenDoors_noPriorSwaps`; `test_L3_laterProportional_mins`; `test_L4_removeProRata`; `test_L5_mixedDecimals_6_6_18_18` **replaced by the eight books** (today only asserts the default 6/6/18/18 mix); `test_L6_donation_doesNotChangeReserves`; `test_I2_donate_reverts`; `test_S0_inertBook_swapReverts`; `test_S1_exactIn_pair0_previewEqualsExecution`; `test_S1b_exactIn_pair0_oneForZero`; `test_S_allSixPairs_exactIn_bothDirections`; `test_S_allSixPairs_exactOut_bothDirections`; `test_S14_exactOut_zero_reverts`; `test_FIX_SCALE_baseScaleFromDecimals` plus Curve `test_scaleDescale_roundTrip_18dec` / `test_scaleDescale_6dec` **extended with 9**; zap `test_Z1`–`test_Z6_*`; `test_R1_rateProvider_scales`; `test_R3_zeroProviders_decimalOnly`; `test_A1_reentrancy_{addLiquidity,zapIn,removeLiquidity}`.

Balancer and Curve are separate SUTs. Each gets the eight books.

#### 5.4 Single SE wrap hook and Single SE CP buffer hook

Two products. Both arity 2. Both NEED all eight two-token combos. Today 18-only except where noted.

**Wrap/unwrap (legacy single SE buffer)** suites: `…/standardExchange/single/UniswapV4SingleSEBufferHook_{Routes,RouteSmoke,Fees,Flat,LiquidityBan}.t.sol` and `adversarial/Adversarial_{Access,Accounting,Donation,Economic,Griefing,Reentrancy}.t.sol`.

Must clone: `test_HS1_wrapExactIn_previewEqualsExecution`; `test_HS2_unwrapExactIn_previewEqualsExecution`; `test_HS3_wrapExactOut_previewEqualsExecution`; `test_HS4_unwrapExactOut_previewEqualsExecution`; `test_HS7_wrapWithUsageFee_previewEqualsExec_feeToMints_noHookFee`; `test_flat_afterWrapUnwrap`; `test_A1_pairDonation_doesNotMintFreeSE`; `test_A2_seDonation_doesNotCreditFreeUnwrap`; `test_A3_donateThenSwap_idleNotCredited`; `test_C1_hostilePair_reenterOnWrap`; `test_C2_hostilePair_reenterOnUnwrap`; `test_C3_reenterSE_fromTokenCallback`.

**CP buffer** suites: `…/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_{Liquidity,Swap,Fees,Permit2,Adversarial,OwnerOnlyLiquidity,OwnerDuringLock,VaultViews}.t.sol`.

Must clone: `test_P1_firstDeposit_minLiquidityAndVirtualPair`; `test_P3_subsequentDeposit_previewEqualsExec_clampRefund`; `test_W1_withdraw_previewEqualsExec`; `test_B6_depositWithSeShares_firstMint_mintsLp`; `test_B6_depositWithSeShares_subsequent_previewEqualsExec`; `test_B6_withdrawSeShares_paysSeAndRaw_previewEqualsExec`; zap `test_Zi1_*` / `test_Zo1_*`; `test_S1_exactIn_bothDirections_previewEqualsExec`; `test_SE1_exchangeIn_*`; `test_SE2_exchangeOut_bothDirections`; `test_D30_ownerSwapExactIn_*`; `test_D30_ownerSwapExactOut_*`; `test_A1_seDonation_dilutesLps_noFreeMint`; `test_A2_rawDonation_doesNotFreeExtract`; `test_C1_hostileRaw_reentrancy_onDeposit`; `test_F2_protocolFee_mintsToFeeTo_onGrowth`; `test_F3_feeOff_kLastZero`. Mixed decimals: none today.

#### 5.5 Dual SE CP buffer hook

Suites: `…/dual/UniswapV4DualSEBCPHook_{Core,Swap,Adversarial,B6M3}.t.sol`. Gold fixture is two ERC-4626 SEs (`TestBase_UniswapV4DualSEBCPHook`). Decimal matrix is the nine `D_U*` cells in §1. Clone onto every NEED cell (`D_U6_U6` … `D_U18_U9`). Do not add Dual-with-two-token-SE fixtures. Do not run an 8×8 two-token cartesian.

Must clone onto every NEED `D_U*` cell: `test_P1_firstDeposit_mintsLpAndMinLiquidity`; `test_P3_subsequentDeposit_previewEqualsExecution`; `test_B6_depositSeSharesBothLegs_mintsLp`; `test_B6_depositMixed_seAndPair`; `test_W1_withdraw_unwrapBoth`; `test_B6_withdrawSeShares_paysSe`; `test_B6_withdrawMixed_seAndPair`; `test_S1_exactIn_zeroForOne_previewEqualsExecution`; `test_S1b_exactIn_oneForZero_*`; `test_M3_exchangeOut_previewEqualsExec`; `test_A1_pairDonation_doesNotFreeExtract`; `test_A2_seDonation_doesNotMintFreeLp`; `test_C1_hostilePair_reenterOnDeposit`; `test_F2_protocolFee_mintsToFeeTo`. Today `D_U18_U18` only.

Unified DETF **must not** bind this hook. Gold CP `test_T7_1_dualHook_reverts` stays a bind-revert (N/A for decimal clones of a DETF instance). Decimal coverage for Dual SE is hook-only.

#### 5.6 SE weighted / orbital / quad-stable buffer hooks

Same books as the matching swap hook (§5.1–5.3). Scale first-mint tests that already use 6+18 remain and do **not** skip `B_P9_*` or `B_P18_R6`.

**SE orbital** (today 18-only): `test_firstMint_twoLegs_setsR`; `test_firstMint_threeLegs`; `test_B6_firstMint_withSeShares`; `test_fullBook_subsequent_previewEqualsExec`; `test_remove_previewEqualsExec`; `test_partialBook_seedThirdLeg`; `test_swap_exactIn_allSixDirections`; `test_swap_exactOut_preview`; `test_swap_exactOut_execution_previewEqualsExec`; `test_exchangeIn_previewEqualsExec`; `test_exchangeOut_previewEqualsExec`; `test_bufferedLeg_freeTokenNotBook`; `test_C1_reentrancy_addLiquidity_duringTransferFrom_reverts`; `test_protocolGrowth_onAdd_assertGt`; `test_RP1_effectiveReserve_is_sharesTimesRate`.

**SE weighted**: `test_firstMint_fullBook_mintsVminusMin`; `test_firstMint_fullBook_inventoryBook`; `test_partialFirstMint_twoLegs_n3`; `test_joinProportional_previewEqualsExecution`; `test_joinUnbalanced_previewEqualsExec`; `test_exitProportional_previewEqualsExec`; `test_swapExactIn_v4Door_afterFirstMint`; `test_swapExactOut_previewAndSeExec`; `test_seExchangeIn_previewEqualsExec`; `test_seExchangeOut_previewEqualsExec`; `test_FIX_mixedDecimals_6and18` (HAVE 6+18 first mint only); `test_liveSeBook_donationDilutes`; `test_C1_reentrancy_join_hitsReentrancy`; `test_n8_smoke_deployDoorsMintSwapJoin` cloned onto **`B_P6_R18` and `B_P9_R18` only** (D14). `test_reject_badDecimals_pairToken` (5) and `…19` stay as InvalidDecimals; 9 must **succeed**.

**SE Balancer/Curve quad buffer**: `test_firstMint_fullBook_geoMeanMinusMin`; `test_joinProportional_previewEqualsExecution`; `test_propJoinExit_previewEqualsExec`; `test_depositSingle_withdrawSingle_previewEqualsExec`; `test_swapExactIn_onePair_previewEqualsExec`; `test_swapExactOut_onePair_previewEqualsExec`; `test_swapExactIn_allDirectedPairs`; `test_swapExactOut_allDirectedPairs_previewPositive`; `test_seExchangeIn/Out_previewEqualsExec`; `test_FIX_SCALE_6_18_mixedDecimalsFirstMint` (HAVE one raw 6 + three 18, not the eight books); `test_donation_rawFace_dilutesJoin`; `test_A1_donation_seShares_dilutesJoin`; `test_C1_reentrancy_join_hitsReentrancy`; Curve extra B6Firm flexible join/exit.

- [ ] Two-token hooks in §5.4 clone the listed tests onto all eight two-token combos
- [ ] Dual SE clones the listed tests onto every NEED `D_U*` cell; no two-token Dual fixture exists
- [ ] Orbital / weighted / quad swap and matching SE buffer hooks clone listed tests onto the books in D14 / §1
- [ ] Factory / IFacet / staged-init door-count tests stay EX-FACTORY / EX-IFACET

### 6. Unified Uniswap V4 DETF

SUT: `UniswapV4DetfDFPkg` / `IUniswapV4Detf` only. Do not restore family DETF diamonds. Do not edit `TestBase_UniswapV4Detf.sol` (locked). New decimal TestBases are new files.

#### 6.1 Gold Open + Policy scenario IDs (18-dec HAVE; decimal NEED)

These IDs already run on gold CP / Orbital / Weighted / Quad at 18 decimals. Every ID that is not EX-* must run on the consolidated books in §6.3.

**Stage 11 Open IDs** (inherited by every `*_ProductLaw.t.sol` via `UniswapV4Detf_Stage11OpenSuite` + Open bases). Suites: `UniswapV4Detf_IoTablesOpenBase.sol`, `UniswapV4Detf_ClaimOpenBase.sol`, `UniswapV4Detf_Alignment_CloseD25OpenBase.sol`, `UniswapV4Detf_ReserveDonationOpenBase.sol`, `UniswapV4Detf_AdversarialOpenBase.sol`, `UniswapV4Detf_OwnerOnlyLiquidityOpenBase.sol`, `UniswapV4Detf_Alignment_RedeemD15OpenBase.sol`, plus suite extras.

| ID | Function | Clone onto books |
|----|----------|------------------|
| T7.2 | `test_T7_2_defaultTables_pairAndShare_noUnderlyings` | YES |
| T7.10 | `test_T7_10_laterBond_joinUnbalanced_unboostedG` | YES |
| T7.14 | `test_T7_14_commonNftUnused_claimHoldsNoHookLp` | YES |
| T7.19 | `test_T7_19_afterMint_diamondHasNoJoinableBalances` | YES |
| owner | `test_reserveHook_ownerIsDetf`; `test_reserveHook_thirdPartyAddReverts` | YES |
| sell | `test_preMaturity_sell_reverts`; `test_postMaturity_sell_mintsRebasingClaim`; `test_claimRewards_whileLocked` | YES |
| D15 | `test_D15_1_previewEqualsExecute`; `test_D15_8_nonDetfPayoutForbidden`; `test_D15_redeem_paysDetf_only` | YES |
| D25 | `test_D25_1_userDetfOnlyFromClaimRewards` … `test_D25_7_minRejoinLpOutGt0`; `test_D25_lastClose_feeCreatorPendingDoesNotJump` | YES |
| DN | `test_DN1_donate_pair_Ogt0_unassignedLp`; `test_DN2_donate_vaultShare`; `test_DN4` … `test_DN14`; `test_DN16` … `test_DN22` (DN3/DN15 NatSpec N/A) | YES |
| I/A0/K | `test_A0_donateBeforeFirstBond_cannotFreeMint`; `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork`; `test_I1_{mint,bond,donate}_*`; `test_I2_*`; `test_I3_*`; `test_K1_donationNotMintCredit` | YES |
| nest | `test_T_NEST_1_nestedHappy_pushTrue_hostReservesSync`; `test_T_NEST_2_*`; `test_T_NEST_3_*`; `test_T_LOCAL_I1_*` | YES |
| compound | `test_compound_raises_protocolLp`; `test_open_never_expands` | YES |

**Stage 11 Policy IDs** (`UniswapV4Detf_Stage11PolicySuite` + `UniswapV4Detf_PolicyLayerBase` + OpeningPrice layer + D15 Policy + FC base). Concrete FC names are `test_FC1_univ4Detf_<FixtureId>_*` on each sibling.

| ID | Function | Clone |
|----|----------|-------|
| T7.8 | `test_T7_8_policy_isMintingAllowed_token` | YES |
| deadband | `test_policy_mint_blocked_in_deadband_then_allowed_after_push`; `test_policy_burn_allowed_when_synthetic_below_burnThreshold` | YES |
| D31 | `test_D31_1_policyMint_realizesThenGates`; `test_D31_2_realizeWouldCloseMint_revertsUnchanged`; `test_D31_3_policyBurn_realizesThenGates` | YES |
| D22 | `test_D22_claimUngated` / `test_D15_9_ungatedVsPolicy` | YES |
| T1 T2 T5 | `test_T1_openingZero_storesAsCreation_firstBondGAtPeg`; `test_T2_openingUsesG_creationViewUnchanged`; `test_T5_creationZero_revertsInvalidCreationRate` | YES |
| T6 | `test_T6_openingLengthMismatch_reverts` | YES on Weighted and Quad only |
| T8.4 | `test_T8_4_policy_pairA_not_pairB_via_trades` | YES on Weighted only |
| FC1–FC12 | `test_FC1_univ4Detf_<id>_feeToAndCreatorCanClaim` … `test_FC12_univ4Detf_<id>_conservationTwoWaves` | YES |
| D15 subset | same three D15 functions as Open | YES |

**Gold-only IDs** (CP / Orbital / Weighted / Quad gold suites, not Stage 11). Clone money-path IDs onto books. J1–J3 and T7.16/T7.18 stay EX-J. `test_T7_15_L2_FoT_forbidden` is EX-FOT-NATS. `test_T7_1_dualHook_reverts` is bind-revert only (Dual SE is **not** a DETF host).

| Function | Clone |
|----------|-------|
| `test_T7_1_bareStandardExchange_reverts`; `test_T7_1_customCloseLengthNotOne_reverts`; `test_T7_1_customCloseLengthTwo_reverts`; `test_deploy_inert_until_first_bond` | YES (amounts at deploy) |
| `test_T7_1_dualHook_reverts` | N/A bind-revert; Dual SE decimals live on the **hook** (§5.5), not on a DETF instance |
| `test_T7_3_customMint_seUnderlying_allowed`; `test_T7_4_customVault_notHookSe_reverts` | YES |
| `test_T7_5_firstBond_joinUnbalanced_goesLive`; `test_preLive_mint_reverts` | YES |
| `test_T7_6_liveMint_grossSwapQuote_d11` | YES |
| `test_T7_7_liveMint_share_pairEqFromPreviewExchangeOut` | YES |
| `test_T7_9_liveBurn_previewEqExec_pair`; `test_T7_9_previewExitProp_is_not_withdrawSingle` | YES |
| `test_T7_11_customClose_leftoverOwnerSwap` (CP); `test_T8_3_customClose_onePair` (Quad execute) | YES |
| `test_T7_12_defaultClose_basket_pairOut`; `test_T7_13_donatePair_Ogt0_unassignedLp` | YES |
| `test_T7_16_exactOut_absent`; `test_T7_17_joinUnbalanced_pairAndShareSameLeg_reverts`; `test_T7_18_noFamilyGetters` | EX-J / selector |
| `test_T7_20_sweepDust_joinsPairDust_unassignedLp`; `test_T7_20_afterBond_noJoinableDust`; `test_T7_21_failedDustJoin_doesNotRevertMint` | YES |
| `test_D15_2_smallRedeemConsumesPending`; `test_D15_3_pendingCoversOwed_skipsLpWithdraw`; `test_D15_4_shortfallResidualBuy_otherBondersUnchanged`; `test_D15_5_multiLegLeftoverDump` (n-leg); `test_D15_6_lastExitRejoinsLeftover`; `test_D15_7_realizeExpansionFirst_paysFromId0Slice`; `test_D15_pendingFirst_thenZapOutToDetf` | YES |
| `test_D31_4_openMintDoesNotExpand` | YES on gold Open |
| Orbital extras: `test_T8_1_sameDetfPkg_asCp`; `test_T8_1_defaultMintRows_twoPairsTwoShares`; `test_T8_1_firstBond_threeLegs`; `test_T8_1_liveMint_onePair` | YES |
| Quad extras: `test_T8_3_firstBond_fourLegs` | YES |
| `test_F1_satellitesUnowned`; `test_reentrancy_mint_hitsIsLocked`; J1–J3 | EX-J / YES reentrancy |

Gold files that contain those tests today (`H18` HAVE):

- CP: `UniswapV4Detf_{Mint,Bond,Burn,Close,Deploy,Donate,Dust,IoTables,OpeningPrice,Policy,Claim,ReserveDonation,OwnerOnlyLiquidity}.t.sol`; `UniswapV4Detf_Alignment_{CloseD25,RedeemD15,FeeCreatorClaim}.t.sol`; `adversarial/Adversarial_{A0Crops,TrustFlags,Surface,Reentrancy,NestedSe}.t.sol`
- Orbital / Weighted / Quad: matching `UniswapV4Detf_{Orbital,Weighted,Quad}_*.t.sol` and `UniswapV4Detf_{Orbital,Weighted,Quad}_Adversarial_*.t.sol`

#### 6.2 Stage 11 firstBond/mint/burn/close (26 fixtures, 18-dec HAVE)

These contracts are **not** ProductLaw. They still move pair tokens. **Every fixture** must clone firstBond/mint/burn/close onto every book required for that fixture’s arity (D5).

| Fixture | Suite | Exact tests |
|---------|-------|-------------|
| H-CP-GV4 | `prod-se/UniswapV4Detf_Cp_Univ4Se.t.sol` | `test_H_CP_GV4_firstBond`; `test_H_CP_GV4_mint`; `test_H_CP_GV4_burn`; `test_H_CP_GV4_close` |
| H-CP-GV3 | `prod-se/UniswapV4Detf_Cp_Univ3Se.t.sol` | matching `test_H_CP_GV3_*` |
| H-CP-MB | `prod-se/UniswapV4Detf_Cp_MorphoBlueSe.t.sol` | matching Morpho fixture names |
| H-CP-P1 | `prod-se/UniswapV4Detf_Cp_PonsV1Se.t.sol` | matching |
| H-CP-P2 | `pons/UniswapV4Detf_PonsV2Se.t.sol` | `test_T10_8_firstBond_withPonsSeLive`; `test_T10_9_liveMint_weth` (launch-token mint despite the name); `test_T10_10_afterMint_diamondHasNoJoinableBalances`; `test_H_CP_P2_{firstBond,mint,burn,close}` |
| Orbital / Weighted / Quad × Univ4, Univ3, MorphoBlue, MorphoMix, PonsV1, PonsV2, PonsMix | matching `prod-se/UniswapV4Detf_{Orbital,Weighted,Quad}_*.t.sol` | that fixture’s `test_*_firstBond/mint/burn/close` |

Pons launch tokens are protocol-fixed 18. Do not invent a 6-dec pons launch token. For H-CP-P2 / PonsMix / PonsV1 fixtures: N/A on changing the launch token decimals; still run `P18_R6` / `P18_R9` (and n-leg `B_P18_R6` / `B_P18_R9`) when the **other** hook/SE token is configurable.

ProductLaw / Policy siblings for all 26 fixtures (`*_ProductLaw.t.sol`, `*_Policy.t.sol`) already execute the §6.1 Open/Policy IDs at 18 decimals. Decimal clones of those IDs follow D5: **every fixture × every book for that arity**.

#### 6.3 DETF consolidation (LOCKED)

Consolidation applies to **n-leg token shapes** (eight `B_*` books, not a cartesian of every leg’s decimals). It does **not** skip Stage 11 fixtures.

| Layer | Decimal books |
|-------|----------------|
| Gold CP | eight two-token combos in §4 (`H6` … `P9_R6`) on the gold ERC-4626 / Uni V4 SE used by `TestBase_UniswapV4Detf` |
| Gold Orbital / Weighted / Quad | eight `B_*` books |
| Stage 11 | **Every** ProductLaw sibling, Policy sibling, and firstBond/mint/burn/close contract among the 26 fixtures runs every book required for that fixture’s arity. CP fixtures: eight two-token combos (or `U6`/`U9` when the bound SE is single-underlying Morpho). Orbital/Weighted/Quad fixtures: eight `B_*` books. Pons launch-token fixtures: do not change launch-token decimals; still run books that vary the **other** configurable leg (`P18_R6`, `P18_R9`, `B_P18_R6`, `B_P18_R9`) |
| Morpho-bound DETF | `U6` and `U9` on the Morpho **loan** token, including full Open/Policy ID set and firstBond/mint/burn/close, on every Morpho Stage 11 fixture (H-CP-MB, H-OR-MB, H-WE-MB, H-QD-MB, MorphoMix) |

- [ ] Every §6.1 Open/Policy/gold money-path ID that is not EX-* runs on every book required for that family’s arity
- [ ] Every Stage 11 firstBond/mint/burn/close contract among the 26 fixtures runs those four tests on every book for that fixture’s arity
- [ ] ProductLaw and Policy siblings for all 26 fixtures run the §6.1 IDs on those same books
- [ ] `TestBase_UniswapV4Detf.sol` is byte-identical to pre-program (not edited)
- [ ] Pons launch-token decimals stay 18; books vary only the other configurable leg as D9

### 7. Balancer V3 DETF families

Same scenario classes as unified DETF (bond, mint, burn, close D25, D15, FC, Policy/D31, donation, I1, compound). 18-dec HAVE in the listed suites. Decimal NEED per arity.

#### 7.1 Single Standard Exchange DETF

Test root: `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/`. Two-token (pair + SE share). Combos: eight in §4.

In-scope suites (clone every money-path `test_*` listed). EX-IFACET: `SingleStandardExchangeDETFExchangeInFacet_IFacet_Test.t.sol`. EX-J: `Adversarial_Surface.t.sol`. Fuzz/invariant: every combo.

| Scenario | Suite | Exact 18-dec tests (all NEED the eight two-token combos) |
|----------|-------|----------------------------------------------------------|
| SC-DEPLOY / bond | `SingleStandardExchangeDETF_Deploy.t.sol`; `…_Bonding.t.sol` | `test_deploy_inert_notLive`; `test_deploy_mintRevertsWhileInert`; `test_deploy_syntheticPriceAtOneWhenNoSupply`; `test_firstBond_bootstrapsReserveLive`; `test_bond_live_unboostedG_and_d4Pot`; `test_bond_revertsIfLockTooShort`; `test_bond_clampsLockAboveMax`; `test_sellPositionToDetfNft_revertsBondNotMature`; `test_sellPositionToDetfNft_afterMaturity_mints4626` |
| SC-DETF-MINT / BURN | `…_Mint.t.sol`; `…_Burn.t.sol` | `test_mint_fromVaultShares_afterBootstrap`; `test_mint_doesNotIncreaseReserveDetf_orFeeTo`; `test_mint_revertsWhenInert`; `test_mint_stillGatedByThresholdAfterBootstrap`; `test_burn_toVaultShares`; `test_burn_decreasesDetfSupply` |
| Policy | `…_ThresholdMode.t.sol`; `…_Info.t.sol` | all `test_deploy_policyDefaults_*`; deadband mint/burn; `test_info_*` that read prices |
| FC | `…_Alignment_FeeCreatorClaim.t.sol` | `test_FC1_singleSe_feeToAndCreatorCanClaim` … `test_FC12_singleSe_conservationTwoWaves` |
| D15 / D25 / D31 | Alignment Redeem/Close/D31 | HAVE: `test_D15_1_previewEqualsExecute`; `test_D15_8_tokenOutNotDetfReverts`; `test_D15_9_ungatedVsOpen`; D25-1..6; `test_D25_lastClose_feeCreatorPendingDoesNotJump`; `test_D31_4_openMintDoesNotExpand`. **D13 fill first:** add Uni V4-parity `test_D15_2_smallRedeemConsumesPending`; `test_D15_3_pendingCoversOwed_skipsLpWithdraw`; `test_D15_4_shortfallResidualBuy_otherBondersUnchanged`; `test_D15_6_lastExitRejoinsLeftover`; `test_D15_7_realizeExpansionFirst_paysFromId0Slice` (and D15-5 on n-leg families) at 18-dec, then clone |
| Donate | `…_ReserveDonation.t.sol` | `test_N1_donate_pairToken_credits_id0` … `test_N21_d2_afterDonate` (skip N/A N11/N14/N22 NatSpec) |
| Compound / expansion | `…_ProtocolCompound.t.sol`; `…_NaturalExpansion.t.sol` | `test_C1_C2_lazyCompoundOnMintIncreasesProtocolBpt`; `test_C3_userClaimFreeDetfWhileLocked`; `test_C4_feeRecipientGetsFreeDetfNotAutoJoined`; `test_C5_protocolCompoundRaisesClaimRateProxyPrincipal`; `test_C6_publicCompoundProtocolRewards`; `test_C7_publicAbiAndOnlySelfAtomic`; `test_C8_joinFailureBestEffort_thenRetry`; `test_E1_policyExpandAfterRichSyntheticAndWarp` … `test_E8_catchUpCapAndNoDoubleCount` |
| Product law | `…_ProductLaw.t.sol` | `test_M1_preMaturitySell_revertsBondNotMature` … `test_M8_buyClaim_emptyThenFewerShares`; `test_close_previewMatchesExecute_paysVaultShare`; M12–M15 |
| Nested | `…_NestedPush.t.sol`; `…_ComposedStableMatrix.t.sol` | T-NEST-1..8; `test_T_LOCAL_PUSH_transferToDetf_true_whenClaimedLeU`; `test_T_LOCAL_I1_bookedDetf_trueWithoutPushReverts`; `test_matrix_composedStable_outerFirstBondAndInnerStillServes` |
| Adv / I / A0 | `adversarial/Adversarial_{A0Crops,SingleSE_P0,TrustFlag,Reentrancy}.t.sol` | A0, CROPS, I1/I2/I3, P0 E5/A1–A3/D2–D6/F1–F4/C1/H2/H3; `test_reentrancy_mintSharePath_nestedHitsIsLocked`; `test_reentrancy_crossFunction_bond_nestedHitsIsLocked` |
| Fuzz / inv | `fuzz/SingleStandardExchangeDETF_Fuzz.t.sol`; `invariant/SingleStandardExchangeDETF.invariant.t.sol` | `testFuzz_mintThenPartialBurn_conservation`; `testFuzz_holderBalance_notDilutedByOthersMint`; `testFuzz_zeroPreview`; `invariant_residualDetfZero`; `invariant_ghostConsistent`; `invariant_actorBalancesLeSupply`; `invariant_stillLive` |
| Guards / disable | `…_Guards.t.sol`; `…_Disable.t.sol`; `…_Requirements.t.sol` | `test_guard_zeroAmountReverts`; `test_guard_deadlineExpiredReverts`; `test_guard_unsupportedRouteReverts`; disable/reenable exchangeIn; fee-split dest |

#### 7.2 Multi-vault weighted DETF

Test root: `…/multi-vault-weighted/`. N-leg. Books: eight `B_*`. Consolidation: do not cartesian every vault’s underlying. Apply books to **raw unpaired / pairToken roles** the same way as Uni V4 weighted.

In-scope: `MultiVaultWeightedDetf_{Deploy,MintBurn,Bonding,Claim,ProductLaw,ProtocolCompound,NaturalExpansion,ThresholdMode,ReserveDonation,Liveness,FeeNonDilution,MixedRated,MultiLeg,NRange,PriceShift,Nested,NestedPush,Reentrancy,Alignment_*}.t.sol`; `adversarial/Adversarial_{A0,Access,BondClaim,Donation,Economic,Griefing,Guards,Nested,PkgArgs,PriceManipulation,Reentrancy,TrustFlags}.t.sol`. EX-J: `Adversarial_Surface.t.sol`. EX-IFACET: ExchangeIn facet test. Fuzz/invariant: every `B_*` book. **D13:** same D15-2..7 fill-then-clone as §7.1 (include D15-5).

#### 7.3 Composed stable common DETF

Test root: `…/stable/common/`. N-leg stable. Books: eight `B_*`.

In-scope: `ComposedStableCommonDetf_{IntegratedDeploy,ProductLaw,ProtocolCompound,NaturalExpansion,ThresholdMode,NestedPush,Alignment_*}.t.sol`; `adversarial/Adversarial_ComposedStable_{P0,SecurePull,SecRemediation,GE}.t.sol`; sequences file. Target-harness files that construct `MockStandardExchange` are **not** gold SUT coverage; decimal clones belong on `ComposedStableCommonDetf_IntegratedDeploy_Test` and ProductLaw, not on those harnesses. **D13:** same D15-2..7 fill-then-clone as §7.1 (include D15-5).

#### 7.4 Mixed buffer multi-vault stable DETF

Test root: `…/mixedBuffer/`. Mixed raw + SE legs. Books: eight `B_*` with pairToken orientation on the documented pair buffer token.

In-scope: `MixedBufferMultiVaultStableDetf_{Deploy,Mint,Burn,Bonding,Claim,Bootstrap,ProductLaw,ProtocolCompound,NaturalExpansion,ThresholdMode,ReserveDonation,Routes,Pricing,PriceShift,RateProviders,NLegs,Liveness,Guards,Nested,NestedPush,Reentrancy,Alignment_*}.t.sol`; `adversarial/Adversarial_MixedBuffer_{A0,P0,TrustFlag}.t.sol`. **D13:** same D15-2..7 fill-then-clone as §7.1 (include D15-5).

- [ ] Single SE DETF clones every listed money-path `test_*` onto all eight two-token combos
- [ ] Multi-vault weighted, composed stable, and mixed buffer DETFs clone listed money-path tests onto all eight `B_*` books
- [ ] D15-2..7 (D15-5 on n-leg) exist and are green at 18-dec on each Balancer DETF family before any `decimals/` clone of those IDs
- [ ] MockStandardExchange harness files are not decimal-cloned

### 8. Balancer V3 SE buffer pools

Test root: `test/foundry/spec/protocols/dexes/balancer/v3/pools/`. Products: const-prod Standard Exchange buffer (Aerodrome + Uni V2 TestBases), multi-pair weighted, mixed-leg weighted, common-buffer multi-vault weighted/stable, mixed-buffer multi-vault stable.

Today DAI/USDC fixtures use Crane `usdc` at **18** decimals. NEED the eight two-token combos on CP buffer; NEED eight `B_*` books on n-leg pools.

In-scope (clone every listed money-path `test_*`). Crane `usdc` is 18. `usdc6Decimals` exists in Crane and is **unused** here.

| Product | Suites | Exact 18-dec tests (NEED eight two-token combos or eight `B_*`) |
|---------|--------|------------------------------------------------------------------|
| CP SE buffer (Aerodrome + Uni V2) | `StandardExchangeBufferPool.spec.t.sol`; UniV2 spec; RateTracking; Target; comparative; `Adversarial_BalancerV3SinglePoolSE.t.sol` | `test_init_virtualTTAMatchesSeed`; `test_init_bptSupplyPositive`; `test_lpAdd_sharesOnly_basic`; `test_lpAdd_unbalanced_*`; `test_lpRemove_basic`; `test_swap_TTAtoShares_basic`; `test_swap_sharesToTTA_basic`; `test_onSwap_*_EXACT_IN_*`; `test_ttaToSharesExactOut_nearMaxOutRatio_succeeds`; `test_initialQuote_isNav`; `test_quoteTracksRate_upAndDown`; `test_adversarial_donationGriefing`; `test_I1_*`; `test_E6_refund_fatMax_*` |
| Weighted common-buffer multi-vault | `CommonBufferMultiVault_RoutingAndWalk.spec.t.sol` | `test_init_virtualBuffer_fromSeed`; `test_lp_proportional_scalesVirtual`; `test_lp_unbalanced_buffer_add_growsVirtual`; `test_swap_buffer_to_share_exactIn`; `test_swap_share_to_buffer_exactIn`; `test_swap_share0_to_share1`; `test_A3_donation_noFreeBpt`. `test_deploy_T8_U5_N2` is **token-count 8**, not 8-dec |
| Weighted mixed-leg | `MixedLegWeightedBufferPool.spec.t.sol`; `MixedLeg_P4_Smoke.spec.t.sol` | `test_lp_addProportional_scalesVirtual`; `test_lp_removeProportional_scalesVirtualDown`; `test_swap_bufferToShares_exactIn`; `test_swap_P4_*`; `test_swap_crossPair_*`; `test_donation_noBptMint_virtualUnchanged`; `test_C1_hostileBuffer_reentrancy_onLiveSwap` |
| Weighted multi-pair | multiPairBuffer spec | `test_init_virtualBuffer_fromBufferSeed`; `test_lp_addProportional_scalesVirtual`; within-pair / cross-pair / share-share / buffer-buffer swaps; donation; `test_C1_hostileBuffer_reentrancy_onLiveSwap` |
| Stable common / mixed buffer | `*WalkAndExhaust.spec.t.sol` | `test_lp_proportional_scalesVirtual`; `test_swap_buffer_to_share_exactIn`; `test_swap_share_to_buffer_exactIn`; `test_formula_onSwap_exactOut_fixedVector`; `test_RP1_unpaired_with_rate`; `test_A3_donation_noFreeBpt`; `test_C1_hostileBuffer_reentrancy_onLiveSwap` |

Coordinator router (`BalancerV3UniswapV4CoordinatorRouter_*.t.sol`) does not scale `decimals()`. Out of this PRD except as a passthrough of raw amounts already covered by the pools it talks to. Same rule: Balancer V3 SE Router (`test/.../balancer/v3/routers/**`) and `WrappedStandardExchangeRateProvider.t.sol` are non-goals (D18). TWAP `test_H19_non18SnapshotNativeAndMissingDecimals` HAVE 6; NEED 9 (§4.3).

- [ ] CP SE buffer clones listed tests onto all eight two-token combos
- [ ] N-leg Balancer pools clone listed tests onto all eight `B_*` books
- [ ] Crane `usdc` 18-dec fixtures are not counted as 6-dec coverage
- [ ] Coordinator router, Balancer V3 SE Router, and wrapped SE rate provider have no `decimals/` suites

### 9. Implementation shape

- New TestBases override **token construction only**. Shared non-SUT stub: `contracts/test/stubs/MintableERC20Decimals.sol` (constructor `name, symbol, decimals_`; mint/approve/transfer/transferFrom; `decimals` immutable `uint8`). `SimpleMintableERC20` becomes a 18-dec wrapper of that stub (`constructor(name, symbol)` calls `MintableERC20Decimals(name, symbol, 18)` and does **not** redeclare `decimals`) so gold Dual still compiles. `SimpleYieldERC4626` asset type is `MintableERC20Decimals` (shares stay 18-dec SimpleMintableERC20). Protocol-issued shares stay 18-dec (D12).
- **Exception:** Aave cross-version loop TestBases keep `ERC20MintBurnOwnableOperableDFPkg` and pass the combo decimals into `deployToken`. Do not replace that package with the stub.
- Do not use 18-only `SimpleMintableERC20` as the **underlying** of a decimal clone.
- New suites live under a `decimals/` folder next to the gold suite, named `<GoldSuite>_<ComboId>.t.sol`. Dual cells use the `D_U*` ID (`UniswapV4DualSEBCPHook_Core_D_U6_U9.t.sol`). They inherit the gold test body or the Stage 11 Open/Policy abstract. Do not parameterize gold TestBases (D7).
- **D13 order:** (1) fill missing 18-dec production-first money paths (`SlipstreamStandardExchange_Routes.t.sol`; Balancer DETF D15-2..7 including D15-5 on n-leg; any Real Stata route missing versus the mock route list), (2) then `decimals/` clones. Do not rewrite `AaveV3StataStandardExchange.t.sol`.
- Do not edit `TestBase_UniswapV4Detf.sol`. Do not `new` DFPkgs. Facets via CREATE3. Vault/DETF DFPkgs via `indexedexManager.deploy*DFPkg`.
- Preview==exec, conservation, and dust asserts use the token’s native decimals. Do not compare a 6-dec transfer to `1 ether`.
- Opening-price WADs stay 18-dec. Pair amounts that seed first bond scale with `pairToken.decimals()`.
- `via_ir` forbidden. Hermetic default `forge test`. Forge patience applies.

- [ ] `forge test --match-path '**/decimals/**'` is the decimal program matcher
- [ ] Gold 18-dec matchers used by unified DETF deprecation stay green
- [ ] Each NEED cell in §3–§8 has at least one passing test function whose name or NatSpec records the combo ID
- [ ] `contracts/test/stubs/MintableERC20Decimals.sol` exists; new decimal TestBases use it for underlyings except Aave loop
- [ ] Gold Dual still compiles after `SimpleMintableERC20` becomes the 18-dec wrapper and `SimpleYieldERC4626` takes `MintableERC20Decimals` as asset

### 10. Roles and naming

Use DETF role names: `rateAsset`, `pairToken`, `standardExchangeVault`, `vaultShare`, `detfToken`, `reservePool` / `reserveHook`, `rebasingClaimToken`. Do not name suites RICH/WETH unless the token is actually WETH (native-wrap tests only).

- [ ] No new suite, TestBase, or NatSpec uses RICH, RICHIR, or WETH unless the token is native WETH
- [ ] Combo IDs in `decimals/` contract names match §1 (`U6`, `P6_R18`, `B_P9_R18`, `D_U6_U18`, …)
- [ ] After PoolKey / token sort, NatSpec still states which **role** is 6 vs 9 vs 18

## Non-goals

- Changing production decimal policy (non-18 is already allowed; this PRD is tests only)
- A `processArgs` decimals allowlist
- FoT or rebasing-underlying support
- 8-dec WBTC books (except existing weighted n4 6/8/18/18 fixture, which stays)
- Cloning EX-J / EX-IFACET / EX-FACTORY / EX-MARKER / EX-FOT-NATS / EX-LST-FIXED / EX-MOCK
- Frontend, tokenlist, or Playwright
- Restoring family Uni V4 DETF diamonds
- Editing `TestBase_UniswapV4Detf.sol`
- Cartesian of every n-leg **token** (more books than the eight `B_*` shapes)
- Dual-with-two-token-SE fixtures or an 8×8 two-token Dual cartesian (Dual stays ERC-4626×ERC-4626 `D_U*` cells)
- Inventing 6-dec or 9-dec pons launch tokens, wstETH, weETH, or rETH
- Changing `vaultShare` / `detfToken` / `rebasingClaimToken` / hook LP decimals (D12)
- DualLiquidity linked cross-version (production tree absent)
- Balancer V3 SE Router (`test/foundry/spec/protocol/dexes/balancer/v3/routers/**`)
- `WrappedStandardExchangeRateProvider.t.sol`
- Rewriting `AaveV3StataStandardExchange.t.sol` (mock hermetic stays; clones come from Real)
- Inventing a Uni V2 adversarial suite under `standard-exchange/adversarial/`
- `via_ir`, package-specific Foundry profiles, SUT mocks

## Constraints

- Production-first: CraneTest → IndexedexTest → protocol TestBase. No mock vaults, DETFs, manager, registry, fee oracle, facets, or DFPkgs
- Token policy LOCKED: FoT forbidden; rebasing underlyings forbidden; non-18 allowed (scale to 18); pause accepted
- Foundry: hermetic default; fork profile `FOUNDRY_PROFILE=fork` only where gold already forks; `via_ir` forbidden
- Unified DETF ABI: sell on Bond NFT; redeem on `IRebasingClaimToken`; no family `buyClaim` / `depositClaim` / `redeemClaim`
- Worktree compile seed and forge patience from root `Claude.md`

## Actors

Omit. Tests and implementor agents only.

## Decisions

| ID | Decision | Status | Rationale |
|----|----------|--------|-----------|
| D1 | Scenario = money-path `test_*` in §2. Declaration/factory/loupe tests are exempt | Decided | Decimals do not change selectors; cloning J/IFacet is theater |
| D2 | Homogeneous `H6` and `H9` are required for two-token SEs, plus mixed 6/18, 9/18, 6/9 with both pair orientations | Decided | Both-legs-6 (USDC/USDT) and both-legs-9 are real books |
| D3 | Pair-token orientation is a distinct combo (`P6_R18` ≠ `P18_R6`, etc.) | Decided | Source request required both “pair is 6” and “pair is 18” for 6/18, and the same for other mixes |
| D4 | LST receipts are EX-LST-FIXED. Morpho/ERC-4626/Aave Stata/Aave loop are in-scope | Decided | Those products take a configurable IERC20; wstETH/weETH/rETH do not |
| D5 | N-leg token **shape** is the eight `B_*` books (not per-leg cartesian). Stage 11 runs **every fixture × every book** for that arity, including ProductLaw, Policy, and firstBond/mint/burn/close | Decided | Owner chose full Stage 11 × book matrix; n-leg consolidation is book shape only |
| D6 | Dual SE buffer is gold ERC-4626×ERC-4626 only. Decimal matrix is the nine `D_U*` cells in §1 (HAVE `D_U18_U18`; NEED the other eight). No two-token Dual fixtures and no 8×8 two-token cartesian in this program | Decided | Review Q5: gold Dual is ERC-4626×ERC-4626; owner chose U-cartesian only |
| D7 | New suites under `decimals/` siblings; new TestBases; do not retarget or parameterize gold 18-dec files; do not edit `TestBase_UniswapV4Detf.sol` | Decided | Owner chose sibling suites |
| D8 | L1 fuzz and L3 invariants run on **every** required combo for that product | Decided | Owner chose fuzz every combo |
| D9 | Pons launch token decimals are N/A; configurable other leg still runs `P18_R6` / `P18_R9` and n-leg `B_P18_R6` / `B_P18_R9` | Decided | Pons factory mints 18 |
| D10 | PRD path `docs/testing/non-18-decimal-token-test-coverage.md` | Decided | File written here |
| D11 | Crane `usdc` 18-dec DAI/USDC fixtures are `H18`, not 6-dec coverage | Decided | Inventory fact |
| D12 | Only configured underlyings change decimals. `vaultShare`, `detfToken`, `rebasingClaimToken`, Bond NFT, and hook LP stay 18 | Decided | Token policy: scale inputs to 18 internally |
| D13 | Fill missing 18-dec production-first money paths first (Slipstream live zap exec in `SlipstreamStandardExchange_Routes.t.sol`; Balancer DETF D15-2..7 including D15-5 on n-leg; any Real Stata route missing versus the mock route list), then decimal-clone | Decided | Owner chose fill-then-clone; Stata 18-dec gold is already Real (D15) |
| D14 | Weighted n=2: eight two-token combos. n=3 and n=4: all eight `B_*` as live join/swap books. n=8 smoke: `B_P6_R18` and `B_P9_R18` only | Decided | Owner chose n=3/4 full, n=8 mixed pair |
| D15 | Stata decimal clones come from `AaveV3StataStandardExchange_Real.t.sol`. `AaveV3StataStandardExchange.t.sol` is EX-MOCK: do not edit, do not clone. U6/U9 deploy Crane Stata with `asset().decimals()` 6 and 9 | Decided | Review Q4: clone from Real only; reconciles D7 and D13 |
| D16 | Dual decimal cells are `D_U6_U6` … `D_U18_U9` as listed in §1. New suites named `<GoldSuite>_<CellId>.t.sol` | Decided | Review Q5; naming so implementors do not invent IDs |
| D17 | Shared underlying stub is `contracts/test/stubs/MintableERC20Decimals.sol`. `SimpleMintableERC20` wraps it at 18-dec. `SimpleYieldERC4626` asset type is `MintableERC20Decimals`. Aave loop keeps `ERC20MintBurnOwnableOperableDFPkg` | Decided | Review Q6 |
| D18 | DualLiquidity linked cross-version, Balancer V3 SE Router, and Wrapped SE rate provider are non-goals | Decided | Review Q7: DualLiquidity tree absent; router and rate provider do not scale decimals() |
| D19 | Aave cross-version loop required combos are the same eight two-token IDs as Uni V2/V3/V4 SE. `pairToken` = `tokenA`. Today tokenA 18 + tokenB 6 is PARTIAL `P18_R6`. No extra single-underlying U6/U9 loop configs | Decided | Review Q8 |

## Execute

Implementation plan: ./non-18-decimal-token-test-coverage.plan.md
Run: /goal docs/testing/non-18-decimal-token-test-coverage.plan.md
