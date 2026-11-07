# Identity

- Member: astra
- Profile: research
- Phase: initial independent response
- Requested role: council-member
- Requested model: chatgpt-subscription/gpt-6-astra:high
- Runtime role, model, reasoning setting, account route, and task ID: not exposed
- Peers read before submission: no
- Fresh or continued: fresh

# Question and targets

What distinct causes produce the supplied IndexedEx full-spread test failures? Which failures share a cause, and which execute different failing paths?

The targets are the package test, nine V4 FullSpread hook-matrix files, and `AlreadyUnlocked.t.sol`, `BufferHookIntegration.t.sol`, and `Native.t.sol` named or identified by the brief. This is a research diagnosis, not an implementation review or an implementation proposal.

# Evidence

## Evidence classes

- **Supplied runtime evidence:** the failure strings in `docs/research/fs-failure-causes-20261105/brief.md:75-89`. I did not reproduce those runs.
- **Source observation:** the current repository files and line ranges cited below, read independently without peer responses.
- **Inference:** the causal connections between those sources and the supplied failures. The arithmetic below is a source-derived integer calculation in memory, not an EVM execution, a contract test, or a recovered runtime trace.

## The shared one-sided sizing failure

**Source observation.** A face-to-vault-share request selects `_mintOne`, which calls `_size`, copies its liquidity and remainder into the plan, and derives shares from that liquidity. With zero added liquidity, `_shares` returns without setting a positive output. The public preview returns the plan's output and refund words separately. Sources: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:22-35,106-116,230-245`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultQuoteTarget.sol:14-21`.

**Source observation.** The interior-price path computes a fee-excluded integer `n`, converts it to gross input with **rounding down**, projects that exact input, and rejects the entire mint when `quote.applied < n`. Rejection sets the remainder to the entire offered amount. The projection accumulates `amountInStep` into `applied`, excluding fees. The swap step itself also rounds down when removing fees from gross input. Sources: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:198-220`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMath.sol:140-175`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultSwapProjection.sol:55-68`; `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/SwapMath.sol:64-87`.

**Inference: the concrete mismatch is a double-floor fee conversion followed by an exact lower-bound check.** At the fixture's 3,000-pip fee, an uncapped final step has:

```text
gross   = floor(n * 1000 / 997)
applied = floor(gross * 997 / 1000)
```

Unless `n` is divisible by 997, `applied` is `n - 1`, so the planner rejects an otherwise positive quoted swap. This conclusion follows from the two floors and the `applied < n` comparison, not from a claim that every zero quote is ordinary deposit dust. Sources: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMath.sol:172-175`; `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/SwapMath.sol:64-83`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:207-216`.

**Source observation: fixture inputs.** The matrix initializes the backing pool at `2^96`, with fee 3,000 and spacing 60, supplies 1,000,000 tokens per side as external full-range liquidity, and bootstraps the vault with 100,000 per side. The package/borrowed/native base initializes the same price, fee, and spacing but does not add that external position; the named tests bootstrap 100,000 per side. The package initializes the vault's position at the minimum and maximum usable ticks. Initial protocol fee is zero. Sources: `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol:50-54,65-74,180-215`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol:47-76`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol:184-186`; `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol:101-107`; the three direct-test locators in conclusion C2.

**Arithmetic inference.** Evaluating the read integer formulas gives full-range bounds `4306310044` and `1457652066949847389969617340386294118487833376468`, vault liquidity `100000000000000000005435`, and matrix external liquidity `1000000000000000000054353`. Rounded-up bootstrap payments fit the supplied amounts. These calculations use `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol:36-109`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol:20-75`, and `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMath.sol:82-114,140-159,210-284,287-497`.

The following are derived values, not supplied runtime measurements:

| Initial state and input | Solved net `n` | Gross input | Fee-excluded applied input |
| --- | ---: | ---: | ---: |
| Matrix, 1 ether face | 499248760185015444 | 500751013224689512 | 499248760185015443 |
| Matrix, 3 ether face | 1497745601806272105 | 1502252358882920867 | 1497745601806272104 |
| Matrix, 10 ether face | 4992477420650838384 | 5007499920412074607 | 4992477420650838383 |
| Matrix, 100 ether face | 49923756132251980921 | 50073978066451334925 | 49923756132251980920 |
| Direct base, 100 ether face | 49912449780244685771 | 50062637693324659750 | 49912449780244685770 |
| Direct base, 1,000 ether face | 498010663111113401233 | 499509190683162889902 | 498010663111113401232 |

