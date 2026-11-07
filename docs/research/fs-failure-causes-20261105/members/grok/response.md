# Identity

- Member: grok
- Profile: research
- Phase: initial independent response
- Requested role: council-member
- Requested model: xai/grok-4.7:xhigh
- Runtime identity: not exposed
- Task ID: not exposed
- Peers read before submission: no
- Fresh or continued: fresh

This is a research diagnosis. It does not replace the brief, authorize implementation, or authorize a haircut, a search, or a code edit.

# Question and targets

Question: What distinct causes produce the supplied IndexedEx full-spread test failures? Group failures that share one cause. Keep causes separate when the code paths differ.

Targets: the failing tests named in `docs/research/fs-failure-causes-20261105/brief.md`, and the production or test code those failures execute.

The supplied failure strings are runtime evidence. They were not re-run. Optional context, `docs/reviews/se-fullspread-plan-execution-20261104/IMPLEMENTATION_AND_TEST_PLAN.md` and the remediation PRD it cites, was not read. That absence is a gap. It is not used as proof of a runtime cause.

# Evidence

## Cause A. One-sided face-to-share plan returns zero shares and refunds the whole input

The quote and the execution call the same planner.

Observation, source. `previewExchangeIn` builds `Planner.planIn` and returns `(0, 0)` only when the kind is `Unsupported` or `plan.failed` is set. Otherwise it returns `(plan.amountOut, plan.amountRefunded)`.

```14:18:contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultQuoteTarget.sol
function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
    external
    view
    returns (uint256 amountOut, uint256 amountRefunded)
{
    Types.Plan memory plan_ = Planner.planIn(address(tokenIn), amountIn, address(tokenOut));
    if (plan_.kind == Types.Kind.Unsupported || plan_.failed) return (0, 0);
    return (plan_.amountOut, plan_.amountRefunded);
}
```

Observation, source. A face in and the share out is `_mintOne`, not a pass-through and not an exit.

```28:30:contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol
if (tokenOut_ == share_ && (tokenIn_ == face0_ || tokenIn_ == face1_)) {
    return _mintOne(amountIn_, tokenIn_ == face0_);
}
```

Observation, source. `_shares` sets `amountOut` only when `liquidityAdded` is nonzero. A zero liquidity addition returns with `amountOut` still 0 and `failed` still false.

```230:245:contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol
function _shares(Types.Plan memory plan_, uint128 liquidityBefore_) private view {
    uint256 supply_ = ERC20Repo._totalSupply();
    if (plan_.liquidityAdded == 0) return;
    if (supply_ == 0) {
        if (plan_.liquidityAdded <= Types.MIN_SHARES) {
            plan_.failed = true;
            return;
        }
        // ...
    }
    plan_.amountOut = plan_.netShares;
}
```

Observation, source. Execution reverts `MinLiquidityNotMet` when `plan.failed` is set. A call that returns is not that branch.

```62:63:contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultExecution.sol
if (plan_.failed) revert IVault.MinLiquidityNotMet();
```

Observation, source. In range, with active liquidity, `_size` has five full-remainder exits. Each sets `remainder` to the whole input and leaves `liquidity` at 0. There is no smaller retry. The comment on the function says the size is one exact-input swap, not a search.

```192:226:contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol
if (active_ == 0) {
    best_.remainder = amount_;
    return best_;
}
// ...
if (n_ == 0) {
    best_.remainder = amount_;
    return best_;
}
// ...
if (gross_ == 0 || gross_ > amount_) {
    best_.remainder = amount_;
    return best_;
}
// ...
if (quote_.applied < n_ || quote_.received == 0 || quote_.spent == 0 || crossed_) {
    best_.remainder = amount_;
    return best_;
}
best_ = Math.sizeOneSided(/* ... */);
if (best_.liquidity == 0 || best_.swapIn == 0) {
    best_.swapIn = 0;
    best_.swapOut = 0;
    best_.unswapped = 0;
    best_.liquidity = 0;
    best_.remainder = amount_;
}
```

