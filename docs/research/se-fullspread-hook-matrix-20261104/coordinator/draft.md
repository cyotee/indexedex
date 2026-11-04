# Draft

- Draft ID: draft-se-fullspread-hook-matrix-20261104-r1
- Run ID: se-fullspread-hook-matrix-20261104
- Question: complete the hook-matrix in the published plan
- This draft does not authorize implementation

## Rejected alternatives

These are names, not open choices.

- Sibling behavior contracts. The PRD adds a row beside each live behavior. The `.t.sol` row overrides `setUp` where the inherited setup cannot express the bind. It does not edit the seven behavior contracts.
- A second instance of this vault as the other SE. FS-HOOK-02 item 5 says a both-buffered composition is not the required proof.
- `SeMatrix_FullSpreadV3Fixture` as the other SE. FS-HOOK-02 item 2 names current PairToken as the family that rejects the outer unlock.
- A rate-provider field added to `single/`. That package has no such field. FS-HOOK-01 forbids a new hook-package field.
- `hasPartialCase() == true` as a way to book the user's unused input. Unused declared user input is refunded. A donation or compound remainder is a separate booked case.
- A PoolManager or vault `vm.mockCall`. Plan section 13 forbids mocking either.

## Replacement for plan section 12

Replace section 12 with the following text.

## 12. Hook integration and migration

Add one row file beside each live behavior below. Copy the Uniswap V3 full-spread row shape: one contract, `sharedPkg` where the V3 row uses it, and `_newFixture()` returning `new SeMatrix_FullSpreadV4Fixture(_ctx(), sharedPkg)`. Do not add a sibling behavior contract. Do not edit the seven behavior contracts. Do not weaken their other-family assertions. Do not copy V3 row comments that say full-spread exact-out delivers the previewed amount.

The one fixture file is `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol`. It follows `SeMatrix_FullSpreadV3Fixture.sol` except for this family's package, pool, and refund tuple.

- Package: deploy this vault through `UniswapV4FullSpreadStandardExchangeVault` and the bound IndexedEx registry. Not the V3 package. Not `exchangeInManyToOne`. Not `setLiquidReservePercentageOfVault`, `localReserve`, or `deployedReserve`. Bootstrap is one bundle deposit of both faces through this vault's public bundle route.
- Pool: one bound hookless PoolKey, hook `address(0)`, initialized on the bound PoolManager. Not a Uniswap V3 3000-fee pool.
- Refund tuple: `previewExchangeIn` and `exchangeIn` return `(uint256 amountOut, uint256 amountRefunded)`. The fixture and the rows read `amountOut`. The refund word is not output and is not shares. `previewExchangeOut` returns zero. `exchangeOut` reverts `ExchangeOutNotAvailable()`.

The fixture deploys this vault, that hookless pool, the two face tokens, and the external rate-provider instances. The two faces are the PoolKey currencies in `currency0`, `currency1` order, with WETH substituted for native at the boundary. Hermetic mintable faces are sorted so `currency0` is the lower address. `faceToken()` on the primary rows is `currency0`. `otherToken()` is `currency1`.

Deploy two `IStandardExchangeRateProviderDFPkg` instances against the same vault:

- `currency0` provider: `reserveVault` and `rateSubject` are this vault. `rateTarget` is `currency0`.
- `currency1` provider: the same vault. `rateTarget` is `currency1`. It does not deploy a second vault.

This vault stores no provider and does not implement `getRate()` or `asset()`. The fixture does not add a booked getter and does not `vm.load`, etch, or mock this vault or the PoolManager. A refund assertion is the returned `amountRefunded` and the recipient balance. A donation or compound remainder is observed by the maintenance result and balances, not by a new getter.

Index rule. For a currency-sorted pair, `index(X)` is 0 when `X` is the lower address, otherwise 1. `zeroForOne` spends currency 0. `oneForZero` spends currency 1. For an ascending array, sort the whole token, SE, provider, and weight record together. `index(X)` is that record's rank. This vault's share is a PoolKey currency only in `single/`. In every other family the share is buffered inventory on the face leg. It is not a pool currency.

Other SE. Where a topology names another Standard Exchange, deploy one PairToken vault through `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultDFPkg.sol`, using that family's existing package test setup as the deployment pattern. Do not construct it with `SeMatrix_FullSpreadV4Fixture` or `SeMatrix_FullSpreadV3Fixture`. Acquire its shares before the outer unlock. The hook leg token is that share. During the outer unlock the hook does not call that vault's `exchangeIn`, `exchangeOut`, or bundle routes. If the current package rejects `token == se` without `asset()`, record the consumer, selector, arguments, and revert under FS-HOOK-04 and do not pass that identity variant. Do not add `asset()`. That record does not close FS-A26 and does not close the FS-OWN-29 rows. The runnable proof is the share transfer the hook accepts without calling that vault. Do not replace that leg with a second instance of this vault.