Every row is one unit short of the planner's required net input. The matrix currency1 calculations for 1 and 100 ether give the same displayed values using the opposite-direction coefficients. These small swaps do not reach the initialized full-range boundary; the boundary cap therefore does not remove this mismatch. Sources for that inference: the fixture position construction above; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMath.sol:235-284`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultSwapProjection.sol:97-125`; `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/SwapMath.sol:64-87`.

There is also a later, distinct zero/full-refund gate: `sizeOneSided` demands that rounded-up consumption of the acquired token equal the quoted swap output exactly, and that input-side consumption fit the unswapped balance. **That gate exists, but it is not needed to explain the calculated cases above: they return earlier at `applied < n`.** I do not attribute these supplied failures to the later equality check merely because it can also return zero. Sources: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMath.sol:47-79`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:212-227`.

# Assumptions

1. The supplied failures correspond to the current source paths inspected here. No commit identifier or complete execution trace was supplied, and I did not inspect Git or build artifacts.
2. Arithmetic reconstruction uses the initialization and liquidity operations explicitly present in the cited fixtures. It does not substitute for running their deployments or observing their storage.
3. The brief's abbreviated matrix names refer to the V4 FullSpread concrete files listed below, not their adjacent V3 counterparts.
4. A reported error identifies the failing condition, not every later behavior of that test. A seed failure does not establish what the subsequent swap, withdrawal, gas assertion, or negative control would do.

# Coverage

“Examined” means the complete named concrete file was read, together with the relevant execution path cited in this response. It does not mean every transitive dependency was audited.

| Named failing file | Coverage | Relevant diagnosis |
| --- | --- | --- |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/UniswapV4FullSpreadStandardExchangeVault.Package.t.sol` | Examined | C1-C2; one-sided shares assertion |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | Examined | C1, C3; inherited seed fails before later row behavior |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | Examined | C8-C10; shared refund helper and two independent dual failures |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | Examined | C7-C8; missing effective face reserve after seed |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | Examined | C4, C8; zero-wrap preview and full-refund assertion |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | Examined | C5, C8; zero inventory at first mint |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5.t.sol` | Examined | C5, C8; same inherited first-mint gate, five active records |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | Examined | C5, C8; separate Curve first-mint implementation |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | Examined | C6, C8; two-leg positivity gate |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol` | Examined | C6, C8; partial-book quote proceeds to buffer rejection |
| `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/AlreadyUnlocked.t.sol` | Examined | C2; returned zero shares, not the named unlock error |
| `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/BufferHookIntegration.t.sol` | Examined | C3; inherits constant-product row |
| `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Native.t.sol` | Examined | C2; one-sided WETH-face shares assertion |

Supporting behavior files, hook implementations, deployment validation, and token/router code were examined in the cited relevant ranges, not comprehensively. The optional `docs/reviews/se-fullspread-plan-execution-20261104/IMPLEMENTATION_AND_TEST_PLAN.md` and its remediation PRD were not examined: this response diagnoses executed code and supplied errors, not requirement compliance.

# Conclusions

## C1. One shared numerical cause produces the zero face-to-share quotes

**Conclusion, inferred from the source and arithmetic above:** the rounded-down gross input loses one unit when the swap removes its fee, and `_size` rejects it because the applied input is below the solved net input. That creates zero shares and a full input refund for the relevant fixture amounts. This is not a tuple-decoding confusion: the quote target returns `(plan.amountOut, plan.amountRefunded)`, and `ExchangeInAmount.previewOut` explicitly takes the first word. Sources: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:207-245`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultQuoteTarget.sol:14-21`; `contracts/utils/ExchangeInAmount.sol:9-15`.

This explains the direct `SE quotes the face: 0 <= 0` assertions in the constant-product bind and single-buffer bind tests. Both assert a positive face-to-share preview before the later action they describe. Sources: `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol:209-221`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:57-73`.

## C2. Package, borrowed-unlock, and native assertions expose the same zero mint through different entry contexts

