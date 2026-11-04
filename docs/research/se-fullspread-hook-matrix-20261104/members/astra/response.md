## Identity

- Run: `se-fullspread-hook-matrix-20261104`.
- Member: astra.
- Profile: research.
- Phase: initial independent response.
- Requested role: council-member.
- Requested model: `chatgpt-subscription/gpt-6-astra:high`.
- Actual runtime role, model, and reasoning setting: not exposed.
- Peers read before submission: no.

## Question and targets

Complete section 12 of the published Uniswap V4 full-spread implementation and testing plan with one specified binding per topology, including the additional target, index, and leg-count cases the PRD requires. This contribution specifies future tests; it does not report those tests passing.

The targets are:

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md`, read in full.
- The hook, rate-target, and matrix requirements in `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`.
- All seven real `*_SeMatrixBehavior.sol` files and all seven adjacent `*_SeMatrix_UniswapV3FullSpreadStandardExchangeVault.t.sol` files named by the brief.
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV3Fixture.sol` and `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol`, both read in full.

## Evidence

The following are source observations, not assertions that the proposed V4 rows already work. In this response, `H/` expands to `test/foundry/spec/hooks/uniswap/v4/standardExchange/`; `P` denotes the complete plan path above, and `R` denotes the complete PRD path above. These abbreviations also apply to line references.

| Source read | Observation |
| --- | --- |
| `P:49`, `P:200-216` | Section 3 places the adapter in the vault-spec directory. Section 12 instead needs the hook matrix; its seven behavior paths point into production directories and do not name the admitted behavior files. Section 12 also carries the return-tuple migration, which must survive replacement. |
| `R:216-218`, `R:480-522`, `R:596-613` | The external provider has `reserveVault`, `rateSubject`, and `rateTarget` arguments. The vault is the rate subject. Both underlying targets and separate pools holding the same vault are required. The family has no exact-output implementation. Unused user input is refunded, while donation and compound remainder is booked. |
| `H/SeMatrixFixture.sol:25-38`, `H/SeMatrixFixture.sol:59-140` | The existing adapter interface supplies shared deployment context, a selected face, the SE share, funding, partial-consumption controls, book observations, and the other AMM token. Its partial-case comments describe older book-not-refund behavior; they are not this family's product law. |
| `H/SeMatrix_FullSpreadV3Fixture.sol:76-87`, `:103-183`, `:239-289` | The reference fixture reuses a package, creates two face tokens and an independently seeded market, and bootstraps through production routes. Its sleeve controls, V3 reserve getter, and mocked V3 `mint` failure are V3-specific and cannot be copied as V4 behavior. |
| `H/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol:100-141`, `:196-215` | The wrapper binds `pairToken = face`, `standardExchange = se`, and a currency-sorted face/share pair. This is a wrap/unwrap hop, not a two-vault pool. |
| `H/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol:117-140`, `:208-221` | The CP single row binds the face, a raw token, the SE, and an external provider. The PoolManager currencies are the face and raw token; the hook holds the SE share as buffered inventory. |
| `H/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol:85-137`, `:154-178`, `:229-248` | The V3 row creates two fixtures and binds two face/SE/provider triples. Package leg numbering is distinct from the currency-sorted PoolKey order. Copying both buffered V3 legs is not the required V4 canonical cross-vault fixture. |
| `H/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol:89-168`, `:219-236` | The current row creates three same-family fixtures and sets `token0..2`, `se0..2`, and `rp0..2`; it opens all three pair doors. Its all-buffered assertions need adaptation for the mixed topology specified below. |
| `H/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol:70-105`, `:128-161` | The current row is two-leg, sorted by face/raw address, with weights `0.5e18` each. It binds the SE only at `faceIdx` and derives providers from matching token/SE arrays. |
| `H/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol:98-146`, `:172-217` | The current Curve row sorts four fixtures, builds fixed `address[4]` arrays, and expects every leg to be buffered. |
| `H/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol:37-69`, `:103-175`, `:248-270` | The current Balancer row has a fixed `LEGS = 4`, fixed-four temporary package arrays, and a four-leg assertion. Lowering `_seLegCount()` changes buffered-leg count, not total leg count. It does not produce the PRD's required two- and five-leg cases. |

