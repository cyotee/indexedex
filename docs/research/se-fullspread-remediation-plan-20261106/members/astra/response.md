# Astra research contribution

## Identity

- Run: `se-fullspread-remediation-plan-20261106`.
- Member: astra.
- Profile: research.
- Phase: initial independent response.
- Requested role: council-member.
- Requested model: `chatgpt-subscription/gpt-6-astra:high`.
- Actual runtime model, reasoning setting, provider/account route, and task identity: not exposed.
- Delivery: this owned response only.

## Question and targets

Write one implementation and test plan for the adopted gaps in the current `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`, without requiring another product decision. The plan amends, rather than replaces, the family implementation plan. It does not authorize implementation.

Specification fingerprint: `4f1f3204088b39e038a17154d79594be262921a231c6a01eeb33a7ee0373e8f3`, coordinator-supplied; not recomputed.

## Evidence

The following source aliases are used throughout this response:

| Alias | Source and admitted use |
| --- | --- |
| R | `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`, read in full, including the November 6 owner lock, boundary dust sentence, F1-F11, unresolved list, recommendations, and limitations. Requirements authority for these remediations. |
| B | `docs/research/se-fullspread-remediation-plan-20261106/brief.md`, read in full. Assignment scope, copied requirement law, and twelve-section plan shape. |
| P | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md`. Dependent package, sizing, exit, fixture, section 12 topology, gas, test-file, and precedence provisions. |
| F | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`. Dependent owner requirements, package and interface requirements, FS-HOOK requirements, harness law, and FS-A acceptance rows. Not a new source of remediation findings. |

Current code reads were context only, to locate the functions named in this plan. They are not a new code review, a verification of the historical review, or evidence that tests pass.

| Context file | Functions or declarations located |
| --- | --- |
| Family `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol` | `planIn`, `planBundleIn`, `planBundleOut`, `planMaintenance`, `_mintOne`, `_exit`, `_size`, `_shares`. |
| Family `UniswapV4FullSpreadStandardExchangeVaultMath.sol` | `sizeOneSided`, `_liquidityFittingOut`, `amountsToPay`, `proportional`, `claim`; the planner's call to `singleTokenAdd` was also read. |
| Family `UniswapV4FullSpreadStandardExchangeVaultExecution.sol` | `exchangeIn`, `maintain`, `_run`, `_direct`, `_locked`, `onCallback`, `_mint`, `_bookExit`, `_close`. |
| Family `UniswapV4FullSpreadStandardExchangeVaultExecutionPreparation.sol` | `run`, `settle`, `ownDeltasZero`, `_settle`. |
| Family `UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol` | Constructor, `bindingHash`, `facetCuts`, `facetInterfaces`, `processArgs`, `deployVault`, `initAccount`. |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol` | Constructor, `_deployPkg`, `hasPartialCase`, `limitCapacity`, `openCapacity`, `seBooked`. |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol` | Abstract `limitCapacity`, `openCapacity`, and `seBooked` declarations. This resolves the parent-contract dependency for F6/F7 without changing that parent. |
| Weighted two-leg row named in section 8 below | `setUp`, `_initializeWeighted`, `_newFixture`. |

The context reads locate code already expressing parts of the locked behavior, including the 49% calculation, exit-specific error mapping, six infrastructure code checks, constant-zero fixture getter, and weighted two-leg setup. This plan therefore specifies the required end state and regressions; it does not order those implementations replaced simply because the historical finding predates them.

## Assumptions

- R's November 6 lock and B's copied law are closed requirements, not proposals.
- All commands, edits, assertions, and measurements in Conclusions are instructions for a later authorized implementation task. None was executed during this research assignment.
- A failed or missing measurement is not evidence of economic correctness or compatibility. A historical finding is not proof that the same defect remains in the current source.
- Short test filenames below are the files named by R and P section 13, rather than a request to create a second suite using the older expanded filenames in F.

## Coverage

R was read completely. The two base documents were consulted for requirements on which R depends, including every section 12 row needed for F11. Code was read only for the function-level change map and the fixture-parent dependency. No peer response, readiness report, historical questions file, deleted remediation plan, preview-consumer index, or public search source was read. No tests, builds, installs, Git operations, deployment, wallets, or sub-agents were used.

## Conclusions

### 1. Authority

This is one remediation implementation and test plan for R's adopted F1-F11 gaps and its owner locks. It does not authorize implementation. It does not replace the family plan.

A later authorized implementer applies the smallest changes needed to establish the specified end state, retaining existing conforming code. The implementation sequence is: package and sizing invariants; exit accounting and error propagation; fixture preservation; targeted functional assertions; route-complete gas measurements. No step expands the unresolved list into implementation scope.