**Source observation.** Execution uses the same planner as preview. With `minOut = 0`, an unfailed zero-output mint plan passes the minimum check, runs its zero actions, mints no nonzero share amount, and refunds the input to the caller. Sources: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultExecution.sol:63-95,213-243`.

- **Package:** after a balanced bootstrap, it deposits 1,000 ether of token0 and immediately asserts `shares > 0`; the exit comes later. **Inference:** the supplied failure is explained at the mint assertion, without inventing an exit failure. Source: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/UniswapV4FullSpreadStandardExchangeVault.Package.t.sol:23-38`.
- **AlreadyUnlocked:** the test bootstraps, funds and approves a contract caller, executes a 100-ether one-sided deposit inside `manager.unlock`, decodes the return, and asserts `shares > 0`. Its delta assertions follow that assertion. **Inference:** this is not evidence of a `ManagerAlreadyUnlocked` revert or uncleared deltas; the failing assertion is earlier. Ordinary `exchangeIn` is the entry allowed to borrow the unlocked context, subject to its explicit guards. Sources: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/AlreadyUnlocked.t.sol:35-48,58-90`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultExecution.sol:192-224`.
- **Native:** it first asserts a positive balanced-bundle mint, then deposits 1,000 ether WETH as the native-currency face and asserts `more > 0`. The planner maps the native currency to WETH at its public face boundary. **Inference:** C1 explains the second mint assertion; the supplied string does not establish a separate native-settlement defect. Sources: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Native.t.sol:61-77`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:255-261`.

The direct-base arithmetic in Evidence covers 100 and 1,000 ether at this bootstrap. The shared cause is the sizing decision; the borrowed-lock and native contexts remain distinct paths, not separately proven broken subsystems.

## C3. Constant-product `InsufficientLpOut` is a seed failure, not a beforeSwap wrapper

**Source observation.** The inherited `_seed` deposits 100 face units and 100 raw units. `_bufferPair` sees a zero face-to-share preview and returns zero without calling the vault's exchange. The hook consequently has no SE shares; its rated reserve is zero. `_firstMint` computes the geometric mean of its two reserves and rejects a value at or below minimum liquidity with `InsufficientLpOut`. Sources: `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol:79-83`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol:161-170`; `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol:287-294,453-479,507-525`; `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:419-425`; `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookMath.sol:154-155`.

**Inference.** The named composed-gas, caller-separation, buffer-first, product-index, swap, partial-consumption, and preview rows share this failing seed. Their later behavior is not reached. In particular, the inherited partial-consumption test calls `_seed` before deciding whether to use its dust control, and the concrete preview-parity test can first compare two zero outputs successfully before reaching the failing `_seed`. Sources: `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol:240-244,482-488`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:68-69,94-104,108-125,137-145,181-194,221-225`.

`BufferHookIntegration.t.sol` inherits this concrete row, and its gas override also seeds before swapping and checking gas. Its supplied constant-product failures therefore belong to this same group; the bind failure belongs to C1. Source: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/BufferHookIntegration.t.sol:21-33`.

## C4. Single-buffer `MinAmountNotMet(1, 0)` really is a beforeSwap zero-preview rejection

**Source observation.** The single-buffer hook's `beforeSwap` chooses `_wrapExactIn`; that function previews the wrap and explicitly throws `MinAmountNotMet(1, 0)` when the preview is zero, before taking input or calling the vault exchange. Its preview delegates to the vault's face-to-share preview. Sources: `contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookTarget.sol:118-137,195-207`; `contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookCommon.sol:92-96`.

**Inference.** C1 supplies the zero; this hook supplies the minimum-output error. Unlike C3, this failure occurs during the attempted swap rather than during a preceding LP seed. The gas row invokes `swapExactIn` before its gas assertion, so its name does not make this a gas-ceiling failure. Source: `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:191-200`.

**Source observation.** V4's hook-call helper adds `HookCallFailed` context when the underlying hook call fails, and `beforeSwap` uses that helper. **Inference:** the supplied outer wrapper is transport/context for the inner error, not an additional root cause. Source: `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol:133-139,249-258`.

## C5. Balancer two/five-leg and Curve `ZeroAmount` reject a zero inventory leg during first-mint quotation

**Source observation.** Balancer maps each offered face amount into inventory, using the SE preview for a converting leg. Its initial proportional join requires every active inventory amount and offered pair amount to be positive. Thus a positive face amount with zero quoted shares fails `_firstMint` with `ZeroAmount` before `_commitJoin`. Sources: `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.sol:638-654`; `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol:46-90`.

**Source observation.** Curve has a separate implementation of the same kind of gate: it maps four face amounts to inventory and rejects any zero first-mint inventory leg. Sources: `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.sol:790-804`; `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore.sol:78-122`.

**Inference.** These families share C1 as the input to their failure, but their immediate failure is their first-mint all-positive-inventory requirement, not V4 `beforeSwap`. Balancer's two- and five-leg files share the runtime-length seed implementation; Curve uses its own four-leg seed. Each supplies 100 ether per leg before the later row actions. Sources: `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:163-171,242-275,299-316`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5.t.sol:12-18,54-58`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:127-134,215-252,273-290`.

