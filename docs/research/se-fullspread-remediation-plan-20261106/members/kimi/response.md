# Kimi response: full-spread remediation implementation and test plan

## Identity

- Run: `se-fullspread-remediation-plan-20261106`
- Member: `kimi`
- Profile: research
- Phase: initial independent response
- Requested role: council-member
- Requested model: `kimi-coding/k3.1-pro:high`, global route
- Runtime identity: not exposed
- Task ID: not exposed

## Question and targets

Write one remediation implementation and test plan from the current `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`, specific enough for an implementer to close adopted findings F1-F11 without making another product decision. The deliverable is only this owned response. The coordinator retains publication of the consolidated plan.

## Evidence

- Read the council brief in full.
- Read the whole current remediation PRD, including the 2026-11-06 owner lock, F1-F11, the unresolved list, recommendations, and limitations.
- Coordinator-supplied remediation PRD fingerprint: `4f1f3204088b39e038a17154d79594be262921a231c6a01eeb33a7ee0373e8f3`; recorded as supplied and not recomputed.
- Read the family plan's adopted readings, package and storage law, money routes, quotes, hook rows, migration boundary, test plan, implementation names, traceability, and owner answers.
- Read the family PRD's package rules, money rules, FS-TEST-01 through FS-TEST-04, and acceptance rows FS-A01 through FS-A39 where the remediation depends on them.
- Context-only reads to name current functions: `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol`, `UniswapV4FullSpreadStandardExchangeVaultMath.sol`, `UniswapV4FullSpreadStandardExchangeVaultExecution.sol`, and `UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol`. These reads are locators, not a fresh conformance review or runtime evidence.
- No peer response was read.

## Assumptions

- No product assumption is added. The 2026-11-06 remediation lock and the other owner answers are closed law.
- Implementation begins only under a later authorization; this response is a plan, not that authorization.
- Current function names identify edit seams. Their presence does not establish that a finding is already fixed or that any test passes.
- In the test tables, `Package.t.sol`, `Money.t.sol`, `QuotesAndRate.t.sol`, and `BufferHookIntegration.t.sol` mean the corresponding files under `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`.

## Coverage

The plan covers every adopted remediation finding F1-F11. It assigns production edit seams, one-sided inside/boundary/collapsed behavior, the exit receipt and error, package and fixture corrections, all required gas rows, executable assertions, traceability, and stop conditions. It does not cover the unwalked preview-consumer index or convert the remediation PRD's unresolved list into work.

## Conclusions

### 1. Authority

This plan amends `UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md` only for the gaps adopted by the remediation PRD. It does not replace the family plan or the family PRD. It does not authorize implementation, tests, installs, deployment, wallet operations, or Git. It does not certify current code, current tests, gas usage, or preview-consumer migration.

### 2. Sources and precedence

1. The current remediation PRD, including its 2026-11-06 owner lock and boundary dust sentence, wins for every gap that lock names. Its fingerprint is the coordinator-supplied value recorded above, not a recomputed value.
2. The family PRD and family plan remain the base for behavior the remediation does not amend, including production-first harness rules, FS-A01 through FS-A08, FS-A31, and the section 12 row topology.
3. Later owner locks in the admitted sources win over older conflicting sentences. Historical question files, readiness reports, deleted remediation plans, and the unresolved list are not requirements sources.
4. The context-only production reads supply current function names. They do not supersede either specification and do not add a finding.
5. Where this plan repeats a closed rule, implement that rule literally. Do not substitute an alternative economic design or a removed sizing method.

### 3. Already closed product choices

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

### 4. Production changes

