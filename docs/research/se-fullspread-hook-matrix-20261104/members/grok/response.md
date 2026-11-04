# Grok initial response

## Identity

- Label: grok
- Profile: research
- Phase: initial independent response
- Requested role: council-member
- Requested model: `xai/grok-4.7:xhigh`
- Runtime role, model, reasoning, and task ID: not exposed
- Peers read before submission: no

## Question and targets

Question: review the published full-spread implementation plan and complete its hook-matrix so an implementer can add this vault's row to each of the seven topologies without inventing a binding.

Targets read:

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md`
- PRD hook and matrix sentences in `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`: FS-HOOK-01, FS-HOOK-02, FS-HOOK-03, FS-HOOK-04, FS-TEST-04, and the FS-OWN-29 sentences those rows cite
- The seven live `*_SeMatrixBehavior.sol` files named in the brief
- The seven `*_SeMatrix_UniswapV3FullSpreadStandardExchangeVault.t.sol` row files beside those behaviors
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV3Fixture.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol`

This response does not authorize implementation.

## Evidence

Observation. Plan section 12 tells the implementer to add a sibling behavior file beside seven `contracts/hooks/.../*.behavior.sol` paths. Those paths are not the live files. The live behavior contracts are the seven paths in FS-TEST-04 and in the brief. Each already has a Uniswap V3 full-spread row beside it. Every one of those seven row files does only this: it stores `sharedPkg`, overrides `_newFixture()`, constructs `SeMatrix_FullSpreadV3Fixture(_ctx(), sharedPkg)`, and returns that fixture. They do not define a new harness.

Observation. `SeMatrix_FullSpreadV3Fixture` deploys a Uniswap V3 factory, the V3 full-spread package, two `SimpleMintableERC20` faces sorted so `token0 < token1`, a 3000-fee V3 pool, the vault through `pkg_.deployVault(pool)`, an idle liquid-reserve sleeve, an independent LP, and a bootstrap through `exchangeInManyToOne`. `faceToken()` is `token0`. It does not deploy a rate-provider instance. `seBooked()` is `localReserve(token0)`. `hasPartialCase()` returns true.

Observation. Plan section 3 says the matrix adapter is `SeMatrix_FullSpreadV4Fixture.sol` in the vault-spec directory `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`. The V3 rows import the fixture from `test/foundry/spec/hooks/uniswap/v4/standardExchange/`. The brief requires the V4 fixture at `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol`.

Observation. FS-HOOK-03 and FS-TEST-04: on an enabled vault, `exchangeOut` reverts `ExchangeOutNotAvailable()` and `previewExchangeOut` returns zero with no refund word. Exact-output success cannot pass. A user's unused input is refunded. A donation or compound remainder is booked, so those rows stay. Do not add `asset()`. An identity bind the current hook rejects without `asset()` is an FS-HOOK-04 record, not a pass.

Observation. FS-OWN-29: rate-provider instances are deployed by `IStandardExchangeRateProviderDFPkg` for a vault and rate-target pair. `PkgArgs` carries `reserveVault`, `rateSubject`, and `rateTarget`. There is a scenario for each underlying token. Separate pools may hold the same vault, each with a different `rateTarget`. The provider reads the widened preview tuple. This vault stores no rate-provider address and does not implement `getRate()`.

Observation. FS-HOOK-02 names the canonical proof: this vault is the buffered leg; the hook is configured with one external provider and one rate target; the other Standard Exchange is not asked to mint or redeem inside the outer unlock; Current PairToken rejects that context; the two backing pool keys differ; one direction mints this vault's shares while the manager is unlocked and the reverse burns them; same-backing-pool sequential composition stays unverified. A both-buffered composition of another family that already supports the same borrowed unlock is optional and is not the required proof.

Observation. The seven behaviors, and what they bind:

