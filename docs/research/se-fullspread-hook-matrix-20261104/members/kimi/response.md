# Identity

- Member: kimi
- Profile: research
- Phase: initial independent response
- Requested role: council-member
- Requested model and reasoning: `kimi-coding/k3.1-pro:high`, global route
- Runtime identity: not exposed
- Peers read before submission: no

# Question and targets

Determine the complete hook-matrix binding for `UniswapV4FullSpreadStandardExchangeVault`. The target is a replacement for section 12 of the published implementation plan that lets an implementer add this vault's row to all seven existing hook topologies without choosing a fixture, leg role, rate target, token index, swap direction, or assertion adaptation.

# Evidence

- The published plan's section 12 names stale behavior paths and does not bind the per-topology indices, leg roles, or rate-target rows. Section 3 also places `SeMatrix_FullSpreadV4Fixture.sol` in the vault test directory rather than the hook-matrix directory required by the brief.
- PRD FS-HOOK-01 binds seven families: single, constant-product single, dual, orbital, weighted with 2 through 8 legs and both a minimum and larger setup, fixed-four Curve, and Balancer with 2 through 5 legs including 2-leg and 5-leg setups.
- PRD FS-HOOK-02 requires FullSpread as the buffered leg, an external rate provider, exact-input mint and burn directions on disjoint backing PoolKeys, and no conversion of the other Standard Exchange under an unsupported outer unlock. Same-backing-pool sequential composition remains unverified.
- PRD FS-HOOK-03 and FS-TEST-04 make exact-output success impossible: `previewExchangeOut` returns zero and enabled `exchangeOut` reverts `ExchangeOutNotAvailable()`. They also require unused user input to be refunded while donation and compound remainders remain booked.
- PRD FS-OWN-29 and FS-A29 require one external provider row per underlying token and two pools holding the same vault at different `rateTarget` values. The provider consumes the widened preview tuple. The vault has no `getRate`, `rateAsset`, or `asset`.
- All seven existing V3 rows implement `_newFixture()` with `SeMatrix_FullSpreadV3Fixture` and reuse `sharedPkg`. That is the row shape to preserve.
- `SeMatrix_FullSpreadV3Fixture.sol` deploys a production vault on an independently seeded pool, exposes token0 as the face and token1 as the other token, and bootstraps through public routes. Its V3 sleeve and `localReserve` bookkeeping are not portable to V4.
- The single behavior's `_mintSeSharesTo` seeds through exact-out, and all seven behaviors contain exact-output success assertions. Those specific bodies cannot be inherited as passes for V4.
- The Curve and Balancer V3 rows expressly state that their hook family mints SE shares through the SE exact-out route. Their inherited exact-out-dependent seed and join success bodies therefore become rejection records for V4, not compatibility passes.
- The Balancer behavior's default row is fixed at four legs, while FS-HOOK-01 requires this family to prove 2-leg and 5-leg configurations. The V4 sibling row must use those two configurations rather than copy the four-leg default.

# Assumptions

- `token0` and `token1` name the two ERC-20 faces of the V4 vault's own hookless backing pool. `face` means `token0`; `other face` means `token1`.
- A second rate-target row is a second test row in the same named topology file. It reuses the same V4 vault, deploys a second external provider with the other face as `rateTarget`, and uses a second hook product pool. It does not deploy a different V4 vault to satisfy FS-A29.
- Numeric PoolKey currency indices are determined by address ordering at runtime. The bindings below name the exact role-to-index computation instead of pretending deployment addresses are known in advance. Configuration leg indices are named explicitly.
- The other Standard Exchange in a cross-vault configuration is an identity share leg. The hook must not mint or redeem that other SE inside the outer unlock. If the current package rejects `token == se` without `asset()`, the row records the consumer, selector, arguments, and revert under FS-HOOK-04; it is not a pass.

# Coverage

