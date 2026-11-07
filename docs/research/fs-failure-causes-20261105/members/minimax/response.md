# Full-spread failure causes - independent diagnosis

## Identity

- Member: minimax
- Profile: research
- Phase: initial independent response
- Requested role: council-member
- Requested model: minimax/MiniMax-M3
- Adaptive thinking: requested; not exposed (the task tool exposes no separate thinking control)
- Runtime identity: not exposed
- Task ID: not exposed
- Peers read before submission: no
- Fresh or continued: fresh

## Question and targets

Question: what distinct causes produce the supplied IndexedEx full-spread test failures, grouping failures that share one cause and keeping causes separate where the code paths differ.

Targets read for this response: the thirteen failing files named in the brief, plus the production and test code those failures execute (full-spread vault planner/math/execution, the six hook families, the matrix fixture, and the shared matrix helpers). Method: read-only source inspection, plus a source-derived integer evaluation of the planner's own formulas. No suite was run, no code was changed, no peer file was read.

## Evidence

### 1. Source observation - the face-to-share route and its only sizing engine

- `previewExchangeIn` delegates to `Planner.planIn` and returns the plan's `amountOut`/`amountRefunded` (`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultQuoteTarget.sol:14-21`). A face in, share out route selects `_mintOne` (`.../UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:29-31`).
- `_mintOne` takes all of its sizing from `_size`, books `_size`'s `remainder` as the refund, and only mints from the liquidity `_size` returned (`.../UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:106-117`).
- `_size` has four "give up" exits, and every one of them sets `remainder = amount_` and returns without liquidity or a swap: `n_ == 0` (`.../UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:199-203`), `gross_ == 0 || gross_ > amount_` (`.../UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:207-211`), a failed swap projection (`.../UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:212-217`), and a zero-liquidity sizing result (`.../UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:221-227`).
- `_shares` returns immediately when `liquidityAdded == 0`, so `amountOut` stays zero (`.../UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:230-245`). Execution then mints nothing and refunds `plan_.amountRefunded` to the caller (`.../UniswapV4FullSpreadStandardExchangeVaultExecution.sol:75-77`, `.../UniswapV4FullSpreadStandardExchangeVaultExecution.sol:93-94`).
- The analytic input is `Math.quadraticInput` (`.../UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:199`), which returns 0 when its fixed-point root is zero or exceeds the amount (`.../UniswapV4FullSpreadStandardExchangeVaultMath.sol:141-159`); `Math.grossFromNet` floors the fee gross-up (`.../UniswapV4FullSpreadStandardExchangeVaultMath.sol:172-176`).

### 2. Inference from the cited source - which `_size` exit the fixture takes

The matrix fixture bootstraps a real full-range position and an independent external LP, at Q96 start price, 3000 fee, 100,000 ether bootstrap and 1,000,000 ether external liquidity (`test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol:50-54`, `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol:180-215`). Recomputing the cited integer formulas (`.../UniswapV4FullSpreadStandardExchangeVaultMath.sol:141-159`, `.../UniswapV4FullSpreadStandardExchangeVaultMath.sol:235-285`) against those parameters gives:

- token0 direction (zeroForOne): net input `n = 998497746619929894` for a 1e18 input, and the floored gross-up `grossFromNet(n) = 1001502253380070104`, which is greater than the 1e18 input, so `_size` takes the `gross_ > amount_` exit (`.../UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:207-211`).
- token1 direction (oneForZero): `quadraticInput` returns 0, so `_size` takes the `n_ == 0` exit (`.../UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:199-203`).

Both directions therefore produce the same observable: `previewExchangeIn(face, x, share) == (0, x)` and an `exchangeIn` that mints nothing and refunds the whole input. The ratio in the first case (about 1.0015x) is stable for 1, 100 and 1000 ether inputs.

This is a source-derived evaluation of the cited formulas, not a suite execution and not a runtime trace.

### 3. Source observation - the direct `0 <= 0` and zero-quote assertions