Observation, runtime, single-buffer partial consumption. The failure is `one-sided remainder stays a rounding residue, not the input: 1000000000000000000 >= 10000000000000000`. That is `assertLt(refund, amount / 100)` with `refund == 1e18` and `amount / 100 == 1e16`.

```76:84:test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol
function test_row_partialConsumption_bookedNotRefunded() public override {
    uint256 amount = _f(1);
    uint256 refund = 1;
    for (uint256 i; i < 8 && refund != 0; ++i) {
        (, refund) = IFullSpreadTuple(seUT).previewExchangeIn(face, amount, seUT);
        if (refund != 0 && amount > refund) amount -= refund;
    }
    (, refund) = IFullSpreadTuple(seUT).previewExchangeIn(face, amount, seUT);
    assertLt(refund, amount / 100, "one-sided remainder stays a rounding residue, not the input");
```

Inference from that measurement, not from a re-run. A failed plan previews `(0, 0)`, so `refund` would be 0 and `assertLt(0, amount / 100)` would pass. The measured `refund == 1e18` is the full-remainder word, not the failed-plan word. The loop cannot shrink `amount` when `refund == amount`, because the subtraction requires `amount > refund`. The same `previewExchangeIn` is what the bind rows compare against zero.

Observation, runtime. These assertions failed as `0 <= 0` or `SE quotes the face: 0 <= 0`:

- Constant-product bind, `assertGt(ExchangeInAmount.previewOut(...), 0, "SE quotes the face")` at `UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol:217`. `ExchangeInAmount.previewOut` returns only the share word (`contracts/utils/ExchangeInAmount.sol:8-11`).
- Single-buffer bind, `assertGt(quoted, 0, "SE quotes the face")` at `UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:68`.
- `BufferHookIntegration.t.sol` inherits that constant-product row (`BufferHookIntegration.t.sol:19`). Its supplied bind failure is the inherited assertion.
- Package `test_oneSidedDepositThenExit` calls `exchangeIn` and then `assertGt(shares, 0)` (`UniswapV4FullSpreadStandardExchangeVault.Package.t.sol:31-32`). The supplied failure is an assertion, not `MinLiquidityNotMet`.
- AlreadyUnlocked `test_borrowedExchangeInMintsAndClearsDeltas` decodes the returned tuple and `assertGt(shares_, 0)` (`AlreadyUnlocked.t.sol:84-86`). A revert inside the unlocked call would have surfaced as that revert, not as `0 <= 0`.

Observation, source. The matrix fixture is not an empty pool at the bind quote. It initializes at `2^96`, adds independent full-range liquidity, then bootstraps the vault with a balanced bundle (`SeMatrix_FullSpreadV4Fixture.sol:184`, `163-187`, `189-204`). The vault position itself is min-to-max usable ticks (`UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol:184-186`). The usage-fee mapping returns 0 unless set (`VaultFeeOracleRepo.sol:184-185`). A zero fee does not consume gross shares (`Planner.sol:248-253` and `Math.sol` `netShares`).

Inference. After that bootstrap, a returned share word of 0 on a non-failed plan is `liquidityAdded == 0`. That is one of the full-remainder exits in `_size`. Which of those five predicates fired was not isolated. No forge run was used to isolate it. "No active liquidity" and "price outside the position" are rejected for the matrix bind: the fixture has both external liquidity and an in-range full-range position before the test body.

The Package, AlreadyUnlocked, and Native tests use `TestBase_UniswapV4FullSpreadStandardExchangeVault`, which initializes the pool at `2^96` and does not add external liquidity (`TestBase_UniswapV4FullSpreadStandardExchangeVault.sol:67-75`). Each failing test, or its `setUp`, first does a balanced bundle. Package's sibling `test_bootstrapBundleDepositMintsShares` is not in the supplied failures and asserts `positionLiquidity() > 1000` (`Package.t.sol:20`). The one-sided call is a later call in `test_oneSidedDepositThenExit`. Absence of the fixture's external LP is not required for the zero: the one-sided call still returned 0 after a bundle that the same planner prices with `proportional`, not `_size` (`Planner.sol:38-48`).