| Topology | Bound configurations | Exact-input coverage |
| --- | --- | --- |
| single | One V4 buffered SE and its face | Wrap and unwrap, `zeroForOne` and `oneForZero` |
| constantProduct/single | V4 face leg plus one raw leg | Face/raw in both directions |
| dual | V4 buffered face plus other-SE identity share | Both directions, with V4 mint and burn |
| orbital | Three legs: V4, other-SE identity, raw | All three pair keys in both directions |
| weighted | Two legs and three legs | Every V4-facing selected pair in both directions |
| Curve quad | Four legs: V4, other-SE identity, two raw | V4/other-SE and V4/raw pairs in both directions |
| Balancer quad | Two legs and five legs | Every V4-facing selected pair in both directions |

Every configuration has a token0-target row and a token1-target row for the same V4 vault. Every row carries the exact-output, refund, booked-remainder, disjoint-backing-pool, and no-`asset()` rules stated below.

# Conclusions

## Replacement for plan section 12: Hook integration and migration

Add the seven row files named below beside the real behavior contracts. Copy the corresponding V3 row shape: implement `_newFixture()`, reuse `sharedPkg` where multiple fixtures are needed, and override only assertions that V4 cannot satisfy. Do not edit or weaken assertions for other SE families.

Use one fixture file:

`test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol`

It follows `SeMatrix_FullSpreadV3Fixture.sol` except for this family's package, its bound hookless Uniswap V4 pool, and the `(uint256 amountOut, uint256 amountRefunded)` preview tuple. It deploys the production V4 vault through its package and registry on that hookless backing PoolKey, creates and exposes the two face tokens, seeds independent backing liquidity, bootstraps shares only through accepted exact-input public routes, and deploys an external `IStandardExchangeRateProviderDFPkg` instance whose `reserveVault` and `rateSubject` are this vault. The primary provider's `rateTarget` is token0. The second rate row keeps the same vault, deploys another external provider whose `rateTarget` is token1, and binds a second hook product pool. The fixture's book accessor reads this family's booked ledger; it does not recreate the V3 sleeve or `localReserve` model. It does not install or call `getRate`, `rateAsset`, or `asset`.

Apply these assertion adaptations in every sibling row:

1. Decode every V4 `previewExchangeIn` result as `(amountOut, amountRefunded)` and use `amountOut` for output expectations. Migrate every V4 `exchangeIn` return decoder to the same tuple.
2. Replace inherited exact-output success with the V4 negative contract. Direct `previewExchangeOut` returns zero; an enabled `exchangeOut` reverts `ExchangeOutNotAvailable()`; a hook route reaching it fails closed and pays neither token. Remove exact-output success segments from the inherited PoolManager both-direction test and retain a separate negative exact-output test. Seed shares through exact-input routes, not through the single behavior's exact-out `_mintSeSharesTo` helper.
3. Replace the inherited ordinary-user `partialConsumption_bookedNotRefunded` expectation: unused declared user input is refunded to the payer, is not booked, and is not minted. Keep donation and compound remainder rows: those remainders are booked, are not refunded, and remain available to later maintenance processing.
4. Attempt the identity bind where the topology supports it. A rejection that requires `asset()` is an FS-HOOK-04 record, not a pass, and does not waive the required buffered and rate-target rows.
5. Every cross-vault proof uses different backing PoolKeys for this V4 vault and the other SE. One exact-input direction mints V4 shares while the manager is unlocked and the reverse burns them; assert token and share balances, position owner, full-range ticks, salt zero, and this diamond's per-address deltas. Same-backing-pool sequential composition stays unverified and is not reported as passed.
6. The canonical cross-vault case keeps this V4 vault as the buffered leg and never asks the other SE to convert under the outer unlock. The other SE share is identity-only; an identity rejection without `asset()` is recorded under FS-HOOK-04. Identity-only trading is separate evidence and does not prove V4 underlying entry or exit.

### 1. Single SE buffer hook