1. **One-sided candidate construction.** In `UniswapV4FullSpreadStandardExchangeVaultPlanner._size`, form one candidate from 49% of the processed input only when the position is strictly in range and active liquidity is nonzero. Require the exact-input projection to spend that complete 49% and return a usable output. In `UniswapV4FullSpreadStandardExchangeVaultMath.sizeOneSided`, size the following add from the quoted output, require the add to consume that output completely, require the unswapped input to cover the add's input-token charge, and leave rounding only in the original input token. Reject the whole candidate when any of those conditions fails; clear its swap and add fields and set its remainder to the full processed input.
2. **One-sided route propagation.** In `Planner._mintOne`, publish the candidate remainder as `amountRefunded` and the positional refund, push no swap or add for a collapsed candidate, and retain `Planner._shares` as the first-deposit floor check for a selected add. In `Planner.planMaintenance`, apply the same candidate rule to the combined one-token processed balance and push no action for a collapsed candidate. In `UniswapV4FullSpreadStandardExchangeVaultExecution.exchangeIn`, refund the returned input-token remainder to `msg.sender` and mint only the selected plan's shares. In `Execution.maintain`, book the actual post-settlement held balances, including boundary dust or a collapsed input, and never pay that remainder as a refund. `Execution._run` must execute a selected swap before its selected add and must execute neither for a collapsed candidate.
3. **One-token exit failure and receipt.** In `Planner._exit`, retain the pre-burn principal, fee, and booked apportionment; mark the plan failed when the exact-input projection cannot spend all opposing principal plus opposing fee and opposing booked claim. In `Execution.exchangeIn`, map that specific failed one-token exit to `AmountOutNotMet` before `_run` and before any burn, rather than to `MinLiquidityNotMet`. After a viable plan runs, calculate the requested-token recipient receipt from the actual settled proceeds and the holder's requested principal, requested fee portion, and requested booked claim; enforce `minOut_` on that receipt before burning, then return and pay that same receipt. Keep `Execution._bookExit` limited to the holder claims and other holders' remainders, with no residual opposing-token payment, booking, or retention for the exiting holder.
4. **Infrastructure validation.** In `UniswapV4FullSpreadStandardExchangeVaultDFPkg.constructor`, check `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, and `universalRouter` for nonzero code before storing each binding. A zero or code-empty address reverts `InvalidComponent`; deployment therefore leaves no partial diamond. Keep these six bindings inside `bindingHash` and do not narrow the existing checks on the other components.
5. **No rate or capacity addition.** Do not add `getRate`, `exchangeRate`, a booked production view, a sleeve capacity gate, or a new error for boundary dust or a collapsed candidate. No production change is authorized for an unresolved-list item.

### 5. One-sided size

Use this algorithm for a one-sided share mint and for the one-token arm of `Planner.planMaintenance`:

1. Define `amount` as the processed input after route funding. For maintenance, this is the combined one-token booked, collected-fee, and donation balance specified by family plan section 9. The direction is the provided face token's `zeroForOne` direction.
2. **Boundary first.** If `sqrtPriceX96 <= sqrtA` or `sqrtPriceX96 >= sqrtB`, create no swap. At the lower boundary the position wants token0; at the upper boundary it wants token1. If the caller supplied the wanted token, use the single-token add calculation and leave any unconsumed dust in that token. If the caller supplied the other token, select no add and return the entire input as remainder. A share mint refunds the remainder. A donation or compound books it. Equality at either boundary follows this rule, not the in-range rule.
3. **In-range candidate.** Only when `sqrtA < sqrtPriceX96 < sqrtB` and active pool liquidity is nonzero, compute `swapIn = mulDiv(amount, 49, 100)`. Form one unbounded exact-input projection for `swapIn`. The candidate collapses if `swapIn` is zero or cannot be represented by the swap call, the projection cannot spend all `swapIn`, received output is zero, or no add can consume the received output with the remaining original input.
4. **Selected add.** Given a fully spent `swapIn` and `swapOut`, derive the greatest feasible add from `swapOut`. Let `needOut` be the add's charge in the swap-output token and `needIn` its charge in the original input token. Require `needOut == swapOut` and `needIn <= amount - swapIn`. Set `unswapped = needIn` and `remainder = amount - swapIn - needIn`. The selected actions are exactly one swap of `swapIn`, then one add; the add consumes all `swapOut`. There is no opposing-token remainder from the selected plan.
5. **Collapsed candidate.** Zero active liquidity is a collapse condition, not a boundary case. On any collapse condition, clear `swapIn`, `swapOut`, `unswapped`, and `liquidity`, set `remainder = amount`, and push neither a swap nor an add. A share mint returns that input to the payer and mints nothing. A donation or compound books that input and refunds nothing.
6. **First-deposit floor.** A selected first add with `0 < liquidityAdded <= 1_000` still makes `Planner._shares` fail the plan and makes `Execution.exchangeIn` revert `MinLiquidityNotMet`. Do not convert that revert into a collapsed-refund success. A collapsed first candidate has no selected add and follows the preceding remainder rule.

Preview and execution continue to use the same Planner candidate from the same state. A preview is not permission to warm a gas measurement or to substitute a stale result during execution.

### 6. One-token exit receipt and the incomplete-exit error

1. Before the burn, calculate the holder's withdrawn principal in each face, requested and opposing fee claims, and requested and opposing booked claims using the family plan's pre-burn supply and multiplication-before-division rules.
2. The opposing amount to swap is opposing withdrawn principal plus the opposing fee claim plus the opposing booked claim. If that amount is nonzero and the exit swap cannot spend all of it, `Planner._exit` returns a failed one-token-exit plan. `Execution.exchangeIn` raises `AmountOutNotMet`; it does not call `_run`, burn shares, or pay a partial exit. Any later minimum failure also reverts the whole transaction, so an apparent action before the revert leaves no state change.
3. For a viable exit, the recipient receipt is exactly: actual requested-token swap proceeds + withdrawn requested-token principal + the holder's requested-token fee portion + the holder's requested booked claim. Do not use swap proceeds alone, do not use only the pre-execution quote, and do not count another holder's fee remainder or booked balance.
4. In `Execution.exchangeIn`, derive the actual requested-token increase across `_run`, remove the other holders' requested-token fee remainder, and add the holder's requested booked claim so that booked custody is neither omitted nor double-counted. Compare `minOut_` with this receipt before `ERC20Repo._burn`. Set `amountOut_` to the same receipt, pay exactly it to `recipient`, and only then book the other holders' remainders through `_bookExit`.
5. `Planner._exit` remains the preview engine: its projected `amountOut` is the requested direct components plus projected swap proceeds from the same pre-burn state. Execution must not pay a stale preview when the settled receipt differs.

### 7. Package and fixture assertions

1. In `Package.t.sol`, carry FS-A01 through FS-A04 explicitly:
   - FS-A01: assert the reviewed selector cut through the factory-built proxy, the required absent family selectors, the callable Crane Protocol Aware and SinglePositionAware getters, and factory-owned surfaces remaining callable without being package cuts. `getRate` and `rateAsset` remain absent.
   - FS-A02: assert `bindingHash` changes when any facet, any linked library, or any infrastructure binding changes, including each of the six named infrastructure addresses.
   - FS-A03: for each of `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, and `universalRouter`, deploy with a zero value and with a code-empty nonzero value and assert `InvalidComponent` with no usable vault. Retain the other invalid-component and invalid-initialization rows, including hooked or uninitialized pool keys, double initialization, wrong `processArgs` caller, and the right registry in the wrong account.
   - FS-A04: assert the full-spread storage slot equals its specified namespace derivation and differs from both PairToken's and Wings' slots.
   - Preserve the permit-domain and direct-transfer assertions and the absent `getRate`/`asset` coverage. Do not add an `exchangeRate` assertion or an issuance-reads-`exchangeRate` assertion.