AlreadyUnlocked reaches the same `planIn`. Its caller is a contract, `pretransferred` is false, and `exchangeIn` is allowed while the manager is already unlocked (`Execution.sol:190-201`). The unlocked path still plans with `planIn` and mints `plan.netShares` (`Execution.sol:71-74`). A settlement or context failure on that path reverts `InvalidUnlockedContext`, `SettlementMismatch`, or `ManagerAlreadyUnlocked`. The supplied failure is a returned zero. That is Cause A, not a separate unlock defect.

Native settlement unwraps WETH and settles native value (`ExecutionPreparation.sol:88-100`). A settle mismatch reverts `SettlementMismatch`. It does not return a zero share word. The native test has two `assertGt(..., 0)` calls (`Native.t.sol:74` on the bundle, `Native.t.sol:76` on the one-sided WETH deposit). The supplied string does not name the line. Inference: the bundle uses `proportional` on equal in-range amounts and is not the `_size` path; the one-sided call is the Cause A path. That line identification is not proved by the failure string. See Limits.

## Cause B. Hook paths turn that zero into different errors. These are not one beforeSwap wrap.

The zero share word is Cause A. The reported hook error depends on which guard reads it. The hypothesis that `beforeSwap` wraps the zero into every one of `MinAmountNotMet`, `InsufficientLpOut`, `ZeroAmount`, `BufferFailed`, and `NotLive` is rejected. Only the single-buffer exact-in wrap and the orbital liveness check are `beforeSwap` failures. The others revert on a direct join or deposit, which is why the supplied strings are not `HookCallFailed`.

PoolManager does wrap a failing hook call. `Hooks.callHook` reverts `HookCallFailed` when the hook call fails (`lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol:131-139`), and `beforeSwap` uses that helper (`Hooks.sol:257-258`). That wrap is the outer error only where the failing call is a pool swap.

### B1. Constant product: deposit, `InsufficientLpOut`, not `beforeSwap`

Observation, source. `_bufferPair` reads the face-to-share preview and returns 0 without exchanging when that preview is 0.

```282:289:contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol
function _bufferPair(uint256 amount) internal returns (uint256 seOut) {
    if (amount == 0) return 0;
    // ...
    (uint256 minOut,) = IStandardExchangeIn(l.standardExchange).previewExchangeIn(
        IERC20(l.pairToken), amount, IERC20(l.standardExchange)
    );
    if (minOut == 0) return 0;
```

Observation, source. The pair-side reserve is the SE claim, and a zero share balance rates to 0 (`Target.sol:187-190`, `ClaimLib.sol:420-423`). First mint then takes `sqrt(xWad * yWad)` (`HookMath.sol:154-155`). A zero side is 0, and 0 is not above `MINIMUM_LIQUIDITY`.

```895:901:contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol
function _firstMint(uint256 used0, uint256 used1, address to) internal returns (uint256 lpAmount) {
    _intakePoolAmounts(used0, used1);
    uint256 geometric = Math.mintSharesFirst(/* pair-side reserve is the SE claim */);
    if (geometric <= Repo.MINIMUM_LIQUIDITY) revert InsufficientLpOut();
```

`beforeSwap` on this hook does not revert `InsufficientLpOut`. A zero exact-in output there reverts `ZeroAmount` (`Target.sol:557`). The supplied constant-product failures are `InsufficientLpOut`, so they are not that swap guard.

The V4 matrix rows that the brief names call `_seed` or `_swapExactIn` after `_seed` (`UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:68-80`, `94-108`, `181-189`, `221-224`). `_seed` is `_joinBoth` into `single.deposit` (`SeMatrixBehavior.sol:161-170`). That deposit is the first mint above. `BufferHookIntegration.t.sol` inherits those rows. Its supplied `InsufficientLpOut` on the constant-product row family is this deposit, including its own gas override, which calls `_swapExactIn` only after the inherited seed path is not the first call in every row; the rows that call `_seed` fail at the seed. The bind row fails earlier at Cause A's quote assertion, before `_seed` (`SeMatrixBehavior.sol:217-219`).

`test_row_seFailure_rollsBack` is not in the supplied constant-product failures. It expects `AmountOutNotMet(quoted + 1, quoted)` (`V4 matrix file, lines 170-176`). A zero non-failed quote makes that expected selector match. That is consistent with Cause A and is not an additional cause.

