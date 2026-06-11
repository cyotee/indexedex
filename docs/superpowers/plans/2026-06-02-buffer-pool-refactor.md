# Standard Exchange Buffer Pool — Refactor Plan

**Source spec:** `docs/superpowers/specs/2026-05-31-standard-exchange-buffer-pool-design.md`
**Source plan:** `docs/superpowers/plans/2026-05-31-standard-exchange-buffer-pool-plan.md`
**Status:** WIP — accumulating changes from iterative discussion. Implementation deferred until all changes captured.

This file accumulates design changes the user is making to the deployed Buffer Pool after reviewing the initial implementation. We iterate Q&A → user decision → append to this file. When the user signals done, all changes get implemented in one pass.

---

## Change 1 — Enable unbalanced add liquidity; relax "no TTA at rest" to "eventually no TTA"

### Current behavior

- `LiquidityManagement.disableUnbalancedLiquidity = true` in `StandardExchangeBufferPoolStandardVaultPkg._liquidityManagement()`.
- `StandardExchangeBufferHookTarget.onBeforeAddLiquidity` rejects `AddLiquidityKind.UNBALANCED` and `AddLiquidityKind.SINGLE_TOKEN_EXACT_OUT` with `AddLiquidityNotProportional()`.
- Original spec section 4 lists "Strict zero TTA invariant: pool's actual TTA balance held by the Balancer V3 Vault is always 0 between operations" as a decision.
- Invariant tests (Task 24 `invariant_actualTTABounded`) and spec section 8.3 assume actual TTA returns to a baseline (zero or initial-seed) after every operation.

### Target behavior

- `LiquidityManagement.disableUnbalancedLiquidity = false` so the Vault accepts UNBALANCED and SINGLE_TOKEN_EXACT_OUT add-liquidity kinds.
- The hook accepts `UNBALANCED` and `SINGLE_TOKEN_EXACT_OUT`; `onAfterAddLiquidity` updates `virtualTTA` and `hookSharesDelta` correctly based on the actual `amountsInScaled18` the math produced (no longer pure proportional scaling).
- Drop the "strict zero TTA at rest" invariant. Replace it with an **"eventually no TTA" invariant**: between operations TTA can sit in the pool; the pool is expected to migrate that TTA into the Standard Exchange Vault over time. The drain happens opportunistically (during subsequent swaps the hook drains accumulated TTA; possibly a keeper-callable `sweep()` for explicit triggering — TBD).

### Implementation notes

- **DFPkg:** flip the LM flag in `_liquidityManagement()`. The flag is the only Vault-level switch; once false, the Vault will dispatch UNBALANCED / SINGLE_TOKEN_EXACT_OUT to `BasePoolMath.computeAddLiquidityUnbalanced` / `BasePoolMath.computeAddLiquiditySingleTokenExactOut`, both of which already use our `IBasePool.computeInvariant` / `computeBalance` correctly.
- **Hook `onBeforeAddLiquidity`:** drop the UNBALANCED/SINGLE_TOKEN_EXACT_OUT rejection. Keep DONATION / CUSTOM / PROPORTIONAL passthroughs as they are.
- **Hook `onAfterAddLiquidity`:** generalize the state update. Proportional case: scale `virtualTTA` and `hookSharesDelta` by `(T+bptOut)/T` as today. Non-proportional case: increment `virtualTTA` by `amountsInScaled18[ttaIdx]` (the actual TTA the LP deposited, in scaled18 — the pool's economic position grew by exactly that on the TTA side) and increment `hookSharesDelta` by `amountsInScaled18[sharesIdx]` converted back to raw shares via the current rate (the pool's *logical* share-side position grew, but its actual shares balance also grew by the deposit, so the delta needs to stay aligned).
- **`computeBalance`:** the existing implementation already supports the math the Vault uses for SINGLE_TOKEN_EXACT_OUT. Verify the rounding direction matches Balancer's expectations (`Math.Rounding.Ceil` for "pool round-up").
- **Invariant tests:** replace the "actual TTA returns to baseline" assertion with a looser bound. New invariant: actual TTA is bounded by a function of total LP deposits + cumulative inflow from open trades — i.e. it can grow, but not exceed what's been deposited or routed through.
- **Eventual drain mechanism (open question):** the natural drain is the existing `onAfterSwap` reconcile, but it only drains the TTA the current swap just added — it doesn't sweep historical TTA accumulated from unbalanced adds. Options:
  1. Have `onAfterSwap` drain *all* accumulated TTA, not just the swap-added X. Cheapest from gas perspective when swaps are frequent.
  2. Add a permissionless `sweep()` function on the pool/hook that anyone can call to drain accumulated TTA to the Standard Exchange Vault (returns minted shares to the pool via DONATION).
  3. Both.
  This needs a follow-up decision (see Change N below or a future change entry).

### Spec/doc updates