- **Behavior:** `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol`.
- **New row beside it:** `UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
- **Fixture and targets:** `SeMatrix_FullSpreadV4Fixture.sol` deploys the V4 vault, its hookless backing PoolKey, token0/token1, and the external provider. The primary row rates the share into token0; the second row uses the same vault and rates it into token1 in a second hook product pool.
- **Indices and legs:** The hook product PoolKey contains `face` and the V4 share. After currency sorting, `shareIdx = buffer.currency0() == seUT ? 0 : 1` and `faceIdx = 1 - shareIdx`. There are no other legs.
- **Exact input:** Exercise face-to-share wrap and share-to-face unwrap. Cover both `zeroForOne` and `oneForZero` according to the sorted indices; one direction mints and the other burns through borrowed `exchangeIn`.
- **Assertion binding:** Exact-out wrap and unwrap previews return zero and execution reverts rather than delivering output; replace exact-out seeding with exact-input minting. Refund unused user input. Keep donation and compound remainders booked.
- **Composition:** This is a one-vault row, not the canonical two-vault proof. The canonical dual binding is the dual row below: V4 buffered, other SE identity-only with no outer-unlock conversion, disjoint backing PoolKeys, and same-backing-pool sequential composition unverified.

### 2. Constant-product single buffer hook

- **Behavior:** `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol`.
- **New row beside it:** `UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
- **Fixture and targets:** `SeMatrix_FullSpreadV4Fixture.sol` supplies the V4 vault, hookless backing PoolKey, both faces, and external provider. Bind `standardExchange = seUT` and `pairToken = face`; use token0 as the primary `rateTarget` and token1 for the second same-vault row.
- **Indices and legs:** The product PoolKey contains `face` and `raw`. `faceIdx = single.currency0() == face ? 0 : 1`; `rawIdx = 1 - faceIdx`. The V4 share has no product-pool currency index: it is buffered inventory on `faceIdx`. `rawIdx` is an unbuffered transfer leg with `standardExchangeOf(raw) == address(0)`.
- **Exact input:** Exercise face-to-raw and raw-to-face, covering `zeroForOne` and `oneForZero` by address order. Only the face leg converts through V4; the raw leg remains a transfer.
- **Assertion binding:** Both inherited hook exact-out success bodies and the exact-out portions of the PoolManager swap row become zero-preview/`ExchangeOutNotAvailable` negatives with no payment. Refund unused declared user input rather than booking it; keep donation and compound remainders booked.
- **Composition:** This raw-leg row is not a two-vault pass. For the canonical dual case, use V4 as the buffered leg, the other SE as an identity share with no unsupported conversion, and disjoint backing PoolKeys. Same-backing-pool sequential composition remains unverified.

### 3. Dual SE buffer constant-product hook

