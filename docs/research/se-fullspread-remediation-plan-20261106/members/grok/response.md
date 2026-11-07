# Response

## Identity

- Member: grok
- Phase: initial independent response
- Role: council-member
- Requested model: xai/grok-4.7:xhigh
- Actual model: not exposed
- Task ID: not exposed
- Fresh or continued: not exposed
- Runtime reasoning: not exposed

## Question and targets

Question: write one remediation implementation and test plan from the current `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`. The plan must be specific enough that an implementer can close the adopted gaps without making a product decision.

Targets:

- Required source: `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`, including the 2026-11-06 owner lock and the boundary dust sentence.
- Specification fingerprint, coordinator-supplied, not recomputed: `4f1f3204088b39e038a17154d79594be262921a231c6a01eeb33a7ee0373e8f3`
- Family PRD, read only where a remediation sentence depends on it: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`
- Family plan, read only where a remediation sentence depends on it: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md`
- Owned response: `docs/research/se-fullspread-remediation-plan-20261106/members/grok/response.md`

This plan does not authorize implementation. It does not replace the family plan. It does not replace the remediation PRD.

## Evidence

The remediation PRD was read in full. The 2026-11-06 owner lock in that file is the requirement law for the gaps it names. Adopted findings are F1 through F11. The unresolved list is not adopted.

Family-plan sections read because a remediation sentence depends on them: section 2 (49% sizing and gas ceilings), section 4 (six infrastructure components), section 9 (one-token exit and maintenance remainder), section 12 (fixture, weighted `setUp`, the nine row files, and the migration this pass does not close), section 13 (test-file assignment and the named gas routes), and section 16 (the shorter 2026-11-05 answers the later lock replaces where they differ).

Family-PRD passages read because a remediation sentence depends on them: the precedence paragraph, FS-FACET-01, FS-PKG-02, FS-MONEY-01, FS-OWN-30, FS-OWN-33, FS-A01 through FS-A04, FS-A08, and FS-A16.

Code reads below are context. They name the current function a plan sentence points at. They are not a conformance review, and they are not a test run.

- `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol`: `planMaintenance`, `_mintOne`, `_exit`, `_size`, `_shares`.
- `UniswapV4FullSpreadStandardExchangeVaultMath.sol`: `sizeOneSided`, `singleTokenAdd`, `quadraticInput`.
- `UniswapV4FullSpreadStandardExchangeVaultExecution.sol`: `exchangeIn`, `maintain`.
- `UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol`: `constructor`.
- `SeMatrix_FullSpreadV4Fixture.sol`: `limitCapacity`, `openCapacity`, `seBooked`.
- `SeMatrixFixture.sol`: those three functions are declared with no body, so a concrete fixture must override them.
- `UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`: `setUp`, `test_composedRouteGasFitsCeiling`.
- `TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol`: `_swapExactIn` calls `swapRouter.swapExactIn` on the hook PoolKey.
- `Package.t.sol`, `Money.t.sol`, and `QuotesAndRate.t.sol`: the test functions named in section 10.

No peer response was read. No test, Git command, or install was run. This response does not say that any named test passes.

## Assumptions

None. The parent-fixture fact is an observation: `SeMatrixFixture.limitCapacity`, `openCapacity`, and `seBooked` have no body. The empty capacity overrides stay. `seBooked` stays as an override and must not report a balance.

Processed input is the amount the current function already passes to `_size`. For a one-sided share mint, that is the funded declared amount in `_mintOne`. For a one-token `donate` or `compound`, that is the combined booked, collected-fee, and donation balance of that one token in `planMaintenance`. It is not a second 49% of an already reduced amount.

## Coverage

| Source | Status | Reason |
| --- | --- | --- |
| Remediation PRD, current file | read in full | Required source |
| Fingerprint `4f1f3204088b39e038a17154d79594be262921a231c6a01eeb33a7ee0373e8f3` | recorded | Coordinator-supplied. Not recomputed |
| Family plan sections 2, 4, 9, 12, 13, 16 | read | A remediation sentence depends on each |
| Family PRD passages named in Evidence | read | A remediation sentence depends on each |
| Named production and test functions | context | Used only to name the current function |
| Preview-consumer index | not walked | This pass does not close that migration |
| Unresolved list | not implemented | Not a requirements source |
| Peer responses | not read | Forbidden on this pass |

## Conclusions

### 1. Authority