### B2. Single buffer: `beforeSwap` wraps the zero as `MinAmountNotMet(1, 0)`

Observation, source. The wrap preview is the vault preview's share word.

```92:96:contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookCommon.sol
function _previewWrap(uint256 pairIn) internal view returns (uint256 seOut) {
    _requireNonZero(pairIn);
    (uint256 quotedAmountOut,) = IStandardExchangeIn(se).previewExchangeIn(IERC20(pair), pairIn, IERC20(se));
    return quotedAmountOut;
}
```

Observation, source. Exact-in `beforeSwap` calls `_wrapExactIn`, which reverts `MinAmountNotMet(1, 0)` when that word is 0 (`Target.sol:118-161` and `195-200`).

```195:200:contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookTarget.sol
function _wrapExactIn(uint256 pairIn, Currency pairC, Currency seC)
    internal
    returns (uint256 seOut)
{
    seOut = _previewWrap(pairIn);
    if (seOut == 0) revert IStandardExchangeErrors.MinAmountNotMet(1, 0);
```

The supplied `WrappedError` / `beforeSwap` / `MinAmountNotMet(1, 0)` / `HookCallFailed` on composed gas and the row swaps is this guard, wrapped by `Hooks.callHook`. The bind failure in the same file is Cause A, read directly, not through `beforeSwap`. The partial-consumption failure in the same file is Cause A's refund word, measured as the whole input. It is not a second production defect and it is not a `beforeSwap` wrap.

### B3. Weighted N2, Balancer quad, Balancer quad 5, and Curve quad: first-mint `ZeroAmount`

Observation, source. Join inventory for a buffered leg is `ExchangeInAmount.previewOut` of the face into the SE. A raw leg copies the pair amount.

```612:625:contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol
if (se == address(0) || se == l.tokens[i]) {
    invDeltas[i] = pairAmounts[i];
} else {
    invDeltas[i] = ExchangeInAmount.previewOut(/* token, amount, se */);
}
```

The curve and balancer copies are the same mapping (`Curve Target.sol:790-802`, `Balancer Target.sol:639-652`).

Observation, source. A two-token weighted first mint reverts `ZeroAmount` unless both inventories are positive. A four-token curve first mint, and the balancer first mint, revert `ZeroAmount` if any inventory is 0.

```122:128:contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookLiquidityTarget.sol
if (n == 2) {
    if (pos != 2) revert ZeroAmount();
} else {
    if (pos < 2) revert ZeroAmount();
}
```

```84:86:contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityTarget.sol
if (invAmounts[i] == 0 || pairAmounts[i] == 0) revert ZeroAmount();
```

```84:86:contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol
if (invAmounts[i] == 0 || pairAmounts[i] == 0) revert ZeroAmount();
```

The V4 weighted, curve, and balancer rows call `joinProportional` from `_seedWeighted`, `_seedCurve`, or `_seedBalancer` before any pool swap (`weighted V4 matrix file, lines 131-136`; `curve V4 matrix file, lines 127-132`; `balancer V4 matrix file, lines 164-169`). Balancer quad 5 inherits that seed (`...Vault_5.t.sol:11-16`, `54-56`). A zero face preview makes the buffered inventory 0, so these first-mint guards revert `ZeroAmount` before `_bufferToken`. That matches an unwrapped `ZeroAmount()` and rejects a `beforeSwap` wrap for this group. `_bufferToken` in these families would have reverted `BufferFailed` on a zero preview (`Weighted Target.sol:534-535`, `Curve Target.sol:703`, `Balancer Target.sol:556`). The supplied error is `ZeroAmount`, so those rows do not reach that later guard.

### B4. Weighted N3: the count check passes, then `_bufferToken` reverts `BufferFailed`

Observation, source. For `n != 2`, the weighted first mint allows a partial book when at least two inventories are positive (`LiquidityTarget.sol:127-128`). N3 then commits and buffers every positive leg.