The seven adjacent V3 row files were read completely. Their `_newFixture()` implementations preserve the same pattern: construct `SeMatrix_FullSpreadV3Fixture(_ctx(), sharedPkg)`, retain `f.pkg()`, and return `f`. The relevant ranges are single lines 13-20, CP single 11-19, dual 10-18, orbital 10-18, weighted 10-18, Curve 17-25, and Balancer 17-25. The Curve and Balancer V3 row comments at lines 10-16 explicitly explain that their positive rows became possible when V3 gained exact-output share minting. That is evidence against treating their existing success bodies as automatically applicable to this V4 family.

## Assumptions

1. A matrix binding is a concrete future test configuration, not a claim that an unread package implementation accepts it. The admitted sources do not include the rejecting package functions. I therefore do not invent an `asset()` rejection selector or report an identity bind rejected.
2. `V` is the new V4 full-spread share. `A = V.vaultTokens()[0]` and `B = V.vaultTokens()[1]` are its two ERC-20 faces. Both are distinct 18-decimal test tokens in this matrix fixture. The backing pool is initialized, hookless, and independently liquid.
3. The selected other-SE share is `W`, a real Uniswap V3 full-spread instance from the admitted V3 fixture. Its backing pair uses separate tokens `C` and `D`. Its shares are acquired outside the outer V4 unlock through exact-input production routes. The matrix does not assume that V3 supports conversion inside that unlock.
4. Logical leg numbers, sorted array indices, and a pair door's PoolManager currency indices are different concepts. The replacement specifies all three rather than asserting that a buffered share is a PoolKey currency when the admitted behavior uses its face there.
5. Stable-hook fixtures are denomination-controlled test markets, not assertions that a volatile full-spread share has a peg. All SE inventory uses the configured rate provider; no share is silently relabeled as an unrated raw token.

## Coverage

| Requirement | Binding in the replacement |
| --- | --- |
| Seven real behavior paths and adjacent new rows | Sections 12.2-12.8 |
| One shared V4 fixture and the V3 row shape | Section 12.1 |
| Both face targets, same vault in two pools, both pair index positions | Section 12.1 and each topology's target rows |
| Single and CP single exact-input directions | Sections 12.2-12.3 |
| Canonical dual cross-vault fixture | Section 12.4 |
| Three orbital legs, including another SE share | Section 12.5 |
| Weighted two-leg and larger supported setup | Section 12.6: two and four legs |
| Curve fixed four-leg setup | Section 12.7 |
| Balancer dynamic two- and five-leg setups | Section 12.8 |
| Exact-output rejection, refunds, maintenance remainder | Section 12.9, with per-topology inherited-body references |
| Disjoint backing pools and same-pool limitation | Sections 12.1 and 12.4 |
| Preserve return-width migration and historical evidence replacement | Section 12.10 |

One sentence outside section 12 must change. In section 3, replace **"The matrix adapter is `SeMatrix_FullSpreadV4Fixture.sol` in that directory."** with **"The matrix adapter is `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol`; the seven row files and their family-specific sibling behaviors live beside the existing hook-matrix behaviors listed in section 12."** The rest of section 3's prohibition on weakening other-family assertions remains. This is advice for the coordinator; this response does not edit that sentence.

## Conclusions

### 12. Hook integration and migration

**12.1. Shared fixture, notation, and target/index rows**

Use one new adapter file:

`test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol`.

It follows `SeMatrix_FullSpreadV3Fixture.sol` except for this family's package, pool, and refund tuple. Keep the `SeMatrixFixture` adapter and concrete-row `_newFixture()`/`sharedPkg` pattern. Deploy the V4 facets through their FactoryServices, the package through the IndexedEx manager registry path, and the vault through that package. Initialize its bound hookless backing PoolKey on the same real PoolManager used by the hook. Deploy two distinct face tokens, seed independent backing liquidity, and bootstrap `V` using its accepted public money routes before any hook operation. Do not seed the share balance directly.

The fixture exposes the vault `V`, both ordered faces `A` and `B`, and the bound backing PoolKey `K_V`. Its selected `faceToken()` is `A` in the primary row and `B` in the companion target row; `otherToken()`, `fund`, and `fundOther` follow that selection. Target selection is fixture configuration, not a change to `V.vaultTokens()` or the vault package arguments. The two target configurations must share the same deployed `V` in the explicit simultaneous-pools test; do not satisfy that test with two independently deployed vaults.

