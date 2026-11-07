# Member response — minimax

## Identity

- Member: minimax
- Profile: research
- Phase: initial independent response
- Requested role: council-member
- Requested model and reasoning: `minimax/MiniMax-M3`, admitted adaptive thinking, not a selectable depth
- Task ID: not exposed
- Write access on this pass: `docs/research/se-fullspread-remediation-plan-20261106/members/minimax/response.md` only
- Other runtime identity: not exposed. No other runtime identity is claimed.
- Sub-agents: none launched. No peer response was read.

## Question and targets

One remediation implementation and test plan for the adopted gaps in the current `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`, specific enough that an implementer closes them without making a product decision, and amendable against the family plan and the family PRD.

Targets named by the plan: the full-spread production family under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`, the family test directory `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`, the matrix fixture `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol`, and the nine section 12 row files under `test/foundry/spec/hooks/uniswap/v4/standardExchange/`.

## Evidence

Admitted sources, read in full or by the cited rows:

- `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`, the whole current file: the 2026-11-06 owner lock (Scope, Rule, Boundary, Collapsed candidate, Exit receipt, Migration scope), owner answers 1 to 5, findings F1 to F11, the unresolved list, coverage, and recommendations.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`: FS-OWN-30 (line 220), FS-OWN-32, FS-OWN-33 locked 2026-11-06 (line 246), FS-A01 to FS-A08 and FS-A16 (lines 550 to 561), FS-A05, FS-A31, and the exit-preview rows.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md`: sections 2, 4, 6, 7, 9, 10, 12, 13, 14, 15, and the 2026-11-05 owner answers (lines 387 to 497).

Context reads, declared code files read only to name the current function a plan sentence points at:

- `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol`: `planIn`, `_mintOne`, `_exit`, `planMaintenance`, `_size` (lines 178 to 224), `_shares` (lines 225 to 239).
- `UniswapV4FullSpreadStandardExchangeVaultMath.sol`: `sizeOneSided` (lines 47 to 83), `singleTokenAdd` (lines 198 to 227), and the unreferenced root helpers `quadraticInput`, `boundaryInput`, `grossFromNet` (lines 159 to 197).
- `UniswapV4FullSpreadStandardExchangeVaultSwapProjection.sol`: `exactInput` (lines 21 to 95, unbounded limit), `limitingSqrt` (lines 98 to 128).
- `UniswapV4FullSpreadStandardExchangeVaultExecution.sol`: `exchangeIn` (lines 52 to 110), including the exit receipt block and the `plan_.failed` mapping; `maintain`; `_run`; `_bookExit`.
- `UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol`: `constructor` (lines 70 to 112), `_validate`, `_append` (lines 265 to 290).
- `SeMatrix_FullSpreadV4Fixture.sol`: `seBooked`, `limitCapacity`, `openCapacity` (lines 105 to 118), `_deployPkg` (lines 157 to 195), and the parent `SeMatrixFixture.sol` declarations of `limitCapacity`, `openCapacity`, `seBooked` (lines 92 to 108).
- `UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`: `setUp` (lines 44 to 47) and `_initializeWeighted(2)`.
- Test files: `Package.t.sol` (338 lines in the current tree), `Money.t.sol`, `OneSidedFuzz.t.sol`, `QuotesAndRate.t.sol`, `BufferHookIntegration.t.sol`, `Native.t.sol`, and the nine section 12 row files, read for the assertion names and the measurement sites.

## Assumptions

- The current tree is the tree this plan applies to. The PRD's line citations predate it: `Package.t.sol` is 338 lines now, not the 69 the PRD cites, and it already carries the FS-A01 to FS-A04 rows the PRD reports as missing. The plan therefore states, per gap, whether the current tree already implements the law or still needs work.
- "The processed input" is the amount the Planner processes for one route: the declared input on the mint path, and the combined booked, collected-fee, and donation balance of the single held token on the one-token `donate` or `compound` path.
- The brief's requirement law is closed. This plan applies it and does not reopen it.
- The first-deposit composition in section 5 rests on the brief's law bullet, on family plan section 7 ("The route then continues with zero consumed input. The route's existing minimum and liquidity checks still apply. ... A first deposit that does not add more than 1_000 liquidity still reverts `MinLiquidityNotMet()`."), and on FS-A05 ("Added liquidity less than or equal to `1_000` is rejected"). It does not rest on the PRD's unresolved list.

## Coverage

Read: the required source, both base documents, and the declared code files above. Not read: the preview-consumer index, the repo-wide preview-migration sites, the other families' behavior contracts beyond the row files named here, the other members' files, and the rest of the repository. No test was run, no build was made, no gas was measured.

## Conclusions

### 1. Authority

This plan does not authorize implementation, tests, installs, deployment, or Git. It does not replace the family plan. It amends the family plan for the gaps named by the 2026-11-06 remediation lock and by the requirement law in section 3, and it leaves every other family-plan sentence in force. Starting the work this plan describes requires a later owner instruction.

### 2. Sources and precedence

Required source: `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`, the current file, including the 2026-11-06 owner lock and the boundary dust sentence.

Specification fingerprint: `4f1f3204088b39e038a17154d79594be262921a231c6a01eeb33a7ee0373e8f3`, coordinator-supplied, recorded here as coordinator-supplied and not recomputed by this member.

Base documents this plan amends, read where a remediation sentence depends on them:

- Family PRD: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`
- Family plan: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md`

Precedence, highest first:

1. The 2026-11-06 owner lock in the remediation PRD wins for the gaps it names: the 49% one-sided size, the boundary case, the collapsed candidate, the one-token exit receipt, and the migration scope.
2. The 2026-11-05 owner answers in the remediation PRD and family plan section 16 win for the six infrastructure components, the weighted two-leg `setUp`, the exit receipt basis, the `getRate` and `exchangeRate` absence, and the gas list.
3. FS-OWN-33 as locked 2026-11-06 in the family PRD, FS-OWN-30, FS-OWN-32, and the FS-A rows.
4. Family plan sections 2, 4, 6, 7, 9, 10, 12, 13.
5. Everything else in the family plan and PRD.

Not a source: historical question files, the readiness reports, the deleted remediation plan, the PRD's unresolved list, and the preview-consumer index. A removed sizing method is not a requirement.

### 3. Already closed product choices

These are copied from the brief's requirement law. They are not reopened here, and no removed method is restated as an option.

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

### 4. Production changes, naming the current function each change touches

One production change is required. Every other adopted gap is already implemented in the current tree by the named function; the plan states that so no implementer rewrites working code, and section 10 keeps the assertion that holds each one in place.

**P1. First-deposit floor before the zero-liquidity early return.**
Touch points: `UniswapV4FullSpreadStandardExchangeVaultPlanner._shares`, and, unchanged, the `plan_.failed` mapping in `UniswapV4FullSpreadStandardExchangeVaultExecution.exchangeIn`.

`_shares` currently returns before the first-deposit floor check whenever `plan_.liquidityAdded == 0`, so a candidate that adds nothing never reaches the `Types.MIN_SHARES` test. The change: evaluate the first-deposit floor first. When `ERC20Repo._totalSupply() == 0` and `plan_.liquidityAdded <= Types.MIN_SHARES`, set `plan_.failed = true` and return without a mint, without the floor mint, and without a refund. When the supply is not zero, a candidate that adds nothing keeps minting nothing and keeps its input as remainder. `Execution.exchangeIn` already maps a failed non-exit plan to `IVault.MinLiquidityNotMet()` before `_run`, so no burn, no swap, and no refund can occur; that mapping stays and must not be reused for the one-token exit, which maps to `AmountOutNotMet` in section 6. `planBundleIn` shares `_shares`, so a first bundle deposit that adds at most 1,000 liquidity reverts `MinLiquidityNotMet()` on the same path.

**Already implemented; no production change, keep as is.**

- 49% size: `Planner._size` takes one quote, derives the swap input with `FullMath.mulDiv(amount_, 49, 100)`, and calls `Math.sizeOneSided` once. No iteration, no root, no tick search.
- Collapsed candidate: `Planner._size` returns `remainder = amount_` with `swapIn`, `swapOut`, and `unswapped` zeroed when the 49% swap cannot be formed or when `Math.sizeOneSided` cannot fit the swap output, and `Math.sizeOneSided` returns `remainder = amount_` before any subtraction that could underflow.
- Boundary: `Planner._size` compares `read_.sqrtPriceX96 <= read_.sqrtA || read_.sqrtPriceX96 >= read_.sqrtB` and, at or beyond the boundary, returns either `Math.singleTokenAdd` with no swap action or the whole input as remainder.
- Exit receipt: `Execution.exchangeIn` snapshots the requested-token balance, runs the plan, computes `grown_` as the post-swap balance delta, subtracts the other holders' fee remainder, adds this holder's booked claim, and enforces the caller's minimum against that receipt before the burn.
- Incomplete exit: `Planner._exit` sets `plan_.failed` when the quote does not spend the unwanted amount, and `Execution.exchangeIn` maps that failure to `IStandardExchangeErrors.AmountOutNotMet` before `_run`.
- Six infrastructure components: the `UniswapV4FullSpreadStandardExchangeVaultDFPkg` constructor checks `code.length` for `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, and `universalRouter` and reverts `InvalidComponent` before any of them is stored.
- Fixture: `SeMatrix_FullSpreadV4Fixture.seBooked` returns zero and reads no balance; `limitCapacity` and `openCapacity` stay because `SeMatrixFixture` declares both as external virtual, so the overrides are required by the parent and add no gate.
- Weighted two-leg row: the `setUp` override that calls the weighted test base and then `_initializeWeighted(2)` stays.