This plan amends the family plan for the adopted gaps in the current remediation PRD. It does not replace the family plan. It does not replace the family PRD. It does not authorize implementation, tests, installs, deployment, or Git.

Do not start the edits this plan describes until a later owner instruction authorizes implementation.

### 2. Sources and precedence

Use this order. A later row wins only for the gap it names. It does not reopen a sentence a later lock left in place.

1. The 2026-11-06 owner lock in `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md` wins for the gaps it names. Fingerprint `4f1f3204088b39e038a17154d79594be262921a231c6a01eeb33a7ee0373e8f3` is coordinator-supplied. Do not recompute it.
2. Family PRD FS-OWN-33, locked 2026-11-06, is the same sizing law. Family PRD FS-OWN-30 is the same one-token receipt law. FS-A16 is withdrawn. Do not add that test.
3. Family plan sections 2, 4, 9, 12, and 13 remain the base this plan amends. Where section 9 still says the receipt is "the swap proceeds plus the withdrawn amount sent to the recipient," the four-term receipt in section 6 replaces that sentence for the one-token exit. Where section 16 item 1 says revert `InvalidComponent` "if none is present," section 7 replaces it: each missing or code-empty address reverts. Where section 16 item 4 omits the boundary, the collapsed candidate, or the tick-walk prohibition, section 5 is the complete rule.
4. Adopted findings F1 through F11 name the code the lock changes. They do not add a second product rule.
5. The unresolved list is not a source. Do not implement it.

A removed sizing method is not a requirement. Do not restore an iterative search, an exact-output size, a closed-form root, or a tick walk.

### 3. Already closed product choices

Copy of the requirement law. These are closed. Do not reopen them. Do not offer a menu. Do not restore a removed method.

- Inside the position, a one-sided share mint and a one-token `donate` or `compound` swap 49% of the processed input, then deposit. Do not iterate. Do not size an exact output. Do not solve a closed-form root. Do not walk ticks to find a better split.
- If the price is not strictly inside the position, including exactly at either boundary, do not swap. A share mint refunds what the add does not take. A `donate` or `compound` books that dust and does not refund it. The other token is not swapped. A share mint refunds it. A `donate` or `compound` books it.
- A collapsed candidate returns the input and keeps no swap. A share mint refunds that input and mints nothing. A `donate` or `compound` books that input and does not refund it. A first deposit that does not add more than 1,000 liquidity still reverts `MinLiquidityNotMet`. That is not a refund.
- The one-token exit receipt is the swap proceeds, the withdrawn requested-token principal, the requested-token fee portion, and the requested booked claim. An incomplete exit raises `AmountOutNotMet` and does not burn.
- A missing or code-empty infrastructure address reverts `InvalidComponent` before it is stored. The six addresses are `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, and `universalRouter`.
- The weighted two-leg row keeps its `setUp` override. Do not delete it.
- Do not add an `exchangeRate` test. `getRate` stays uninstalled.
- Gas ceilings stay 11,900,000 cold standalone, 12,000,000 composed, and 5,000,000 preview. Measure every named standalone route and every section 12 row. Do not warm a measurement with a preview.
- This pass does not walk or certify the preview-consumer index. The family plan still requires that migration. This plan does not close it.
- `seBooked()` must not report a balance. Empty capacity overrides stay unless the parent does not require them. Do not add a capacity gate.
- The unresolved list is not a set of new requirements. Do not implement those items in this plan.

The parent does require the overrides. `SeMatrixFixture` declares `limitCapacity`, `openCapacity`, and `seBooked` with no body. The empty capacity overrides stay. `seBooked` stays and returns 0.

The 49% sentence is the inside-position swap. It is not a bundle deposit and not a one-token exit. The boundary sentence is the no-swap path. The collapsed-candidate sentence is the path that keeps no swap. The first-deposit sentence is not waived by either path: if the add is not greater than 1,000, `exchangeIn` reverts `MinLiquidityNotMet` and does not refund.

### 4. Production changes, naming the current function each change touches

Context only. Each row is the required end state of the named function. Do not add a new error. Do not add a new public selector.

| Current function | File | Required end state |
| --- | --- | --- |
| `_size` | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol` | Selects the section 5 candidate. Does not iterate, size an exact output, solve a root, or walk ticks. Does not call `Math.quadraticInput`, `Math.boundaryInput`, `Math.grossFromNet`, or `Math._positiveRoot`. The comment that calls 49% a fraction under test, or that cites 48% as an alternative, is removed. 49% is the lock. |
| `_mintOne` | same Planner file | Calls `_size` for a one-sided share mint. Pushes a swap only when `sized.swapIn != 0`. Sets `amountRefunded` to the input-token remainder. Does not push a swap on a collapsed or other-token boundary candidate. |
| `planMaintenance` | same Planner file | One-token `donate` or `compound` calls `_size` with the combined booked, collected-fee, and donation balance of that token. Pushes a swap only when `sized.swapIn != 0`. Does not set `plan.failed` on a collapsed candidate. Does not refund. Both-token maintenance still uses `Math.proportional` and does not take the 49% path. |
| `_shares` | same Planner file | On a first deposit (`totalSupply` is zero), added liquidity that is not greater than `Types.MIN_SHARES` (1,000), including zero, sets `plan.failed`. Do not return before that check when supply is zero. When supply is nonzero and added liquidity is zero, do not set `plan.failed`. |
| `_exit` | same Planner file | Swaps the whole unwanted claim, not 49%. If the quote does not spend that whole unwanted amount, sets `plan.failed` and returns without pushing the swap. |
| `sizeOneSided` | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMath.sol` | Consumes the quoted swap output in the following add, or returns the full input as remainder with `swapIn` zero and liquidity zero. Does not keep a selected swap whose output the add does not consume. |
| `singleTokenAdd` | same Math file | Boundary no-swap add of the wanted token. Must not swap and must not walk ticks. Unused input is remainder. If it can add no liquidity, remainder is the full input. |
| `exchangeIn` | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultExecution.sol` | Maps `OneTokenExit` with `plan.failed` to `AmountOutNotMet` before `_run` and before burn. Maps every other `plan.failed` to `MinLiquidityNotMet` before `_run` and before the refund pay. The one-token else branch pays and returns the section 6 receipt, then burns only after that receipt meets `minAmountOut`. |
| `maintain` | same Execution file | Does not pay a donation or compound remainder back to the caller. After settlement, books the held face balances when a donation amount was taken or an action ran, including a collapsed one-token candidate. |
| `constructor` | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol` | Before any of the six addresses is stored, and before a facet is appended, rejects a missing or code-empty `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, or `universalRouter` with `InvalidComponent`. One empty address is enough. Do not store the other five and continue. |