```591:595:contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol
function _bufferLast(uint256[] memory pairAmounts) internal {
    for (uint8 i; i < l.numTokens; ++i) {
        if (pairAmounts[i] > 0) _bufferToken(i, pairAmounts[i]);
    }
}
```

```534:535:contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol
(uint256 minOut,) = IStandardExchangeIn(se).previewExchangeIn(IERC20(t), amount, IERC20(se));
if (minOut == 0) revert BufferFailed();
```

`_seedThree` calls the same `joinProportional` (`N3 file, lines 168-174`). The supplied row-family error is `BufferFailed`, not `ZeroAmount`. Inference from that difference: the N3 first-mint count check passed, so at least two inventories were positive, and the buffered face then hit `minOut == 0`. That is a different guard from B3. It is the same zero preview. It is not `beforeSwap`.

### B5. Orbital: the buffer does not revert on a zero quote; the later face swap reverts `NotLive`

Observation, source. Orbital `_bufferToken` passes the preview through as `minOut`, including 0. It does not revert `BufferFailed` or `ZeroAmount` on a zero preview (`Orbital Common.sol:624-640`). Vault execution with `minOut == 0` and a non-failed zero share word returns `(0, refund)` rather than reverting (`Execution.sol:62-66`).

Observation, source. `beforeSwap` calls `_swapExactInExecute` (`Orbital HooksTarget.sol:278-310`), which quotes through `ClaimLib.previewSwapExactInContext` with no manager (`Common.sol:810-819`). That quote loads the book and reverts `NotLive` when `R` is 0 or either effective reserve is 0.

```868:877:contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol
function _loadSwapLiveCtxBook(address tokenIn, address tokenOut) private view returns (SwapLiveCtx memory ctx) {
    if (l.R == 0) revert NotLive();
    uint256 eIn = _effectiveNativeOf(tokenIn);
    ctx.eOutNative = _effectiveNativeOf(tokenOut);
    if (eIn == 0 || ctx.eOutNative == 0) revert NotLive();
```

`ClaimLib.previewSwapExactInContext` calls that loader when `manager == address(0)` (`ClaimLib.sol:175-181`).

The supplied orbital failures on composed gas, index0, index1, poolManager swap, and rate target are `WrappedError` / `beforeSwap` / `NotLive` / `HookCallFailed`. Those rows call `_seedMixed` and then `_swapExactIn` (`orbital V4 matrix file, lines 111-116`, `150-164`, `243-247`). `_seedMixed` asserts the deposit returned shares. The supplied error is a wrapped `beforeSwap` revert, not that assertion and not `ZeroAmount`. Inference: the direct deposit returned, and the face swap then failed the liveness check because the face effective reserve was still 0 after a zero-quote buffer. That is a different code path from B2's `MinAmountNotMet(1, 0)` and from B4's `BufferFailed`.

## Cause C. Partial-consumption residue checks fail because Cause A refunds the whole input

This is not a separate production cause. It is a different assertion on Cause A's refund word.

Observation, source. `FullSpreadV4MatrixChecks.refunds` first requires a face-to-other pass-through to refund 0, then requires a one-sided mint refund to be strictly between 0 and the input.

```183:195:test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol
(, uint256 fullRefund_) = IFullSpreadV4MatrixMoney(fx_.se()).exchangeIn(
    face_, 1 ether, out_, 0, address(this), false, block.timestamp
);
require(fullRefund_ == 0, "fully consumed control has no refund");
(uint256 quoted_, uint256 refund_) =
    IFullSpreadV4MatrixMoney(fx_.se()).previewExchangeIn(face_, amount_, shares_);
require(refund_ > 0 && refund_ < amount_, "one-sided mint cannot fully consume");
```

Observation, runtime. Orbital, balancer quad, balancer quad 5, curve quad, weighted, and weighted N3 report `one-sided mint cannot fully consume` on partial consumption, not `fully consumed control has no refund`. Those overrides call `refunds` (`orbital V4 file line 190`, `balancer V4 file line 259`, `curve V4 file line 232`, `weighted V4 file line 200`, `N3 file line 264`). The pass-through control therefore passed. Face-to-other exact input is not the failing path.