2. In `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol`, remove `seBooked()` and every test-row dependency on it. Do not replace it with `token0.balanceOf(seVault)`, another raw-balance getter, or a production booked view. Inspect the immediate parent fixture contract for `limitCapacity()` and `openCapacity()`: retain empty overrides when the parent requires the declarations; remove them only when the parent does not. Neither branch adds logic, a capacity gate, or a new production selector.
3. Keep `setUp` in `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`. It calls the weighted TestBase setup once and then `_initializeWeighted(2)` before the row's own bind. Keep the separate `_N3.t.sol` override for `n == 3`. Do not delete the two-leg override or make the two-leg row reuse the three-leg initialization.

### 8. Gas measurements

Use real production fixtures, put setup outside the measured body, record the measured value, and assert the applicable ceiling. A standalone measurement is a cold public-call body with no preceding preview in that measurement. A composed measurement covers the whole hook transaction, including vault and hook work. An oversized route remains unresolved and is not reported as passing.

| Measurement | File | Ceiling |
| --- | --- | ---: |
| `exchangeIn` one-sided share mint | `Money.t.sol` | 11,900,000 cold standalone |
| `exchangeIn` one-token exit | `Money.t.sol` | 11,900,000 cold standalone |
| `exchangeIn` pass-through | `Money.t.sol` | 11,900,000 cold standalone |
| `exchangeBundleInForSingleOut` | `Money.t.sol` | 11,900,000 cold standalone |
| `exchangeBundleOut` | `Money.t.sol` | 11,900,000 cold standalone |
| `donate` | `Money.t.sol` | 11,900,000 cold standalone |
| `compound` | `Money.t.sol` | 11,900,000 cold standalone |
| `previewExchangeIn` for one-sided mint, one-token exit, and pass-through | `QuotesAndRate.t.sol` | 5,000,000 each |
| `previewExchangeBundleInForSingleOut` | `QuotesAndRate.t.sol` | 5,000,000 |
| `previewExchangeBundleOut` | `QuotesAndRate.t.sol` | 5,000,000 |
| `previewExchangeOut` | `QuotesAndRate.t.sol` | 5,000,000 |
| Existing buffered composed integration routes | `BufferHookIntegration.t.sol` | 12,000,000 whole transaction |
| Single row's claimed exact-input composed route or routes | `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | 12,000,000 each |
| Constant-product single row's claimed routes, including its second rate-target pool | `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | 12,000,000 each |
| Dual row's claimed routes, including its second rate-target pool | `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | 12,000,000 each |
| Orbital row's claimed face-conversion routes and second rate-target pool | `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | 12,000,000 each |
| Weighted two-leg row's claimed routes and second rate-target pool | `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | 12,000,000 each |
| Weighted three-leg row's claimed routes | `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol` | 12,000,000 each |
| Curve quad row's claimed routes and second rate-target pool | `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | 12,000,000 each |
| Balancer two-leg row's claimed routes and second rate-target pool | `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | 12,000,000 each |
| Balancer five-leg row's claimed routes | `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5.t.sol` | 12,000,000 each |