`planBundleIn` does not call `_size`. Do not add a 49% swap to a bundle deposit. `_exit` does not call `_size`. Do not apply 49% to a one-token exit.

### 5. One-sided size, including the boundary and the collapsed candidate

Scope: a one-sided share mint, and a one-token `donate` or `compound`. Not a bundle deposit. Not a one-token exit.

Processed input:

- Share mint: the funded declared amount `_mintOne` passes to `_size`.
- One-token `donate` or `compound`: `have0_` or `have1_` in `planMaintenance` after the unpaid fee, if any, is included in that local sum. That sum is booked balance plus collected fee plus donation of that one token.

Inside the position means `sqrtPriceX96 > sqrtA` and `sqrtPriceX96 < sqrtB` for this vault's stored position bounds. Equality with either bound is not inside.

Inside path. One exact-input swap, then the add.

- `swapIn = FullMath.mulDiv(processed, 49, 100)`.
- If `swapIn` is zero, or `swapIn` is greater than `uint256(type(int256).max)`, the candidate is collapsed.
- Otherwise quote `SwapProjection.exactInput` for that `swapIn` at the existing unbounded limit. Do not add a tighter cap. Do not request an exact output.
- If `quote.spent` is not equal to `swapIn`, or `quote.received` is zero, the candidate is collapsed. Do not keep the smaller spent amount. Do not retry.
- Otherwise call `Math.sizeOneSided` with that spent amount and received amount. The add must consume the swap output. Rounding leaves any remainder in the input token. The swap input is not the amount the add itself consumes.
- If `sizeOneSided` returns liquidity zero, or does not consume the swap output, the candidate is collapsed. Clear `swapIn`, `swapOut`, and liquidity. Remainder is the full processed input.
- A selected plan pushes one swap of `swapIn` and one add of the fitted liquidity. It does not push a second swap.

Boundary path. Price not strictly inside, including exactly `sqrtA` or exactly `sqrtB`. Do not swap. Do not quote a swap.