The single-buffer file does not call `refunds`. Its own assertion measured `refund == 1e18`. A full remainder fails `refund < amount`. A zero refund would also fail `refund > 0`, but the single-buffer numbers reject that reading for this vault. Inference: the other families' require fails for the same full-remainder word, because they call the same `previewExchangeIn`. Their failure strings do not print the refund, so `refund == 0` remains possible for those files alone. It is not the reading that also explains Cause A.

Constant-product partial consumption is not this assertion. Its inherited row calls `_seed` first (`SeMatrixBehavior.sol:240-241`) and is in the supplied `InsufficientLpOut` group. That is B1.

Dual partial consumption calls `refunds` only after `_requireIdentity` (`dual V4 file, lines 378-380`). It is not in the supplied dual failures. See Cause D.

## Cause D. Dual allowance and the PairToken-side search are not the quote

### D1. `test_row_index1` exhausts the share-side search

Observation, source. The only `revert("no PairToken share on the requested side of the face")` is the harness search. It tries the initial share, then 32 `deployNamed` candidates, and reverts if none sorts on the requested side of the fixture face.

```124:134:test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol
function pair(SeMatrix_FullSpreadV4Fixture fx_, bool faceAtZero_) internal returns (FullSpreadV4MatrixPairToken record_) {
    record_ = new FullSpreadV4MatrixPairToken();
    record_.initialize(address(this));
    if (_shareSide(fx_, record_.share(), faceAtZero_)) return _checkedPair(fx_, record_);
    for (uint256 i_; i_ < 32; ++i_) {
        address share_ = record_.deployNamed(/* ... */);
        if (_shareSide(fx_, share_, faceAtZero_)) return _checkedPair(fx_, record_);
    }
    revert("no PairToken share on the requested side of the face");
}
```

`test_row_index1` reverts to the pre-pair snapshot and calls `_configureDual(false)` (`dual V4 file, lines 342-347`). That requests the opposite side from `setUp`, which calls `_configureDual(true)` (`lines 245-263`). Inference: the `true` search returned, because a failure there would have failed `setUp` for every test in the file. The supplied index1 failure is the `false` search exhausting 32 candidates. It does not call the vault quote, the hook, or `beforeSwap`.

### D2. Composed gas reverts `allowance` because the identity bind is rejected and the replacement router was never approved

Observation, source. The dual package accepts `token == standardExchange` only when `asset()` (`0x38d52e0f`) returns a different nonzero underlying. Otherwise the token must appear in `vaultTokens()`.

```172:177:contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol
function isWrapperShareInventory(address pair, address se) internal view returns (bool) {
    if (pair == address(0) || pair != se) return false;
    (bool ok, bytes memory data) = pair.staticcall(abi.encodeWithSelector(bytes4(0x38d52e0f)));
    if (!ok || data.length < 32) return false;
    address underlying = abi.decode(data, (address));
    return underlying != address(0) && underlying != pair;
}
```

```384:397:contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg.sol
_requireTokenInVaultTokens(a.standardExchange0, a.token0);
_requireTokenInVaultTokens(a.standardExchange1, a.token1);
// ...
function _requireTokenInVaultTokens(address se, address token) private view {
    if (UniswapV4SeBufferHookLegLib.isWrapperShareInventory(token, se)) return;
    address[] memory tokens = IBasicVault(se).vaultTokens();
    // ...
    revert TokenNotInVaultTokens();
}
```

Observation, source. The pair-token vault directory has `assetInfo()`, not `asset()`. The staticcall does not succeed. `_configureDual` sets `standardExchange1` and `token1` both to the PairToken share (`dual V4 file, lines 262-275`). `processArgs` therefore reverts `TokenNotInVaultTokens`. The test catches that, sets `identityAccepted` false, sets `hook` to `address(0)`, and returns without deploying or approving (`lines 276-283`).

Observation, source. `setUp` still constructs a new `WrapperExactOutRouter` on the full-spread manager before that rejection (`dual V4 file, lines 253-254`). The parent `setUp` has already deployed a dual hook, bound `poolKey`, and approved `tokenA` and `tokenB` only to that parent hook (`TestBase_UniswapV4DualSEBCPHook.sol:104-117`, `149-160`). Those tokens are `SimpleMintableERC20`, whose `transferFrom` reverts `allowance` unless the allowance is `type(uint256).max` or at least the amount.