**Changes that must not be made.**

- No production path may call `Math.quadraticInput`, `Math.grossFromNet`, `Math.boundaryInput`, or `SwapProjection.limitingSqrt`. They are the removed sizing method's helpers and are reachable today only through the two harnesses that the characterization contract uses. The Planner keeps the 49% single quote.
- `SwapProjection.exactInput` keeps the unbounded limit, `TickMath.MIN_SQRT_PRICE + 1` and `TickMath.MAX_SQRT_PRICE - 1`. No tick-capped price limit is added to the sizing or the exit swap.
- No new family error, no sleeve capacity gate, no booked view on the vault, no `getRate`, no `exchangeRate`.

### 5. One-sided size, including the boundary and the collapsed candidate

The size. Inside the position, `Planner._size` swaps 49% of the processed input and the add consumes the swap output. The swap input is the 49% fraction; the add consumes the swap output; rounding leaves the remainder in the input token. The size is computed once. There is no iteration, no exact-output sizing, no closed-form root, and no tick walk that looks for a better split. `Math.sizeOneSided` fits the liquidity to the quoted swap output and leaves the input-token remainder; it does not re-derive a better split.

The boundary. `Planner._size` requires the price to be strictly inside the position. At or beyond either boundary, including exactly at it, no swap is planned and no swap action is pushed. The wanted token is then added with no swap through `Math.singleTokenAdd`. What the add does not take stays in the input token: on the share-mint path `Planner._mintOne` carries it as `plan_.amountRefunded` and `Execution.exchangeIn` refunds it to `msg.sender` in the input token only; on the `donate` and `compound` path `Planner.planMaintenance` produces no refund and `Execution.maintain` re-books the vault's actual balances, so the dust is booked. The other token is never swapped: on the share-mint path it is refunded to `msg.sender`, and on the `donate` and `compound` path it is booked in the vault. No new error is introduced for any of these cases.