- Single, `UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol`. One fixture. `pairToken` is the face and `standardExchange` is the fixture SE. Hook-pool `currency0 < currency1`, and the two currencies are the face and the SE share (`test_row_bind_deploysThroughPackage`). No rate-provider argument is assigned in this file. `_defaultPkgArgs()` is passed through.
- Constant-product single. One fixture on the pair leg. `rawToken` stays the base raw token. `standardExchangeOf(raw) == address(0)`. `faceIsCurrency0` is `currency0() == pairToken`. `rateProvider` is `providerForCp(..., seUT, face)`.
- Dual. `_newFixture()` is called twice. Package `standardExchange0` / `token0` is the leg under test. Package `standardExchange1` / `token1` is a second instance of the same family. `faceIsC0` is `currency0() == face`. Both legs get a `providerForCp` against that leg's own SE and face. After seed, the hook holds both SEs' shares.
- Orbital. `_newFixture()` is called three times. Package fields `token0/1/2`, `se0/1/2`, `rp0/1/2`. Every leg is buffered. Swap rows use `tokenIn = face1` and `tokenOut = face0`, and the reverse. Pair keys are `poolKey01`, `poolKey12`, and `poolKey02` at spacing 60.
- Weighted. One fixture. Two tokens, address-sorted. `faceIdx` is this vault and is buffered. `otherIdx` is raw and has `standardExchange == address(0)`. Weights are `0.5e18` and `0.5e18`. Providers come from `providersFor(toks, ses)`.
- Curve quad. Four fixtures, faces sorted ascending. Inherited `faceIdx` is 0 and `otherIdx` is 1 after that sort. Every leg is buffered. Providers come from `providersFor4`. The V3 row comment says this family mints through `previewExchangeOut` / `exchangeOut` and that the V3 vault gained that route under D64.
- Balancer quad. `LEGS = 4`. `_seLegCount()` is virtual and returns 4. `_buildLegs` reverts when `seLegs > 4`. `_rowPkgArgs` builds `address[4]`. `test_row_bind_deploysThroughPackage` asserts `numTokens() == LEGS`. A raw leg is used only when `_seLegCount()` is lowered, and the pool is still four tokens.

Observation. All seven behaviors declare these tests `virtual`: `test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed`, `test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly`, and `test_row_poolManagerSwap_bothDirections_noFaceResidual`. The first two assert exact output delivered. The third asserts exact-in payment in both directions and then asserts exact-out delivery. Single's `_mintSeSharesTo` calls `previewExchangeOut` and `exchangeOut` on the fixture SE. Single's `test_row_previewMatchesExecution` compares `previewExchangeOut` on that SE to the hook's exact-out preview.

Observation. All seven declare `test_row_partialConsumption_bookedNotRefunded` virtual. If `hasPartialCase()` is false, the body calls `_roundingToZeroControl` and returns. The other branch asserts "no refund of the unconsumed part" and "SE booked the remainder above capacity". None of the seven behavior files contains `donate` or `compound`.

Observation. `test_row_seFailure_rollsBack` calls `fx.armOperativeRevert()` when `operativeRevertReachable()` is true. The V3 fixture implements that by `vm.mockCallRevert` on the V3 pool `mint`. The false branch asserts `seBooked()` grows. FS-TEST-01 forbids `vm.mockCall` on this vault or the PoolManager.

Inference. A V4 row that only swaps the fixture class, and otherwise keeps the V3 comments that exact-out now passes, will treat exact-out success as a pass. That contradicts FS-HOOK-03 and FS-TEST-04.

Inference. Two calls to a V4 `_newFixture()` bind two instances of this vault and ask both to convert. That is not the FS-HOOK-02 proof, and it is not the optional both-buffered case, which is another family that already supports the borrowed unlock.

## Assumptions