```55:58:contracts/test/stubs/MintableERC20Decimals.sol
function transferFrom(address from, address to, uint256 amount) external virtual override returns (bool) {
    uint256 allowed = allowance[from][msg.sender];
    if (allowed != type(uint256).max) {
        require(allowed >= amount, "allowance");
```

Observation, source. Composed gas does not consult `identityAccepted`. It calls `_seed`, then `_swapExactIn` (`dual V4 file, lines 421-426`). `_swapExactIn` pranks `user` and calls the replacement router on the still-parent `poolKey` (`SeMatrixBehavior.sol:204-214`). The router `transferFrom`s the payer before it swaps (`WrapperExactOutRouter.sol:79-81` and `97-102`). The user never approved that new router.

Inference. The seed pull is not this revert: `dual.deposit` still points at the parent hook, and the parent tokens were approved to that hook. The unapproved `transferFrom` is the composed-gas swap. The reported string `allowance` is `MintableERC20Decimals`'s require, not a vault error and not Cause A. The router is also bound to a different manager than the leftover `poolKey`; that mismatch is on the same call, but `_settle` reverts `allowance` before the swap would report it.

Rows that call `_requireIdentity` return after recording the rejected bind (`dual V4 file, lines 303-307`). They are not the supplied dual failures.

# Assumptions

- The supplied failure strings are the forge failures for the named files. They were not re-run.
- `assertGt(x, 0)` failing as `0 <= 0`, and `assertLt` failing as `a >= b`, is the forge-std assertion format. The custom messages in the brief match the assertions cited above.
- `0x38d52e0f` is `asset()`, as the comment on `isWrapperShareInventory` states. The selector was not recomputed.
- The usage-fee mapping is unset in the Package, AlreadyUnlocked, and Native setups. No assignment to `setUsageFeeOfVault` was found in those tests.
- V3 full-spread matrix files are not the named failures. See Coverage.

# Coverage

Examined:

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/UniswapV4FullSpreadStandardExchangeVault.Package.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/AlreadyUnlocked.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Native.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/BufferHookIntegration.t.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` and its `SeMatrixBehavior.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` and the parent `TestBase_UniswapV4DualSEBCPHook.sol` setup it leaves in place
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` and `...Vault_5.t.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` and `...Vault_N3.t.sol`
- The vault quote, planner, execution, execution preparation, and the hook guards cited above
- `SeMatrix_FullSpreadV4Fixture.sol`

Partially examined:

- `UniswapV4FullSpreadStandardExchangeVaultMath.sol` and `UniswapV4FullSpreadStandardExchangeVaultSwapProjection.sol`, far enough to identify the sizer's exits, not far enough to evaluate the quadratic coefficients
- `BufferHookIntegration.t.sol` extra tests (`getRate`, staged pretransfer, exact-out, identity). They are not in the supplied failures. Their inherited rows are the supplied failures.
- Balancer quad 5, as an inheritor of the quad seed and three local overrides

Not examined:

- The V3 full-spread matrix files under the same hook families. Reason: the supplied names, `SE quotes the face`, `refunds`, and the `FullSpreadV4` fixture match the V4 files above. No V3 file was required to place a supplied failure.
- `docs/reviews/se-fullspread-plan-execution-20261104/IMPLEMENTATION_AND_TEST_PLAN.md` and the remediation PRD. Gap. Not used as cause.

# Conclusions

Five causes. They share the zero face-to-share plan only where the cited path reads that plan. They are not one story.

1. Cause A, one production plan. `planIn` / `_mintOne` / `_size` returns a non-failed one-sided plan with `amountOut == 0` and `amountRefunded ==` the input. The single-buffer numbers prove the refund shape. Package, AlreadyUnlocked, and the one-sided Native call return that zero share word instead of reverting. Constant-product bind, single-buffer bind, and the inherited BufferHookIntegration bind assert that share word and fail `SE quotes the face: 0 <= 0`. This is not a missing-liquidity bind and not a native-settle or already-unlocked revert.