### 2. Sources and precedence

R's November 6, 2026 remediation lock wins for the gaps it names. Its earlier owner answers remain where the later lock does not replace them. B fixes this pass's scope and delivery.

P and F supply the unchanged package surface, accounting definitions, testing harness, and exact topology/file names needed by R. An older contradictory sentence about sizing, weighted setup, the exit minimum, or the withdrawn rate test is not an alternative implementation path.

The specification fingerprint is `4f1f3204088b39e038a17154d79594be262921a231c6a01eeb33a7ee0373e8f3`, coordinator-supplied and not recomputed. Code context is a locator, not authority to change these requirements. Historical question files, readiness reports, and removed plans are not requirements sources.

Path abbreviations used below:

- `C/` = `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`.
- `T/` = `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`.
- `H/` = `test/foundry/spec/hooks/uniswap/v4/standardExchange/`.
- A family Solidity basename in a function table is relative to `C/`.

### 3. Already closed product choices

The following requirement law is copied from B:

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

Apply this table as an end-state checklist. An already-conforming implementation needs a regression assertion, not gratuitous replacement.

| File and current function | Required implementation work |
| --- | --- |
| `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol::_size` | Keep the strict-interior decision, single 49% exact-input request, and one add candidate described in section 5. Return a completely cleared candidate with the original input as remainder when it collapses. Boundary handling occurs before treating zero active liquidity as a collapse. |
| `UniswapV4FullSpreadStandardExchangeVaultMath.sol::sizeOneSided`, `_liquidityFittingOut`, `amountsToPay`; `singleTokenAdd` called by `_size` | Calculate the add from the quoted post-swap state. Validate the output-consumption and input-budget conditions before subtracting to form the remainder. The no-swap boundary add consumes only the wanted token. Do not introduce a search or another swap-sizing method. |
| `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol::_mintOne`, `planMaintenance` | Schedule a swap only for an accepted candidate, followed by its add. A rejected candidate must leave no swap action in the plan. Route remainder ownership to the mint refund or maintenance booking, respectively. Keep the pre-maintenance fee collection and the both-token proportional branch. |
| `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol::_shares` and `UniswapV4FullSpreadStandardExchangeVaultExecution.sol::exchangeIn` | Enforce the explicit first-deposit floor even for zero added liquidity. A first deposit adding at most 1,000 liquidity fails with `MinLiquidityNotMet`; an established-vault collapsed mint can return zero shares and the input subject to its existing minimum. Do not let a zero-liquidity early return bypass the lock. This is the explicit collapse qualification, not adoption of the unresolved diagnostic as an additional project. |
| `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol::_exit` | Retain pre-burn apportionment and the all-unwanted-token requirement. Keep the planner's exit-failure result distinct in meaning from an entry liquidity failure. The preview amount remains the full expected receipt. |
| `UniswapV4FullSpreadStandardExchangeVaultExecution.sol::exchangeIn`, `_run`, `_direct`, `_locked`, `onCallback` and `UniswapV4FullSpreadStandardExchangeVaultExecutionPreparation.sol::run` | Carry the actual exit swap consumption and proceeds from the manager action through the existing locked/direct action result path. Incomplete consumption must reach `AmountOutNotMet`, not `MinLiquidityNotMet`. Enforce the minimum on the actual complete receipt before burning and paying. If internal callback result encoding changes, update its encoder and both decoders together; do not change the public exchange tuple or callback selector. |
| `UniswapV4FullSpreadStandardExchangeVaultExecution.sol::_bookExit`, `_close` | Deduct only the exiting booked claims and retain other holders' fee remainder. Keep reservations cleared and the existing settlement checks at return. Do not book an incomplete opposing exit residual as a successful exit. |
| `UniswapV4FullSpreadStandardExchangeVaultExecution.sol::maintain` | After the accepted maintenance actions, book the actual held remainder, including boundary dust and collapsed processed input. Do not refund a processed donation/compound remainder. Preserve the distinct funding/pretransfer checks and event rules; this is not authority to rewrite those contracts. |
| `UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol::constructor` | Require code for all six named infrastructure bindings before assignment. Keep the existing component, linked-library, and selector validation. No new constructor field, mutable setter, or fallback address. |

The receipt change uses the existing settlement engine on both unlock paths. Retain one unlock per manager action on the locked path, no nested unlock on the borrowed path, and the guard across the operation. No additional public getter or economic state ledger is needed.

For F5/F9, `facetCuts`, `facetInterfaces`, `bindingHash`, `processArgs`, `deployVault`, and `initAccount` are the current package assertion targets. This plan does not prescribe a package redesign.