Common adaptation, every topology. The row overrides these inherited tests. Exact-out success cannot pass.

- `test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed` expects the revert, or a zero `previewExchangeOut`, and does not assert a delivered amount.
- `test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly` uses the same adaptation.
- The exact-out half of `test_row_poolManagerSwap_bothDirections_noFaceResidual` reverts and pays neither token. The exact-in half stays.

`test_row_partialConsumption_bookedNotRefunded` cannot pass its booked-not-refunded body. Unused declared user input is refunded to `msg.sender` and is not booked. When the hook calls `exchangeIn`, `msg.sender` is the hook. Trace that refund to the entitled caller. Do not relabel it as booked inventory. Do not delete the test. Do not make it pass by booking the refund. Include a no-refund control.

Donation and compound remainders are booked, so those rows stay. None of these seven behavior files contains `donate` or `compound`. Do not delete a booked-remainder assertion that is not in the file. Do not use the user's unspent input as the donation remainder. Do not call `donate` or `compound` inside the outer unlock.

`test_row_seFailure_rollsBack` cannot use the V3 `pool.mint` mock. The row overrides it. Force `AmountOutNotMet` on an exact-input call whose minimum is above the quote. Assert shares, face balances, and the vault's face balance unchanged. Do not `vm.mockCall` this vault or the PoolManager.

Do not call `_mintSeSharesTo`. It uses `exchangeOut`. Seed shares with exact-input `exchangeIn`. In `test_row_previewMatchesExecution`, the `previewExchangeOut` equalities cannot pass as a positive quote. `previewExchangeOut` returns zero. The exact-in `previewExchangeIn` equalities stay and read `amountOut`.

One-word `previewExchangeIn` comparisons in inherited bind tests read `amountOut` after the migration below. That decoder change is not permission to change other families' expected amounts.

Disjoint PoolKey rule, every topology. The hook product PoolKey and this vault's backing PoolKey are different keys. The backing key has hook `address(0)`. Where the currency1 test builds a second hook pool, that pool is a second product PoolKey, it holds the same vault, and it is not the backing PoolKey. PairToken's backing pool is not this vault's backing PoolKey. Same-backing-pool sequential composition stays unverified. These rows do not pass it.

The canonical cross-vault proof is the `dual/` row below. A PairToken leg on another topology does not replace it. `single/` is not a two-vault proof.

### Single

Behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol`

Row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`

Fixture: the one fixture. It deploys this vault, the hookless pool, the two faces, and the two provider instances. The single package has no rate-provider field. The row does not add one. There is no currency1 hook row on this topology. FS-OWN-29's both-target proof is not this row.

Hook-pool indices. The PoolKey is the address-sorted pair of the face and this vault's share. `index(share)` is 0 when the share is the lower address, otherwise 1. The face is the other index. There is no raw leg and no second SE leg.

Directions. Exact-input face to share mints while unlocked. Exact-input share to face burns while unlocked. Those two calls are `zeroForOne` and `oneForZero`. Exact-out is not a direction.

This is not a two-vault proof. This vault is the only SE.

### Constant-product single

Behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol`

Row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`

Fixture: the one fixture, plus one raw 18-decimal token that is neither face and is not this vault's share. Primary `setUp` binds the `currency0` face as `pairToken` and the `currency0` provider as `rateProvider`. The second case in this same file is `test_row_rateTarget_currency1`. It keeps the same vault, uses the `currency1` provider, and deploys a second hook pool whose pair token is `currency1`. That second pool is not a second vault.

Hook-pool indices. Currencies are the face and the raw token, address-sorted. This vault's share is not a pool currency. The share-bearing index is the currency index of the face: `standardExchangeOf(face)` is this vault and that leg is buffered. The other index is the raw token: `standardExchangeOf(raw)` is `address(0)`. The face leg is the leg that converted. The raw leg is a transfer.

Directions. Exact-input face to raw, and exact-input raw to face. Both are required. Exact-out is not a direction.

This is not the two-vault proof.

### Dual

Behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol`

Row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`

This is the canonical cross-vault proof. The inherited `setUp` calls `_newFixture()` twice. The row overrides `setUp` and does not call `super.setUp()`. `_deployRowHook` is not virtual, so the row does not edit the behavior to make it virtual. The row deploys through the same package factory with these arguments:

