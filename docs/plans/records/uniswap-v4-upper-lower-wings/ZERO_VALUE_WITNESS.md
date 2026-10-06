# Real-pool positive-value invariant counterexample — 2026-10-05

## Result

Target-only initial funding does not by itself imply positive current whole-book liquidation value forever. Both orientations reproduced this using the real Crane Uniswap V4 PoolManager port, fee=3000, spacing=60, hookless PoolKey, starting sqrt price=2^96, a zero local sleeve and no external LP.

| Target | Initial target funding (native units) | Opposing inventory after removal, including fees | Target proceeds |
| --- | ---: | ---: | ---: |
| token0 | 997005 | 18453516213140790637181269 | 0 |
| token1 | 997005 | 18453516209681194614058339 | 0 |

1. Fund the corresponding wing with only target, liquidity=1,000,000 and the production Geometry/Inventory helpers' exact required target input. No target remains local.
2. A separate trader actually swaps across the wing to tick +887221 (upper) or -887221 (lower). All removable principal and earned fees are now opposing inventory. This ordinary hookless swap has no share-burn operation.
3. The portfolio owner actually removes its entire position and settles principal/fees. It receives zero target.
4. It attempts the permitted opposing-to-target swap through the now-empty pool. Both currency deltas are exactly zero; all opposing input remains local. This is a completed market-limited attempt, not an unfinished simulation assigned zero.
5. A positive control adds real external liquidity and trades the price back, then confirms those same retained tokens can produce target proceeds. Recovery depends on market state.

A zero effective sleeve is expressible by the existing oracle: VaultFeeOracleRepo._validateWadPercentage accepts 0, and liquidReservePercentageOfVault returns global zero when instance/type/global settings are zero. The witness does not mock an oracle or impose a new sleeve policy; the oracle configuration is checked separately in the sleeve suite.

## Evidence boundaries

Tests: UniswapV4UpperLowerWingsStandardExchangeVaultRecoveryValue.t.sol, both test_realPool_target*OnlyFundingCanReachZeroRealizableValue cases. Log: owner-rulings-tests.log. Artifact-first command and exit 0: owner-rulings-test-result.json. All 25 tests passed, including these two witness tests; passing confirms the counterexample, not the positive-value invariant.

This is a real protocol/portfolio reference, not a deployed Wings vault or share-issuance test. It refutes the assertion that target-only funding alone enforces positive V; a future vault can prevent the state through an additional invariant. No outstanding shares were minted by this reference harness. The share implication follows only for a design that issues shares for that initial funding and allows this zero-sleeve allocation, since the subsequent market trade does not burn them.

Mandatory next-operation harvest does not supply missing target: caller credit is isolated from the incumbent book, and there is no external liquidity to convert the harvested opposing inventory. Adding caller credit makes post-contribution value positive, but does not define the candidate's zero pre-contribution denominator.

## Narrow resolution needed

To make the requested S>0 => V>0 invariant hold, enforce a strictly positive local target reserve while shares exist, including after reserve-funded costs. The smallest native-unit floor is one target unit. This would override a zero/rounded-zero oracle sleeve target and is therefore an explicit exception to pure percentage-only placement, not silently selected here. It also requires lifecycle/fee/withdrawal proofs; one-unit retention is a proposed invariant mechanism, not a security certification.

Alternatively, allow the demonstrated zero-value state and define its issuance/redemption behavior. The owner has not approved that alternative or recapitalization. No new public money path implements either choice yet.

## Oracle verification completed

The production IndexedEx manager/fee-oracle fixture confirms effective zero and percentage rounding without mocks. Sleeve.test_zeroOraclePercentageHasNoWingsDefault passes with actual oracle zero. Sleeve.test_positivePercentageCanRoundToZero passes at p=0.2e18: target inventory 5 native units yields local sleeve 0; inventory 6 yields 1. All five sleeve tests pass, including actual instance override/clear and full-width/fuzz arithmetic. Combined result: 30/30 tests across six suites, artifact-first exit 0 (`owner-rulings-sleeve-tests.log`).