Deploy two real external `IStandardExchangeRateProviderDFPkg` instances:

- `R_A`: `reserveVault = V`, `rateSubject = V`, `rateTarget = A`.
- `R_B`: `reserveVault = V`, `rateSubject = V`, `rateTarget = B`.

The fixture makes these addresses available to the row. Bind `R_A` to the `A` row and `R_B` to the `B` row through the hook's existing supported rate-provider configuration. Use the same provider deployment facility as the existing matrix, with these explicit arguments; do not select a full-book provider merely because a helper's name contains `Cp`. Assert the actual instance arguments and that consumers decode `(amountOut, amountRefunded)` and use `amountOut` for valuation. The vault stores neither provider and exposes neither `getRate()` nor `asset()`.

Each topology's new `.t.sol` file contains a `RateTarget0` row (`T = A`, `R_T = R_A`) and a `RateTarget1` row (`T = B`, `R_T = R_B`). These are concrete test contracts or explicit test cases in that file, not alternate suggested bindings. Also test two live hook products using the same `V` simultaneously, one with each target/provider. For a pure wrapper, the external provider is still tested against its configured subject and target; the wrap/unwrap quote is not replaced with a rate multiplication. Do not add a rate-provider field to a package to make this test configuration fit.

The index convention is exact:

- For a currency-sorted pair of distinct tokens `X` and `Y`, `index(X) = 0` if `X < Y`, otherwise `1`; `index(Y) = 1 - index(X)`. `zeroForOne` spends currency 0; `oneForZero` spends currency 1.
- For a required ascending array `tokens`, `index(X)` is the number of entries whose addresses are less than `X`. Sort the complete token/SE/provider/decimals/weight record together. This formula, rather than deployment order, determines every index below.
- Exercise both physical index placements of the tested leg. The two-leg cases deploy counter-leg tokens or instances with addresses on the two sides of the tested token and assert the resulting currency indices before swapping. In the pure wrapper, deploy independent fixture instances for the index-placement controls if needed; retain the same-vault requirement separately for the two-target simultaneous-products test.
- In a buffered liquidity leg, the external token is `T`, while the associated reserve inventory is `V`. Thus `tokens[index(T)] = T` and `standardExchange(index(T)) = V` describe the share's inventory index. They do not mean the PoolManager currency is `V`. Only the pure single wrapper below has `V` itself as one of its two PoolKey currencies.

When another SE share is needed, use the one selected binding throughout: `W`, a real V3 full-spread vault from `SeMatrix_FullSpreadV3Fixture.sol`. Its face tokens `C,D` are disjoint from `A,B`. Acquire `W` shares before entering the outer unlock. Configure it as an identity leg with external token `W` and SE `W`, not as a `C -> W` or `D -> W` buffered conversion. Its configured external rate-provider instance is `R_W`, with `reserveVault = W`, `rateSubject = W`, and `rateTarget = C`; use controlled fixture denominations for this valuation and do not assume one share equals one face unit. The provider may read a quote; the hook must not execute a mint or redeem on `W` during the outer unlock. An identity-bind rejection must be recorded as described in section 12.9; it is not a passing cross-vault test.

For every row, assert that the hook's product PoolKey differs from `K_V` and that `K_V.hooks == address(0)`. In every multi-vault case, record the other vault's backing identity as well: the selected V3 instance has its own distinct backing pool and tokens, not a V4 PoolKey fabricated for a V3 pool. Where two V4 instances are used for a separate supported composition control, assert their actual backing PoolKeys differ. Do not reuse the same V4 backing PoolKey for the canonical proof. Same-backing-pool sequential composition remains **unverified**, not impossible, and is not proved by these disjoint-backing rows.

For each topology, add the named family-specific sibling behavior beside the existing behavior and the named concrete row beside both. Preserve the old behavior's assertions for its other concrete families. Use its TestBase, deployment path, router, and fixture interface; do not create a substitute hook or matrix harness. Override this family's virtual setup and affected test entrypoints. Where the inherited internal helper is non-virtual or hardcodes an incompatible leg count, use a family-local helper from those overridden entrypoints, rather than altering the shared helper or accidentally invoking the old setup first.