- PairToken is the other Standard Exchange because FS-HOOK-02 names it as the current vault that rejects mint or redeem inside the outer unlock. PairToken source and a PairToken matrix fixture were not in the admitted read set. The bind is the name and the no-call rule from that sentence, not a fixture path copied from disk.
- The single behavior's admitted file does not assign a rate-provider argument. This response does not open the TestBase to inspect `_defaultPkgArgs`. The single row does not add a field.
- Foundry isolates test contracts. Two row files cannot share one vault diamond. The two rate-target pools therefore live in one row contract, on the vault that `_newFixture()` deployed.
- Hook package interfaces were not opened. Leg roles are taken from the behavior files and from FS-HOOK-01. No rejecting selector was present in the admitted files, so none is invented here.

## Coverage

The replacement below binds all seven topologies. For each it names the live behavior path, the new row filename, the one fixture and what it deploys, the rate-target face and the currency1 row where FS-HOOK-02's required FS-OWN-29 rows require both, the hook-pool index of this vault's share and the other indices, the exact-input directions, the inherited assertions that cannot pass and the adaptation, the disjoint PoolKey rule, and the canonical case. Closed product locks are not reopened. No peer response was read.

## Conclusions

Replace plan section 12 with the following text.

### 12. Hook integration and migration

Add a row file beside each live behavior below. Copy the Uniswap V3 full-spread row shape: one contract, `sharedPkg`, and `_newFixture()` returning `new SeMatrix_FullSpreadV4Fixture(_ctx(), sharedPkg)`. Do not add a sibling behavior file. Do not edit the seven behavior contracts. Do not weaken their other-family assertions. Do not copy the V3 row comments that say full-spread exact-out now delivers the previewed amount. Those comments are not a pass for this vault.

The one fixture file is `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol`. It follows `SeMatrix_FullSpreadV3Fixture.sol` except for this family's package, pool, and refund tuple.

- Package: `UniswapV4FullSpreadStandardExchangeVault` through its production package and the bound registry. Not the V3 package. Not `exchangeInManyToOne`. Not `setLiquidReservePercentageOfVault`, `localReserve`, or `deployedReserve`. Bootstrap is one bundle deposit of both faces through this vault's public bundle route.
- Pool: one bound hookless PoolKey, hook `address(0)`, initialized on the bound PoolManager. Not a Uniswap V3 3000-fee pool.
- Refund tuple: `previewExchangeIn` returns `(uint256 amountOut, uint256 amountRefunded)`. The fixture and the rows read `amountOut`. The refund word is not output and is not shares.

The fixture deploys this vault, that hookless pool, the two face tokens, and the external rate-provider instance. The two faces are the PoolKey currencies in currency0, currency1 order, with WETH substituted for native at the boundary. Hermetic mintable faces are sorted so currency0 is the lower address. `faceToken()` on the primary rows is currency0. The constructor deploys one `IStandardExchangeRateProviderDFPkg` instance whose `reserveVault` and `rateSubject` are this vault and whose `rateTarget` is currency0. `currency1RateProvider()` deploys a second instance against that same vault with `rateTarget` equal to currency1. It does not deploy a second vault. This vault stores no provider and does not implement `getRate()`.

`seBooked()` is `booked[i]` of the bound face in `vaultTokens()` order. `hasPartialCase()` returns false. User unused input does not increase `booked`. `operativeRevertReachable()` returns false. The fixture does not `vm.mockCall` this vault or the PoolManager.

Common adaptation, every topology. The row overrides these inherited tests. Exact-out success cannot pass. `exchangeOut` on an enabled vault reverts `ExchangeOutNotAvailable()`. `previewExchangeOut` returns zero and gains no refund word. A hook path that calls `exchangeOut` on this vault reverts and pays neither token.

- `test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed` cannot pass. The override expects that revert, or a zero `previewExchangeOut`, and does not assert a delivered amount.
- `test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly` cannot pass. Same adaptation.
- The exact-out half of `test_row_poolManagerSwap_bothDirections_noFaceResidual` cannot pass. The exact-in half stays. The exact-out half reverts and pays neither token.

