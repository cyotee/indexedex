# Remaining non-residual-classified failures

Source: `25-restored-hooks-and-detf.log`, complete failure footer.
This is a triage filter, not a root-cause verdict.


## Encountered 1 failing test in test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Buffers_Detf.t.sol:RebasingAwareERC4626_Buffers_Detf

- [FAIL: TokenNotInVaultTokens()] test_F16_cpDetfMintRedeemWrapperShareReserve() (gas: 19425376)

## Encountered 1 failing test in test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Buffers_Detf.t.sol:RebasingAwareERC4626_Buffers_Detf_Weighted

- [FAIL: InvalidDecimals()] test_F16_weightedDetfMintRedeemWrapperShareLeg() (gas: 21592005)

## Encountered 1 failing test in test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_DetfInvariant.t.sol:RebasingAwareERC4626_DetfInvariant

- [FAIL: TokenNotInVaultTokens()] setUp() (gas: 0)

## Encountered 1 failing test in test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol:CpPublicReserveLiquidityTest

- [FAIL: each non-DETF leg receives duration bonus once: 70141130683 != 70140564004] test_lpBondValuesDistinctNonDetfLegsAndRetainsWholeInventory() (gas: 5382211)

## Encountered 1 failing test in test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol:CpReserveLiquidityTest

- [FAIL: each non-DETF leg receives duration bonus once: 70141130683 != 70140564004] test_lpBondValuesDistinctNonDetfLegsAndRetainsWholeInventory() (gas: 5386717)

## Encountered 2 failing tests in test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol:OrbitalPublicReserveLiquidityTest

- [FAIL: custom bond preview includes prior SE wrapping: 9010614067 != 9016484371] test_customBondQuoteIncludesWrappingBeforeIssuance() (gas: 74275279)
- [FAIL: Error != expected error: MinAmountNotMet(9203800805480119728 [9.203e18], 9199914671212067327 [9.199e18]) != MinAmountNotMet(9203800805480119728 [9.203e18], 9203800805480119727 [9.203e18])] test_customDonationQuoteIncludesWrappingBeforeReserveJoin() (gas: 73551503)

## Encountered 2 failing tests in test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol:OrbitalReserveLiquidityTest

- [FAIL: custom bond preview includes prior SE wrapping: 9010614067 != 9016484371] test_customBondQuoteIncludesWrappingBeforeIssuance() (gas: 71554756)
- [FAIL: Error != expected error: MinAmountNotMet(9203800805480119728 [9.203e18], 9199914671212067327 [9.199e18]) != MinAmountNotMet(9203800805480119728 [9.203e18], 9203800805480119727 [9.203e18])] test_customDonationQuoteIncludesWrappingBeforeReserveJoin() (gas: 70831242)

## Encountered 2 failing tests in test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol:WeightedPublicReserveLiquidityTest

- [FAIL: assertion failed: 2073049799406 != 2073049799407] test_customBondQuoteIncludesWrappingBeforeIssuance() (gas: 112473575)
- [FAIL: configured donation remains quotable: 0 <= 0] test_customDonationQuoteIncludesWrappingBeforeReserveJoin() (gas: 60817609)

## Encountered 2 failing tests in test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol:WeightedReserveLiquidityTest

- [FAIL: assertion failed: 2073049799406 != 2073049799407] test_customBondQuoteIncludesWrappingBeforeIssuance() (gas: 107164016)
- [FAIL: configured donation remains quotable: 0 <= 0] test_customDonationQuoteIncludesWrappingBeforeReserveJoin() (gas: 55513083)

## Encountered 1 failing test in test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/UniswapV4DetfLeftoverPreview.t.sol:UniswapV4DetfLeftoverPreview_Test

- [FAIL: this CP fixture requires both unbalanced-join legs: 1609039336514292252 != 0] test_RC06_nonzeroPreview_usesSingleAssetFallback() (gas: 501677)

## Encountered 2 failing tests in test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Burn_H6.t.sol:UniswapV4Detf_Burn_H6

- [FAIL: Error != expected error: InsufficientTokenOut() != ZeroAmount()] test_smallPrimaryBurn_firstPayableBoundary() (gas: 10265359)

## Encountered 3 failing tests in test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons/UniswapV4Detf_PonsV2Se_ProductLaw.t.sol:UniswapV4Detf_PonsV2Se_ProductLaw

- [FAIL: no launch on diamond: 79047316 > 10] test_DN11_ownerOnlyLiquidity_donateStillWorks() (gas: 6365259)
- [FAIL: no launch on diamond: 14223335 > 10] test_DN1_donate_pair_Ogt0_unassignedLp() (gas: 6480298)
- [FAIL: no launch on diamond: 25242110 > 10] test_DN2_donate_vaultShare() (gas: 7571116)

## Encountered 3 failing tests in test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons/decimals/UniswapV4Detf_PonsV2Se_ProductLaw_P18_R6.t.sol:UniswapV4Detf_PonsV2Se_ProductLaw_P18_R6

- [FAIL: no launch on diamond: 79047316 > 10] test_DN11_ownerOnlyLiquidity_donateStillWorks() (gas: 6365259)
- [FAIL: no launch on diamond: 14223335 > 10] test_DN1_donate_pair_Ogt0_unassignedLp() (gas: 6480298)
- [FAIL: no launch on diamond: 25242110 > 10] test_DN2_donate_vaultShare() (gas: 7571116)

