# Identity

- Member: kimi
- Profile: research
- Phase: initial independent response
- Requested role: council-member
- Requested model and reasoning: kimi-coding/k3.1-pro:high
- Route: global
- Runtime identity: not exposed
- Task ID: not exposed
- Peers read before submission: no
- Fresh or continued: fresh

# Question and targets

Question: what distinct causes produce the supplied IndexedEx full-spread test failures, grouping failures only when they share a code-backed cause and keeping different code paths separate?

The targets are the package, Native, AlreadyUnlocked, BufferHookIntegration, and nine full-spread hook-matrix files named in the brief, plus the production and shared test code their supplied failures execute. The supplied strings are treated as runtime evidence, not as stack traces. This response diagnoses only; it does not recommend an implementation or authorize a haircut, search, or code edit.

# Evidence

## C1 — The vault rejects a nonzero root because gross/fee rounding leaves `applied == n - 1`

**Source observation.** Face-to-share previews call `Planner.planIn` and return its `(amountOut, amountRefunded)` directly (`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultQuoteTarget.sol:15-21`). Inside the position, `_size` computes a fee-excluded quadratic input `n_`, converts it with `Math.grossFromNet`, obtains an exact-input projection, and rejects the candidate when `quote_.applied < n_`; rejection sets `best_.remainder = amount_` (`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:191-217`). `grossFromNet` is explicitly a rounded-down `n * 1_000_000 / (1_000_000 - feePips)` (`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMath.sol:171-176`). The pool step also rounds `amountRemainingLessFee` down and, when the target is not reached, assigns that value to `amountIn` and leaves the rest as fee (`lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/SwapMath.sol:63-83`). The swap projection accumulates that `amountInStep_` into `quote_.applied` (`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultSwapProjection.sol:52-67`).

**Arithmetic inference from those exact integer formulas, not a test run.** For the package fixture's full-range position, 1,000 ether input, and 3,000-pips fee, the quadratic is nonzero: `n = 498010663111113401233`. The floored gross is `499509190683162889902`; applying the pool's floored fee exclusion gives `applied = 498010663111113401232`, exactly `n - 1`. The same direction-independent one-wei shortfall occurs for the matrix fixture with its additional external full-range LP: at 1 ether, `n = 499248760185015444` and `applied = n - 1`; at 3, 10, 100, and 1,000 ether it is also `n - 1` in both directions. The fixture establishes the 3,000 fee and full-range key (`test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol:47-51,77-82,185-225`). Thus the supplied zero quotes are explained by the explicit `quote_.applied < n_` rejection, not by a zero quadratic root and not by the later exact-output-consumption check.

**Source observation.** Once that rejection leaves liquidity at zero, `_shares` returns without assigning shares (`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:230-245`). Execution mints only a nonzero `netShares` and pays `amountRefunded` back to the caller (`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultExecution.sol:75-77,238-244`). This produces the two observed words: zero shares and a full-input refund.

**Grouping inference.** The package's `assertGt(shares, 0)` (`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/UniswapV4FullSpreadStandardExchangeVault.Package.t.sol:30-34`), AlreadyUnlocked's `assertGt(shares_, 0)` (`test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/AlreadyUnlocked.t.sol:82-86`), and Native's `assertGt(more_, 0)` (`test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Native.t.sol:70-76`) all fail on this same plan. AlreadyUnlocked changes unlock/direct-execution handling, but `Execution.exchangeIn` still calls the same `Planner.planIn` before `_run` (`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultExecution.sol:47-77,216-235`). Native changes the public face to WETH, but the planner maps native currency zero to that same WETH face before planning (`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:253-262`). Neither is a separate zero-share cause.

The partial-consumption failures are also C1, not an independent residue-accounting defect. The shared matrix helper requires `0 < refund < amount` (`test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:184-201`), while C1 returns `refund == amount`. The single-buffer row's loop cannot reduce the amount when `refund == amount`, so its final residue assertion compares the original 1 ether with 0.01 ether (`test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:74-89`). These assertions expose the full refund; they do not show a second code path.

## C2 — Constant-product buffering skips a zero quote, leaving a zero first-mint LP product

**Source observation.** The constant-product `_bufferPair` returns zero immediately when the SE preview is zero (`contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol:287-303`). Its rated reserve is zero when the hook holds no SE shares (`contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:420-427`). First mint computes `sqrt(xWad * yWad)` (`contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookMath.sol:154-156`) and reverts `InsufficientLpOut` when that geometric amount is at or below minimum liquidity (`contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol:519-527`).

**Terminal-path inference.** C1 therefore produces `InsufficientLpOut` during the initial seed, before the later hook operation. This groups the constant-product single matrix's composed gas, caller separation, buffer-first, face-index, hook-swap, partial-consumption, PoolManager-swap, and preview-match failures, plus the inherited BufferHookIntegration constant-product failures; the integration suite inherits that row (`test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/BufferHookIntegration.t.sol:18-26`). The bind failures are instead direct C1 preview assertions: the constant-product behavior requires a positive face quote (`test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol:215-218`). The selector `InsufficientLpOut` here is a first-mint consequence, not evidence of a distinct beforeSwap defect.