- If the caller provided the token the position wants, call `Math.singleTokenAdd`. Push no swap. A share mint refunds what the add does not take. A `donate` or `compound` books that dust and does not refund it.
- If the caller provided the other token, push no swap and add no liquidity. Remainder is the full processed input. A share mint refunds it. A `donate` or `compound` books it. No new error.

Collapsed candidate. This is not the boundary. Zero active liquidity is this case, not the boundary case. The 49% swap cannot be formed, or the following add cannot consume its output.

- Return the full processed input. Keep no swap. Push no swap.
- A share mint with existing supply refunds that input and mints nothing.
- A `donate` or `compound` books that input and does not refund it. `planMaintenance` must not set `plan.failed` for this candidate.
- A first deposit whose added liquidity is not greater than 1,000, including a collapsed candidate that adds zero, sets `plan.failed` in `_shares`. `exchangeIn` reverts `MinLiquidityNotMet` before `_run` and before the refund pay. That revert is not a refund. Do not return a successful refund on that path.

Refund and booking. A share-mint refund is `Execution.exchangeIn` paying `plan.amountRefunded` to `msg.sender` in the input token only. It is not a payment of the other token. A `donate` or `compound` remainder is not paid back. `maintain` books the held face balance after settlement. Do not add a refund transfer to `maintain`.

Do not call `quadraticInput`, `boundaryInput`, `grossFromNet`, or `_positiveRoot` from `_size`, `_mintOne`, `planMaintenance`, or `planIn`. Do not restore a candidate loop.

### 6. One-token exit receipt and the incomplete-exit error

This is FS-OWN-30. It is not the 49% rule. The functions are `Planner._exit` and `Execution.exchangeIn`.

The one-token exit minimum, and the returned `amountOut`, are the recipient receipt. That receipt is all four of these amounts, added once:

1. Swap proceeds: the requested token the executed swap in this call delivered to this vault. Not a `previewExchangeIn` result from before this call. Not the swap proceeds alone.
2. Withdrawn requested-token principal: the requested-token amount from removing `liquidity * sharesBurned / supplyBeforeBurn`.
3. Requested-token fee portion: `floor(feesOwed * sharesBurned / supplyBeforeBurn)` for the requested token. Do not also count that fee as an already booked balance.
4. Requested booked claim: `floor(booked[i] * sharesBurned / supplyBeforeBurn)` for the requested token.

`minAmountOut` binds that sum. `exchangeIn` pays that sum to `recipient` and returns it as `amountOut`. It does not pay the opposing token to `recipient`. It does not pay, book, or keep the opposing residual. The other holders' fee remainder and booked remainder stay booked. They are not part of the receipt.

`Planner._exit` still measures the claims before the burn and still swaps all unwanted withdrawn principal plus the opposing fee and the opposing booked claim. If `quote.spent` is not that whole unwanted amount, set `plan.failed` and return without pushing the swap.

`Execution.exchangeIn` then does only this:

- If `plan.kind` is `OneTokenExit` and `plan.failed`, revert `IStandardExchangeErrors.AmountOutNotMet` before `_run`. Do not burn.
- Do not map that exit shortfall to `MinLiquidityNotMet`.
- After `_run`, the paid and returned amount is the four-term sum, using the swap proceeds the executed swap delivered. A balance-growth figure is acceptable only when it equals that sum and does not include another holder's fee remainder or an unbooked balance. If the current else-branch figure is not that sum, change that else branch until it is.
- If that sum is below `minAmountOut`, revert `AmountOutNotMet` before `ERC20Repo._burn`. Do not burn.
- Burn only after the receipt meets the minimum. Then pay the receipt and book the other holders' remainder through the existing `_bookExit`.

Do not add a new error for a quote-versus-pool difference. Do not describe a quote-versus-pool shortfall as an observed defect. The incomplete-exit error is the existing `AmountOutNotMet`. On a projected shortfall that does not execute, the actual amount passed to that error is 0. On an executed receipt below the minimum, the actual amount is the four-term receipt.

### 7. Package and fixture assertions