Measure both exact-input directions wherever family plan section 12 claims both. Do not use one row's measurement as evidence for another row, a second PoolKey, or the reverse direction. `setOperator` and `setOperatorFor` receive no new economic-route gas row. No measurement reads `getRate`.

### 9. Out of scope

- Do not walk `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md`, regenerate its anchors, migrate its consumers, or certify that repo-wide migration in this remediation. The family plan still requires that work; this plan neither performs nor closes it.
- Do not implement or adjudicate the remediation PRD's unresolved list. That includes the unresolved exit projection concern, the separate zero-added-liquidity concern, the named identity/partial-consumption classification concerns, share-burn allowance ambiguity, native credit receipt, and the repo-wide migration observations. Adopted F1-F11 rows remain in scope only as written.
- Do not rewrite the family plan, change other families' expected amounts, add a sibling behavior contract, alter the hook topology, or introduce a new product decision.
- This response does not implement code, run tests, deploy, or publish the coordinator's consolidated plan.

### 10. Tests

All rows below are work to add or complete and then run under later implementation authorization. They are not statements of current results. Use the family production-first TestBase, real deployed vault and PoolManager instances, and public funding routes; do not mock, etch, or inject storage into the vault or PoolManager.

| Assertion to establish | File |
| --- | --- |
| For token0 and token1 inputs strictly inside the position, a share mint spends exactly 49% in one swap, then adds; the add consumes the full swap output, any rounding remainder is only input-token remainder, the payer receives that remainder, and net shares plus fee shares follow the selected liquidity. | `Money.t.sol` |
| For one-token `donate` and `compound` strictly inside the position, the same 49% shape holds; an input-token remainder remains booked, is not refunded, and does not become share credit. Include collected-fee plus booked processing and a fresh donation arm. | `Money.t.sol` |
| At exact lower and exact upper boundaries, and outside on both sides, no swap occurs. Supplying the token the position wants permits only the direct add and refunds or books its dust; supplying the other token adds nothing and refunds or books the whole input. Cover both faces for share mint, donation, and compound. | `Money.t.sol` |
| With zero active liquidity, an unformable 49% swap, a partial or zero quote, or an add that cannot consume the quote, the candidate collapses with no swap and no add. A share mint refunds the full input and mints zero; donation or compound books the full input and refunds zero. Assert balances, shares, position liquidity, booked custody, and reserved custody. | `Money.t.sol` |
| A selected first add of 1,000 liquidity or less reverts `MinLiquidityNotMet` and mints nothing; it is not reported as a successful collapsed refund. A selected first add above 1,000 retains the floor mint and normal net-share accounting. | `Money.t.sol` |
| For requested token0 and token1 exits with nonzero direct principal, requested fees, requested booked claim, and swap proceeds, `amountOut` and the recipient balance delta equal all four components together. The caller minimum is checked against that receipt, and no opposing residual is paid, booked, or retained for the exiting holder. | `Money.t.sol` |
| An exit projection that cannot spend all opposing principal plus opposing fee and opposing booked claim reverts `AmountOutNotMet`, not `MinLiquidityNotMet`; shares are not burned and vault balances, position liquidity, booked ledger, and reservations are unchanged. A separate actual-receipt-below-minimum row has the same no-burn and atomic-rollback assertions. | `Money.t.sol` |
| From identical state, mint and one-token-exit previews match execution's `amountOut`; mint and pass-through refund words match actual unused input. A stale preview is not substituted for the settled exit receipt. | `QuotesAndRate.t.sol` |
| FS-A01 through FS-A04 assertions in section 7 are present, including every zero/code-empty case for all six infrastructure bindings, `bindingHash` sensitivity, invalid initialization contexts, the selector cut, and slot inequality. Keep the permit domain, direct-transfer, and absent `getRate`/`asset` checks; add no `exchangeRate` test. | `Package.t.sol` |
| The fixture and rows compile and run without `seBooked()` or a raw-balance substitute. Capacity declarations follow only the immediate parent's requirement and contain no gate. The weighted two-leg setup initializes two legs through its retained override, while the `_N3` row initializes three. | `SeMatrix_FullSpreadV4Fixture.sol`; the weighted two-leg and `_N3` row files named in section 8 |
| Every standalone, preview, existing composed integration, and section 12 row measurement named in section 8 records gas and satisfies its stated ceiling, with no preview warm-up and no cross-row substitution. | `Money.t.sol`, `QuotesAndRate.t.sol`, `BufferHookIntegration.t.sol`, and every row file listed in section 8 |
| Existing one-sided preview/execution, donation/compound marker, disabled-vault, bundle, and borrowed-path assertions remain intact except where the remediation changes the required error or receipt; run the related family specs to detect regressions rather than narrowing those assertions. | The seven family spec files assigned by family plan section 13 |