## C3 — The single wrapper explicitly maps a zero wrap quote to `MinAmountNotMet(1, 0)`

**Source observation.** `_wrapExactIn` previews the wrap and directly reverts `MinAmountNotMet(1, 0)` when the result is zero (`contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookTarget.sol:195-207`). `beforeSwap` calls that wrapper for exact-input wraps (`contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookTarget.sol:89-119`).

**Terminal-path inference.** This is the single-buffer matrix's composed-gas and row-swap wrapper around C1. Its bind failure is the direct positive-quote assertion (`test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:55-70`), and its partial-consumption failure is the C1 full refund described above. The wrapper selector is a separate terminal mapping, not another upstream vault cause.

## C4 — All-positive first-mint rules turn the zero inventory preview into `ZeroAmount`

**Source observation.** Balancer's first mint requires every active leg's inventory and pair amounts to be nonzero (`contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol:79-90`). Curve has the same all-four requirement (`contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore.sol:111-122`). Their `_pairToInvPreview` functions obtain a converting leg's intended inventory from the SE preview (`contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.sol:639-654`; `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.sol:790-805`). Weighted two-leg first mint requires exactly two positive inventory inputs (`contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol:223-244`).

**Terminal-path inference.** C1 makes the FullSpread leg's inventory preview zero. Balancer quad, Balancer quad 5, and Curve quad consequently hit their all-active-leg `ZeroAmount`; the two-leg weighted row hits `pos != 2`. These failures occur during join computation, before buffer execution. They share C1 upstream but use different terminal guards from C2 and C3.

## C5 — Weighted N3 permits a two-of-three first mint, then its buffer rejects the zero quote

**Source observation.** For more than two weighted legs, first mint requires only `pos >= 2`, not all legs (`contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol:223-244`). The N3 row supplies a FullSpread face, a pre-acquired PairToken share, and a raw token (`test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol:96-138`), so the latter two still provide two positive inventory inputs. `_commitJoin` then executes `_bufferLast` (`contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol:306-313`), whose buffer library reverts `BufferFailed` on a zero minimum (`contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol:338-350`).

**Terminal-path inference.** This proves the brief's weighted/N3 split. N3 does not fail at the two-leg `ZeroAmount` guard: its two nonconverting legs let first-mint computation continue, and C1 is instead surfaced by the later `BufferFailed` guard. Its partial-consumption failure remains C1's full refund.

## C6 — Orbital permits a partial seed but cannot make all three legs live

**Source observation.** Orbital first mint requires only two offered legs and calculates shares from the sum of effective preview values (`contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:1029-1043`). The FullSpread preview contributes zero through `_previewClaimInAt`, while raw and identity legs can still contribute positive values (`contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:1101-1121`). Orbital's buffer does not reject a zero minimum before calling the SE (`contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:624-642`), but `_isLive` requires every leg live and a converting leg is live only when the hook holds its SE shares (`contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:168-178`). Swap quoting separately reverts `NotLive` when the input effective native amount is zero (`contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol:124-129`).

**Terminal-path inference.** The orbital row's three records are one converting FullSpread face, one PairToken identity, and one raw leg (`test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:50-58`). The latter two permit a partial first mint, but C1 leaves no FullSpread shares on the hook. The subsequent composed-gas, index0, index1, PoolManager-swap, and rate-target swaps therefore reach `NotLive`. This is not the stable/weighted first-mint `ZeroAmount` path, and the partial-consumption row is again the direct C1 full refund.

## C7 — The dual gas row uses a stale base hook/pool after rejected identity binding

**Source observation.** The dual base setup assigns `dual = IDualHook(hook)` for its default tokenA/tokenB product and approves those tokens to that hook (`test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook.sol:119-149`). The FullSpread row's `_bindDual` catch records a rejected bind, sets only `hook = address(0)`, and returns before deploying the replacement or funding/approving its face and PairToken share (`test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:270-299`). It does not clear the base `dual` object or rebuild the base `poolKey`. Other dual paths call `_requireIdentity`, but `test_composedRouteGasFitsCeiling` calls `_seed` and `_swapExactIn` without that guard (`test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:303-310,421-426`). The router pays the PoolManager with `transferFrom(payer, ...)` (`contracts/test/stubs/WrapperExactOutRouter.sol:97-105`), and the mintable token reverts with the literal `allowance` when that allowance is absent (`contracts/test/stubs/MintableERC20Decimals.sol:54-62`).