- Spec section 2 decisions table: change "Pool reserves at rest" from "Strict zero TTA invariant" to "Eventual zero TTA — pool may hold TTA between operations; drains to Standard Exchange Vault via subsequent swap reconcile or explicit sweep."
- Spec section 4.2 (LiquidityManagement): set `disableUnbalancedLiquidity = false`.
- Spec section 6: add a new subsection 6.6 "LP add (unbalanced) / single-token-exact-out" describing the flow.
- Spec section 7.1 (errors): remove `AddLiquidityNotProportional` if it no longer fires (or keep only for unsupported kinds — none in the new design).
- Spec section 8.3 (invariants): update `invariant_PoolActualTTAStaysBoundedByBaseline` semantics; add `invariant_TTAEventuallyDrains` if we add a drain trigger.

### Test impact

- Existing proportional behaviors stay unchanged.
- Add new behavior libraries:
  - `Behavior_StandardExchangeBufferPool_LP_AddUnbalanced` — LP supplies unequal amounts of TTA and shares; assert BPT minted, `virtualTTA` updated, `hookSharesDelta` updated, residual TTA noted (and drained if a drain mechanism is wired).
  - `Behavior_StandardExchangeBufferPool_LP_AddSingleTokenExactOut` — LP supplies one token to hit an exact BPT target; symmetric assertions.
- Invariant suite: update `invariant_actualTTABounded` to the new "bounded by cumulative deposits + open trade flow" semantics.
- Unit tests: `Behavior_StandardExchangeBufferPool_Errors` should drop the AddLiquidityNotProportional unbalanced test (or rewrite it for whatever truly disallowed kinds remain — likely none).

### Risk

- The hook's `onAfterAddLiquidity` non-proportional update path is new code. Math correctness needs careful unit tests:
  - virtualTTA growth equals the LP's TTA contribution (in scaled18) for pure-TTA unbalanced adds.
  - hookSharesDelta update must keep `actualShares - hookSharesDelta` consistent with the pool's economic shares position.
- Allowing unbalanced add creates an LP-loss surface: an LP who supplies only TTA pays CP slippage relative to depositing in the SE vault first. Consider whether to document this prominently or guard via a router that auto-prefers the SE-vault-direct path.

---

## Change 2 — Package always deploys the rate provider via StandardExchangeRateProviderDFPkg

### Current behavior

- `IStandardExchangeBufferPoolPkg.PkgArgs` takes `IRateProvider rateProvider` as an input field.
- `StandardExchangeBufferPoolStandardVaultPkg.deployPool(seVault, tta, shares, rateProvider)` accepts the rate provider from the caller and passes it through to `initAccount` (where it lands in `StandardExchangeBufferPoolRepo._rateProvider`).
- Callers are responsible for deploying or sourcing the rate provider themselves before invoking `deployPool`.
- The `StandardExchangeRateProviderDFPkg` exists separately (`contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/`) and its `deployRateProvider(reserveVault, rateTarget)` is already idempotent — the Diamond Package Factory CREATE3-deploys at a salt derived from the args, so re-calling with the same `(seVault, tta)` pair returns the existing address.

### Target behavior

- The Package always deploys (or recovers, idempotently) the rate provider itself by calling `StandardExchangeRateProviderDFPkg.deployRateProvider(seVault, tta)` from inside its own deploy flow.
- `IStandardExchangeBufferPoolPkg.PkgArgs` drops the `rateProvider` field; callers supply only `(seVault, tta, shares)`.
- `IStandardExchangeBufferPoolPkg.PkgInit` gains a new immutable `IStandardExchangeRateProviderDFPkg rateProviderPkg` reference so the buffer-pool Package knows which RP package to call.
- `deployPool(seVault, tta, shares)` becomes the new signature (no rate provider arg).

### Why

- Removes a footgun: previously a caller could pass any `IRateProvider` (even a mismatched or malicious one) and the buffer-pool Package would accept it. By construction we now guarantee the rate provider is the canonical `StandardExchangeRateProviderDFPkg`-deployed instance for the `(seVault, tta)` pair.
- Single source of truth: there's exactly one rate provider per `(seVault, tta)` across the system. Different pools using the same pair share the same rate provider.
- DPF idempotency means it's safe to call on every `deployPool` invocation — no need for callers to track "did I deploy the RP yet."
- Simpler caller UX.

### Implementation notes

- **`IStandardExchangeBufferPoolPkg.PkgInit`**: add `IStandardExchangeRateProviderDFPkg rateProviderPkg;`.
- **`IStandardExchangeBufferPoolPkg.PkgArgs`**: remove `IRateProvider rateProvider;`. The struct becomes `{IERC20 tta; IERC20 shares; IStandardExchange standardExchangeVault;}`.
- **`StandardExchangeBufferPoolStandardVaultPkg` constructor**: stash the new `rateProviderPkg` as an immutable `RATE_PROVIDER_PKG`.
- **`updatePkg`**: when building the `TokenConfig[]`, call `RATE_PROVIDER_PKG.deployRateProvider(a.standardExchangeVault, a.tta)` and use the returned `IRateProvider` as the rate provider on the shares-side `TokenConfig`.
- **`initAccount`**: same — call `RATE_PROVIDER_PKG.deployRateProvider(seVault, tta)` to get the rate provider, then pass it to `StandardExchangeBufferPoolRepo._initialize(...)`.
- **`deployPool(seVault, tta, shares)`**: drop the `rateProvider` argument; the Package handles it internally.
- **`StandardExchangeBufferPool_FactoryService`**: update `buildPkgInit` to accept the rate provider package reference and include it in the `PkgInit` struct.
- **`TestBase_StandardExchangeBufferPool`**: drop the manual `_deployRateProvider` step; just pass the existing `StandardExchangeRateProviderDFPkg` reference into `buildPkgInit`. The Package will call into it during pool deployment.