2. Cause B1, constant-product deposit. `_bufferPair` treats the zero preview as "do not exchange". First mint then reverts `InsufficientLpOut` because the pair-side claim is 0. This covers the constant-product row family named in the brief, including BufferHookIntegration's inherited rows. It is not `beforeSwap`.

3. Cause B2, single-buffer `beforeSwap`. `_previewWrap` reads the zero share word and `_wrapExactIn` reverts `MinAmountNotMet(1, 0)`. PoolManager wraps that as `HookCallFailed`. This covers the single-buffer composed-gas and row-swap failures only.

4. Cause B3, weighted N2, balancer quad, balancer quad 5, and curve quad joins. `joinProportional` maps the zero preview into a zero inventory and the first-mint guard reverts `ZeroAmount` before buffering. Same zero preview as Cause A. Different guard from B2 and B4.

5. Cause B4, weighted N3 join. The three-leg count check does not revert `ZeroAmount` when two other inventories are positive. `_bufferToken` then reverts `BufferFailed` because `minOut == 0`. Same zero preview. Different guard from B3, which is why N3's supplied error is not `ZeroAmount`.

6. Cause B5, orbital face swap. The buffer accepts a zero `minOut` and the vault returns 0 shares without reverting. The later face `beforeSwap` reverts `NotLive` because the effective reserve is 0 or `R` is 0. PoolManager wraps that as `HookCallFailed`. This covers orbital composed gas, index0, index1, poolManager swap, and rate target. It is not `MinAmountNotMet`, `BufferFailed`, or `ZeroAmount`.

7. Cause C, same plan, different assertion. Partial-consumption rows that call `refunds`, and the single-buffer residue assertion, fail because Cause A does not leave a rounding residue. The pass-through control in `refunds` passed. This is not a sleeve-booking defect and not a second sizer.

8. Cause D1, dual `test_row_index1` only. The harness cannot find a PairToken share on the requested side of the face within 32 candidates. No vault quote runs.

9. Cause D2, dual composed gas only. The share-as-SE bind is rejected because `asset()` is absent, the replacement router is never approved, and composed gas still swaps the leftover parent pool key through that router. `SimpleMintableERC20.transferFrom` reverts `allowance`. This is not Cause A and not D1.

Rejected collapses:

- One `beforeSwap` wrap does not produce `InsufficientLpOut`, `ZeroAmount`, and `BufferFailed`. Those three are direct deposit or join guards.
- Package, AlreadyUnlocked, and Native `0 <= 0` are not a separate package, unlock, or native-settlement defect. They are Cause A's returned zero, except that Native's failure string does not by itself identify which of its two `assertGt` calls failed.
- The partial-consumption residue assertion is not an independent production cause.
- The dual allowance failure and the dual share-side revert are not the face-to-share plan.

# Limits

- No forge, cast, install, Git, or deployment was run. The predicate inside `_size` that first sets the full remainder was not isolated. The five exits are cited. The quadratic coefficients were not evaluated.
- Native `test_wethFaceDepositsAgainstNativeCurrency` has two `assertGt(..., 0)` calls and the supplied string names neither. The one-sided call is the Cause A path. The bundle path was not proved to have returned nonzero by a trace.
- For orbital, balancer, curve, weighted, and weighted N3, `one-sided mint cannot fully consume` does not print the refund. `refund == 0` would fail the same require. The single-buffer measurement and the shared planner are the basis for reading it as a full remainder.
- Orbital `NotLive` is proved as the `beforeSwap` quote guard. Which of `R == 0` or a zero effective reserve was true after `_seedMixed` was not traced.
- Weighted N3 reaching `BufferFailed` rather than `ZeroAmount` implies the first-mint count check passed. The identity-rejected leg configuration that makes the other two inventories positive was not executed.
- Dual composed gas: the unapproved router `transferFrom` is the call that lacks allowance. A trace was not captured. The seed pull is approved, so it is not the matching require.
- The implementation plan and remediation PRD were not read. Nothing in this response is a product requirement drawn from them.
- This diagnosis does not authorize an implementation, a haircut, a search, or a code edit.