The collapsed candidate. `Planner._size` keeps no swap when the 49% swap cannot be formed or when the following add cannot consume its output: `swapIn`, `swapOut`, and `unswapped` are zeroed and the remainder is the whole input. The share-mint path then refunds that input and mints nothing. The `donate` and `compound` path books that input and does not refund it. A first deposit that does not add more than 1,000 liquidity reverts `MinLiquidityNotMet()`, and that revert is not a refund: P1 in section 4 moves the first-deposit floor ahead of the zero-liquidity early return so a collapsed first deposit reverts instead of refunding. The floor mint to `address(0)` and the fee-share mint happen only on a first deposit that adds more than 1,000 liquidity.

### 6. One-token exit receipt and the incomplete-exit error

The receipt. The one-token exit minimum, and the returned `amountOut`, are the recipient receipt: the swap proceeds, the withdrawn requested-token principal, the requested-token fee portion, and the requested booked claim. It is not the swap proceeds alone and it is not a stale preview. `Execution.exchangeIn` computes it from the post-run requested-token balance delta, after removing the other holders' fee remainder and after adding this holder's booked claim, and it enforces the caller's minimum against that receipt before the burn. The preview quotes the same receipt, so `previewExchangeIn` and `exchangeIn` agree for the same state.

The incomplete exit. `Planner._exit` measures before the burn, apportions the fee claim and the booked claim by `sharesBurned / supplyBeforeBurn`, and, when the projected swap does not spend the unwanted amount, sets `plan_.failed` and returns. `Execution.exchangeIn` maps that failure to `IStandardExchangeErrors.AmountOutNotMet` and returns before `_run`, so no share is burned, no token moves, and the booked balances are unchanged. The mapping for the one-token exit stays separate from the `IVault.MinLiquidityNotMet()` mapping that P1 uses for a failed mint plan.