`constructor` of `UniswapV4FullSpreadStandardExchangeVaultDFPkg` is the check. For each of `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, and `universalRouter`, a missing address or a code-empty address reverts `InvalidComponent` before that address is stored and before a facet is appended. The package construction reverts. No diamond is deployed from that attempt.

`Package.t.sol` holds the package assertions. Do not add an `exchangeRate` test. Do not add a test whose only point is that issuance does not read `exchangeRate`. `getRate` stays uninstalled. `test_getRateAndAssetAreAbsent` remains the absence check. It is not an `exchangeRate` test. `test_permitDomainUsesPackageName` stays. This plan does not delete it.

`test_selectorCutAndCraneGetters` must assert FS-A01: package inputs follow FS-FACET-01; ERC-165, ERC-8109, loupe, and `PostDeployAccountHookFacet` are absent from cuts and still callable on the factory-built proxy where the factory installs them; the reviewed selector manifest succeeds through the proxy; family `poolManager()`, family-only `poolKey()`, `rateAsset()`, `getRate()`, `basket()`, `wrappedNative()`, `localReserves()`, and every Standardized Yield selector are absent; the Crane Protocol Aware getters and `UniswapV4SinglePositionAware` getters are callable; factory selectors stay disjoint. Add any missing conjunct to that function. Do not invent a new selector hex.

`test_bindingHashChangesWithAnyBinding` must assert FS-A02: `bindingHash` changes if any facet, library, or infrastructure binding changes, including each of the six infrastructure addresses.

`test_invalidComponentRevertsBeforeDiamond` must assert the six infrastructure rejects. For each address, one case is `address(0)` and one case is a code-empty address. Expect `InvalidComponent` from the package constructor. Do not require a deployed diamond.

`test_badPoolWrongCallerAndSecondInitRevert` must assert the rest of FS-A03: an uninitialized pool key reverts `InvalidPoolKey`; a hooked pool key reverts `InvalidPoolKey`; a second initialization reverts `AlreadyInitialized` and does not produce a second vault; `processArgs` from a caller that is not the bound registry reverts `NotCalledByRegistry`; `processArgs` from the bound registry when `address(this)` is not the bound `diamondFactory` reverts `NotCalledByRegistry`. There is no rate-asset argument, no wrapped-native argument, and no zap-limit argument to reject. There is no inherited-domain reject. A rejected attempt leaves no usable vault from that attempt. The first successful vault is not destroyed to satisfy that sentence.

`test_storageSlotIsNotPairTokenOrWings` must assert FS-A04: the family slot is not the PairToken slot and not the Wings slot. Do not change the slot formula.

Fixture file: `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol`.

- `limitCapacity` stays an empty override. Do not add a body that limits capacity.
- `openCapacity` stays an empty override. Do not add a body that opens a sleeve.
- Do not add a sleeve capacity gate.
- `seBooked` stays, because the parent declares it with no body. It returns 0. It must not call `balanceOf` and must not report a booked balance. Do not add a production booked view to satisfy the parent.

Weighted two-leg file: `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.

- `setUp` stays. It calls `TestBase_UniswapV4StandardExchangeWeightedBufferHook.setUp()`, then `_initializeWeighted(2)`. Do not delete that override.
- The three-leg file remains the `n == 3` override. Do not move the two-leg `setUp` into it. Do not delete the three-leg `setUp`.

### 8. Gas measurements, naming each route and file

Ceilings, copied from the closed law:

- Cold standalone body: 11,900,000.
- Composed transaction, including hook work: 12,000,000.
- Preview: 5,000,000.

Fixture setup stays outside the measured body. The snapshot is `gasleft` immediately before the named call and `gasleft` immediately after it. Do not call `previewExchangeIn`, `previewExchangeBundleInForSingleOut`, `previewExchangeBundleOut`, or `previewExchangeOut` before that snapshot. Do not run the same route once to warm it and then measure the second call. An oversized route is unresolved, not passed. Do not raise a ceiling. Do not mark that row passed.

`setOperator` and `setOperatorFor` are not in this set. Do not add gas tests for them.