- Package row: one-sided deposit of 1,000 ether into the share, then `assertGt(shares, 0)` (`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/UniswapV4FullSpreadStandardExchangeVault.Package.t.sol:32-34`).
- Already-unlocked row: borrowed `exchangeIn` of 100 ether of token0 into the share, then `assertGt(shares_, 0)` (`test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/AlreadyUnlocked.t.sol:73-86`).
- Native row: WETH one-sided deposit of 1,000 ether into the share, then `assertGt(more_, 0)` and `assertLt(refund_, 1_000 ether)` (`test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Native.t.sol:71-77`).
- Constant-product bind row: `ExchangeInAmount.previewOut(...) > 0` against the full-spread SE (`test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol:209-222`; the helper reads the first word of the preview tuple at `contracts/utils/ExchangeInAmount.sol:9-15`).
- Single-wrapper bind row: `(uint256 quoted, uint256 refund) = previewExchangeIn(face, _f(1), seUT); assertGt(quoted, 0)` (`test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:67-72`).

### 4. Source observation - the partial-consumption assertions read the same refund word

- Shared helper: `require(refund_ > 0 && refund_ < amount_, "one-sided mint cannot fully consume")` on the one-sided mint preview (`test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:188-195`).
- Single-wrapper row: the same loop subtracts the quoted refund from the amount and finally asserts `assertLt(refund, amount / 100, "one-sided remainder stays a rounding residue, not the input")` (`test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:76-88`).

Both read the refund word of the same full-spread one-sided mint whose `_size` exits set `remainder = amount_` (`.../UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:199-227`, `.../UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:106-117`).

### 5. Source observation - each hook family refuses the zero SE output on its own code path

- Constant product (`InsufficientLpOut`): `_bufferPair` reads the SE preview and returns 0 without buffering when `minOut == 0` (`contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol:287-293`); the first mint then sizes LP shares from reserves that hold no SE claim and reverts `InsufficientLpOut` when the geometric mean is at or below the minimum (`.../UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol:519-526`).
- Single wrapper (`MinAmountNotMet(1, 0)`): the context quote is gated behind an ERC-165 probe (`contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol:33-37`, `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol:44-50`) and otherwise returns the plain SE preview (`contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol:91-98`); with that preview at zero, `_wrapExactIn` reverts `MinAmountNotMet(1, 0)` (`contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookTarget.sol:195-205`).
- Orbital (`NotLive` inside `beforeSwap`): `_bufferToken` does not revert on a zero SE quote (`contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:628-642`), so the hook finishes the seed holding zero full-spread shares; the effective native value of a buffered leg is zero when the SE balance is zero (`contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol:450-461`), and the pre-swap liveness check reverts `NotLive` when an input or output effective balance is zero (`contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol:227-233`) on the `beforeSwap` path (`contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookHooksTarget.sol:278-326`).
- Balancer quad, Balancer quad 5 and Curve quad (`ZeroAmount`): the first-mint inventory projection maps a buffered face leg to the SE's own preview (`contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.sol:639-655`, `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.sol:790-805`); a zero preview makes the face leg's inventory delta zero, and first mint rejects a zero delta with `ZeroAmount` (`contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol:79-91`, `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore.sol:111-123`).
- Weighted two-leg row (`ZeroAmount`): the same inventory projection is used (`contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol:612-628`) and a two-leg first mint requires both legs positive (`contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol:223-246`), so the zero face leg reverts `ZeroAmount` at `.../UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol:233`.
- Weighted three-leg row (`BufferFailed`): a three-leg first mint only requires two positive deltas (`contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol:231-236`), so it proceeds to the commit step, which buffers the pair leg (`contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol:748-751`), and `_bufferToken` rejects a zero minimum with `BufferFailed` (`contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol:525-540`).

### 6. Source observation - the PairToken share side failure is a bounded address sample

- `pair()` deploys one record, then at most 32 more named PairToken vaults, and reverts with exactly `no PairToken share on the requested side of the face` when none lands on the requested side (`test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:124-135`); the side test is a pure address comparison (`.../UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:137-139`).
- It runs during `setUp` through `_configureDual`, before any hook binding or preview (`.../UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:245-268`).
- The same bounded-sample assumption appears in the shared named-PairToken helper, which records `sideMatched` over at most 32 candidates (`test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol:39-53`) and degrades to an "UNVERIFIED after 32 vault candidates" log instead of a revert (`test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:214-218`, `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:186-191`).