**12.2. `single/`: one face/share wrapper**

- Existing behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol`.
- New sibling behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4FullSpreadStandardExchangeVault_single.behavior.sol`.
- New row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
- Fixture: the shared `SeMatrix_FullSpreadV4Fixture.sol`, deploying `V`, `K_V`, `A`, `B`, and `R_A/R_B`.
- Binding: `standardExchange = V`, `pairToken = T`. The PoolKey is the sorted pair `(T,V)`. The share's currency index is `index(V)`; the face is `1 - index(V)`. There is no second SE leg and no separate raw liquidity leg.
- Targets: `RateTarget0` uses `T=A` and `R_A`; `RateTarget1` uses `T=B` and `R_B`. Check external provider configuration without inventing a provider slot on the wrapper or using the provider instead of the wrapper's executable previews.
- Directions: exact-input `T -> V` wraps and mints while unlocked; exact-input `V -> T` unwraps and burns while unlocked. Execute both `zeroForOne` and `oneForZero` with the sorted mapping above. This proves one-vault entry/exit, not the canonical dual cross-vault proof.
- Adaptations: the inherited exact-out tests at behavior lines 333-385, the exact-out halves of `test_row_poolManagerSwap_bothDirections_noFaceResidual` at 403-410, and the exact-out half of `test_row_previewMatchesExecution` at 471-483 become negative cases. `_mintSeSharesTo` at 185-192 itself uses exact-out and must not prepare any V4 test; mint a measured share balance using canonical exact-input before the unlock. Adapt `test_row_partialConsumption_bookedNotRefunded` at 237-265 to user-refund accounting and retain separate maintenance-booking cases. Keep resting pretransfers separate from operation refunds and preserve caller-fund isolation.
- Backing and cross-vault scope: apply section 12.1's disjoint backing/product key rule. Same-backing-pool composition is unverified. The canonical case is section 12.4, not an extra SE invented for this wrapper.

**12.3. `constantProduct/single/`: buffered face plus raw token**

- Existing behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol`.
- New sibling behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4FullSpreadStandardExchangeVault_constantProductSingle.behavior.sol`.
- New row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
- Fixture: the shared V4 fixture plus one distinct raw 18-decimal token `X`, which is neither `A`, `B`, nor `V`.
- Binding: `standardExchange = V`, `pairToken = T`, `rawToken = X`, `rateProvider = R_T`. The product PoolKey contains sorted `(T,X)`. At `index(T)`, the buffered inventory is `V`; at `index(X)`, inventory is raw `X` and `standardExchangeOf(X) = address(0)`. `V` is not a third PoolKey currency.
- Targets: run `(A,X,V,R_A)` and `(B,X,V,R_B)`, with two products sharing `V`.
- Directions: exact-input `T -> X` exercises the `T -> V` input buffering; `X -> T` exercises a `V -> T` output conversion. Execute `zeroForOne` and `oneForZero`; assert which conversion actually ran. The `X` leg is only transferred and has no hidden SE conversion.
- Adaptations: change the two exact-out success entrypoints at 313-375 and the exact-out halves at 395-402 into fail-closed cases wherever they require V4 exact-out. Replace the user-booking expectations at 240-265 with refunds; retain donation/compound book tests. Preserve deposit, withdrawal, rollback, pretransfer, and preview assertions that remain meaningful, decoding the V4 tuple and separating any user refund from resting hook inventory.
- Backing and cross-vault scope: `K_V` is hookless and distinct from the product key. Same-backing-pool composition is unverified. This raw-counterleg row does not replace section 12.4.

**12.4. `dual/`: the canonical cross-vault case**