`test_row_partialConsumption_bookedNotRefunded` cannot pass its booked-not-refunded body. `hasPartialCase()` false makes that inherited function take `_roundingToZeroControl`. Unused declared user input is refunded to `msg.sender` and is not booked. Do not delete the test. Do not make it pass by booking the refund.

Donation and compound remainders are booked, so those rows stay. None of these seven behavior files contains `donate` or `compound`. Do not delete a donation or compound booked-remainder assertion. There is none in these files to remove. `test_row_bufferFirst_restingFace_notPaidToJoiner` is a transfer onto the hook, not vault `donate`. It stays inherited.

`test_row_seFailure_rollsBack` cannot pass on either inherited branch. The V3 `pool.mint` mock is not this package, and the PoolManager is not mocked. The row overrides the test. It forces `AmountOutNotMet` on an exact-input call whose minimum is above the quote, and it asserts shares, face balances, and `booked` unchanged. It does not require user input to increase `seBooked()`.

One-word `previewExchangeIn` comparisons in the inherited bind tests read `amountOut` after the migration below. That decoder change is not permission to change other families' expected amounts.

Disjoint PoolKey rule, every topology. The hook product PoolKey and this vault's backing PoolKey are different keys. Where the currency1 test builds a second hook pool, that pool is a second hook PoolKey, it holds the same vault diamond, and it is not the backing PoolKey. Same-backing-pool sequential composition stays unverified. These rows do not pass it.

Identity bind. The dual row attempts `token == this vault` once. If the current package rejects that bind without `asset()`, the row records the consumer, selector, arguments, and revert under FS-HOOK-04 and does not pass. Do not add `asset()`. No rejecting function is cited in the admitted files, so this section does not name a selector. That record does not close FS-A26 and does not close the FS-OWN-29 rows.

Other Standard Exchange. Where a topology has a non-converting SE leg, that leg is a PairToken share. The row does not construct it with `SeMatrix_FullSpreadV4Fixture`. During the outer unlock the hook does not call that vault's `exchangeIn`, `exchangeOut`, or `exchangeBundle*`. If the current hook makes that call, the run is an FS-HOOK-04 record naming the hook function, selector, arguments, and revert. It is not a pass. Do not edit the hook. Do not replace that leg with a second instance of this vault. Two instances of this vault are not the required proof and are not the optional both-buffered case.

#### Single

Behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol`

Row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`

Fixture: the one fixture above. It deploys this vault, the hookless pool, the two faces, and the currency0 rate-provider instance. The admitted single behavior assigns no rate-provider argument and passes `_defaultPkgArgs()` through. The row does not add a rate-provider field. There is no currency1 row on this topology. FS-HOOK-02's both-target proof is not this row.

Hook-pool indices. `currency0` is the lower address of the face and this vault's share. `currency1` is the higher address. `vaultTokens()[0]` is `currency0` and `vaultTokens()[1]` is `currency1`. This vault's share is the index whose currency equals `se()`. The other index is the face. There is no raw leg and no second SE leg.

Directions. Exact-input wrap (face in, share out) and exact-input unwrap (share in, face out). Those two calls are `zeroForOne` and `oneForZero` through `_swapParams`. Exact-out is not a direction.

Additional adaptation. Do not call `_mintSeSharesTo`. It calls `previewExchangeOut` and `exchangeOut` on this vault. Seed shares with exact-input `exchangeIn`, which the behavior `setUp` already does. In `test_row_previewMatchesExecution`, the two `previewExchangeOut` equalities cannot pass as a positive quote. `previewExchangeOut` returns zero. The exact-in `previewExchangeIn` equalities stay and read `amountOut`.

Canonical case. This is not a two-vault proof. This vault is the only SE. No other Standard Exchange is asked to convert.

#### Constant-product single

Behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol`

Row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`