## Encountered 3 failing tests in test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons/decimals/UniswapV4Detf_PonsV2Se_ProductLaw_P18_R9.t.sol:UniswapV4Detf_PonsV2Se_ProductLaw_P18_R9

- [FAIL: no launch on diamond: 79047316 > 10] test_DN11_ownerOnlyLiquidity_donateStillWorks() (gas: 6365259)
- [FAIL: no launch on diamond: 14223335 > 10] test_DN1_donate_pair_Ogt0_unassignedLp() (gas: 6480298)
- [FAIL: no launch on diamond: 25242110 > 10] test_DN2_donate_vaultShare() (gas: 7571116)

## Encountered 4 failing tests in test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw.t.sol:UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw

- [FAIL: above-dust retention requires a successful Standard Exchange preview of zero: 138859345 != 0] test_DN11_ownerOnlyLiquidity_donateStillWorks() (gas: 26417409)
- [FAIL: above-dust retention requires a successful Standard Exchange preview of zero: 405080104 != 0] test_DN1_donate_pair_Ogt0_unassignedLp() (gas: 32320331)
- [FAIL: above-dust retention requires a successful Standard Exchange preview of zero: 759333587 != 0] test_DN2_donate_vaultShare() (gas: 36760683)
- [FAIL: above-dust retention requires a successful Standard Exchange preview of zero: 1593472687 != 0] test_T7_10_laterBond_joinUnbalanced_unboostedG() (gas: 25859830)

## Encountered 2 failing tests in test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Orbital_PonsV1Se.t.sol:UniswapV4Detf_Orbital_PonsV1Se

- [FAIL: above-dust retention requires a successful Standard Exchange preview of zero: 341080 != 0] test_H_OR_P1_burn() (gas: 59359060)

## Encountered 6 failing tests in test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Orbital_PonsV1Se_ProductLaw.t.sol:UniswapV4Detf_Orbital_PonsV1Se_ProductLaw

- [FAIL: above-dust retention requires a successful Standard Exchange preview of zero: 60464 != 0] test_DN11_ownerOnlyLiquidity_donateStillWorks() (gas: 55933142)
- [FAIL: above-dust retention requires a successful Standard Exchange preview of zero: 173413 != 0] test_DN1_donate_pair_Ogt0_unassignedLp() (gas: 57695051)
- [FAIL: entire residual independently previews zero shares: 173413 != 0] test_DN22_legacyV3Residual_booked_repeatSweep_noFreePretransfer() (gas: 58300849)
- [FAIL: entire residual independently previews zero shares: 173413 != 0] test_DN22_legacyV3Residual_laterFundedRetry() (gas: 58299925)
- [FAIL: above-dust retention requires a successful Standard Exchange preview of zero: 99271 != 0] test_DN2_donate_vaultShare() (gas: 60983195)
- [FAIL: above-dust retention requires a successful Standard Exchange preview of zero: 62620 != 0] test_T7_10_laterBond_joinUnbalanced_unboostedG() (gas: 67449919)

## Encountered 2 failing tests in test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Orbital_Univ3Se.t.sol:UniswapV4Detf_Orbital_Univ3Se

- [FAIL: RateProviderFailed()] test_H_OR_GV3_burn() (gas: 34590962)

## Encountered 4 failing tests in test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Orbital_Univ3Se_ProductLaw.t.sol:UniswapV4Detf_Orbital_Univ3Se_ProductLaw

- [FAIL: above-dust retention requires a successful Standard Exchange preview of zero: 114996855 != 0] test_DN11_ownerOnlyLiquidity_donateStillWorks() (gas: 54936559)
- [FAIL: above-dust retention requires a successful Standard Exchange preview of zero: 346004433 != 0] test_DN1_donate_pair_Ogt0_unassignedLp() (gas: 56747513)
- [FAIL: above-dust retention requires a successful Standard Exchange preview of zero: 178731224 != 0] test_DN2_donate_vaultShare() (gas: 59594604)
- [FAIL: above-dust retention requires a successful Standard Exchange preview of zero: 97899375 != 0] test_T7_10_laterBond_joinUnbalanced_unboostedG() (gas: 62564686)

## Encountered 3 failing tests in test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Quad_MorphoBlueSe.t.sol:UniswapV4Detf_Quad_MorphoBlueSe

- [FAIL: EvmError: Revert] test_H_QD_MB_burn() (gas: 33572084)
- [FAIL: EvmError: Revert] test_claimAfterMatureClose_matchesProjection() (gas: 32772366)

## Encountered 3 failing tests in test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Quad_Univ3Se.t.sol:UniswapV4Detf_Quad_Univ3Se

- [FAIL: EvmError: Revert] test_H_QD_GV3_burn() (gas: 34993933)
- [FAIL: EvmError: Revert] test_claimAfterMatureClose_matchesProjection() (gas: 33939287)

## Encountered 2 failing tests in test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Weighted_Univ3Se.t.sol:UniswapV4Detf_Weighted_Univ3Se

- [FAIL: RateProviderFailed()] test_H_WE_GV3_burn() (gas: 34179606)