- Existing behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol`.
- New sibling behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4FullSpreadStandardExchangeVault_dual.behavior.sol`.
- New row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
- Fixture: the shared V4 fixture supplies `V`, `K_V`, `A/B`, `R_A/R_B`; the existing V3 fixture supplies the selected other vault `W`, its independent `C/D` pool, and publicly acquired shares. Deploy `R_W` externally with the arguments in section 12.1.
- Binding: package leg 0 is `(standardExchange0=V, token0=T, rateProvider0=R_T)`. Package leg 1 is `(standardExchange1=W, token1=W, rateProvider1=R_W)`. The product PoolKey contains sorted `(T,W)`. `V` is the reserve share associated with the `T` leg at currency index `index(T)`; the other SE share `W` itself is the currency at `index(W)`. Do not confuse package `token0` with PoolManager `currency0`.
- Targets: `T=A/R_A` and `T=B/R_B`, with `V` shared between the two target products. Exercise both index placements of the tested leg.
- Directions: `T -> W` mints `V` shares under the borrowed unlock and pays already-owned `W`; `W -> T` transfers `W` in and burns `V` shares to pay `T`. Execute exact-input `zeroForOne` and `oneForZero`. Trace the V4 mint/burn and assert `W.totalSupply()` and `W`'s backing position do not change during the hook transaction. No `W.exchangeIn` or `W.exchangeOut` execution is permitted inside that outer unlock.
- Assertions: check user, hook, vault, and PoolManager balances; actual `V` share deltas; position owner `V`; stored full-range ticks and salt; and zero touched per-address currency deltas for `V` at return. Do not settle a foreign address's delta. Check positive output and no identity-route burn-for-zero.
- Adaptations: replace the default second buffered fixture and its assertions at 85-137 and 229-248 with the specified identity leg. Do not ask the V3 fixture to buffer its face during this call. Replace the exact-out success tests at 347-409 and exact-out halves at 429-436 with the negative contract. Adapt user-booking at 270-295 and maintain donation/compound booking separately.
- Rejection handling: attempt this exact identity binding. If the current package requires `asset()` or rejects identity, record its actual rejecting function, selector, arguments, and revert under FS-HOOK-04. Do not add `asset()`, mark the case passed, substitute a two-buffered composition, or claim that an unrelated raw-token route closes FS-A26. The canonical cross-vault proof remains open until this required route genuinely runs.
- Backing rule: use independent backing markets and distinct face pairs. The V3 pool has no V4 PoolKey; report that fact rather than claiming a fabricated second key inequality. The V4 product PoolKey must differ from `K_V`. A companion two-V4 backing-key control, when used to satisfy the literal two-key assertion in FS-A26, deploys a second V4 vault on a distinct initialized hookless `K_W` and uses its share only as the same identity leg; it is a distinct required key-observation control, not permission to turn on two buffered conversions. Same-backing-pool sequential composition remains unverified.

**12.5. `orbital/`: three named legs**

- Existing behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol`.
- New sibling behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4FullSpreadStandardExchangeVault_orbital.behavior.sol`.
- New row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
- Fixture: the shared V4 fixture, the selected V3 `W` fixture and `R_W`, and one distinct raw 18-decimal token `X`.
- Binding: exactly three package legs: index 0 `(token0=T,se0=V,rp0=R_T)`; index 1 `(token1=W,se1=W,rp1=R_W)`; index 2 `(token2=X,se2=address(0),rp2=address(0))`. `V` is buffered inventory at logical index 0, `W` is another-SE identity inventory at logical index 1, and `X` is raw at logical index 2. Use `standardExchange(uint8)` and `rateProvider(uint8)` to assert those bindings. Do not replace them with invented `standardExchange0()` getters.
- Targets: build this three-leg configuration once with `T=A/R_A` and once with `T=B/R_B`, sharing `V` in the simultaneous-products case.
- Directions: open all three pair doors `(T,W)`, `(T,X)`, `(W,X)`. Their currency indices are independently address-sorted. Run both exact-input directions on `(T,W)` and `(T,X)`, proving V4 mint on input buffering and V4 burn on output conversion. Run `(W,X)` in both directions as the identity/raw transfer control, with no conversion on `W`. This uses all three legs rather than only naming the third.
- Adaptations: the existing all-buffered assertions at 219-236 are false for the specified raw leg and must become per-role assertions. Replace exact-out success at 362-433 and 455-463 with fail-closed cases for paths that reach V4 exact-out. Adapt the user-booking body at 256-287 to refunds; retain maintenance remainder and caller-fund tests. Any unsupported identity bind is a cited FS-HOOK-04 record, not a passing three-leg conversion.
- Backing and cross-vault scope: enforce the disjoint markets/product-key rule in section 12.1, never call `W` conversion under the unlock, and retain section 12.4 as the canonical dual proof. Same-backing-pool composition is unverified.

