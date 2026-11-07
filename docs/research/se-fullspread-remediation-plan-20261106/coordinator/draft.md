# Full-spread remediation implementation and test plan

- Draft ID: draft-se-fullspread-remediation-plan-20261106-r1
- Plan ID: se-fullspread-remediation-plan-20261106
- Requirement source: `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`
- Specification fingerprint, coordinator-supplied: `4f1f3204088b39e038a17154d79594be262921a231c6a01eeb33a7ee0373e8f3`
- This draft is not the published plan. It does not authorize implementation.

## 1. Authority

This plan amends the family plan for the gaps adopted by the current remediation PRD. It does not replace the family plan or the family PRD. It does not authorize implementation, tests, installs, deployment, or Git.

Family plan: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md`

Family PRD: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`

## 2. Sources and precedence

The 2026-11-06 owner lock in the remediation PRD wins for the gaps it names. A dated lock in the family PRD wins over an older sentence in the family plan. A status line that says a file was not edited is not a lock.

A member report that the current tree already implements a gap is context, not proof. Verify the named function. If it already matches, keep it. If it does not, that is the defect. Do not invent a second mechanism.

## 3. Already closed product choices

- Inside the position, a one-sided share mint and a one-token `donate` or `compound` swap 49% of the processed input, then deposit. Do not iterate. Do not size an exact output. Do not solve a closed-form root. Do not walk ticks to find a better split.
- If the price is not strictly inside the position, including exactly at either boundary, do not swap. A share mint refunds what the add does not take. A `donate` or `compound` books that dust and does not refund it. The other token is not swapped. A share mint refunds it. A `donate` or `compound` books it.
- A collapsed candidate returns the input and keeps no swap. A share mint refunds that input and mints nothing. A `donate` or `compound` books that input and does not refund it. A first deposit that does not add more than 1,000 liquidity still reverts `MinLiquidityNotMet`. That is not a refund.
- The one-token exit receipt is the swap proceeds, the withdrawn requested-token principal, the requested-token fee portion, and the requested booked claim. An incomplete exit raises `AmountOutNotMet` and does not burn.
- A missing or code-empty value among `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, and `universalRouter` reverts `InvalidComponent` before it is stored.
- The weighted two-leg row keeps its `setUp` override.
- Do not add an `exchangeRate` test. `getRate` stays uninstalled.
- Gas ceilings stay 11,900,000 for a cold standalone body, 12,000,000 for a composed transaction, and 5,000,000 for a preview. Do not warm a measurement with a preview.
- This pass does not walk or certify the preview-consumer index.
- `seBooked()` must not report a balance. Do not add a capacity gate.

## 4. Production changes

Name the current function. Do not restore a removed sizing helper on these paths.

| Function | Required behavior |
| --- | --- |
| `Planner._size` | Inside the position, one exact-input quote of 49% of the processed input, then one add. No loop. Do not call `quadraticInput`, `boundaryInput`, `grossFromNet`, or `_positiveRoot`. At the boundary, push no swap. Wanted token uses `singleTokenAdd`. Other token is not swapped. A collapsed candidate keeps no swap. |
| `Planner.planMaintenance` | A one-token `donate` or `compound` calls `_size` with the combined booked, collected-fee, and donation balance of that token. It does not refund dust. |
| `Planner._shares` | A first deposit whose added liquidity is not greater than 1,000, including zero, fails before any refund path. |
| `Planner._exit` | Swaps the whole unwanted claim, not 49%. If that quote cannot spend the whole unwanted amount, the plan fails and keeps no swap. `amountOut` is the four-part receipt. |
| `Execution.exchangeIn` | `OneTokenExit` with `plan.failed` reverts `AmountOutNotMet` before the burn. A first-deposit floor failure reverts `MinLiquidityNotMet` and does not refund. |
| `UniswapV4FullSpreadStandardExchangeVaultDFPkg` constructor | Checks the six infrastructure addresses for code before storage. A miss reverts `InvalidComponent` and creates no diamond. |

`planBundleIn` does not call `_size`. Do not add a 49% swap to a bundle deposit. `_exit` does not call `_size`.

## 5. One-sided size

Processed input is the amount the current function already passes to `_size`. For a share mint, that is the funded declared amount. For `donate` or `compound`, that is the combined one-token maintenance balance.

Inside the position, the swap input is `mulDiv(amount, 49, 100)`. The add consumes the swap output. Rounding remainder stays in the input token. A share mint refunds it. A `donate` or `compound` books it.

At the boundary, do not swap. A share mint refunds what the add does not take. A `donate` or `compound` books that dust and does not refund it.

A collapsed candidate is not the boundary. Zero active liquidity is this case. If the 49% swap cannot be formed, or the add cannot consume its output, keep no swap. A later share mint refunds the whole input and mints nothing. A `donate` or `compound` books that input and does not refund it. A first deposit that does not add more than 1,000 liquidity reverts `MinLiquidityNotMet` instead of taking the refund path.

## 6. One-token exit

Measure before the burn. The holder's fee claim is `floor(feesAccrued * sharesBurned / supplyBeforeBurn)` for each token. The holder's booked claim is `floor(bookedBalance * sharesBurned / supplyBeforeBurn)`. Do not count the same fee in both terms.

Swap all opposing principal, opposing fee, and opposing booked claim into the requested token, or fail the plan. Pay the recipient the swap proceeds, the withdrawn requested-token principal, the requested-token fee portion, and the requested booked claim. That sum is `amountOut`. `minAmountOut` binds that receipt.

If the swap cannot spend the whole unwanted claim, revert `AmountOutNotMet` and do not burn. Do not map that case to `MinLiquidityNotMet`.

## 7. Package and fixture

`Package.t.sol` must assert FS-A01 through FS-A04: the selector cut, a `bindingHash` change, `InvalidComponent` for each of the six addresses, and the slot check. A constructor revert creates no package and no diamond. Do not add an `exchangeRate` test.

`SeMatrix_FullSpreadV4Fixture.seBooked()` returns 0. It must not return a token balance. Keep the empty `limitCapacity` and `openCapacity` overrides if the parent declares them. Do not fill them in. The weighted two-leg `setUp` calls the parent `setUp`, then `_initializeWeighted(2)`. Do not delete that override.

## 8. Gas

One cold measurement per standalone route, in the money or maintenance file that owns the route: one-sided share mint, one-token exit, pass-through, `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound`. One composed measurement for each family-plan section 12 row, in that row's file. One preview measurement for each preview route, in the quote file, under 5,000,000. Do not warm any measurement with a preview. An oversized route is unresolved, not passed. Do not raise a ceiling.

## 9. Out of scope

- The preview-consumer index walk. The family plan still requires it. This plan does not close it.
- The remediation PRD's unresolved list. Naming those items is not a finding that they are defects.
- Restoring an iterative sizing loop, a closed-form root, or a tick walk.
- Adding `asset()`, `getRate`, or `exchangeRate`.
- A capacity gate.

## 10. Tests

Do not claim any row already passes. A row that already matches stays. A row that does not is the defect.

| Row | File | Assertion |
| --- | --- | --- |
| Inside, share mint | `Money.t.sol` | One swap of 49%. The add consumes the swap output. Remainder is in the input token and is refunded. |
| Inside, donate and compound | `Money.t.sol` | Same 49% shape. Input-token remainder is booked, not refunded. |
| Boundary, wanted token | `Money.t.sol` | No swap. Share mint refunds unused add dust. `donate` and `compound` book that dust. |
| Boundary, other token | `Money.t.sol` | No swap. Share mint refunds the input. `donate` and `compound` book it. |
| Collapsed, supply already nonzero | `Money.t.sol` | No swap. Share mint refunds the whole input and mints nothing. `donate` and `compound` book the input. |
| First deposit at or under 1,000 | `Money.t.sol` | `MinLiquidityNotMet`. No refund. No mint. Includes a collapsed first deposit that adds zero. |
| Incomplete one-token exit | `Money.t.sol` | `AmountOutNotMet`. No burn. Not `MinLiquidityNotMet`. |
| Exit receipt | `Money.t.sol` | `amountOut` equals swap proceeds plus withdrawn requested-token principal plus requested-token fee portion plus requested booked claim. |
| Invalid component | `Package.t.sol` | Each of the six addresses reverts `InvalidComponent` before a diamond exists. |
| Removed sizing helpers | `QuotesAndRate.t.sol` | No assertion requires `quadraticInput` or an iterative sizing loop. |

## 11. Traceability

| Finding | Plan section |
| --- | --- |
| F1 incomplete exit error | 6, 10 |
| F2 recipient receipt | 6, 10 |
| F3 collapsed candidate | 5, 10 |
| F4 sizing method | 3, 5, 10 |
| F5 infrastructure code check | 4, 7, 10 |
| F6 `seBooked` | 7 |
| F7 capacity overrides | 7, 9 |
| F8 weighted `setUp` | 7 |
| F9 package assertions | 7, 10 |
| F10 `AmountOutNotMet` in money tests | 10 |
| F11 gas | 8 |

## 12. Stop conditions

Stop when every section 10 row is true against the current functions, or when a named function cannot meet its section 4 row without a new product choice. Report that blocker. Do not choose it. Do not certify the preview-index walk.