Fixture: the one fixture. Primary `setUp` binds the currency0 face as `pairToken` and the fixture provider as `rateProvider`. The second row is `test_row_rateTarget_currency1` in this same file. It keeps the same vault, calls `currency1RateProvider()`, and deploys a second hook pool whose pair token is currency1. That second pool is the other rate-target pool. It is not a second vault.

Hook-pool indices. Currencies are the face and the raw token, address-sorted. `faceIsCurrency0` is true when `currency0() == pairToken`. This vault's share is not a pool currency. The share-bearing index is the currency index of the face: `standardExchangeOf(face)` is this vault and that leg is buffered. The other index is the raw token: `standardExchangeOf(raw)` is `address(0)`. The face leg is the leg that converted. The raw leg is a transfer.

Directions. Exact-input face to raw, and exact-input raw to face. `zeroForOne` is `tokenIn < tokenOut`. Both directions are required. Exact-out is not a direction.

Canonical case. This vault is the buffered leg. The raw leg is not an SE and is not asked to convert. This is not the two-vault proof.

#### Dual

Behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol`

Row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`

This is the canonical cross-vault proof. The inherited `setUp` calls `_newFixture()` twice. The row overrides `setUp` and does not call `super.setUp()`. `_deployRowHook` is not virtual, so the row does not edit the behavior to make it virtual. The row deploys through the same package factory with these arguments:

- Package index 0, `standardExchange0` / `token0`: this vault and its currency0 face. This is the converting buffered leg. `rateProvider0` is the fixture's currency0 provider.
- Package index 1, `standardExchange1` / `token1`: a PairToken share. `rateProvider1` is that other SE's own provider, not this vault's currency1 provider. The hook does not call PairToken to mint or redeem inside the outer unlock.

The second row is `test_row_rateTarget_currency1` in this same file. Same vault diamond. Second hook pool. This vault's face on that pool is currency1. `rateProvider0` is `currency1RateProvider()`. PairToken remains the non-converting leg. The two hook pools are the two FS-OWN-29 pools.

Hook-pool indices. The hook pool currencies are the two leg tokens, address-sorted. `faceIsC0` is `currency0() == face`. This vault's share is not a pool currency. The share-bearing index is the currency index of this vault's face. The other index is the PairToken share.

Directions. Exact-input `zeroForOne` and `oneForZero` on that pair, using `_zfo`. One direction mints this vault's shares while the manager is unlocked. The reverse burns them. Assert balances, position owner, ticks, salt, and per-address deltas. Exact-out is not part of this row.

Inherited assertions that require leg 1 to be minted by a call cannot pass as conversion proofs. That includes `assertGt(IERC20(seUT1).balanceOf(hook), 0, "hook holds leg 1 SE shares after buffering")` and the leg-1 `previewExchangeIn` quote in `test_row_bind_deploysThroughPackage`. The row overrides those assertions. Leg 1's share balance changes only by transfer. A hook call that mints or redeems PairToken inside the unlock is the FS-HOOK-04 record above, not a pass.

Canonical case. This vault is the buffered leg. PairToken is not asked to convert under an unlock it does not support.

#### Orbital

Behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol`

Row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`

Three legs. The inherited three `_newFixture()` calls are not the bind. The row overrides `setUp` and does not call `super.setUp()`.

- Package index 0, `se0` / `token0` / `rp0`: this vault, converting buffered leg. Primary `rp0` is the fixture's currency0 provider. `token0` is that vault's currency0 face.
- Package index 1, `se1` / `token1` / `rp1`: PairToken diamond A. Share transfer only. Not asked to convert. `rp1` is that SE's provider, not this vault's.
- Package index 2, `se2` / `token2` / `rp2`: PairToken diamond B, a different share from diamond A. Share transfer only. Not asked to convert. `rp2` is that SE's provider, not this vault's.