- Package index 0: this vault and its `currency0` face. This is the converting buffered leg. `rateProvider0` is the `currency0` provider.
- Package index 1: the PairToken vault and its share, deployed as stated above. `rateProvider1` is that vault's own provider, not this vault's `currency1` provider. The hook does not call PairToken to mint or redeem inside the outer unlock.

The second case in this same file is `test_row_rateTarget_currency1`. Same vault. Second hook pool. This vault's face on that pool is `currency1`. `rateProvider0` is the `currency1` provider. PairToken remains the non-converting leg. The two hook pools are the two FS-OWN-29 pools.

Hook-pool indices. The hook pool currencies are the face and the PairToken share, address-sorted. This vault's share is not a pool currency. The share-bearing index is the currency index of this vault's face. The other index is the PairToken share.

Directions. Exact-input `zeroForOne` and `oneForZero` on that pair. One direction mints this vault's shares while the manager is unlocked. The reverse burns them. Assert balances, position owner, ticks, salt, and per-address deltas. Assert PairToken `totalSupply` and PairToken balances do not change by a mint or redeem during the hook transaction. Exact-out is not part of this row.

Inherited assertions that require leg 1 to be minted by a call cannot pass as conversion proofs. The row overrides those assertions. Leg 1's share balance changes only by transfer. A hook call that mints or redeems PairToken inside the unlock is the FS-HOOK-04 record above, not a pass.

### Orbital

Behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol`

Row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`

Three legs. The inherited three `_newFixture()` calls are not the bind. The row overrides `setUp` and does not call `super.setUp()`.

- Package index 0, `se0` / `token0` / `rp0`: this vault, converting buffered leg. Primary `token0` is the `currency0` face. Primary `rp0` is the `currency0` provider.
- Package index 1, `se1` / `token1` / `rp1`: the PairToken vault and its share. Share transfer only. Not asked to convert. `rp1` is that vault's provider, not this vault's.
- Package index 2, `se2` / `token2` / `rp2`: one raw 18-decimal token. `se2` is `address(0)`. `rp2` is `address(0)`.

The second case in this same file is `test_row_rateTarget_currency1`. Same vault. `token0` on that second hook is `currency1`. `rp0` is the `currency1` provider. Legs 1 and 2 stay PairToken and raw.

Hook-pool indices. This vault's share is not a pair-key currency. The share-bearing leg is package index 0. Index 1 is the PairToken share. Index 2 is raw. The behavior builds `poolKey01`, `poolKey12`, and `poolKey02` at spacing 60. Run both exact-input directions on `poolKey01` and `poolKey02`. Those pairs include this vault's face. `poolKey12` is a transfer control. It is not a conversion of this vault. Use `standardExchange(uint8)` and `rateProvider(uint8)`. Do not invent `standardExchange0()` getters.

Inherited assertions that all three legs are converting instances of this family cannot pass. The row overrides `test_row_bind_deploysThroughPackage` for those checks. Leg 0 is this vault and is buffered. Leg 1 is not converted by a call under the unlock. Leg 2 is raw.

### Weighted

Behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol`

2-leg row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`

This file is the 2-leg setup. After ascending sort, the face index is this vault and is buffered. The other index is raw, `standardExchange == address(0)`, and is not buffered. Weights stay `0.5e18` and `0.5e18`, traveling with the sorted records. The primary provider is the `currency0` instance. The second case in this same file is `test_row_rateTarget_currency1`: same vault, second hook pool, pair token `currency1`, provider the `currency1` instance, raw leg unchanged.

3-leg row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol`

`n` is 3. This is the one larger supported setup. The row overrides `setUp` and does not use the 2-length constructor as this proof. After ascending sort of the whole record: the face index is this vault, buffered, `currency0` rate target, weight `0.5e18`; one index is the PairToken share, not asked to convert, weight `0.25e18`; the remaining index is raw, weight `0.25e18`. The weights sum to `1e18`. This file does not repeat the currency1 pool. The 2-leg file holds the two rate-target pools.

Hook-pool indices. This vault's share is not a pool currency. The share-bearing index is the face index after the sort.

Directions. On the 2-leg file, exact-input face to raw and raw to face. On the 3-leg file, exact-input both ways on the face/raw pair and the face/PairToken pair. The raw leg is a transfer. The PairToken leg is not asked to convert under an unlock it does not support.

### Curve quad

Behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol`