Sources: R F1-F5 and owner lock; P sections 4, 6-10; F FS-OWN-11, FS-OWN-30 through FS-OWN-33.

### 5. One-sided size, including the boundary and the collapsed candidate

Define `A` as the processed amount of the input token. For a funded one-sided mint, this is the amount admitted by the existing funding rule. For one-token maintenance, it is the combined one-token booked balance, collected fees, and admitted donation amount. Do not apply this sizing rule to bundle deposits, pass-throughs, one-token exits, or maintenance that already holds both tokens.

**Boundary decision.** Compare the current square-root price against the stored position endpoints. Strict interior means `sqrtA < sqrtPrice < sqrtB`. Equality with either endpoint is outside that branch.

- At or below the lower endpoint, the position wants currency0.
- At or above the upper endpoint, the position wants currency1.
- If the supplied token is wanted, perform only its no-swap add and calculate the unused input from the actual add requirements.
- If it is not wanted, select no swap and no add; the whole processed input remains.
- On a share mint, refund the unused input to `msg.sender`, not `recipient`; do not book or mint it. On maintenance, keep it booked and do not refund it. The same rule applies to dust from the wanted-token add.

**Interior candidate.** Form the exact-input request with overflow-safe `floor(A * 49 / 100)` in native token units. There is one balancing quote and one candidate add, not repeated attempts. Use the existing unbounded price limit. Quote projection may follow the pool's real swap behavior; it must not vary the selected fraction or walk ticks to select a different split.

The add is calculated at the quoted post-swap price. Let `s` be the input the projected swap actually consumes, `o` its output, and `dIn`/`dOut` the rounded-up amounts the candidate add requires. Accept only a usable candidate for which:

- The liquidity is nonzero and representable.
- `s <= A`, `dIn <= A - s`, and `dOut == o`.
- The swap output is consumed by the add. The remainder is exactly `A - s - dIn`, in the original input token only.

The requested swap budget is the fixed 49% amount; an existing partial exact-input result is not a reason to introduce an entry `IncompleteConversion` check or another sizing attempt. It still must satisfy the add-consumes-output condition. Computing liquidity that can consume a returned amount is add arithmetic, not permission to size an exact-output swap.

**Collapse.** Zero active liquidity inside the position is a collapse case, not a boundary add. A zero/unformable swap, an unusable add, or an add that cannot consume the output returns the clean no-action candidate: zero swap input, zero swap output, zero added liquidity, zero consumed add input, and remainder `A`. Do not retain an earlier candidate's action, subtract rejected amounts, or execute a swap and then refund the original amount from other holders' funds.

An established-vault mint returns zero shares and refunds `A` if its minimum allows zero output; a positive minimum retains `AmountOutNotMet`. A first deposit with added liquidity at most 1,000 instead reverts `MinLiquidityNotMet`, including the zero-liquidity candidate. No floor or fee shares are minted on that failure. Maintenance books `A` and does not refund it.

Keep `Donation()` for a successful donation even when no add occurs. Do not emit `Compounded()` without an actual deposit of collected fees or booked tokens. Empty compound still changes nothing and emits nothing. A fee-collection action that precedes a collapsed maintenance candidate is not a retained balancing swap.

Sources: R owner lock and F3/F4; F FS-OWN-14, FS-OWN-21, FS-OWN-30, FS-OWN-32, FS-OWN-33; P sections 2 and 9.

### 6. One-token exit receipt and the incomplete-exit error

Take `S = supplyBeforeBurn` and `b = sharesBurned`. The floor is included in `S`. Before any burn, compute:

- Liquidity removed: `floor(positionLiquidity * b / S)`.
- Fee claim for each token: `floor(unpaidFees[i] * b / S)`.
- Booked claim for each token: `floor(booked[i] * b / S)`.

Multiply before dividing. Previously booked fees belong only in the booked term; do not also count them as unpaid.

For requested token `w` and opposing token `u`, the unwanted swap input is the holder's withdrawn `u` principal plus the `u` fee claim plus the `u` booked claim. Swap all of that claim. Do not sell another holder's inventory. A zero unwanted claim requires no swap.

The successful recipient receipt is:

```text
receipt =
    actual requested-token swap proceeds
  + withdrawn requested-token principal
  + holder's requested-token fee claim
  + holder's requested booked claim
```

Obtain actual consumption/proceeds from the manager's swap result in `ExecutionPreparation.run`, rather than treating a planned quote as execution evidence. Thread that result through `_direct` or the `_locked`/`onCallback` result and aggregate it in `_run`. Preserve fee-return bookkeeping. The internal result can be extended without changing any public return signature.