Standalone routes. File: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Money.t.sol`. Ceiling 11,900,000. The measured call is the external route, not a preview.

| Route | Contract | Function |
| --- | --- | --- |
| `exchangeIn` one-sided share mint | `UniswapV4FullSpreadStandardExchangeVault_Money_Test` | `test_gasOneSidedMintFitsCeiling` |
| `exchangeIn` one-token exit | same | `test_gasOneTokenExitFitsCeiling` |
| `exchangeIn` pass-through | same | `test_gasPassThroughFitsCeiling` |
| `exchangeBundleInForSingleOut` | same | `test_gasBundleInFitsCeiling` |
| `exchangeBundleOut` | same | `test_gasBundleOutFitsCeiling` |
| `donate` | same | `test_gasDonateFitsCeiling` |
| `compound` | `UniswapV4FullSpreadStandardExchangeVault_MoneyCompoundGas_Test` | `test_gasCompoundFitsCeiling` |

Composed routes. One measurement in each section 12 row file. Function name: `test_composedRouteGasFitsCeiling`. Ceiling 12,000,000. The measured call is that row's exact-input hook swap through the test router, on the hook PoolKey, for 1 ether of the face. It is not a direct vault `exchangeIn`. It is not an exact-output swap. Seed and other setup stay outside the snapshot. `BufferHookIntegration.t.sol`'s `test_composedRouteGasFitsCeiling` is not one of these nine and does not cover them. Do not delete it. Do not count it as a section 12 row.

| Row | File | Measured call |
| --- | --- | --- |
| Single | `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | Exact-input face to share, 1 ether, through the hook router |
| Constant-product single | `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | Exact-input face to raw, 1 ether, through the hook router |
| Dual | `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | Exact-input that mints this vault's shares on the primary hook pool, face spent, 1 ether. If the PairToken identity record is rejected, this measurement is not passed. Record the consumer, selector, arguments, and revert under FS-HOOK-04. Do not substitute another route. Do not add `asset()`. |
| Orbital | `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | Exact-input face to raw on `poolKey02`, the direction that mints this vault's shares, 1 ether |
| Weighted 2-leg | `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | Existing `test_composedRouteGasFitsCeiling`: `_seedWeighted` outside the snapshot, then `_swapExactIn(face, other, 1 ether)`. That helper calls `swapRouter.swapExactIn` on the hook PoolKey. Keep that call. |
| Weighted 3-leg | `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol` | Exact-input face to raw, 1 ether, through the hook router |
| Curve quad | `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | Exact-input face to `raw0`, 1 ether, through the hook router |
| Balancer 2-leg | `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | Exact-input face to raw, 1 ether, through the hook router |
| Balancer 5-leg | `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5.t.sol` | Exact-input face to the first raw token in the ascending sorted record, 1 ether, through the hook router |

Preview ceiling stays 5,000,000 in `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/QuotesAndRate.t.sol`: `test_previewExchangeInGasFitsCeiling`, `test_previewExchangeBundleInGasFitsCeiling`, `test_previewExchangeBundleOutGasFitsCeiling`, and `test_previewExchangeOutGasFitsCeiling`. This plan does not add a preview consumer. Those four calls are not a warm-up for a standalone or composed measurement.

### 9. Out of scope

Preview-consumer index. Do not walk `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md`. Do not certify that migration. The family plan still requires it. This plan does not close it. Do not treat the two named re-read sites, or the index line anchors, as a completed walk.

Unresolved list. Do not implement these. Naming them is the exclusion, not a work item.

- The exit projection does not fully remove the position from the projected pool state.
- The untraced report that zero added liquidity bypasses the first-deposit floor. The adopted floor sentence in section 5 is the lock. It is not this unresolved item, and it does not adopt the rest of that report.
- Section 12 identity-bind tests that pass after a recorded rejection, and the single-row partial-consumption assertions.
- The classification concern that a recorded rejection or an unverified address-side case may be marked as a compatible passing row.
- The other unre-read test-body findings not already covered by F9, F10, or F11.
- Share-burn allowance. Do not change `Execution._requireShares`.
- Native credit receipt. Do not change `unlockCallback` or the diamond `receive` path.
- Repo-wide migration of one-word preview readers.
- Regeneration of the preview-consumer index.

Do not restore `quadraticInput` as the sizing method. Removing the QuotesAndRate assertions in section 10 is in scope because those assertions would keep the removed method. Deleting the unused Math root helpers is not a requirement of this plan. No production function named in section 4 may call them.

### 10. Tests

Name the assertion and the file. This response does not claim that any of these tests passes. An implementer adds a missing assertion to the named function. An implementer does not add a second test for the same row.