Their separately overridden partial-consumption tests do not use those seeds; those belong to C8.

## C6. Weighted two-leg and weighted N3 fail at different stages

**Source observation.** Weighted first maps offered face amounts to inventory. With two records, `_firstMint` requires exactly two positive inventory amounts. With more than two records it only requires at least two, and can calculate a partial-book mint when not all inventory legs are positive. Sources: `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol:612-626`; `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol:202-245`.

**Inference, two-leg row.** Its FullSpread face quotes zero and its raw leg remains positive, so only one inventory leg is positive: `_firstMint` throws `ZeroAmount`. The concrete row initializes two records and seeds each with 100 ether. Source: `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:44-46,65-74,130-136`; the weighted production locators above.

**Inference, N3 row.** Its raw and pre-acquired PairToken-share records can supply two positive inventory amounts even when the FullSpread leg quotes zero. That passes the partial-book first-mint quotation. But `usedPair` remains the offered amounts; commit then pulls and buffers the positive face input. `_bufferToken` repeats the face-to-share preview and throws `BufferFailed` when it is zero. This explains why N3 reports a different error without needing a different FullSpread numerical cause. Sources: `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol:114-148,167-175`; `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol:223-245,306-318`; `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol:525-539,590-595,619-625`.

This `BufferFailed` is the seed's buffer-last rejection, not a `beforeSwap` wrapper. The N3 gas test calls `_seedThree` before swapping. Source: `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol:317-321`.

## C7. Orbital accepts the zero conversion during seed, then lacks a live effective face reserve

**Source observation.** Orbital's initial LP calculation accepts at least two positive offered amounts and values the offered faces through `_sumFaceEffectiveWad`. Its `previewBufferClaimIn` falls back to the offered face amount when the SE preview returns zero. Actual `_bufferToken` permits a zero minimum and does not reject zero returned shares. Sources: `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:1029-1043,1101-1120,628-643,1275-1284`; `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol:475-488`.

**Source observation.** After buffering, the first mint sets its radius from post-buffer effective amounts; the radius calculation only requires the largest leg to be positive. By contrast, a converting leg's effective reserve is zero if the hook holds no SE shares, regardless of loose refunded face tokens. Sources: `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:1294-1331`; `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookMath.sol:134-143`; `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol:263-270,448-461`.

**Inference.** The mixed seed can mint LP using its other records and the face-value quotation fallback, while the actual FullSpread conversion produces no shares. A subsequent face-involving swap sees an empty effective input or output reserve and throws `NotLive`. The exact-input `beforeSwap` calls the quote path before taking/buffering that swap's input; that path selects the book-context check requiring nonzero radius and both effective reserves. Sources: `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookHooksTarget.sol:278-319`; `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:732-740,810-819`; `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol:175-185,227-233`.

This is not simply the single-buffer hook's immediate zero-preview check under another error name. Orbital has a distinct seed/quote/accounting path: zero conversion is tolerated first, then reserve liveness rejects the swap. The concrete mixed seed and failing directions match that sequence, including the currency1 rate-target variant. Source: `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:111-129,142-164,212-215,243-247`. The outer V4 wrapper is explained by `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol:133-139`.

## C8. Partial-consumption assertions require a proper residue, not a full refund

**Source observation, single buffer.** The loop only reduces its candidate amount when `amount > refund`. A full refund leaves that amount unchanged on every iteration. The final assertion requires the refund to be less than 1% of the amount. **Inference:** a `(0, 1 ether)` preview produces exactly the supplied `1 ether >= 0.01 ether` failure before `_wrapExactIn`; it does not show a failed refund transfer. Source: `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:76-87`.

**Source observation, shared helper.** Orbital, stable, and weighted overrides call `FullSpreadV4MatrixChecks.refunds`. That helper first performs a face-to-other-face control swap, then previews a one-sided share mint and requires `refund > 0 && refund < amount`. A full refund and a zero refund both fail that message; the message alone does not distinguish them. Sources: `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:177-204`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:189-192`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:258-260`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:231-234`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:199-202`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol:263-266`.

**Arithmetic inference for that changed state.** The preceding 1-ether face0-to-face1 swap changes the matrix sqrt price to `79228090704803944239423584507`. At that price, the following 1-ether mint solves `n = 499248760185117976`, gross `500751013224792353`, and applied input `499248760185117975`: again one unit short, hence a full refund under C1. This calculation uses the helper's order above, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol:31-47`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/SwapMath.sol:64-87`, and `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMath.sol:235-259` together with the cited planner guard.

Thus these are assertion failures caused by a zero-consumption quote violating the test's narrower residue assumption. They are distinct from the hook seed/swap errors. The constant-product partial-consumption failure remains in C3 because its seed fails before reaching its own control.

## C9. Dual composed-gas `allowance` follows rejected identity binding and stale baseline objects

**Source observation.** Dual setup first runs the baseline test base, which deploys an ERC4626-backed hook, assigns `dual` and `poolKey`, and approves that hook for its baseline tokenA/tokenB. The FullSpread row then replaces `pm` and `swapRouter`. Its attempted identity bind catches a validation failure, sets `hook = address(0)`, and returns **before** replacing `dual`, rebinding `poolKey`, or performing its new approvals. Sources: `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook.sol:87-94,131-150`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:245-259,270-300`.