The existing requested-token balance-growth calculation in `exchangeIn` can remain the settlement reconciliation: subtract the collected requested-token fees belonging to staying holders from the operation's requested-token growth, and add the exiting requested booked claim already held before the operation. Reconcile this with the four receipt terms. Raw vault balance alone is not the receipt; it includes inventory the caller does not own.

Before burning:

1. A planner-detected inability to consume the unwanted claim raises `AmountOutNotMet`.
2. Actual unwanted consumption must equal that claim. Any opposing residual raises `AmountOutNotMet` even if `minAmountOut == 0`.
3. The complete actual receipt must satisfy `minAmountOut`. Otherwise raise `AmountOutNotMet`, carrying the actual output for an ordinary minimum miss.
4. Only after these checks burn the caller's shares, pay the receipt to `recipient`, and return that same amount as `amountOut`.

A reverting incomplete exit rolls back removal, settlement, token changes, booked changes, and the burn. Do not convert this failure into a refund, a residual booking, a partial payment, or a new error. The rule is identical on locked and borrowed `exchangeIn`.

Other holders retain their booked balance minus only the exiting share and receive their portion of newly collected fees in booking. Their inventory is not available to repair a shortfall. Both-token exits remain no-swap claims.

Test the formula against actual recipient balance changes, with a recipient distinct from the caller and with both requested tokens. Preview equality is checked from the same economic state. A quote obtained before a real intervening trade is not an execution receipt.

R F2 reports use of the planned amount; it does not report an observed quote-versus-pool payout mismatch. The regressions establish the new receipt guarantee without claiming that historical mismatch occurred.

Sources: R F1, F2, F10 and exit lock; F FS-OWN-30 and FS-A08; P sections 6, 8-10.

### 7. Package and fixture assertions

**Package, in `T/Package.t.sol`.**

- FS-A01: inspect the exact package cut and exercise the installed selector manifest through the registry-created proxy. Confirm shared token, permit/domain, standard-vault, money, preview, out, query, Protocol Aware, and SinglePositionAware surfaces are on their intended facets. `vaultTokens` is the basic-facet contribution; the query facet contributes only `reserveOfToken` and `reserves`. No duplicate family manager/key getter is installed. Factory ERC-165, ERC-8109, and loupe behavior remains available as specified. The temporary post-deploy hook is removed from the finished proxy. Keep `getRate` and `asset` absent.
- FS-A02: mutate each `PkgInit` field independently, including every facet, each of the six linked-library entries, and every infrastructure binding, and assert a changed `bindingHash`. Use valid alternative bindings where deployment is involved so a rejection is not mislabeled a hash proof. Do not add an input field.
- FS-A03: cover zero and nonzero code-empty values separately for each of the six named infrastructure fields. Assert `InvalidComponent` and no usable partial deployment. Retain component-code, linked-component mismatch, and forbidden-cut negatives. Also assert the existing errors for an uninitialized/hooked pool, a second initialization, a wrong `processArgs` caller, the right registry in the wrong account, and a mismatched initialization context. Do not introduce a tick-spacing rejection.
- FS-A04: assert the exact family storage namespace differs from the actual PairToken and Wings namespaces. Use their declared namespace constants in the later test implementation, not guessed comparison values or storage injection.
- Keep generated-name permit-domain coverage and the existing absent-rate surface coverage. Do not add an `exchangeRate` assertion or an issuance-does-not-read-`exchangeRate` test. F's withdrawn FS-A16 is not a missing test to restore.

**Fixture, in `H/SeMatrix_FullSpreadV4Fixture.sol`.**

The read parent `SeMatrixFixture` requires `seBooked`, `limitCapacity`, and `openCapacity`. Retain the existing constant-zero `seBooked()` override as an interface accommodation, not a measurement of actual booked funds. Do not return an ERC-20 balance, inspect storage through it, or add a production booked getter. Tests must not cite its zero as proof that booked funds are zero.

Retain the empty `limitCapacity(uint256)` and `openCapacity()` overrides because this parent requires them. Do not add a sleeve capacity gate. Preserve `hasPartialCase() == false`; it is not a reason to skip the row-specific refund assertions already assigned by the family plan.

Do not change the parent or other families merely to remove the three declarations. If a later parent version no longer requires an override, removing that unused compatibility declaration is mechanical; the product rule remains no capacity gate and no reported booked balance.

**Weighted row.**

In `H/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`, keep `setUp()` calling `TestBase_UniswapV4StandardExchangeWeightedBufferHook.setUp()` and then `_initializeWeighted(2)`. Verify that the configured row actually has two legs and the specified providers, roles, and weights. Keep the separately named `_N3.t.sol` row's `n == 3` setup. Do not substitute one row's measurement for the other.