File: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Money.t.sol`, contract `UniswapV4FullSpreadStandardExchangeVault_OneSidedAndExit_Test`, unless a row below names another contract.

| Assertion | Function |
| --- | --- |
| Inside the position, a successful one-sided mint's Swap input equals `FullMath.mulDiv(amountIn, 49, 100)`. The refund is input token only. The other token is not refunded and is not left unbooked. No second swap. | `test_spotOneSidedMintRefundsOnlyInputToken` and `_assertSuccessfulMint` |
| The same 49% Swap input on a one-token `donate`. Processed input is booked plus collected fee plus donation of that token. The caller is not refunded. Input-token dust stays in the vault. The other token is not booked as residue. | `test_oneTokenDonateSwapsAndBooksInputRemainder` and `_assertOneTokenDonate` |
| A one-token `compound` does not refund the caller. | `test_oneTokenCompoundDoesNotRefund` |
| At `sqrtPrice` equal to the lower bound, equal to the upper bound, and strictly outside either bound: no Swap. The wanted token is added and the share mint refunds only what the add does not take. The other token is not swapped; the share mint refunds the entire input and mints nothing; the `donate` of that other token does not refund and books it. | `test_outsidePositionAddsWantedToken` and `_assertOutside`. Extend that test so the price is set to each bound, not only past the range. |
| Collapsed candidate, supply already nonzero, price strictly inside: full input refunded, nothing minted, no Swap. Use a processed amount whose 49% swap cannot be formed, including `mulDiv(amount, 49, 100) == 0`, and a quote that does not spend the whole 49% amount. Do not retry a smaller swap. | `test_collapsedCandidateKeepsNoSwap`. Add this function to the same contract. |
| The same collapsed input on `donate`: caller is not refunded, the input is booked, no Swap. | same new function |
| First deposit that does not add more than 1,000 liquidity, including a collapsed candidate that adds zero, reverts `MinLiquidityNotMet`. The call does not return a refund. No shares are minted. | `test_firstDepositBelowFloorRevertsMinLiquidityNotMet`. Add this function to the same contract. |
| One-token `amountOut` equals swap proceeds plus withdrawn requested-token principal plus requested-token fee portion plus requested booked claim. The recipient's balance increase equals that sum. The opposing token paid to the recipient is zero. The test uses a nonzero requested fee portion and a nonzero requested booked claim, so a two-term sum cannot satisfy it. `minAmountOut` equal to that sum succeeds. `minAmountOut` one above it reverts `AmountOutNotMet` and does not burn. | `test_oneTokenExitReceiptIsProceedsPlusWithdrawn` and `_assertExitReceipt` |
| A preview captured before the pool moves is not the receipt and is not the minimum basis. After the move, `amountOut` equals the four-term receipt from the post-move execution, not the saved preview. | `test_oneTokenExitMinimumIsNotStalePreview` |
| The exit swap cannot spend the whole unwanted amount: revert `AmountOutNotMet`, not `MinLiquidityNotMet`. Caller shares and `totalSupply` are unchanged. No face balance changes. | `UniswapV4FullSpreadStandardExchangeVault_Money_Test.test_incompleteExitRevertsAmountOutNotMetAndDoesNotBurn` |

File: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Package.t.sol`.

| Assertion | Function |
| --- | --- |
| FS-A01, as section 7 states it | `test_selectorCutAndCraneGetters` |
| FS-A02, including each of the six infrastructure addresses | `test_bindingHashChangesWithAnyBinding` |
| Each of the six addresses, missing and code-empty, reverts `InvalidComponent` before a diamond exists | `test_invalidComponentRevertsBeforeDiamond` |
| FS-A03 pool, caller, wrong-account registry, and second initialization, as section 7 states them | `test_badPoolWrongCallerAndSecondInitRevert` |
| FS-A04 slot inequality | `test_storageSlotIsNotPairTokenOrWings` |
| `getRate` and `asset` stay absent. This is not an `exchangeRate` test. | `test_getRateAndAssetAreAbsent` |