**12.6. `weighted/`: two and four legs**

- Existing behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol`.
- New sibling behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4FullSpreadStandardExchangeVault_weighted.behavior.sol`.
- New row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
- Fixture: the shared V4 fixture and three distinct raw 18-decimal tokens `X,Y,Z`; no other SE is converted by this topology's required rows.
- Two-leg binding: sort records `(T,V,R_T,0.5e18)` and `(X,0,0,0.5e18)` by token address. `V` is the reserve share at `index(T)`; raw `X` occupies `index(X)`.
- Four-leg binding: sort `(T,V,R_T,0.25e18)`, `(X,0,0,0.25e18)`, `(Y,0,0,0.25e18)`, `(Z,0,0,0.25e18)`. All four weights sum to `1e18`; only `index(T)` is buffered. The other three indices are the ranks of `X,Y,Z` and have zero SE/provider entries. This chooses four, not an unspecified "larger" count.
- Targets: run both leg counts for `T=A/R_A` and `T=B/R_B`. In the two-leg submatrix, cover `index(T)=0` and `index(T)=1`. Retain the same-`V`, different-target simultaneous-products case.
- Directions: in the two-leg setup, run `T <-> X`; in the four-leg setup, run `T <-> X`, `T <-> Y`, and `T <-> Z`, with both exact-input currency directions on each pair door. Raw/raw doors are transfer controls, not V4 entry/exit proof.
- Adaptations: generalize only this family's array setup and amount builders; the current setup at 85-105 and `_amounts` at 128-132 are fixed to two entries. Replace exact-out success at 248-310 and 329-335 with the negative contract when V4 exact-out is reached. Replace the book-not-refund reconciliation at 179-209 with `declared input = consumed input + user refund`, keeping maintenance-booking tests. Do not use `reserveOfToken(face)` as an idle-book getter in the AMM fund-separation test at 401-416.
- Backing and cross-vault scope: `K_V` is hookless and distinct from every product key. Same-backing-pool composition remains unverified; the dual canonical proof remains section 12.4.

**12.7. `stable/quad/curve/`: fixed four legs**

- Existing behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol`.
- New sibling behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4FullSpreadStandardExchangeVault_curveQuad.behavior.sol`.
- New row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
- Fixture: the shared V4 fixture and raw test tokens `X,Y,Z`, in controlled target-denominated test markets.
- Binding: exactly four sorted records `(T,V,R_T)`, `(X,0,0)`, `(Y,0,0)`, `(Z,0,0)` in fixed `address[4]` token/SE/provider arrays, with the existing `DEFAULT_BASE_AMP`. At `index(T)`, reserve inventory is `V` and is rated by `R_T`; the other three indices contain raw tokens. Do not put `V` into an unrated raw slot or claim that its share has a peg.
- Targets: run the complete four-leg setup for `T=A/R_A` and `T=B/R_B`; retain two products holding the same `V`.
- Directions: open all six pair doors. Exercise `T <-> X`, `T <-> Y`, and `T <-> Z` as both exact-input currency directions. The three raw/raw doors are controls. Every claimed V4 conversion pass must show the actual `exchangeIn` mint or burn, not only a hook-level exact-input label.
- Adaptations: do not copy the four-buffered fixture loop or assert all legs are buffered. Most importantly, the existing V3 row explicitly relies on exact-output share minting. Any inherited `_seed`, proportional join, unbalanced join, single deposit, withdrawal, or swap path that reaches `V.exchangeOut` cannot remain a positive assertion merely because its public hook entrypoint says exact-input. Pin the enabled-vault zero preview/fail-closed behavior and record the actual hook consumer if the required exact-input route cannot execute. Do not manufacture shares or patch the hook to get past seeding.
- The explicit exact-out success bodies at behavior lines 312-374 and 396-402 become negatives; the user-booking body at 240-265 becomes a refund test. Maintenance remainder cases remain and must not disappear behind a failing `_seed`. Retain preview/execution and rollback checks on the paths that genuinely execute. A failed seed cannot cause the rest of the row to be logged as passed.
- Backing and cross-vault scope: apply section 12.1's disjoint-key rule and keep same-backing-pool composition unverified. This mixed raw/SE stable row does not replace section 12.4.

