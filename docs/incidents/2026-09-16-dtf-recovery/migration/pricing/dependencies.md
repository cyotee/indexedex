# Frozen Migration mint-quote dependency contract

Date: 2026-11-10. Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-02`.

**Result:** a finite capture/evaluation design is available for the inspected weighted fixtures. Existing public queries are not, by themselves, a closed frozen evaluator. In particular, buffered raw reserves lack a truthful getter, and SE transition bytes are not a promise of read-free evaluation. The proposed changes below close those gaps without changing ordinary quote behavior. This initial dependency report does **not** close E3, complete plan task 2, establish actual deployment bindings, or resolve fungible ancestry or TokenStaking ownership.

## 1. Calculation and source boundary

The controlling inputs are the phase-two brief and the copied `MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` sections 1-6 and task 2. Phase-one `migration/evidence/phase01-verification.md:301-327` expressly permits this work independently of E2. No eligibility, custody, surrender, allocation or reward policy is decided here.

All source paths below are relative to this worktree. For compact references, the following names denote the **complete file paths** in this table; subsequent `NAME:line` references expand to those paths, not to another version of the file.

| Name | Current source anchor and responsibility |
| --- | --- |
| Entry | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfTarget.sol:175-195`: mint preview |
| Common | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:115-127`, `:151-181`, `:259-263`: p, route resolution, pair equivalent, uplift and gross |
| Split | `contracts/vaults/detf/common/core/DETFMintSplitLib.sol:19-26`: independently floored user/pot outputs |
| Claim | `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol:39-99`, `:136-193`, `:401-407`: rated reserves, fee, inflow, budget, disable query |
| Math | `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol:32-37`, `:48-75`, `:89-104`, `:206-230`: scales, fee, weighted exact-input |
| HookRepo | `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookRepo.sol:37-65`: stored book |
| HookQueries | `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol:128-224`, `:313-318`, `:410-415`: getter meanings and reserve synchronization |
| HookDispatch | `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookInQuoteBase.sol:14-31`; `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget.sol:20-30`: standard exact-input dispatch |
| Context | `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol:19-56`, `:116-150`: rate, ERC165, snapshot, deposit/redemption results |
| Legs | `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol:53-118`, `:144-163`: external-operation projection and projected rate |
| Receipt | `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:34-75`, `:84-112`, `:130-155`, `:214-219`: ordinary ERC4626-SE preview |
| Backing | `contracts/vaults/standard/erc4626/ReceiptBackedERC4626AccountingLib.sol:19-30`, `:45-80`: booked-cash backing and receipt/share arithmetic |
| ReceiptState | `contracts/vaults/standard/erc4626/ERC4626StandardExchangeQuoteTarget.sol:15-60`, `:63-147`, `:204-349`: serialized state and remaining live calls |
| V3In | `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol:21-43`, `:72-83`, `:178-213`: ordinary V3 previews |
| V3Common | `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:125-127`, `:183-205`, `:215-253`, `:299-395`, `:457-483`, `:624-640`: locks, policy, swaps, reserves, fees and deposit math |
| V3State | `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInQueryTarget.sol:26-60`, `:109-164`, `:177-224`, `:272-367`: transition state and evaluation |
| CP | `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol:16-77`, `:110-126`: V3 deposit and blocked exit math |
| V3Quoter | `lib/crane/contracts/utils/math/UniswapV3Quoter.sol:15-22`, `:109-157`, `:168-211`, `:221-271`: actual pool reads, unlimited traversal and liquidity projection |
| Morpho | `contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeCommon.sol:73-101`, `:145-178`: offset, accrued NAV and ordinary previews |
| MorphoState | `contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeQuoteTarget.sol:20-47`, `:50-129`: capture and transitions |
| Provider | `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:47-134`: current/projected whole-book rate |
| Result | `contracts/utils/ExchangeInAmount.sol:15-21`, `:41-50`: output/refund tuple validation |

The branch to reproduce is:

1. Resolve the accepted mint input to its configured SE and the **first** matching hook pair in DETF hook-pair order. `_tryHookPairOfVault` matches either the mint-table mapping for that pair or `hook.standardExchangeOf(pair)`; do not invent an address-sorted match.
2. `_pairEq`: if input equals that pair, return the original native input unchanged. Otherwise use the configured SE's ordinary `previewExchangeIn(input, amount, pair).amountOut`. That particular call ignores its refund word. A non-share input yielding zero is `InvalidRoute`; a share input may yield zero and reach the next quote's zero-domain error.
3. `boosted = Math.mulDiv(pairEq, W + p, W)`.
4. Hook ordinary `previewExchangeIn(pair, boosted, detf)` dispatches to weighted exact-input, with **manager = zero**. It is not the hook's LP mint route because output is DETF, not the hook LP.
5. `user = DETFMintSplitLib._splitLiveGross(gross, p).userDetf`. Sum separately evaluated original ETH and DTF components. Return zero immediately for a zero original component.

`Entry:181-190` also reads reserve-live/route membership, a self-call pair preview, synthetic-price gating and projected expansion, and can select a swap fallback. Migration deliberately evaluates the specified **mint branch**, even below its ordinary gate. Consequently synthetic creation prices, thresholds, outstanding DETF supply, owned LP, epoch timestamps, pending expansion and price-gate/swap-after-exchange state are **not evaluator dependencies**. Capture verifies the funded/live setup and accepted routes, but evaluation never runs that gate, opening-bond pricing or fallback. Omitting those operations is the accepted branch selection, not replacing their result with a made-up price.

## 2. Capture and evaluation API contract

Proposed semantics, not an assertion that these functions already exist:

```solidity
// Called internally by the one-shot Migration administration operation.
captureConfiguredMintBook() -> FrozenMintBook