The three faces and three SE addresses stay distinct, as the behavior's `setUp` requires. The second row is `test_row_rateTarget_currency1` in this same file. Same vault. `rp0` is `currency1RateProvider()`. `token0` on that second hook is currency1. Legs 1 and 2 stay the two PairToken shares. The second hook pool is the other rate-target pool.

Hook-pool indices. This vault's share is not a pair-key currency. The share-bearing leg is package index 0. Indices 1 and 2 are the other-SE legs. The behavior builds `poolKey01`, `poolKey12`, and `poolKey02` at spacing 60. The row exercises `zeroForOne` and `oneForZero` on `poolKey01`, the pair of this vault's face and leg 1's token. That is the pair the behavior's swap rows already use (`tokenIn = face1`, `tokenOut = face0`, and the reverse). `poolKey12` is not a conversion of this vault.

Inherited assertions that all three legs are converting instances of this family cannot pass. The row overrides `test_row_bind_deploysThroughPackage` for those three `standardExchange` and `isBuffered` checks. Leg 0 is this vault and is buffered. Legs 1 and 2 are the PairToken shares and are not converted by a call under the unlock.

Canonical case. This vault is the buffered leg on index 0. The other Standard Exchange legs are not asked to convert under an unlock they do not support.

#### Weighted

Behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol`

Row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`

This file is the 2-leg setup. It copies the V3 row shape. The behavior already sorts two tokens. `faceIdx` is this vault and is buffered. `otherIdx` is raw, `standardExchange(otherIdx) == address(0)`, and it is not buffered. Weights stay `0.5e18` and `0.5e18`. The primary provider is the fixture's currency0 instance, passed where the behavior calls `providersFor`. The second row is `test_row_rateTarget_currency1` in this same file: same vault, second hook pool, pair token currency1, provider `currency1RateProvider()`, raw leg unchanged.

Hook-pool indices. This vault's share is not a pool currency. The share-bearing index is `faceIdx` after the address sort. The other index is the raw leg.

Directions. Exact-input face to raw, and exact-input raw to face. Those are `zeroForOne` and `oneForZero`. Exact-out is not a direction.

The one larger supported setup is a second file, not a second choice of `n`: `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol`. `n` is 3. The row overrides `setUp` and does not use the 2-length constructor as this proof. After ascending sort: the index of the fixture face is this vault, buffered, currency0 rate target; one index is raw with `standardExchange == address(0)`; the remaining index is one PairToken share, not asked to convert. This file does not repeat the currency1 pool. The 2-leg file holds the two rate-target pools.

Canonical case. This vault is the buffered leg. The raw leg is not asked to convert. On the 3-leg file, the PairToken leg is not asked to convert under an unlock it does not support.

#### Curve quad

Behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol`

Row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`

Four legs. Tokens are sorted ascending, as the package requires. The inherited four `_newFixture()` calls are not the bind. The row overrides `setUp` and does not call `super.setUp()`. Exactly one leg is this vault: the sorted index of its bound face. That index is the leg under test. It is not hard-coded to 0 unless that face is the lowest address. The other three indices are three distinct PairToken shares, three diamonds, none of them this vault, none asked to convert. Do not treat this vault's share as a peg. Do not bind four instances of this vault.

The provider on this vault's leg is the fixture's currency0 instance. The other three legs do not use this vault's provider. The second row is `test_row_rateTarget_currency1` in this same file. Same vault. This vault's leg token on that second hook pool is currency1. `currency1RateProvider()` is the provider on that leg. The other three legs stay the three PairToken shares.

Hook-pool indices. This vault's share is not a pool currency. The share-bearing index is the sorted index of the bound face. The other three indices are the other-SE legs.

Directions. Exact-input both ways between this vault's face and the next sorted leg. The row names that next leg `other`. Those two calls are `zeroForOne` and `oneForZero`. Exact-out is not a direction. The V3 row's D64 exact-out comment is not copied.