**Terminal-path inference.** The supplied dual composed-gas `allowance` is therefore a fixture-routing failure: the row can seed the stale default hook and then swap the stale default pool through a router that has no default-token payer approval. It is not C1 and not a dual production buffer allowance failure. The guarded identity paths do not take this route.

## C8 — The dual index1 fixture exhausts its bounded PairToken address-side search

**Source observation.** `FullSpreadV4MatrixChecks.pair` initializes one PairToken record, tries at most 32 additional named vaults, and returns only when `(face < share) == faceAtZero_`; otherwise it reverts `no PairToken share on the requested side of the face` (`test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:119-141`). `test_row_index1` requests `faceAtZero_ == false` through `_configureDual(false)` (`test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:338-344`).

**Terminal-path inference.** The supplied message is exactly the exhaustion branch, before a successful index1 hook configuration. It is a bounded-fixture-search failure, independent of C1's quote arithmetic and C7's later stale-hook allowance route.

# Assumptions

- The supplied strings accurately identify the observed failures, but no stack traces were supplied. Terminal paths above are source-path inferences tied to those strings; C1's one-wei values are independent arithmetic evaluation of the cited source formulas and fixture values, not EVM output.
- Matrix preview arithmetic assumes the fixture immediately after its real external-LP seed and bootstrap, before any later state-changing row operation; those are the two full-range positions constructed by the fixture (`test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol:185-225`).
- C7 assumes the recorded identity-rejection branch is the one accompanying the supplied allowance failure. That is the only row branch that clears `hook` while leaving the base `dual`/`poolKey` and skipping replacement approvals (`test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:279-299`).
- The optional implementation plan was read for context only. It is not used as proof of any runtime cause, and the remediation PRD it cites was not read.

# Coverage

Every named failing file was examined.

| Failing file | Status | Cause assignment |
| --- | --- | --- |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/UniswapV4FullSpreadStandardExchangeVault.Package.t.sol` | examined | C1 |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | examined | C1 direct bind; C2 seed/row family |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | examined | C1 partial consumption; C7 composed gas; C8 index1 |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | examined | C1 partial consumption; C6 swap family |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | examined | C1 direct bind/partial; C3 wrap swaps |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | examined | C1 partial; C4 row family |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5.t.sol` | examined | C1 partial; C4 row family |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | examined | C1 partial; C4 row family |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | examined | C1 partial; C4 row family |
| `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol` | examined | C1 partial; C5 row family |
| `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/AlreadyUnlocked.t.sol` | examined | C1 |
| `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/BufferHookIntegration.t.sol` | examined | C1 direct bind; C2 inherited row family |
| `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Native.t.sol` | examined | C1 |

# Conclusions

There are eight distinct terminal causes, with one shared upstream vault cause:

1. **C1:** floored gross-up followed by floored pool fee exclusion makes `applied = n - 1`; `Planner._size` rejects the nonzero candidate and returns zero shares with a full-input refund. This directly explains Package, AlreadyUnlocked, Native, all direct `SE quotes the face` failures, and every supplied partial-consumption/full-refund assertion.
2. **C2:** constant-product skips the zero buffer and computes zero first-mint LP, yielding `InsufficientLpOut` across its row family and BufferHookIntegration.
3. **C3:** the single wrapper's explicit zero-quote guard yields `MinAmountNotMet(1, 0)`.
4. **C4:** Balancer quad, Balancer quad 5, Curve quad, and two-leg weighted reject the zero inventory preview under their all-positive first-mint rules, yielding `ZeroAmount`.
5. **C5:** weighted N3 gets past its two-of-three first-mint rule using PairToken plus raw inventory, then yields `BufferFailed` when the FullSpread buffer preview is zero.
6. **C6:** orbital also gets past a partial first mint, but its FullSpread leg remains without SE shares, so subsequent swaps yield `NotLive`.
7. **C7:** the dual composed-gas row lacks the identity guard and routes through stale base `dual`/`poolKey` state after a rejected replacement bind, producing an unrelated fixture `allowance` failure.
8. **C8:** dual index1 exhausts the explicit 32-candidate PairToken address-side search and reverts before hook configuration.

C2-C6 are different downstream surfacings of C1, not five more vault defects. C7 and C8 are independent dual-test fixture causes. The evidence does not support separate Native, AlreadyUnlocked, or partial-consumption root causes, and it does not support collapsing C2-C8 into one terminal code path.

# Limits

- Per instruction, I did not run Forge, the project tests, Cast, installs, Git, or deployments. No runtime stack trace was available to replace the cited static terminal-path inferences.
- The arithmetic in C1 was independently derived from the read integer formulas and fixtures; it was not emitted by an EVM run. It rules out a zero root for the examined package and matrix preview cases and identifies the subsequent one-wei guard as the rejecting condition.
- The remediation PRD cited by the optional plan was not read. No requirement is inferred from that omission, and the plan itself was not treated as runtime evidence.
- Only the named failing files and dependencies needed for their paths were examined. No peer response was read.