// Pure arithmetic except reads of already sealed snapshot storage/capsules.
evaluateOriginal(FrozenMintBook S, address contribution, uint256 amount)
    -> (uint256 pairEquivalent, uint256 grossDetf, uint256 userDetf)

// Two narrow, typed, read-only source extensions:
hook.captureWeightedMintBook() -> WeightedBook
se.captureFrozenQuoteInputs(address asset, address holder, CaptureMode mode)
    -> TaggedFamilyInputs
```

`CaptureMode` is a closed enum: OrdinaryInput, OrdinaryRedemption, TransitionRedemption. `TaggedFamilyInputs` is the closed union of the field schemas in sections 5-7, with family/version and requested mode; unknown tags fail. `FrozenMintBook` contains version, chain ID, Migration proxy, capture block number/timestamp, hook identity, accepted ETH-to-WETH identity mapping, original DTF identity, p, ordered routes, `WeightedBook`, and the family payloads actually needed by those routes. The current block's hash is not available through `blockhash(block.number)`; a prior-block hash can be provenance, not a replacement for the captured values. Snapshot identity domain-separates the version, chain, proxy and captured contents. Numeric input is read from configured contracts, not supplied as a price by the owner.

Capture runs in one protected transaction after funding. No external money operation, pool unlock, token movement, issuance, expansion settlement or executing rebalance occurs during it. Source reads are static. Provider/query getters may internally simulate canonical quotes; capture does not carry their projected state into another source read. Commit only after every required payload and route is validated. A failed capture leaves no installed snapshot or partially sealed pool. No recapture, mutation, callback-controlled evaluator address, proxy upgrade or lazy fetch is allowed. The retained evaluator accepts only original contributions and this sealed state; configuration changes cannot replace a sealed dependency.

**Bound:** the hook has 2-8 legs (`HookRepo:25-32`, `:91-93`). There are exactly two recovery contribution identities, hence at most two additional directly selected route SEs beyond the hook's SEs. Deduplicate by `(SE, asset, holder, quote mode)`, not just SE address: ordinary conversion, hook buffering and holder-constrained redemption have different semantics. The concrete family schemas below are fixed-size except an explicitly bounded V3 pool image. An unrecognized family or unclosed native nested vault is an explicit capture failure, never an invitation to follow arbitrary dependencies indefinitely. This is an engineering coverage limit, not removal of a legacy eligibility category.

Evaluation may use linked **pure** canonical math and immutable snapshot storage. It must not call the original hook, SE, rate provider, registry, fee oracle, token metadata, pool or `supportsInterface` again. A frozen V3 query capsule, if used, contains only the captured pool image and has no setters, upgrade route or fallback to the original pool. A view call to such sealed data is not a live-market read. Pin evaluator code at deployment; do not let future loupe/provider changes select different arithmetic.

## 3. Weighted book: exact fields, units and accessibility

Every field in the following table is copied to snapshot-owned storage or sealed data. Evaluation uses that copy, which is why subsequent mutation of the listed source cannot affect it.

| Captured field | Native units / meaning | Real contract query surface, or exact missing accessor |
| --- | --- | --- |
| `tokens[]`, count, input/output indices | Addresses; pool order, including native nine-decimal DETF self-leg | `tokens()`, `numTokens()`, `token(i)`; `HookQueries:136-150`; public wrappers in `UniswapV4StandardExchangeWeightedBufferHookHooksTarget.sol:333-344`. Check indices by address, not assumed sort/weight position. |
| `standardExchanges[]`, provider identities | Addresses; zero is semantically distinct from identity `se == token` | `standardExchange(i)`, `rateProvider(uint256)`, `rateProviders()`, `standardExchangeOf(pair)`; `HookQueries:156-165`, `:254-256`; `UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget.sol:189-201`. |
| `weights[]` | WAD fractions | `getNormalizedWeights()` / `weight(i)`; `HookQueries:148-154`. Preserve exact integers, including asymmetry. |
| `invScales[]`, `ratedScales[]` | `10^(36 - inventoryDecimals)` and `10^(36 - pairDecimals)` respectively; not token rates | `invScale(i)`, `ratedScale(i)`; `HookQueries:168-174`. Inventory decimals refer to SE shares on buffered legs. Use captured scales, not later `decimals()`. |
| `rawReserves[]` | Native pair-token units retained/booked by hook | **Missing for buffered legs.** Add them to `captureWeightedMintBook()` directly from `HookRepo.Layout.rawReserves`. `nativeReserve(i)` returns SE shares, not raw cash, when an SE is bound (`HookQueries:313-318`). `reserveOfToken(pair)` is also unsuitable: `_syncVaultReserves` stores `_nativeAt(i)` (`HookQueries:410-415`). |
| `seReserves[]` | Native SE-share units attributed to hook inventory | Existing `seBalance(i)` returns the stored `seReserves[i]` (`HookQueries:188-192`). Never use ambient `IERC20(se).balanceOf(hook)` as the reserve. Raw legs have zero SE inventory. |
| Provider read result for each possibly used provider | Success flag and raw return bytes; on success exactly one nonzero WAD whole pair tokens per whole inventory share | Call `IRateProvider.getRate()` in **hook caller context**; validation is `Claim:93-99`. Aggregate hook capture preserves this context and distinguishes absent, failing, malformed and zero providers. Do not eagerly reject an unused failing provider if the canonical branch would not read it. |
| Hook swap fee | WAD input fee, not V4 pips | `feeOracle().dexSwapFeeOfVault(hook)` / `dexSwapFee()` (`HookQueries:128-130`, `:217-219`; `Claim:48-50`). Must be `< W`. Capture from hook context, do not use SE usage fee or fee-override pips. |
| Registry identity, per-SE package lookup result and disabled result | Address, registered/not registered, boolean; retain query failure when relevant | `vaultRegistry` is in `HookRepo:61` and has no getter in the inspected hook binding surface; expose through aggregate capture. Call its `packageOfVault(se)` and `isDisabled(se)` exactly as `Claim:401-407`. Unknown registration is `BufferFailed`, not enabled. Read only for nonzero SE legs when that branch needs it. |
| Nested ordinary deposit recipe, and output redemption recipe if reached | Typed state, not an amount-independent conversion multiplier | Sections 5-7. Input ordinary preview is `Claim:69-73`. Output uses `Context.redeemResult`, including its ERC165/transition branch (`Claim:151-167`; `Context:137-150`). |
| DETF mint-route membership, selected SE, resolved pair, pair order | Addresses and boolean | Migration capture can read its own `UniswapV4DetfRepo.Storage.mintTable/hookPairTokens`; public mint-route query is `Entry:67-69`. Resolution is `Common:154-181`. Copy the resolved route, not a pointer to a future route lookup. |
| Seigniorage `p` | WAD | Migration's configured fee oracle `seigniorageIncentivePercentageOfVault(Migration)`; zero oracle means zero (`Common:115-119`). Use the same captured p for uplift and split; no second live fee read (`Common:121-127`, `:259-263`). Preserve subtraction/overflow behavior rather than clamping an invalid p. |
| Setup/provenance | Booleans and addresses | Own `isReserveLive`, hook `isLive()`, expected self-leg, route identities and capture context. Require a funded quoteable book before sealing; these checks do not mint or prove task-3 bootstrap. |

`ratedBalance(i)` returns **native rated pair units**, not WAD; `ratedBalances()` is therefore not a substitute for scales or the full book (`HookQueries:204-214`, `:328-330`). `seClaim(i)` is a trade-sized live SE preview, not D60 reserve valuation (`HookQueries:194-201`). Capture can store derived rated values for reconciliation, but raw/SE inventories, scales, rates and nested recipes remain the evaluator inputs.

Provider implementation internals do not have to be replayed after capture: the canonical manager-zero path reads the current `getRate()` value, so its exact successful return is a valid frozen primitive. This does **not** turn the overall quote into a scalar-rate approximation. `Provider:51-134` obtains supply, metadata and full-book or zero-supply deposit previews, with upward normalization; those potentially complex reads happen at capture in the original provider. Failed/short/zero returns retain fail-closed meaning. `quoteRate` and its live-independent-subject fallback must not be called during frozen evaluation.

## 4. Exact frozen weighted evaluation

Use the existing Math functions with the same arguments, expression order, checked products, floors and reverts. Do not algebraically combine adjacent divisions or replace checked multiplication with a more permissive operation just because the final rational expression looks equal.

Let `scale(x,s) = Math.scaleTo(x,s)`, `unscale(x,s) = Math.descale(x,s)`, and `RPU(x,r,inv,rated) = Math.ratedPairUnits(x,r,inv,rated)`.

1. First reject zero hook input, identical tokens and invalid indices, in canonical order (`Claim:42-45`). Then build **all** rated balances, in order, as `Claim:57-60`, `:77-90` do:
   - No SE and no provider: `units = raw`.
   - No SE with provider: `units = RPU(raw, rate, invScale, ratedScale)`.
   - SE with zero stored SE shares: `units = raw`, with no provider read.
   - SE with nonzero shares: require a provider, then `units = raw + RPU(seShares, rate, invScale, ratedScale)`.
   - `rated[i] = scale(units, ratedScale[i])`.
   All-leg construction matters: an invalid rate on another held leg can fail an otherwise two-leg quote.
2. Check nonzero rated input/output. `net = boosted - floor(boosted * swapFee / W)` once (`Claim:47-53`, `Math:100-105`).
3. Map **net**, not boosted, into rated input (`Claim:63-73`):
   - No SE: `units = net` without provider; otherwise `units = mulDiv(net, rate, W)`. Then scale. This input expression differs from the held-reserve `RPU` expression; preserve it.
   - Nonzero SE: registry unknown fails; disabled yields `scale(net, ratedScale)` without a deposit preview.
   - Enabled SE: evaluate the **ordinary** frozen `previewExchangeIn(pair, net, se)` to `(shares, refund)`; check `refund <= net`. If shares are zero, inflow is `scale(refund, ratedScale)` with no rate read. Otherwise inflow is `scale(refund + RPU(shares, rate, invScale, ratedScale), ratedScale)`.
   - Do not special-case `se == pair` into this input branch unless that SE's actual ordinary identity preview does so. The source still calls its preview and checks its registration. `_pairEq` identity is a different, earlier bypass.
4. Enforce `inflow <= rated[i] * MAX_IN_RATIO / W`, then call existing `Math.quoteExactIn(rated[i], weights[i], rated[j], weights[j], inflow, W, W, 0)`. Thus the fee is not charged again. Preserve zero-rounded output, Balancer pow rounding and domain errors. Reject `budget >= rated[j]` (`Claim:138-147`).
5. Output is **not** simply budget divided by a rate (`Claim:150-167`):
   - `nativeBudget = unscale(budget, ratedScale[j])`; `local = min(raw[j], nativeBudget)`.
   - No SE: output is `nativeBudget`, and `output >= raw[j]` fails. This branch does not invert a configured rate provider, even if one exists; preserve the actual source.
   - SE: `deficit = nativeBudget > local ? budget - scale(local, ratedScale[j]) : 0`. Preserve rated dust in this expression.
   - Nonzero deficit: read frozen provider rate; `sharesOut = floor(floor(deficit * W / rate) * W / invScale[j])`. The **two floors** are deliberate. Fail when `sharesOut > stored seReserves[j]`. For nonzero shares, run the frozen redemption result in section 5, 6 or 7, require zero share refund (`UnwrapFailed` otherwise), and add its **asset output** to local. For `se == pair`, Context returns `(sharesOut, 0)` immediately, without ERC165, holder or transition reads (`Context:137-140`); preserve that identity branch. Zero total output fails.
6. Split gross with captured p using Split; keep only user credit. No reserve, holder or nested-SE state from this component is committed or passed to the next component or entitlement. Within a nested transition, its own next-state calculations still occur if canonical evaluation performs them.

The canonical mint quote's manager is zero. Therefore `pairInWithContext`, `ratedWadAllWithContext`, unavailable-unlock projection, projected provider `quoteRate`, and `Legs.afterExternalExchange/afterExternalDeposit` are not invoked by this branch. They are used by different hook entry routes (`Claim:45-52`, `:170-195`; `Legs:53-118`). Do not accidentally substitute the swap-fallback's projected post-conversion book for the required unchanged book. Nevertheless, **manager zero does not eliminate nested transition evaluation on output**: `Context.redeemResult` still captures `quoteState` whenever transition ERC165 is advertised.

The minimal factor boundary is an acyclic pipeline, not an opaque callback into the old hook:

| Proposed internal helper | Inputs and result; permitted dependencies |
| --- | --- |
| `ratedBook(book)` | All captured raw/SE amounts, scales and provider results -> rated array. Validate rate failures only where the original rating reads them. |
| `ratedInput(leg, net, depositResult)` | Captured leg plus the typed family's ordinary result at this exact net amount -> rated inflow; disabled/no-SE branches bypass the result. No original-SE call. |
| `swapBudget(book, rated, i, j, inflow)` | Existing Math exact-input call and ratio checks -> rated output budget. Pure. |
| `outputPlan(leg, budget)` | Captured raw/SE balances, scales and provider result -> native local output and exact shares-to-redeem. Pure; preserve zero-share/deficit branches. |
| `finishOutput(plan, redemptionResult)` | Add local and typed redemption output; enforce refund and zero-output checks. The identity-SE plan bypasses a redemption recipe. |

Migration performs the amount-dependent typed deposit/redemption evaluations between these stages using sections 5-7. The ordinary ClaimLib wrappers keep gathering their live inputs and calling the same factored arithmetic. This avoids a family-aware import in the DETF's ordinary mint code and avoids changing ordinary nested-call order.

## 5. ERC4626-SE recipe: fields rather than a one-share quote

### 5.1 Ordinary conversion and buffering

Receipt's ordinary previews use the following captured state:

| Field | Units | Acquisition / exact missing contract |
| --- | --- | --- |
| Wrapper SE address, protocol vault, underlying | Addresses | `protocolVault()` / `_underlying()` (`Receipt:84-90`), vault `asset()`. Record route identity. |
| Wrapper issued supply `S` | Native wrapper shares | `IERC20(se).totalSupply()`. |
| Held receipt tokens `H` | Native protocol-vault shares | `IERC20(vault).balanceOf(se)`. |
| Booked local cash `L` | Native underlying | `IBasicVault(se).reserveOfToken(underlying)`; public implementation `contracts/vaults/basic/MultiAssetBasicVaultTarget.sol:20-22`. Do not substitute all live cash or cap it by balance in the **backing** calculation. |
| Receipt conversion model | Tagged exact implementation plus `A`, effective `V`, virtual assets `a`, virtual shares `v` | Actual `totalAssets()`, `totalSupply()`, metadata and a source-specific exact effective-supply getter where fees add virtual shares. The SimpleYield fixture has `a=v=0`, and explicit empty-asset/supply branches (`contracts/test/stubs/SimpleYieldERC4626.sol:100-145`). ReceiptState's `VirtualVault` also encodes these fields (`ReceiptState:204-246`, `:249-265`). |
| Conversion/preview distinctions | Versioned model discriminator, any directional fee/cap policy actually used by the admitted vault | **Missing general guarantee.** A single successful ratio probe is not proof that arbitrary ERC4626 previews follow that ratio. `captureFrozenQuoteInputs` must certify a reviewed exact model, not guess from a unit preview. Unknown/noncanonical vault code is unsupported until its own finite recipe is supplied. |

Compute frozen `B = H + convertToShares(L)` when L is nonzero, otherwise H (Backing). Preserve the original receipt conversion's product/rounding and empty-state branches. Then Receipt's entire relevant ordinary routing is bounded:

- SE -> same SE: amount unchanged.
- Underlying -> SE: `receiptEquivalent = frozen convertToShares(amount)`; output is receiptEquivalent when S or B is zero, otherwise checked `receiptEquivalent * S / B`.
- Protocol receipt -> SE: same wrapper conversion applied to the native receipt input.
- Underlying -> protocol receipt: frozen **previewDeposit**, not blindly convertToShares.
- Protocol receipt -> underlying: frozen **previewRedeem**.
- SE -> protocol receipt: checked `amount * B / S`, or zero for S zero.
- SE -> underlying: the preceding receipt claim, then frozen previewRedeem, with Receipt's zero-claim early return.

Ordinary ERC4626-SE preview refunds are zero: the public wrapper is `contracts/vaults/standard/erc4626/ERC4626StandardExchangeInTargetExt.sol:12-18`, over Receipt's amount-only return. Capacity-limited underlying investment is a different execution operation: it books uninvested underlying, not a partial-input refund (`Receipt:141-155`; `ERC4626StandardExchangeInTarget.sol:53-65`). Do not insert `maxDeposit` into this ordinary quote or deduct the dilution usage fee from the user's quoted shares.

### 5.2 Output redemption transition

Capture the transition-support boolean once. If false, use the ordinary recipe above and its refund. If true, the canonical branch calls `quoteState(pair, hook)`, then `quoteTransition(state, RedeemExactIn, sharesOut)` and converts consumed shares into a refund (`Context:137-150`; Result). Required state is **all fields of ReceiptState.QuoteState**:

- `exchange`, `vault`, `asset`, `holder`: addresses.
- `holderShares`, `supply`, `vaultShares`, `nativeExcludedShares`, `receiptBacking`: native SE shares for the first two, native receipt units for the last three.
- `localUnderlying`: native underlying units.
- `nativeQuote`: boolean; `vaultState`: the exact tagged underlying state.
- For its direct VirtualVault: `assets`, `virtualAssets` in native underlying; `supply`, `virtualShares`, `heldShares`, `pendingHeldFee` in native protocol shares.
- Frozen underlying identity, conversion model and wrapper fee-recipient/usage-fee values if the factored transition helper retains deposit support. `feeTo` is an address; usage fee is WAD. Neither is a haircut on RedeemExactIn.

Existing `quoteState` exposes the bytes, but reusing the live SE to evaluate them is forbidden. It still reads `protocolVault()`, `_underlying()`, live fee settings in deposits, nested SE methods, and live `IERC4626.convertToShares(localUnderlying)` in `_syncQuoteBacking` (`ReceiptState:65-96`, `:129-136`, `:268-349`). Factor the arithmetic into a state-input helper; supply these captured values, not the original addresses as callable dependencies.

For direct exact models, output is deterministically the wrapper's pro-rata receipt claim converted through its frozen vault model. Preserve local-first withdrawal accounting, receipt inventory checks, pending-held-fee realization and next-state validation. Output evaluation must first reproduce the initial holderAssets computation performed by canonical `quoteState` (`ReceiptState:59`; `V3State:60`), then the requested transition and its holderAssetsAfter computation. Input-only capture need not compute either. Do not skip a calculation that can revert simply because weighted output discards that return.

`nativeQuote == true` means the underlying receipt is another SE. Its bytes alone do not close this contract: `_vaultTransition`, `_vaultAssets` and `_normalizeNativeSnapshot` call that SE. The exact missing dependency is a reviewed, versioned capture/evaluation recipe for **that named underlying SE**, including its conversion-to-receipt surface used for local cash. No arbitrary recursive fallback is authorized. Initial implementation must reject such an unclosed binding, not pretend that VirtualVault probes proved it linear.

## 6. V3 SE recipe, including the amount-dependent pool path

The required production nested-route fixture binds two real V3 SEs and an unbuffered DETF self-leg: `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted_Univ3Se.sol:43-66` and `TestBase_UniswapV4Detf_Weighted_ProdSe.sol:128-141`. The Pons-v1 sibling binds the same V3 SE implementation to launch-token/WETH pools (`TestBase_UniswapV4Detf_Weighted_PonsV1Se.sol:62-73`). Neither fixture establishes a deployed Migration reserve configuration.

### 6.1 Pair deposit: small finite state

For ordinary pair -> V3 SE buffering, capture:

- SE/token0/token1 identities; issued native SE supply.
- Exact `reserve0` and `reserve1` from `_totalVaultReservesForShareMath`, each in its token's native units.
- Token decimals or, equivalently, exact derived native-share minimum liquidity for the zero-supply branch.

The totals include live free token balances, deployed center amounts at captured sqrt price and position liquidity/ticks, **stored and unpoked collectable fees** (`V3Common:299-395`). Using `reserveOfToken` or principal-only position amounts loses backing. An ordinary pair deposit uses V3In's preview and Common's `_sharesOutForDeposit`; reuse CP's square-root invariant growth, ceil-before invariant, floor-after invariant and exact `mulDiv` (`V3In:72-83`; `V3Common:624-640`; CP). There is no input swap in this deposit preview, no post-deposit rebalance and no user usage-fee deduction; its refund is zero (`UniswapV3FullSpreadStandardExchangeVaultInMultiQueryTarget.sol:11-17`).

**Minimal missing read:** `captureFrozenQuoteInputs(asset, holder, mode)` must expose those totals directly, without evaluating a hypothetical full-holder redemption. Existing `quoteState` serializes enough ingredients to reconstruct the totals, but also calls `_inventoryAssets` for holderAssets (`V3State:59-60`), which can traverse the entire pool or fail for reasons not visited by ordinary deposit preview. Do not introduce that extra precondition into input-only capture.

### 6.2 Cross-token conversion and output redemption: not a scalar

If `_pairEq` converts the opposing V3 pool token into the bound pair, V3In dispatches to the real pool swap quote and checks captured pool-unlocked state. If it converts V3 SE shares into the pair, it uses the ordinary zap-out preview. If the weighted output leg is buffered, Context may instead invoke V3's transition redemption. Those are three distinct modes, all amount dependent.

The complete finite payload for these modes is:

| Captured field group | Native units and acquisition |
| --- | --- |
| `InventoryQuote` identity and policy | `vault` address; `token0` boolean selecting accounting/output asset; `idle` boolean from `pool.slot0().unlocked`; `lower/upper` signed ticks. Obtain through new side-effect-free capture read; existing shape is `V3State:26-60`. Pool address is already returned by `assetInfo()` (`UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol:22-24`), not by `yieldToken()` which is zero. |
| Shares | `supply`, `shares` in native SE shares, with holder **hook**, not Migration or zero. Existing capture reads `totalSupply()` and `balanceOf(holder)`; transition rejects spending beyond these shares (`V3State:113-135`). Keep actual holder balance separate from attributed `seReserves`. |
| Free/fee inventory | `free0/free1`, `fees0/fees1` in native token0/token1; current position liquidity in V3 liquidity units; initial `liquidityDelta = 0`. Free balances and collectable fees use V3Common above. `quoteState` already exposes these, but the new read avoids its holder-value calculation. |
| Pool header | token0/token1 addresses, tick spacing, fee in V3 pips, sqrt price in Q64.96, signed tick, active liquidity, and protocol-fee byte from `slot0`. Public pool getters supply these. The protocol-fee nibble matters to transition fee growth (`V3Quoter:125-145`, `:182-190`). |
| Pool curve | Frozen `tickBitmap(int16)` words, and `ticks(int24).liquidityGross/liquidityNet` for every initialized tick plus both managed boundaries even when zero. Gross is uint128 liquidity; net is int128 liquidity. Source reads are exactly `V3Quoter:203-211`, `:221-271`. Store zero words too, or represent their verified absence in a complete dense word interval. |
| Rebalance policy | `liquidReservePercentageOfVault(se)` in WAD, and both token decimals or exact absolute-floor values in native token units. `V3State:327-367` still reads these **after** a transition. Relative tolerance remains the code constant 0.05 WAD (`V3Common:79-81`, `:183-212`). |
| Initial share policy | Exact minimum liquidity and created/managed-position identity. It affects zero-supply mint and initial-residual branches, and zero-created-position withdrawal must remain zero (`V3Common:299-312`, `:624-651`). |

This pool image has an explicit mathematical bound, not "snapshot the whole pool": capture every bitmap word covering compressed ticks from `floor(MIN_TICK / spacing)` through `floor(MAX_TICK / spacing)`, with one guard word on each side for the quoter's `compressed + 1`/word-edge lookup. Enumerate set bits and read only the two liquidity words per initialized tick, plus managed boundaries. At spacing 1 the core interval is 6,932 bitmap words and at most 1,774,545 tick indices; larger spacing reduces it. Header and image come from **one capture transaction**. No off-chain values or multi-block stitching is an equivalent capture.

Use a sealed query capsule for this image so the existing shared `UniswapV3Quoter` can run unchanged against its pool-getter surface. Absent out-of-coverage queries fail; never fall back to the original pool. Ordinary V3 preview orchestration and V3 transition orchestration must be narrowly factored to accept captured inventory/policy/token identities and this frozen pool. Do not call the original V3 SE with old bytes: `_inventorySwap` still reads the live pool; `_inventoryRebalance` still reads policy and decimals (`V3State:272-367`). Do not modify shared `lib/crane` to add a second quoter.

Preserve all canonical behavior: managed-liquidity withdrawal rounding before swap, boundary bitmap flips after projected liquidity changes, swap price limits, partial price-limit fills and retained unspent input, protocol-adjusted fee growth, supply/share bounds, blocked-pool local payout checks, rebalance and holderAssetsAfter. The normal zap-out preview and transition redemption are not interchangeable (`V3In:178-213`; `V3State:119-153`, `:194-224`).

**Engineering constraint:** `maxSteps = 0` is unlimited, not 512 (`V3Quoter:21`, `:146-151`; `V3Common:226-233`). A small tick window, fixed number of hops or one-price swap surrogate is not canonical. Full curve capture may exceed transaction gas/storage/runtime limits for a dense pool. Initial implementation must measure the actual configured pool image and fail capture explicitly if it cannot be atomically captured; it cannot silently narrow the quote or assemble a different-block book. For the inspected pair-input/raw-DETF-output fixtures, the **deposit-only payload in 6.1 suffices**, because the live provider's full-book rate is captured as a primitive. The large curve image is required only when a selected conversion/output actually needs the V3 swap/transition path. This report does not claim that expensive path already has executable gas evidence.

## 7. Morpho fixture and refund closure

The existing Morpho weighted fixture is separate from the required ERC4626/V3 baselines (`contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted_MorphoBlueSe.sol:43-59`). Its direct loan-token deposit can also be captured finitely:

- `MorphoState.QuoteState`: exchange/holder addresses; holderShares and supply in native SE shares; idle in native loan tokens; expected marketAssets/marketBorrowed in native loan tokens; marketShares and suppliedShares in Morpho supply-share units.
- `MorphoState:32-47` already exposes the **accrued** expected-market totals and adjusts supplied shares when the SE is Morpho's fee recipient. Thus later timestamp, IRM, borrow or fee-recipient changes need not be replayed. Preserve the returned accrued values, not only the unaccrued `market()` record.
- Also capture the actual ERC4626 arithmetic decimal offset (`Morpho:73-75`), which is **missing from those bytes**, and usage fee/feeTo if factoring transition deposits. Metadata decimals do not prove the configured offset. Add these to the typed family capture accessor.
- Ordinary output is the existing assets/share conversion over `idle + suppliedShares.toAssetsDown(expectedAssets, expectedShares)`, with the captured offset. Ordinary preview does not check cash availability (`Morpho:145-178`). Transition redemption **does** run `_quotePay` and its liquidity constraint, using captured marketBorrowed and idle (`MorphoState:112-129`). Do not add that constraint to ordinary `_pairEq` conversion.

Reuse the existing SharesMathLib/BetterMath conversion primitives, not a rounded one-share rate. Both amount words in the ordinary Morpho preview are explicit: output plus zero refund (`MorphoBlueStandardExchangeInTarget.sol:54-57`). This family needs no pool-curve capsule.

For an SE returning nonzero deposit refunds, the hook contract is unambiguous: **refund is native input**, added to rated newly minted shares only once; zero shares with nonzero refund can still supply rated inflow. Refund greater than supplied input is invalid. Output redemption refund, conversely, fails. A capture adapter must provide an exact amount-dependent `(amountOut, amountRefunded)` evaluator over its typed state; neither `getRate`, a stored unit quote nor a constant utilization/refund percentage satisfies that interface.

The inspected ordinary ERC4626, V3 and Morpho recipes return zero deposit refund; a disabled registered SE provides the concrete full-local-input branch, not a call to an SE. No partially refunding unknown SE is certified by this report. If the actual Migration binding includes one, the exact unsatisfied dependency is its ordinary `previewExchangeIn(pair, amount, se)` refund/consumption function and, if used on output, its redemption/transition function. Capture must reject that binding until its finite typed recipe and code identity are added. This does not license zeroing the refund, dropping the leg, swapping through a different route or changing an entitlement.

## 8. Minimal implementation touch list

These are **proposed later implementation paths**, not edits made by this node. Paths are exact. The first group is necessary for the two required baseline bindings; subsequent groups are conditional on selected nested routes. Do not expand this into an ordinary DETF refactor.

### Required capture/evaluator increment

1. New `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationSnapshotLib.sol`: capture orchestration, tagged payload validation and frozen mint-branch evaluation; zero handling, original grouping and no live fallback.
2. New `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationSnapshot.sol`: versioned field types, capture errors and evaluator contract. Keep future source/ancestry ABI out of it. Snapshot storage/wiring later belongs to the plan's `UniswapV4DetfMigrationRepo.sol` and allocation target, not ordinary DETF storage; this node does not authorize their lifecycle implementation.
3. New `contracts/interfaces/IStandardExchangeFrozenQuoteInputs.sol`: read-only tagged family capture schema; no arbitrary evaluator address/calldata. Include explicit ordinary-versus-transition mode and holder, exact model version and the fields above.
4. `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol`: add the aggregate stored-book capture read, including raw reserves, stored SE reserves, registry identity and hook-context external read results. Do not derive raw cash by subtracting rounded rated balances.
5. `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookHooksTarget.sol`: expose `captureWeightedMintBook`.
6. New `contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookCapture.sol`: declare its typed read-only surface and book fields. Keep the existing broad hook interface unchanged so adding capture does not replace its existing ERC165 identity.
7. `contracts/hooks/uniswap/v4/standardExchange/weighted/facets/UniswapV4StandardExchangeWeightedBufferHookHooksFacet.sol`: declare/install the added selector and separate interface consistently; current `facetFuncs` has 48 selectors (`:29-79`). Also update `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol:146-169`, whose package interface list is explicit. Package selector routing comes from facet metadata; do not merely add an unreachable Target method.
8. `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol`: factor only state-input exact-input rating/budget/output arithmetic required for canonical reuse, with existing live entrypoints gathering their usual values. Frozen callers must never enter storage-reading helpers. Existing `UniswapV4StandardExchangeWeightedBufferHookMath.sol`, Split, CP and Result remain reused arithmetic sources, not replacement formulas.
9. `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol`: expose/factor the finite ordinary receipt conversion using captured model, supply and backing, retaining original native arithmetic. Add family capture through the existing query composition; do not change investment/custody behavior.
10. `contracts/vaults/standard/erc4626/ERC4626StandardExchangeQuoteTarget.sol`: add `captureFrozenQuoteInputs` and separate direct-model evaluation from live protocol/fee reads. If only ordinary input conversion is used, do not force a holder redemption or transition simulation during capture.
11. `contracts/vaults/standard/erc4626/ERC4626StandardExchangeInFacetExt.sol:22-32`: expose the new read on the existing preview/transition facet, not the execution InFacet or OutFacet. Update its separate interface declaration and `contracts/vaults/standard/erc4626/ERC4626StandardExchangeDFPkg.sol:116-132`, whose package interface list is explicit. The inherited capture method comes from QuoteTarget; no duplicate selector installation.
12. `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInQueryTarget.sol`: side-effect-free input capture, including exact reserve totals, without `_inventoryAssets`. Declare it in `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInQueryFacet.sol:21-35` and advertise `IStandardExchangeFrozenQuoteInputs` there and in `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol:124-140`. Existing CP supplies deposit arithmetic; no swap-loop edit is required for input-only fixtures.

The accessor is a newly deployed-source capability. Adding it to source does not install it on an already deployed immutable hook/SE. Any actual instance lacking it needs a demonstrated existing-getter reconstruction or a newly composed instance. A cheatcode storage read, artifact JSON or RPC storage dump is not an on-chain capture implementation.

### Only if V3 conversion/output requires a pool curve

13. New `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationFrozenV3Pool.sol`: immutable/sealed query capsule for the bounded pool image and only the canonical quoter getter surface.
14. The plan's new `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigration_Component_FactoryService.sol`: deterministic capsule deployment support, with no direct production `new`; deployment plumbing must preserve one-transaction capture/seal atomicity.
15. `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol`, `UniswapV3FullSpreadStandardExchangeVaultInBase.sol`, and `UniswapV3FullSpreadStandardExchangeVaultInQueryTarget.sol`: factor only preview/transition orchestration taking captured inventory, pool endpoint and rebalance policy. Do not route ordinary previews through a frozen snapshot or alter live swap semantics.

### Only if Morpho is actually bound

16. `contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeQuoteTarget.sol` and `MorphoBlueStandardExchangeCommon.sol`: add missing offset/policy capture and factor state-only conversion/transition arithmetic.
17. `contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeInFacet.sol`: advertise/install the family capture read; update the explicit interface list in `contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeDFPkg.sol:115-129`. Reuse existing expected-market snapshot acquisition, not a new IRM simulator.

### Tests owned by the later implementation unit

18. New `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigrationSnapshot.sol` and `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationSnapshot.t.sol`: real registry/factory deployment and differential/freeze tests. Reuse the existing weighted ERC4626 and V3 production fixtures; do not replace hook/SE/fee oracle/registry with mocks.
19. Existing unchanged regression invocation targets: `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Weighted.t.sol` and `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Weighted_Univ3Se.t.sol`. Exercise asymmetric scale configurations from `TestBase_UniswapV4Detf_Weighted_Decimals.sol:43-63`; its stale 18-decimal comment is not the actual DETF unit contract.

No edits to ordinary `UniswapV4DetfCommon.sol`, `UniswapV4DetfTarget.sol`, rate-provider implementation, `lib/crane`, dependency links, product law or owner decisions are necessary for this specification. Hook and SE accessor additions/factoring require ordinary differential regression, selector/loupe checks and bytecode-size checks in the later implementation unit.

## 9. Reasoning checks and remaining proof obligations

These are source-trace checks, **not executed tests**.

| Case | Consequence tested against the design |
| --- | --- |
| Buffered leg with retained cash | Capture raw and SE inventory separately. Same rated balance but different raw/SE composition changes output local/deficit split. `nativeReserve`, rated balance or two ERC20 balances cannot reconstruct it. |
| SE deposit amount dependence | V3 deposits use square-root invariant growth, not `net * rate`. ERC4626 wraps receipt equivalents against full booked-cash backing. Both evaluate at actual **net boosted original amount**. |
| Deposit refunds | Preserve `(shares, refund)` and validate refund bounds. All-refund/zero-share maps to local rated input; partial refund adds once; zero-share/zero-refund reaches canonical zero-domain failure. For the inspected zero-refund families, assert zero rather than inventing capacity refunds. Unknown partial-refund bindings remain an explicit adapter gap. |
| Output redemption | Rate determines a **share budget**, not final assets. Read no live state after selecting its frozen transition/ordinary recipe; enforce stored SE share cap, applicable captured transition-holder limits, zero refund and zero-output failure. Preserve Context's identity bypass. In the two required fixtures DETF is raw, so this branch is inspected but not falsely claimed as exercised by their baseline tests. |
| Rate changes | Frozen getRate response drives both held valuation and applicable input/output mapping. Later provider/subject yield or total-supply changes cannot enter evaluation. Identity/unheld branches must preserve when no rate is read. |
| Fee changes | Hook swap fee applied exactly once before nested deposit; captured p applied before hook and after gross. SE transition fee/policy reads use captured values. Later feeTo, usage, liquid-reserve and seigniorage changes cannot enter. Ordinary ERC4626/Morpho dilution fees are not an extra user-output haircut. |
| Disable or registration changes | Registered+disabled is its captured raw-input branch; unknown registration fails. Later re-enable cannot cause buffering, later disable cannot erase a captured deposit. Do not impose input-disable logic on output redemption: Claim does not do that. Separate Migration lifecycle/registry authorization is not frozen pricing. |
| Direct-pair identity | `_pairEq(pair, x) = x` with no underlying SE preview, even when that SE would reject another route. Do not use provider, NAV or a receipt quote here. Hook `se == pair` is separately governed by its actual preview semantics, not this bypass. |
| Contribution conversion before hook | Evaluate conversion output against captured state but do **not** project its execution into hook reserves/SE state. Ordinary mint-branch preview does not run Legs.afterExternalExchange; using it would choose the fallback's different computation. |
| Original inputs, zero and limits | Quote each whole original ETH/DTF component independently against identical S; zero bypasses zero-input quotes. Do not chunk, sequentially move reserves, quote a remaining fraction, merge recipients' original inputs, insert a duration boost or include the inventory/self-leg pot. Preserve checked-overflow, weighted 30% max-in, zero and reserve-exhaustion errors. |

Before the implementation can claim E3, it must establish: actual Migration mint routes and code/selector identities; exact supported receipt models (including empty-state behavior); successful proxy capture of buffered raw reserves; no source getter/fee/provider/SE/pool calls reachable after capture; canonical-result parity on real proxies; independently mutated reserves, shares, rate/fee/disable and nested state; exact boundary/revert parity; and, if needed, atomic full V3-image gas/storage feasibility. A family byte payload plus later calls to its original SE is specifically insufficient.

Caller-sensitive or nondeterministic unreviewed providers/SE previews are not certified by the inspected models. Capture must preserve the hook caller context for its reads and reject unclosed implementations; it cannot prove arbitrary bytecode deterministic from one probe. Current ordinary code remains the behavioral oracle.

## 10. Node checks, cleanup and DoneClaim

- Authored scope: this `dependencies.md` only. No product/test/plan/shared dependency edits, delegation, Git operations, installs, builds, tests, deployment, public transactions or allocations.
- Work method: read the full phase-two brief, copied plan sections 1-6/task 2, router/assistant rules and applicable Crane/IndexedEx source/testing guidance; traced ordinary mint, weighted dispatch/rating/budget, context/leg behavior, ERC4626 and production V3/Morpho dependencies and fixture bindings.
- Owned runtime root created with `mktemp -d '/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/pricing-dependencies.XXXXXX'`: `/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/pricing-dependencies.S3FeC4`. Subsequent tool environment: TMPDIR at that root; NODE_COMPILE_CACHE at its `/node`; BUN_RUNTIME_TRANSPILER_CACHE_PATH at its `/bun`. The creation command exported all three to the parent temporary root before `mktemp`, then the session tool environment was set to the owned root.
- Source/read-back verification: reread this report and checked explicit source-anchor ranges across 34 source files through the read tool. One fixture end-line was outside its file; corrected the Morpho fixture anchor to lines 43-59 after reading its actual final line 60. Manually corrected stale p/getter/disable offsets and verified the real ERC4626 preview selector owner is `InFacetExt`, not the execution InFacet or OutFacet. Checked all ten reasoning rows in section 9 against the traced branch. These are source/document checks, not passing Solidity tests.
- Processes/ports: no persistent process, server, port, compile, monitor or child task started. The short `mktemp` and cleanup commands completed. Cleanup ran with explicit worktree cwd and all three owned runtime environment variables, used only `rmdir "$TMPDIR"` on the empty owned root, then `test ! -e "$TMPDIR"`. Read-back output was `CLEANUP_ROOT_ABSENT /var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/pricing-dependencies.S3FeC4`, `OWNED_PERSISTENT_PROCESSES 0`, `OWNED_PORTS 0`. No shared cache or another lane's root was touched.
- Limits: source reasoning only; no numeric differential execution or live deployment validation. Required source accessors/factoring, unsupported nested-model/refund adapters and V3 image feasibility are explicit above. No claim of task-2 completion.
- DoneClaim: the dependency-node deliverable is this file, with bounded field/evaluation contracts, current source anchors, required/conditional touch paths, explicit unsatisfied dependencies and cleanup receipts. Plan task 2 and E3 remain open for implementation and independent executable verification.