- **Behavior:** `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol`.
- **New row beside it:** `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
- **Fixture and targets:** `SeMatrix_FullSpreadV4Fixture.sol` supplies the V4 vault, hookless backing PoolKey, token0/token1, and external provider. Leg 0 binds `standardExchange0 = seUT` and `token0 = face`. Leg 1 binds the other SE and its own share as an identity leg. The V4 provider targets token0 in the primary row and token1 in the second same-vault row.
- **Indices and legs:** Configuration leg 0 is the buffered V4 face leg; configuration leg 1 is the other-SE identity share leg. The V4 share is inventory on leg 0, not a product-pool currency. In the product PoolKey, `v4FaceCurrencyIdx = dual.currency0() == face ? 0 : 1`, and the other-SE share has the complementary currency index.
- **Exact input:** Exercise V4 face to other-SE share and other-SE share to V4 face, with both `zeroForOne` and `oneForZero`. The first mints V4 shares while unlocked; the reverse burns them. The other SE only transfers its share and is never asked to mint or redeem in the outer unlock.
- **Assertion binding:** Replace both exact-out success rows and exact-out PoolManager segments with zero-preview/`ExchangeOutNotAvailable` negatives. Refund unused user input; keep donation and compound remainders booked. If the other-SE identity bind is rejected without `asset()`, record that reject under FS-HOOK-04 and do not pass the identity row or add `asset()`.
- **Composition:** This is the canonical cross-vault proof. The V4 backing PoolKey and the other SE's backing PoolKey must differ. Assert balances, position owner, ticks, salt, and per-address deltas in both directions. Same-backing-pool sequential composition stays unverified.

### 4. Orbital buffer hook

- **Behavior:** `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol`.
- **New row beside it:** `UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
- **Fixture and targets:** One `SeMatrix_FullSpreadV4Fixture.sol` instance supplies the V4 vault, hookless backing PoolKey, both faces, and external provider. Configuration leg 0 binds `se0 = seUT`, `token0 = face`, and `rp0` to that provider. Leg 1 is the other-SE identity share; leg 2 is raw. Use token0 then token1 as the two same-vault V4 `rateTarget` rows.
- **Indices and legs:** This is a three-leg topology. Leg 0 is V4 buffered, leg 1 is other-SE identity with no conversion, and leg 2 is raw with zero SE. The V4 share is leg-0 inventory, not a pool currency. For each pair PoolKey, currency index 0/1 is assigned by ascending token address; retain the logical leg indices 0, 1, and 2 for `se0/se1/se2` and `rp0/rp1/rp2`.
- **Exact input:** Exercise both directions on `poolKey01` (V4 face/other-SE identity), `poolKey02` (V4 face/raw), and `poolKey12` (other-SE identity/raw). For every pair, `zeroForOne` means currency0 to currency1 and `oneForZero` is the reverse. Only leg 0 calls V4; leg 1 remains identity and leg 2 remains raw.
- **Assertion binding:** Replace exact-out success and exact-out PoolManager segments with zero-preview/`ExchangeOutNotAvailable` negatives. Refund unused user input and keep donation/compound remainders booked. Do not treat the V4 share as an unrated raw leg.
- **Composition:** `poolKey01` is the cross-vault case: V4 buffered and the other SE never converting under the outer unlock. Its backing PoolKey must differ from the other SE's backing PoolKey. Same-backing-pool sequential composition remains unverified; identity-only movement is not underlying entry/exit proof.

### 5. Weighted buffer hook

- **Behavior:** `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol`.
- **New row beside it:** `UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
- **Fixture and targets:** `SeMatrix_FullSpreadV4Fixture.sol` deploys the V4 vault, hookless backing PoolKey, both faces, and external provider. The V4 face is buffered and rated into token0 in the primary row and token1 in the second same-vault row.
- **Indices and legs:** Bind two configurations in this file. The 2-leg configuration is V4 face plus raw. The larger supported configuration is exactly 3 legs: V4 face, other-SE identity share, and raw. Sort each token array ascending as the package requires; `v4Idx` is the sorted position of the V4 face, `otherSeIdx` the position of the identity share in the 3-leg row, and `rawIdx` the raw position. `ses[v4Idx] = seUT`, the other-SE slot is identity-only, and the raw slot has SE zero. The V4 share has no product-pool currency index; it is inventory at `v4Idx`.
- **Exact input:** In the 2-leg row, exercise V4 face/raw in both `zeroForOne` and `oneForZero` directions. In the 3-leg row, exercise V4 face/other-SE identity and V4 face/raw in both directions. The raw leg transfers only, and the other SE never converts under the outer unlock.
- **Assertion binding:** Replace inherited exact-out success and PoolManager exact-out segments with zero-preview/`ExchangeOutNotAvailable` negatives. Refund unused user input, not book it; keep donation and compound remainders booked. Rate the V4 share on its buffered leg and do not classify it as raw.
- **Composition:** The 3-leg V4/other-SE pair is the cross-vault case and uses disjoint backing PoolKeys. The other SE remains identity-only. Same-backing-pool sequential composition stays unverified, and any no-`asset()` identity rejection is an FS-HOOK-04 record rather than a pass.

### 6. Curve quad stable buffer hook

- **Behavior:** `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol`.
- **New row beside it:** `UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
- **Fixture and targets:** `SeMatrix_FullSpreadV4Fixture.sol` supplies one V4 vault, its hookless backing PoolKey, token0/token1, and external provider. Use token0 for the primary `rateTarget` and token1 for the second same-vault row and second hook product pool.
- **Indices and legs:** Use exactly four valid legs: one V4 buffered face, one other-SE identity share, and two raw tokens. After ascending token sorting, record `v4Idx`, `otherSeIdx`, `rawIdx0`, and `rawIdx1`; `ses[v4Idx] = seUT`, the raw SE slots are zero, and the other SE is not converted. The V4 share is rated inventory at `v4Idx`, not a stable or raw peg.
- **Exact input:** Exercise V4 face/other-SE identity and V4 face/`raw0` in both `zeroForOne` and `oneForZero` directions, using each pair's sorted currencies. These are attempts against the real hook; any direction whose buffering path calls V4 `exchangeOut` must record the intentional rejection and must not be marked a success.
- **Assertion binding:** The inherited Curve seed/join path mints SE shares through exact-out, so those success bodies become enabled-vault `ExchangeOutNotAvailable` rejection records with unchanged balances. All other exact-out previews return zero where directly called. Unused exact-input user amounts are refunded; donation and compound remainders stay booked. Do not bypass the hook with a substitute mint route and call the row compatible.
- **Composition:** The V4/other-SE pair uses disjoint backing PoolKeys and no other-SE conversion under the outer unlock. Same-backing-pool sequential composition remains unverified. An identity rejection without `asset()` is FS-HOOK-04 and does not close the canonical dual proof.