### 7. Source observation - the literal `allowance` string comes from the plain ERC-20 stub, not from the vault or the hooks

- The string exists in `MintableERC20Decimals.transferFrom` (`contracts/test/stubs/MintableERC20Decimals.sol:56-60`), the base of `SimpleMintableERC20` (`contracts/test/stubs/SimpleMintableERC20.sol:10-12`), which is the fixture's face token (`test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol:180-184`).
- The PairToken share leg would not produce that string: Crane's ERC-20 raises `ERC20InsufficientAllowance` (`lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:157-167`).
- The dual row approves both the face and the PairToken share to the hook before the composed-gas deposit (`test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:293-300`), and the hook's deposit pulls both currencies from its caller through the external pull library (`contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookPullLib.sol:22-27`, `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol:1357-1360`).
- The identity-rejection branch of the dual bind returns before those approvals and leaves `hook == address(0)` (`.../UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:277-285`), and a call to an address without code does not raise this string either.

## Assumptions

- The supplied failure strings are accurate for the checkout state read for this response, and `0 <= 0` is the `assertGt` failure of a zero share count.
- `seUT` in every hook matrix row is the full-spread vault produced by `SeMatrix_FullSpreadV4Fixture` (`test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol:65-75`, `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol:93-95`), so one vault's quote is the shared input to every hook wrapper below.
- Face decimals are 18 in the fixture, so the quoted amounts are 1e18-scale (`test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol:50-54`, `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol:146-148`).
- The numeric planner figures in Evidence section 2 were recomputed by hand from the cited Solidity formulas; no project code was executed.
- `HookCallFailed` and the `beforeSwap` selector in the supplied strings are the outer V4/caller wrapper; the meaningful inner error is the family-specific one.

## Coverage

Named failing files, all examined:

| Named failing file | Status | Note |
| --- | --- | --- |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/UniswapV4FullSpreadStandardExchangeVault.Package.t.sol` | examined | full file (41 lines); one-sided deposit assertion at 32-34 |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | examined | full file (233 lines) |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | examined | full file (427 lines), including the shared helper library used by the other rows |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | examined | full file (249 lines) |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | examined | full file (202 lines) |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | examined | full file (318 lines) |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5.t.sol` | examined | full file (60 lines) |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | examined | full file (292 lines) |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | examined | full file (259 lines) |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol` | examined | full file (323 lines), including the shared named-PairToken helper |
| `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/AlreadyUnlocked.t.sol` | examined | full file (123 lines) |
| `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/BufferHookIntegration.t.sol` | examined | full file (115 lines); it extends the constant-product row |
| `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Native.t.sol` | examined | full file (79 lines) |

Supporting production and test sources read: the full-spread `QuoteTarget`, `Planner`, `Math`, `Execution`, `ExecutionPreparation`, `Projection`, `SwapProjection`, `Types` and `Repo`; `SeMatrix_FullSpreadV4Fixture`; the constant-product, single, dual, orbital, Balancer-quad, Curve-quad and weighted hook targets, claim libraries, join cores and pull library; `UniswapV4SeBufferHookContextQuoteLib`, `UniswapV4SeBufferHookLegLib`, `ExchangeInAmount`; Crane `ERC20Repo`, `ERC20PermitStub`, `LiquidityAmounts`, `TickMath`, `SafeERC20`; the test stubs `MintableERC20Decimals` and `SimpleMintableERC20`; the PairToken package and test base. No file outside the admitted repository scope was read, and no peer member file was opened.

## Conclusions

1. **Cause 1 - the full-spread vault's one-sided mint planner never produces a positive share quote.** Every `0 <= 0` assertion, every zero face-to-share quote, and every partial-consumption failure share this cause. The face-to-share route is `_mintOne` (`.../UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:29-31`), whose sizing `_size` can only return "no liquidity, refund everything" through its four exits (`.../UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:199-227`); with zero liquidity `_shares` produces no shares (`.../UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:230-245`) and execution refunds the full input (`.../UniswapV4FullSpreadStandardExchangeVaultExecution.sol:75-77`). For this fixture the token0 direction leaves `_size` because the fee gross-up exceeds the deposited amount, and the token1 direction leaves it because the analytic root is zero (Evidence section 2).
2. **Cause 1 also explains the hook matrix rows, but through five distinct immediate causes, one per family code path.** The shared input is the same zero quote; what differs is where each family refuses it: constant product silently drops the zero buffer quote and then cannot mint LP (`.../UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol:287-293`, `.../UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol:519-526`); the single wrapper hook reverts `MinAmountNotMet(1, 0)` on the zero preview (`.../UniswapV4SingleStandardExchangeBufferHookTarget.sol:195-205`); orbital ends the seed with no SE shares and reverts `NotLive` on the liveness check (`.../UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol:227-233`); Balancer quad, Balancer quad 5, Curve quad and the two-leg weighted row reject a zero inventory delta with `ZeroAmount` (`.../UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol:79-91`, `.../UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore.sol:111-123`, `.../UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol:223-246`); the three-leg weighted row clears its weaker first-mint gate and then reverts `BufferFailed` in the buffer commit (`.../UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol:231-236`, `.../UniswapV4StandardExchangeWeightedBufferHookTarget.sol:525-540`). Treating `InsufficientLpOut`, `MinAmountNotMet`, `NotLive`, `ZeroAmount` and `BufferFailed` as five unrelated causes would be wrong; treating them as one undifferentiated story would also be wrong, because the rejection sites differ.
3. **The partial-consumption failures are the same cause as the zero quote, not a separate one.** The assertions read the refund word of the same one-sided mint, and the vault's only non-zero refund for a one-sided mint comes from a partial `_size` result; every failing `_size` path sets the refund to the whole input (`.../UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:199-227`, `.../UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:106-117`). "Expects a residue, gets the input" is the observable of cause 1, not a separate mechanism.
4. **The package, Already-unlocked and Native `0 <= 0` assertions are cause 1 as well.** All three are one-sided face-to-share deposits asserting a positive share count (`.../UniswapV4FullSpreadStandardExchangeVault.Package.t.sol:32-34`, `.../AlreadyUnlocked.t.sol:73-86`, `.../Native.t.sol:71-77`); the borrowed-unlock context and the native/WETH boundary are not involved in producing the zero.
5. **Cause 2 - the dual `test_row_index1` PairToken failure is a bounded address-side search, independent of the quote.** The helper samples one record plus at most 32 named PairToken vault addresses and reverts with the supplied message when none compares on the requested side of the face (`.../UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:124-139`); it runs during setup before any binding or preview (`.../UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:245-268`). The same assumption exists in the other rows, where it only logs "UNVERIFIED after 32 vault candidates" (`.../UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol:39-53`).
6. **Cause 3 - the dual composed-gas `allowance` failure is a separate token-approval failure, not a full-spread quote failure.** The literal string is emitted only by the plain ERC-20 stub's `transferFrom` (`contracts/test/stubs/MintableERC20Decimals.sol:56-60`), which backs the fixture's face token (`test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol:180-184`), on the hook's currency pull path (`contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookPullLib.sol:22-27`). It is distinct from causes 1 and 2, and no vault or hook error listed in the brief produces it.

So the failures reduce to three independent causes - one vault-side quote cause with five hook-side rejection sites, one test-helper address-search cause, and one token-approval cause - not to one story and not to the seven buckets suggested by the failure strings.

## Limits

- No test, script or deployment was run; the failure strings are the supplied evidence, and the planner figures in Evidence section 2 are a hand evaluation of the cited formulas, not a runtime trace.
- For the dual `allowance` failure the admitted source establishes the failing leg (the plain ERC-20 face transfer) and that it is separate from the quote path, but not which spender/amount was short: the current row approves both legs to the hook before the deposit (`.../UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:293-300`), and no runtime stack was supplied. The deeper sub-cause is therefore unresolved.
- For the PairToken side failure the source proves the bounded-search mechanism and the cap, not why this particular deterministic sample of addresses missed the requested side.
- The source tree may have been modified concurrently while this response was written; every path and line above refers to the checkout as read during this response, and the math in Evidence section 2 is a reading of those same files.
- This is a research diagnosis. It does not recommend an implementation, does not authorize a haircut, a search or a code edit, and does not state that any of these causes is fixed by any particular change.