**12.8. `stable/quad/balancer/`: dynamic two and five legs**

- Existing behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol`.
- New sibling behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4FullSpreadStandardExchangeVault_balancerStable.behavior.sol`.
- New row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
- Fixture: the shared V4 fixture and four distinct raw 18-decimal test tokens `X,Y,Z,Q`, in controlled target-denominated markets.
- Two-leg binding: sorted dynamic records `(T,V,R_T)` and `(X,0,0)`.
- Five-leg binding: sorted dynamic records `(T,V,R_T)`, `(X,0,0)`, `(Y,0,0)`, `(Z,0,0)`, `(Q,0,0)`.
- For each count, `V` is the rated reserve share at `index(T)`, and all other indices are the ranks of their named raw tokens with zero SE/provider entries. Assert `numTokens()==2` and `numTokens()==5` respectively. Keep the existing stable amplification choice. Do not treat the share as a peg or an unrated raw leg.
- Targets: run both counts for `T=A/R_A` and `T=B/R_B`, with the two index placements in the two-leg case and simultaneous products sharing `V`.
- Directions: the two-leg setup runs `T <-> X`. The five-leg setup runs `T <-> X`, `T <-> Y`, `T <-> Z`, and `T <-> Q`; each pair runs `zeroForOne` and `oneForZero` exact-input. Open all ten pair doors in the five-leg setup and keep raw/raw pairs as controls.
- Adaptations: the shared behavior's `LEGS=4`, `address[4]` temporaries, four-token funding, and `numTokens()==4` assertion must not control this family's two/five setup. Overriding `_seLegCount()` alone is insufficient. Use family-local dynamic-array helpers from overridden setup/test entrypoints, while retaining the existing package/TestBase/router infrastructure and leaving other families untouched.
- The V3 row's exact-output-mint dependency applies here too. An exact-input-named hook route that invokes V4 exact-out is a negative or unresolved integration case, not a pass. Replace explicit exact-out success at 386-448 and 468-474; adapt user-booking at 292-317 to refunds; retain maintenance-booking, preview, pretransfer, and atomic rollback coverage independently of an unsupported positive seed.
- Backing and cross-vault scope: apply section 12.1's disjoint-key rule, retain section 12.4 as the canonical dual proof, and leave same-backing-pool sequential composition unverified.

**12.9. Required family adaptations and result classification**

These requirements apply to every topology above.

1. **Exact output.** On an enabled V4 vault, `previewExchangeOut` returns zero and `exchangeOut` reverts `ExchangeOutNotAvailable()`, with no token movement, burn, mint, or book change. Assert these directly in both face/share directions. For a hook route, record the actual rejection boundary: a hook may reject the zero preview before dispatch, or the vault rejection may be propagated or wrapped. Do not invent the wrapper's selector. A route that calls V4 exact-out cannot be a success. An identity-only route which never calls V4 exact-out is a separate case and does not prove V4 entry/exit.
2. **Exact-input success.** Measure both actual V4 conversion directions, not merely the signed PoolManager direction. The caller reaching the borrowed V4 path must have code, hold and pay the input, and use `pretransferred=false`. Assert allowance and real payment on unwrap as well as wrap. Retain same-state output preview equality and the caller minimum. Read both words of the widened tuple.
3. **Unused user input.** Replace `test_row_partialConsumption_bookedNotRefunded` for this family with a nonzero-refund case driven by real supported pool state and rounding, not a V3 sleeve or a mocked capacity gate. At the vault boundary, reconcile declared input, consumed input, refund to `msg.sender`, and output to `recipient`. At the hook/router boundary, trace that operation refund to the entitled caller and distinguish it from old hook inventory. Do not relabel a user refund as booked inventory, swallow it under dust tolerance, or set `hasPartialCase=false` merely to evade refund coverage. Include a no-refund control.
4. **Donation and compound remainder.** Keep separate positive remainder cases. An authorized donation/compound call executes while the manager is locked, books actual leftover inventory, and does not refund it. A later permitted maintenance call may process it. Assert the no-op compound case and marker-event rules from section 9. Do not invoke maintenance inside the outer unlock to construct this fixture: those routes reject `ManagerAlreadyUnlocked`. Do not use the user's unspent deposit as the donation remainder.
5. **Book observations and caller-fund separation.** `reserveOfToken` describes deployed position amounts plus unpaid position fees, not a local sleeve. Replace old unchanged-reserve assertions with measurements of this family's booked balances and known unbooked transfers, using test-side observations without adding a production getter or modifying storage. A new caller's deposit may legitimately change position reserves and price. It must not take prior local inventory as that caller's input/refund or mint against other holders' booked/fee inventory. The V3 fixture's `localReserve`, sleeve controls, and next-invest sweep assumptions are not V4 contracts.
6. **Failures and isolation.** Retain resting-transfer isolation, EOA-pretransfer rejection where the hook exposes that route, positive output delivery, rollback, and provider valuation checks. Do not copy `vm.mockCallRevert` against the backing PoolManager or the V4 vault from the V3 fixture. Use production execution and the applicable family failure conditions. Record balance, supply, book, and delta changes before and after a failure; a revert must not be counted as a positive conversion.
7. **Unresolved integration records.** For an actual identity, `asset()`, pair-overlap, missing-quote, or denomination rejection, record the consumer path and function, selector, concrete arguments, and exact revert bytes. Say which requested row is blocked and why that topology cannot express it, if that is what the evidence establishes. This is FS-HOOK-04, not a passing bind. It does not close FS-A26 or waive either FS-OWN-29 target row. A missing configured provider is not an incompatibility disposition. Do not add an interface, `asset()`, or a stub quote to erase the record.
8. **Gas.** Preserve the existing whole-transaction composed-route ceiling. A route above 12,000,000 gas is unresolved, not passed; preview ceilings remain 5,000,000. Provider evaluation and hook work are not a reason to omit parts of the measured composed transaction.