The residual. The exit swaps all of the exiting holder's opposing principal, opposing fee portion, and opposing booked claim, and does not pay, book, or keep that residual. The other holders' fee and booked remainders are booked, not swapped.

### 7. Package and fixture assertions

Package. The `UniswapV4FullSpreadStandardExchangeVaultDFPkg` constructor rejects a missing or code-empty value for `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, and `universalRouter` with `InvalidComponent` before any of them is stored, so no partial diamond exists. `Package.t.sol` must assert that for all six addresses, in both the code-empty and the zero-address form, and must assert that a rejected deployment leaves no usable vault. The same file carries FS-A01 to FS-A04, the package cut, the permit domain, and the `getRate` and `asset` absence. `bindingHash` must change when any facet, library, or infrastructure binding changes. The storage slot must differ from the PairToken slot and the Wings slot. No `exchangeRate` test is added; `getRate` stays uninstalled and its absence is asserted, not its history.

Fixture. `SeMatrix_FullSpreadV4Fixture.seBooked` returns zero and must not read a balance. `limitCapacity` and `openCapacity` stay as the empty overrides the parent requires, and no capacity gate is added. The fixture deploys this vault through its production package and the bound IndexedEx registry, binds one hookless PoolKey, bootstraps with one public bundle deposit of both faces, deploys the `currency0` and `currency1` external rate providers, and does not mock, etch, or inject storage into this vault or the PoolManager.

Weighted row. The two-leg row keeps its `setUp` override, which calls the weighted test base and then `_initializeWeighted(2)`. The three-leg file remains the `n == 3` override.

### 8. Gas measurements, naming each route and file

Ceilings do not move: 11,900,000 for a cold standalone body, 12,000,000 for a composed transaction, and 5,000,000 for a preview. Every measurement is the first call to its route in its own transaction, so the body is cold; fixture setup and seeding stay outside the measured window; no measurement is warmed by a preview; and no measurement reads `getRate`. An oversized route is reported as unresolved, not passed, and the ceiling is not raised to make it pass.

Standalone routes, 11,900,000, in `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Money.t.sol`:

| Route | Measurement site |
| --- | --- |
| `exchangeIn`, one-sided share mint | `test_gasOneSidedMintFitsCeiling` |
| `exchangeIn`, one-token exit | `test_gasOneTokenExitFitsCeiling` |
| `exchangeIn`, pass-through | `test_gasPassThroughFitsCeiling` |
| `exchangeBundleInForSingleOut` | `test_gasBundleInFitsCeiling` |
| `exchangeBundleOut` | `test_gasBundleOutFitsCeiling` |
| `donate` | `test_gasDonateFitsCeiling` |
| `compound` | `test_gasCompoundFitsCeiling`, in `UniswapV4FullSpreadStandardExchangeVault_MoneyCompoundGas_Test` |

`setOperator` and `setOperatorFor` are appointment calls and are not in this set.

Composed routes, 12,000,000, one measurement in each section 12 row file, named `test_composedRouteGasFitsCeiling`:

| Section 12 row | File, under `test/foundry/spec/hooks/uniswap/v4/standardExchange/` |
| --- | --- |
| single | `single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` |
| constant-product single | `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` |
| dual | `dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` |
| orbital | `orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` |
| weighted, 2 legs | `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` |
| weighted, 3 legs | `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol` |
| curve quad | `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` |
| balancer quad, 2 legs | `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` |
| balancer quad, 5 legs | `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5.t.sol` |

Preview routes, 5,000,000, in `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/QuotesAndRate.t.sol`: `previewExchangeIn`, `previewExchangeBundleInForSingleOut`, `previewExchangeBundleOut`, and `previewExchangeOut`.

### 9. Out of scope

- The preview-consumer index walk and the repo-wide migration of one-word `previewExchangeIn` and `exchangeIn` decoders. The family plan still requires that migration. This plan does not close it and does not certify it. The index line anchors are not a live checklist, and this plan does not regenerate the index.
- The PRD's unresolved list, none of which is a requirement here: the exit projection not removing the position from the projected pool state; the zero-added-liquidity bypass characterization; the classification of a recorded rejection or an unverified address-side case as a compatible passing row; the section 12 identity-bind rows that pass after a recorded rejection and the single-row partial-consumption assertions; the remaining Astra findings 6 to 21 and Kimi findings 5, 6, and 8 to 14 that F9, F10, or F11 does not already cover; the share-burn allowance reading; the native credit receipt reading; the repo-wide migration sites; and the index line anchors.
- Restoring any removed sizing method, and re-deriving the 49% fraction.
- `getRate`, `exchangeRate`, and every rate row for this vault.
- A sleeve capacity gate, a booked view on the vault, or a booked getter that reports a balance.
- Implementation, tests, installs, deployment, wallets, Git, and edits to the remediation PRD, the family PRD, and the family plan.

### 10. Tests

Every row below names an assertion and a file. No row is claimed to pass; each is a requirement on the suite the implementer delivers. Hermetic suites use `forge test --use solar`; `via_ir` is forbidden; production artifacts are built before the tests because the factory services read creation bytecode from `out/`.

New rows, to be added:

| Assertion | File |
| --- | --- |
| A one-sided deposit whose 49% swap fraction rounds to zero keeps no swap: the pool price is unchanged, the whole input is refunded in the input token, no shares are minted, and no other-token balance appears in the vault | `Money.t.sol`, `UniswapV4FullSpreadStandardExchangeVault_OneSidedAndExit_Test` |
| A first deposit that adds at most 1,000 liquidity reverts `IVault.MinLiquidityNotMet()`, refunds nothing, mints nothing, and leaves the total supply unchanged | `Money.t.sol`, a new test contract that does not bootstrap the vault |
| With deep enough liquidity for the swap to be fully spent, the pool `Swap` event input equals `FullMath.mulDiv(processedInput, 49, 100)` for a one-sided share mint and for a one-token `donate`, and the add consumes the swap output | `Money.t.sol`, `UniswapV4FullSpreadStandardExchangeVault_OneSidedAndExit_Test` |
| A one-token exit receipt equals the recipient's requested-token increase and contains the withdrawn requested-token principal, the requested-token fee portion, and the requested booked claim, and not the swap proceeds alone | `Money.t.sol`, `UniswapV4FullSpreadStandardExchangeVault_OneSidedAndExit_Test` |
| Each of the six infrastructure addresses, in the zero-address form as well as the code-empty form, reverts `InvalidComponent` in the package constructor and leaves no usable vault | `Package.t.sol` |

Rows that exist and must remain, each asserted against the law in section 3:

| Assertion | File |
| --- | --- |
| An incomplete one-token exit reverts `AmountOutNotMet` and does not burn: shares, total supply, caller balances, recipient balances, and vault balances are unchanged | `Money.t.sol`, `test_incompleteExitRevertsAmountOutNotMetAndDoesNotBurn` |
| The exit receipt is the swap proceeds plus the withdrawn principal, the returned `amountOut` equals the recipient's balance increase, and a minimum above the receipt reverts `AmountOutNotMet` without a burn | `Money.t.sol`, `test_oneTokenExitReceiptIsProceedsPlusWithdrawn` |
| A minimum set from a stale preview is not paid as a stale quote: the returned `amountOut` equals the recipient's actual increase | `Money.t.sol`, `test_oneTokenExitMinimumIsNotStalePreview` |
| A one-sided mint refunds only the input token, the other token is neither refunded nor left booked, and the preview equals execution | `Money.t.sol`, `test_oneSidedMintRefundsOnlyInputToken`, `test_spotOneSidedMintRefundsOnlyInputToken`, `test_oneSidedPreviewMatchesExecution` |
| A one-token `donate` swaps and books the input remainder and does not refund it, and a one-token `compound` does not refund and does not book the other token | `Money.t.sol`, `test_oneTokenDonateSwapsAndBooksInputRemainder`, `test_oneTokenCompoundDoesNotRefund` |
| At and beyond either boundary no swap happens: the price is unchanged, the wanted token is added, the unwanted token is refunded for a mint and booked for a `donate` | `Money.t.sol`, `test_outsidePositionAddsWantedToken` |
| An unusable one-sided input is refunded whole and the refund is never in the other token | `OneSidedFuzz.t.sol`, `testFuzz_oneSidedPreviewMatchesExecution` |
| FS-A01 to FS-A04, the package cut, the permit domain, and the `getRate` and `asset` absence; no `exchangeRate` test exists | `Package.t.sol` |
| The seven standalone gas measurements and the four preview measurements, none warmed by a preview | `Money.t.sol`, `QuotesAndRate.t.sol` |
| The composed measurement in each section 12 row | the nine row files in section 8 |
| The two-leg row overrides `setUp` and calls the weighted test base, then `_initializeWeighted(2)` | the weighted 2-leg row file |

### 11. Traceability

From each adopted remediation finding to a plan section, with the state of the current tree as this member read it:

| Finding | Section | State in the current tree |
| --- | --- | --- |
| F1, incomplete exit raises the wrong error | 6, 10 | `Execution.exchangeIn` already maps a failed one-token exit plan to `AmountOutNotMet` before `_run`; `Money.t.sol` carries the regression row |
| F2, exit basis | 6, 10 | `Execution.exchangeIn` already builds the receipt from the post-run balance delta; the fee portion and the booked claim are not separately pinned, so the new receipt row in section 10 applies |
| F3, collapsed candidate | 5, 4 (P1), 10 | `Planner._size` already keeps no swap and returns the input as remainder; P1 adds the first-deposit composition, and the new collapsed-candidate and first-deposit rows apply |
| F4, the reviewed sizing loop is not the method | 3, 4, 5 | `Planner._size` already takes one 49% quote; the removed method's helpers must not be wired back |
| F5, infrastructure addresses | 4, 7, 10 | The constructor already checks the six addresses; the zero-address variants of the package row apply |
| F6, the fixture booked getter | 7 | `seBooked` already returns zero and reads no balance |
| F7, the fixture capacity declarations | 7 | The parent requires both overrides, so they stay and add no gate |
| F8, the weighted two-leg `setUp` | 7, 10 | The override is present and stays |
| F9, FS-A01 to FS-A04 in `Package.t.sol` | 7, 10 | The file now carries those rows; the zero-address variants apply |
| F10, `Money.t.sol` does not name the exit error | 6, 10 | The regression row is present and stays |
| F11, gas rows | 8, 10 | All seven standalone routes, all nine section 12 rows, and the four preview routes carry measurements |

From each bullet of the requirement law in section 3 to a plan section:

| Requirement law bullet | Section |
| --- | --- |
| 49% of the processed input, no iteration, no root, no tick walk | 4, 5, 10 |
| Boundary, including exactly at either boundary | 5, 10 |
| Collapsed candidate, refund or book, and the first-deposit floor | 4 (P1), 5, 10 |
| One-token exit receipt and the incomplete-exit error | 6, 10 |
| Missing or code-empty infrastructure address reverts `InvalidComponent` | 4, 7, 10 |
| The weighted two-leg row keeps its `setUp` override | 7, 10 |
| No `exchangeRate` test; `getRate` stays uninstalled | 4, 7, 10 |
| Gas ceilings and every named route and row measured | 8, 10 |
| The preview-consumer index is not walked or certified | 9 |
| `seBooked()` reports no balance; empty capacity overrides stay; no capacity gate | 4, 7 |
| The unresolved list is not a set of new requirements | 9 |

### 12. Stop conditions

Stop when all of these rows are true:

1. `Planner._shares` evaluates the first-deposit floor before the zero-added-liquidity early return, and a first deposit that adds at most 1,000 liquidity reverts `MinLiquidityNotMet()` with no refund and no mint.
2. `Money.t.sol` carries the collapsed-candidate row: no swap, the whole input refunded in the input token, no shares minted.
3. `Money.t.sol` carries the first-deposit floor row: `MinLiquidityNotMet`, no refund, no mint, supply unchanged.
4. `Money.t.sol` carries the 49% fraction row for the one-sided share mint and for the one-token `donate`.
5. `Money.t.sol` carries the exit receipt row that includes the withdrawn principal, the requested fee portion, and the requested booked claim, and equals the recipient's increase.
6. `Money.t.sol` keeps the incomplete-exit row: `AmountOutNotMet`, no burn, balances unchanged.
7. `Package.t.sol` carries the zero-address and code-empty variants for all six infrastructure addresses.
8. The seven standalone measurements, the four preview measurements, and the nine composed row measurements are present, cold, and not preview-warmed.
9. The fixture keeps `seBooked()` returning zero and both empty capacity overrides, with no capacity gate.
10. The weighted two-leg row keeps its `setUp` override with `_initializeWeighted(2)`.
11. No production path calls `Math.quadraticInput`, `Math.grossFromNet`, `Math.boundaryInput`, or `SwapProjection.limitingSqrt`.
12. No `exchangeRate` test exists and `getRate` stays uninstalled.

Stop and report when one of these blockers is hit:

- A standalone route or a composed row exceeds its ceiling. Report the route, the measured gas, and the file. Do not raise the ceiling and do not change the route's economics.
- A section 12 row cannot be measured. Report the row, the file, and the setup failure.
- P1 makes an existing full-spread test fail. Report the test, the file, and the expectation that conflicts with the law. Do not delete or weaken the test.
- The 49% fraction cannot be observed from the pool event for a route. Report the route and the observation used instead. Do not change the fraction.
- The first-deposit floor row cannot be produced from the current test base. Report the constraint and the fixture needed. Do not weaken the floor.

## Limits

- Static reading only. No forge test, compile, gas measurement, install, deployment, or Git action was run for this contribution.
- The fingerprint `4f1f3204088b39e038a17154d79594be262921a231c6a01eeb33a7ee0373e8f3` is recorded as coordinator-supplied and was not recomputed.
- The code-file reads listed under Evidence are context reads for naming current functions. They are not a review of those files and not a re-adjudication of the PRD's findings.
- This contribution does not certify the preview-consumer migration, does not walk the index, and implements nothing from the unresolved list.
- No peer response was read, no sub-agent was launched, and no file outside the owned response path was written.
- Member reading is not a coordinator re-read, and no statement here is runtime proof.