Sources: R F5-F9 and owner answers; B fixture law; P sections 4, 5, 12, 13; F FS-A01 through FS-A04.

### 8. Gas measurements, naming each route and file

Gas closure is route-complete, not sampled. Each row below receives a separately identifiable measurement and assertion. Test setup, balances, approvals, and bootstrap are prepared outside the measured standalone body. A fresh transaction/access context must make the measured route cold; pausing a gas meter does not reset warmed accounts or storage. Do not call previews or route-dependent getters to prepare the measurement in that same context.

Measure the public diamond entry through return, including its internal calls, settlement, transfers, and events. Assertions and diagnostic reads follow the measurement. For composed routes, measure the whole outer transaction through final settlement, including hook work and all nested vault work; do not sum isolated vault body measurements. Use transaction gas accounting that includes the transaction overhead for the 12,000,000 ceiling. Record the coldness/isolation method with the result. For previews, measure the complete public preview call separately, with no preceding warming call.

**Standalone: each body at most 11,900,000 gas, in `T/Money.t.sol`.**

| Measurement ID | Exact route to measure |
| --- | --- |
| G-S1 | `exchangeIn(face, amount, share, ...)`: productive one-sided share mint. |
| G-S2 | `exchangeIn(share, amount, face, ...)`: one-token exit, including removal and conversion of the opposing claim. |
| G-S3 | `exchangeIn(face0, amount, face1, ...)`: pass-through. |
| G-S4 | `exchangeBundleInForSingleOut`: accepted two-face bundle deposit. |
| G-S5 | `exchangeBundleOut`: both-token exit. |
| G-S6 | `donate`: funded productive maintenance, not just a no-op marker. |
| G-S7 | `compound`: nonempty productive maintenance, not only the empty fast path. |

Exercise the supported token directions and material branches of those routes: first and later mint, requested-token exits in both directions, one-token and both-token maintenance, fee collection where owed, and accepted funding variants. Boundary/collapse measurements supplement rather than replace a productive measurement. `setOperator` and `setOperatorFor` are not economic routes in this table.

**Previews: each at most 5,000,000 gas, in `T/QuotesAndRate.t.sol`.**

Measure `previewExchangeIn` separately for mint, exit, and pass-through, plus `previewExchangeBundleInForSingleOut`, `previewExchangeBundleOut`, and the unsupported `previewExchangeOut` zero-result path. Record both relevant token directions and caller-order cases. No `getRate` read is part of a gas measurement. Functional preview checks may run in other tests; they do not warm these measurements.

**Composed: each whole transaction at most 12,000,000 gas.**

`T/BufferHookIntegration.t.sol` owns the composed gas acceptance ledger. Each of the following P section 12 row files owns a separately named measured case using its real topology. Reuse its setup rather than constructing a replacement topology solely for a lower gas figure. A shared measurement helper may carry the same assertion, but it must execute each listed row.

All paths below are relative to `H/`:

| ID | Exact file | Required measured composition |
| --- | --- | --- |
| G-C1 | `single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | Face/share exact-input mint and burn directions on this one-vault topology. No invented rate-provider field. |
| G-C2 | `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | Face/raw exact-input both directions, with the currency0 and currency1 target pools and the required face-index placements. |
| G-C3 | `dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | Canonical FullSpread/PairToken-identity composition, both exact-input directions, both rate-target pools, and both required face-index placements. |
| G-C4 | `orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | Three-leg setup: both directions on face/PairToken and face/raw pairs, both rate-target cases and required pair-index placements; retain the other pair as its transfer control. |
| G-C5 | `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | Two legs, face/raw both directions, both target pools and required index placements. Keep the two-leg setup override. |
| G-C6 | `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol` | Three legs, face/raw and face/PairToken both directions, with currency0 provider and sorted whole records. Do not substitute the two-leg result. |
| G-C7 | `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | Four legs, face/PairToken and face/first-sorted-raw both directions, including the second rate-target pool. |
| G-C8 | `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | Dynamic two-leg face/raw setup, both directions, both target pools and required index placements. Assert the two-leg identity before measurement in setup. |
| G-C9 | `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5.t.sol` | Dynamic five-leg setup, face/PairToken and face/first-sorted-raw both directions, with currency0 provider. Do not substitute the two-leg result. |

A measured revert does not establish the gas of a successful route. Preserve P's distinction between supported exact-input success, intentional exact-output rejection, and FS-HOOK-04 integration rejection. If the prescribed PairToken identity bind is rejected, record consumer, selector, arguments, and revert; mark that composed measurement blocked. Do not replace it with another FullSpread instance or a raw token and call the canonical route measured. Independent prescribed raw-leg measurements still proceed.

For each G-S/G-C/preview case record file, test identifier, route direction, topology/leg count, provider target, product index where relevant, input/state description, measured gas, threshold, and coldness method. An oversized route is unresolved, not passed. Do not raise a ceiling, omit a row, warm the test, or alter the 49% rule to obtain a green result.

Sources: R F11 and gas owner answer; P sections 2, 12, 13; F FS-A31.

### 9. Out of scope

This pass does not walk the preview-consumer index and does not certify or close its migration. The family plan still requires that migration. Running scoped tests or measuring an external provider is not evidence that all consumers were migrated.

R's entire unresolved list remains outside this implementation plan: the unadopted exit-projection diagnosis; the earlier untraced floor diagnosis apart from the explicit first-deposit lock implemented above; unadopted identity/partial-consumption and compatibility-classification findings; the other unadopted member findings; share-burn allowance interpretation; native-credit receipt diagnosis; repo-wide return migration; and stale index anchors. These are not new work items or new product requirements.

Do not redesign hooks, add `asset` to make a bind pass, add rate components to this vault, change the public ABI, introduce a sleeve/capacity gate, edit other families' behavior expectations, or create another sizing method. The composed measurements preserve the family plan's prescribed topology; a blocker is reported rather than solved by an unrequested hook or other-vault change.

This plan does not certify the complete family implementation, all historical acceptance rows, or all audit inventory items. It closes only its adopted remediation rows with the evidence below.

### 10. Tests

Use the existing production-first family TestBase and real registry/package/facet deployment. Bootstrap through accepted public routes. The vault, PoolManager, registry, package, and fee oracle are not mocked, etched, subclassed substitutes, or storage-injected SUTs. Use accepted funding tokens and normal pool operations to construct states. Do not add a production inspection getter just to make an assertion convenient.

The following labels name planned assertions, not existing test names or passing results:

| Assertion ID | File | Required assertion |
| --- | --- | --- |
| T-P1 | `T/Package.t.sol` | Exact package cut and proxy-callable manifest, intended facet ownership, factory-selector disjointness and temporary-hook removal, plus the required absent `getRate`/`asset` surface; FS-A01. |
| T-P2 | `T/Package.t.sol` | Each binding changes `bindingHash`, including all six library indices and all infrastructure fields; FS-A02. |
| T-P3 | `T/Package.t.sol` | For each of the six infrastructure fields independently: zero and nonzero code-empty addresses produce `InvalidComponent`, with no usable partial deployment. Include valid-code control. |
| T-P4 | `T/Package.t.sol` | Remaining FS-A03 invalid-component, linked-binding/cut, pool-key, caller/context, and double-initialization negatives with the specified errors and no partial usable vault. |
| T-P5 | `T/Package.t.sol` | Family namespace differs from both actual comparison-family namespaces; FS-A04. Preserve the permit/domain coverage. |
| T-S1 | `T/Money.t.sol` | For each input face in strict interior, the selected swap request is `floor(A*49/100)`; accepted execution consumes its output in the add. Actual input spent plus refunded equals the admitted input; no opposing swap-output dust is donated or booked. |
| T-S2 | `T/Money.t.sol` | Established-vault collapsed mint: zero shares, full processed-input refund, no retained swap or add, no fee mint, no booked increase attributable to that refund. Test dust and add-output-consumption rejection without changing the SUT. |
| T-S3 | `T/Money.t.sol` | First-deposit added liquidity of zero and at most 1,000 raises `MinLiquidityNotMet`, restores funds, and creates no floor/supply. An above-floor control creates the specified floor and net/fee issuance. Include a zero-active-liquidity interior setup as a collapse, not a boundary add. |
| T-S4 | `T/Money.t.sol` | At each exact boundary and on each exterior side: wanted input uses a no-swap add and refunds unused mint input; other-token input is fully refunded with no swap/add. Established-vault positive minimum still binds. |
| T-S5 | `T/Money.t.sol` | `donate` and `compound`, separately, book wanted-token boundary dust, whole wrong-token boundary input, and collapsed processed input; no payer refund. Accepted interior one-token maintenance follows 49%; both-token maintenance does not swap. |
| T-S6 | `T/Money.t.sol` | Successful zero-add donation emits only the applicable marker; zero-add maintenance does not claim a compounded deposit. Empty compound changes no state and emits nothing. Later valid maintenance or a holder exit accounts for the booked remainder, rather than relying on `seBooked()`. |
| T-E1 | `T/Money.t.sol` | Requested receipt equals actual recipient increase and returned `amountOut`, with independently calculated principal, unpaid-fee claim, booked claim, and actual swap proceeds. Test both requested tokens and a distinct recipient. |
| T-E2 | `T/Money.t.sol` | A minimum between the swap-proceeds-only value and the full receipt succeeds when the full receipt satisfies it. A minimum equal to the receipt succeeds; one above it raises `AmountOutNotMet` and restores state. This distinguishes the locked receipt basis from proceeds alone. |
| T-E3 | `T/Money.t.sol` | A nonzero unwanted claim that cannot be completely swapped raises `AmountOutNotMet` even with minimum zero. Caller shares and total supply are unchanged; principal removal, fees, booked claims, token transfers, and manager deltas roll back. It must not raise `MinLiquidityNotMet`. |
| T-E4 | `T/Money.t.sol` | With multiple holders and both unpaid fees and preexisting booked funds, only the exiting claims are consumed; other holders' fees/remainders remain accounted for and are not swapped. No double counting of previously booked fees. |
| T-E5 | `T/AlreadyUnlocked.t.sol` | Run the receipt and incomplete-consumption assertions through real self-funded borrowed `exchangeIn`, with no nested unlock. Propagated failure restores the operation; caught inner failure restores the vault while leaving the outer caller responsible for its own deltas. |
| T-Q1 | `T/QuotesAndRate.t.sol` | Same-state previews and execution agree on net mint output and complete exit receipt in both directions. Boundary and collapse preview outputs are coherent and do not invent a view revert. Do not require execution refund-word equality where F's funding rule explicitly permits a difference. |
| T-Q2 | `T/QuotesAndRate.t.sol` and `T/Money.t.sol` | Obtain a quote, perform a real intervening pool trade, then execute. Assert the current receipt and caller minimum, not a cached quote payout. This is a new-state minimum test, not a claimed historical quote/pool mismatch. |
| T-F1 | `T/BufferHookIntegration.t.sol` | With nonzero face custody on the fixture's vault, its required `seBooked` accommodation still does not report that custody. No test uses that accommodation as proof of the ledger. Capacity calls remain empty and do not affect a later real route. |
| T-F2 | Weighted two-leg and `_N3.t.sol` files in section 8 | Setup produces the respective two-/three-leg configuration; two-leg setup retains the explicit base call and `_initializeWeighted(2)`. Measurements and assertions cannot silently run at the other count. |
| T-G1 | `T/Money.t.sol` | All G-S1 through G-S7 measurements satisfy their unchanged ceiling, each in a demonstrably cold context. |
| T-G2 | `T/QuotesAndRate.t.sol` | Every preview case in section 8 satisfies 5,000,000 gas without a warm-up call. |
| T-G3 | `T/BufferHookIntegration.t.sol` and all nine exact row paths in section 8 | Separate whole-transaction measurement for every prescribed supported composed case; an oversized or rejected route remains unresolved/blocked, not counted as passing. |

Use functional state construction, not a mocked swap return, to trigger collapse and incomplete conversion. Seed external liquidity for the productive exit controls; use a real pool state that lacks enough executable opposing liquidity for the incomplete-exit negative. If a proposed deterministic state cannot be constructed through public routes, report the specific blocked assertion rather than fabricating it with storage writes.

For rollback tests record pre-state before the attempted call and compare post-state before any snapshot restoration: caller/recipient balances, supply and shares, position liquidity/identity, both face balances, and this diamond's manager deltas. Use externally observable claim payouts and later maintenance to substantiate booked ownership without adding a booked getter. Manager events can corroborate swap/add attribution; log presence alone is not the recipient receipt or the rollback proof.

Targeted fuzzing varies processed input, token direction, supported pool fee/spacing, and current price across these already-closed branches. Assert integer conservation, output consumption, the floor, and receipt/minimum behavior. A bounded fuzz run is evidence for the exercised domain, not a universal claim. No sleeps or timing-dependent state preparation.

For the later authorized execution, build affected production artifacts with Solar before running the assigned tests because FactoryServices load creation bytecode from `out/`. Follow the repository's artifact-aware scoped test workflow; keep the configured test roots stable. All compiling Forge invocations use `--use solar`, the hermetic default profile, and no `via_ir`. Run the family files and all nine named composed row files, recording command, exit status, and results. Do not call this research response a test run.

### 11. Traceability from each adopted remediation finding to a plan section

| Adopted finding | Operative resolution | Plan sections | Evidence rows |
| --- | --- | --- | --- |
| F1 | Incomplete exit is `AmountOutNotMet` with no burn. | 4, 6, 10, 12 | T-E3, T-E5. |
| F2 | Minimum, payment, and returned amount use the actual complete receipt; no assertion that a historical mismatch was observed. | 4, 6, 10 | T-E1, T-E2, T-E4, T-E5, T-Q1, T-Q2. |
| F3 | Clear collapsed candidates completely; refund mint input or book maintenance input; preserve explicit first-deposit floor. | 4, 5, 10 | T-S2 through T-S6, T-Q1. |
| F4 | Apply November 6 fixed 49% law with boundary and collapse handling; no restored sizing method. | 3-5, 10 | T-S1, T-S4, T-S5, T-Q1. |
| F5 | Six code checks before storage and `InvalidComponent`; no partial usable deployment. | 4, 7, 10 | T-P3, T-P4. |
| F6 | Fixture must not report a balance through `seBooked`; parent-required constant accommodation is not a ledger view. | 7, 10 | T-F1; maintenance/claim accounting in T-S5, T-S6, T-E4. |
| F7 | Preserve parent-required empty capacity overrides; no capacity gate. | 7, 10 | Parent-declaration context and T-F1. |
| F8 | Keep explicit weighted two-leg setup; retain separate three-leg setup. | 7, 8, 10 | T-F2, G-C5, G-C6. |
| F9 | Add/retain complete FS-A01-A04 assertions; no withdrawn rate test. | 7, 10 | T-P1 through T-P5. |
| F10 | Put the exit-error regression in the assigned money file. | 6, 10 | T-E3 in `T/Money.t.sol`, with borrowed counterpart T-E5. |
| F11 | Seven standalone routes, every named composed row, and preview measurements at unchanged ceilings. | 8, 10, 12 | G-S1-G-S7, G-C1-G-C9 and preview cases; T-G1-T-G3. |

The November 6 boundary-dust sentence is implemented in sections 5 and 10, including both maintenance functions. Migration exclusion and the entire unresolved-list exclusion are section 9. Neither exclusion can be marked closed by the rows above.

### 12. Stop conditions

For the later authorized implementation task, stop successfully only when all of these are established by recorded evidence:

1. Sections 4-7 have the specified end state, with already-conforming code preserved and no forbidden surface or alternative sizing path introduced.
2. T-P1 through T-P5 establish FS-A01-A04 and the six infrastructure negatives without restoring a withdrawn test.
3. T-S1 through T-S6 and T-Q1 establish interior sizing, exact-boundary/exterior behavior, collapse, refund-versus-booking ownership, and the first-deposit exception.
4. T-E1 through T-E5 establish complete actual receipts, minimum enforcement, full opposing-claim conversion, and rollback on both unlock paths.
5. T-F1/T-F2 establish the fixture accommodations and both weighted setup counts without a capacity gate or a reported booked balance.
6. Every standalone, preview, and named composed measurement is recorded against its unchanged ceiling, with supported topology/direction/target cases identified and coldness demonstrated.
7. The relevant artifact build and specified tests finish with recorded successful results. No failing or missing row is silently removed, relabeled, or substituted.
8. The completion report explicitly leaves the preview-consumer migration and R's unresolved list unclosed.

If a named blocker prevents one of those conditions, complete the independent work and stop with that blocker rather than claiming remediation completion. Blocker records identify the exact source/file, assertion or gas row, reproducible condition, observed error or measured gas, affected dependent rows, and completed unaffected rows. Named blockers are:

- **B-AUTH:** no later instruction authorizes implementation or test execution. This research response is not that instruction.
- **B-BUILD:** the required artifact build or scoped test compilation fails; preserve the actual command and diagnostics.
- **B-STATE:** a necessary collapse/incomplete-exit test state cannot be constructed through the accepted public harness without changing the SUT or weakening the assertion.
- **B-GAS:** a measured supported route exceeds its fixed ceiling, or a measurement cannot establish the required cold/whole-transaction accounting.
- **B-HOOK:** the prescribed composed route is rejected by an existing consumer, including an unavailable identity bind; record FS-HOOK-04 particulars and do not substitute a different topology.
- **B-SCOPE:** closing a named row would require a preview-index migration, hook redesign, other-family change, or another unresolved item outside this plan.

These are reporting conditions, not unanswered product choices or permission to change the requirements.

For this council-member assignment, stop after writing this owned response. Do not implement the plan, run its checks, or publish the coordinator's final artifact.

## Limits

This is an independent research contribution and proposed implementation/test plan, not a Review findings report, an implementation, or a test-pass claim. The fingerprint is supplied provenance, not a locally computed identity check. Runtime identity beyond the requested member/role/model was not exposed.

No peer responses were read. No project code, PRD, family plan, coordinator artifact, or other member file was edited. The plan neither replaces the family plan nor authorizes implementation. The preview-consumer migration and R's unresolved list remain outside this pass.