File: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/QuotesAndRate.t.sol`.

Remove these assertions. Do not replace them with another root, another iteration bound, or a tick walk. The outside-position and zero-liquidity cases are the Money.t.sol rows above, not quadratic zeros.

- `test_quadraticRootMatchesLockToken0`
- `test_quadraticRootMatchesLockToken1`
- `test_quadraticIsZeroOutsidePosition`
- `test_quadraticIsZeroWhenActiveLiquidityIsZero`
- `test_quadraticCapIsSegmentBoundary`

File: `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol`.

| Assertion | Function |
| --- | --- |
| `seBooked` returns 0 and does not read a balance | `seBooked` |
| `limitCapacity` and `openCapacity` remain empty | those two functions |

File: the weighted two-leg row named in section 8.

| Assertion | Function |
| --- | --- |
| `setUp` calls the weighted test base, then `_initializeWeighted(2)`. The override is present. | `setUp` |

Gas assertions are the functions named in section 8. Each asserts its named call is at or under its ceiling. None of those assertions is claimed to pass by this plan.

### 11. Traceability from each adopted remediation finding to a plan section

| Finding | What the lock adopted | Plan section |
| --- | --- | --- |
| F1 | An incomplete one-token exit raises `AmountOutNotMet` and does not burn | 4, 6, 10 |
| F2 | The exit basis is the recipient receipt, not an already observed quote-versus-pool shortfall | 6, 10 |
| F3 | A collapsed one-sided candidate returns the input and keeps no swap | 4, 5, 10 |
| F4 | The sizing method is 49% of the processed input. Do not restore the loop, the root, or a tick walk | 3, 4, 5, 10 |
| F5 | Each of the six infrastructure addresses is checked for code before it is stored | 4, 7, 10 |
| F6 | `seBooked` must not report a balance. Do not add a production booked view | 7, 10 |
| F7 | Empty capacity overrides stay. The parent requires them. Do not add a capacity gate | 7, 10 |
| F8 | The weighted two-leg `setUp` override stays | 7, 10 |
| F9 | Package.t.sol carries FS-A01 through FS-A04. Do not add the withdrawn `exchangeRate` half of FS-A16 | 7, 10 |
| F10 | Money.t.sol names the exit error | 6, 10 |
| F11 | Every named standalone route and every section 12 row has its own gas measurement | 8, 10 |
| Owner lock, migration | This pass does not walk or certify the preview-consumer index | 9 |
| Owner lock, unresolved list | Those items are not requirements | 9 |
| Owner lock, `getRate` | No `exchangeRate` test. `getRate` stays uninstalled | 3, 7, 10 |

### 12. Stop conditions

Stop when every row below is true, or when a named blocker is reported. Do not stop to ask a product question. The choices in section 3 are closed.

Rows that end the work:

- `_size` swaps 49% of the processed input inside the position, or takes the boundary path, or takes the collapsed path. It does not call the removed root helpers. The provisional 48%/49% comment is gone.
- A boundary price, including either exact bound, pushes no swap. Share-mint dust is refunded. Donate and compound dust is booked and not refunded. The other token is not swapped.
- A collapsed candidate pushes no swap. An existing-supply share mint refunds the full input and mints nothing. A donate or compound books that input and does not refund it.
- A first deposit that does not add more than 1,000 liquidity reverts `MinLiquidityNotMet` before the refund pay.
- `exchangeIn` maps an incomplete one-token exit to `AmountOutNotMet` and does not burn. The paid and returned `amountOut` is the four-term receipt. `minAmountOut` binds that receipt.
- The six infrastructure addresses are rejected, missing or code-empty, before they are stored.
- `seBooked` returns 0. `limitCapacity` and `openCapacity` stay empty. The weighted two-leg `setUp` override is present.
- Package.t.sol contains the FS-A01 through FS-A04 assertions in section 10. No `exchangeRate` test was added.
- Money.t.sol contains the sizing, boundary, collapsed, floor, receipt, and incomplete-exit assertions in section 10.
- The five quadratic assertions are not acceptance rows.
- Each standalone function in section 8 measures its named call with no preview warm-up.
- Each of the nine section 12 files measures its named hook swap with no preview warm-up.
- The preview-consumer index was not walked. The unresolved list was not implemented.

Named blockers. Report the row and stop that row. Do not raise a ceiling. Do not mark the row passed. Do not substitute another route.

- A standalone, composed, or preview measurement exceeds its ceiling. Report the route, the file, the function, and the measured value.
- The dual row's PairToken identity record is rejected. Report the consumer, selector, arguments, and revert under FS-HOOK-04. That gas row is not passed. Do not add `asset()`.
- A file named in section 4, 7, 8, or 10 cannot be opened.

This plan does not authorize the implementer to start.

## Limits

- Static reading only. No forge test, compile, gas measurement, install, deployment, or Git action was run for this response.
- A current function name is context for where the change goes. It is not a statement that the current test passes.
- Family plan and family PRD text outside the passages named in Evidence was not used as a source.
- Peer responses were not read.
- Runtime identity was not given. Those fields are not exposed.
- This plan does not replace the family plan and does not authorize implementation.