### 7. Balancer quad stable buffer hook

- **Behavior:** `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol`.
- **New row beside it:** `UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
- **Fixture and targets:** `SeMatrix_FullSpreadV4Fixture.sol` deploys the V4 vault, hookless backing PoolKey, token0/token1, and external provider. Rate the same V4 share into token0 in the primary row and token1 in the second row with a second hook product pool.
- **Indices and legs:** Bind exactly two configurations, not the inherited fixed-four default. The 2-leg configuration is V4 buffered face plus raw. The 5-leg configuration is V4 buffered face, other-SE identity share, and three raw tokens. Sort each dynamic array ascending and record `v4Idx`, `otherSeIdx` in the 5-leg row, and every `rawIdx`; raw SE entries are zero. The V4 share is rated inventory at `v4Idx`, not a pool currency or raw peg.
- **Exact input:** In the 2-leg row, exercise V4 face/raw in both `zeroForOne` and `oneForZero` directions. In the 5-leg row, exercise V4 face/other-SE identity and V4 face/`raw0` in both directions. Any direction whose hook buffering calls V4 `exchangeOut` records the rejection rather than a pass.
- **Assertion binding:** The inherited Balancer seed/join success path uses SE exact-out minting, so replace it with enabled-vault `ExchangeOutNotAvailable` rejection and unchanged balances. Direct exact-out previews return zero. Refund unused exact-input user amounts and keep donation/compound remainders booked. Do not copy a fixed-four constructor or weaken the hook's other-family rows.
- **Composition:** The 5-leg V4/other-SE pair is the cross-vault case, with disjoint backing PoolKeys and no other-SE mint or redeem under the outer unlock. Same-backing-pool sequential composition remains unverified. A no-`asset()` identity rejection is an FS-HOOK-04 record, not a pass.

Section 3 has one blocking sentence outside this replacement. Replace “The matrix adapter is `SeMatrix_FullSpreadV4Fixture.sol` in that directory.” with “The matrix adapter is `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol`.” No other plan section needs to change for this matrix.

# Limits

This is a research binding only. It does not authorize implementation, hook redesign, or changes to the PRD or other families' assertions. No tests were run and no runtime compatibility is claimed. Exact numeric currency indices remain address-order computations at deployment. An actual identity-bind rejection must be recorded with its consumer, selector, arguments, and revert. Disjoint-pool composition does not verify same-backing-pool sequential composition.