Inherited assertions that every leg's `standardExchange` is a converting instance of this family cannot pass. The row overrides those checks in `test_row_bind_deploysThroughPackage`.

Canonical case. This vault is the one buffered converting leg. The other Standard Exchange legs are not asked to convert under an unlock they do not support.

#### Balancer quad

Behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol`

Do not copy the fixed-four constructor. `LEGS` is 4, `_buildLegs` reverts above 4, and `_rowPkgArgs` builds `address[4]`. Overriding `_seLegCount()` to 2 still deploys that four-token constructor. The V4 rows do not call `_buildLegs` or `_rowPkgArgs`.

2-leg row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`

The row overrides `setUp` and deploys through the package's dynamic arrays of length 2. After ascending sort, the fixture-face index is this vault, buffered, converting, currency0 rate target. The other index is raw, `standardExchange == address(0)`, not buffered. No other SE is on this pool. The second row is `test_row_rateTarget_currency1` in this same file: same vault, second hook pool, this vault's leg token is currency1, provider is `currency1RateProvider()`, the other leg stays raw.

5-leg row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5.t.sol`

The row overrides `setUp` and deploys through the package's dynamic arrays of length 5. After ascending sort: the fixture-face index is this vault, converting, currency0 rate target; one index is one PairToken share, not asked to convert; the other three indices are raw. This file does not repeat the currency1 pool. The 2-leg file holds the two rate-target pools.

Hook-pool indices. This vault's share is not a pool currency. The share-bearing index is the sorted index of the bound face. On the 2-leg row the other index is raw. On the 5-leg row one other index is the PairToken share and the remaining three are raw.

Directions. Exact-input both ways between this vault's face and the raw `other` leg. Those are `zeroForOne` and `oneForZero`. Exact-out is not a direction.

`test_row_bind_deploysThroughPackage` asserts `numTokens() == 4`. That cannot pass. The 2-leg row overrides it to assert 2. The 5-leg row overrides it to assert 5. Do not edit the behavior.

Canonical case. This vault is the buffered leg. On the 2-leg row no other SE is asked to convert. On the 5-leg row the PairToken leg is not asked to convert under an unlock it does not support.

#### Migration

Migrate every one-word reader of `previewExchangeIn` listed in `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md` to `(uint256 amountOut, uint256 amountRefunded)`. Also migrate every one-word decoder of `exchangeIn`, including implementations, overrides, typed ignored-return callers, low-level decoders, the six length gates, the three ABI bindings, helpers, tests, scripts, and generated ABI artifacts. Do not paste the index. Consumers that value the result use `amountOut`, not the refund word. The migration must compile repo-wide. Known production assignments that will not compile against the widened return are `UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib.sol` and `ComposedStableCommonDetfCommon.sol`. Those two lines are examples, not the whole set.

### Sentence outside section 12

Section 3 blocks the fixture path. The sentence that must change is: "The matrix adapter is `SeMatrix_FullSpreadV4Fixture.sol` in that directory."

"That directory" in that paragraph is `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`. The sentence must name `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol`. This is not a product-lock change.

## Limits

- Runtime identity was not exposed. Peers were not read. The plan, the PRD, and project code were not edited. Tests, installs, deploys, and Git were not run. No sub-agent was launched.
- PairToken source was not opened. The other-SE bind uses the name and the no-call rule in FS-HOOK-02. It does not cite a PairToken fixture path.
- No identity-bind rejecting function appears in the admitted behavior, row, fixture, plan, or hook sentences. The dual row's FS-HOOK-04 record is written from the revert the row observes. This response does not invent that selector.
- Section 3's sentence "Add a sibling behavior file beside each of them." and section 13's cell "the seven sibling behavior files" were not selected as the one sentence that must change. The replacement above states the artifacts are row files. Those two sentences remain outside section 12.
- This response does not authorize implementation and does not replace the plan. The coordinator updates the hook-matrix portion after advisory review.