Row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`

Four legs. Tokens are sorted ascending, as the package requires. The inherited four `_newFixture()` calls are not the bind. The row overrides `setUp` and does not call `super.setUp()`. Exactly one leg is this vault: the sorted index of its bound face. That index is the leg under test. It is not hard-coded to 0 unless that face is the lowest address. One other index is the PairToken share, not asked to convert. The other two indices are two distinct raw tokens. Do not treat this vault's share as a peg. Do not bind four instances of this vault.

The provider on this vault's leg is the `currency0` instance. The PairToken leg uses its own provider. The raw legs use `address(0)`. The second case in this same file is `test_row_rateTarget_currency1`. Same vault. This vault's leg token on that second hook pool is `currency1`. The `currency1` provider is the provider on that leg. The other three legs stay PairToken and the two raw tokens.

Hook-pool indices. This vault's share is not a pool currency. The share-bearing index is the sorted index of the bound face.

Directions. Exact-input both ways between this vault's face and the PairToken share, and both ways between this vault's face and one named raw token. Exact-out is not a direction. Any hook path that reaches `exchangeOut` on this vault is a negative, not a pass. A failed seed is not a passed row. Do not manufacture shares or patch the hook.

Inherited assertions that every leg's `standardExchange` is a converting instance of this family cannot pass. The row overrides those checks.

### Balancer quad

Behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol`

Do not copy the fixed-four constructor. `LEGS` is 4, `_buildLegs` reverts above 4, and `_rowPkgArgs` builds `address[4]`. Overriding `_seLegCount()` to 2 still deploys that four-token constructor. The V4 rows do not call `_buildLegs` or `_rowPkgArgs`.

2-leg row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`

The row overrides `setUp` and deploys through the package's dynamic arrays of length 2. After ascending sort, the face index is this vault, buffered, converting, `currency0` rate target. The other index is raw, `standardExchange == address(0)`, not buffered. No other SE is on this pool. The second case in this same file is `test_row_rateTarget_currency1`: same vault, second hook pool, this vault's leg token is `currency1`, provider is the `currency1` instance, the other leg stays raw.

5-leg row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5.t.sol`

The row overrides `setUp` and deploys through the package's dynamic arrays of length 5. After ascending sort: the face index is this vault, converting, `currency0` rate target; one index is the PairToken share, not asked to convert; the other three indices are raw. This file does not repeat the currency1 pool. The 2-leg file holds the two rate-target pools.

Hook-pool indices. This vault's share is not a pool currency. The share-bearing index is the sorted index of the bound face. On the 2-leg row the other index is raw. On the 5-leg row one other index is the PairToken share and the remaining three are raw.

Directions. Exact-input both ways between this vault's face and the raw leg on the 2-leg row. On the 5-leg row, exact-input both ways between this vault's face and the PairToken share, and both ways between this vault's face and one named raw token. Exact-out is not a direction. A seed or join path that reaches `exchangeOut` is an `ExchangeOutNotAvailable` record with unchanged balances. It is not a pass.

`test_row_bind_deploysThroughPackage` asserts `numTokens() == 4`. That cannot pass. The 2-leg row overrides it to assert 2. The 5-leg row overrides it to assert 5. Do not edit the behavior.

### Migration

Migrate every one-word reader of `previewExchangeIn` listed in `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md` to `(uint256 amountOut, uint256 amountRefunded)`. Also migrate every one-word decoder of `exchangeIn`, including implementations, overrides, typed ignored-return callers, low-level decoders, the six length gates, the three ABI bindings, helpers, tests, scripts, and generated ABI artifacts. Do not paste the index. Consumers that value the result use `amountOut`, not the refund word. The migration must compile repo-wide. Known production assignments that will not compile against the widened return are `UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib.sol` and `ComposedStableCommonDetfCommon.sol`. Those two lines are examples, not the whole set.

Preserve all current V3 matrix rows. Replace stale historical V4 FullSpread evidence only with results from the newly named V4 rows. The evidence destinations are `docs/audits/apex-2026-09-17-evidence/hook-se-matrix.json`, `hook-se-matrix-findings.json`, `hook-se-matrix-finding-descriptions.json`, `docs/audits/apex-2026-09-17-evidence.md`, and `docs/audits/apex-2026-09-17-evidence/acceptance.json` item R10.3. Neither the historical compatibility label nor the existence of this matrix is runtime evidence.

## Sentences outside section 12

Section 3. Replace "The matrix adapter is `SeMatrix_FullSpreadV4Fixture.sol` in that directory." with "The matrix adapter is `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol`."

Section 3. Replace "Add a sibling behavior file beside each of them." with "Add the row files named in section 12 beside the seven behavior contracts. Do not add a sibling behavior contract."

Section 13. Replace "BufferHookIntegration.t.sol and the seven sibling behavior files" with "BufferHookIntegration.t.sol and the row files named in section 12."

These three replacements are path corrections. They are not product-lock changes.

## Limits

This draft is the coordinator synthesis of the four originals. It is not a fifth vote and it does not authorize implementation. No Forge run, test, install, deployment, or Git operation was performed for this draft.