**Source observation.** The identity candidate is the PairToken diamond itself. Dual validation only accepts that wrapper-share shortcut when `asset()` returns a distinct nonzero underlying; otherwise it searches `vaultTokens`. The inspected PairToken package binds its two underlying faces and specifies its component selector sets without `asset()`. Sources: `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg.sol:374-397`; `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol:170-177`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultDFPkg.sol:260-264,320-325,361-470`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:262-274`.

**Source observation.** Other dual row paths call `_requireIdentity` and can return after recording the rejection; the composed-gas test does not. It calls `_seed` and `_swapExactIn` unconditionally. Those inherited helpers use `dual` and `poolKey`, respectively. The new router settles the key's input token with `transferFrom` before calling `manager.swap`; the mintable token emits the literal `"allowance"` error when that router lacks approval. Sources: `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:303-315,421-425`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol:181-193,204-212`; `contracts/test/stubs/WrapperExactOutRouter.sol:74-83,97-106`; `contracts/test/stubs/MintableERC20Decimals.sol:56-62`.

**Inference.** The gas test continues with the old, already-approved hook for seeding, then the new router tries to settle an old-key token for which it has no approval. This explains the supplied literal allowance failure before the FullSpread swap path. It is a fixture continuation/approval mismatch following the rejected identity bind, not another form of the one-sided quote rejection and not proof of a gas-limit problem. No full trace was supplied to identify the particular old token address.

## C10. Dual index1 exhausts a bounded address-side selection, independently of conversion

**Source observation.** `test_row_index1` restores the pre-PairToken snapshot and calls `_configureDual(false)`. The shared `pair` helper tries its initial share and then 32 named vault candidates, accepting only a share address on the requested side of the face. If none matches, it throws the exact supplied string. This happens before `_bindDual` and before the direction tests. Sources: `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:123-139,262-267,342-346`.

**Inference.** This failure means that the finite candidate set did not satisfy the requested address ordering in that run. It does not mean the pool consumed too much input, the vault returned zero shares, or PairToken transfer-only execution failed. Naming does affect the encoded package arguments and salt, so the attempts are not inherently the same identity; nevertheless, the code does not guarantee that its finite set spans both sides of an arbitrary face address. Sources: `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:62-67,124-139`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/test/bases/TestBase_UniswapV4PairTokenStandardExchangeVault.sol:84-93`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultDFPkg.sol:205-206`.

## Grouping decision

The supplied failures therefore do **not** all have one cause:

- C1 is a shared numerical trigger for the zero quote, direct zero-mint assertions, and the consumer failures in C3-C8.
- C3-C7 preserve different consumer paths and failure stages: constant-product first mint, single-buffer swap preview, stable first-mint inventory validation, weighted positivity versus buffer commit, and orbital post-seed reserve liveness.
- C8 is an assertion on a strict partial-refund expectation, not another hook error.
- C9 and C10 are independent dual-fixture causes: rejected-bind continuation into stale objects without router approval, and finite address-side candidate exhaustion.

The detailed source locators in C1-C10 support those distinctions. In particular, the proposed blanket description “beforeSwap wraps zero into every listed error” is rejected: the seed errors are reached before those swaps.

# Limits

- No Forge command, project test suite, installation, Git operation, deployment, wallet operation, or sub-agent was used. Only this response file was written.
- The supplied errors remain supplied runtime evidence. The numerical values are explicitly source-derived arithmetic, not observed contract return values or a test pass.
- No whole-repository correctness claim is made. Supporting files were read selectively, and the shared workspace was not frozen.
- The optional implementation plan and remediation PRD were not read. No product-compliance judgment is inferred from their absence.
- I have not verified later assertions hidden behind the earlier failures, nor identified actual deployed addresses from a trace.
- This diagnosis recommends no implementation and authorizes no haircut, numerical search, product change, or code edit.