### Spec/doc updates

- Spec section 3.2 (rate provider): update wording from "Configurable; users may supply an alternative `IRateProvider`" to "Deployed by the Package via `StandardExchangeRateProviderDFPkg` (always the canonical instance for `(seVault, tta)`)." Remove the "configurable rate provider" decision from section 2's decisions table — the rate provider is now an implementation detail of the Package.
- Spec section 3.3 (`StandardExchangeBufferPoolDFPkg`): update `deployPool` signature to drop the `rateProvider` parameter.
- Spec section 4.1 (TokenConfig): the shares-side `rateProvider` is the `StandardExchangeRateProviderDFPkg`-deployed instance for the registered `(seVault, tta)` pair.

### Test impact

- `Behavior_StandardExchangeBufferPool_Registration.behavior_poolIsRegisteredWithExpectedTokens` and any test that reads `pool.rateProvider()` continues to work — the address is just whatever DPF returned, and that's deterministic.
- `TestBase_StandardExchangeBufferPool`: setUp simplifies (no more manual RP deploy step).
- Add a `Behavior_StandardExchangeBufferPool_RateProviderIdempotency` test asserting two pools with the same `(seVault, tta)` registered against the same shares token end up using the same `IRateProvider` address.

### Risk

- Low. The DPF idempotency is well-established; calling `deployRateProvider` twice with the same args returns the same address. The Package becomes opinionated about which RP to use, which is a deliberate restriction (the "Configurable rate provider" affordance is being removed).
- Migration consideration: any existing deployment that passed a custom RP would need to be redeployed under the new Package signature. Since this is pre-release, that's acceptable.

---

## Change 3 — Drop `shares` argument from `deployPool` (derive from `seVault`)

### Current behavior

- `IStandardExchangeBufferPoolPkg.PkgArgs` includes both `IStandardExchange standardExchangeVault` and `IERC20 shares` fields.
- `deployPool(IStandardExchange seVault, IERC20 tta, IERC20 shares, IRateProvider rateProvider)` takes both arguments from the caller.
- In the test base (`TestBase_StandardExchangeBufferPool` lines 313/320): `seVault = IStandardExchangeProxy(vaultAddr); shares = IERC20(vaultAddr);` — they are the same address, just cast to different interfaces.

### Target behavior

- Drop the `shares` field from `PkgArgs` and the `shares` parameter from `deployPool`.
- Inside the Package, derive the share token as `IERC20(address(seVault))` everywhere it's used (registration `TokenConfig`, repo `_initialize`, pool name string, etc.).
- New `deployPool` signature (combined with Change 2): `deployPool(IStandardExchange seVault, IERC20 tta)`.

### Why

- Removes a redundant argument that's structurally guaranteed to equal `address(seVault)`. The Standard Exchange Vault is a Crane Diamond that implements both `IStandardExchange` (for `exchangeIn` / `exchangeOut` / `previewExchangeOut`) and `IERC20` (because vault shares ARE the vault contract).
- Eliminates a misuse surface: previously a caller could pass `shares = address(0xBAD)` (a token unrelated to the vault) and the Package would happily register it; the resulting pool would either fail at first swap (no shares to actually exchange) or worse, accept arbitrary token deposits while the hook tries to redeem nonexistent vault shares.
- Reflects the actual data model in code.

### Implementation notes