**12.10. Migration and matrix evidence**

Migrate every one-word reader of `previewExchangeIn` listed in `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md` to `(uint256 amountOut, uint256 amountRefunded)`. Also migrate every one-word decoder of `exchangeIn`, including implementations, overrides, typed ignored-return callers, low-level decoders, the six length gates, the three ABI bindings, helpers, tests, scripts, and generated ABI artifacts. Do not paste the index. Consumers that value the result use `amountOut`, not the refund word. The migration must compile repo-wide. Known production assignments that will not compile against the widened return are `UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib.sol` and `ComposedStableCommonDetfCommon.sol`. Those two lines are examples, not the whole set.

Preserve all current V3 matrix rows and other families' assertions. Replace stale historical V4 FullSpread evidence only with results from the newly named V4 rows. Update the FS-TEST-04 evidence destinations: `hook-se-matrix.json`, `hook-se-matrix-findings.json`, `hook-se-matrix-finding-descriptions.json`, `docs/audits/apex-2026-09-17-evidence.md`, and `docs/audits/apex-2026-09-17-evidence/acceptance.json` item R10.3, with the JSON files under `docs/audits/apex-2026-09-17-evidence/`.

Each result identifies topology, leg count, face target, provider instance arguments, token-index map, share inventory, backing identity, direction, actual conversion calls, refund/book result, and pass versus intentional rejection versus unresolved integration. Neither the historical compatibility label nor the existence of this completed matrix is runtime evidence.

## Limits

This is an independent research contribution, not an implementation authorization and not a replacement already applied to the published plan. No tests, builds, installs, deployments, wallet operations, Git commands, or sub-agents were used. No peer files were read. Only this response file was written.

The admitted behaviors and V3 rows establish harness shape and inherited expectations. They do not establish acceptance of the selected new identity binds, the exact rejection bytes of an unread hook consumer, or runtime gas. The single wrapper's admitted behavior delegates package arguments to its inherited TestBase and does not expose a provider member assignment in the file read; this response therefore does not invent such a member. Likewise, the admitted Balancer behavior demonstrates a fixed-four test wrapper, while the PRD requires the dynamic two/five package topology. The future implementation must use that package's existing interface, not pretend the fixed-four wrapper already exercises those counts.

The literal FS-A26 two-V4-PoolKey control is explicitly separated from the canonical V3 identity-counterleg case because a V3 pool is not a V4 PoolKey. The distinction preserves the required key assertion without claiming that reading these sources proves either cross-vault execution.