### 11. Traceability from each adopted remediation finding to a plan section

| Finding | Plan sections that close it |
| --- | --- |
| F1: incomplete one-token exit used the wrong error | Sections 4, 6, and 10: `Planner._exit` failure mapping, `Execution.exchangeIn` raising `AmountOutNotMet` before burn, and the explicit `Money.t.sol` regression. |
| F2: one-token exit minimum and returned amount use the recipient receipt | Sections 4, 5, 6, and 10: the four-component actual receipt, minimum and return equality, same-state preview rule, and token0/token1 assertions. This does not assert that a payout mismatch was previously observed. |
| F3: collapsed one-sided candidate could retain a swap or invalid remainder | Sections 4, 5, and 10: full candidate rejection, cleared actions, full input remainder, maintenance booking, and collapse tests. |
| F4: reviewed sizing loop was not the adopted method | Sections 3, 4, 5, and 10: one 49% exact-input candidate, one following add, no alternative sizing search, and action/remainder assertions. |
| F5: six infrastructure bindings lacked code-empty validation | Sections 3, 4, 7, and 10: constructor checks before storage and zero/code-empty package tests for each address with no usable partial vault. |
| F6: fixture exposed a raw-balance booked getter | Sections 3, 7, and 10: removal of `seBooked()` and its consumers, with no raw-balance or production-view replacement. |
| F7: fixture declared capacity functions whose parent constraint was unresolved | Sections 3, 7, and 10: immediate-parent signature check, required empty overrides retained only when necessary, and no capacity gate. |
| F8: weighted two-leg setup conflicted with older plan text | Sections 3, 7, and 10: retained two-leg `setUp`, weighted TestBase call, `_initializeWeighted(2)`, and separate three-leg setup. |
| F9: package tests omitted FS-A01 through FS-A04 | Sections 7 and 10: explicit selector-cut, binding-hash, invalid-component/initialization, and slot assertions; no `exchangeRate` test. |
| F10: money tests omitted the required exit error | Sections 6 and 10: named `AmountOutNotMet`, no-burn, and atomic-state assertions in `Money.t.sol`. |
| F11: standalone and composed gas coverage was absent from assigned files | Section 8 and the gas row in section 10: all seven standalone routes, preview ceilings, existing composed integration, and every named section 12 row file with its own whole-transaction measurement. |

### 12. Stop conditions

1. After later implementation authorization, stop the remediation successfully only when the production rules in sections 4-7 are implemented, every assertion named in sections 8 and 10 has been executed and is true, every gas value is within its stated ceiling, and F1-F11 each map to a passing named row. Do not close a row from inspection, a preview, a sampled route, or another row's result.
2. If a route exceeds a gas ceiling, stop that row as unresolved and report the route, file, measured gas, and ceiling. Do not relabel it as passing and do not change the economic rule to force it under the ceiling.
3. If a required hermetic state cannot be constructed, or a real route reverts before the named assertion, report the exact test file, route, setup, and revert. Leave the row open; do not use a mock, storage injection, a deleted assertion, or a substitute route to make it pass.
4. If implementation exposes a contradiction with a closed requirement, stop the affected edit and report the exact file, function, and conflicting sentence. Do not make a new product choice, offer an economic alternative, or reopen the lock.
5. The preview-index walk and unresolved list remain outside this remediation's completion claim. Their continued openness does not permit this plan to certify them, and completing this remediation must not mark the family plan's migration complete.
6. This research assignment stops when this owned response is written. No implementation or test result is claimed here.

## Limits

This was static, admitted-source research only. No tests, builds, installs, deployment, Git operations, sub-agents, peer reads, or edits outside this response were performed. The fingerprint was not recomputed. Current-code reads were limited to naming edit functions and are not runtime or complete-conformance evidence. This plan does not replace the family plan and does not authorize implementation.