- **`IStandardExchangeBufferPoolPkg.PkgArgs`**: remove `IERC20 shares;`. The struct becomes `{IERC20 tta; IStandardExchange standardExchangeVault;}` (after Change 2 also dropped `rateProvider`).
- **`deployPool`**: signature becomes `(IStandardExchange seVault, IERC20 tta) external returns (address)`. Drop the `shares` argument.
- **`updatePkg` and `initAccount`**: wherever the existing code references `a.shares`, replace with `IERC20(address(a.standardExchangeVault))`. Sort indices use the same expression.
- **Sanity check on registration**: since the share token is structurally identical to the SE vault, `onRegister`'s token-order validation will pass naturally — no extra check needed beyond what `StandardExchangeBufferHookTarget.onRegister` already does.
- **Test base**: `TestBase_StandardExchangeBufferPool` stops needing a separate `shares` field for the Package call. The local `shares` accessor can stay for test convenience (it's just `IERC20(address(seVault))`).

### Spec/doc updates

- Spec section 3.3 (`StandardExchangeBufferPoolDFPkg`): update `deployPool` signature.
- Spec section 4.1 (TokenConfig): note that the share token in the registration is `IERC20(address(standardExchangeVault))` — derived, not passed in.
- Spec section 2 (decisions): tighten the "Single pair" decision to reflect that share-token identity is determined by the SE vault address.

### Test impact

- All tests calling `bufferPoolPkg.deployPool(...)` need to drop the `shares` argument. The change is mechanical.
- Add a `Behavior_StandardExchangeBufferPool_Registration.behavior_shareTokenIsSeVault` test that asserts `address(IStandardExchangeBufferPool(pool).shareToken()) == address(seVault)`.

### Risk

- Trivial. The change just removes a redundant argument.
- One subtle consequence to verify: if any code path ever needs the share token as a *fresh* `IERC20` reference (not from storage), it must derive consistently via `IERC20(address(seVault))`. Grepping the Package + hook for any `Repo._shareToken()` callers and confirming they don't make assumptions about it being a separate contract.

---

## Change 4 — Add Uniswap V2 Standard Exchange Vault integration tests (local + fork)

### Current behavior

- The deployed Buffer Pool integration tests use **only the Aerodrome (Slipstream) Standard Exchange Vault** as the underlying SE vault. `TestBase_StandardExchangeBufferPool` inherits `TestBase_BalancerV3Vault` + the Aerodrome DAI/USDC fixture from Crane's `TestBase_BalancerV3Fork_StrategyVault`.
- The repo has full production code for a **Uniswap V2 Standard Exchange Vault** at `contracts/protocols/dexes/uniswap/v2/`:
  - `UniswapV2StandardExchangeDFPkg`, `UniswapV2StandardExchangeInFacet/Target`, `UniswapV2StandardExchangeOutFacet/Target`, `UniswapV2StandardExchangeCommon`, `UniswapV2_Component_FactoryService`.
- The repo has spec tests for the Uniswap V2 SE Vault *standalone* (under `test/foundry/spec/protocol/dexes/uniswap/v2/`):
  - `TestBase_UniswapV2StandardExchange_IStandardExchangeIn`, `TestBase_UniswapV2StandardExchange_IStandardExchange`, plus tests for deposit, slippage, passthrough, IStandardExchangeIn interface.
- There are **no fork tests** for the Uniswap V2 SE Vault — `test/foundry/fork/` has zero entries matching `*Uniswap*`.
- There are **no Buffer Pool tests** (local or fork) that exercise our pool against a Uniswap V2 SE Vault.

### Target behavior

Add two new test artifacts:

**(a) Local (spec) integration tests:** Buffer Pool + Uniswap V2 SE Vault using the existing standalone V2 SE Vault test fixture as the SE vault implementation. Run through the same behaviors the Aerodrome-backed spec runner does (registration, init, swap both directions, LP add/remove, clamping, errors).

**(b) Fork tests:** Buffer Pool + a Uniswap V2 SE Vault deployed against a real Uniswap V2 Pair (e.g. WETH/USDC) on an Ethereum mainnet fork. Run smoke swaps and LP ops end-to-end against actual mainnet Uniswap V2 bytecode and a real Balancer V3 Vault (on whichever chain has both — likely Sepolia for Balancer V3, or pick a chain where both are deployed; if no shared chain, fork two chains or use Balancer V3 mainnet + Uniswap V2 mainnet on the same Ethereum mainnet fork).

### Why

- The current test stack only proves the pool works with one specific SE vault implementation (Aerodrome). The Buffer Pool's design is supposed to be SE-vault-agnostic — any `IStandardExchange` should plug in. Testing only one implementation is a confirmation-bias hazard.
- Uniswap V2 has substantively different on-chain mechanics from Aerodrome (different fee model, no concentrated liquidity, different slippage curve) — exercising both confirms the hook's pre-seat sizing and rate-provider path are correct across SE vault types.
- A real fork against actual Uniswap V2 Pair bytecode validates production-realistic conditions (real fee accrual, real pair reserves, real K-invariant) that even Layer 2 tests can't fully replicate.

### Implementation notes

**(a) Local spec stack:**

1. Refactor `TestBase_StandardExchangeBufferPool` so the SE vault wiring is overridable. Today it hard-codes Aerodrome. Extract an abstract `_deployStandardExchangeVault()` (or similar) hook the concrete subclass provides.
2. Create `TestBase_StandardExchangeBufferPool_UniswapV2` that inherits the abstract base and overrides the SE vault deployment to use the Uniswap V2 SE Vault DFPkg with two locally-deployed test ERC20s + a freshly-deployed `UniswapV2Pair` (mirror what `TestBase_UniswapV2StandardExchange_IStandardExchange` already does — it deploys real Uniswap V2 factory + pair + router locally).
3. Wire all existing behavior libraries (Registration, Initialization, Swap_TTAtoShares, Swap_SharesToTTA, LP_AddProportional, LP_RemoveProportional, Clamping, Errors, Adversarial) into a new `StandardExchangeBufferPool_UniswapV2.spec.t.sol` runner that inherits the V2-backed test base.
4. The behavior libraries themselves should not need changes — they were written generically against `IStandardExchange`. Verify by reading them.

**(b) Fork stack:**

1. Identify the target fork. Options:
   - **Ethereum mainnet** has both Uniswap V2 (canonical) and Balancer V3. Use an existing `eth_main/` fork base (we have `test/foundry/fork/eth_main/vaults/basic/...`) and add `test/foundry/fork/eth_main/balancer/v3/Fork_StandardExchangeBufferPool_UniswapV2.t.sol`.
   - **Sepolia** has Balancer V3 deployed; Uniswap V2 may also exist there. Confirm before committing.
2. Create or extend an `eth_main` Balancer V3 fork base if one doesn't already exist (we may need a new `TestBase_BalancerV3Fork_EthMain.sol`).
3. The fork test deploys our DFPkg against the live Balancer V3 Vault, deploys a fresh Uniswap V2 SE Vault wrapped around an existing live `UniswapV2Pair` (e.g. `WETH/USDC` at the canonical address `0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc`), initializes the Buffer Pool with seed liquidity, and runs round-trip swap + LP smoke tests.
4. Mirror the existing `Fork_StandardExchangeBufferPool.t.sol` (Aerodrome on Base) test shape so assertions are symmetric.

### Spec/doc updates

- Spec section 8.4 (Fork tests): expand from "Sepolia / Base fork against Aerodrome" to "Per supported SE vault implementation: Aerodrome on Base, Uniswap V2 on Ethereum mainnet."
- Spec section 8.5 (Adversarial / Property tests): add a note that the adversarial behaviors should run against every supported SE vault implementation, not just Aerodrome.

### Test impact

- Refactoring `TestBase_StandardExchangeBufferPool` to make SE vault deployment overridable will touch the existing Aerodrome-backed spec runner. Verify that the existing 20 spec tests + 8 invariants still pass after the refactor.
- New artifacts (all under `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/uniswapV2/` and `test/foundry/fork/eth_main/balancer/v3/`):
  - `bases/TestBase_StandardExchangeBufferPool_UniswapV2.sol`
  - `StandardExchangeBufferPool_UniswapV2.spec.t.sol`
  - `StandardExchangeBufferPool_UniswapV2.invariant.t.sol` (optional — copy of the Aerodrome invariant with the V2 base)
  - `test/foundry/fork/eth_main/balancer/v3/TestBase_BalancerV3Fork_EthMain.sol` (if not present)
  - `test/foundry/fork/eth_main/balancer/v3/Fork_StandardExchangeBufferPool_UniswapV2.t.sol`

### Risk

- The behavior libraries assume `_doSwap` and the Router shape from the test base. If a V2 SE vault requires different pre-approvals or has different decimals than Aerodrome's DAI/USDC, the test base needs to handle those differences (different `mintShares` / `mintTTA` helpers).
- The Uniswap V2 fee model (0.3% flat) is different from Aerodrome's stable-pool fee. The hook reads `getStaticSwapFeePercentage` from the Balancer Vault (which is a property of the Buffer Pool, not the underlying SE vault), so this is decoupled — but the SE vault's `previewExchangeOut` will reflect its own fee, and the pre-seat sizing must still produce `Y_TTA_final == Y_TTA`. Worth an explicit assertion in the new spec runner.
- Forking Ethereum mainnet is more expensive (more state) than Base mainnet. The fork test runtime may be substantial. Mitigate by pinning to a specific block with known liquidity and skipping if `ETH_MAIN_RPC_URL` (or `ALCHEMY_KEY` for eth) isn't configured.
- Discovery: if Uniswap V2 isn't deployed on the same chain as Balancer V3 in any environment we'd want to fork, this approach needs adjustment (run the SE vault on a forked eth chain and the Balancer V3 Vault on a forked Base chain — Foundry's multi-fork support handles this, but it's more complex).

---

## Change 6 — Audit + fix `UniswapV2StandardExchangeOutTarget` In/Out invariant gaps

### Current behavior (the bug)

When integrating the Buffer Pool with the Uniswap V2 Standard Exchange Vault, `BalanceNotSettled` is hit on TTA → shares swaps. Investigation pinned the root cause to a real bug in the V2 SE vault: `UniswapV2StandardExchangeOutTarget` does not implement `previewExchangeOut` / `exchangeOut` for at least Route 6 (ZapIn Vault Deposit). Specifically:

- `previewExchangeOut` Route 6 (lines 253–259): silently returns `0` with the comment "No gas efficient way to calculate the the amount in for a ZapIn to target amount out."
- `exchangeOut` Route 6 (lines 665–670): explicitly reverts `InvalidRoute(tokenIn, tokenOut)`.

The corresponding In side (`UniswapV2StandardExchangeInTarget`) fully implements Route 6 forward direction. So the same route is functional via `exchangeIn` but broken via `exchangeOut` — the In/Out invariant is violated.

This violates the design invariant that exchangeIn and exchangeOut for the same route and same conditions must be inverse-consistent (i.e. if `previewExchangeIn(tokenIn, X, tokenOut) → Y`, then `previewExchangeOut(tokenIn, tokenOut, Y)` must return X within rounding tolerance).

### Target behavior

Every route the vault advertises (Routes 1–7) must implement both `previewExchangeIn` / `exchangeIn` AND `previewExchangeOut` / `exchangeOut` such that the In/Out functions are inverse-consistent. Specifically the audit must:

1. For each of the 7 routes, inspect the `previewExchangeOut` / `exchangeOut` implementations in `UniswapV2StandardExchangeOutTarget.sol`.
2. Identify any route that returns `0`, reverts `InvalidRoute`, or computes a value inconsistent with the matching `previewExchangeIn` / `exchangeIn` in `UniswapV2StandardExchangeInTarget.sol`.
3. Implement a correct closed-form (or sufficiently-accurate iterative) inverse for any missing/broken route.
4. Add In/Out invariant tests proving the round-trip consistency for every route.

### Why the dev's "no gas efficient way" comment is wrong (Route 6 example)

The forward path is `X DAI → optimal-swap-split → LP minted → vault shares`. The reverse — "for target Y shares, what X DAI is needed?" — admits a closed-form solution that requires no square root:

1. `LP_target = _convertToAssetsUp(Y_shares, vault.vaultLpReserve, vault.vaultTotalShares, decimalOffset)` (ERC4626 inverse).
2. From the ratio-preserving LP-add constraint and V2's mint formula:
   - `Y'_swap = LP_target · r0 / (f · T)` (DAI swapped through the pair, where `f = 0.997`, `T` is pair LP supply)
   - `amount0_LP = (r0 + Y'_swap) · LP_target / T`
   - `X_required = amount0_LP + Y'_swap`
3. Round X up to favor the pool (caller supplies at-least-enough DAI).

Roughly 4 multiplications + 3 divisions. Cheaper than the forward direction (which needs a square root).

### Implementation

1. **`@crane` or indexedex local `ConstProdUtils`** — add `_quoteZapInToTargetLPWithFee(targetLP, T, r0, r1, feeNumerator, feeDenominator, kLast, ownerFeeShare, feeOn)` returning `amountIn_DAI`. Mirror the `kLast` / protocol-fee mint accounting that `_quoteSwapDepositWithFee` performs on the In side.

2. **`UniswapV2StandardExchangeOutTarget.previewExchangeOut`** Route 6 — replace the `return 0` stub:
   ```solidity
   uint256 LP_target = BetterMath._convertToAssetsUp(amountOut, vault.vaultLpReserve, vault.vaultTotalShares, ERC4626Repo._decimalOffset());
   amountIn = ConstProdUtils._quoteZapInToTargetLPWithFee(LP_target, indexSource.totalSupply, indexSource.knownReserve, indexSource.opposingReserve, indexSource.knownfeePercent, UNISWAPV2_FEE_DENOMINATOR, indexSource.kLast, UNISWAPV2_PROTOCOL_FEE_SHARE, feeOn);
   return amountIn;
   ```

3. **`UniswapV2StandardExchangeOutTarget.exchangeOut`** Route 6 — replace the `revert InvalidRoute(...)` stub:
   - Compute `amountIn` via the same inverse formula.
   - `if (amountIn > maxAmountIn) revert MaxAmountExceeded(maxAmountIn, amountIn);`
   - Secure `amountIn` of `tokenIn` from the caller (`_secureTokenTransfer` honoring `pretransferred`).
   - Run the actual `_swapDeposit` + `_setLastTotalAssets` + `_convertToSharesDown` + `_mint` sequence, identical to `exchangeIn` Route 6 lines 766–836 but with the pre-computed `amountIn`.
   - Assert the actual minted shares `>= amountOut` (otherwise revert; this guards against rounding errors that would let the caller receive fewer shares than requested).
   - Return `amountIn` actually consumed.

4. **Audit the other 6 routes** (1, 2, 3, 4, 5, 7) for similar gaps. For each route, check that the Out side has a working implementation. Where it punts (`return 0` / `revert InvalidRoute`), derive the closed-form inverse and implement.

   Likely candidates needing review based on the spec test names (which only cover slippage and execVsPreview on the In side for most routes):
   - Route 2 (Pass-through ZapIn): forward is `_swapDeposit` (DAI → LP); reverse "X LP target → ? DAI" admits similar inverse to Route 6 without the ERC4626 step.
   - Route 4 (Underlying Pool Vault Deposit): forward is LP → shares via ERC4626; reverse is a straightforward `_convertToAssetsUp`. Likely already implemented; verify.
   - Route 5 (Underlying Pool Vault Withdrawal): forward is shares → LP via ERC4626; reverse is `_convertToSharesUp`. Likely already implemented; verify.
   - The pass-through swap (Route 1) and pass-through ZapOut (Route 3) should also have closed-form reverses; verify the implementations exist and are correct.

### Tests

In `test/foundry/spec/protocol/dexes/uniswap/v2/`:

For each route `N` in 1..7, add a test contract `UniswapV2StandardExchange_RouteN_InOutInvariant.t.sol` (or one combined file) with:

- `test_routeN_previewInOutInverse_forward` — `previewExchangeIn(tokenIn, X, tokenOut) → Y`; `previewExchangeOut(tokenIn, tokenOut, Y) → X'`; assert `|X − X'| <= 1 wei`. Repeat across a small set of `(X, reserve_state)` cases.
- `test_routeN_previewInOutInverse_reverse` — symmetric: `previewExchangeOut(tokenIn, tokenOut, Y) → X`; `previewExchangeIn(tokenIn, X, tokenOut) → Y'`; assert `|Y − Y'| <= 1 wei`.
- `test_routeN_exchangeOut_matchesPreview` — `previewExchangeOut → X`; `exchangeOut(tokenIn, maxIn=X, tokenOut, Y)` returns `X` consumed (within 1 wei) and the recipient receives at least `Y` of `tokenOut`.
- `test_routeN_exchangeOut_revertsWhenMaxInsufficient` — `exchangeOut(..., maxAmountIn = X − 1)` reverts.
- Fuzz: `testFuzz_routeN_inOutInvariant` over 100 random `(X, reserve_state)` combinations.

### Spec/doc updates

- Add a section in the V2 SE Vault docs (or a NatSpec block on each Route) explicitly stating "exchangeIn and exchangeOut MUST be inverse-consistent for this route" with the round-trip assertion.

### Risk

- The closed-form derivation has to mirror the In side's `_calcVaultFee` / `_calcAndMintVaultFee` accounting exactly. If the In side mints fee shares before computing `_convertToSharesDown`, the Out side must mint fee shares before computing `_convertToAssetsUp` — otherwise the round-trip closes off by the fee-share delta. Verify by reading the In side code carefully.
- Some routes may genuinely have asymmetric forward/reverse math (e.g., where the forward path uses up-front information that the reverse can't reconstruct without iteration). For those, document the trade-off explicitly and use a binary-search inverse with a tight tolerance rather than reverting.
- Fixing the V2 SE vault Out side closes the In/Out invariant gap but **does not directly fix the Buffer Pool's `BalanceNotSettled`**. The Buffer Pool's rate provider asks the Route 7 question (`previewExchangeIn(seVault, X, rateTarget)`) while the hook executes Route 6 forward (`exchangeIn(rateTarget, X, seVault)`). These are different economic queries on a CP curve and may still produce different rates even after the vault Out side is fixed. After Change 6 lands, re-run the V2 spec runner to determine whether the BalanceNotSettled persists. If it does, follow up with a Buffer Pool design change to use exchangeOut (with a target shares amount) instead of exchangeIn for the TTA → shares hook reconcile path — that way the hook tells the SE vault exactly how many shares to mint, and the V2 vault uses the now-correct Route 6 exchangeOut implementation to compute and consume the required X DAI.

---

## Change 5 — Eliminate all hand-rolled mocks from Buffer Pool tests

### Current behavior

- `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/_HookMocks.sol` defines hand-rolled mock contracts: `MockBalancerV3Vault`, `MockStandardExchange`, `StaticRateProvider`, `HookHarness`. These are used by:
  - `StandardExchangeBufferHookTarget_PreSeat.t.sol`
  - `StandardExchangeBufferHookTarget_PostSwap.t.sol`
  - `StandardExchangeBufferHookTarget_LPAdd.t.sol`
  - `StandardExchangeBufferHookTarget_LPProportional.t.sol`
- `StandardExchangeBufferHookTarget_Registration.t.sol` and `StandardExchangeBufferPoolTarget.t.sol` use `vm.mockCall` for `IERC20.decimals` / `IERC20.approve` and a local `StaticRateProvider`.
- `StandardExchangeBufferPoolLiquidityTarget.t.sol` doesn't use a Vault mock but uses `address(this)`/`address(0xBEEF)` as bare addresses (no real ERC20 tokens).
- The integration `TestBase_StandardExchangeBufferPool` already uses Crane's `TestBase_BalancerV3Vault` (which deploys real Balancer V3 Vault code, not a mock) and a real Aerodrome SE vault — so the integration stack is already mock-free for Vault/SE vault concerns.
- These mocks were a major source of false confidence: every production bug found during Tasks 19/20 (the `exchangeOut` return-semantic flip, the fee-adjustment miss, the premature `virtualTTA` decrement, the LP TTA-conversion timing) sailed past the mock-based unit tests because the mocks didn't enforce the Vault's actual semantics.

### Target behavior

**No hand-rolled mocks anywhere in the Buffer Pool test tree.** Delete `_HookMocks.sol` and rewrite every test that uses it to drive against real Crane fork packages.

Allowed test infrastructure (all from Crane, all real bytecode, all deployable via DPF):

| Purpose | Crane package / fork |
|---|---|
| ERC20 test tokens (TTA, etc.) | `lib/daosys/lib/crane/contracts/tokens/ERC20/ERC20MintBurnOwnableOperableDFPkg.sol` — the operable-mintable ERC20 we already use elsewhere |
| WETH | `lib/daosys/lib/crane/contracts/protocols/tokens/wrappers/weth/v9/WETH9.sol` (deployed via `TestBase_Weth9` from the same dir) |
| Balancer V3 Vault | `lib/daosys/lib/crane/contracts/protocols/dexes/balancer/v3/vault/diamond/BalancerV3VaultDFPkg.sol` |
| Balancer V3 Router | `lib/daosys/lib/crane/contracts/protocols/dexes/balancer/v3/router/diamond/BalancerV3RouterDFPkg.sol` |
| Uniswap V2 (Factory / Pair / Router) for SE Vault underlying | `lib/daosys/lib/crane/contracts/protocols/dexes/uniswap/v2/stubs/{UniV2Factory.sol, UniV2Pair.sol, UniV2Router02.sol}` |
| Standard Exchange Vault wrapping the V2 pair | existing indexedex `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol` |
| Rate provider | indexedex `StandardExchangeRateProviderDFPkg` (already exists; idempotent via DPF per Change 2) |

Hand-rolled `StaticRateProvider` is **also disallowed**. Use the real `StandardExchangeRateProviderDFPkg` — it computes the rate from the actual SE vault's reserves and preview functions.

### Why

- Mocks are an attractive nuisance in this codebase: every bug found in production by integration tests was already covered by a mock test that passed. The mocks encoded the developer's *belief* about the Vault's semantics, not the Vault's actual behavior. Deleting them removes a category of false-positive signal.
- The Crane fork packages give us full real bytecode for every dependency, deployable in a local Foundry test in seconds. There's no test-velocity reason to keep mocks.
- Future contributors who see a passing test will know the test actually exercised real code.

### Implementation notes

**Delete:**
- `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/_HookMocks.sol`

**Rewrite (use real Balancer V3 Vault + real SE Vault from the Crane fork packages):**
- `StandardExchangeBufferHookTarget_PreSeat.t.sol`
- `StandardExchangeBufferHookTarget_PostSwap.t.sol`
- `StandardExchangeBufferHookTarget_LPAdd.t.sol`
- `StandardExchangeBufferHookTarget_LPProportional.t.sol`
- `StandardExchangeBufferHookTarget_Registration.t.sol` (drop `vm.mockCall` + StaticRateProvider; use real ERC20 + real rate provider)
- `StandardExchangeBufferPoolTarget.t.sol` (drop StaticRateProvider + decimals mock; use real ERC20 with real metadata + real rate provider)
- `StandardExchangeBufferPoolLiquidityTarget.t.sol` (the router-gate check can be tested via an external call from a real router contract or just direct call; either way no Vault mock needed since the function is `view`/`pure` and doesn't actually depend on Vault state)

After the rewrite, every "unit" test essentially becomes a focused integration test against the same deployed stack the spec runner uses. The structural distinction collapses to:

- **`*.t.sol` files focused on a single function/behavior** — sit alongside `bases/TestBase_StandardExchangeBufferPool.sol`, exercise the deployed stack with a narrow assertion set.
- **`StandardExchangeBufferPool.spec.t.sol`** — the omnibus runner that wires every behavior library.
- **`StandardExchangeBufferPool.invariant.t.sol`** — fuzz layer over the same stack.
- **Fork tests** — same again but against a live chain.

**Shared deployment helpers:**
- The existing `TestBase_StandardExchangeBufferPool` already does almost all of this — it deploys the real Balancer V3 Vault (via Crane's `TestBase_BalancerV3Vault`), real SE vault, real rate provider, real pool. Make it the foundation every former unit test inherits from. Expose individual sub-deployment helpers (`_deployVault()`, `_deploySEVault()`, `_deployBufferPool()`) as `internal virtual` so a slim subclass can pick just what it needs.
- For the Uniswap V2 path (Change 4), the same pattern applies: `TestBase_StandardExchangeBufferPool_UniswapV2` deploys the V2 factory/pair/router stubs + V2 SE Vault + Buffer Pool, all real.

**Token setup:**
- All test ERC20s use `ERC20MintBurnOwnableOperableDFPkg`. The test base deploys them via DPF, grants minter rights to the test contract, and uses `mint(actor, amount)` in helpers like `mintTTA`/`mintShares`.
- Where WETH is needed (Uniswap V2 router commonly expects WETH), deploy `WETH9` via `TestBase_Weth9`.

### Spec/doc updates

- Spec section 8.1 (Test base): explicitly state "No hand-rolled mocks; every dependency is the real Crane fork package."
- Spec section 8.2 (Behavior libraries): no change.
- Add a new section 8.6 "Banned testing patterns" listing: hand-rolled mock vault, hand-rolled mock SE vault, hand-rolled mock rate provider, `vm.mockCall` on production interfaces, `StaticRateProvider`, and any test contract that re-implements an interface in this repo rather than deploying the real package.

### Test impact

- All 8 mock-using unit test files are rewritten. They become slower (each one now deploys a Balancer V3 Vault) but materially more trustworthy.
- Test coverage of *exact call sequence* (which the current `MockBalancerV3Vault.observed[]` array verifies) is mostly lost; we'd instead assert end-state invariants (post-swap balances, deltas, virtualTTA / hookSharesDelta updates). If exact-call-sequence assertions are still desired for a specific test, use Foundry's `vm.expectCall` against the real Vault address — that doesn't replace the Vault, it just observes that a specific call was made.
- The hook unit test refactor will likely surface bugs the mocks hid. Plan a triage pass after rewrite.

### Risk

- One-time refactor cost is significant: ~8 files, each gets rewritten end-to-end. Maybe a day or two of subagent work.
- After the rewrite, total test runtime grows (more contract deployments per test). Acceptable trade-off; the spec runner already deploys the full stack and runs in seconds.
- A few of the current "unit" tests check things that are essentially impossible to express without a controllable Vault mock — e.g. "the hook handles `settle` returning a different amount than the hint." For those, the right answer is to delete the test rather than mock around it: in reality the Vault doesn't do that, and asserting against an impossible behavior was wasted code. If during rewrite a test seems to require mock-only behavior, document why and remove.
